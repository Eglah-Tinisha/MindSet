"""Run STT + text BERT + audio SER + provisional fusion."""

from __future__ import annotations

import time
from typing import Any, Dict, Optional

from multimodal.provisional_fusion import provisional_final
from speech.transcribe import transcribe_audio_bytes


def run_multimodal_pipeline(
    audio_bytes: bytes,
    *,
    language: Optional[str] = None,
    skip_audio: bool = False,
    skip_text: bool = False,
    suffix: str = ".wav",
) -> Dict[str, Any]:
    total_started = time.perf_counter()

    # --- STT ---
    transcript_block: Dict[str, Any]
    try:
        transcript_block = {
            "ok": True,
            **transcribe_audio_bytes(
                audio_bytes, language=language, suffix=suffix
            ),
        }
    except Exception as exc:  # noqa: BLE001
        transcript_block = {
            "ok": False,
            "text": "",
            "language": language or "en",
            "duration_sec": 0.0,
            "stt_model": None,
            "stt_ms": 0,
            "error": str(exc),
            "speech_detected": False,
        }

    transcript_text = (transcript_block.get("text") or "").strip()

    # Do not let silence/noise produce a made-up transcript or emotion label.
    if transcript_block.get("speech_detected") is False:
        total_ms = int((time.perf_counter() - total_started) * 1000)
        return {
            "transcript": transcript_block,
            "text_prediction": None,
            "text_error": "no_clear_speech",
            "audio_prediction": None,
            "audio_error": "no_clear_speech",
            "provisional_final": {
                "emotion": "unknown",
                "confidence": 0.0,
                "strategy": "no_clear_speech",
                "reason": "No clear speech was detected in this recording.",
            },
            "pipeline": {"stt_ms": int(transcript_block.get("stt_ms") or 0), "text_ms": 0, "audio_ms": 0, "total_ms": total_ms},
        }

    # --- Text ---
    text_prediction = None
    text_ms = 0
    text_error = None
    if not skip_text and transcript_text:
        t0 = time.perf_counter()
        try:
            from bert_predict import predict_emotion

            text_prediction = predict_emotion(transcript_text)
        except Exception as exc:  # noqa: BLE001
            text_error = str(exc)
        text_ms = int((time.perf_counter() - t0) * 1000)
    elif skip_text:
        text_error = "skipped"
    elif not transcript_text:
        text_error = "empty_transcript"

    # --- Audio SER ---
    audio_prediction = None
    audio_ms = 0
    audio_error = None
    if not skip_audio:
        t0 = time.perf_counter()
        try:
            from audio_emotion.audio_predict import predict_emotion_audio

            audio_prediction = predict_emotion_audio(audio_bytes)
        except Exception as exc:  # noqa: BLE001
            audio_error = str(exc)
        audio_ms = int((time.perf_counter() - t0) * 1000)
    else:
        audio_error = "skipped"

    final = provisional_final(
        transcript=transcript_text,
        text_prediction=text_prediction,
        audio_prediction=audio_prediction,
    )

    total_ms = int((time.perf_counter() - total_started) * 1000)
    return {
        "transcript": transcript_block,
        "text_prediction": text_prediction,
        "text_error": text_error,
        "audio_prediction": audio_prediction,
        "audio_error": audio_error,
        "provisional_final": final,
        "pipeline": {
            "stt_ms": int(transcript_block.get("stt_ms") or 0),
            "text_ms": text_ms,
            "audio_ms": audio_ms,
            "total_ms": total_ms,
        },
    }