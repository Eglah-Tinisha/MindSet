#!/usr/bin/env python3
"""
Fine-tune Wav2Vec2 for speech emotion recognition (Phase 1 audio model).

Usage (from understanding_ai/audio_emotion):
    python train_audio.py
    AUDIO_SER_BATCH_SIZE=4 python train_audio.py

Requires: manifest.csv from scripts.build_manifest + wav files under data/raw/
"""

from __future__ import annotations

import json
import os
import pickle
import random
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional

import numpy as np
import pandas as pd
import torch
from sklearn.metrics import accuracy_score, classification_report, f1_score
from sklearn.preprocessing import LabelEncoder
from torch.utils.data import Dataset

PACKAGE_DIR = Path(__file__).resolve().parent
if str(PACKAGE_DIR) not in sys.path:
    sys.path.insert(0, str(PACKAGE_DIR))

from config import (  # noqa: E402
    BATCH_SIZE,
    EARLY_STOPPING_PATIENCE,
    EPOCHS,
    EVAL_BATCH_SIZE,
    FREEZE_FEATURE_ENCODER,
    FP16,
    LEARNING_RATE,
    MANIFEST_PATH,
    MAX_DURATION_SEC,
    MAX_GRAD_NORM,
    METRIC_FOR_BEST,
    MODEL_OUTPUT_DIR,
    PRETRAINED_MODEL,
    REPORTS_DIR,
    SAMPLE_RATE,
    SEED,
    WARMUP_RATIO,
    WEIGHT_DECAY,
)
from labels import AUDIO_LABELS, AUDIO_LABEL_TO_ID, assert_label_space  # noqa: E402


def set_seed(seed: int = SEED) -> None:
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)


def setup_device() -> torch.device:
    print("\n  Checking hardware...")
    if torch.cuda.is_available():
        device = torch.device("cuda")
        print(f"  ✓ GPU  : {torch.cuda.get_device_name(0)}")
        print(f"  ✓ VRAM : {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB")
        torch.backends.cuda.matmul.allow_tf32 = True
        torch.backends.cudnn.allow_tf32 = True
        torch.backends.cudnn.benchmark = True
    else:
        device = torch.device("cpu")
        print("  ⚠ No CUDA — training on CPU will be slow.")
    return device


def load_manifest(path: Path = MANIFEST_PATH) -> pd.DataFrame:
    if not path.is_file():
        raise FileNotFoundError(
            f"Manifest not found: {path}\n"
            "Run: python -m scripts.download_datasets && python -m scripts.build_manifest"
        )
    df = pd.read_csv(path)
    required = {"path", "label", "split"}
    missing = required - set(df.columns)
    if missing:
        raise ValueError(f"Manifest missing columns: {missing}")
    df = df.dropna(subset=["path", "label"]).copy()
    df["label"] = df["label"].astype(str).str.strip().str.lower()
    assert_label_space(df["label"].tolist())
    # resolve paths relative to package
    def resolve(p: str) -> str:
        cand = Path(p)
        if cand.is_file():
            return str(cand.resolve())
        cand2 = (PACKAGE_DIR / p).resolve()
        return str(cand2)

    df["abs_path"] = df["path"].map(resolve)
    df = df[df["abs_path"].map(lambda p: Path(p).is_file())].reset_index(drop=True)
    print(f"  Manifest rows usable: {len(df)}")
    print(f"  Labels: {sorted(df['label'].unique())}")
    print(f"  Split counts:\n{df['split'].value_counts().to_string()}")
    return df


@dataclass
class AudioExample:
    path: str
    label_id: int


