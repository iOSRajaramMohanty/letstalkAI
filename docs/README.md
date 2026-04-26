# letstalkAI Documentation

## Overview

letstalkAI is a privacy-first document AI assistant that transforms PDFs into conversational knowledge bases with intelligent image understanding. Built on **Apple Intelligence** and **Local LLMs (MLX)**, all processing happens on-device, ensuring your data never leaves your control.

---

## Documentation Index

| Document | Description |
|----------|-------------|
| [TARGET_MARKETS.md](./TARGET_MARKETS.md) | Target markets, use cases, and go-to-market strategy |
| [SECURITY_COMPARISON.md](./SECURITY_COMPARISON.md) | Security comparison between on-device AI and cloud AI |

---

## Key Features

### 1. Document Intelligence
- PDF text extraction with OCR
- Embedded image extraction
- Vision-based image classification
- RAG (Retrieval-Augmented Generation) for accurate answers

### 2. Smart Image Understanding
- Apple Vision framework classification
- Dynamic label indexing per document
- Query-specific image retrieval
- Self-learning query-label mappings

### 3. Privacy & Security
- 100% on-device processing
- No internet required for AI
- No data sent to cloud servers
- No third-party access to your documents

### 4. Multi-Modal Interaction
- Text chat interface
- Voice input support
- Image display in responses
- Listen (text-to-speech) feature

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    letstalkAI Architecture                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   Document  │───▶│  Extraction │───▶│   Storage   │     │
│  │   Upload    │    │  (PDF/OCR)  │    │  (SQLite)   │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
│                            │                   │            │
│                            ▼                   │            │
│                     ┌─────────────┐            │            │
│                     │   Vision    │            │            │
│                     │Classification│           │            │
│                     └─────────────┘            │            │
│                            │                   │            │
│                            ▼                   ▼            │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │    User     │───▶│     RAG     │◀───│  Embeddings │     │
│  │    Query    │    │  Retrieval  │    │   (NLE)     │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
│                            │                                │
│                            ▼                                │
│                   ┌─────────────────┐                       │
│                   │   AI Engine     │                       │
│                   ├─────────────────┤                       │
│                   │ Apple Intel. OR │                       │
│                   │ Local LLM (MLX) │                       │
│                   └─────────────────┘                       │
│                            │                                │
│                            ▼                                │
│                     ┌─────────────┐                         │
│                     │  Response   │                         │
│                     │ + Images    │                         │
│                     └─────────────┘                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Technology Stack

| Component | Technology |
|-----------|------------|
| Platform | iOS 18+ / macOS 15+ (iOS 26+ for Apple Intelligence) |
| AI Engine (Cloud) | Apple Intelligence (FoundationModels) |
| AI Engine (Local) | MLX-Swift (Llama, Qwen, Gemma models) |
| Vision | Apple Vision Framework (VNClassifyImageRequest) |
| Embeddings | NaturalLanguage Embeddings (NLEmbedding) |
| Database | SQLite (via SQLite.swift) |
| PDF Processing | PDFKit + Core Graphics |
| OCR | Vision (VNRecognizeTextRequest) |
| Architecture | Clean Architecture (MVVM + Use Cases) |

---

## AI Engine Modes

### 1. Apple Intelligence (Cloud-Ready)
- Uses Apple's FoundationModels framework
- Requires iOS 26+ / macOS 26+ with Apple Intelligence enabled
- Best quality responses

### 2. Local LLMs (MLX)
- Uses open-source models (Llama, Qwen, Gemma)
- Works on any Apple Silicon device
- 100% offline after model download
- Models: 500MB - 4GB each

### How the Dual Engine Works

```
┌─────────────────────────────────────────────────────────┐
│                    User Message                         │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│              Check Selected Model                        │
└─────────────────────────────────────────────────────────┘
                          │
            ┌─────────────┴─────────────┐
            │                           │
            ▼                           ▼
┌───────────────────────┐    ┌───────────────────────┐
│  Local LLM Selected?  │    │  Apple Intelligence   │
│  ✅ Use MLX Engine    │    │  ✅ Use Foundation    │
│  Works offline        │    │     Models            │
└───────────────────────┘    └───────────────────────┘
            │                           │
            └───────────┬───────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│                    AI Response                          │
└─────────────────────────────────────────────────────────┘
```

---

## Privacy Commitment

1. **No Cloud Processing** - All AI runs on Apple Silicon
2. **No Data Collection** - Zero telemetry on document contents
3. **No Model Training** - Your data never trains AI models
4. **Full User Control** - Delete app = delete all data
5. **Offline First** - Works without internet connection

---

## Compliance Ready

| Regulation | Status |
|------------|--------|
| GDPR | ✅ Compliant (no data transfer) |
| HIPAA | ✅ Compliant (PHI stays local) |
| CCPA | ✅ Compliant (no data sharing) |
| FERPA | ✅ Compliant (student data protected) |
| SOC 2 | ✅ No external processing |

---

## Getting Started

1. Open the app
2. Create a new chat session
3. Upload a PDF document
4. Ask questions in natural language
5. View text answers with relevant images

---

## Support

For technical support or feature requests, please refer to the main README.md in the project root.
