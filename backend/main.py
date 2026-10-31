"""Sathi AI backend for a local prototype.

This backend generates answers only for confirmed general-information questions.
It rejects private claim context, document/OCR text, chat history and obvious
personal questions. Private documents are meant to stay in Sathi's encrypted
on-device vault. The backend does not connect to an insurer.

Before accepting real customer data in production, add Firebase/OIDC authentication,
per-user authorization, rate limiting, audit controls, secret management, a retention
policy, and a reviewed privacy/security design. The local development endpoints are
not a production insurance service.
"""
from __future__ import annotations

import base64
import json
import logging
import os
import re
import time
from datetime import datetime, timezone
from typing import Literal
from urllib.parse import urlparse

from dotenv import load_dotenv
from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
try:
    from google import genai
    from google.genai import types
except ImportError:  # Allows local rule tests without the optional provider SDK installed.
    genai = None
    types = None
from pydantic import BaseModel, Field

load_dotenv()
logger = logging.getLogger("uvicorn.error")

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "").strip()
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-3.6-flash").strip()
GEMINI_TRANSCRIPTION_MODEL = os.getenv("GEMINI_TRANSCRIPTION_MODEL", "gemini-3.5-transcribe").strip()
MAX_AUDIO_BYTES = 8 * 1024 * 1024
MAX_CONTEXT_CHARS = 18_000
# Set true only for a local, short-lived hackathon backend using synthetic or
# thoroughly redacted data. Production authentication is not implemented here.
ALLOW_UNAUTHENTICATED_DEV = os.getenv("SATHI_ALLOW_UNAUTHENTICATED_DEV", "false").strip().lower() == "true"


def safe_provider_error(exc: Exception) -> str:
    """Log provider error metadata without logging prompts, OCR, audio, or API keys."""
    message = str(exc)
    if GEMINI_API_KEY:
        message = message.replace(GEMINI_API_KEY, "[REDACTED_API_KEY]")
    message = re.sub(r"(?i)bearer\s+\S+", "Bearer [REDACTED]", message)
    return message[:800] or "(no provider message)"


client = (
    genai.Client(
        api_key=GEMINI_API_KEY,
        http_options=types.HttpOptions(timeout=120_000),
    )
    if GEMINI_API_KEY and genai is not None and types is not None
    else None
)

app = FastAPI(title="Sathi AI Assistant API", version="1.0.0")
allowed_origins = [item.strip() for item in os.getenv("SATHI_ALLOWED_ORIGINS", "*").split(",") if item.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization", "X-Sathi-Prototype"],
)


@app.middleware("http")
async def log_request_duration(request: Request, call_next):
    """Log endpoint, status and duration only, never private user content."""
    started = time.perf_counter()
    response = await call_next(request)
    elapsed = time.perf_counter() - started
    if request.url.path in {"/v1/agent/chat", "/v1/agent/company-info", "/v1/claims/analyze", "/v1/voice/transcribe"}:
        logger.info(
            "[sathi-timing] %s %s status=%s duration_s=%.1f",
            request.method, request.url.path, response.status_code, elapsed,
        )
    return response


