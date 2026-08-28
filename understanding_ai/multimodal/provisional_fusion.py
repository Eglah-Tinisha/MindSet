"""Text-priority voice fusion with derived emotional states.

This is an explainable prototype fusion layer:
- text emotion is weighted at 70 percent;
- voice-tone emotion is weighted at 30 percent;
- derived states are transparent interpretations of the two model signals,
  not new trained classifier labels.
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional

TEXT_WEIGHT = 0.70
VOICE_WEIGHT = 0.30

# Audio SER labels are projected into the existing text-emotion taxonomy.
_AUDIO_TO_TEXT = {
    "neutral": ["contentment"],
    "calm": ["contentment", "relief", "trust"],
    "happy": ["joy", "excitement", "contentment"],
    "sad": ["sadness", "grief", "loneliness"],
    "angry": ["anger", "frustration"],
    "fear": ["fear", "anxiety"],
    "disgust": ["disgust"],
    "surprise": ["surprise", "awe"],
    "anxiety": ["anxiety", "fear"],
}

_NEGATIVE = {
    "anger", "anxiety", "fear", "sadness", "disgust", "frustration",
    "grief", "guilt", "shame", "loneliness", "regret", "jealousy",
}
_POSITIVE = {
    "admiration", "anticipation", "awe", "contentment", "empathy",
    "excitement", "hope", "joy", "love", "pride", "relief", "trust",
}


def _norm(label: Optional[str]) -> str:
    return (label or "").strip().lower().replace(" ", "_")


def _score(value: Any) -> float:
    try:
        score = float(value or 0.0)
    except (TypeError, ValueError):
        return 0.0
    if score > 1.0:
        score /= 100.0
    return max(0.0, min(1.0, score))


def _family(label: str) -> str:
    if label in _NEGATIVE:
        return "negative"
    if label in _POSITIVE:
        return "positive"
    return "neutral"


def _distribution(prediction: Optional[Dict[str, Any]]) -> Dict[str, float]:
    """Build a normalized distribution from a text prediction."""
    if not prediction:
        return {}

    raw: Dict[str, float] = {}
    for item in prediction.get("top_emotions") or []:
        if not isinstance(item, dict):
            continue
        label = _norm(item.get("emotion") or item.get("label"))
        if label:
            raw[label] = max(raw.get(label, 0.0), _score(item.get("confidence") or item.get("probability") or item.get("score")))

    primary = _norm(prediction.get("emotion") or prediction.get("primary_emotion"))
    if primary:
        raw[primary] = max(raw.get(primary, 0.0), _score(prediction.get("confidence") or prediction.get("primary_prob")))

    total = sum(raw.values())
    if total <= 0:
        return {}
    return {label: value / total for label, value in raw.items()}


def _audio_distribution(prediction: Optional[Dict[str, Any]]) -> Dict[str, float]:
    """Project the 9-class audio model into text-emotion labels."""
    if not prediction:
        return {}

    audio_top = prediction.get("top_emotions") or []
    raw: Dict[str, float] = {}
    for item in audio_top:
        if not isinstance(item, dict):
            continue
        audio_label = _norm(item.get("emotion") or item.get("label"))
        confidence = _score(item.get("confidence") or item.get("probability") or item.get("score"))
        targets = _AUDIO_TO_TEXT.get(audio_label, [audio_label])
        if not targets:
            continue
        share = confidence / len(targets)
        for target in targets:
            raw[target] = raw.get(target, 0.0) + share

    if not raw:
        primary = _norm(prediction.get("emotion"))
        targets = _AUDIO_TO_TEXT.get(primary, [primary])
        confidence = _score(prediction.get("confidence"))
        if targets:
            for target in targets:
                raw[target] = confidence / len(targets)

    total = sum(raw.values())
    if total <= 0:
        return {}
    return {label: value / total for label, value in raw.items()}


def _derived_state(text_label: str, voice_label: str) -> Dict[str, str]:
    """Return a transparent, user-facing derived emotional interpretation."""
    text_family = _family(text_label)
    voice_family = _family(voice_label)

    pair_rules = {
        ("anger", "neutral"): ("Frustrated resignation", "Your words carried frustration while your voice sounded more restrained."),
        ("anger", "sadness"): ("Hurt frustration", "Your words sounded angry while your voice also carried sadness."),
        ("anxiety", "contentment"): ("Uneasy calm", "Your words suggested worry while your voice sounded calmer."),
        ("anxiety", "sadness"): ("Overwhelmed worry", "Your words suggested worry and your voice carried a lower emotional tone."),
        ("sadness", "contentment"): ("Quiet sadness", "Your words carried sadness while your voice sounded calm or contained."),
        ("sadness", "joy"): ("Bittersweet feeling", "Your words and voice carried different emotional directions."),
        ("loneliness", "contentment"): ("Withdrawn loneliness", "Your words suggested loneliness while your voice sounded emotionally contained."),
        ("hope", "sadness"): ("Cautious hope", "Your words carried hope while your voice still sounded heavy."),
        ("joy", "anxiety"): ("Excited nervousness", "Your words sounded positive while your voice carried tension."),
        ("relief", "anxiety"): ("Relief after tension", "Your words suggested relief while your voice still carried some tension."),
        ("frustration", "contentment"): ("Guarded frustration", "Your words carried frustration while your voice remained controlled."),
        ("grief", "contentment"): ("Heavy-hearted calm", "Your words carried grief while your voice sounded quiet or controlled."),
        ("confusion", "anxiety"): ("Restless uncertainty", "Your words suggested uncertainty and your voice carried tension."),
        ("contentment", "sadness"): ("Reflective sadness", "Your words sounded settled while your voice carried sadness."),
        ("excitement", "fear"): ("Nervous anticipation", "Your words sounded energized while your voice carried nervousness."),
    }
    if (text_label, voice_label) in pair_rules:
        label, note = pair_rules[(text_label, voice_label)]
        return {"label": label, "note": note}

    if text_family == "negative" and voice_family == "negative":
        return {"label": "Emotionally overwhelmed", "note": "Both your words and voice carried difficult emotional signals."}
    if text_family == "negative" and voice_family == "neutral":
        return {"label": "Guarded difficulty", "note": "Your words carried difficulty while your voice sounded more controlled."}
    if text_family == "positive" and voice_family == "negative":
        return {"label": "Mixed emotional pull", "note": "Your words and voice carried different emotional directions."}
    if text_family == "positive" and voice_family == "neutral":
        return {"label": "Settled positivity", "note": "Your words sounded positive and your voice sounded steady."}
    if text_family == voice_family == "positive":
        return {"label": "Warm encouragement", "note": "Both your words and voice carried supportive emotional signals."}
    if text_label == "confusion":
        return {"label": "Reflective uncertainty", "note": "Your words suggested uncertainty while your voice added emotional context."}
    return {"label": "Reflective mixed state", "note": "Your words and voice were combined to describe this reflection."}


def provisional_final(
    *,
    transcript: str,
    text_prediction: Optional[Dict[str, Any]],
    audio_prediction: Optional[Dict[str, Any]],
) -> Dict[str, Any]:
    """Create a text-priority 70/30 combined voice-journal result."""
    transcript_exists = bool((transcript or "").strip())
    text_distribution = _distribution(text_prediction)
    voice_distribution = _audio_distribution(audio_prediction)

    text_primary = _norm((text_prediction or {}).get("emotion"))
    voice_primary = _norm((audio_prediction or {}).get("emotion"))

    # Keep the existing audio-only fallback when speech was not detected.
    if not transcript_exists or not text_distribution:
        if not voice_distribution:
            return {
                "emotion": "unknown",
                "confidence": 0.0,
                "strategy": "no_signal",
                "reason": "No clear speech or voice signal was available.",
                "signals": {"text": None, "voice": None},
                "derived_state": None,
            }
        mapped = max(voice_distribution, key=voice_distribution.get)
        return {
            "emotion": mapped,
            "confidence": round(voice_distribution[mapped], 4),
            "strategy": "voice_only",
            "reason": "A voice-tone signal was available, but clear words were not detected.",
            "signals": {
                "text": None,
                "voice": {"emotion": voice_primary, "weight": 1.0},
            },
            "derived_state": None,
        }

    # Text-only fallback when audio prediction is unavailable.
    if not voice_distribution:
        winner = max(text_distribution, key=text_distribution.get)
        return {
            "emotion": winner,
            "confidence": round(text_distribution[winner], 4),
            "strategy": "text_only",
            "reason": "Your words were the available signal for this reflection.",
            "signals": {
                "text": {"emotion": text_primary, "weight": 1.0},
                "voice": None,
            },
            "derived_state": None,
        }

    combined: Dict[str, float] = {}
    for label, probability in text_distribution.items():
        combined[label] = combined.get(label, 0.0) + probability * TEXT_WEIGHT
    for label, probability in voice_distribution.items():
        combined[label] = combined.get(label, 0.0) + probability * VOICE_WEIGHT

    winner = max(combined, key=combined.get)
    derived = _derived_state(text_primary or winner, voice_primary or winner)
    combined_top = [
        {"emotion": label, "confidence": round(score, 4), "confidence_percent": round(score * 100, 2)}
        for label, score in sorted(combined.items(), key=lambda item: item[1], reverse=True)[:5]
    ]

    return {
        "emotion": winner,
        "confidence": round(combined[winner], 4),
        "strategy": "text_priority_70_voice_30",
        "reason": "Your words were given the strongest influence, while your voice tone added supporting context.",
        "signals": {
            "text": {"emotion": text_primary, "weight": TEXT_WEIGHT, "confidence": _score((text_prediction or {}).get("confidence"))},
            "voice": {"emotion": voice_primary, "weight": VOICE_WEIGHT, "confidence": _score((audio_prediction or {}).get("confidence"))},
            "combined_top_emotions": combined_top,
        },
        "derived_state": derived,
    }