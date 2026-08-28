"""
Central configuration for the audio speech-emotion recognition (SER) pipeline.
Edit this file rather than scattering constants across scripts.
"""

from __future__ import annotations

import os
from pathlib import Path

# ── Paths ────────────────────────────────────────────────────────────────────
PACKAGE_DIR = Path(__file__).resolve().parent
UNDERSTANDING_AI_DIR = PACKAGE_DIR.parent
DATA_DIR = PACKAGE_DIR / "data"
RAW_DIR = DATA_DIR / "raw"
PROCESSED_DIR = DATA_DIR / "processed"
MANIFEST_PATH = DATA_DIR / "manifest.csv"
MODELS_DIR = PACKAGE_DIR / "models"
MODEL_OUTPUT_DIR = MODELS_DIR / "wav2vec2_ser"
REPORTS_DIR = PACKAGE_DIR / "reports"

# ── Audio ────────────────────────────────────────────────────────────────────
SAMPLE_RATE = 16_000
MAX_DURATION_SEC = 6.0
MIN_DURATION_SEC = 0.4
TARGET_CHANNELS = 1

# ── Model ────────────────────────────────────────────────────────────────────
PRETRAINED_MODEL = "facebook/wav2vec2-base"
SEED = 42
TEST_SIZE = 0.15
BATCH_SIZE = 8          # 8GB VRAM friendly; drop to 4 if OOM
EVAL_BATCH_SIZE = 16
EPOCHS = 12
LEARNING_RATE = 3e-5
WEIGHT_DECAY = 0.01
WARMUP_RATIO = 0.1
MAX_GRAD_NORM = 1.0
FP16 = True             # set False if CUDA fp16 fails
FREEZE_FEATURE_ENCODER = True  # freeze CNN frontend for first epochs
FREEZE_FEATURE_ENCODER_EPOCHS = 2
EARLY_STOPPING_PATIENCE = 3
METRIC_FOR_BEST = "f1_macro"

# ── Inference ────────────────────────────────────────────────────────────────
TOP_K = 5
CONF_THRESHOLD = 0.30

# ── Dataset download targets ─────────────────────────────────────────────────
ENABLED_DATASETS = (
    "ravdess",
    "crema_d",
    "tess",
    "savee",
)

HF_DATASET_SOURCES = {
    "ravdess": {
        "kind": "zip_urls",
        "note": "Prefer local unzip of RAVDESS Audio_Speech_Actors into data/raw/ravdess/",
    },
    "crema_d": {
        "kind": "hf",
        "hf_id": "AbstractTTS/CREMA-D",
        "note": "Falls back to manual AudioWAV folder under data/raw/crema_d/",
    },
    "tess": {
        "kind": "kaggle_or_manual",
        "note": "Place TESS wavs under data/raw/tess/",
    },
    "savee": {
        "kind": "manual",
        "note": "Place SAVEE wavs under data/raw/savee/",
    },
}


def env_bool(name: str, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


FP16 = env_bool("AUDIO_SER_FP16", FP16)
BATCH_SIZE = int(os.environ.get("AUDIO_SER_BATCH_SIZE", BATCH_SIZE))
PRETRAINED_MODEL = os.environ.get("AUDIO_SER_MODEL", PRETRAINED_MODEL)