def mask_pii(text: str) -> str:
    """Best-effort additional masking. This does not replace a reviewed DLP layer."""
    text = re.sub(r"\b\d{4}[ -]?\d{4}[ -]?\d{4}\b", "[ID REDACTED]", text)
    text = re.sub(r"\b[A-Z]{5}\d{4}[A-Z]\b", "[PAN REDACTED]", text, flags=re.I)
    text = re.sub(r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b", "[EMAIL REDACTED]", text, flags=re.I)
    text = re.sub(r"(?:\+?91[\s-]?)?[6-9]\d{4}[\s-]?\d{5}\b", "[PHONE REDACTED]", text)
    return text


def is_private_or_sensitive_query(value: str) -> bool:
    """Conservative server-side guard: this endpoint is general-info only."""
    raw = value.strip()
    if not raw:
        return True
    if mask_pii(raw) != raw or re.search(r"\b\d{4,}\b", raw):
        return True
    q = raw.casefold()
    private_markers = (
        "my claim", "my policy", "my insurer", "my hospital", "my bill", "my diagnosis",
        "my treatment", "my medication", "my surgery", "my medical", "my test result",
        "my ", "i have ", "i had ", "i was diagnosed", "i take ", "i paid ",
        "mera ", "meri ", "mere ", "mujhe ", "maine ",
        "मेरा ", "मेरी ", "मेरे ", "मुझे ",
        "my decision letter", "this document", "this letter", "attached document", "uploaded document",
        "claim status", "claim number", "claim id", "policy number", "policy id",
        "approved amount", "requested amount", "claim ka status", "claim ka reason",
        "mera claim", "meri policy", "mere documents", "meri report", "mera bill",
        "mera ilaaj", "meri bimari", "meri diagnosis", "is letter mein", "mere document",
        "मेरा क्लेम", "मेरी पॉलिसी", "मेरे दस्तावेज", "मेरी रिपोर्ट", "मेरा बिल",
        "मेरा इलाज", "मेरी बीमारी", "इस पत्र", "इस दस्तावेज", "क्लेम स्टेटस",
    )
    if any(marker in q for marker in private_markers):
        return True
    first_person_markers = (
        "i have ", "i had ", "i was diagnosed", "i take ", "i paid ", "i was admitted",
        "i visited ", "mujhe ", "maine ", "mera ", "meri ", "mere ",
        "मुझे ", "मेरी ", "मेरा ", "मेरे ",
    )
    health_or_finance_markers = (
        "diabetes", "cancer", "kidney disease", "heart disease", "diagnosis", "medication",
        "medicine", "treatment", "surgery", "medical report", "lab report", "test result",
        "prescription", "hospitalised", "hospitalized", "admitted", "premium amount", "loan amount",
        "medical bill", "इलाज", "बीमारी", "दवा", "रिपोर्ट", "सर्जरी", "अस्पताल",
    )
    return any(marker in q for marker in first_person_markers) and any(marker in q for marker in health_or_finance_markers)


def clean_text(value: object, limit: int = 7000) -> str:
    if not isinstance(value, str):
        return ""
    return mask_pii(value.strip())[:limit]


def safe_history(history: list[dict[str, str]]) -> list[dict[str, str]]:
    """Bounded in-memory turns for follow-up questions; do not persist or log."""
    cleaned: list[dict[str, str]] = []
    for turn in history[-10:]:
        if not isinstance(turn, dict):
            continue
        role = str(turn.get("role", ""))
        content = clean_text(turn.get("content"), 1500)
        if role in ("user", "assistant") and content:
            cleaned.append({"role": role, "content": content})
    return cleaned


def safe_context(context: dict | None) -> dict:
    """Accept only supported, bounded, user-supplied context; never add sample data."""
    if not isinstance(context, dict):
        return {}
    safe: dict = {}
    raw_docs = context.get("documentTexts", [])
    docs: list[dict[str, str]] = []
    if isinstance(raw_docs, list):
        for item in raw_docs[:5]:
            if not isinstance(item, dict):
                continue
            title = clean_text(item.get("title"), 120)
            text = clean_text(item.get("text"), 6000)
            if text:
                docs.append({"title": title or "User-provided document", "text": text})
    if docs:
        safe["documentTexts"] = docs
    names = context.get("attachedDocumentNames", [])
    if isinstance(names, list):
        safe_names = [clean_text(name, 120) for name in names[:20] if isinstance(name, str)]
        safe_names = [name for name in safe_names if name]
        if safe_names:
            safe["attachedDocumentNames"] = safe_names
    # Only accept explicitly user-entered, non-authoritative fields. The prompt is
    # instructed not to present them as insurer-verified facts.
    for key in ("userEnteredClaimStatus", "userEnteredReason", "insurerName"):
        value = clean_text(context.get(key), 1200)
        if value:
            safe[key] = value
    encoded = json.dumps(safe, ensure_ascii=False)
    if len(encoded) > MAX_CONTEXT_CHARS:
        # Document texts are already bounded but truncate the total defensively.
        return {"contextNote": "Provided context was too large and was omitted; ask the user for a shorter excerpt."}
    return safe


Intent = Literal[
    "claim_status", "required_documents", "prepare_reconsideration",
    "explain_rejection", "document_review", "general_help"
]


class AgentRequest(BaseModel):
    message: str = Field(min_length=1, max_length=3000)
    language: Literal["hinglish", "hindi", "english"] = "hinglish"
    cloudConsent: bool = False
    queryMode: Literal["general_information"] = "general_information"
    claimContext: dict | None = None
    chatHistory: list[dict[str, str]] = Field(default_factory=list, max_length=12)


class AgentOutput(BaseModel):
    answer: str = Field(description="A useful, direct answer in the requested language. Do not invent personal claim facts.")
    intent: Intent
    actionIndex: int = Field(ge=1, le=4)
    actionLabel: str
    draft: str = Field(default="", description="A complete editable reconsideration draft only when the user asks for one; otherwise empty.")
    evidenceUsed: list[str] = Field(default_factory=list)
    notice: str = Field(description="Short data/source limitation, if relevant; do not claim a live insurer lookup happened.")


class CompanyInfoRequest(BaseModel):
    model_config = {"extra": "forbid"}

    message: str = Field(min_length=1, max_length=1000)
    language: Literal["hinglish", "hindi", "english"] = "hinglish"
    cloudConsent: bool = False


class CompanyInfoSource(BaseModel):
    title: str
    url: str


class CompanyInfoOutput(BaseModel):
    answer: str
    sources: list[CompanyInfoSource] = Field(default_factory=list)
    checkedAt: str
    intent: Literal["general_help"] = "general_help"
    actionIndex: int = 1
    actionLabel: str = "Review answer"
    draft: str = ""
    draftTranslation: str = ""
    evidenceUsed: list[str] = Field(default_factory=list)
    notice: str = ""
    mode: str = "company_web_lookup"


class ClaimAnalyzeRequest(BaseModel):
    cloudConsent: bool = False
    insurerReason: str = Field(default="", max_length=5000)
    uploadedDocuments: list[str] = Field(default_factory=list, max_length=30)
    requiredDocuments: list[str] = Field(default_factory=list, max_length=30)
    documentTexts: list[dict[str, str]] = Field(default_factory=list, max_length=5)


class ClaimAnalysisOutput(BaseModel):
    summary: str
    missingDocuments: list[str] = Field(default_factory=list)
    nextSteps: list[str] = Field(default_factory=list)
    disclaimer: str
    evidenceUsed: list[str] = Field(default_factory=list)


SYSTEM_PROMPT = """You are Sathi, a careful health-insurance claim support assistant for customers in India.
Help in the user's requested language: natural Roman-script Hinglish for 'hinglish',
simple Devanagari Hindi for 'hindi', and plain English for 'english'. Be practical,
kind, specific, and easy to understand. Answer the user's actual question, including
questions that do not match a predefined list.

TRUTH AND DATA RULES:
- You have NO live connection to any insurer, TPA, hospital, bank, credit bureau, or claim portal.
- Never invent a real claim status, claim ID, amount, policy clause, coverage decision, deadline,
  document receipt, insurer response, or claim-submission result.
- Never invent or guess insurer/TPA phone numbers, helplines, email addresses, URLs, policy
  identifiers, current fees, or other details that require a current official source. This service
  has no live web or insurer-directory lookup. Say when a detail cannot be verified, ask which
  insurer or which kind of number the user means when unclear, and point them to their e-card,
  policy documents, or the insurer's official website. Do not present an unverified number as fact.
- If asked for live claim status, say you cannot fetch it yet and explain that an authenticated
  insurer/TPA integration or the insurer's portal is needed. You may explain how the user can check.
- The supplied context, if any, is user-provided OCR or text. It is not verified by an insurer.
- If a decision letter excerpt is provided, explain only what that excerpt supports and name the
  document title as the source. If no letter text is available, ask the user to attach/read the
  letter or paste a redacted excerpt; do not guess why their claim was rejected.
- If asked for required documents and the policy/letter doesn't specify them, offer a general
  starter checklist but clearly say exact requirements vary by insurer, claim type, and policy.
- If asked what to ask an insurer/TPA, give a practical checklist: current status and next step,
  the exact reason and policy clause for a denial/deduction, missing documents and submission
  channel/deadline, amount breakdown, and complaint/escalation reference. Suggest getting answers
  in writing and never sharing OTPs, passwords, or PINs.
- If asked to draft a reconsideration/appeal, create a usable editable draft grounded only in the
  user's facts. Use bracketed placeholders for missing facts. Do not invent policy clauses, dates,
  medical facts, amounts, or evidence. Do not state the draft has been sent.
- Explain eligibility, exclusions, waiting periods, co-pay, sub-limits, or medical necessity only
  when supported by user-provided wording. Encourage confirmation with the insurer for decisions.
- Do not ask for Aadhaar, PAN, full policy number, bank credentials, OTP, or unnecessary medical IDs.
- Never claim to have uploaded, submitted, escalated, or checked something unless an integrated
  external service actually did that. This service has no such integrations.
- Provide a short, concrete next step. Do not promise claim recovery or act as legal/medical advice.
Return a concise but complete answer, usually 3-8 short sentences. Longer drafts are allowed when
requested. EvidenceUsed must mention only supplied evidence, not invented citations.
"""


def detect_intent(message: str) -> Intent:
    text = message.casefold()
    if any(x in text for x in ["status", "track", "tracking", "kaha tak", "kahan tak", "claim kaha", "claim kahan", "स्टेटस", "स्थिति", "कहाँ तक", "कहां तक"]):
        return "claim_status"
    if any(x in text for x in ["draft", "appeal", "reconsider", "dobara review", "letter bana", "reply likh", "अपील", "ड्राफ्ट"]):
        return "prepare_reconsideration"
    if any(x in text for x in ["document", "docs", "bill", "paper", "kagaz", "कागज", "कागज़", "दस्तावेज", "डॉक्यूमेंट", "upload", "missing"]):
        return "required_documents"
    if any(x in text for x in ["reject", "rejected", "rejection", "denied", "deny", "partial", "partly", "short pay", "reason", "kyu", "kyun", "kyon", "क्यों", "अस्वीकृत", "रिजेक्ट"]):
        return "explain_rejection"
    if any(x in text for x in ["read this", "check this document", "analyse this", "analyze this", "is this letter", "document mein", "letter mein"]):
        return "document_review"
    return "general_help"


def action_for_intent(intent: Intent, language: str) -> tuple[int, str]:
    labels = {
        "claim_status": (3, "ट्रैकर देखें" if language == "hindi" else "Open tracker"),
        "required_documents": (2, "दस्तावेज़ देखें" if language == "hindi" else "Open documents"),
        "prepare_reconsideration": (4, "ड्राफ्ट देखें" if language == "hindi" else "Review draft"),
        "explain_rejection": (1, "क्लेम देखें" if language == "hindi" else "Review claim"),
        "document_review": (2, "दस्तावेज़ देखें" if language == "hindi" else "Open documents"),
        "general_help": (1, "क्लेम देखें" if language == "hindi" else "Review claim"),
    }
    return labels[intent]


def require_prototype_access() -> None:
    if not ALLOW_UNAUTHENTICATED_DEV:
        raise HTTPException(
            status_code=503,
            detail="This backend has no production authentication. For local synthetic-data development only, set SATHI_ALLOW_UNAUTHENTICATED_DEV=true. Do not expose that mode publicly or send real customer data.",
        )


def require_model() -> None:
    if client is None:
        raise HTTPException(
            status_code=503,
            detail="Live AI is not configured. Start the Sathi backend with GEMINI_API_KEY set in backend/.env. No demo answer was returned.",
        )


@app.get("/health")
def health() -> dict:
    return {
        "status": "ok",
        "modelConfigured": client is not None,
        "agentModel": GEMINI_MODEL if client else None,
        "transcriptionModelConfigured": client is not None,
        "transcriptionModel": GEMINI_TRANSCRIPTION_MODEL if client else None,
        "publicCompanyLookupConfigured": client is not None,
        "insurerIntegrationConfigured": False,
        "unauthenticatedDevelopmentMode": ALLOW_UNAUTHENTICATED_DEV,
        "mode": "live_gemini" if client else "ai_not_configured",
    }


@app.post("/v1/agent/chat")
def chat(request: AgentRequest) -> dict:
    require_prototype_access()
    if not request.cloudConsent:
        raise HTTPException(status_code=403, detail="Cloud general-information consent is required before sending this question.")
    # Enforce the local-first privacy rule at the server boundary as well. A
    # malformed/older client must not be able to attach files, OCR, claim context,
    # or conversation history to a Gemini request.
    if request.claimContext:
        raise HTTPException(status_code=400, detail="This endpoint accepts general-information questions only. Claim context and document text are never accepted.")
    if request.chatHistory:
        raise HTTPException(status_code=400, detail="Conversation history is not accepted by the online general-information endpoint.")
    if is_private_or_sensitive_query(request.message):
        raise HTTPException(status_code=422, detail="This looks personal or claim-specific. For privacy, this online endpoint accepts generic questions only. Remove personal details or use Private mode.")
    require_model()
    message = clean_text(request.message, 3000)
    if not message:
        raise HTTPException(status_code=400, detail="Message is empty after validation.")
    # The only user payload used for the cloud generation is the current question.
    intent = detect_intent(message)
    action_index, action_label = action_for_intent(intent, request.language)
    prompt = (
        f"User language preference: {request.language}.\n"
        f"Detected topic for navigation only: {intent}.\n"
        f"User's general-information question (PII masked): {message}\n\n"
        "Answer the question using general knowledge only. You have not received the user's policy, documents, OCR, claim context, history, or insurer records. If asked about live status, "
        "state there is no insurer/TPA integration and no status lookup was performed. Do not use or invent any sample claim. "
        "For unknown/absent details, say what input is missing and how the customer can supply it safely. "
        "If the user asks for an appeal/reconsideration letter, put the complete editable letter in the JSON 'draft' field, "
        "and put a short explanation/next step in 'answer'. Otherwise set 'draft' to an empty string. "
        f"Return intent={intent}, actionIndex={action_index}, actionLabel={action_label}."
    )
    try:
        result = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction=SYSTEM_PROMPT,
                response_mime_type="application/json",
                response_schema=AgentOutput,
                temperature=0.2,
                max_output_tokens=1600,
            ),
        )
        output_text = (result.text or "").strip()
        if not output_text:
            raise ValueError("The model returned an empty response.")
        output = AgentOutput.model_validate_json(output_text)
        # Do not trust the model to change which application screen a user opens.
        output.intent = intent
        output.actionIndex = action_index
        output.actionLabel = action_label
        output.notice = (output.notice or "").strip()
        return {
            **output.model_dump(),
            "mode": "gemini_agent",
            "model": GEMINI_MODEL,
            "notice": output.notice or "AI-generated from the confirmed general-information question only. No files, OCR, claim context, chat history, or insurer portal was queried.",
        }
    except HTTPException:
        raise
    except Exception as exc:
        # Never log user prompts, OCR text, audio, or generated content.
        logger.error("Sathi Gemini chat failed (%s): %s", type(exc).__name__, safe_provider_error(exc))
        raise HTTPException(
            status_code=502,
            detail=f"Live AI request failed ({type(exc).__name__}). See backend terminal for sanitized provider error details.",
        ) from exc


