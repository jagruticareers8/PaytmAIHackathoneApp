# Firebase and partner API setup — future integration

Firebase and partner APIs are shown in the pitch/architecture as future integration points. This source archive does not contain a Firebase project, provider credentials, insurer or TPA integration, nor live claim status.

## Firebase (future)

1. Create a Firebase project in your organisation account.
2. Run `dart pub global activate flutterfire_cli`, then `flutterfire configure`.
3. Add only the Firebase plugins required by the selected feature.
4. Initialise Firebase before `runApp` using generated `firebase_options.dart`.
5. Apply security rules, App Check where appropriate, authentication and per-user document/claim authorization.
6. Do not send medical records, OCR text, or decision-letter contents to Analytics.

## Partner services (future)

Use a backend adapter between Flutter and each insurer/TPA. Never put partner secrets or AI keys in the app. Keep sandbox/production environments separate. Authenticate the user, authorise access to a specific claim, verify consent and use event/reference IDs returned by the partner.

## Verified policy retrieval (future)

A real retrieval system must index approved policy versions with insurer, product, effective-date, page and section metadata. Citations must point to real retrieved excerpts. If retrieval is empty, Sathi must say it cannot verify the answer from the supplied source, not invent clause numbers.

## WebSocket events (future)

`ClaimUpdatesSocket` is only a helper for a future authenticated event channel. The current app does not connect to an insurer status feed. A future backend must authorize each claim subscription, use TLS, validate event schemas, and avoid raw sensitive content in logs.
