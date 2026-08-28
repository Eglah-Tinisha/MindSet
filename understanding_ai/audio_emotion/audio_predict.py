#!/usr/bin/env python3
"""
Audio emotion inference for Phase 1 SER model.

Usage:
    python audio_predict.py path/to/clip.wav
    from audio_predict import predict_emotion_audio
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple, Union

import numpy as np
import torch

PACKAGE_DIR = Path(__file__).resolve().parent
if str(PACKAGE_DIR) not in sys.path:
    sys.path.insert(0, str(PACKAGE_DIR))

from config import (  # noqa: E402
    CONF_THRESHOLD,
    MAX_DURATION_SEC,
    MODEL_OUTPUT_DIR,
    SAMPLE_RATE,
    TOP_K,
)
from labels import AUDIO_LABELS, text_candidates_for  # noqa: E402

_AUDIO_CACHE: Optional[Tuple[Any, Any, torch.device, Dict[str, Any]]] = None


def confidence_label(conf: float) -> str:
    if conf >= 0.90:
        return "Very High"
    if conf >= 0.75:
        return "High"
    if conf >= 0.55:
        return "Moderate"
    if conf >= 0.35:
        return "Low"
    return "Very Low"


def _load_waveform(
    source: Union[str, Path, bytes, bytearray],
    sample_rate: int = SAMPLE_RATE,
    max_duration: float = MAX_DURATION_SEC,
) -> np.ndarray:
    """Load mono float32 waveform from path or raw bytes.

    Uses soundfile for paths (avoids torchcodec required by torchaudio 2.11+).
    """
    import io

    import soundfile as sf

    if isinstance(source, (bytes, bytearray)):
        array, sr = sf.read(io.BytesIO(source), dtype="float32", always_2d=True)
    else:
        path = Path(source)
        if not path.is_file():
            raise FileNotFoundError(f"Audio file not found: {path}")
        array, sr = sf.read(str(path), dtype="float32", always_2d=True)

    # (samples, channels) -> mono tensor
    mono = array.mean(axis=1)
    wav = torch.from_numpy(np.ascontiguousarray(mono))
    if int(sr) != int(sample_rate):
        import torchaudio

        wav = torchaudio.functional.resample(
            wav.unsqueeze(0), int(sr), int(sample_rate)
        ).squeeze(0)
    max_len = int(sample_rate * max_duration)
    if wav.numel() > max_len:
        wav = wav[:max_len]
    if wav.numel() == 0:
        raise ValueError("Audio is empty after loading.")
    peak = wav.abs().max().clamp(min=1e-8)
    wav = wav / peak
    return wav.cpu().numpy().astype(np.float32)


def load_audio_model(model_dir: Union[str, Path] = MODEL_OUTPUT_DIR):
    from transformers import Wav2Vec2ForSequenceClassification, Wav2Vec2Processor

    model_dir = Path(model_dir)
    if not model_dir.is_dir():
        raise FileNotFoundError(
            f"Audio model directory not found: {model_dir}\n"
            "Train first with: python train_audio.py"
        )

    print(f"  Loading audio SER model from {model_dir} ...", flush=True)
    processor = Wav2Vec2Processor.from_pretrained(str(model_dir))
    model = Wav2Vec2ForSequenceClassification.from_pretrained(str(model_dir))
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model.to(device)
    model.eval()

    config: Dict[str, Any] = {
        "sample_rate": SAMPLE_RATE,
        "max_duration_sec": MAX_DURATION_SEC,
        "label_map": {i: n for i, n in enumerate(AUDIO_LABELS)},
    }
    cfg_path = model_dir / "config.json"
    if cfg_path.is_file():
        with cfg_path.open(encoding="utf-8") as f:
            disk = json.load(f)
        config.update(disk)
        if "label_map" in disk:
            # normalize keys to int
            config["label_map"] = {int(k): v for k, v in disk["label_map"].items()}

    print(f"  ✓ Audio model ready on {device}")
    return processor, model, device, config


def get_audio_model(model_dir: Union[str, Path, None] = None):
    """Load (or reuse) processor + model. Cache is keyed by resolved model path."""
    global _AUDIO_CACHE
    path = Path(model_dir) if model_dir is not None else MODEL_OUTPUT_DIR
    path = path.resolve()
    if _AUDIO_CACHE is not None:
        cached_path = _AUDIO_CACHE[3].get("_resolved_model_dir")
        if cached_path == str(path):
            return _AUDIO_CACHE
    processor, model, device, config = load_audio_model(path)
    config = dict(config)
    config["_resolved_model_dir"] = str(path)
    _AUDIO_CACHE = (processor, model, device, config)
    return _AUDIO_CACHE


def predict_emotion_audio(
    audio: Union[str, Path, bytes, bytearray],
    model_dir: Union[str, Path, None] = None,
) -> Dict[str, Any]:
    """
    Predict emotion from a wav/flac/mp3 path or raw audio bytes.

    Returns a JSON-serializable dict compatible with MindSet API style.
    """
    processor, model, device, config = get_audio_model(model_dir)
    sample_rate = int(config.get("sample_rate", SAMPLE_RATE))
    max_duration = float(config.get("max_duration_sec", MAX_DURATION_SEC))
    label_map: Dict[int, str] = {
        int(k): str(v) for k, v in config.get("label_map", {}).items()
    }
    if not label_map:
        label_map = {i: n for i, n in enumerate(AUDIO_LABELS)}

    array = _load_waveform(audio, sample_rate=sample_rate, max_duration=max_duration)
    inputs = processor(
        array,
        sampling_rate=sample_rate,
        return_tensors="pt",
        padding=True,
    )
    input_values = inputs.input_values.to(device)
    attention_mask = None
    if hasattr(inputs, "attention_mask") and inputs.attention_mask is not None:
        attention_mask = inputs.attention_mask.to(device)

    with torch.no_grad():
        if attention_mask is not None:
            logits = model(input_values=input_values, attention_mask=attention_mask).logits
        else:
            logits = model(input_values=input_values).logits
        probs = torch.softmax(logits, dim=-1).cpu().numpy()[0]

    order = np.argsort(probs)[::-1]
    top_emotions: List[Dict[str, Any]] = []
    for idx in order[:TOP_K]:
        name = label_map.get(int(idx), AUDIO_LABELS[int(idx)] if int(idx) < len(AUDIO_LABELS) else str(idx))
        p = float(probs[idx])
        top_emotions.append(
            {
                "emotion": name,
                "confidence": round(p, 4),
                "confidence_percent": round(p * 100, 2),
            }
        )

    top = top_emotions[0]
    emotion = top["emotion"]
    conf = float(top["confidence"])

    return {
        "emotion": emotion,
        "confidence": round(conf, 4),
        "confidence_percent": round(conf * 100, 2),
        "confidence_label": confidence_label(conf),
        "top_emotions": top_emotions,
        "label_space": "audio_v1",
        "low_confidence": conf < CONF_THRESHOLD,
        "text_compatible_map": {
            "audio_emotion": emotion,
            "primary_text_candidates": text_candidates_for(emotion),
        },
        "duration_sec": round(float(len(array) / sample_rate), 3),
    }


def main(argv: Optional[List[str]] = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if not args:
        print("Usage: python audio_predict.py <audio_file>")
        return 1
    path = args[0]
    result = predict_emotion_audio(path)
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
