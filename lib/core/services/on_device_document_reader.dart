import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as image_lib;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import 'on_device_ocr_service.dart';

typedef DocumentReadProgress =
void Function(int completedPages, int totalPages);

class DocumentReadResult {
  const DocumentReadResult({
    required this.text,
    required this.pageCount,
    required this.ocrPageCount,
    required this.isPdf,
  });

  final String text;
  final int pageCount;
  final int ocrPageCount;
  final bool isPdf;

  bool get hasReadableText => text.trim().isNotEmpty;
}

/// Reads PDFs and supported images entirely on this device.
///
/// Digital PDFs use their embedded text layer. Scanned/low-text PDF pages are
/// rendered locally and sent to the existing ML Kit recognizers. The input path
/// should point to a short-lived decrypted file in the app's private cache; the
/// caller is responsible for deleting that file after this method completes.
class OnDeviceDocumentReader {
  OnDeviceDocumentReader({OnDeviceOcrService? ocrService})
      : _ocrService = ocrService ?? OnDeviceOcrService();

  final OnDeviceOcrService _ocrService;
  static Future<void>? _pdfInitialization;

  static bool isPdfPath(String path) =>
      path.toLowerCase().trim().endsWith('.pdf');

  Future<DocumentReadResult> readFile(
      String path, {
        DocumentReadProgress? onProgress,
      }) async {
    if (!await File(path).exists()) {
      throw FileSystemException('The selected document is not available.');
    }

    if (isPdfPath(path)) {
      return _readPdf(path, onProgress: onProgress);
    }

    final text = await _ocrService.readImageText(path);
    onProgress?.call(1, 1);
    return DocumentReadResult(
      text: text.trim().isEmpty ? '' : '[Page 1]\n${text.trim()}',
      pageCount: 1,
      ocrPageCount: 1,
      isPdf: false,
    );
  }

  Future<DocumentReadResult> _readPdf(
      String path, {
        DocumentReadProgress? onProgress,
      }) async {
    await _ensurePdfInitialized();
    final document = await PdfDocument.openFile(path);
    OnDeviceOcrSession? ocrSession;
    final pageTexts = <String>[];
    var pagesNeedingOcr = 0;
    var totalPages = 0;

    try {
      final pages = document.pages;
      totalPages = pages.length;
      if (totalPages == 0) {
        throw const FormatException('This PDF has no pages.');
      }

      final temporaryDirectory = await getTemporaryDirectory();
      for (var index = 0; index < totalPages; index++) {
        final page = pages[index];
        var pageText = '';

        // Native PDF text is more accurate than OCR for printed amounts/dates.
        try {
          pageText = (await page.loadText())?.fullText.trim() ?? '';
        } catch (_) {
          // Continue with on-device OCR if embedded text cannot be read.
        }

        if (_needsOcr(pageText)) {
          pagesNeedingOcr++;
          PdfImage? renderedPage;
          File? temporaryPng;
          try {
            final pageWidth = page.width <= 0 ? 1.0 : page.width;
            final pageHeight = page.height <= 0 ? 1.0 : page.height;
            final targetWidth = math
                .min(1600.0, math.max(1100.0, pageWidth * 2.0))
                .toDouble();
            final targetHeight = math
                .min(2400.0, targetWidth * pageHeight / pageWidth)
                .toDouble();

            renderedPage = await page.render(
              fullWidth: targetWidth,
              fullHeight: targetHeight,
              backgroundColor: 0xFFFFFFFF,
            );

            if (renderedPage != null) {
              final raster = renderedPage.createImageNF(
                pixelSizeThreshold: 2200,
              );
              final pngBytes = image_lib.encodePng(raster);
              temporaryPng = File(
                '${temporaryDirectory.path}/sathi_pdf_${DateTime.now().microsecondsSinceEpoch}_$index.png',
              );
              await temporaryPng.writeAsBytes(pngBytes, flush: true);
              ocrSession ??= await _ocrService.openSession();
              final imageText = await ocrSession.readImageText(
                temporaryPng.path,
              );
              pageText = _mergePageText(pageText, imageText);
            }
          } catch (_) {
            // Keep any embedded text already recovered and continue with the
            // next page. A single malformed page should not discard the PDF.
          } finally {
            if (temporaryPng != null && await temporaryPng.exists()) {
              try {
                await temporaryPng.delete();
              } catch (_) {}
            }
            renderedPage?.dispose();
          }
        }

        if (pageText.trim().isNotEmpty) {
          pageTexts.add('[Page ${index + 1}]\n${pageText.trim()}');
        }
        onProgress?.call(index + 1, totalPages);
      }
    } finally {
      await ocrSession?.close();
      await document.dispose();
    }

    return DocumentReadResult(
      text: pageTexts.join('\n\n').trim(),
      pageCount: totalPages,
      ocrPageCount: pagesNeedingOcr,
      isPdf: true,
    );
  }

  Future<void> _ensurePdfInitialized() {
    final current = _pdfInitialization;
    if (current != null) return current;

    final initialization = pdfrxFlutterInitialize();
    _pdfInitialization = initialization;
    return initialization.catchError((Object error) {
      _pdfInitialization = null;
      throw error;
    });
  }

  static bool _needsOcr(String text) {
    final value = text.trim();
    if (value.isEmpty) return true;
    final wordCount = RegExp(r'\S+').allMatches(value).length;
    return value.length < 70 || wordCount < 8;
  }

  static String _mergePageText(String embeddedText, String imageText) {
    final seen = <String>{};
    final lines = <String>[];
    for (final source in [embeddedText, imageText]) {
      for (final line in source.split(RegExp(r'\r?\n'))) {
        final value = line.trim();
        if (value.isEmpty) continue;
        // Preserve Unicode text (including Devanagari). Removing everything
        // outside ASCII letters would silently discard Hindi OCR output.
        final key = value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
        if (seen.add(key)) lines.add(value);
      }
    }
    return lines.join('\n').trim();
  }
}
