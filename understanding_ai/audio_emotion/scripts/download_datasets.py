#!/usr/bin/env python3
"""
Download / prepare open SER datasets under audio_emotion/data/raw/.

Many emotion corpora require accepting license terms or manual download.
This script:
  1. Creates the expected folder layout.
  2. Attempts automated downloads where public URLs/HF IDs work.
  3. Prints clear manual steps when automation is blocked.

Usage (from understanding_ai/audio_emotion):
    python -m scripts.download_datasets
    python -m scripts.download_datasets --only ravdess crema_d
"""

from __future__ import annotations

import argparse
import os
import sys
import zipfile
from pathlib import Path
from typing import Iterable
from urllib.request import urlretrieve

# Allow running as script or module
PACKAGE_DIR = Path(__file__).resolve().parents[1]
if str(PACKAGE_DIR) not in sys.path:
    sys.path.insert(0, str(PACKAGE_DIR))

from config import ENABLED_DATASETS, RAW_DIR  # noqa: E402

# Public RAVDESS speech actor zips (Zenodo record 1188976 style mirrors).
# Official distribution is often via Zenodo; these IDs are the standard pack names.
RAVDESS_SPEECH_ZIPS = [
    # If these fail, place Audio_Speech_Actors_01-24 under data/raw/ravdess/
]


def _ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def _download(url: str, dest: Path, retries: int = 5) -> bool:
    """Download with resume + retries (handles flaky Zenodo connections)."""
    import urllib.request

    print(f"  ↓ {url}")
    print(f"    → {dest}")
    dest.parent.mkdir(parents=True, exist_ok=True)

    for attempt in range(1, retries + 1):
        try:
            existing = dest.stat().st_size if dest.is_file() else 0
            headers = {}
            mode = "wb"
            if existing > 0:
                headers["Range"] = f"bytes={existing}-"
                mode = "ab"
                print(f"  · resume attempt {attempt}/{retries} from byte {existing}")
            else:
                print(f"  · download attempt {attempt}/{retries}")

            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=120) as resp:
                # If server ignores Range and sends full file, rewrite from scratch.
                content_range = resp.headers.get("Content-Range", "")
                if existing > 0 and not content_range and resp.status == 200:
                    mode = "wb"
                    existing = 0
                total = resp.headers.get("Content-Length")
                total_i = int(total) if total and total.isdigit() else None
                read = 0
                chunk = 1024 * 1024
                with dest.open(mode) as out:
                    while True:
                        block = resp.read(chunk)
                        if not block:
                            break
                        out.write(block)
                        read += len(block)
                        if total_i:
                            done = existing + read if mode == "ab" else read
                            full = existing + total_i if mode == "ab" and content_range else total_i
                            if full:
                                pct = min(100.0, 100.0 * done / full)
                                print(f"\r  · progress: {done / 1e6:.1f} MB ({pct:.1f}%)", end="", flush=True)
                print()

            size = dest.stat().st_size if dest.is_file() else 0
            if size < 1_000_000:
                print(f"  ✗ file too small ({size} bytes) — retrying")
                continue
            print(f"  ✓ download complete ({size / 1e6:.1f} MB)")
            return True
        except Exception as exc:  # noqa: BLE001
            print(f"  ✗ download failed (attempt {attempt}/{retries}): {exc}")
            # keep partial file for resume on next attempt
    return False


def _unzip(zip_path: Path, out_dir: Path) -> None:
    print(f"  📦 unzip {zip_path.name} → {out_dir}")
    with zipfile.ZipFile(zip_path, "r") as zf:
        zf.extractall(out_dir)


