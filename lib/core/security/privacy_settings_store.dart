import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores only a local consent preference. Do not treat this as authentication
/// or as a substitute for server-side consent verification.
class PrivacySettingsStore {
  PrivacySettingsStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _cloudConsentKey = 'sathi_allow_redacted_cloud_analysis';
  static const _voiceConsentKey = 'sathi_allow_cloud_voice_transcription';
  final FlutterSecureStorage _storage;

  Future<bool> readCloudConsent() async =>
      (await _storage.read(key: _cloudConsentKey)) == 'true';

  Future<void> writeCloudConsent(bool enabled) =>
      _storage.write(key: _cloudConsentKey, value: enabled.toString());

  /// Separate explicit consent: audio can contain more sensitive data than text.
  Future<bool> readVoiceConsent() async =>
      (await _storage.read(key: _voiceConsentKey)) == 'true';

  Future<void> writeVoiceConsent(bool enabled) =>
      _storage.write(key: _voiceConsentKey, value: enabled.toString());
}
