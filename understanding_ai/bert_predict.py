"""
=======================================================
  BERT Emotion Classifier  —  Prediction & Analysis
=======================================================
  Usage:
    python bert_predict.py                  ← interactive mode
    python bert_predict.py "I feel great"   ← single prediction
=======================================================
"""

import sys
import os
import math
import pickle
import numpy as np
import textwrap

import torch
from transformers import BertTokenizerFast, BertForSequenceClassification

# ─────────────────────────────────────────────────────
#  CONFIG
# ─────────────────────────────────────────────────────
BASE_DIR       = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR      = os.path.join(BASE_DIR, "bert_model")
MAX_LEN        = 128
TOP_K          = 5
CONF_THRESHOLD = 0.30
SECONDARY_THRESHOLD = 0.03   # emotions above this get mentioned in summary
WIDTH          = 62          # box width
_MODEL_CACHE   = None

# ─────────────────────────────────────────────────────
#  EMOTION METADATA
# ─────────────────────────────────────────────────────
EMOTION_EMOJI = {
    "admiration":   "🌟", "anger":        "😡", "anticipation": "⏳",
    "anxiety":      "😰", "awe":          "😲", "boredom":      "😴",
    "confusion":    "😕", "contentment":  "😌", "disgust":      "🤢",
    "empathy":      "🤝", "excitement":   "🤩", "fear":         "😨",
    "frustration":  "😤", "grief":        "😢", "guilt":        "😔",
    "hope":         "🌈", "jealousy":     "😒", "joy":          "😊",
    "loneliness":   "🥺", "love":         "❤️", "pride":        "🏆",
    "regret":       "😞", "relief":       "😮‍💨", "sadness":     "😞",
    "shame":        "😳", "surprise":     "😮", "trust":        "🤜",
}

POSITIVE_EMOTIONS = {
    "joy", "love", "excitement", "hope", "admiration", "contentment",
    "anticipation", "pride", "trust", "relief", "awe", "empathy"
}
NEGATIVE_EMOTIONS = {
    "anger", "sadness", "fear", "disgust", "grief", "guilt", "shame",
    "loneliness", "anxiety", "frustration", "jealousy", "regret"
}
NEUTRAL_EMOTIONS = {"surprise", "confusion", "boredom"}

# ─────────────────────────────────────────────────────
#  EMOTION → NATURAL LANGUAGE PHRASE TEMPLATES
# ─────────────────────────────────────────────────────
# Used to build the AI summary sentence
EMOTION_PHRASES = {
    "admiration":   "filled with admiration",
    "anger":        "quite angry",
    "anticipation": "full of anticipation",
    "anxiety":      "anxious",
    "awe":          "in awe",
    "boredom":      "bored",
    "confusion":    "confused",
    "contentment":  "content",
    "disgust":      "disgusted",
    "empathy":      "empathetic toward others",
    "excitement":   "excited",
    "fear":         "afraid",
    "frustration":  "frustrated",
    "grief":        "grieving",
    "guilt":        "guilty",
    "hope":         "hopeful",
    "jealousy":     "jealous",
    "joy":          "joyful",
    "loneliness":   "lonely",
    "love":         "feeling love",
    "pride":        "proud",
    "regret":       "full of regret",
    "relief":       "relieved",
    "sadness":      "sad",
    "shame":        "ashamed of yourself",
    "surprise":     "surprised",
    "trust":        "trusting",
}

# ─────────────────────────────────────────────────────
#  HELPER FUNCTIONS
# ─────────────────────────────────────────────────────
def confidence_label(conf):
    if conf >= 0.90: return "Very High", 5
    if conf >= 0.75: return "High     ", 4
    if conf >= 0.55: return "Moderate ", 3
    if conf >= 0.35: return "Low      ", 2
    return                  "Very Low ", 1

def confidence_bar_colored(conf, width=20):
    filled = int(round(conf * width))
    empty  = width - filled
    level  = confidence_label(conf)[1]
    colors = {5: "\033[92m", 4: "\033[92m", 3: "\033[93m", 2: "\033[91m", 1: "\033[91m"}
    c      = colors.get(level, "")
    reset  = "\033[0m"
    return f"{c}{'█' * filled}{reset}{'░' * empty}"

def entropy(probs):
    probs = np.clip(probs, 1e-10, 1.0)
    return float(-np.sum(probs * np.log2(probs)))

def certainty_score(probs):
    max_entropy = math.log2(len(probs))
    h = entropy(probs)
    return round((1 - h / max_entropy) * 100, 1)

