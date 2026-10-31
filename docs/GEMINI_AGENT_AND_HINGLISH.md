# Gemini agent and Hinglish voice

## General information text assistant

`SathiAgentService.ask()` is a low-level online adapter for general information only. The `LocalFirstSathiAgentService` checks the encrypted local document vault and built-in offline FAQ first. If no local answer exists, the question is non-personal, the user has enabled online lookup, and the user confirms the exact question, Sathi sends only that question to Gemini.

No OCR, filenames, attachments, `claimContext` or previous chat turns are sent. The backend enforces the same boundary and disables the old claim-analysis route.

## Private document workflow

The claim-specific workflow stays local:
- Add a document and copy it into Sathi's AES-GCM encrypted app-private vault.
- Run on-device image OCR and mask common identifiers before storing OCR text.
- Retrieve relevant local sentences by keyword matching.
- Prepare a template-based editable reconsideration draft from locally retrieved excerpts.
- Record app actions locally. The tracker does not represent insurer status.

When the optional on-device models are installed, Sathi also uses EmbeddingGemma 2 for local semantic retrieval and Qwen3 0.6B for offline answer generation. Without those user-downloaded model files, the app uses local retrieval + rules + a small fixed FAQ. PDF text extraction is not bundled; use image OCR for supported images or the paste-text path for text obtained elsewhere.

## Hinglish voice

- Device speech recognition is the default; locale availability and Hinglish accuracy vary by OS/provider.
- Optional cloud Hinglish transcription requires separate voice consent, online-information consent, General information mode and confirmation before each recording. The audio itself leaves the device and is sent to the backend/Gemini for transcription.
- The user reviews the transcript before tapping **Help me with this**. Speech transcription and answering are separate steps.
- Never record a private claim question for cloud transcription.

## Truth and production boundaries

Sathi has no insurer, TPA, hospital, claim portal or payment integration. It must not invent live status, coverage, amounts, receipts or claim recovery. The local development backend has no production authentication; set `SATHI_ALLOW_UNAUTHENTICATED_DEV=true` only for synthetic local testing. Before any real-customer pilot, add authentication, per-user authorization, secrets management, rate limits, retention/deletion controls, privacy review and security testing.


## On-device RAG

When downloaded, Qwen3 0.6B and EmbeddingGemma 2 provide a local generative RAG path. Local model errors are shown honestly and do not trigger a cloud retry with private text. See [ON_DEVICE_LLM.md](ON_DEVICE_LLM.md).
