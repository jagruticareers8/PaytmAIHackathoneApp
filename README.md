# Sathi — Local-first health-insurance claim companion

Sathi is a Flutter hackathon MVP for one focused journey: help a person organise a health-insurance decision letter, understand text they supplied, prepare an editable reconsideration draft, and keep a private record of their own next steps.

## Privacy design

**Private by default. Local first. Online only for a separate general-information question after confirmation.**

1. The user adds a document. Sathi copies it into its app-private vault and encrypts that copy with AES-GCM. The vault key is held in Android Keystore/iOS Keychain via `flutter_secure_storage`.
2. For supported images, OCR runs on-device with Google ML Kit Latin and Devanagari recognizers. The extracted text is PII-masked and saved in the encrypted local vault. For PDFs, the user can paste text they extracted elsewhere; this archive does not include a PDF text-extraction engine.
3. Sathi performs local-first retrieval. The built-in FAQ and deterministic fact extractor work without downloadable models. If the user chooses **How Sathi works → Download offline AI models**, Sathi installs Qwen3 0.6B for on-device answer generation and EmbeddingGemma 2 Text 270M for semantic retrieval. Saved OCR chunks are embedded and retrieved locally, their vectors are kept in the encrypted vault, and answers are generated on-device. After the one-time model download, this RAG path works offline.
4. A question that appears personal or claim-specific remains local. If the local evidence does not answer a personal question, Sathi abstains. If a generic question is not answered by local retrieval/knowledge and the user has enabled online lookup, Sathi shows a confirmation dialog with the exact question. Only that question is sent to backend/Gemini. No files, OCR, claim context, document names, or chat history are attached.
5. Cloud voice transcription is optional and separately consented. It sends a short WAV to the configured backend for Gemini transcription only after the user chooses General information mode and confirms the upload. Do not speak personal medical/claim details during cloud transcription.
6. The reconsideration letter is a local editable draft. The tracker records actions made by the user on the device; it does not show verified insurer status.

## Implemented in this source tree

- Flutter + Dart + BLoC UI and state management.
- AES-GCM encrypted local vault for app-owned copies of attachments, masked OCR text, drafts and local activity.
- On-device OCR for supported images using Latin and Devanagari recognizers. The iOS Devanagari pod requires iOS 15.5+; PDFs still use local copy/paste text extraction.
- Local document search and offline insurance FAQ in English, Hindi and Roman Hinglish.
- Optional on-device generative RAG: Qwen3 0.6B + EmbeddingGemma 2 Text 270M, installed from public Apache-2.0 model repositories after the user taps the download button.
- Encrypted local semantic vector cache and evidence-grounded prompts for on-device Q&A.
- Device speech input with locale detection and recovery UI.
- Optional confirmed online general-information answers through the Gemini backend.
- Optional separately consented Gemini audio transcription.
- Editable reconsideration draft, copy-to-clipboard, and a local activity tracker.
- Backend-side guard rejecting claim context, OCR text, filenames, and conversation history at the online general-information endpoint.
- Flutter and Python tests.

## Not implemented / not to be claimed in a demo

- No live insurer/TPA, hospital, policy, claims or grievance API.
- No claim submission, resubmission, escalation or live-status polling.
- No official policy corpus or insurer-approved clause retrieval is bundled. On-device RAG only retrieves the user's own saved documents plus a small general guide.
- The on-device model files are downloaded only after user action; they are not bundled in the app archive. The initial combined download is about 500 MB. Offline generation quality is limited by Qwen3 0.6B and should be tested on target phones.
- No production authentication, tenant isolation, rate limiting, analytics consent framework, or production security audit.

## UI robustness

The shared button theme uses finite minimum widths (`Size(0, height)`) to prevent the previous `BoxConstraints forces an infinite width` layout assertion when buttons appear in rows. `test/app_theme_layout_test.dart` protects this regression. The Home page has one simple entry flow and the Documents page does not count optional document categories as mandatory progress.

## Final implementation specification

Read [`SATHI_FINAL_SPECIFICATION.md`](SATHI_FINAL_SPECIFICATION.md) for the final feature boundaries, simple user flow, error handling, platform requirements, and acceptance checklist.

## Project structure