def bar(value, width=20, color=None):
    filled = int(round(value * width))
    empty  = width - filled
    reset  = "\033[0m"
    if color:
        return f"{color}{'█' * filled}{reset}{'░' * empty}"
    return "█" * filled + "░" * empty

def colored(text, code):
    return f"\033[{code}m{text}\033[0m"

def divider(char="═", width=WIDTH):
    return char * width

def section(title, char="─", width=WIDTH):
    side = (width - len(title) - 2) // 2
    return f"{'─'*side} {title} {'─'*(width - side - len(title) - 2)}"

def wrap_print(text, indent=4, width=WIDTH):
    """Print wrapped text with indent."""
    wrapped = textwrap.fill(text, width=width - indent)
    for line in wrapped.splitlines():
        print(" " * indent + line)

# ─────────────────────────────────────────────────────
#  NATURAL LANGUAGE SUMMARY GENERATOR
# ─────────────────────────────────────────────────────
def generate_summary(results, probs):
    """
    Build a natural language sentence describing the emotional state.
    Includes primary + any secondary emotions above threshold.
    """
    # Collect significant emotions
    significant = [
        (emotion, prob)
        for emotion, prob in results
        if prob >= SECONDARY_THRESHOLD
    ]

    if not significant:
        significant = [results[0]]  # always include at least primary

    primary_emotion, primary_prob = significant[0]
    secondary = significant[1:]  # everything after primary

    # Get phrases
    primary_phrase   = EMOTION_PHRASES.get(primary_emotion, primary_emotion)
    secondary_phrases = [
        EMOTION_PHRASES.get(e, e)
        for e, _ in secondary
    ]

    # Build the sentence
    if not secondary_phrases:
        sentence = f"You appear to be {primary_phrase}."
    elif len(secondary_phrases) == 1:
        sentence = (
            f"You appear to be {primary_phrase}, "
            f"and at the same time {secondary_phrases[0]}."
        )
    elif len(secondary_phrases) == 2:
        sentence = (
            f"You appear to be {primary_phrase}, "
            f"while also feeling {secondary_phrases[0]} "
            f"and {secondary_phrases[1]}."
        )
    else:
        others = ", ".join(secondary_phrases[:-1])
        last   = secondary_phrases[-1]
        sentence = (
            f"You appear to be {primary_phrase}, "
            f"with underlying feelings of {others}, "
            f"and even {last}."
        )

    # Add a valence-based closing note
    pos = sum(p for e, p in results if e in POSITIVE_EMOTIONS)
    neg = sum(p for e, p in results if e in NEGATIVE_EMOTIONS)

    if neg > 0.80:
        closing = " This suggests a predominantly difficult emotional state."
    elif neg > 0.50 and pos > 0.20:
        closing = " There is a mix of difficult and hopeful feelings present."
    elif pos > 0.80:
        closing = " This reflects a very positive emotional state."
    elif pos > 0.50:
        closing = " Overall, the tone leans positive."
    else:
        closing = ""

    return sentence + closing

# ─────────────────────────────────────────────────────
#  LOAD MODEL
# ─────────────────────────────────────────────────────
def load_model():
    if not os.path.isdir(MODEL_DIR):
        raise FileNotFoundError(
            f"Model directory '{MODEL_DIR}' not found. Run bert_train.py first."
        )

    print()
    print(divider())
    print(colored(f"  {'BERT Emotion Classifier':^{WIDTH-2}}", "1;36"))
    print(divider())
    print(f"\n  {'⟳'} Loading model from '{MODEL_DIR}' ...", end=" ", flush=True)

    tokenizer = BertTokenizerFast.from_pretrained(MODEL_DIR)
    model     = BertForSequenceClassification.from_pretrained(MODEL_DIR)

    with open(os.path.join(MODEL_DIR, "label_encoder.pkl"), "rb") as f:
        le = pickle.load(f)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model.to(device)
    model.eval()

    print(colored("✓ Done", "92"))
    gpu_name = torch.cuda.get_device_name(0) if torch.cuda.is_available() else "CPU"
    print(f"  {'⚙'} Device     : {colored(gpu_name, '96')}")
    print(f"  {'📦'} Classes    : {colored(str(len(le.classes_)), '96')}")
    print(f"  {'🔍'} Max Length : {colored(str(MAX_LEN), '96')} tokens")
    print()

    return tokenizer, model, le, device

def get_model():
    """Load the BERT model once and reuse it for API/CLI predictions."""
    global _MODEL_CACHE
    if _MODEL_CACHE is None:
        _MODEL_CACHE = load_model()
    return _MODEL_CACHE