def prepare_ravdess() -> None:
    target = RAW_DIR / "ravdess"
    _ensure_dir(target)
    wavs = list(target.rglob("*.wav"))
    if wavs:
        print(f"  ✓ RAVDESS already present ({len(wavs)} wav files)")
        return

    print("  RAVDESS: no wavs found. Trying Zenodo auto-download…")
    # Official speech-only pack on Zenodo (record 1188976), ~200MB+.
    zenodo_url = (
        "https://zenodo.org/records/1188976/files/"
        "Audio_Speech_Actors_01-24.zip?download=1"
    )
    zip_path = target / "Audio_Speech_Actors_01-24.zip"
    if not zip_path.is_file():
        ok = _download(zenodo_url, zip_path)
        if not ok:
            zip_path = None  # type: ignore[assignment]
    else:
        print(f"  · Found existing zip: {zip_path.name}")

    if zip_path is not None and zip_path.is_file() and zip_path.stat().st_size > 1_000_000:
        try:
            _unzip(zip_path, target)
            # Flatten common nested layout:
            # ravdess/Audio_Speech_Actors_01-24/Actor_01 -> ravdess/Actor_01
            nested = target / "Audio_Speech_Actors_01-24"
            if nested.is_dir():
                for child in nested.iterdir():
                    dest = target / child.name
                    if not dest.exists():
                        child.rename(dest)
                try:
                    nested.rmdir()
                except OSError:
                    pass
            # Also handle Actor folders already at target after extract
            wavs = list(target.rglob("*.wav"))
            if wavs:
                print(f"  ✓ RAVDESS ready ({len(wavs)} wav files)")
                return
            print("  ⚠ Zip extracted but no .wav files found — check folder layout")
        except Exception as exc:  # noqa: BLE001
            print(f"  ✗ unzip failed: {exc}")

    manual = target / "MANUAL_DOWNLOAD.txt"
    manual.write_text(
        """RAVDESS — manual download instructions
=====================================
1. Open https://zenodo.org/records/1188976
2. Download Audio_Speech_Actors_01-24.zip (speech only is enough for Phase 1)
3. Unzip so you have EXACTLY:
   audio_emotion/data/raw/ravdess/Actor_01/*.wav
   audio_emotion/data/raw/ravdess/Actor_02/*.wav
   ...
   (NOT an extra nested folder between ravdess and Actor_XX)

Filename pattern (speech):
   03-01-EMOTION-...-Actor.wav
   emotion id: 01=neutral 02=calm 03=happy 04=sad 05=angry 06=fearful 07=disgust 08=surprised
""",
        encoding="utf-8",
    )
    print(f"  ⚠ Auto-download failed or incomplete.")
    print(f"  ⚠ Manually place Audio_Speech_Actors under {target}")
    print(f"  ℹ See {manual}")


def prepare_crema_d() -> None:
    target = RAW_DIR / "crema_d"
    _ensure_dir(target)
    wavs = list(target.rglob("*.wav"))
    if wavs:
        print(f"  ✓ CREMA-D already present ({len(wavs)} wav files)")
        return

    # Try Hugging Face datasets if installed
    try:
        from datasets import load_dataset  # type: ignore

        print("  Trying Hugging Face datasets load for CREMA-D…")
        # Several community cards exist; try common ones and save audio files.
        tried = []
        for hf_id in ("AbstractTTS/CREMA-D", "minoosh/CREMA-D"):
            tried.append(hf_id)
            try:
                ds = load_dataset(hf_id, split="train")
                audio_dir = target / "AudioWAV"
                audio_dir.mkdir(parents=True, exist_ok=True)
                n = 0
                for i, row in enumerate(ds):
                    audio = row.get("audio") or row.get("speech")
                    if not audio:
                        continue
                    path = audio.get("path") if isinstance(audio, dict) else None
                    array = audio.get("array") if isinstance(audio, dict) else None
                    sr = audio.get("sampling_rate") if isinstance(audio, dict) else 16_000
                    label = row.get("label") or row.get("emotion") or "unk"
                    out = audio_dir / f"hf_{i:05d}_{label}.wav"
                    if path and os.path.isfile(path):
                        # copy reference
                        import shutil

                        shutil.copy2(path, out)
                        n += 1
                    elif array is not None:
                        import soundfile as sf
                        import numpy as np

                        sf.write(out, np.asarray(array), int(sr or 16_000))
                        n += 1
                if n:
                    print(f"  ✓ Wrote {n} CREMA-D files from HF ({hf_id})")
                    return
            except Exception as exc:  # noqa: BLE001
                print(f"  · HF {hf_id} failed: {exc}")
        print(f"  ⚠ HF sources failed: {tried}")
    except ImportError:
        print("  · `datasets` package not installed; skip HF CREMA-D pull")

    manual = target / "MANUAL_DOWNLOAD.txt"
    manual.write_text(
        """CREMA-D — manual download instructions
======================================
1. Request / download CREMA-D from the official source:
   https://github.com/CheyneyComputerScience/CREMA-D
2. Place WAV files under:
   audio_emotion/data/raw/crema_d/AudioWAV/*.wav
Filename pattern:
   ActorID_SentenceID_Emotion_Intensity.wav
   Emotion codes: ANG HAP SAD FEA DIS NEU
""",
        encoding="utf-8",
    )
    print(f"  ⚠ Place CREMA-D AudioWAV under {target}")
    print(f"  ℹ See {manual}")


