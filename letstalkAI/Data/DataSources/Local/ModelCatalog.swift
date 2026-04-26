//
//  ModelCatalog.swift
//  letstalkAI
//
//  Available LLM Models Catalog - Similar to Locally AI
//

import Foundation

struct ModelCatalog {
    
    static let families: [ModelFamily] = [
        // MARK: - Featured Models
        
        ModelFamily(
            id: "bonsai",
            name: "Bonsai",
            provider: "PrismML",
            providerIcon: "tree.fill",
            description: "A new class of ultra-efficient models from PrismML. Built for performance where it matters most: on-device and in real time.",
            models: [
                LocalLLMModel(
                    id: "bonsai-8b",
                    name: "Bonsai (8B)",
                    displayName: "Bonsai (8B)",
                    familyId: "bonsai",
                    familyName: "Bonsai",
                    provider: "PrismML",
                    providerIcon: "tree.fill",
                    description: "PrismML's flagship 1-bit Bonsai model. Engineered to deliver powerful intelligence for on-device systems. Recommended for iPhone 15 Pro and newer.",
                    sizeBytes: 1_288_490_189,
                    parameterCount: "8B",
                    recommendedDevice: "iPhone 15 Pro and newer",
                    recommendedDeviceMac: "Mac with M1 or newer",
                    capabilities: [],
                    tags: [.new, .best],
                    downloadURL: "https://huggingface.co/prismml/bonsai-8b-mlx/resolve/main/model.safetensors",
                    version: "1.0"
                )
            ],
            category: .featured
        ),
        
        ModelFamily(
            id: "qwen-3.5",
            name: "Qwen 3.5",
            provider: "Qwen",
            providerIcon: "sparkles",
            description: "Qwen 3.5 models from the Qwen team. Supports 201 languages and dialects, with strong reasoning and visual understanding.",
            models: [
                LocalLLMModel(
                    id: "qwen-3.5-0.8b",
                    name: "Qwen 3.5 (0.8B)",
                    displayName: "Qwen 3.5 (0.8B)",
                    familyId: "qwen-3.5",
                    familyName: "Qwen 3.5",
                    provider: "Qwen",
                    providerIcon: "sparkles",
                    description: "Small model with good vision capabilities and hybrid reasoning. Great for simple conversation and fast answers. Recommended for iPhone 14 and newer.",
                    sizeBytes: 1_106_247_680,
                    parameterCount: "0.8B",
                    recommendedDevice: "iPhone 14 and newer",
                    recommendedDeviceMac: "Mac with Apple Silicon",
                    capabilities: [.vision],
                    tags: [],
                    downloadURL: "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct/resolve/main/model.safetensors",
                    version: "3.5"
                )
            ],
            category: .featured
        ),
        
        ModelFamily(
            id: "lfm-2.5",
            name: "LFM 2.5",
            provider: "Liquid AI",
            providerIcon: "drop.fill",
            description: "A new generation of hybrid models developed by Liquid AI. Improved performance compared to LFM 2 and designed for on-device deployment.",
            models: [
                LocalLLMModel(
                    id: "lfm-2.5-vl-1.6b",
                    name: "LFM 2.5 VL (1.6B)",
                    displayName: "LFM 2.5 VL (1.6B)",
                    familyId: "lfm-2.5",
                    familyName: "LFM 2.5",
                    provider: "Liquid AI",
                    providerIcon: "drop.fill",
                    description: "An updated vision-language model from Liquid AI. Enhanced performance over LFM 2 VL with improved multilingual vision understanding. Recommended for iPhone 15 Pro and newer.",
                    sizeBytes: 1_610_612_736,
                    parameterCount: "1.6B",
                    recommendedDevice: "iPhone 15 Pro and newer",
                    recommendedDeviceMac: "Mac with M1 or newer",
                    capabilities: [.vision],
                    tags: [.recommended],
                    downloadURL: "https://huggingface.co/liquid/lfm-2.5-vl-1.6b/resolve/main/model.safetensors",
                    version: "2.5"
                ),
                LocalLLMModel(
                    id: "lfm-2.5-vl-450m",
                    name: "LFM 2.5 VL (450M)",
                    displayName: "LFM 2.5 VL (450M)",
                    familyId: "lfm-2.5",
                    familyName: "LFM 2.5",
                    provider: "Liquid AI",
                    providerIcon: "drop.fill",
                    description: "A compact vision-language model from Liquid AI. Built on the LFM 2.5 backbone with stronger multilingual image understanding. Great for Shortcut use. Recommended for iPhone 14 and older.",
                    sizeBytes: 492_830_720,
                    parameterCount: "450M",
                    recommendedDevice: "iPhone 14 and older",
                    recommendedDeviceMac: "Mac with Apple Silicon",
                    capabilities: [.vision],
                    tags: [.new],
                    downloadURL: "https://huggingface.co/liquid/lfm-2.5-vl-450m/resolve/main/model.safetensors",
                    version: "2.5"
                ),
                LocalLLMModel(
                    id: "lfm-2.5-thinking-1.2b",
                    name: "LFM 2.5 Thinking (1.2B)",
                    displayName: "LFM 2.5 Thinking (1.2B)",
                    familyId: "lfm-2.5",
                    familyName: "LFM 2.5",
                    provider: "Liquid AI",
                    providerIcon: "drop.fill",
                    description: "A reasoning model from Liquid AI. Optimized for reasoning-heavy tasks like math and programming. Provides enhanced problem-solving capabilities with efficient performance. Recommended for iPhone 15 and newer.",
                    sizeBytes: 998_244_352,
                    parameterCount: "1.2B",
                    recommendedDevice: "iPhone 15 and newer",
                    recommendedDeviceMac: "Mac with Apple Silicon",
                    capabilities: [.thinking],
                    tags: [],
                    downloadURL: "https://huggingface.co/liquid/lfm-2.5-thinking-1.2b/resolve/main/model.safetensors",
                    version: "2.5"
                ),
                LocalLLMModel(
                    id: "lfm-2.5-1.2b",
                    name: "LFM 2.5 (1.2B)",
                    displayName: "LFM 2.5 (1.2B)",
                    familyId: "lfm-2.5",
                    familyName: "LFM 2.5",
                    provider: "Liquid AI",
                    providerIcon: "drop.fill",
                    description: "A new generation of hybrid models developed by Liquid AI. Best-in-class performance for its size. Suited for data extraction, RAG, creative writing, and multi-turn conversations. Recommended for iPhone 15 and older.",
                    sizeBytes: 692_060_160,
                    parameterCount: "1.2B",
                    recommendedDevice: "iPhone 15 and older",
                    recommendedDeviceMac: "Mac with Apple Silicon",
                    capabilities: [.rag],
                    tags: [],
                    downloadURL: "https://huggingface.co/liquid/lfm-2.5-1.2b/resolve/main/model.safetensors",
                    version: "2.5"
                ),
                LocalLLMModel(
                    id: "lfm-2.5-350m",
                    name: "LFM 2.5 (350M)",
                    displayName: "LFM 2.5 (350M)",
                    familyId: "lfm-2.5",
                    familyName: "LFM 2.5",
                    provider: "Liquid AI",
                    providerIcon: "drop.fill",
                    description: "A compact model from Liquid AI's LFM 2.5 family. Best for fast everyday chat, summarization, and lightweight drafting on device.",
                    sizeBytes: 398_458_880,
                    parameterCount: "350M",
                    recommendedDevice: "iPhone 14 and older",
                    recommendedDeviceMac: "Mac with Apple Silicon",
                    capabilities: [.summarization],
                    tags: [],
                    downloadURL: "https://huggingface.co/liquid/lfm-2.5-350m/resolve/main/model.safetensors",
                    version: "2.5"
                )
            ],
            category: .featured
        ),
        
        ModelFamily(
            id: "lfm-2",
            name: "LFM 2",
            provider: "Liquid AI",
            providerIcon: "drop.fill",
            description: "A family of hybrid models developed by Liquid AI. Designed for on-device deployment.",
            models: [
                LocalLLMModel(
                    id: "lfm-2-vl-1.6b",
                    name: "LFM 2 VL (1.6B)",
                    displayName: "LFM 2 VL (1.6B)",
                    familyId: "lfm-2",
                    familyName: "LFM 2",
                    provider: "Liquid AI",
                    providerIcon: "drop.fill",
                    description: "A vision-language model from Liquid AI. Optimized for real-world performance. Supports multilingual visual understanding, and delivers reliable results on complex images and OCR. Recommended for iPhone 15 and newer.",
                    sizeBytes: 1_577_058_304,
                    parameterCount: "1.6B",
                    recommendedDevice: "iPhone 15 and newer",
                    recommendedDeviceMac: "Mac with Apple Silicon",
                    capabilities: [.vision],
                    tags: [],
                    downloadURL: "https://huggingface.co/liquid/lfm-2-vl-1.6b/resolve/main/model.safetensors",
                    version: "2.0"
                ),
                LocalLLMModel(
                    id: "lfm-2-vl-450m",
                    name: "LFM 2 VL (450M)",
                    displayName: "LFM 2 VL (450M)",
                    familyId: "lfm-2",
                    familyName: "LFM 2",
                    provider: "Liquid AI",
                    providerIcon: "drop.fill",
                    description: "A small vision-language model from Liquid AI. With only 450M parameters, it achieves competitive performance for image description and visual question answering. Recommended for iPhone 14 and older.",
                    sizeBytes: 591_396_864,
                    parameterCount: "450M",
                    recommendedDevice: "iPhone 14 and older",
                    recommendedDeviceMac: "Mac with Apple Silicon",
                    capabilities: [.vision],
                    tags: [],
                    downloadURL: "https://huggingface.co/liquid/lfm-2-vl-450m/resolve/main/model.safetensors",
                    version: "2.0"
                ),
                LocalLLMModel(
                    id: "lfm-2-1.2b",
                    name: "LFM 2 (1.2B)",
                    displayName: "LFM 2 (1.2B)",
                    familyId: "lfm-2",
                    familyName: "LFM 2",
                    provider: "Liquid AI",
                    providerIcon: "drop.fill",
                    description: "A new generation of hybrid models developed by Liquid AI. Suited for data extraction, RAG, creative writing, and multi-turn conversations. Recommended for iPhone 15 and older.",
                    sizeBytes: 692_060_160,
                    parameterCount: "1.2B",
                    recommendedDevice: "iPhone 15 and older",
                    recommendedDeviceMac: "Mac with Apple Silicon",
                    capabilities: [.rag],
                    tags: [],
                    downloadURL: "https://huggingface.co/liquid/lfm-2-1.2b/resolve/main/model.safetensors",
                    version: "2.0"
                ),
                LocalLLMModel(
                    id: "lfm-2-700m",
                    name: "LFM 2 (700M)",
                    displayName: "LFM 2 (700M)",
                    familyId: "lfm-2",
                    familyName: "LFM 2",
                    provider: "Liquid AI",
                    providerIcon: "drop.fill",
                    description: "A new generation of hybrid models developed by Liquid AI. Suited for data extraction, RAG, creative writing, and multi-turn conversations. Recommended for iPhone 14 and newer.",
                    sizeBytes: 821_035_008,
                    parameterCount: "700M",
                    recommendedDevice: "iPhone 14 and newer",
                    recommendedDeviceMac: "Mac with Apple Silicon",
                    capabilities: [.rag],
                    tags: [],
                    downloadURL: "https://huggingface.co/liquid/lfm-2-700m/resolve/main/model.safetensors",
                    version: "2.0"
                ),
                LocalLLMModel(
                    id: "lfm-2-350m",
                    name: "LFM 2 (350M)",
                    displayName: "LFM 2 (350M)",
                    familyId: "lfm-2",
                    familyName: "LFM 2",
                    provider: "Liquid AI",
                    providerIcon: "drop.fill",
                    description: "A new generation of hybrid models developed by Liquid AI. Suited for data extraction, RAG, creative writing, and multi-turn conversations. Recommended for iPhone 14 and older.",
                    sizeBytes: 398_458_880,
                    parameterCount: "350M",
                    recommendedDevice: "iPhone 14 and older",
                    recommendedDeviceMac: "Mac with Apple Silicon",
                    capabilities: [.rag],
                    tags: [],
                    downloadURL: "https://huggingface.co/liquid/lfm-2-350m/resolve/main/model.safetensors",
                    version: "2.0"
                )
            ],
            category: .featured
        ),
        
        ModelFamily(
            id: "smollm-3",
            name: "SmolLM 3",
            provider: "Hugging Face",
            providerIcon: "face.smiling.fill",
            description: "Small but powerful model by Hugging Face. Great for complex reasoning, long conversations, and use in English, French, Spanish, German, Italian, and Portuguese.",
            models: [
                LocalLLMModel(
                    id: "smollm-3-3b",
                    name: "SmolLM 3 (3B)",
                    displayName: "SmolLM 3 (3B)",
                    familyId: "smollm-3",
                    familyName: "SmolLM 3",
                    provider: "Hugging Face",
                    providerIcon: "face.smiling.fill",
                    description: "A model made by Hugging Face. Great for complex reasoning, long conversations, and use in English, French, Spanish, German, Italian, and Portuguese. Recommended for iPhone 15 Pro and newer.",
                    sizeBytes: 1_857_028_096,
                    parameterCount: "3B",
                    recommendedDevice: "iPhone 15 Pro and newer",
                    recommendedDeviceMac: "Mac with M1 or newer",
                    capabilities: [.thinking, .multilingual],
                    tags: [],
                    downloadURL: "https://huggingface.co/HuggingFaceTB/SmolLM-3-3B/resolve/main/model.safetensors",
                    version: "3.0"
                )
            ],
            category: .featured
        ),
        
        ModelFamily(
            id: "gemma-3",
            name: "Gemma 3",
            provider: "Google",
            providerIcon: "g.circle.fill",
            description: "Powerful models from Google. Optimized for advanced dialogue tasks and image analysis.",
            models: [
                LocalLLMModel(
                    id: "gemma-3-qat-1b",
                    name: "Gemma 3 QAT (1B)",
                    displayName: "Gemma 3 QAT (1B)",
                    familyId: "gemma-3",
                    familyName: "Gemma 3",
                    provider: "Google",
                    providerIcon: "g.circle.fill",
                    description: "A fast model from Google, with improved memory consumption and better responses compared to the base Gemma 3. Optimized for basic dialogue tasks. Recommended for iPhone 15 and older.",
                    sizeBytes: 766_771_200,
                    parameterCount: "1B",
                    recommendedDevice: "iPhone 15 and older",
                    recommendedDeviceMac: "Mac with Apple Silicon",
                    capabilities: [],
                    tags: [],
                    downloadURL: "https://huggingface.co/google/gemma-3-1b-it/resolve/main/model.safetensors",
                    version: "3.0"
                ),
                LocalLLMModel(
                    id: "gemma-3-vl-2b",
                    name: "Gemma 3 VL (2B)",
                    displayName: "Gemma 3 VL (2B)",
                    familyId: "gemma-3",
                    familyName: "Gemma 3",
                    provider: "Google",
                    providerIcon: "g.circle.fill",
                    description: "A compact vision-language model from the Gemma series. Delivers superior text understanding & generation with deeper visual perception in a smaller package. Recommended for iPhone 15 and newer.",
                    sizeBytes: 1_932_735_488,
                    parameterCount: "2B",
                    recommendedDevice: "iPhone 15 and newer",
                    recommendedDeviceMac: "Mac with Apple Silicon",
                    capabilities: [.vision],
                    tags: [],
                    downloadURL: "https://huggingface.co/google/gemma-3-vl-2b/resolve/main/model.safetensors",
                    version: "3.0"
                )
            ],
            category: .featured
        ),
        
        ModelFamily(
            id: "qwen-3",
            name: "Qwen 3",
            provider: "Qwen",
            providerIcon: "sparkles",
            description: "Powerful models from the Qwen team, including both text and vision-language models. Supports over 100 languages and excels at creative writing and role-playing.",
            models: [
                LocalLLMModel(
                    id: "qwen-3-vl-2b",
                    name: "Qwen 3 VL (2B)",
                    displayName: "Qwen 3 VL (2B)",
                    familyId: "qwen-3",
                    familyName: "Qwen 3",
                    provider: "Qwen",
                    providerIcon: "sparkles",
                    description: "A compact vision-language model from the Qwen series. Delivers superior text understanding & generation with deeper visual perception in a smaller package. Recommended for iPhone 15 and newer.",
                    sizeBytes: 1_932_735_488,
                    parameterCount: "2B",
                    recommendedDevice: "iPhone 15 and newer",
                    recommendedDeviceMac: "Mac with Apple Silicon",
                    capabilities: [.vision],
                    tags: [],
                    downloadURL: "https://huggingface.co/Qwen/Qwen3-VL-2B/resolve/main/model.safetensors",
                    version: "3.0"
                ),
                LocalLLMModel(
                    id: "qwen-3-1.7b",
                    name: "Qwen 3 (1.7B)",
                    displayName: "Qwen 3 (1.7B)",
                    familyId: "qwen-3",
                    familyName: "Qwen 3",
                    provider: "Qwen",
                    providerIcon: "sparkles",
                    description: "The latest model from the Qwen team. It supports over 100 languages and excels at coding, creative writing, and role-playing. Recommended for iPhone 15 and older.",
                    sizeBytes: 1_023_410_176,
                    parameterCount: "1.7B",
                    recommendedDevice: "iPhone 15 and older",
                    recommendedDeviceMac: "Mac with Apple Silicon",
                    capabilities: [.thinking, .codeGeneration],
                    tags: [],
                    downloadURL: "https://huggingface.co/Qwen/Qwen3-1.7B/resolve/main/model.safetensors",
                    version: "3.0"
                ),
                LocalLLMModel(
                    id: "qwen-3-0.6b",
                    name: "Qwen 3 (0.6B)",
                    displayName: "Qwen 3 (0.6B)",
                    familyId: "qwen-3",
                    familyName: "Qwen 3",
                    provider: "Qwen",
                    providerIcon: "sparkles",
                    description: "The latest model from the Qwen team. It supports over 100 languages and is great for lightweight coding, creative writing, and role-playing. Recommended for iPhone 14 and older.",
                    sizeBytes: 644_874_240,
                    parameterCount: "0.6B",
                    recommendedDevice: "iPhone 14 and older",
                    recommendedDeviceMac: "Mac with Apple Silicon",
                    capabilities: [.codeGeneration],
                    tags: [],
                    downloadURL: "https://huggingface.co/Qwen/Qwen3-0.6B/resolve/main/model.safetensors",
                    version: "3.0"
                )
            ],
            category: .featured
        ),
        
        ModelFamily(
            id: "cogito",
            name: "Cogito v1 Preview",
            provider: "Deep Cogito",
            providerIcon: "brain",
            description: "Hybrid reasoning models from Deep Cogito. Optimized for coding, STEM, instruction following and general helpfulness.",
            models: [
                LocalLLMModel(
                    id: "cogito-v1-3b",
                    name: "Cogito v1 (3B)",
                    displayName: "Cogito v1 (3B)",
                    familyId: "cogito",
                    familyName: "Cogito v1 Preview",
                    provider: "Deep Cogito",
                    providerIcon: "brain",
                    description: "A hybrid reasoning model from Deep Cogito. Optimized for coding, STEM, instruction following and general helpfulness. Supports over 30 languages. Recommended for iPhone 15 Pro and newer.",
                    sizeBytes: 1_953_497_088,
                    parameterCount: "3B",
                    recommendedDevice: "iPhone 15 Pro and newer",
                    recommendedDeviceMac: "Mac with M1 or newer",
                    capabilities: [.thinking, .codeGeneration],
                    tags: [],
                    downloadURL: "https://huggingface.co/deepcogito/cogito-v1-3b/resolve/main/model.safetensors",
                    version: "1.0"
                )
            ],
            category: .featured
        ),
        
        ModelFamily(
            id: "llama-3.2",
            name: "Llama 3.2",
            provider: "Meta",
            providerIcon: "infinity",
            description: "Small models from Meta. Good for multilingual dialogue and summarization tasks.",
            models: [
                LocalLLMModel(
                    id: "llama-3.2-3b",
                    name: "Llama 3.2 (3B)",
                    displayName: "Llama 3.2 (3B)",
                    familyId: "llama-3.2",
                    familyName: "Llama 3.2",
                    provider: "Meta",
                    providerIcon: "infinity",
                    description: "A model from Meta. Good for multilingual dialogue and summarization tasks. Recommended for iPhone 15 Pro and newer.",
                    sizeBytes: 1_943_011_328,
                    parameterCount: "3B",
                    recommendedDevice: "iPhone 15 Pro and newer",
                    recommendedDeviceMac: "Mac with M1 or newer",
                    capabilities: [.multilingual, .summarization],
                    tags: [],
                    downloadURL: "https://huggingface.co/meta-llama/Llama-3.2-3B-Instruct/resolve/main/model.safetensors",
                    version: "3.2"
                ),
                LocalLLMModel(
                    id: "llama-3.2-1b",
                    name: "Llama 3.2 (1B)",
                    displayName: "Llama 3.2 (1B)",
                    familyId: "llama-3.2",
                    familyName: "Llama 3.2",
                    provider: "Meta",
                    providerIcon: "infinity",
                    description: "A fast model from Meta. Good for basic multilingual dialogue and summarization tasks. Recommended for iPhone 15 and older.",
                    sizeBytes: 727_711_744,
                    parameterCount: "1B",
                    recommendedDevice: "iPhone 15 and older",
                    recommendedDeviceMac: "Mac with Apple Silicon",
                    capabilities: [.multilingual, .summarization],
                    tags: [],
                    downloadURL: "https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct/resolve/main/model.safetensors",
                    version: "3.2"
                )
            ],
            category: .featured
        ),
        
        // MARK: - Legacy Models
        
        ModelFamily(
            id: "gemma-3-legacy",
            name: "Gemma 3 (1B)",
            provider: "Google",
            providerIcon: "g.circle.fill",
            description: "A fast model from Google. Optimized for basic dialogue tasks. Recommended for iPhone 15 and older.",
            models: [
                LocalLLMModel(
                    id: "gemma-3-1b-legacy",
                    name: "Gemma 3 (1B)",
                    displayName: "Gemma 3 (1B)",
                    familyId: "gemma-3-legacy",
                    familyName: "Gemma 3",
                    provider: "Google",
                    providerIcon: "g.circle.fill",
                    description: "A fast model from Google. Optimized for basic dialogue tasks. Recommended for iPhone 15 and older.",
                    sizeBytes: 816_840_704,
                    parameterCount: "1B",
                    recommendedDevice: "iPhone 15 and older",
                    recommendedDeviceMac: "Mac with Apple Silicon",
                    capabilities: [],
                    tags: [.legacy],
                    downloadURL: "https://huggingface.co/google/gemma-3-1b-it/resolve/main/model.safetensors",
                    version: "3.0"
                )
            ],
            category: .legacy
        ),
        
        ModelFamily(
            id: "gemma-2",
            name: "Gemma 2",
            provider: "Google",
            providerIcon: "g.circle.fill",
            description: "Lightweight and efficient models from Google. Tailored for English-language tasks and communication.",
            models: [
                LocalLLMModel(
                    id: "gemma-2-2b",
                    name: "Gemma 2 (2B)",
                    displayName: "Gemma 2 (2B)",
                    familyId: "gemma-2",
                    familyName: "Gemma 2",
                    provider: "Google",
                    providerIcon: "g.circle.fill",
                    description: "A model from Google. Tailored for English-language tasks and communication. Recommended for iPhone 15 Pro and newer.",
                    sizeBytes: 1_577_058_304,
                    parameterCount: "2B",
                    recommendedDevice: "iPhone 15 Pro and newer",
                    recommendedDeviceMac: "Mac with M1 or newer",
                    capabilities: [],
                    tags: [.legacy],
                    downloadURL: "https://huggingface.co/google/gemma-2-2b-it/resolve/main/model.safetensors",
                    version: "2.0"
                )
            ],
            category: .legacy
        ),
        
        ModelFamily(
            id: "granite-4.0",
            name: "Granite 4.0",
            provider: "IBM",
            providerIcon: "building.columns.fill",
            description: "The latest models from IBM. Delivers industry-leading performance in tasks like instruction following. Optimized for edge deployments with remarkable inference efficiency.",
            models: [
                LocalLLMModel(
                    id: "granite-4.0-h-micro",
                    name: "Granite 4.0 H Micro",
                    displayName: "Granite 4.0 H Micro",
                    familyId: "granite-4.0",
                    familyName: "Granite 4.0",
                    provider: "IBM",
                    providerIcon: "building.columns.fill",
                    description: "The latest dense hybrid 3B parameters model from IBM. Delivers strong performance across benchmarks with industry-leading results in tasks like instruction following. Optimized for edge deployments with remarkable inference efficiency. Recommended for iPhone 15 Pro and newer.",
                    sizeBytes: 1_943_011_328,
                    parameterCount: "3B",
                    recommendedDevice: "iPhone 15 Pro and newer",
                    recommendedDeviceMac: "Mac with M1 or newer",
                    capabilities: [.thinking],
                    tags: [.legacy],
                    downloadURL: "https://huggingface.co/ibm-granite/granite-4.0-h-micro/resolve/main/model.safetensors",
                    version: "4.0"
                ),
                LocalLLMModel(
                    id: "granite-4.0-h-1b",
                    name: "Granite 4.0 H (1B)",
                    displayName: "Granite 4.0 H (1B)",
                    familyId: "granite-4.0",
                    familyName: "Granite 4.0",
                    provider: "IBM",
                    providerIcon: "building.columns.fill",
                    description: "The latest dense hybrid ~1.5B parameters model from IBM. Delivers strong performance across benchmarks against models of similar size. Optimized for edge deployments with remarkable inference efficiency. Recommended for iPhone 15 and older.",
                    sizeBytes: 1_288_490_189,
                    parameterCount: "1B",
                    recommendedDevice: "iPhone 15 and older",
                    recommendedDeviceMac: "Mac with Apple Silicon",
                    capabilities: [.thinking],
                    tags: [.legacy],
                    downloadURL: "https://huggingface.co/ibm-granite/granite-4.0-h-1b/resolve/main/model.safetensors",
                    version: "4.0"
                ),
                LocalLLMModel(
                    id: "granite-4.0-h-350m",
                    name: "Granite 4.0 H (350M)",
                    displayName: "Granite 4.0 H (350M)",
                    familyId: "granite-4.0",
                    familyName: "Granite 4.0",
                    provider: "IBM",
                    providerIcon: "building.columns.fill",
                    description: "The latest dense hybrid 350M parameters model from IBM. Delivers strong performance across benchmarks against models of similar size. Optimized for edge deployments with remarkable inference efficiency. Recommended for iPhone 14 and older.",
                    sizeBytes: 398_458_880,
                    parameterCount: "350M",
                    recommendedDevice: "iPhone 14 and older",
                    recommendedDeviceMac: "Mac with Apple Silicon",
                    capabilities: [.thinking],
                    tags: [.legacy],
                    downloadURL: "https://huggingface.co/ibm-granite/granite-4.0-h-350m/resolve/main/model.safetensors",
                    version: "4.0"
                )
            ],
            category: .legacy
        ),
        
        ModelFamily(
            id: "granite-3.3",
            name: "Granite 3.3",
            provider: "IBM",
            providerIcon: "building.columns.fill",
            description: "A hybrid reasoning model by IBM. Designed to handle general instruction-following, reasoning, and coding tasks.",
            models: [
                LocalLLMModel(
                    id: "granite-3.3-2b",
                    name: "Granite 3.3 (2B)",
                    displayName: "Granite 3.3 (2B)",
                    familyId: "granite-3.3",
                    familyName: "Granite 3.3",
                    provider: "IBM",
                    providerIcon: "building.columns.fill",
                    description: "A hybrid reasoning model by IBM. Designed to handle general instruction-following, reasoning, and coding tasks. Recommended for iPhone 15 Pro and newer.",
                    sizeBytes: 1_536_778_240,
                    parameterCount: "2B",
                    recommendedDevice: "iPhone 15 Pro and newer",
                    recommendedDeviceMac: "Mac with M1 or newer",
                    capabilities: [.thinking, .codeGeneration],
                    tags: [.legacy],
                    downloadURL: "https://huggingface.co/ibm-granite/granite-3.3-2b-instruct/resolve/main/model.safetensors",
                    version: "3.3"
                )
            ],
            category: .legacy
        ),
        
        ModelFamily(
            id: "qwen-2.5",
            name: "Qwen 2.5",
            provider: "Qwen",
            providerIcon: "sparkles",
            description: "A multilingual model from the Qwen team, supporting over 29 languages. Great for chatting, handling data like tables and JSON, and role-playing.",
            models: [
                LocalLLMModel(
                    id: "qwen-2.5-3b",
                    name: "Qwen 2.5 (3B)",
                    displayName: "Qwen 2.5 (3B)",
                    familyId: "qwen-2.5",
                    familyName: "Qwen 2.5",
                    provider: "Qwen",
                    providerIcon: "sparkles",
                    description: "A multilingual model from the Qwen team, supporting over 29 languages. Great for chatting, handling data like tables and JSON, and role-playing. Recommended for iPhone 15 Pro and newer.",
                    sizeBytes: 1_867_776_000,
                    parameterCount: "3B",
                    recommendedDevice: "iPhone 15 Pro and newer",
                    recommendedDeviceMac: "Mac with M1 or newer",
                    capabilities: [.multilingual],
                    tags: [.legacy],
                    downloadURL: "https://huggingface.co/Qwen/Qwen2.5-3B-Instruct/resolve/main/model.safetensors",
                    version: "2.5"
                ),
                LocalLLMModel(
                    id: "qwen-2-vl-2b",
                    name: "Qwen 2 VL (2B)",
                    displayName: "Qwen 2 VL (2B)",
                    familyId: "qwen-2.5",
                    familyName: "Qwen 2.5",
                    provider: "Qwen",
                    providerIcon: "sparkles",
                    description: "A multilingual vision-language 2B parameters model from the Qwen team. Excels in tasks like text recognition, image comprehension, and object detection. Recommended for iPhone 15 Pro and newer.",
                    sizeBytes: 1_342_177_280,
                    parameterCount: "2B",
                    recommendedDevice: "iPhone 15 Pro and newer",
                    recommendedDeviceMac: "Mac with M1 or newer",
                    capabilities: [.vision],
                    tags: [.legacy],
                    downloadURL: "https://huggingface.co/Qwen/Qwen2-VL-2B-Instruct/resolve/main/model.safetensors",
                    version: "2.5"
                )
            ],
            category: .legacy
        ),
        
        // MARK: - Experimental Models
        
        ModelFamily(
            id: "josiefied-qwen",
            name: "Josiefied Qwen 3",
            provider: "Gökdeniz Gülmez",
            providerIcon: "person.fill",
            description: "A modified Qwen 3 model by Gökdeniz Gülmez. Fine-tuned with a focus on openness and instruction alignment.",
            models: [
                LocalLLMModel(
                    id: "josiefied-qwen-3-1.7b",
                    name: "Josiefied Qwen 3 (1.7B)",
                    displayName: "Josiefied Qwen 3 (1.7B)",
                    familyId: "josiefied-qwen",
                    familyName: "Josiefied Qwen 3",
                    provider: "Gökdeniz Gülmez",
                    providerIcon: "person.fill",
                    description: "A modified Qwen 3 model by Gökdeniz Gülmez. Fine-tuned with a focus on openness and instruction alignment. Recommended for iPhone 15 and older.",
                    sizeBytes: 1_032_192_000,
                    parameterCount: "1.7B",
                    recommendedDevice: "iPhone 15 and older",
                    recommendedDeviceMac: "Mac with Apple Silicon",
                    capabilities: [.thinking],
                    tags: [.experimental],
                    downloadURL: "https://huggingface.co/gokdenizgulmez/josiefied-qwen3-1.7b-mlx/resolve/main/model.safetensors",
                    version: "1.0"
                )
            ],
            category: .experimental
        ),
        
        ModelFamily(
            id: "dolphin-llama",
            name: "Dolphin Llama 3.2",
            provider: "Dolphin AI",
            providerIcon: "fish.fill",
            description: "Dolphin 3.0 is the next generation of the Dolphin series of instruct-tuned models by Dolphin AI. Designed to be the ultimate general purpose local model.",
            models: [
                LocalLLMModel(
                    id: "dolphin-llama-3.2-3b",
                    name: "Dolphin Llama 3.2 (3B)",
                    displayName: "Dolphin Llama 3.2 (3B)",
                    familyId: "dolphin-llama",
                    familyName: "Dolphin Llama 3.2",
                    provider: "Dolphin AI",
                    providerIcon: "fish.fill",
                    description: "Dolphin 3.0 is the next generation of the Dolphin series of instruct-tuned models by Dolphin AI. Designed to be the ultimate general purpose local model, enabling coding, math, and general use cases.",
                    sizeBytes: 1_943_011_328,
                    parameterCount: "3B",
                    recommendedDevice: "iPhone 15 Pro and newer",
                    recommendedDeviceMac: "Mac with M1 or newer",
                    capabilities: [.codeGeneration],
                    tags: [.experimental],
                    downloadURL: "https://huggingface.co/cognitivecomputations/dolphin-2.9-llama3.2-3b/resolve/main/model.safetensors",
                    version: "3.2"
                ),
                LocalLLMModel(
                    id: "dolphin-llama-3.2-1b",
                    name: "Dolphin Llama 3.2 (1B)",
                    displayName: "Dolphin Llama 3.2 (1B)",
                    familyId: "dolphin-llama",
                    familyName: "Dolphin Llama 3.2",
                    provider: "Dolphin AI",
                    providerIcon: "fish.fill",
                    description: "Dolphin 3.0 is the next generation of the Dolphin series of instruct-tuned models by Dolphin AI. Designed to be the ultimate general purpose local model, enabling coding, math, and general use cases.",
                    sizeBytes: 728_760_320,
                    parameterCount: "1B",
                    recommendedDevice: "iPhone 15 and older",
                    recommendedDeviceMac: "Mac with Apple Silicon",
                    capabilities: [.codeGeneration],
                    tags: [.experimental],
                    downloadURL: "https://huggingface.co/cognitivecomputations/dolphin-2.9-llama3.2-1b/resolve/main/model.safetensors",
                    version: "3.2"
                )
            ],
            category: .experimental
        )
    ]
    
    static var featuredFamilies: [ModelFamily] {
        families.filter { $0.category == .featured }
    }
    
    static var legacyFamilies: [ModelFamily] {
        families.filter { $0.category == .legacy }
    }
    
    static var experimentalFamilies: [ModelFamily] {
        families.filter { $0.category == .experimental }
    }
    
    static var allModels: [LocalLLMModel] {
        families.flatMap { $0.models }
    }
    
    static func model(withId id: String) -> LocalLLMModel? {
        allModels.first { $0.id == id }
    }
    
    static func family(withId id: String) -> ModelFamily? {
        families.first { $0.id == id }
    }
    
    static var onboardingModels: [LocalLLMModel] {
        [
            model(withId: "lfm-2-vl-1.6b"),
            model(withId: "gemma-3-qat-1b"),
            model(withId: "qwen-3.5-0.8b")
        ].compactMap { $0 }
    }
}
