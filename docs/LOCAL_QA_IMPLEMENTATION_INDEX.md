# Local Document Q&A Implementation Index

Main implementation:
- `lib/features/claim/data/local_first_sathi_agent_service.dart`
    - `_amountQuestionType` and `_extractLabeledAmount`: labelled amount extraction.
    - `_localFactKind`: English/Hinglish/Hindi question intent classification.
    - `_answerLocalLabeledFact`: evidence retrieval and field-specific answer formatting.
    - `_findRelevantExcerpts`, `_documentChunks`, `_expandQuery`: local retrieval and query expansion.
    - `_localFactNotFound`: explicit no-evidence result for recognised questions, to avoid irrelevant snippets.
    - `_offlineFaq`: fixed general insurance FAQ when no document answer is needed.
- `lib/core/storage/local_private_vault.dart`: encrypted local data store.
- `test/local_first_document_qa_test.dart`: broad question patterns and no-false-coverage test.
- `test/local_first_document_amount_test.dart`: amount-extraction regression test.
- `docs/LOCAL_DOCUMENT_QA.md`: design, examples, limitations, test instructions.

Privacy boundary:
- Document Q&A runs on device from saved OCR text.
- No fine-tuning happens on user data.
- General cloud AI is a separate fallback requiring explicit consent and confirmation; private question/document text and previous chat history are not attached to that request.

Known limitation:
- The on-device answer generator is currently extractive/templates + field extraction, not a fully generative on-device LLM. For more flexible natural-language answers offline, integrate a local LLM runtime and send it only the local question and retrieved local excerpts.