def prepare_tess() -> None:
    target = RAW_DIR / "tess"
    _ensure_dir(target)
    wavs = list(target.rglob("*.wav"))
    if wavs:
        print(f"  ✓ TESS already present ({len(wavs)} wav files)")
        return
    manual = target / "MANUAL_DOWNLOAD.txt"
    manual.write_text(
        """TESS — manual download instructions
===================================
1. Download Toronto Emotional Speech Set (TESS)
   https://tspace.library.utoronto.ca/handle/1807/24487
   or Kaggle mirrors of TESS
2. Unzip so folders look like:
   audio_emotion/data/raw/tess/OAF_angry/*.wav
   audio_emotion/data/raw/tess/YAF_happy/*.wav
Emotion is usually in the folder or filename (angry, happy, sad, fear, disgust, neutral, ps).
""",
        encoding="utf-8",
    )
    print(f"  ⚠ Place TESS wavs under {target}")
    print(f"  ℹ See {manual}")


def prepare_savee() -> None:
    target = RAW_DIR / "savee"
    _ensure_dir(target)
    wavs = list(target.rglob("*.wav"))
    if wavs:
        print(f"  ✓ SAVEE already present ({len(wavs)} wav files)")
        return
    manual = target / "MANUAL_DOWNLOAD.txt"
    manual.write_text(
        """SAVEE — manual download instructions
====================================
1. Download SAVEE (Surrey Audio-Visual Expressed Emotion)
   http://kahlan.eps.surrey.ac.uk/savee/  (registration often required)
2. Place wavs under:
   audio_emotion/data/raw/savee/**/*.wav
Filename codes: a=anger d=disgust f=fear h=happiness n=neutral sa=sadness su=surprise
""",
        encoding="utf-8",
    )
    print(f"  ⚠ Place SAVEE wavs under {target}")
    print(f"  ℹ See {manual}")


PREPARE = {
    "ravdess": prepare_ravdess,
    "crema_d": prepare_crema_d,
    "tess": prepare_tess,
    "savee": prepare_savee,
}


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Prepare SER dataset folders")
    parser.add_argument(
        "--only",
        nargs="*",
        default=list(ENABLED_DATASETS),
        help="Subset of datasets: ravdess crema_d tess savee",
    )
    args = parser.parse_args(list(argv) if argv is not None else None)

    print("=" * 56)
    print("  Audio SER — dataset preparation")
    print("=" * 56)
    _ensure_dir(RAW_DIR)

    for name in args.only:
        key = name.strip().lower()
        if key not in PREPARE:
            print(f"  ✗ unknown dataset: {name}")
            continue
        print(f"\n[{key}]")
        PREPARE[key]()

    print("\nDone. Next:")
    print("  python -m scripts.build_manifest")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
