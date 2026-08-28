"""
Local FastAPI backend for MindSet emotion models.

- POST /predict            → BERT text emotion classifier
- POST /analyze            → alias for /predict (Flutter default)
- POST /predict_audio      → Wav2Vec2 speech emotion classifier
- POST /predict_audio_b64  → audio via base64 JSON
- POST /predict_multimodal → STT + text + audio + provisional fusion
- POST /predict_multimodal_b64

Run with (from understanding_ai/):
    uvicorn api:app --reload --host 0.0.0.0 --port 8000
"""

from __future__ import annotations

import base64
import binascii
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from bert_predict import get_model, predict_emotion

# Make packages importable as siblings.
_ROOT = Path(__file__).resolve().parent
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

try:
    from audio_emotion.audio_predict import get_audio_model, predict_emotion_audio
except Exception:  # noqa: BLE001
    get_audio_model = None  # type: ignore[assignment]
    predict_emotion_audio = None  # type: ignore[assignment]

try:
    from speech.transcribe import get_stt_status, load_stt_model
except Exception:  # noqa: BLE001
    get_stt_status = None  # type: ignore[assignment]
    load_stt_model = None  # type: ignore[assignment]

try:
    from multimodal.pipeline import run_multimodal_pipeline
except Exception:  # noqa: BLE001
    run_multimodal_pipeline = None  # type: ignore[assignment]


app = FastAPI(
    title="MindSet Emotion API",
    description=(
        "Local REST API for text BERT, audio SER, STT, and multimodal fusion."
    ),
    version="1.2.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class PredictionRequest(BaseModel):
    text: str = Field(..., description="Text to analyse for emotion.")


class PredictionResponse(BaseModel):
    emotion: str
    confidence: float
    confidence_percent: float
    confidence_label: str
    certainty_score: float
    entropy: float
    summary: str
    top_emotions: List[Dict[str, Any]]
    valence: Dict[str, float]


class AudioBase64Request(BaseModel):
    audio_base64: str = Field(..., description="Base64-encoded audio bytes.")
    format: Optional[str] = Field(
        default="wav",
        description="Hint only (wav/webm/m4a/mp3); decoding uses content.",
    )


class AudioPredictionResponse(BaseModel):
    emotion: str
    confidence: float
    confidence_percent: float
    confidence_label: str
    top_emotions: List[Dict[str, Any]]
    label_space: str
    low_confidence: bool = False
    text_compatible_map: Dict[str, Any] = Field(default_factory=dict)
    duration_sec: Optional[float] = None


class MultimodalBase64Request(BaseModel):
    audio_base64: str
    format: Optional[str] = "wav"
    language: Optional[str] = "en"
    skip_audio: bool = False
    skip_text: bool = False


@app.on_event("startup")
def startup_event() -> None:
    # Text model
    try:
        get_model()
        app.state.model_load_error = None
    except Exception as exc:  # noqa: BLE001
        app.state.model_load_error = str(exc)

    # Audio model
    app.state.audio_model_load_error = None
    app.state.audio_model_ready = False
    if get_audio_model is None:
        app.state.audio_model_load_error = (
            "audio_emotion package or dependencies not available"
        )
    else:
        try:
            get_audio_model()
            app.state.audio_model_ready = True
        except Exception as exc:  # noqa: BLE001
            app.state.audio_model_load_error = str(exc)
            app.state.audio_model_ready = False

    # STT model (soft-fail)
    app.state.stt_ready = False
    app.state.stt_error = None
    if load_stt_model is None:
        app.state.stt_error = "speech package not available (pip install faster-whisper)"
    else:
        try:
            load_stt_model()
            status = get_stt_status() if get_stt_status else {}
            app.state.stt_ready = bool(status.get("ready"))
            app.state.stt_error = status.get("error")
        except Exception as exc:  # noqa: BLE001
            app.state.stt_ready = False
            app.state.stt_error = str(exc)


def _root_payload() -> Dict[str, Any]:
    return {
        "message": "MindSet emotion API is running.",
        "docs": "Open http://127.0.0.1:8000/docs to test the API.",
        "endpoints": {
            "text": "POST /predict or POST /analyze",
            "audio": "POST /predict_audio",
            "multimodal": "POST /predict_multimodal",
            "health": "GET /health",
        },
    }


@app.get("/")
def root() -> Dict[str, Any]:
    return _root_payload()


@app.post("/")
def root_post() -> Dict[str, Any]:
    return _root_payload()


@app.get("/health")
def health() -> Dict[str, Any]:
    stt = get_stt_status() if get_stt_status else {
        "ready": getattr(app.state, "stt_ready", False),
        "error": getattr(app.state, "stt_error", None),
    }
    return {
        "status": "ok",
        "text_model": "error" if getattr(app.state, "model_load_error", None) else "ready",
        "text_model_error": getattr(app.state, "model_load_error", None),
        "audio_model": (
            "ready"
            if getattr(app.state, "audio_model_ready", False)
            else "unavailable"
        ),
        "audio_model_error": getattr(app.state, "audio_model_load_error", None),
        "stt": "ready" if stt.get("ready") else "unavailable",
        "stt_error": stt.get("error") or getattr(app.state, "stt_error", None),
        "stt_model": stt.get("model"),
    }


def _run_text_predict(request: PredictionRequest) -> Dict[str, Any]:
    if getattr(app.state, "model_load_error", None):
        raise HTTPException(
            status_code=503,
            detail=f"Model loading failed: {app.state.model_load_error}",
        )

    text = request.text.strip() if request.text else ""
    if not text:
        raise HTTPException(status_code=400, detail="Text must not be empty.")

    try:
        return predict_emotion(text)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except FileNotFoundError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(
            status_code=500,
            detail=f"Prediction failed: {exc}",
        ) from exc


@app.post("/predict", response_model=PredictionResponse)
def predict(request: PredictionRequest) -> Dict[str, Any]:
    return _run_text_predict(request)


@app.post("/analyze", response_model=PredictionResponse)
def analyze(request: PredictionRequest) -> Dict[str, Any]:
    """Alias for /predict — matches Flutter AppSettings default endpoint."""
    return _run_text_predict(request)


def _require_audio_stack() -> None:
    if predict_emotion_audio is None:
        raise HTTPException(
            status_code=503,
            detail=(
                "Audio emotion stack is not importable. "
                "Install audio_emotion/requirements_audio.txt"
            ),
        )
    if not getattr(app.state, "audio_model_ready", False):
        err = getattr(app.state, "audio_model_load_error", "unknown error")
        raise HTTPException(
            status_code=503,
            detail=(
                f"Audio model not ready: {err}. "
                "Train with audio_emotion/train_audio.py first."
            ),
        )


def _decode_base64_audio(raw: str) -> bytes:
    value = raw.strip()
    if value.startswith("data:") and "," in value:
        value = value.split(",", 1)[1]
    try:
        audio_bytes = base64.b64decode(value, validate=False)
    except binascii.Error as exc:
        raise HTTPException(status_code=400, detail="Invalid base64 audio.") from exc
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="Audio payload is empty.")
    return audio_bytes


