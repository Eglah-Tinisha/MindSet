#!/usr/bin/env python3
"""
Scan data/raw/* and write a unified manifest.csv with audio Phase-1 labels.

Usage:
    python -m scripts.build_manifest
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import re
import sys
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple

PACKAGE_DIR = Path(__file__).resolve().parents[1]
if str(PACKAGE_DIR) not in sys.path:
    sys.path.insert(0, str(PACKAGE_DIR))

from config import MANIFEST_PATH, RAW_DIR, SEED, TEST_SIZE  # noqa: E402
from labels import (  # noqa: E402
    AUDIO_LABELS,
    CREMA_D_CODE_TO_AUDIO,
    RAVDESS_ID_TO_AUDIO,
    SAVEE_CODE_TO_AUDIO,
    TESS_TOKEN_TO_AUDIO,
    normalize_audio_label,
)


def _speaker_hash_split(speaker: str, seed: int = SEED, test_size: float = TEST_SIZE) -> str:
    """Deterministic speaker-level split so no speaker leaks train↔val."""
    digest = hashlib.md5(f"{seed}:{speaker}".encode("utf-8")).hexdigest()
    bucket = int(digest[:8], 16) / 0xFFFFFFFF
    return "val" if bucket < test_size else "train"


def _rel(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(PACKAGE_DIR.resolve()))
    except ValueError:
        return str(path.resolve())


def parse_ravdess(path: Path) -> Optional[Tuple[str, str]]:
    # 03-01-05-01-01-01-12.wav → modality-vocal-emotion-...
    name = path.stem
    parts = name.split("-")
    if len(parts) < 3:
        return None
    emotion_id = parts[2]
    label = RAVDESS_ID_TO_AUDIO.get(emotion_id)
    if not label:
        return None
    # actor is last field
    actor = parts[-1] if parts else "unknown"
    speaker = f"ravdess_actor_{actor}"
    return label, speaker


def parse_crema_d(path: Path) -> Optional[Tuple[str, str]]:
    # 1001_DFA_ANG_XX.wav
    parts = path.stem.split("_")
    if len(parts) < 3:
        return None
    actor = parts[0]
    code = parts[2].lower()
    label = CREMA_D_CODE_TO_AUDIO.get(code)
    if not label:
        label = normalize_audio_label(code)
    if not label:
        return None
    return label, f"crema_{actor}"


def parse_tess(path: Path) -> Optional[Tuple[str, str]]:
    # Folder YAF_angry or filename OAF_back_angry
    tokens = re.split(r"[_\s/\\-]+", str(path).lower())
    label = None
    for tok in tokens:
        if tok in TESS_TOKEN_TO_AUDIO:
            label = TESS_TOKEN_TO_AUDIO[tok]
            break
        mapped = normalize_audio_label(tok)
        if mapped:
            label = mapped
            break
    if not label:
        return None
    # speaker from YAF / OAF prefix
    speaker = "tess_unknown"
    for tok in tokens:
        if tok.startswith("yaf"):
            speaker = "tess_yaf"
            break
        if tok.startswith("oaf"):
            speaker = "tess_oaf"
            break
    return label, speaker


def parse_savee(path: Path) -> Optional[Tuple[str, str]]:
    # DC_a01.wav or a01.wav
    stem = path.stem.lower()
    speaker = "savee"
    m = re.match(r"([a-z]{2})_([a-z]+)(\d+)", stem)
    if m:
        speaker = f"savee_{m.group(1)}"
        code = m.group(2)
    else:
        m2 = re.match(r"([a-z]+)(\d+)", stem)
        if not m2:
            return None
        code = m2.group(1)
    # longest match first (sa, su before s)
    for key in sorted(SAVEE_CODE_TO_AUDIO.keys(), key=len, reverse=True):
        if code == key or code.startswith(key):
            return SAVEE_CODE_TO_AUDIO[key], speaker
    return None


PARSERS = {
    "ravdess": parse_ravdess,
    "crema_d": parse_crema_d,
    "tess": parse_tess,
    "savee": parse_savee,
}


def collect_rows() -> List[Dict[str, str]]:
    rows: List[Dict[str, str]] = []
    if not RAW_DIR.exists():
        return rows

    for dataset_dir in sorted(p for p in RAW_DIR.iterdir() if p.is_dir()):
        dataset = dataset_dir.name.lower()
        parser = PARSERS.get(dataset)
        if parser is None:
            # try generic folder name matching enabled set
            continue
        for wav in dataset_dir.rglob("*"):
            if wav.suffix.lower() not in {".wav", ".flac", ".mp3", ".ogg"}:
                continue
            parsed = parser(wav)
            if not parsed:
                continue
            label, speaker = parsed
            if label not in AUDIO_LABELS:
                continue
            split = _speaker_hash_split(speaker)
            rows.append(
                {
                    "path": _rel(wav),
                    "label": label,
                    "dataset": dataset,
                    "speaker": speaker,
                    "split": split,
                }
            )
    return rows


def write_manifest(rows: List[Dict[str, str]], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = ["path", "label", "dataset", "speaker", "split"]
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def summarize(rows: List[Dict[str, str]]) -> None:
    from collections import Counter

    print(f"  Total clips : {len(rows)}")
    if not rows:
        return
    print("  By dataset  :", dict(Counter(r["dataset"] for r in rows)))
    print("  By split    :", dict(Counter(r["split"] for r in rows)))
    print("  By label    :", dict(Counter(r["label"] for r in rows)))


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=MANIFEST_PATH)
    args = parser.parse_args(list(argv) if argv is not None else None)

    print("=" * 56)
    print("  Audio SER — build manifest")
    print("=" * 56)
    rows = collect_rows()
    write_manifest(rows, args.out)
    summarize(rows)
    print(f"\n  ✓ Wrote {args.out}")
    if not rows:
        print("  ⚠ No audio found. Run scripts.download_datasets and place wavs first.")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())