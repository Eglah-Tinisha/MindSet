"""STT configuration (Faster-Whisper)."""

from __future__ import annotations

import os

# base.en is a good quality/speed balance for short journal clips on 8GB GPU.
WHISPER_MODEL = os.environ.get("MINDSET_WHISPER_MODEL", "base.en")
WHISPER_DEVICE = os.environ.get("MINDSET_WHISPER_DEVICE", "auto")  # auto|cuda|cpu
WHISPER_COMPUTE_TYPE = os.environ.get("MINDSET_WHISPER_COMPUTE", "auto")
WHISPER_LANGUAGE = os.environ.get("MINDSET_WHISPER_LANGUAGE", "en")
WHISPER_BEAM_SIZE = int(os.environ.get("MINDSET_WHISPER_BEAM", "1"))