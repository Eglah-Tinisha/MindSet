#!/usr/bin/env python3
"""
Evaluate a trained audio SER model on the validation split of manifest.csv.

Usage:
    python evaluate_audio.py
    python evaluate_audio.py --model-dir models/wav2vec2_ser
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import torch
from sklearn.metrics import accuracy_score, classification_report, f1_score
from sklearn.preprocessing import LabelEncoder

PACKAGE_DIR = Path(__file__).resolve().parent
if str(PACKAGE_DIR) not in sys.path:
    sys.path.insert(0, str(PACKAGE_DIR))

from audio_predict import predict_emotion_audio, get_audio_model  # noqa: E402
from config import MANIFEST_PATH, MODEL_OUTPUT_DIR, REPORTS_DIR  # noqa: E402
from labels import AUDIO_LABELS  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-dir", type=Path, default=MODEL_OUTPUT_DIR)
    parser.add_argument("--manifest", type=Path, default=MANIFEST_PATH)
    parser.add_argument("--split", default="val")
    args = parser.parse_args()

    if not args.manifest.is_file():
        print(f"✗ Missing manifest: {args.manifest}")
        return 1
    if not args.model_dir.is_dir():
        print(f"✗ Missing model dir: {args.model_dir}")
        return 1

    df = pd.read_csv(args.manifest)
    df = df[df["split"] == args.split].reset_index(drop=True)
    if df.empty:
        print(f"✗ No rows for split={args.split}")
        return 1

    print(f"Evaluating {len(df)} clips from split={args.split}")
    get_audio_model(str(args.model_dir))  # warm load

    y_true = []
    y_pred = []
    for row in df.itertuples(index=False):
        path = Path(row.path)
        if not path.is_file():
            path = PACKAGE_DIR / row.path
        if not path.is_file():
            continue
        try:
            result = predict_emotion_audio(str(path), model_dir=str(args.model_dir))
            y_pred.append(result["emotion"])
            y_true.append(str(row.label).strip().lower())
        except Exception as exc:  # noqa: BLE001
            print(f"  skip {path}: {exc}")

    if not y_true:
        print("✗ No successful predictions")
        return 1

    labels = AUDIO_LABELS
    report = classification_report(
        y_true, y_pred, labels=labels, zero_division=0, digits=4
    )
    acc = accuracy_score(y_true, y_pred)
    f1m = f1_score(y_true, y_pred, average="macro", zero_division=0, labels=labels)
    print(report)
    print(f"accuracy={acc:.4f}  f1_macro={f1m:.4f}")

    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    out = REPORTS_DIR / "eval_report_inference.txt"
    out.write_text(
        report + f"\naccuracy={acc:.4f}\nf1_macro={f1m:.4f}\n",
        encoding="utf-8",
    )
    print(f"✓ {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())