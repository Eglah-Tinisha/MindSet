# Networking

## Flutter Networking
- `http` package posts reflection text to the local API.
- JSON request body: `{ "text": "<reflection>" }`
- Content type: `application/json`

## Error Handling
- Timeouts map to a user-friendly message.
- Non-2xx responses parse `detail` when present.
- Client connection failures tell the user to start the Uvicorn server.

## Endpoints
- Default inferred client endpoint: `http://10.0.2.2:8000/predict`
- Fallback endpoints:
  - `http://127.0.0.1:8000/predict`
  - `http://localhost:8000/predict`
  - `http://10.0.2.2:8000/predict`

## Local API
- `understanding_ai/api.py`
- `/predict`
- `/health`
- `/`

## Cloud / Firebase Networking
- Firebase Auth and Firestore use SDK-managed network calls.
- Android manifest allows internet access and cleartext traffic for local development.