def _suffix_from_format(fmt: Optional[str]) -> str:
    name = (fmt or "wav").lower().lstrip(".")
    if name in {"wav", "webm", "m4a", "mp3", "ogg", "flac", "aac"}:
        return f".{name}"
    return ".wav"


@app.post("/predict_audio", response_model=AudioPredictionResponse)
async def predict_audio(
    file: Optional[UploadFile] = File(default=None),
) -> Dict[str, Any]:
    """Predict emotion from voice audio (multipart field `file`)."""
    _require_audio_stack()
    if file is None:
        raise HTTPException(
            status_code=400,
            detail="Provide multipart file field `file` (or use /predict_audio_b64).",
        )
    audio_bytes = await file.read()
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="Audio payload is empty.")
    try:
        return predict_emotion_audio(audio_bytes)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except FileNotFoundError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(
            status_code=500,
            detail=f"Audio prediction failed: {exc}",
        ) from exc


@app.post("/predict_audio_b64", response_model=AudioPredictionResponse)
def predict_audio_b64(request: AudioBase64Request) -> Dict[str, Any]:
    """JSON-only audio prediction."""
    _require_audio_stack()
    audio_bytes = _decode_base64_audio(request.audio_base64)
    try:
        return predict_emotion_audio(audio_bytes)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except FileNotFoundError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(
            status_code=500,
            detail=f"Audio prediction failed: {exc}",
        ) from exc


@app.post("/predict_multimodal")
async def predict_multimodal(
    file: UploadFile = File(...),
    language: str = Form(default="en"),
    skip_audio: bool = Form(default=False),
    skip_text: bool = Form(default=False),
) -> Dict[str, Any]:
    """STT + text emotion + audio emotion + provisional fusion."""
    if run_multimodal_pipeline is None:
        raise HTTPException(
            status_code=503,
            detail="Multimodal pipeline unavailable. Install faster-whisper and restart.",
        )
    audio_bytes = await file.read()
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="Audio payload is empty.")
    filename = file.filename or "clip.wav"
    suffix = Path(filename).suffix or ".wav"
    try:
        return run_multimodal_pipeline(
            audio_bytes,
            language=language,
            skip_audio=skip_audio,
            skip_text=skip_text,
            suffix=suffix,
        )
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(
            status_code=500,
            detail=f"Multimodal prediction failed: {exc}",
        ) from exc


@app.post("/predict_multimodal_b64")
def predict_multimodal_b64(request: MultimodalBase64Request) -> Dict[str, Any]:
    if run_multimodal_pipeline is None:
        raise HTTPException(
            status_code=503,
            detail="Multimodal pipeline unavailable. Install faster-whisper and restart.",
        )
    audio_bytes = _decode_base64_audio(request.audio_base64)
    try:
        return run_multimodal_pipeline(
            audio_bytes,
            language=request.language,
            skip_audio=request.skip_audio,
            skip_text=request.skip_text,
            suffix=_suffix_from_format(request.format),
        )
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(
            status_code=500,
            detail=f"Multimodal prediction failed: {exc}",
        ) from exc


@app.exception_handler(Exception)
async def unhandled_exception_handler(
    request: Request,
    exc: Exception,
) -> JSONResponse:
    return JSONResponse(
        status_code=500,
        content={"detail": f"Unexpected server error: {exc}"},
    )
