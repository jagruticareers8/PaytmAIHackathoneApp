# Sathi implementation status

| Capability | Status | Notes |
|---|---|---|
| Flutter UI / BLoC | Implemented | Home, Claim, Documents, Tracker, Draft, Assistant and Privacy screens. No seeded claim amounts/status/rejection reason. |
| Encrypted local vault | Implemented | AES-GCM encrypted attachments and encrypted JSON snapshot; vault key stored via platform secure storage. |
| On-device OCR | Implemented for supported images | Google ML Kit Latin + Devanagari recognizers for supported images; PDF OCR is not bundled and currently uses local copy/paste text extraction. OCR text is masked and saved locally. |
| Local document Q&A | Implemented | Exact labelled fact extraction plus semantic local RAG using EmbeddingGemma 2 and on-device Qwen3 0.6B after the user downloads both models. |
| Offline insurance FAQ | Implemented | Fixed general definitions/checklists in English, Hindi and Roman Hinglish. |
| Editable reconsideration draft | Implemented locally | Template grounded in local excerpts/placeholders; user must review and submit manually. |
| Live general-information AI | Implemented behind backend config | Gemini 3.6 Flash default, only after local lookup and explicit per-question confirmation. Private query/document text is not sent. |
| Hinglish device voice | Available | Uses OS speech service. Accuracy and installed locales vary. |
| Cloud voice transcription | Optional | Sends short audio to Gemini only after voice consent, General-information mode and per-recording confirmation. |
| Live claim-text cloud analysis | Disabled | `/v1/claims/analyze` returns HTTP 410 to protect private claim text. |
| Live insurer/TPA status | Not implemented | Requires authenticated partner API. |
| Claim submission/resubmission/escalation | Not implemented | The app prepares/copies a draft only. |
| On-device semantic RAG | Implemented after model download | Embeds saved OCR chunks, retrieves relevant local passages and generates a local answer with source labels. The built-in guide is not a verified insurer policy corpus. |
| On-device generative LLM | Optional download | Qwen3 0.6B `.litertlm` model and EmbeddingGemma 2 Text 270M `.litertlm` model are downloaded after user action; not bundled in source ZIP. |
| Production authentication/operations | Not implemented | No Firebase/OIDC login, tenant isolation, production rate limits, audit framework or security review. |

## Privacy boundary

Sathi checks exact local fields first, then runs semantic RAG on local OCR/document text and the offline guide when both optional on-device models are installed. An obvious personal/claim-specific question remains local. When an unanswered generic question may go online, the user sees the exact text and confirms it. The HTTP adapter sends only the current general question; the backend rejects non-empty context/history and obvious personal queries. Cloud voice is a separate opt-in because the audio itself leaves the device.

A Gemini answer is not insurer verification. Never claim that a claim status was checked, a letter was submitted, a policy clause is verified, or recovery is guaranteed unless a future authenticated partner integration actually performs that operation.

## On-device RAG lifecycle

The language and embedding models are downloaded on demand in **How Sathi works**. Once installed, document embeddings and generation run on the device. The encrypted vault stores a bounded semantic embedding cache while ordinary claim-state writes preserve it. See [ON_DEVICE_LLM.md](ON_DEVICE_LLM.md) for model URLs, platform requirements and the offline validation procedure.