class SERDataset(Dataset):
    def __init__(
        self,
        examples: List[AudioExample],
        processor: Any,
        sample_rate: int = SAMPLE_RATE,
        max_duration: float = MAX_DURATION_SEC,
        augment: bool = False,
    ):
        self.examples = examples
        self.processor = processor
        self.sample_rate = sample_rate
        self.max_duration = max_duration
        self.augment = augment
        self.max_length = int(sample_rate * max_duration)

    def __len__(self) -> int:
        return len(self.examples)

    def _load_wave(self, path: str) -> np.ndarray:
        # Prefer soundfile — torchaudio 2.11+ routes load() through torchcodec,
        # which is often missing on Windows and breaks training.
        import soundfile as sf

        array, sr = sf.read(path, dtype="float32", always_2d=True)
        # (samples, channels) -> mono
        mono = array.mean(axis=1)
        wav = torch.from_numpy(mono)
        if sr != self.sample_rate:
            import torchaudio

            wav = torchaudio.functional.resample(
                wav.unsqueeze(0), sr, self.sample_rate
            ).squeeze(0)
        if wav.numel() > self.max_length:
            wav = wav[: self.max_length]
        if self.augment and wav.numel() > 0:
            # light gain jitter
            gain = 10 ** (random.uniform(-3, 3) / 20)
            wav = wav * gain
            if random.random() < 0.3:
                noise = torch.randn_like(wav) * 0.005
                wav = wav + noise
        # peak normalize
        peak = wav.abs().max().clamp(min=1e-8)
        wav = (wav / peak).cpu().numpy().astype(np.float32)
        return wav

    def __getitem__(self, idx: int) -> Dict[str, Any]:
        ex = self.examples[idx]
        array = self._load_wave(ex.path)
        inputs = self.processor(
            array,
            sampling_rate=self.sample_rate,
            return_tensors="pt",
            padding=False,
        )
        item = {
            "input_values": inputs.input_values.squeeze(0),
            "labels": torch.tensor(ex.label_id, dtype=torch.long),
        }
        if hasattr(inputs, "attention_mask") and inputs.attention_mask is not None:
            item["attention_mask"] = inputs.attention_mask.squeeze(0)
        return item


class DataCollatorSERPadding:
    """Pad variable-length input_values for Wav2Vec2 sequence classification."""

    def __init__(self, processor: Any):
        self.processor = processor

    def __call__(self, features: List[Dict[str, Any]]) -> Dict[str, torch.Tensor]:
        # Normalize to 1-D float tensors / arrays for the processor pad API.
        input_values = []
        for f in features:
            v = f["input_values"]
            if isinstance(v, torch.Tensor):
                v = v.detach().cpu().float().numpy()
            input_values.append(v)
        labels = torch.stack([f["labels"] for f in features])
        batch = self.processor.pad(
            {"input_values": input_values},
            padding=True,
            return_tensors="pt",
        )
        batch["labels"] = labels
        return batch


def compute_metrics_builder(label_list: List[str]):
    def compute_metrics(eval_pred):
        logits, labels = eval_pred
        preds = np.argmax(logits, axis=-1)
        return {
            "accuracy": round(float(accuracy_score(labels, preds)), 4),
            "f1_macro": round(float(f1_score(labels, preds, average="macro", zero_division=0)), 4),
            "f1_weighted": round(
                float(f1_score(labels, preds, average="weighted", zero_division=0)), 4
            ),
        }

    return compute_metrics


def build_examples(df: pd.DataFrame) -> List[AudioExample]:
    # Use fixed AUDIO_LABEL_TO_ID order (do NOT use sklearn LabelEncoder —
    # it sorts alphabetically and desyncs from model id2label / config.json).
    return [
        AudioExample(
            path=row.abs_path,
            label_id=int(AUDIO_LABEL_TO_ID[str(row.label).strip().lower()]),
        )
        for row in df.itertuples(index=False)
    ]


