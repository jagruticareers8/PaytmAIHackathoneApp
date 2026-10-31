# What was merged into the uploaded `dev_v3` branch

This archive is based on the uploaded `SathiCalimRecovery-dev_v3.zip`, with the previous local-first changes integrated into the actual project structure and native app folders preserved.

## Main code updates

- Added `lib/core/storage/local_private_vault.dart` for AES-GCM encrypted app-private attachments and state snapshot.
- Added `lib/features/claim/data/local_first_sathi_agent_service.dart` for local document retrieval, offline FAQ, personal-query blocking and optional general-information fallback.
- Updated `ClaimCubit` to copy attachments into the vault, save masked OCR text, persist local drafts/activity and perform local-only claim readiness checks.
- Updated document, assistant, privacy, claim, home, tracker and draft screens to use local-first behavior.
- Updated low-level Gemini client to send only confirmed general questions and no context/history; extended request timeout to 135 seconds.
- Updated FastAPI to reject private/claim context on the online endpoint and return HTTP 410 for legacy cloud claim analysis. Optional audio transcription has separate consent and confirmation gates.
- Set the sample model default to `gemini-3.6-flash`, matching the successful direct test reported for this project.
- Fixed `file_picker` usage to use `FilePicker.pickFile()` for the v13 package API.
- Added Android Internet/microphone/camera/speech-recognition declarations, debug-only cleartext HTTP for a local backend, Android minSdk floor, and iOS permission descriptions.
- Replaced the stale seeded-claim widget test with a test that confirms the initial claim state does not invent claim facts.
- Updated docs and CI to reflect the included native projects and real privacy boundary.

## Not a production insurance integration

This release does not retrieve live insurer records or submit claims, has no user authentication/tenant authorization, and does not include an on-device generative LLM. Offline answers use local retrieval, rules, and a built-in FAQ. Use synthetic data only in this hackathon build.
