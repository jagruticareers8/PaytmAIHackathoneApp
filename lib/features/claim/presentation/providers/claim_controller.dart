import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/security/pii_masker.dart';
import '../../../../core/storage/local_private_vault.dart';
import '../../data/claim_analysis_service.dart';
import '../../domain/models/claim_models.dart';

/// Creates the remote claim-analysis adapter for integrations that are explicitly
/// non-private. Personal documents use the encrypted local vault only.
ClaimAnalysisService createClaimAnalysisService() {
  const baseUrl = String.fromEnvironment(
    'SATHI_API_BASE_URL',
    defaultValue: '',
  );
  return ApiClaimAnalysisService(baseUrl: baseUrl);
}

/// BLoC/Cubit owner for claim workflow state. Private claim text and drafts are
/// persisted in an encrypted app-private vault; no network call occurs here for
/// documents, OCR, or claim analysis.
class ClaimCubit extends Cubit<ClaimState> {
  ClaimCubit(ClaimAnalysisService _, {LocalPrivateVault? vault})
    : _vault = vault ?? LocalPrivateVault(),
      super(ClaimState.empty()) {
    _ready = _restoreLocalState();
  }

  final LocalPrivateVault _vault;
  late final Future<void> _ready;

  Future<void> _restoreLocalState() async {
    try {
      final saved = await _vault.readSnapshot();
      final savedRows = saved['documents'];
      final restoredDocuments = <ClaimDocument>[];
      if (savedRows is List) {
        final seenIds = <String>{};
        for (final row in savedRows) {
          if (row is! Map || row['id'] is! String || row['uploaded'] != true) {
            continue;
          }
          final id = row['id'] as String;
          if (!seenIds.add(id)) continue;
          final fileName = (row['fileName'] ?? 'Document').toString();
          final uploadedAtText = row['uploadedAt'] as String?;
          final extractedText = row['extractedText'] as String?;
          restoredDocuments.add(
            ClaimDocument(
              id: id,
              title: (row['title'] ?? fileName).toString(),
              description: (row['description'] ?? 'Added from your phone')
                  .toString(),
              required: row['required'] == true,
              uploaded: true,
              fileName: fileName,
              uploadedAt: uploadedAtText == null
                  ? null
                  : DateTime.tryParse(uploadedAtText),
              // Never restore a temporary path from an earlier app session.
              localPath: null,
              extractedText: extractedText,
              storedLocally: row['storedLocally'] == true,
              readFailed:
                  row['readFailed'] == true ||
                  (extractedText ?? '').trim().isEmpty,
            ),
          );
        }
      }
      restoredDocuments.sort(
        (a, b) => (a.uploadedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(b.uploadedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );

      final restoredTimeline = <ClaimTimelineEvent>[];
      final savedTimeline = saved['timeline'];
      if (savedTimeline is List) {
        for (final row in savedTimeline) {
          if (row is! Map) continue;
          restoredTimeline.add(
            ClaimTimelineEvent(
              title: (row['title'] ?? '').toString(),
              description: (row['description'] ?? '').toString(),
              dateLabel: (row['dateLabel'] ?? '').toString(),
              done: row['done'] == true,
              isCurrent: row['isCurrent'] == true,
            ),
          );
        }
      }
      if (isClosed) return;
      emit(
        state.copyWith(
          documents: restoredDocuments,
          timeline: restoredTimeline,
          appealDraft: (saved['appealDraft'] ?? '').toString(),
          appealDraftTranslation: (saved['appealDraftTranslation'] ?? '')
              .toString(),
          reconsiderationMarkedSubmitted:
              saved['reconsiderationMarkedSubmitted'] == true,
        ),
      );
    } catch (_) {
      // Do not silently overwrite encrypted data if decryption fails. This
      // session remains usable but starts with empty in-memory state.
    }
  }

  Map<String, dynamic> _snapshotFor(ClaimState current) => {
    'version': 1,
    'documents': current.documents
        .map(
          (document) => <String, dynamic>{
            'id': document.id,
            'title': document.title,
            'description': document.description,
            'required': document.required,
            'uploaded': document.uploaded,
            'fileName': document.fileName,
            'uploadedAt': document.uploadedAt?.toIso8601String(),
            'storedLocally': document.storedLocally,
            // The OCR text is PII-masked before it reaches state and this
            // entire snapshot is encrypted by LocalPrivateVault.
            'extractedText': document.extractedText,
            'readFailed': document.readFailed,
          },
        )
        .toList(),
    'timeline': current.timeline
        .map(
          (event) => <String, dynamic>{
            'title': event.title,
            'description': event.description,
            'dateLabel': event.dateLabel,
            'done': event.done,
            'isCurrent': event.isCurrent,
          },
        )
        .toList(),
    'appealDraft': current.appealDraft,
    'appealDraftTranslation': current.appealDraftTranslation,
    'reconsiderationMarkedSubmitted': current.reconsiderationMarkedSubmitted,
  };

  Future<void> _persistLocalState() async {
    try {
      await _vault.mergeSnapshot(_snapshotFor(state));
    } catch (_) {
      // Do not log private text. UI state remains available for this session;
      // callers that must persist a selected attachment receive an explicit error.
    }
  }

  /// Saves a selected file from picker bytes. This works with Android/iOS
  /// content URIs and cloud-backed file providers where a stable path is not
  /// guaranteed. The original file is not modified.
  Future<void> attachDocumentBytes({
    required String id,
    required String fileName,
    required List<int> sourceBytes,
  }) async {
    await _ready;
    await _vault.saveAttachmentBytes(id: id, bytes: sourceBytes);

    final cleanName = fileName.split(RegExp(r'[/\\]')).last.trim();
    final safeName = cleanName.isEmpty ? 'Health document' : cleanName;
    final document = ClaimDocument(
      id: id,
      title: safeName,
      description: 'Added from your phone',
      required: false,
      uploaded: true,
      fileName: safeName,
      uploadedAt: DateTime.now(),
      localPath: null,
      storedLocally: true,
      readFailed: false,
    );
    final updated = [
      ...state.documents.where((item) => item.id != id),
      document,
    ];
    emit(
      state.copyWith(
        documents: updated,
        timeline: [
          ClaimTimelineEvent(
            title: 'Document added',
            description:
                'A copy of $safeName was saved privately on this phone.',
            dateLabel: 'Just now',
            done: true,
          ),
          ...state.timeline.map((event) => event.copyWith(isCurrent: false)),
        ],
        clearAnalysis: true,
        clearAnalysisError: true,
      ),
    );
    await _persistLocalState();
  }

  Future<void> markDocumentReadFailed(String id) async {
    await _ready;
    final updated = state.documents.map((document) {
      if (document.id != id) return document;
      return document.copyWith(readFailed: true, clearExtractedText: true);
    }).toList();
    emit(state.copyWith(documents: updated, clearAnalysis: true));
    await _persistLocalState();
  }

  /// Compatibility wrapper for callers that still have a readable file path.
  /// New picker flows should use [attachDocumentBytes], because picker paths can
  /// be temporary or unavailable for cloud-backed files.
  Future<void> attachDocument(
    String id,
    String fileName, {
    String? localPath,
  }) async {
    await _ready;
    if (localPath == null || localPath.trim().isEmpty) {
      throw StateError(
        'The selected file is no longer available. Please choose it again.',
      );
    }
    final file = File(localPath);
    if (!await file.exists()) {
      throw StateError(
        'The selected file is no longer available. Please choose it again.',
      );
    }
    await attachDocumentBytes(
      id: id,
      fileName: fileName,
      sourceBytes: await file.readAsBytes(),
    );
  }

  Future<void> removeDocument(String id) async {
    await _ready;
    await _vault.deleteAttachment(id);
    final updated = state.documents
        .where((document) => document.id != id)
        .toList();
    emit(state.copyWith(documents: updated, clearAnalysis: true));
    await _persistLocalState();
  }

  /// Returns a source path for on-device OCR. Persisted attachments are decrypted
  /// only into a temporary file; the calling screen must delete it in finally.
  Future<String?> pathForOnDeviceOcr(String id) async {
    await _ready;
    ClaimDocument? document;
    for (final item in state.documents) {
      if (item.id == id) {
        document = item;
        break;
      }
    }
    if (document == null) return null;
    final currentPath = document.localPath;
    if (currentPath != null && await File(currentPath).exists())
      return currentPath;
    if (!document.storedLocally || document.fileName == null) return null;
    return _vault.materializeAttachmentForOcr(
      id: id,
      fileName: document.fileName!,
    );
  }

  /// Save only PII-masked OCR text. The text is encrypted at rest and searchable
  /// locally even after the app is restarted.
  Future<void> saveExtractedText(String id, String maskedText) async {
    await _ready;
    final redacted = PiiMasker.mask(maskedText.trim());
    final updated = state.documents.map((document) {
      if (document.id != id) return document;
      return document.copyWith(extractedText: redacted, readFailed: false);
    }).toList();
    emit(state.copyWith(documents: updated, clearAnalysis: true));
    // Wait for the encrypted snapshot write before telling the user it was saved.
    await _persistLocalState();
  }

  /// Claim analysis is deliberately local-only. It reports which documents have
  /// readable local text; it does not upload OCR or ask a cloud model to inspect
  /// a private claim. This is a local completeness hint, not insurer verification.
  Future<void> analyzeClaim() async {
    await _ready;
    emit(state.copyWith(isAnalyzing: true, clearAnalysisError: true));
    try {
      final readable = state.documents
          .where((d) => (d.extractedText ?? '').trim().isNotEmpty)
          .toList();
      final noText = state.documents
          .where((d) => d.uploaded && (d.extractedText ?? '').trim().isEmpty)
          .map((d) => d.title)
          .toList();
      final result = ClaimAnalysis(
        summary: readable.isEmpty
            ? 'No readable document text was found yet. Add a clearer document and Sathi will try reading it again. No claim data was sent online.'
            : 'Sathi found readable text in ${readable.length} locally saved document(s). This is a local document-readiness check only; it does not verify coverage, claim status, or the insurer’s decision.',
        missingDocuments: noText,
        nextSteps: readable.isEmpty
            ? const [
                'Add a clear insurance letter or bill.',
                'Ask Sathi once the document is ready.',
              ]
            : const [
                'Search the saved document text for the insurer’s reason.',
                'Compare the stated reason with the supporting records.',
                'Confirm exact requirements with the insurer through its official channel.',
              ],
        disclaimer:
            'OFFLINE LOCAL CHECK · No OCR text or claim details were sent to a server. This is not a coverage decision or a guarantee of claim recovery.',
        evidenceUsed: readable.map((document) => document.title).toList(),
      );
      emit(state.copyWith(analysis: result, isAnalyzing: false));
    } catch (error) {
      emit(
        state.copyWith(
          isAnalyzing: false,
          analysisError:
              'Local document check failed. No document data was sent online. ${error.runtimeType}',
        ),
      );
    }
  }

  /// Erases the encrypted local vault and resets all app-owned personal data.
  /// This does not delete the original files in Photos/Downloads.
  Future<void> clearAllLocalData() async {
    await _ready;
    await _vault.clearAll();
    if (isClosed) return;
    emit(ClaimState.empty());
  }

  void saveDraft(String draft, {String translation = ''}) {
    emit(
      state.copyWith(appealDraft: draft, appealDraftTranslation: translation),
    );
    unawaited(_persistLocalState());
  }

  void saveDraftTranslation(String translation) {
    emit(state.copyWith(appealDraftTranslation: translation));
    unawaited(_persistLocalState());
  }

  void markReconsiderationSubmitted() {
    if (state.reconsiderationMarkedSubmitted) return;
    emit(
      state.copyWith(
        reconsiderationMarkedSubmitted: true,
        timeline: [
          const ClaimTimelineEvent(
            title: 'Reconsideration marked by you',
            description:
                'You recorded that you submitted the draft through the insurer’s official channel. Sathi has not sent it or verified receipt.',
            dateLabel: 'Just now',
            done: true,
            isCurrent: true,
          ),
          ...state.timeline.map((e) => e.copyWith(isCurrent: false)),
        ],
      ),
    );
    unawaited(_persistLocalState());
  }
}
