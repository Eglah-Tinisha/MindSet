"""
Audio SER label space + mapping into the existing MindSet text-emotion taxonomy.
"""

from __future__ import annotations

from typing import Dict, List, Sequence

AUDIO_LABELS: List[str] = [
    "neutral",
    "calm",
    "happy",
    "sad",
    "angry",
    "fear",
    "disgust",
    "surprise",
    "anxiety",
]

AUDIO_LABEL_TO_ID: Dict[str, int] = {name: i for i, name in enumerate(AUDIO_LABELS)}
ID_TO_AUDIO_LABEL: Dict[int, str] = {i: name for name, i in AUDIO_LABEL_TO_ID.items()}

TEXT_EMOTIONS: List[str] = [
    "admiration",
    "anger",
    "anticipation",
    "anxiety",
    "awe",
    "boredom",
    "confusion",
    "contentment",
    "disgust",
    "empathy",
    "excitement",
    "fear",
    "frustration",
    "grief",
    "guilt",
    "hope",
    "jealousy",
    "joy",
    "loneliness",
    "love",
    "pride",
    "regret",
    "relief",
    "sadness",
    "shame",
    "surprise",
    "trust",
]

TEXT_COMPATIBLE_MAP: Dict[str, List[str]] = {
    "neutral": [],
    "calm": ["contentment", "relief", "trust"],
    "happy": ["joy", "excitement", "contentment"],
    "sad": ["sadness", "grief", "loneliness"],
    "angry": ["anger", "frustration"],
    "fear": ["fear", "anxiety"],
    "disgust": ["disgust"],
    "surprise": ["surprise", "awe"],
    "anxiety": ["anxiety", "fear"],
}

RAVDESS_ID_TO_AUDIO: Dict[str, str] = {
    "01": "neutral",
    "02": "calm",
    "03": "happy",
    "04": "sad",
    "05": "angry",
    "06": "fear",
    "07": "disgust",
    "08": "surprise",
}

CREMA_D_CODE_TO_AUDIO: Dict[str, str] = {
    "neu": "neutral",
    "hap": "happy",
    "sad": "sad",
    "ang": "angry",
    "fea": "fear",
    "dis": "disgust",
}

TESS_TOKEN_TO_AUDIO: Dict[str, str] = {
    "neutral": "neutral",
    "happy": "happy",
    "sad": "sad",
    "angry": "angry",
    "fear": "fear",
    "disgust": "disgust",
    "ps": "surprise",
    "pleasant_surprise": "surprise",
    "surprise": "surprise",
}

SAVEE_CODE_TO_AUDIO: Dict[str, str] = {
    "a": "angry",
    "d": "disgust",
    "f": "fear",
    "h": "happy",
    "n": "neutral",
    "sa": "sad",
    "su": "surprise",
}

GENERIC_ALIASES: Dict[str, str] = {
    "anger": "angry",
    "angry": "angry",
    "happiness": "happy",
    "happy": "happy",
    "joy": "happy",
    "sadness": "sad",
    "sad": "sad",
    "fearful": "fear",
    "fear": "fear",
    "afraid": "fear",
    "surprised": "surprise",
    "surprise": "surprise",
    "disgusted": "disgust",
    "disgust": "disgust",
    "calm": "calm",
    "neutral": "neutral",
    "anxiety": "anxiety",
    "anxious": "anxiety",
    "stress": "anxiety",
    "stressed": "anxiety",
}


def normalize_audio_label(raw: str | None) -> str | None:
    if raw is None:
        return None
    key = str(raw).strip().lower().replace("-", "_").replace(" ", "_")
    if key in AUDIO_LABEL_TO_ID:
        return key
    if key in GENERIC_ALIASES:
        return GENERIC_ALIASES[key]
    for prefix in ("emotion_", "label_", "emo_"):
        if key.startswith(prefix):
            return normalize_audio_label(key[len(prefix) :])
    return None


def text_candidates_for(audio_emotion: str) -> List[str]:
    return list(TEXT_COMPATIBLE_MAP.get(audio_emotion, []))


def assert_label_space(labels: Sequence[str]) -> None:
    unknown = sorted({lab for lab in labels if lab not in AUDIO_LABEL_TO_ID})
    if unknown:
        raise ValueError(f"Unknown audio labels in manifest: {unknown}")