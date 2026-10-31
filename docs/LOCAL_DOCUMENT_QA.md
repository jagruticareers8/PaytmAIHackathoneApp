# Sathi Local Document Q&A

## Goal

A user can ask different natural-language questions about their own saved claim letter without uploading the private question or document text to Gemini. The system checks OCR text saved in the encrypted local vault first.

## How local Q&A works

1. **Read local data:** The assistant loads documents and OCR text from `LocalPrivateVault` and any currently attached OCR text passed by the screen.
2. **Understand question intent:** It classifies common question types such as amount, reason, status, required documents, deadline, policy/claim references, insurer, hospital, dates, treatment, coverage, contact information, next steps, summary, and reconsideration drafting. It includes English, Roman-script Hinglish, and Hindi phrase variants.
3. **Extract labelled facts:** When possible it extracts amounts, identifiers, status, dates, and other labelled fields directly from OCR text.
4. **Retrieve supporting evidence:** It creates overlapping one-, two-, and three-line text windows. A synonym dictionary expands query terms and a local relevance score ranks the best excerpts. Field-specific anchor checks reduce unrelated results (for example, a diagnosis line is not presented as proof of policy coverage).
5. **Answer only from evidence:** It returns a grounded answer with the local text used. If a recognised field is not present in OCR, it says it could not find the field instead of guessing. Unknown document questions get the best relevant excerpts rather than a fabricated answer.
6. **Keep cloud separate:** Personal claim questions and OCR are not sent to Gemini. Only a separate, non-personal general-information question can enter the online fallback, after consent and confirmation of the exact question. The backend also rejects claim context and history on that route.

## Example questions covered

### Amounts
- “Mera claim kitne ka tha?”
- “How much money was originally requested?”
- “Kitna amount approve hua?”
- “What amount is pending?”
- “How much was deducted?”
- “What is the total hospital bill?”
- “What is the premium / sum insured / co-pay / deductible?”

### Claim decision and next steps
- “Mera claim kyun partly approve hua?”
- “Why did they not approve the full amount?”
- “Has my claim been approved yet?”
- “Abhi claim ka status kya hai?”
- “Which documents do I need to submit?”
- “Which papers should I upload now?”
- “What is the final date to submit supporting documents?”
- “Appeal kitne din mein submit karni hai?”
- “What should I do next?”

### Document facts
- “Mera policy number kya hai?”
- “What is the claim/reference ID?”
- “Who is my insurance company?”
- “Hospital ka naam kya hai?”
- “What date is on the decision letter?”
- “What treatment or diagnosis is mentioned?”
- “Does my policy cover this treatment?”
- “What are the important points in this letter?”
- “Please write an appeal/reconsideration letter for me.”

The answer depends on the actual OCR text. If a policy has no visible coverage clause, Sathi should say it did not find one—not infer coverage from a diagnosis or general FAQ.

## This is retrieval, not fine-tuning

This code does **not** train or fine-tune an LLM on private health/claim documents. That is usually unnecessary and undesirable for individual users. The user's document changes per upload, so the appropriate design is local retrieval-augmented generation (RAG): retrieve relevant excerpts from that user's own saved document and ground the answer in those excerpts.

The current app implements structured field extraction, intent matching, synonym-expanded lexical retrieval, and evidence-based response templates. It is **not yet a fully generative offline language model**. This is deliberately safer than generating an unrestricted answer with no evidence, but it cannot understand every arbitrary phrasing or synthesise all passages as naturally as an LLM.

For flexible offline answers to questions not covered by the known intent patterns, the next step is to integrate an on-device LLM (for example, a compatible Gemma model through LiteRT-LM). The model should run on the device and receive only the user's question plus locally retrieved excerpts. A model must be downloaded/installed, licensed appropriately, and tested for memory, latency, battery, language quality, and device compatibility. Do not fine-tune on raw user documents or upload those documents to a training service.

## Tests

From the Flutter project root:

```bash
flutter test test/local_first_document_qa_test.dart
flutter test test/local_first_document_amount_test.dart
flutter analyze
```

The tests use synthetic OCR text and an in-memory vault. They cover multiple ways of asking about amount, reason, status, required documents, deadlines, identifiers, insurer/hospital, diagnosis, summary, reconsideration drafting, and missing coverage evidence. They also verify the answer path does not call cloud AI for private document questions.

This environment does not have the Flutter SDK installed, so run these checks on your Mac before using the code in a demo.
