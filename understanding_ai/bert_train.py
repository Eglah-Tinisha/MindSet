"""
BERT Emotion Classifier — GPU-Optimized Training Script
=========================================================
Optimized for: RTX 5060 8GB GDDR7 + 32GB RAM (ASUS TUF F16)
Compatible with: transformers >= 4.x / 5.x

Folder structure expected:
    your_project/
    ├── data/
    │   └── train.csv        ← your dataset
    ├── bert_model/          ← model saved here after training
    ├── bert_train.py
    └── bert_predict.py

CSV format:
    text,label
    "I feel great today",joy
"""

import os
import json
import pickle
import warnings
import numpy as np
import pandas as pd

warnings.filterwarnings("ignore")

from sklearn.preprocessing import LabelEncoder
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, accuracy_score, f1_score

import torch
from torch.utils.data import Dataset

from transformers import (
    BertTokenizerFast,
    BertForSequenceClassification,
    TrainingArguments,
    Trainer,
    EarlyStoppingCallback,
    DataCollatorWithPadding,
)

# ══════════════════════════════════════════════════════
#  CONFIGURATION  —  edit only this section
# ══════════════════════════════════════════════════════

CSV_PATH     = "data/train.csv"
TEXT_COL     = "text"
LABEL_COL    = "label"
OUTPUT_DIR   = "bert_model"

MODEL_NAME   = "bert-base-uncased"
MAX_LEN      = 128
BATCH_SIZE   = 32        # RTX 5060 8GB handles 32 at MAX_LEN=128; drop to 16 if OOM
EPOCHS       = 5
LR           = 2e-5
WARMUP_RATIO = 0.06
WEIGHT_DECAY = 0.01
TEST_SIZE    = 0.15
SEED         = 42

# ══════════════════════════════════════════════════════
#  GPU SETUP
# ══════════════════════════════════════════════════════

def setup_device():
    print("\n  Checking hardware...")
    if torch.cuda.is_available():
        device = torch.device("cuda")
        gpu  = torch.cuda.get_device_name(0)
        vram = torch.cuda.get_device_properties(0).total_memory / 1e9
        print(f"  ✓ GPU   : {gpu}")
        print(f"  ✓ VRAM  : {vram:.1f} GB")
        # TF32 — free speedup on RTX 30/40/50 series, no accuracy loss
        torch.backends.cuda.matmul.allow_tf32 = True
        torch.backends.cudnn.allow_tf32 = True
        torch.backends.cudnn.benchmark = True
    else:
        device = torch.device("cpu")
        print("  ⚠ No CUDA GPU detected — running on CPU.")
        print("  ⚠ To enable GPU, reinstall PyTorch with CUDA support:")
        print("    pip uninstall torch -y")
        print("    pip install torch --index-url https://download.pytorch.org/whl/cu128")
        print()
    return device

# ══════════════════════════════════════════════════════
#  1. LOAD & CLEAN DATASET
# ══════════════════════════════════════════════════════

