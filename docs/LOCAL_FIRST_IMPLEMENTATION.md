# Local-first implementation notes

## Data flow

```text
Selected file
  -> encrypted app-private attachment copy (AES-GCM)
  -> on-device OCR for supported images
  -> PII masking
  -> encrypted local snapshot
  -> local document search / offline FAQ
  -> answer stays on device

If local answer is absent:
  generic question only
  -> personal/sensitive heuristic check
  -> explicit confirmation showing exact question
  -> backend enforces no context/history
  -> Gemini answer for general information
```

## User control

- Cloud text preference defaults to off.
- Cloud voice preference is separate from cloud text and defaults to off.
- General-information mode is required before a generic online fallback.
- Each online question requires its own confirmation.
- Cloud voice requires confirmation before each audio recording is sent.
- Private mode never calls the Gemini chat endpoint.
- Local claim analysis never calls `/v1/claims/analyze`; that endpoint returns `410 Gone`.

## Known limitations

- PII masking does not identify every personal detail. A heuristic query filter can miss or over-block questions. The confirmation screen is not a perfect privacy classifier; the user must inspect the exact question.
- Device speech engines may process speech according to their own network settings.
- The app does not include a local generative LLM. Local document answers use keyword retrieval and rules/FAQ.
- Image OCR uses on-device ML Kit Latin and Devanagari recognizers. Android includes the Devanagari text-recognition dependency; iOS includes the Devanagari pod and targets iOS 15.5+. PDF OCR is not bundled.
- The local vault encrypts app-owned copies, but this does not encrypt the original file in Photos/Downloads, screenshots, OS backups, or files the user exported outside the app.
- No insurer/TPA API, real claim status or claim submission exists.