def company_name_tokens(message: str) -> list[str]:
    words = re.findall(r"[a-z0-9]{2,}", message.casefold())
    stop_words = {
        "insurance", "insurer", "company", "the", "what", "where", "which", "who",
        "tell", "give", "provide", "please", "me", "mujhe", "muje", "ka", "ki",
        "ke", "kya", "hai", "batao", "number", "phone", "contact", "helpline",
        "customer", "care", "support", "address", "email", "website", "web", "site",
        "office", "branch", "head", "location", "pata", "kahan", "kaha", "is", "are",
        "for", "of", "to", "in", "on", "and", "or", "their", "my", "your", "a", "an",
        "near", "nearest", "claims", "claim", "service", "services", "policy", "policies",
        "cashless", "hospital", "hospitals", "network", "working", "hours", "mujhe",
        "settlement", "ratio", "grievance", "officer", "ombudsman", "product",
        "products", "plan", "plans", "service", "services", "health",
        "find", "official", "named", "india", "exact", "information",
    }
    if "health" in words:
        stop_words.discard("care")
    return list(dict.fromkeys(word for word in words if word not in stop_words))


def source_matches_company(title: str, url: str, tokens: list[str]) -> bool:
    uri_host = (urlparse(url).hostname or "").casefold()
    title_host = title.casefold().strip().removeprefix("https://").removeprefix("http://")
    title_host = title_host.removeprefix("www.").rstrip("/")
    if re.fullmatch(r"[a-z0-9.-]+\.[a-z]{2,}", title_host):
        host = title_host
    elif "vertexaisearch." not in uri_host:
        host = uri_host
    else:
        # Grounding links are redirects. Without a domain-like source title we
        # cannot safely establish that this result belongs to the named company.
        return False
    host_key = re.sub(r"[^a-z0-9]", "", host)
    if host.endswith(("irdai.gov.in", "policyholder.gov.in")):
        return True
    return any(
        len(token) >= 3 and token in host_key
        for token in tokens
    )


