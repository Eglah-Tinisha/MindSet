#!/usr/bin/env python3
"""
Optional: convert / resample raw clips into data/processed/ at 16 kHz mono.

Training can also load raw wavs on the fly (train_audio.py resamples with
torchaudio). Use this script when you want a fixed processed cache.

Usage:
    python -m scripts.prepare_audio
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

PACKAGE_DIR = Path(__file__).resolve().parents[1]
if str(PACKAGE_DIR) not in sys.path:
    sys.path.insert(0, str(PACKAGE_DIR))

from config import (  # noqa: E402
    MANIFEST_PATH,
    MAX_DURATION_SEC,
    PROCESSED_DIR,
    SAMPLE_RATE,
)


def load_manifest(path: Path):
    with path.open(encoding="utf-8") as f:
        return list(csv.DictReader(f))


def process_one(src: Path, dst: Path) -> None:
    import torch
    import torchaudio

    wav, sr = torchaudio.load(str(src))
    if wav.shape[0] > 1:
        wav = wav.mean(dim=0, keepdim=True)
    if sr != SAMPLE_RATE:
        wav = torchaudio.functional.resample(wav, sr, SAMPLE_RATE)
    max_len = int(MAX_DURATION_SEC * SAMPLE_RATE)
    if wav.shape[-1] > max_len:
        wav = wav[..., :max_len]
    # peak normalize
    peak = wav.abs().max().clamp(min=1e-8)
    wav = wav / peak
    dst.parent.mkdir(parents=True, exist_ok=True)
    torchaudio.save(str(dst), wav, SAMPLE_RATE)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=MANIFEST_PATH)
    args = parser.parse_args()

    if not args.manifest.is_file():
        print(f"✗ Manifest not found: {args.manifest}")
        return 1

    rows = load_manifest(args.manifest)
    print(f"Processing {len(rows)} clips → {PROCESSED_DIR}")
    ok = 0
    for row in rows:
        src = (PACKAGE_DIR / row["path"]).resolve()
        if not src.is_file():
            print(f"  skip missing {src}")
            continue
        rel = Path(row["dataset"]) / src.name
        dst = PROCESSED_DIR / rel
        try:
            process_one(src, dst)
            ok += 1
        except Exception as exc:  # noqa: BLE001
            print(f"  ✗ {src}: {exc}")
    print(f"✓ Processed {ok}/{len(rows)}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())