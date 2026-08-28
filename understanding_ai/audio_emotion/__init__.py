"""Phase 1 audio speech-emotion recognition package."""

# Keep imports lazy so Batch 1 (labels/config only) can verify
# before train/predict modules are created.
try:
    from .audio_predict import get_audio_model, predict_emotion_audio

    __all__ = ["predict_emotion_audio", "get_audio_model"]
except ImportError:  # pragma: no cover - expected during early batches
    __all__: list[str] = []