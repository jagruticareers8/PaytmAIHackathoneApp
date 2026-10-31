# Sathi — Local-first health-insurance claim companion

Sathi is a Flutter hackathon MVP for one focused journey: help a person organise a health-insurance decision letter, understand text they supplied, prepare an editable reconsideration draft, and keep a private record of their own next steps.

## Privacy design

**Private by default. Local first. Online only for a separate general-information question after confirmation.**

1. The user adds a document. Sathi copies it into its app-private vault and encrypts that copy with AES-GCM. The vault key is held in Android Keystore/iOS Keychain via `flutter_secure_storage`.
2. For supported images, OCR runs on-device with Google ML Kit. The extracted text is PII-masked and saved in the encrypted local vault. For PDFs, the user can paste text they extracted elsewhere; this archive does not include a PDF text-extraction engine.
3. Sathi searches local document text and an offline FAQ first. If the optional Qwen3 + EmbeddingGemma models have been downloaded, it also runs true on-device semantic RAG and answer generation. Without the model files, only local retrieval/rules/FAQ are available.
4. A question that appears personal or claim-specific remains local. If a generic question is not found locally and the user has enabled online lookup, Sathi shows a confirmation dialog with the exact question. Only that question is sent to the backend/Gemini. No files, OCR, claim context, document names, or chat history are attached.
5. Cloud voice transcription is optional and separately consented. It sends a short WAV to the configured backend for Gemini transcription only after the user chooses General information mode and confirms the upload. Do not speak personal medical/claim details during cloud transcription.
6. The reconsideration letter is a local editable draft. The tracker records actions made by the user on the device; it does not show verified insurer status.

## Implemented in this source tree

- Flutter + Dart + BLoC UI and state management.
- AES-GCM encrypted local vault for app-owned copies of attachments, masked OCR text, drafts and local activity.
- Local OCR for supported images using both Latin and Devanagari recognizers. PDFs require copy/paste of text from a PDF viewer.
- Local document search and offline insurance FAQ in English, Hindi and Roman Hinglish.
- Device speech input with locale detection and recovery UI.
- Optional confirmed online general-information answers through the Gemini backend.
- Optional separately consented Gemini audio transcription.
- Editable reconsideration draft, copy-to-clipboard, and a local activity tracker.
- Backend-side guard rejecting claim context, OCR text, filenames, and conversation history at the online general-information endpoint.
- Flutter and Python tests.

## Not implemented / not to be claimed in a demo

- No live insurer/TPA, hospital, policy, claims or grievance API.
- No claim submission, resubmission, escalation or live-status polling.
- No verified policy RAG, vector database, or insurer-approved clause retrieval.
- Optional on-device generation is supported by Qwen3 0.6B + EmbeddingGemma 2 Text 270M, downloaded by the user from How Sathi works. The source archive does not bundle their ~500 MB model files.
- No production authentication, tenant isolation, rate limiting, analytics consent framework, or production security audit.

## Project structure

```text
lib/
  core/
    security/         # PII masker and consent settings
    storage/          # AES-GCM local private vault
    services/         # on-device OCR and WebSocket example
  features/claim/
    data/              # local-first router, online general-info adapter
    domain/models/     # claim/document/timeline models
    presentation/
      pages/           # Home, Claim, Documents, Tracker, Draft, Assistant, Privacy
      providers/       # ClaimCubit and local persistence
backend/
  main.py              # FastAPI general-information and opt-in voice endpoints
  .env.example
  test_agent_rules.py
docs/
tests/
android/
ios/
```

## Requirements

- Flutter stable meeting `pubspec.yaml` (Flutter 3.44+ and Dart 3.12+ in this project).
- Python 3.11+ recommended for the backend.
- A Google AI Studio API key for optional online answers/transcription.
- Android Studio / Android SDK for Android builds. Xcode is required for iOS builds.

This archive includes the native Android/iOS project folders. Do not run `flutter create` unless one of those folders is missing.

## 1. Configure the backend

From the project root:

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
cp .env.example .env
```

Edit `backend/.env` and set your own API key. The default tested model name in this project is `gemini-3.6-flash`; update it only if your Google AI Studio account has access to a different model.

```env
GEMINI_API_KEY=YOUR_PRIVATE_KEY
GEMINI_MODEL=gemini-3.6-flash
GEMINI_TRANSCRIPTION_MODEL=gemini-3.5-transcribe
SATHI_ALLOWED_ORIGINS=*
SATHI_ALLOW_UNAUTHENTICATED_DEV=true
```

Keep the key in `backend/.env` only. Never paste it into Dart code or commit it to Git.

Start the backend from inside `backend/`:

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Check it from the Mac:

```bash
curl -s http://127.0.0.1:8000/health
```

The health response indicates whether a key is configured; it does not verify that Gemini is currently available. A live model call can still fail due to quota, service capacity, or API access.

## 2. Configure and run Flutter

Open a second terminal at the project root (the folder containing `pubspec.yaml`):

```bash
flutter pub get
flutter analyze
flutter test
```

For the **Android emulator** while the backend runs on your Mac:

```bash
flutter run \
  --dart-define=SATHI_API_BASE_URL=http://10.0.2.2:8000 \
  --dart-define=SATHI_ALLOW_UNAUTHENTICATED_DEV=true
```

For a **physical Android phone** on the same Wi-Fi, replace `10.0.2.2` with your Mac's LAN IP (for example `192.168.1.101`). The backend must remain running and the macOS firewall must permit the local connection.

The Android debug manifest enables cleartext HTTP only for local development. Use HTTPS and remove the local-development exception for a hosted or production backend. A non-debug/release build is not configured as a production service.

## 3. Use Sathi

1. Open **Documents** and attach a synthetic/test decision-letter image or another document.
2. Select **Read text on device** for supported image formats. Review the extracted text; do not use real medical documents in this hackathon build.
3. Open **Home → Sathi** and use **Private files** mode to search your saved local text or the offline FAQ. Personal questions do not go to the cloud.
4. Choose **General information** only for a generic question. If local search/FAQ cannot answer it and online lookup is enabled, review the exact-question confirmation before sending anything.
5. Review any draft in the **Draft** tab. Copy it and submit it yourself through the insurer's official channel if appropriate.
6. The **Track** tab records local actions only. It is not connected to the insurer.

## 4. Test

Run Flutter tests from the project root:

```bash
flutter test
```

Run backend tests from the project root after installing the requirements and activating the backend venv:

```bash
python -m unittest discover -s backend -v
```

Backend tests exercise intent classification and privacy filters without intentionally calling Gemini. This execution environment does not have the Flutter SDK or your Gemini credentials, so run the checks on your Mac before demoing.

## Security boundary

- The backend's `SATHI_ALLOW_UNAUTHENTICATED_DEV=true` switch is for short-lived local testing with synthetic data only. Never expose this backend publicly in that mode.
- PII masking is best effort, not comprehensive data-loss prevention. The safest rule is not to upload real health/identity/claim data during the hackathon.
- `flutter_secure_storage` protects the vault key; AES-GCM protects app-owned vault files at rest. This is not a substitute for a production threat model, secure backups, device lock, access control, retention/deletion policy, or security review.
- The operating system's own speech-recognition service may use network services according to device settings even when Sathi does not upload an audio file itself. The optional cloud transcription mode definitely sends audio off-device and is separately consented.
- No insurer lookup or claim submission is simulated. Sathi explains only user-provided text and general insurance concepts, and must not promise that a claim will be recovered.
