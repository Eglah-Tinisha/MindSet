# MindSet – Feeling Translator Journal

MindSet is an AI-powered mobile journaling application developed as a final-year academic project. It allows users to write or record journal entries and uses artificial intelligence to analyse emotional content. The system combines text emotion recognition, speech emotion recognition, speech-to-text, and multimodal emotion analysis. Firebase is used for authentication and journal storage.

## Main Features
- User registration and login using Firebase Authentication
- Text-based journal entries
- Voice journal recording
- Text emotion recognition
- Speech emotion recognition
- Speech-to-text transcription
- Multimodal emotion analysis
- Emotion confidence and supporting insights
- Journal history and mood-related analytics
- Firebase Firestore storage
- Configurable AI API endpoint

## Project Structure
MindSet/
├── README.md
├── .gitignore
├── .gitattributes
├── run_mindset.bat
│
├── mindset/                       # Flutter mobile application
│   ├── android/
│   ├── ios/
│   ├── lib/
│   ├── test/
│   ├── firebase.json
│   ├── firestore.rules
│   ├── pubspec.yaml
│   └── pubspec.lock
│
└── understanding_ai/              # Python AI backend
    ├── api.py
    ├── requirements_api.txt
    ├── requirements_stt.txt
    ├── bert_model/
    ├── audio_emotion/
    │   ├── models/
    │   ├── requirements_audio.txt
    │   └── ...
    ├── multimodal/
    └── speech/


# Technologies Used
## Mobile Application
- Flutter
- Dart
- Firebase Authentication
- Cloud Firestore
- Flutter HTTP package
- Flutter audio recording package

## AI and Backend
- Python
- FastAPI
- Uvicorn
- PyTorch
- Hugging Face Transformers
- BERT-based text emotion recognition
- Wav2Vec2-based speech emotion recognition
- Faster-Whisper speech-to-text
- Scikit-learn
- Pandas
- NumPy
- Librosa / SoundFile
- Multimodal emotion fusion

## Prerequisites
Before running the project, install the following software:

1. Git
2. Git LFS
3. Flutter SDK
4. Android Studio and the Android SDK, or another supported Flutter device
5. Python
6. A code editor such as Visual Studio Code
7. Internet access for the first dependency installation and Firebase access

The Flutter project requires Dart SDK 3.12.x or a compatible Flutter version that provides it.

FFmpeg is recommended if speech-to-text needs to process formats such as M4A, WebM or MP3. The application attempts to record WAV audio first, so FFmpeg may not be necessary for normal WAV recordings.


## 1. Clone the Repository
Open PowerShell or Command Prompt and run:
git clone https://github.com/Eglah-Tinisha/MindSet.git
cd MindSet

Because large trained model files are stored using Git LFS, initialise LFS and download the model files:
git lfs install
git lfs pull

Do not continue until the LFS model files have finished downloading.


## 2. Check the Flutter Installation
Run:
flutter doctor

Resolve any required Android SDK or licence issues reported by Flutter.

To view available devices:
flutter devices

An Android emulator is the easiest option for local testing because the application is configured by default to communicate with the host computer through:
http://10.0.2.2:8000


## 3. Set Up the Python AI Environment
Move to the AI backend folder:
cd understanding_ai

Create a virtual environment:
python -m venv .venv

Activate it on Windows PowerShell:
.\.venv\Scripts\Activate.ps1


If PowerShell blocks activation, the environment can still be used directly through `.venv\Scripts\python.exe`, or the execution policy can be adjusted according to the institution's Windows configuration.

Upgrade pip:
python -m pip install --upgrade pip

Install the main API requirements:
pip install -r requirements_api.txt

Install the speech-emotion requirements:
pip install -r audio_emotion/requirements_audio.txt

Install the speech-to-text requirements:
pip install -r requirements_stt.txt


## 4. Start the AI API
Remain inside the `understanding_ai` folder and run:
python -m uvicorn api:app --reload --host 0.0.0.0

When the models have loaded, the API should be available locally.

API home:
http://127.0.0.1:8000/

API health check:
http://127.0.0.1:8000/health

Interactive FastAPI documentation:
http://127.0.0.1:8000/docs

The main endpoints include:
POST /predict
POST /analyze
POST /predict_audio
POST /predict_multimodal
GET  /health

The first startup can take longer because the AI models need to load into memory.


## 5. Install Flutter Dependencies
Open another terminal from the repository root and move into the Flutter application:
cd mindset

Run:
flutter pub get


## 6. Run the Flutter Application
## Android Emulator
Start an Android emulator from Android Studio or VS Code and run:
flutter run