# ─────────────────────────────────────────────────────
#  PREDICT
# ─────────────────────────────────────────────────────
def predict(text, tokenizer, model, le, device):
    enc = tokenizer(
        text,
        max_length=MAX_LEN,
        padding="max_length",
        truncation=True,
        return_tensors="pt"
    )
    input_ids      = enc["input_ids"].to(device)
    attention_mask = enc["attention_mask"].to(device)

    with torch.no_grad():
        logits = model(
            input_ids=input_ids,
            attention_mask=attention_mask
        ).logits

    probs_tensor = torch.softmax(logits, dim=-1).cpu().numpy()[0]
    top_indices  = np.argsort(probs_tensor)[::-1]

    results = []
    for idx in top_indices:
        label = le.inverse_transform([idx])[0]
        prob  = float(probs_tensor[idx])
        results.append((label, prob))

    return results, probs_tensor

def predict_emotion(text):
    """
    Reusable prediction function for the local API.

    Returns the main emotion plus the useful analysis already produced by this
    project: top emotions, valence, certainty, entropy, and summary text.
    """
    if text is None or not str(text).strip():
        raise ValueError("Text must not be empty.")

    tokenizer, model, le, device = get_model()
    cleaned_text = str(text).strip()
    results, probs = predict(cleaned_text, tokenizer, model, le, device)

    top_emotion, top_conf = results[0]
    top_emotion = str(top_emotion)
    pos_score = sum(p for e, p in results if e in POSITIVE_EMOTIONS)
    neg_score = sum(p for e, p in results if e in NEGATIVE_EMOTIONS)
    neu_score = sum(p for e, p in results if e in NEUTRAL_EMOTIONS)

    return {
        "emotion": top_emotion,
        "confidence": round(float(top_conf), 4),
        "confidence_percent": round(float(top_conf) * 100, 2),
        "confidence_label": confidence_label(top_conf)[0].strip(),
        "certainty_score": certainty_score(probs),
        "entropy": round(entropy(probs), 3),
        "summary": generate_summary(results, probs),
        "top_emotions": [
            {
                "emotion": str(emotion),
                "confidence": round(float(prob), 4),
                "confidence_percent": round(float(prob) * 100, 2),
            }
            for emotion, prob in results[:TOP_K]
        ],
        "valence": {
            "positive": round(float(pos_score), 4),
            "negative": round(float(neg_score), 4),
            "neutral": round(float(neu_score), 4),
            "positive_percent": round(float(pos_score) * 100, 2),
            "negative_percent": round(float(neg_score) * 100, 2),
            "neutral_percent": round(float(neu_score) * 100, 2),
        },
    }

