# Audio Emotion AI (Phase 1)

Speech emotion recognition (SER) for MindSet. This package trains and serves a
**Wav2Vec2** classifier over a **9-class audio label space**, separate from the
existing BERT **text** emotion model.

Text AI is unchanged. Multimodal fusion and Flutter mic UI are **later phases**.

## Label space (`audio_v1`)


Each prediction includes `text_compatible_map` so a future fusion engine can
project into the ~27-class text taxonomy.

## Setup

```bash
cd understanding_ai
pip install -r requirements_api.txt
pip install -r audio_emotion/requirements_audio.txt