def load_data() -> pd.DataFrame:
    print(f"\n[1/6] Loading dataset: {CSV_PATH}")

    if not os.path.exists(CSV_PATH):
        raise FileNotFoundError(
            f"\n  ✗ File not found: '{CSV_PATH}'\n"
            f"  Expected location: {os.path.abspath(CSV_PATH)}\n"
            f"  Update CSV_PATH at the top of this script if your file is elsewhere."
        )

    df = pd.read_csv(CSV_PATH)
    print(f"      Columns found : {list(df.columns)}")

    # Auto-detect columns if names differ
    if TEXT_COL not in df.columns:
        matches = [c for c in df.columns if "text" in c.lower() or "sentence" in c.lower()]
        if matches:
            df = df.rename(columns={matches[0]: TEXT_COL})
            print(f"      Auto-mapped '{matches[0]}' → '{TEXT_COL}'")

    if LABEL_COL not in df.columns:
        matches = [c for c in df.columns if "label" in c.lower() or "emotion" in c.lower()]
        if matches:
            df = df.rename(columns={matches[0]: LABEL_COL})
            print(f"      Auto-mapped '{matches[0]}' → '{LABEL_COL}'")

    before = len(df)
    df = df[[TEXT_COL, LABEL_COL]].dropna()
    df[TEXT_COL] = df[TEXT_COL].astype(str).str.strip()
    df = df[df[TEXT_COL].str.len() > 1]
    after = len(df)

    print(f"      Rows          : {before:,} loaded → {after:,} kept ({before - after} dropped)")
    print(f"      Classes ({df[LABEL_COL].nunique()})    : {sorted(df[LABEL_COL].unique())}")
    print(f"\n      Distribution:")
    dist = df[LABEL_COL].value_counts()
    for emotion, count in dist.items():
        bar = "█" * (count * 30 // dist.max())
        print(f"        {emotion:<12} {count:>7,}  {bar}")
    return df

# ══════════════════════════════════════════════════════
#  2. ENCODE LABELS
# ══════════════════════════════════════════════════════

def encode_labels(df: pd.DataFrame):
    print(f"\n[2/6] Encoding labels...")
    le = LabelEncoder()
    df = df.copy()
    df["encoded_label"] = le.fit_transform(df[LABEL_COL])
    num_labels = len(le.classes_)
    print(f"      {num_labels} classes → {dict(enumerate(le.classes_))}")
    return df, le, num_labels

# ══════════════════════════════════════════════════════
#  3. STRATIFIED SPLIT
# ══════════════════════════════════════════════════════

def split_data(df: pd.DataFrame):
    print(f"\n[3/6] Stratified split  (train {int((1-TEST_SIZE)*100)}% / val {int(TEST_SIZE*100)}%)")
    train_df, val_df = train_test_split(
        df, test_size=TEST_SIZE, random_state=SEED,
        stratify=df["encoded_label"]
    )
    print(f"      Train: {len(train_df):,}  |  Val: {len(val_df):,}")
    return train_df.reset_index(drop=True), val_df.reset_index(drop=True)

# ══════════════════════════════════════════════════════
#  4. DATASET CLASS
# ══════════════════════════════════════════════════════

class EmotionDataset(Dataset):
    def __init__(self, texts, labels, tokenizer):
        self.encodings = tokenizer(
            list(texts),
            truncation=True,
            max_length=MAX_LEN,
            padding=False,    # handled per-batch by DataCollatorWithPadding
        )
        self.labels = list(labels)

    def __len__(self):
        return len(self.labels)

    def __getitem__(self, idx):
        item = {k: torch.tensor(v[idx]) for k, v in self.encodings.items()}
        item["labels"] = torch.tensor(self.labels[idx], dtype=torch.long)
        return item

# ══════════════════════════════════════════════════════
#  5. METRICS
# ══════════════════════════════════════════════════════

def compute_metrics(eval_pred):
    logits, labels = eval_pred
    preds = np.argmax(logits, axis=-1)
    return {
        "accuracy":     round(accuracy_score(labels, preds), 4),
        "f1_macro":     round(f1_score(labels, preds, average="macro",    zero_division=0), 4),
        "f1_weighted":  round(f1_score(labels, preds, average="weighted", zero_division=0), 4),
    }

# ══════════════════════════════════════════════════════
#  6. TRAIN
# ══════════════════════════════════════════════════════

def train(train_dataset, val_dataset, tokenizer, num_labels):
    print(f"\n[5/6] Loading {MODEL_NAME}  (num_labels={num_labels})...")

    model = BertForSequenceClassification.from_pretrained(
        MODEL_NAME,
        num_labels=num_labels,
        hidden_dropout_prob=0.1,
        attention_probs_dropout_prob=0.1,
        ignore_mismatched_sizes=True,
    )

    use_fp16 = torch.cuda.is_available()

    # Build TrainingArguments — compatible with transformers 4.x and 5.x
    # fp16_opt_level was removed; fp16=True is sufficient for RTX GPUs
    training_args = TrainingArguments(
        output_dir=OUTPUT_DIR,
        num_train_epochs=EPOCHS,

        per_device_train_batch_size=BATCH_SIZE,
        per_device_eval_batch_size=BATCH_SIZE * 2,

        learning_rate=LR,
        weight_decay=WEIGHT_DECAY,
        warmup_steps=int(WARMUP_RATIO * (len(train_dataset) // BATCH_SIZE) * EPOCHS),
        lr_scheduler_type="cosine",

        # Mixed precision — no fp16_opt_level needed, PyTorch handles it
        fp16=use_fp16,

        eval_strategy="epoch",
        save_strategy="epoch",
        load_best_model_at_end=True,
        metric_for_best_model="f1_macro",
        greater_is_better=True,

        max_grad_norm=1.0,

        # logging_dir removed in transformers 5.2 — set env var if you need TensorBoard:
        # os.environ["TENSORBOARD_LOGGING_DIR"] = os.path.join(OUTPUT_DIR, "logs")
        logging_steps=100,
        logging_first_step=True,

        dataloader_num_workers=2,
        dataloader_pin_memory=use_fp16,   # pin memory only when using GPU
        report_to="none",
        seed=SEED,
    )

    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=train_dataset,
        eval_dataset=val_dataset,
        processing_class=tokenizer,
        data_collator=DataCollatorWithPadding(tokenizer),
        compute_metrics=compute_metrics,
        callbacks=[EarlyStoppingCallback(early_stopping_patience=2)],
    )

    device_str = f"GPU  ({torch.cuda.get_device_name(0)}) ⚡ fp16 ON" if use_fp16 else "CPU  (slow — see GPU fix above)"
    print(f"\n[6/6] Training on : {device_str}")
    print(f"      Batch size   : {BATCH_SIZE}  |  Epochs: {EPOCHS}  |  LR: {LR}\n")

    trainer.train()
    return trainer

# ══════════════════════════════════════════════════════
#  SAVE ARTIFACTS
# ══════════════════════════════════════════════════════

def save_artifacts(trainer, tokenizer, label_encoder, num_labels):
    print(f"\n[✓] Saving artifacts → {OUTPUT_DIR}/")
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    trainer.save_model(OUTPUT_DIR)
    tokenizer.save_pretrained(OUTPUT_DIR)

    with open(os.path.join(OUTPUT_DIR, "label_encoder.pkl"), "wb") as f:
        pickle.dump(label_encoder, f)

    config_data = {
        "num_labels": num_labels,
        "label_map":  {int(i): str(c) for i, c in enumerate(label_encoder.classes_)},
        "model_name": MODEL_NAME,
        "max_len":    MAX_LEN,
    }
    with open(os.path.join(OUTPUT_DIR, "config.json"), "w") as f:
        json.dump(config_data, f, indent=2)

    print(f"    ✓ model weights   → {OUTPUT_DIR}/")
    print(f"    ✓ tokenizer       → {OUTPUT_DIR}/")
    print(f"    ✓ label_encoder   → {OUTPUT_DIR}/label_encoder.pkl")
    print(f"    ✓ config          → {OUTPUT_DIR}/config.json")

# ══════════════════════════════════════════════════════
#  EVALUATION REPORT
# ══════════════════════════════════════════════════════

def evaluate_report(trainer, val_dataset, label_encoder):
    print(f"\n[✓] Final evaluation report (validation set)\n")
    preds_output = trainer.predict(val_dataset)
    preds = np.argmax(preds_output.predictions, axis=-1)
    true  = preds_output.label_ids

    report = classification_report(
        true, preds,
        target_names=label_encoder.classes_,
        zero_division=0,
        digits=4,
    )
    print(report)

    report_path = os.path.join(OUTPUT_DIR, "eval_report.txt")
    with open(report_path, "w") as f:
        f.write(report)
    print(f"    Report saved → {report_path}")

# ══════════════════════════════════════════════════════
#  MAIN
# ══════════════════════════════════════════════════════

def main():
    print("=" * 55)
    print("  BERT Emotion Classifier  —  GPU Training Pipeline")
    print("=" * 55)

    device = setup_device()

    df = load_data()
    df, label_encoder, num_labels = encode_labels(df)
    train_df, val_df = split_data(df)

    print(f"\n[4/6] Tokenizing with BertTokenizerFast...")
    tokenizer = BertTokenizerFast.from_pretrained(MODEL_NAME)
    train_dataset = EmotionDataset(train_df[TEXT_COL], train_df["encoded_label"], tokenizer)
    val_dataset   = EmotionDataset(val_df[TEXT_COL],   val_df["encoded_label"],   tokenizer)
    print(f"      Train: {len(train_dataset):,}  |  Val: {len(val_dataset):,}")

    trainer = train(train_dataset, val_dataset, tokenizer, num_labels)

    save_artifacts(trainer, tokenizer, label_encoder, num_labels)
    evaluate_report(trainer, val_dataset, label_encoder)

    print("\n" + "=" * 55)
    print("  Training complete! ✓")
    print("  Run:  python bert_predict.py")
    print("=" * 55 + "\n")


if __name__ == "__main__":
    main()