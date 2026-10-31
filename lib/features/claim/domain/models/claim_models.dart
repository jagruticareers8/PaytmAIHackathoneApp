class ClaimDocument {
  const ClaimDocument({
    required this.id,
    required this.title,
    required this.description,
    required this.required,
    this.uploaded = false,
    this.fileName,
    this.uploadedAt,
    this.localPath,
    this.extractedText,
    this.storedLocally = false,
    this.readFailed = false,
  });

  final String id;
  final String title;
  final String description;
  final bool required;
  final bool uploaded;
  final String? fileName;
  final DateTime? uploadedAt;

  /// Ephemeral on-device path. The file itself is not sent by the assistant.
  final String? localPath;

  /// PII-masked OCR text retained for encrypted on-device storage and local search.
  /// This text is never attached to an online general-information request.
  final String? extractedText;

  /// True when an encrypted app-private copy is stored in Sathi local vault.
  final bool storedLocally;

  /// True when Sathi could not read enough text from this document.
  final bool readFailed;

  ClaimDocument copyWith({
    bool? uploaded,
    String? fileName,
    DateTime? uploadedAt,
    String? localPath,
    String? extractedText,
    bool? storedLocally,
    bool? readFailed,
    bool clearLocalPath = false,
    bool clearExtractedText = false,
    bool clearAttachment = false,
  }) {
    return ClaimDocument(
      id: id,
      title: title,
      description: description,
      required: required,
      uploaded: uploaded ?? this.uploaded,
      fileName: clearAttachment ? null : (fileName ?? this.fileName),
      uploadedAt: clearAttachment ? null : (uploadedAt ?? this.uploadedAt),
      localPath: clearAttachment
          ? null
          : (clearLocalPath ? localPath : (localPath ?? this.localPath)),
      extractedText: clearAttachment || clearExtractedText
          ? null
          : (extractedText ?? this.extractedText),
      storedLocally: clearAttachment
          ? false
          : (storedLocally ?? this.storedLocally),
      readFailed: clearAttachment ? false : (readFailed ?? this.readFailed),
    );
  }
}

class ClaimTimelineEvent {
  const ClaimTimelineEvent({
    required this.title,
    required this.description,
    required this.dateLabel,
    required this.done,
    this.isCurrent = false,
  });

  final String title;
  final String description;
  final String dateLabel;
  final bool done;
  final bool isCurrent;

  ClaimTimelineEvent copyWith({
    String? title,
    String? description,
    String? dateLabel,
    bool? done,
    bool? isCurrent,
  }) {
    return ClaimTimelineEvent(
      title: title ?? this.title,
      description: description ?? this.description,
      dateLabel: dateLabel ?? this.dateLabel,
      done: done ?? this.done,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }
}

class ClaimCitation {
  const ClaimCitation({
    required this.sourceTitle,
    required this.section,
    required this.excerpt,
    this.page,
  });

  final String sourceTitle;
  final String section;
  final String excerpt;
  final int? page;

  factory ClaimCitation.fromJson(Map<String, dynamic> json) => ClaimCitation(
    sourceTitle: json['sourceTitle'] as String? ?? 'Source document',
    section: json['section'] as String? ?? 'Unspecified section',
    excerpt: json['excerpt'] as String? ?? '',
    page: json['page'] is int ? json['page'] as int : null,
  );
}

class ClaimAnalysis {
  const ClaimAnalysis({
    required this.summary,
    required this.missingDocuments,
    required this.nextSteps,
    required this.disclaimer,
    this.citations = const [],
    this.evidenceUsed = const [],
  });

  final String summary;
  final List<String> missingDocuments;
  final List<String> nextSteps;
  final String disclaimer;
  final List<ClaimCitation> citations;

  /// Evidence excerpts/documents the model says it used. These are user-provided,
  /// not verified insurer sources.
  final List<String> evidenceUsed;

  factory ClaimAnalysis.fromJson(Map<String, dynamic> json) {
    return ClaimAnalysis(
      summary: json['summary'] as String? ?? 'No explanation was returned.',
      missingDocuments: (json['missingDocuments'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      nextSteps: (json['nextSteps'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      disclaimer:
          json['disclaimer'] as String? ??
          'Confirm the next steps with your insurer.',
      citations: (json['citations'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ClaimCitation.fromJson)
          .toList(),
      evidenceUsed: (json['evidenceUsed'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class ClaimState {
  const ClaimState({
    required this.claimId,
    required this.insurerName,
    required this.hospitalName,
    required this.claimDate,
    required this.requestedAmount,
    required this.approvedAmount,
    required this.claimStatus,
    required this.insurerReason,
    required this.documents,
    required this.timeline,
    required this.appealDraft,
    this.appealDraftTranslation = '',
    this.analysis,
    this.isAnalyzing = false,
    this.analysisError,
    this.reconsiderationMarkedSubmitted = false,
  });

  final String claimId;
  final String insurerName;
  final String hospitalName;
  final String claimDate;
  final int requestedAmount;
  final int approvedAmount;
  final String claimStatus;
  final String insurerReason;
  final List<ClaimDocument> documents;
  final List<ClaimTimelineEvent> timeline;
  final String appealDraft;
  final String appealDraftTranslation;
  final ClaimAnalysis? analysis;
  final bool isAnalyzing;
  final String? analysisError;
  final bool reconsiderationMarkedSubmitted;

  int get unpaidAmount => requestedAmount - approvedAmount;
  int get uploadedDocuments => documents.where((d) => d.uploaded).length;
  int get requiredDocuments => documents.where((d) => d.required).length;
  int get uploadedRequiredDocuments =>
      documents.where((d) => d.required && d.uploaded).length;
  double get documentProgress => requiredDocuments == 0
      ? 0
      : uploadedRequiredDocuments / requiredDocuments;
  List<String> get missingRequiredDocuments => documents
      .where((d) => d.required && !d.uploaded)
      .map((d) => d.title)
      .toList();

  factory ClaimState.empty() {
    return const ClaimState(
      claimId: 'Not provided',
      insurerName: 'Not connected',
      hospitalName: 'Not provided',
      claimDate: 'Not provided',
      requestedAmount: 0,
      approvedAmount: 0,
      claimStatus: 'Not connected',
      insurerReason: 'No insurer decision letter text has been provided yet.',
      documents: [],
      timeline: [],
      appealDraft: '',
      appealDraftTranslation: '',
    );
  }

  ClaimState copyWith({
    List<ClaimDocument>? documents,
    List<ClaimTimelineEvent>? timeline,
    String? appealDraft,
    String? appealDraftTranslation,
    ClaimAnalysis? analysis,
    bool? isAnalyzing,
    String? analysisError,
    bool clearAnalysisError = false,
    bool clearAnalysis = false,
    bool? reconsiderationMarkedSubmitted,
  }) {
    return ClaimState(
      claimId: claimId,
      insurerName: insurerName,
      hospitalName: hospitalName,
      claimDate: claimDate,
      requestedAmount: requestedAmount,
      approvedAmount: approvedAmount,
      claimStatus: claimStatus,
      insurerReason: insurerReason,
      documents: documents ?? this.documents,
      timeline: timeline ?? this.timeline,
      appealDraft: appealDraft ?? this.appealDraft,
      appealDraftTranslation:
          appealDraftTranslation ?? this.appealDraftTranslation,
      analysis: clearAnalysis ? null : (analysis ?? this.analysis),
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      analysisError: clearAnalysisError
          ? null
          : (analysisError ?? this.analysisError),
      reconsiderationMarkedSubmitted:
          reconsiderationMarkedSubmitted ?? this.reconsiderationMarkedSubmitted,
    );
  }
}
