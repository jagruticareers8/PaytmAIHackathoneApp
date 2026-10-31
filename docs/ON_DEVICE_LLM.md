# On-device RAG: model choice and implementation

Sathi supports two fully local retrieval configurations. Qwen3 is required for answer generation. EmbeddingGemma is an optional upgrade for semantic retrieval.

## Models

- **Required generation model:** `litert-community/Qwen3-0.6B`, file `Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm` (about 329 MB).
- **Optional semantic retrieval model:** `litert-community/embeddinggemma-2-text-270m-litert-lm`, file `embeddinggemma-2-text-270m.litertlm` (about 165 MB).
- Both model cards list Apache-2.0. Preserve required notices and check terms before distributing an app.
- Models are downloaded only after the user initiates installation. Model files are not committed to Git.

## Supported configurations

| Installed models | Retrieval method | Answer generation |
|---|---|---|
| Qwen3 only | Lexical matching against local chunks | Qwen3 |
| Qwen3 + EmbeddingGemma | Semantic embeddings plus lexical overlap | Qwen3 |
| Qwen3 not installed | On-device RAG unavailable | No local LLM answer |

EmbeddingGemma must never be a prerequisite for Qwen-only document question answering. Installing the required offline language model must not automatically download the optional semantic model.

## Retrieval and privacy flow

1. Existing exact fact extraction handles high-confidence fields where available.
2. The service chunks locally stored OCR text and the bundled offline guide.
3. In Qwen-only mode, it ranks chunks using lexical overlap. It does not call an embedding backend or require an embedding cache.
4. When EmbeddingGemma is installed, the service uses local document/query embeddings and lexical overlap for hybrid ranking. Embeddings are cached in the encrypted local vault.
5. Selected evidence is passed to Qwen3. The prompt requires evidence-grounded answers, treats document text as untrusted input, uses the selected language (English, Hindi or Roman Hinglish), and instructs the model to abstain when evidence is insufficient.
6. This RAG service makes no HTTP request. Private documents, OCR text, local embeddings, claim context and chat history must not be sent to a cloud model as a fallback.

## App usage

Open **How Sathi works → Download offline AI models** and install the required Qwen model. Once Qwen is ready, local RAG can answer questions using lexical retrieval. If the app exposes the optional semantic-search upgrade, users may install EmbeddingGemma separately to improve retrieval.

Connect to Wi-Fi for model downloads and ensure sufficient free storage. After installation, test in airplane mode. The model is small; verify responses. Sathi is not an insurer decision engine.

## Platform configuration

- Android: min SDK 30; arm64-v8a is required for LiteRT-LM native inference.
- iOS: deployment target 15.0 and static framework linkage. Configure additional memory entitlements only after confirming the relevant model and Apple signing requirements.
- Dependencies: `flutter_edge_ai` and `flutter_edge_ai_litertlm`. Initialize the LiteRT-LM inference engine and embedding backend before installation/inference. Initializing the backend does not mean the optional embedding model must be installed.

## Limitations

This is a privacy-preserving local RAG MVP, not a trained insurance-specialist model. The bundled guide is deliberately short and is not a verified insurer policy database. Lexical-only retrieval may miss paraphrases; semantic retrieval can improve matching but does not guarantee correctness. OCR errors affect retrieval. Live insurer status, claim submission, policy verification and formal escalation are not integrated.

## Test plan

1. Run `flutter pub get`, `flutter analyze`, and `flutter test`.
2. Install Qwen only. Confirm the app reports the required model ready and optional semantic search unavailable.
3. Ask questions about a synthetic claim letter in English, Hindi and Hinglish.
4. Install EmbeddingGemma separately and repeat the same questions. Confirm hybrid retrieval is selected.
5. Disable Wi-Fi and repeat document questions. Confirm no cloud fallback is invoked by this RAG service.
6. Test a question whose answer is absent from the document and confirm the assistant abstains.
