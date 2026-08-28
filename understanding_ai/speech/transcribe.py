"""Faster-Whisper transcription for MindSet voice journals."""

from __future__ import annotations

import os
import tempfile
import time
from typing import Any, Dict, Optional, Tuple

from .config_stt import (
    WHISPER_BEAM_SIZE,
    WHISPER_COMPUTE_TYPE,
    WHISPER_DEVICE,
    WHISPER_LANGUAGE,
    WHISPER_MODEL,
)

_WHISPER_MODEL = None
_WHISPER_ERROR: Optional[str] = None
_RESOLVED_DEVICE = "unknown"
_RESOLVED_COMPUTE = "unknown"


def _resolve_device_compute() -> Tuple[str, str]:
    device = WHISPER_DEVICE
    compute = WHISPER_COMPUTE_TYPE
    if device == "auto":
        try:
            import torch

            device = "cuda" if torch.cuda.is_available() else "cpu"
        except Exception:  # noqa: BLE001
            device = "cpu"
    if compute == "auto":
        compute = "float16" if device == "cuda" else "int8"
    return device, compute


def get_stt_status() -> Dict[str, Any]:
    return {
        "ready": _WHISPER_MODEL is not None,
        "error": _WHISPER_ERROR,
        "model": WHISPER_MODEL,
        "device": _RESOLVED_DEVICE,
        "compute_type": _RESOLVED_COMPUTE,
    }


def load_stt_model() -> None:
    """Load Whisper once (called at API startup). Soft-fails if missing."""
    global _WHISPER_MODEL, _WHISPER_ERROR, _RESOLVED_DEVICE, _RESOLVED_COMPUTE
    if _WHISPER_MODEL is not None:
        return
    try:
        from faster_whisper import WhisperModel

        device, compute = _resolve_device_compute()
        _RESOLVED_DEVICE, _RESOLVED_COMPUTE = device, compute
        print(f"  Loading Faster-Whisper '{WHISPER_MODEL}' on {device}/{compute} ...")
        _WHISPER_MODEL = WhisperModel(
            WHISPER_MODEL,
            device=device,
            compute_type=compute,
        )
        _WHISPER_ERROR = None
        print("  ✓ STT ready")
    except Exception as exc:  # noqa: BLE001
        _WHISPER_MODEL = None
        _WHISPER_ERROR = str(exc)
        print(f"  ⚠ STT unavailable: {exc}")


def transcribe_audio_bytes(
    audio_bytes: bytes,
    *,
    language: Optional[str] = None,
    suffix: str = ".wav",
) -> Dict[str, Any]:
    """
    Transcribe raw audio bytes.

    Returns:
      text, language, duration_sec, stt_model, stt_ms
    """
    if not audio_bytes:
        raise ValueError("Audio payload is empty.")

    if _WHISPER_MODEL is None:
        load_stt_model()
    if _WHISPER_MODEL is None:
        raise RuntimeError(
            _WHISPER_ERROR
            or "Faster-Whisper is not available. pip install faster-whisper"
        )

    lang = language if language is not None else WHISPER_LANGUAGE
    if lang == "" or lang == "auto":
        lang = None

    tmp_path = None
    started = time.perf_counter()
    try:
        fd, tmp_path = tempfile.mkstemp(suffix=suffix or ".wav")
        os.close(fd)
        with open(tmp_path, "wb") as f:
            f.write(audio_bytes)

        segments, info = _WHISPER_MODEL.transcribe(
            tmp_path,
            language=lang,
            beam_size=WHISPER_BEAM_SIZE,
            vad_filter=True,
        )
        parts = []
        for seg in segments:
            # Suppress common Whisper hallucinations from silence or low-level
            # emulator microphone noise.
            no_speech = float(getattr(seg, "no_speech_prob", 0.0) or 0.0)
            avg_logprob = float(getattr(seg, "avg_logprob", 0.0) or 0.0)
            if no_speech >= 0.60 or avg_logprob <= -1.20:
                continue
            segment_text = (seg.text or "").strip()
            if segment_text:
                parts.append(segment_text)
        text = " ".join(parts).strip()
        elapsed_ms = int((time.perf_counter() - started) * 1000)
        return {
            "text": text,
            "speech_detected": bool(text),
            "language": getattr(info, "language", lang) or lang or "en",
            "duration_sec": round(float(getattr(info, "duration", 0.0) or 0.0), 3),
            "stt_model": WHISPER_MODEL,
            "stt_ms": elapsed_ms,
            "device": _RESOLVED_DEVICE,
        }
    finally:
        if tmp_path and os.path.isfile(tmp_path):
            try:
                os.remove(tmp_path)
            except OSError:
                pass