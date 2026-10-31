import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Runs OCR on local image files using the on-device ML Kit recognizers.
/// No document bytes or extracted text are uploaded by this service.
class OnDeviceOcrService {
  Future<OnDeviceOcrSession> openSession() async => OnDeviceOcrSession._();

  Future<String> readImageText(String imagePath) async {
    final session = await openSession();
    try {
      return await session.readImageText(imagePath);
    } finally {
      await session.close();
    }
  }
}

/// Reusable OCR session for multi-page documents. The recognizers are created
/// once per upload and released after the last page has been processed.
class OnDeviceOcrSession {
  OnDeviceOcrSession._()
      : _recognizers = [
    TextRecognizer(script: TextRecognitionScript.latin),
    TextRecognizer(script: TextRecognitionScript.devanagiri),
  ];

  final List<TextRecognizer> _recognizers;
  bool _closed = false;

  Future<String> readImageText(String imagePath) async {
    if (_closed) throw StateError('The document reader session is closed.');

    final image = InputImage.fromFilePath(imagePath);
    final outputs = <String>[];
    for (final recognizer in _recognizers) {
      try {
        final result = await recognizer.processImage(image);
        if (result.text.trim().isNotEmpty) outputs.add(result.text.trim());
      } catch (_) {
        // A recognizer can fail on an unsupported script or a particular page.
        // Keep text returned by the other recognizer.
      }
    }

    final seen = <String>{};
    final mergedLines = <String>[];
    for (final output in outputs) {
      for (final line in output.split(RegExp(r'\r?\n'))) {
        final cleaned = line.trim();
        if (cleaned.isEmpty) continue;
        final key = cleaned.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
        if (seen.add(key)) mergedLines.add(cleaned);
      }
    }
    return mergedLines.join('\n').trim();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final recognizer in _recognizers) {
      await recognizer.close();
    }
  }
}