# ─────────────────────────────────────────────────────
#  DISPLAY RESULT
# ─────────────────────────────────────────────────────
def display_result(text, results, probs):
    top_emotion, top_conf = results[0]
    emoji    = EMOTION_EMOJI.get(top_emotion, "🔍")
    cert     = certainty_score(probs)
    ent      = round(entropy(probs), 3)
    conf_lbl, conf_lvl = confidence_label(top_conf)

    # ── Header ──────────────────────────────────────
    print()
    print(divider("═"))
    print(colored(f"  INPUT  : \"{text}\"", "1;37"))
    print(divider("═"))

    # ── Primary Emotion ──────────────────────────────
    print()
    print(f"  {section('PRIMARY EMOTION')}")
    print()

    emotion_color = "91" if top_emotion in NEGATIVE_EMOTIONS else \
                    "92" if top_emotion in POSITIVE_EMOTIONS else "93"

    print(f"  {emoji}  {colored(top_emotion.upper(), f'1;{emotion_color}')}")
    print()
    print(f"  {'Confidence':<16} {top_conf*100:>5.1f}%  "
          f"{conf_lbl}  {confidence_bar_colored(top_conf)}")
    print(f"  {'Certainty Score':<16} {colored(f'{cert}/100', '96')}")

    ent_label = (
        colored("decisive",      "92") if ent < 1.0  else
        colored("fairly clear",  "93") if ent < 2.0  else
        colored("mixed signals", "93") if ent < 3.0  else
        colored("uncertain",     "91")
    )
    print(f"  {'Entropy':<16} {ent}  ({ent_label})")

    if top_conf < CONF_THRESHOLD:
        print()
        print(f"  {colored('⚠  LOW CONFIDENCE — text may carry mixed emotions', '1;93')}")

    # ── Top-K Breakdown ─────────────────────────────
    print()
    print(f"  {section(f'TOP {TOP_K} EMOTION BREAKDOWN')}")
    print()
    print(f"  {'Emotion':<18} {'Prob':>7}   Bar")
    print(f"  {'─'*18} {'─'*7}   {'─'*22}")

    for i, (emotion, prob) in enumerate(results[:TOP_K]):
        em    = EMOTION_EMOJI.get(emotion, "  ")
        is_top = (i == 0)
        marker = colored(" ◄ PRIMARY", "1;33") if is_top else ""

        if is_top:
            e_col = f"1;{emotion_color}"
        elif prob >= SECONDARY_THRESHOLD:
            e_col = "37"
        else:
            e_col = "90"

        bar_color = f"\033[{emotion_color}m" if is_top else "\033[90m"
        prob_bar  = bar(prob, 20, bar_color if is_top else None)

        print(
            f"  {em} {colored(f'{emotion:<15}', e_col)} "
            f"{colored(f'{prob*100:>6.2f}%', '96' if prob >= SECONDARY_THRESHOLD else '90')}   "
            f"{prob_bar}{marker}"
        )

    # ── Emotional Valence ────────────────────────────
    pos_score = sum(p for e, p in results if e in POSITIVE_EMOTIONS)
    neg_score = sum(p for e, p in results if e in NEGATIVE_EMOTIONS)
    neu_score = sum(p for e, p in results if e in NEUTRAL_EMOTIONS)

    print()
    print(f"  {section('EMOTIONAL VALENCE')}")
    print()
    print(f"  {'🟢 Positive':<14}  {pos_score*100:>5.1f}%  {bar(pos_score, 18, chr(27)+'[92m')}")
    print(f"  {'🔴 Negative':<14}  {neg_score*100:>5.1f}%  {bar(neg_score, 18, chr(27)+'[91m')}")
    print(f"  {'⚪ Neutral':<14}  {neu_score*100:>5.1f}%  {bar(neu_score, 18, chr(27)+'[90m')}")

    # ── AI Emotional Summary ─────────────────────────
    print()
    print(f"  {section('AI EMOTIONAL SUMMARY')}")
    print()

    summary = generate_summary(results, probs)

    # Highlight emotion words in the summary
    highlighted = summary
    for emotion, phrase in EMOTION_PHRASES.items():
        if phrase in highlighted:
            ec = "91" if emotion in NEGATIVE_EMOTIONS else \
                 "92" if emotion in POSITIVE_EMOTIONS else "93"
            highlighted = highlighted.replace(
                phrase, colored(phrase, f"1;{ec}")
            )

    wrap_print(highlighted, indent=4, width=WIDTH + 20)  # +20 for color codes

    print()
    print(divider("═"))
    print()

# ─────────────────────────────────────────────────────
#  INTERACTIVE LOOP
# ─────────────────────────────────────────────────────
def interactive_mode(tokenizer, model, le, device):
    print(divider("═"))
    print(colored(f"  {'Interactive Emotion Analysis Mode':^{WIDTH-2}}", "1;36"))
    print(divider("═"))
    print(f"  {'💬'} Type any text and press Enter to analyse.")
    print(f"  {'📋'} Type  {colored('batch', '96')}  to analyse multiple lines at once.")
    print(f"  {'🚪'} Type  {colored('quit', '96')}   to exit.")
    print(divider("─"))

    while True:
        try:
            print(colored("\n  > ", "1;36"), end="")
            user_input = input().strip()
        except (EOFError, KeyboardInterrupt):
            print(colored("\n\n  Goodbye! 👋\n", "1;36"))
            break

        if not user_input:
            continue

        if user_input.lower() in ("quit", "exit", "q"):
            print(colored("\n  Goodbye! 👋\n", "1;36"))
            break

        if user_input.lower() == "batch":
            print(f"  {colored('Batch Mode', '1;33')} — Enter one sentence per line.")
            print(f"  Leave a blank line when done.\n")
            texts = []
            while True:
                print(colored("  > ", "33"), end="")
                line = input().strip()
                if not line:
                    break
                texts.append(line)
            if not texts:
                print("  No input received.")
                continue
            for t in texts:
                results, probs = predict(t, tokenizer, model, le, device)
                display_result(t, results, probs)
            continue

        results, probs = predict(user_input, tokenizer, model, le, device)
        display_result(user_input, results, probs)

# ─────────────────────────────────────────────────────
#  ENTRY POINT
# ─────────────────────────────────────────────────────
if __name__ == "__main__":
    tokenizer, model, le, device = get_model()

    if len(sys.argv) > 1:
        text = " ".join(sys.argv[1:])
        results, probs = predict(text, tokenizer, model, le, device)
        display_result(text, results, probs)
    else:
        interactive_mode(tokenizer, model, le, device)
