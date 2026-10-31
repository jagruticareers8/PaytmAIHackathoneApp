# Sathi backend API contract

The Flutter app uses `SATHI_API_BASE_URL`. For Android emulator local development, the host Mac is normally reachable at `http://10.0.2.2:8000`; a physical phone must use the Mac's LAN IP and the same trusted Wi-Fi.

## `GET /health`

Returns whether the API key/model names are configured, which model is selected, whether transcription is configured, and whether the unauthenticated development flag is active. `modelConfigured=true` means only that a key is present—not that the provider is healthy or the model can currently generate.

## `POST /v1/agent/chat` — general-information fallback only

The app first searches the encrypted local vault and offline FAQ. If no local answer exists and the user has enabled online lookup, Sathi shows a confirmation with the exact question. The request contains the current question and language, with empty `claimContext` and `chatHistory`.

The backend independently rejects:
- non-empty claim context,
- non-empty chat history,
- obvious private/claim-specific questions or common identifiers,
- requests without explicit online-consent state.

No documents, OCR excerpts, file names, private drafts, or prior turns are accepted by this endpoint. Successful response fields include the answer, navigation metadata, mode and model. Provider failures return an HTTP error instead of a canned answer.

## `POST /v1/claims/analyze` — disabled

Returns HTTP 410. Private claim analysis is local only; legacy clients cannot use this route to upload OCR or claim text.

## `POST /v1/voice/transcribe`

Multipart WAV input is accepted only when `cloudConsent=true`, `query_mode=general_information`, and `confirmed_for_general_use=true`. The app separately asks for voice consent and per-recording confirmation. The audio is sent to the configured backend and Gemini; do not use this route for private claim or medical content.

## Not implemented

No insurer/TPA status API, claim submission/resubmission, authenticated customer account, verified policy RAG/vector search, Firebase auth, tenant isolation or production rate limiting is implemented. These require provider agreements, credentials, user/claim authorization and testing. Do not present this development backend as a production insurance service.
