# Model Badges Guide

This document explains the badges displayed in the **Manage Models** screen to help you choose the right model for your needs.

---

## Badge Overview

| Badge | Icon | Color | Meaning |
|-------|------|-------|---------|
| **MLX** | `cpu.fill` | Blue | Model has real MLX support for on-device AI |
| **Vision** | `eye` | Yellow | Model can understand and analyze images |
| **RAG** | `lightbulb.fill` | Yellow | Optimized for document Q&A |
| **Thinking** | `brain` | Purple | Enhanced reasoning capabilities |
| **New** | `sparkle` | Green | Recently added model |
| **Best** | `crown.fill` | Green | Top performing in its category |
| **Recommended** | `checkmark.seal.fill` | Green | Best balance of quality and performance |

---

## Detailed Badge Descriptions

### 🔵 MLX Badge

**What it means:**  
This model has a verified MLX-optimized version available from the `mlx-community` on Hugging Face.

**Why it matters:**
- Downloads actual AI model weights (~500MB - 4GB)
- Runs real neural network inference on Apple Silicon GPU
- Provides actual AI-generated responses (not placeholder)
- Best quality responses

**How to use:**
1. Enable "Real MLX Downloads" in Settings → Developer
2. Download any model with the MLX badge
3. The model will use real AI inference

**Models with MLX support:**
- Llama 3.2 (1B, 3B)
- Qwen 3.5 (0.8B, 2.6B, 5B)
- Gemma 3 (2B, 4B)
- Phi 4 Mini
- Mistral Nemo (12B)

---

### 👁 Vision Badge

**What it means:**  
This model can process and understand images alongside text.

**Capabilities:**
- Analyze photos and screenshots
- Describe image content
- Answer questions about images
- Extract text from images (OCR-like)

**Best for:**
- Photo analysis
- Visual Q&A
- Image-based document understanding

---

### 💡 RAG Badge

**What it means:**  
This model is optimized for Retrieval-Augmented Generation (RAG) tasks.

**Capabilities:**
- Document question answering
- Information extraction from PDFs
- Context-aware responses
- Multi-document synthesis

**Best for:**
- PDF document queries
- Research assistance
- Data extraction from documents

---

### 🧠 Thinking Badge

**What it means:**  
This model has enhanced reasoning and chain-of-thought capabilities.

**Capabilities:**
- Step-by-step problem solving
- Mathematical reasoning
- Logical deduction
- Code generation and debugging

**Best for:**
- Math problems
- Programming tasks
- Complex reasoning questions

---

### ✨ New Badge

**What it means:**  
This model was recently added to the catalog.

**Note:**  
New models may have limited real-world testing. Consider trying established models first for critical tasks.

---

### 👑 Best Badge

**What it means:**  
This model is considered the top performer in its family or category.

**Typically awarded for:**
- Highest benchmark scores
- Best response quality
- Most capable in its size class

---

### ✓ Recommended Badge

**What it means:**  
This model offers the best balance of quality, speed, and resource usage.

**Typically awarded for:**
- Good performance on most devices
- Reasonable download size
- Reliable response quality

---

## Badge Combinations

Models often have multiple badges. Here's how to interpret common combinations:

| Combination | Best For |
|-------------|----------|
| MLX + Vision | Image analysis with real AI |
| MLX + RAG | Document Q&A with real AI |
| MLX + Best | Highest quality responses |
| Vision + Thinking | Complex visual reasoning |
| RAG + Recommended | Reliable document processing |

---

## Choosing a Model

### For Best Quality (with MLX):
Choose models with **MLX** + **Best** badges
- Example: Llama 3.2 (3B)

### For Image Understanding:
Choose models with **Vision** badge
- Example: Qwen 3.5 VL, LFM 2.5 VL

### For Document Q&A:
Choose models with **RAG** badge
- Example: LFM 2.5 (1.2B)

### For Math/Coding:
Choose models with **Thinking** badge
- Example: LFM 2.5 Thinking (1.2B)

### For Limited Storage:
Choose smaller models with **Recommended** badge
- Example: Qwen 3.5 (0.8B)

---

## MLX Download Mode

When **Real MLX Downloads** is enabled in Settings:

| Model Has MLX Badge | Download Behavior |
|---------------------|-------------------|
| ✅ Yes | Downloads real MLX model files from Hugging Face |
| ❌ No | Downloads placeholder (uses smart responses) |

### File Sizes (Real MLX Downloads):

| Model Size | Approximate Download |
|------------|---------------------|
| 0.5B - 1B | 400MB - 700MB |
| 1B - 3B | 700MB - 1.8GB |
| 3B - 8B | 1.8GB - 4GB |
| 8B+ | 4GB+ |

---

## Technical Notes

### MLX Repository Mapping

Models are mapped to `mlx-community` repositories on Hugging Face:

```
llama-3.2-3b  →  mlx-community/Llama-3.2-3B-Instruct-4bit
qwen-3.5-0.8b →  mlx-community/Qwen2.5-0.5B-Instruct-4bit
gemma-3-2b    →  mlx-community/gemma-2-2b-it-4bit
```

### Placeholder Mode

Models without MLX support use intelligent placeholder responses:
- Keyword-based context matching
- Document content extraction (RAG)
- Structured response generation

This provides a functional demo while real MLX inference is being set up.

---

*Last updated: April 2026*
