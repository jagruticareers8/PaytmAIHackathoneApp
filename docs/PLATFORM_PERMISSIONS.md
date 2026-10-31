# Android and iOS configuration

This archive includes Android and iOS runner folders. Permissions for the Sathi camera, microphone, network and speech recognizer are merged into the native projects.

## Android

`android/app/src/main/AndroidManifest.xml` includes:

- `INTERNET` for API calls and the OS speech service
- `RECORD_AUDIO` for voice input
- `CAMERA` for taking a document photo
- a `RecognitionService` query for speech recognizer discovery

`android/app/src/debug/AndroidManifest.xml` allows cleartext HTTP **only in debug builds** so a local Flutter run can reach a development backend. The release manifest should use HTTPS. Do not deploy a public backend with `SATHI_ALLOW_UNAUTHENTICATED_DEV=true`.

The build file sets `minSdk` to at least 24 to match the current `flutter_secure_storage` v11 requirements. Check this if you downgrade the dependency.

If speech recognition returns `error.no.match`, it means the device recognizer could not transcribe the phrase; it does not necessarily mean Sathi or Gemini is broken. Confirm microphone permission and speech service/language availability. Accuracy for Roman-script Hinglish varies by device.

## iOS

`ios/Runner/Info.plist` includes usage descriptions for microphone, speech recognition, camera, and the photo library.

The project uses local HTTP endpoints only for local development. Use an HTTPS backend for real-device testing beyond a trusted local network. Do not add broad App Transport Security exceptions to a release build.

## Privacy modes

- **Private files:** Sathi searches locally and uses device speech recognition. Sathi itself does not upload the current question, OCR text, filenames, documents, or conversation history. The OS speech service may have its own network behaviour depending on device settings.
- **General information:** Sathi checks local documents and the offline FAQ first. For an unanswered generic question, it shows a confirmation dialog and sends only the displayed question to Gemini.
- **Cloud voice transcription:** Separate voice consent + General information mode + a per-recording warning are required. The audio leaves the device for transcription. Never use this with a private claim question.
