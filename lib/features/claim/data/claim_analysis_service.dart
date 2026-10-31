import '../domain/models/claim_models.dart';

abstract interface class ClaimAnalysisService {
  Future<ClaimAnalysis> analyze({
    required String claimId,
    required String insurerReason,
    required List<String> uploadedDocuments,
    required List<String> requiredDocuments,
    required List<Map<String, String>> documentTexts,
  });
}

/// Legacy API adapter is intentionally disabled in local-first mode. Claim
/// documents, OCR, and claim-specific analysis must not be uploaded to Gemini.
/// This class remains only so existing app wiring can be migrated gradually.
class ApiClaimAnalysisService implements ClaimAnalysisService {
  ApiClaimAnalysisService({required this.baseUrl});

  final String baseUrl;

  @override
  Future<ClaimAnalysis> analyze({
    required String claimId,
    required String insurerReason,
    required List<String> uploadedDocuments,
    required List<String> requiredDocuments,
    required List<Map<String, String>> documentTexts,
  }) async {
    throw StateError(
      'Cloud claim analysis is disabled for privacy. Sathi searches encrypted local documents on this device; no claim text or OCR is uploaded.',
    );
  }
}
