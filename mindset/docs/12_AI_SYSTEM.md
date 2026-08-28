# AI System

## Overview
The AI subsystem is a local BERT-based emotion classifier exposed through FastAPI.

## Components
- `understanding_ai/bert_train.py`: trains the classifier from CSV data
- `understanding_ai/bert_predict.py`: loads artifacts and performs inference
- `understanding_ai/api.py`: exposes the `/predict` HTTP endpoint
- `lib/services/emotion_analyzer.dart`: Flutter client for the API

## Model Artifacts
- `bert_model/` is expected as the trained model directory.
- Serialized files include:
  - tokenizer files
  - model weights
  - `label_encoder.pkl`
  - `config.json`

## Inputs
- Raw text reflection
- In the Flutter app, transcript text is treated the same as typed reflections

## Outputs
- Primary emotion
- confidence and confidence percent
- confidence label
- certainty score
- entropy
- generated summary
- top emotion list
- valence breakdown

## Preprocessing
- Input text is trimmed.
- Tokenization uses `BertTokenizerFast`.
- Maximum sequence length is 128 in training and inference.

## Inference
- `predict_emotion()` loads the cached model.
- Softmax probabilities are computed.
- Top-K emotions are produced.
- Valence is computed by emotion grouping.

## Runtime
- Flutter defaults to `http://10.0.2.2:8000/analyze` in settings, while the client fallback list targets `/predict` on localhost and emulator addresses.
- `api.py` currently exposes `/predict`, `/health`, and `/`.

## Important Inference
- The Flutter client expects a JSON shape that can tolerate both `primary_emotion` style fields and simpler emotion fields, so the client is somewhat defensive about the API response.

