/// Lightweight client-side redaction for common Indian contact and ID formats.
/// This is a privacy aid, not a complete DLP/security boundary. The backend must
/// independently validate and mask data before any model or log receives it.
class PiiMasker {
  PiiMasker._();

  static String mask(String input) {
    var output = input;
    // Aadhaar-like 12 digit sequences, with optional spaces.
    output = output.replaceAll(
      RegExp(r'\b\d{4}[ -]?\d{4}[ -]?\d{4}\b'),
      '[ID REDACTED]',
    );
    // PAN format: five letters, four digits, one letter.
    output = output.replaceAll(
      RegExp(r'\b[A-Z]{5}\d{4}[A-Z]\b', caseSensitive: false),
      '[PAN REDACTED]',
    );
    // Email.
    output = output.replaceAll(
      RegExp(
        r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
        caseSensitive: false,
      ),
      '[EMAIL REDACTED]',
    );
    // Indian mobile numbers; deliberately broad around spaces and +91 prefix.
    output = output.replaceAll(
      RegExp(r'(?:\+?91[\s-]?)?[6-9]\d{4}[\s-]?\d{5}\b'),
      '[PHONE REDACTED]',
    );
    return output;
  }
}