def company_lookup_clarification(language: str) -> str:
    return {
        "hinglish": "Kis insurance company ya e-insurance provider ki information chahiye? Company ka exact naam batayein.",
        "hindi": "किस बीमा कंपनी या e-insurance provider की जानकारी चाहिए? कृपया कंपनी का सही नाम बताएं।",
        "english": "Which insurer or e-insurance provider do you mean? Please give its exact name.",
    }[language]


def is_personal_company_lookup_query(message: str) -> bool:
    if mask_pii(message) != message or re.search(r"\b\d{4,}\b", message):
        return True
    text = message.casefold()
    return any(marker in text for marker in (
        "my claim", "my policy", "claim status", "claim amount", "policy number",
        "mera claim", "meri policy", "my diagnosis", "my treatment", "my medical",
        "मेरा क्लेम", "मेरी पॉलिसी", "मेरा इलाज", "मेरी रिपोर्ट",
    ))


@app.post("/v1/agent/company-info")
def company_information(request: CompanyInfoRequest) -> dict:
    """Search public company information only; documents/history are not accepted."""
    require_prototype_access()
    if not request.cloudConsent:
        raise HTTPException(status_code=403, detail="Per-question online lookup consent is required.")
    if is_personal_company_lookup_query(request.message):
        raise HTTPException(status_code=422, detail="This looks personal or claim-specific. This endpoint only searches public company information.")

    message = clean_text(request.message, 1000)
    if not message:
        raise HTTPException(status_code=400, detail="Question is empty after validation.")
    tokens = company_name_tokens(message)
    checked_at = datetime.now(timezone.utc).isoformat(timespec="seconds")
    if not tokens:
        return CompanyInfoOutput(
            answer=company_lookup_clarification(request.language),
            checkedAt=checked_at,
            notice="No web search was made because the company was not identified.",
        ).model_dump()
    require_model()

    prompt = (
        f"Requested language: {request.language}.\n"
        f"Public company-information question: {message}\n\n"
        "Search the web. Answer only about the specifically named insurer or e-insurance provider. Use the company's own official website, "
        "or a government regulator website when relevant. Do not use third-party directories, forums, ads, or model memory as evidence. "
        "For phone numbers, addresses, email addresses, and branch details, copy only what an official source explicitly lists. Never infer "
        "or invent a number or address. If the company is unclear, ask the user to name it. If an official source does not confirm the fact, "
        "say you could not verify it and provide no guessed value. Do not answer personal claim, policy, account, coverage, or status questions."
    )
    try:
        result = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction=(
                    "You are Sathi's public insurance-company information lookup. The user approved sending only this company-related question. "
                    "No documents, OCR, policy data, claim data, or chat history were provided. Never claim to have contacted an insurer. "
                    "Ground every factual answer in official web sources."
                ),
                tools=[types.Tool(google_search=types.GoogleSearch())],
                temperature=0.1,
                max_output_tokens=900,
            ),
        )
        answer = (result.text or "").strip()
        candidates = getattr(result, "candidates", None) or []
        metadata = getattr(candidates[0], "grounding_metadata", None) if candidates else None
        chunks = getattr(metadata, "grounding_chunks", None) or []
        sources: list[CompanyInfoSource] = []
        seen_urls: set[str] = set()
        for chunk in chunks:
            web_source = getattr(chunk, "web", None)
            if web_source is None:
                continue
            title = (getattr(web_source, "title", None) or "Company source").strip()
            url = (getattr(web_source, "uri", None) or "").strip()
            if not url.startswith("https://") or url in seen_urls:
                continue
            if not source_matches_company(title, url, tokens):
                continue
            seen_urls.add(url)
            sources.append(CompanyInfoSource(title=title[:180], url=url[:2000]))
            if len(sources) >= 4:
                break

        if not sources:
            answer = {
                "hinglish": "Main is jawab ko company ke official source se verify nahi kar paaya. Number ya address guess nahi karunga. Company ki official website par details check karein.",
                "hindi": "मैं इस जानकारी को कंपनी के आधिकारिक स्रोत से सत्यापित नहीं कर पाया। मैं नंबर या पता अनुमान से नहीं दूँगा। कंपनी की आधिकारिक वेबसाइट पर विवरण देखें।",
                "english": "I could not verify this from a matching official company source, so I will not guess. Please check the company's official website.",
            }[request.language]
        elif not answer:
            answer = {
                "hinglish": "Official source mila, lekin jawab tayyar nahi ho paaya. Neeche source par details verify karein.",
                "hindi": "आधिकारिक स्रोत मिला, लेकिन जवाब तैयार नहीं हो पाया। नीचे दिए स्रोत पर विवरण जाँचें।",
                "english": "I found a company source but could not prepare an answer. Please check the source below.",
            }[request.language]

        return CompanyInfoOutput(
            answer=answer,
            sources=sources,
            checkedAt=checked_at,
            notice="Online public-company lookup. No user documents or chat history were sent.",
        ).model_dump()
    except Exception as exc:
        logger.error("Sathi company lookup failed (%s): %s", type(exc).__name__, safe_provider_error(exc))
        raise HTTPException(status_code=502, detail="Online company lookup failed. Please try again later.") from exc