```text
lib/
  core/
    security/         # PII masker and consent settings
    storage/          # AES-GCM local private vault
    services/         # on-device OCR and WebSocket example
  features/claim/
    data/              # local-first router, on-device semantic RAG, online general-info adapter
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

This archive includes the native Android/iOS project folders. Do not run `flutter create` unless one of those folders is missing. For iOS, the Podfile and Xcode deployment target are set to 15.5 for the Devanagari OCR dependency. After pulling this version, run `flutter clean`, `flutter pub get`, and (if CocoaPods reports stale state) `cd ios && pod install && cd ..`.

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

## 3. Install the optional offline RAG models

Open **How Sathi works → Download offline AI models** while connected to Wi-Fi and with about 1 GB of free space available. The app downloads two public model files (approximately 329 MB for Qwen3 0.6B and 165 MB for EmbeddingGemma 2 Text 270M). The download is opt-in and progress is shown in the app. Model weights are installed in the platform's app-managed model storage and are not copied into the repository.

After installation:

- Sathi embeds document chunks and the user's question on-device, ranks chunks with cosine similarity, and generates a grounded answer using the retrieved evidence.
- The encrypted vault stores cached embeddings; normal claim-state writes preserve that cache.
- User documents, query text, embedding vectors and on-device prompts do not go to Gemini from this RAG path.
- If evidence does not match, Sathi should say it could not find the answer. A separate general-information fallback may use Gemini only after the user has enabled online general lookup and confirms the exact question. Private questions never fall back to cloud.

The model itself is not fine-tuned on user data. Personalization comes from retrieving the particular user's saved document passages at query time. The on-device model is compact and can make mistakes; cite retrieved evidence and verify policy decisions with the insurer.

### Platform requirements for LiteRT-LM

- Android: the on-device LiteRT-LM package requires `minSdk` 30 and `arm64-v8a`; the project has been raised to Android API 30 minimum. Some x86_64 emulators can run the app and local FAQ but cannot run the local LLM runtime.
- iOS: minimum iOS 15.5 because the Devanagari OCR pod requires it; the Podfile uses static framework linkage. Large on-device models may require the current LiteRT-LM memory entitlements and appropriate Apple signing/provisioning. Validate on a real iPhone before promising offline generation on iOS.
- Native model packages download their runtime during Flutter's native-asset build hooks, so run `flutter clean` and `flutter pub get` if the native library is stale after a dependency upgrade.

Model pages: [Qwen3 0.6B LiteRT-LM](https://huggingface.co/litert-community/Qwen3-0.6B) and [EmbeddingGemma 2 Text 270M LiteRT-LM](https://huggingface.co/litert-community/embeddinggemma-2-text-270m-litert-lm). Both model cards list Apache-2.0 licensing; review their terms and include required notices before distribution.

## 4. Use Sathi

1. Open **Documents** and attach a synthetic/test decision-letter image or another document.
2. Select **Read text on device** for supported image formats. Review the extracted text; do not use real medical documents in this hackathon build.
3. Open **Home → Sathi** and use **Private files** mode to search your saved local text or the offline FAQ. Personal questions do not go to the cloud.
4. Choose **General information** only for a generic question. If local search/FAQ cannot answer it and online lookup is enabled, review the exact-question confirmation before sending anything.
5. Review any draft in the **Draft** tab. Copy it and submit it yourself through the insurer's official channel if appropriate.
6. The **Track** tab records local actions only. It is not connected to the insurer.

## 5. Test

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


## Local document fact answers (amounts)

The local-first assistant now checks labelled amounts in the full saved OCR text before returning generic snippets. Example questions include “Mera claim kitne ka tha?”, “Kitna amount approve hua?”, and “Kitna pending hai?”. The response is generated on-device from stored OCR text and labels the answer as local document evidence—not a live insurer record. A new regression test is in `test/local_first_document_amount_test.dart`.
## Local document Q&A

Sathi uses local OCR text retrieval and structured fact extraction for private claim questions. It supports a range of English/Hinglish/Hindi phrasings, creates overlapping OCR text windows, and returns relevant evidence for questions about claim amounts, status, reason wording, documents, deadlines, policy references, hospital, dates, treatment, coverage and next steps. It does not fine-tune a model on personal documents. See [`docs/LOCAL_DOCUMENT_QA.md`](docs/LOCAL_DOCUMENT_QA.md) for the privacy boundary, current limits and tests.

