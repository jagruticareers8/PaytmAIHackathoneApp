import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/on_device_document_reader.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sathi_card.dart';
import '../../domain/models/claim_models.dart';
import '../providers/claim_controller.dart';

/// A single-step document experience. The user chooses a PDF or photo once;
/// Sathi selects embedded-text extraction or on-device OCR automatically.
class DocumentsPage extends StatefulWidget {
  const DocumentsPage({
    super.key,
    this.autoPickRequest = 0,
    this.onDocumentsReady,
  });

  /// Incremented by Home/Claim so the native file picker opens immediately.
  final int autoPickRequest;
  final VoidCallback? onDocumentsReady;

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  static const int _maxFileBytes = 25 * 1024 * 1024;

  final OnDeviceDocumentReader _reader = OnDeviceDocumentReader();
  final ValueNotifier<String> _progressText = ValueNotifier<String>(
    'Sathi is reading your document…',
  );

  bool _isWorking = false;

  @override
  void didUpdateWidget(covariant DocumentsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoPickRequest != oldWidget.autoPickRequest &&
        widget.autoPickRequest > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isWorking) _addDocuments();
      });
    }
  }

  @override
  void dispose() {
    _progressText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final documents = context
        .watch<ClaimCubit>()
        .state
        .documents
        .where((document) => document.uploaded)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        Text(
          'YOUR DOCUMENTS',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.teal,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Your insurance documents',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Add a PDF or photo. Sathi will read it for you automatically.',
          style: TextStyle(color: AppColors.muted, height: 1.45),
        ),
        const SizedBox(height: 16),
        SathiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.add_to_drive_outlined,
                    color: AppColors.teal,
                    size: 23,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Add documents',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose one or more files. Sathi will do the rest.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 13),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isWorking ? null : _addDocuments,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(_isWorking ? 'Please wait…' : 'Add documents'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Your files',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 9),
        if (documents.isEmpty)
          SathiCard(
            child: Column(
              children: [
                Icon(
                  Icons.folder_open_outlined,
                  size: 34,
                  color: AppColors.teal.withValues(alpha: .75),
                ),
                const SizedBox(height: 8),
                const Text(
                  'No documents added yet',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Add a document and Sathi will read it automatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          )
        else
          ...documents.map(
                (document) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _documentCard(context, document),
            ),
          ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline_rounded, color: AppColors.teal, size: 19),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Your documents stay on this phone.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.tealDark,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _documentCard(BuildContext context, ClaimDocument document) {
    final isReady = (document.extractedText ?? '').trim().isNotEmpty;
    final isFailed = document.readFailed && !isReady;
    final icon = _iconFor(document.fileName ?? document.title);
    final statusText = isReady
        ? 'Ready to ask questions'
        : isFailed
        ? 'Couldn’t read this file'
        : 'Saved on this phone';

    return SathiCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isReady ? AppColors.greenBg : AppColors.page,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              isReady ? Icons.check_circle_outline : icon,
              color: isReady ? AppColors.green : AppColors.teal,
              size: 22,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      isReady
                          ? Icons.check_circle
                          : isFailed
                          ? Icons.info_outline
                          : Icons.lock_outline,
                      size: 14,
                      color: isReady
                          ? AppColors.green
                          : isFailed
                          ? AppColors.amber
                          : AppColors.muted,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: isReady
                              ? AppColors.green
                              : isFailed
                              ? AppColors.amber
                              : AppColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isFailed) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Try an unlocked PDF or a clearer photo.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove document',
            visualDensity: VisualDensity.compact,
            onPressed: _isWorking
                ? null
                : () => context.read<ClaimCubit>().removeDocument(document.id),
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.muted,
              size: 19,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String fileName) {
    if (fileName.toLowerCase().endsWith('.pdf')) {
      return Icons.picture_as_pdf_outlined;
    }
    return Icons.image_outlined;
  }

  Future<void> _addDocuments() async {
    if (_isWorking) return;
    setState(() => _isWorking = true);

    Future<void>? dialogFuture;
    var dialogOpened = false;
    var pickerCancelled = false;
    var readyCount = 0;
    var tooLargeCount = 0;
    var failedCount = 0;

    try {
      final selectedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
      );
      if (!mounted) return;
      if (selectedFiles.isEmpty) {
        pickerCancelled = true;
      } else {
        _progressText.value = 'Sathi is reading your documents…';
        dialogFuture = _showReadingDialog();
        dialogOpened = true;
        await Future<void>.delayed(const Duration(milliseconds: 80));

        final cubit = context.read<ClaimCubit>();
        for (var index = 0; index < selectedFiles.length; index++) {
          final selected = selectedFiles[index];
          final id = 'document_${DateTime.now().microsecondsSinceEpoch}_$index';
          var saved = false;

          try {
            final knownLength = selected.lengthSync();
            final fileLength = knownLength ?? await selected.length();
            if (fileLength != null && fileLength > _maxFileBytes) {
              tooLargeCount++;
              continue;
            }

            final bytes = await selected.readAsBytes();
            if (bytes.isEmpty) {
              failedCount++;
              continue;
            }
            if (bytes.length > _maxFileBytes) {
              tooLargeCount++;
              continue;
            }

            // Replacing a same-named file avoids duplicate entries when the
            // user reselects a clearer copy after a failed read.
            final duplicates = cubit.state.documents
                .where(
                  (document) =>
              document.fileName?.toLowerCase() ==
                  selected.name.toLowerCase(),
            )
                .map((document) => document.id)
                .toList();
            for (final duplicateId in duplicates) {
              await cubit.removeDocument(duplicateId);
            }

            await cubit.attachDocumentBytes(
              id: id,
              fileName: selected.name,
              sourceBytes: bytes,
            );
            saved = true;

            _progressText.value = selectedFiles.length == 1
                ? 'Sathi is reading your document…'
                : 'Reading document ${index + 1} of ${selectedFiles.length}…';

            final read = await _readSavedDocument(cubit, id);
            if (read) {
              readyCount++;
            } else {
              failedCount++;
            }
          } catch (_) {
            if (saved) {
              await cubit.markDocumentReadFailed(id);
            }
            failedCount++;
          }
        }
      }
    } catch (_) {
      failedCount++;
    } finally {
      if (dialogOpened && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        await dialogFuture;
      }
      if (mounted) setState(() => _isWorking = false);
    }

    if (!mounted || pickerCancelled) return;

    if (readyCount > 0 && failedCount == 0 && tooLargeCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your documents are ready. Ask Sathi your question.'),
        ),
      );
      widget.onDocumentsReady?.call();
      return;
    }

    if (readyCount > 0) {
      final message = tooLargeCount > 0
          ? '$readyCount documents ready. One file is too large to add.'
          : '$readyCount documents ready. Sathi could not read one file. Try a clearer copy.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      widget.onDocumentsReady?.call();
      return;
    }

    if (tooLargeCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'That file is too large. Please choose a file under 25 MB.',
          ),
        ),
      );
    } else if (failedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sathi couldn’t read that file. Try an unlocked PDF or a clearer photo.',
          ),
        ),
      );
    }
  }

  Future<bool> _readSavedDocument(ClaimCubit cubit, String documentId) async {
    String? temporaryPath;
    try {
      final path = await cubit.pathForOnDeviceOcr(documentId);
      if (path == null) {
        await cubit.markDocumentReadFailed(documentId);
        return false;
      }

      temporaryPath = path;
      final result = await _reader.readFile(
        path,
        onProgress: (completed, total) {
          if (total > 1) {
            _progressText.value =
            'Reading your document (page $completed of $total)…';
          }
        },
      );
      if (!result.hasReadableText) {
        await cubit.markDocumentReadFailed(documentId);
        return false;
      }

      await cubit.saveExtractedText(documentId, result.text);
      return true;
    } catch (_) {
      await cubit.markDocumentReadFailed(documentId);
      return false;
    } finally {
      if (temporaryPath != null) {
        try {
          final file = File(temporaryPath);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _showReadingDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: _progressText,
                  builder: (context, message, _) =>
                      Text(message, style: const TextStyle(height: 1.4)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