@app.post("/v1/claims/analyze")
def analyze_claim_disabled() -> dict:
    # Private claim/document analysis must remain local. Keep this explicit
    # response so older clients cannot accidentally upload OCR or claim data.
    raise HTTPException(
        status_code=410,
        detail="Cloud claim analysis is disabled by Sathi's local-first privacy policy. Claim documents and OCR text must be analysed on-device.",
    )


@app.post("/v1/voice/transcribe")
async def transcribe_voice(
        audio: UploadFile = File(...),
        language_hint: str = Form(default="hinglish"),
        cloudConsent: bool = Form(default=False),
        query_mode: str = Form(default=""),
        confirmed_for_general_use: bool = Form(default=False),
) -> dict:
    require_prototype_access()
    if not cloudConsent:
        raise HTTPException(status_code=403, detail="Cloud voice consent is required before sending audio for transcription.")
    if query_mode != "general_information" or not confirmed_for_general_use:
        raise HTTPException(status_code=403, detail="Cloud transcription requires General information mode and explicit per-recording confirmation.")
    require_model()
    if audio.content_type not in ("audio/wav", "application/octet-stream", "audio/x-wav"):
        if not (audio.filename or "").lower().endswith(".wav"):
            raise HTTPException(status_code=415, detail="Please send a WAV voice recording.")
    data = await audio.read(MAX_AUDIO_BYTES + 1)
    if len(data) > MAX_AUDIO_BYTES:
        raise HTTPException(status_code=413, detail="Keep voice recordings under 8 MB.")
    if not data:
        raise HTTPException(status_code=400, detail="The voice recording is empty.")
    prompt = (
            "Transcribe this short Indian speech recording verbatim. The speaker may code-switch between Hindi and English (Hinglish), "
            "including English financial/insurance words inside Hindi sentences. Preserve the words, Roman-script English tokens, and meaning; "
            "do not translate, summarise, answer, or guess missing words. Return only the transcript. Language hint: " + language_hint[:30]
    )
    try:
        response = client.interactions.create(
            model=GEMINI_TRANSCRIPTION_MODEL,
            input=[
                {"type": "text", "text": prompt},
                {"type": "audio", "data": base64.b64encode(data).decode("ascii"), "mime_type": "audio/wav"},
            ],
        )
        transcript = (response.output_text or "").strip()
        if not transcript:
            raise ValueError("empty transcript")
        return {"text": transcript, "mode": "gemini_transcribe", "model": GEMINI_TRANSCRIPTION_MODEL}
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Sathi Gemini transcription failed (%s): %s", type(exc).__name__, safe_provider_error(exc))
        raise HTTPException(status_code=502, detail=f"Voice transcription failed ({type(exc).__name__}).") from exc