The default text-emotion API endpoint is:
http://10.0.2.2:8000/predict

`10.0.2.2` is the Android emulator address used to access the host computer's localhost.


## Physical Android Device
Connect the Android phone to the computer using USB and enable Developer Options and USB Debugging.

Check that Flutter can see the device:
flutter devices

Then run:
flutter run

A physical phone cannot normally use `10.0.2.2` to access the computer. The phone must use an API address that it can reach.

Two options are available:

**Option A – Local network**
Run the API with:
python -m uvicorn api:app --host 0.0.0.0 --port 8000

Find the computer's local IPv4 address:
ipconfig

If, for example, the computer IP address is `192.168.1.20`, set the MindSet API endpoint in the application's Settings page to:
http://192.168.1.20:8000/predict

The phone and computer must be connected to the same network, and Windows Firewall must allow the connection.

**Option B – Cloudflare tunnel**
Cloudflare Tunnel may be used to expose the local FastAPI service to the phone. `cloudflared.exe` is intentionally excluded from this repository and must be installed separately.

After the API is running:
cloudflared tunnel --url http://localhost:8000

Cloudflare will provide an HTTPS tunnel address. In the MindSet Settings page, set the API endpoint to the tunnel address followed by `/predict`.

Example format:
https://YOUR-TUNNEL-ADDRESS/predict

The application derives the base URL from this setting for its multimodal voice endpoint.


## 7. Firebase
MindSet uses Firebase Authentication and Cloud Firestore.

The repository contains the Flutter Firebase configuration used by the project. Internet access is required for authentication and Firestore operations.

If Firebase access has been restricted or the original Firebase project is no longer available, a new Firebase project must be configured before authentication and cloud journal storage can operate.

## 8. Using the Application
After the backend and Flutter application are running:
1. Open MindSet.
2. Register a new account or log in.
3. Open the journal page.
4. Enter a written journal reflection or record a voice reflection.
5. Submit the entry for emotion analysis.
6. The Flutter application sends the entry to the local AI API.
7. For text entries, the text emotion model returns emotion information.
8. For voice entries, speech-to-text, speech-emotion analysis and multimodal processing are performed.
9. The result is displayed in the application.
10. Journal entries and associated results can be stored through Firebase.

## 9. Automatic Windows Launcher
A `run_mindset.bat` file is provided as a convenience for Windows.
Place `run_mindset.bat` in the repository root beside this README and double-click it, or run:
.\run_mindset.bat

The launcher:
- checks that Python and Flutter are installed;
- checks the expected project folders;
- creates `.venv` if it does not already exist;
- installs the Python requirements on first setup;
- runs `flutter pub get`;
- starts the FastAPI backend in a separate window;
- checks the API health endpoint;
- starts the Flutter application.

For an Android emulator, no additional API-address change should normally be required.

For a physical Android phone, configure the API endpoint in MindSet Settings using the computer's LAN address or a Cloudflare tunnel as explained above.

## 10. Manual Run Summary
Terminal 1 – AI API:
cd understanding_ai
.\.venv\Scripts\Activate.ps1
python -m uvicorn api:app --reload --host 0.0.0.0 --port 8000

Terminal 2 – Flutter application:
cd mindset
flutter pub get
flutter run

## Troubleshooting
## Git LFS model download fails
Run:
git lfs install
git lfs pull

If the error contains `lookup github.com: no such host`, check the computer's internet/DNS connection and retry.

## `faster_whisper` is unavailable
Install the STT requirements:
pip install -r requirements_stt.txt

Restart Uvicorn afterwards.

## Audio model is unavailable
Install the audio requirements:
pip install -r audio_emotion/requirements_audio.txt

Confirm that the trained Wav2Vec2 model files were successfully downloaded through Git LFS.

## `python-multipart` error
Install the audio requirements or run:
pip install python-multipart

## Flutter cannot reach the API
Check:
http://127.0.0.1:8000/health

If using an Android emulator, use `10.0.2.2`.

If using a physical Android phone, use the computer's reachable LAN IP or a Cloudflare tunnel and update the API endpoint in MindSet Settings.

## Microphone does not work
Grant microphone permission to MindSet. When using an Android emulator, enable the emulator's host microphone input from its extended microphone controls.

## API startup is slow
This is expected on systems using CPU inference because the text, audio and speech-to-text models may require time to load.


## Author
**Eglah Tinisha Kamalenthiran**
BSc (Hons) Computer Science and Software Engineering  
University of Bedfordshire


## Repository
MindSet  
GitHub: `Eglah-Tinisha/MindSet`
