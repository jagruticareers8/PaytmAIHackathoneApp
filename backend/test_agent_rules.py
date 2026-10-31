import unittest
from main import detect_intent, is_private_or_sensitive_query, mask_pii


class LocalFirstPrivacyTests(unittest.TestCase):
    def test_hinglish_rejection_intent(self):
        self.assertEqual(detect_intent("Mera claim reject ho gaya, ab kya karu?"), "explain_rejection")

    def test_document_intent(self):
        self.assertEqual(detect_intent("Kaun se documents chahiye?"), "required_documents")

    def test_hindi_status_intent(self):
        self.assertEqual(detect_intent("मेरा क्लेम स्टेटस क्या है"), "claim_status")

    def test_general_copay_definition_can_be_general(self):
        self.assertFalse(is_private_or_sensitive_query("What does co-pay mean in health insurance?"))

    def test_claim_specific_query_stays_private(self):
        self.assertTrue(is_private_or_sensitive_query("Mera claim reject kyun hua?"))

    def test_personal_identifier_is_masked(self):
        self.assertIn("[ID REDACTED]", mask_pii("My identifier is 1234 5678 9012"))


if __name__ == "__main__":
    unittest.main()