def main() -> int:
    print("=" * 56)
    print("  Wav2Vec2 Audio Emotion — Training (Phase 1)")
    print("=" * 56)
    set_seed()
    setup_device()

    df = load_manifest()
    if len(df) < 20:
        print("✗ Not enough audio samples to train. Add datasets and rebuild manifest.")
        return 1

    train_df = df[df["split"] == "train"].reset_index(drop=True)
    val_df = df[df["split"] == "val"].reset_index(drop=True)
    if train_df.empty or val_df.empty:
        # fallback random split if speaker split collapsed
        print("  ⚠ Empty train/val from speaker split — using random stratified split")
        from sklearn.model_selection import train_test_split

        train_df, val_df = train_test_split(
            df, test_size=0.15, random_state=SEED, stratify=df["label"]
        )
        train_df = train_df.reset_index(drop=True)
        val_df = val_df.reset_index(drop=True)

    present = sorted(df["label"].unique())
    print(f"  Classes present in data: {present}")
    print(f"  Fixed label map: {AUDIO_LABEL_TO_ID}")

    from transformers import (
        EarlyStoppingCallback,
        Trainer,
        TrainingArguments,
        Wav2Vec2ForSequenceClassification,
        Wav2Vec2Processor,
    )

    print(f"\n  Loading processor/model: {PRETRAINED_MODEL}")
    processor = Wav2Vec2Processor.from_pretrained(PRETRAINED_MODEL)
    label2id = {n: i for i, n in enumerate(AUDIO_LABELS)}
    id2label = {i: n for i, n in enumerate(AUDIO_LABELS)}
    model = Wav2Vec2ForSequenceClassification.from_pretrained(
        PRETRAINED_MODEL,
        num_labels=len(AUDIO_LABELS),
        label2id=label2id,
        id2label=id2label,
        problem_type="single_label_classification",
    )

    if FREEZE_FEATURE_ENCODER and hasattr(model, "freeze_feature_encoder"):
        model.freeze_feature_encoder()
        print("  ✓ Frozen Wav2Vec2 feature encoder (CNN)")

    train_ds = SERDataset(build_examples(train_df), processor, augment=True)
    val_ds = SERDataset(build_examples(val_df), processor, augment=False)
    collator = DataCollatorSERPadding(processor)

    use_fp16 = bool(FP16 and torch.cuda.is_available())
    MODEL_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)

    args = TrainingArguments(
        output_dir=str(MODEL_OUTPUT_DIR),
        num_train_epochs=EPOCHS,
        per_device_train_batch_size=BATCH_SIZE,
        per_device_eval_batch_size=EVAL_BATCH_SIZE,
        learning_rate=LEARNING_RATE,
        weight_decay=WEIGHT_DECAY,
        warmup_ratio=WARMUP_RATIO,
        lr_scheduler_type="cosine",
        fp16=use_fp16,
        eval_strategy="epoch",
        save_strategy="epoch",
        load_best_model_at_end=True,
        metric_for_best_model=METRIC_FOR_BEST,
        greater_is_better=True,
        max_grad_norm=MAX_GRAD_NORM,
        logging_steps=50,
        logging_first_step=True,
        # Windows + custom loaders are more stable with 0 workers
        dataloader_num_workers=0,
        dataloader_pin_memory=use_fp16,
        report_to="none",
        seed=SEED,
        remove_unused_columns=False,
    )

    trainer = Trainer(
        model=model,
        args=args,
        train_dataset=train_ds,
        eval_dataset=val_ds,
        data_collator=collator,
        compute_metrics=compute_metrics_builder(AUDIO_LABELS),
        callbacks=[EarlyStoppingCallback(early_stopping_patience=EARLY_STOPPING_PATIENCE)],
    )

    print(f"\n  Train size: {len(train_ds)}  Val size: {len(val_ds)}")
    print(f"  Batch: {BATCH_SIZE}  Epochs: {EPOCHS}  LR: {LEARNING_RATE}  fp16: {use_fp16}")
    trainer.train()

    # Save
    trainer.save_model(str(MODEL_OUTPUT_DIR))
    processor.save_pretrained(str(MODEL_OUTPUT_DIR))
    # Save a simple encoder-compatible artifact for tooling that expects pickle.
    le = LabelEncoder()
    le.fit(AUDIO_LABELS)
    # Force classes_ order to match AUDIO_LABELS (sklearn would sort otherwise).
    le.classes_ = np.array(AUDIO_LABELS, dtype=object)
    with open(MODEL_OUTPUT_DIR / "label_encoder.pkl", "wb") as f:
        pickle.dump(le, f)
    config_data = {
        "num_labels": len(AUDIO_LABELS),
        "label_map": {i: n for i, n in enumerate(AUDIO_LABELS)},
        "label2id": {n: i for i, n in enumerate(AUDIO_LABELS)},
        "model_name": PRETRAINED_MODEL,
        "sample_rate": SAMPLE_RATE,
        "max_duration_sec": MAX_DURATION_SEC,
        "label_space": "audio_v1",
    }
    with open(MODEL_OUTPUT_DIR / "config.json", "w", encoding="utf-8") as f:
        json.dump(config_data, f, indent=2)

    # Eval report
    pred_out = trainer.predict(val_ds)
    preds = np.argmax(pred_out.predictions, axis=-1)
    true = pred_out.label_ids
    # map ids to names via AUDIO_LABELS order used by model
    target_names = AUDIO_LABELS
    report = classification_report(
        true,
        preds,
        labels=list(range(len(AUDIO_LABELS))),
        target_names=target_names,
        zero_division=0,
        digits=4,
    )
    print("\n" + report)
    report_path = REPORTS_DIR / "eval_report.txt"
    report_path.write_text(report, encoding="utf-8")
    print(f"  ✓ Model → {MODEL_OUTPUT_DIR}")
    print(f"  ✓ Report → {report_path}")
    print("\n  Next: python -m evaluate_audio  OR  start API with /predict_audio")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
