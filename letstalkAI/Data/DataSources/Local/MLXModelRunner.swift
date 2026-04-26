//
//  MLXModelRunner.swift
//  letstalkAI
//
//  MLX Model Runner - Handles MLX inference using MLX-Swift-LM
//  Provides real AI text generation on Apple Silicon devices
//

import Foundation

#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
import MLX
#endif

#if canImport(MLXLMTokenizers)
import MLXLMTokenizers
#endif

// MARK: - Generation Parameters
struct MLXGenerationParams: Sendable {
    var maxTokens: Int = 512
    var temperature: Double = 0.7
    var topP: Double = 0.9
    var repetitionPenalty: Double = 1.1
    var stopTokens: [String] = ["</s>", "<|end|>", "<|eot_id|>", "<|endoftext|>"]
}

// MARK: - MLX Model Runner
@MainActor
final class MLXModelRunner: ObservableObject {
    static let shared = MLXModelRunner()
    
    @Published private(set) var isModelLoaded = false
    @Published private(set) var loadingProgress: Double = 0
    @Published private(set) var currentModelName: String?
    @Published private(set) var tokensPerSecond: Double = 0
    @Published private(set) var isGenerating = false
    
    private var modelPath: URL?
    private var mlxModelLoaded = false
    
    #if canImport(MLXLLM)
    private var modelContainer: ModelContainer?
    #endif
    
    private var generationTask: Task<Void, Never>?
    
    private init() {}
    
    // MARK: - Check MLX Availability
    func isMLXAvailable() -> Bool {
        #if canImport(MLXLLM)
        #if targetEnvironment(simulator)
        // MLX does not work on iOS Simulator - requires real Apple Silicon
        return false
        #elseif arch(arm64)
        #if os(macOS)
        return true
        #elseif os(iOS)
        if #available(iOS 16.0, *) {
            return true
        }
        return false
        #else
        return false
        #endif
        #else
        return false
        #endif
        #else
        return false
        #endif
    }
    
    /// Returns true if running on iOS Simulator
    var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Check if Real MLX is Active
    var isRealMLXActive: Bool {
        #if canImport(MLXLLM)
        return mlxModelLoaded && isModelLoaded && modelContainer != nil
        #else
        return false
        #endif
    }
    
    // MARK: - Check if MLX Files Exist for Selected Model
    func hasMLXFilesForModel(modelId: String) -> Bool {
        guard let modelPath = ModelDownloadManager.shared.localPath(for: modelId) else {
            return false
        }
        
        let configPath = modelPath.appendingPathComponent("config.json")
        let weightsPath = modelPath.appendingPathComponent("model.safetensors")
        let weightsIndexPath = modelPath.appendingPathComponent("model.safetensors.index.json")
        
        let hasConfig = FileManager.default.fileExists(atPath: configPath.path)
        let hasWeights = FileManager.default.fileExists(atPath: weightsPath.path)
        let hasShardedWeights = FileManager.default.fileExists(atPath: weightsIndexPath.path)
        
        return hasConfig && (hasWeights || hasShardedWeights)
    }
    
    /// MLX status for display in Settings
    var mlxStatusDescription: String {
        #if targetEnvironment(simulator)
        return "Simulator (MLX not supported)"
        #else
        if let selectedModelId = ModelDownloadManager.shared.selectedModelId {
            if hasMLXFilesForModel(modelId: selectedModelId) {
                if isRealMLXActive {
                    return "Real MLX active"
                } else {
                    return "MLX files ready"
                }
            }
        }
        return "Placeholder mode"
        #endif
    }
    
    /// Whether MLX files are available (for UI display)
    var hasMLXFilesAvailable: Bool {
        guard let selectedModelId = ModelDownloadManager.shared.selectedModelId else {
            return false
        }
        return hasMLXFilesForModel(modelId: selectedModelId)
    }
    
    private var isLoading = false
    
    // MARK: - Load Model
    func loadModel(from path: URL, modelName: String) async throws {
        // Prevent duplicate concurrent loading
        guard !isLoading else {
            print("⚠️ [MLX] Already loading a model, skipping duplicate request")
            return
        }
        
        // Skip if same model is already loaded
        if isModelLoaded && currentModelName == modelName && modelPath == path {
            print("📝 [MLX] Model already loaded: \(modelName)")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        print("🔄 [MLX] Loading model from: \(path.path)")
        
        #if targetEnvironment(simulator)
        // MLX doesn't work on iOS Simulator - use placeholder mode
        print("⚠️ [MLX] Running on Simulator - MLX not supported, using placeholder mode")
        self.modelPath = path
        self.currentModelName = modelName
        self.isModelLoaded = true
        self.mlxModelLoaded = false
        self.loadingProgress = 1.0
        return
        #endif
        
        loadingProgress = 0.1
        
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw MLXRunnerError.loadFailed("Model directory not found at \(path.path)")
        }
        
        let configPath = path.appendingPathComponent("config.json")
        let hasConfig = FileManager.default.fileExists(atPath: configPath.path)
        
        let weightsPath = path.appendingPathComponent("model.safetensors")
        let hasWeights = FileManager.default.fileExists(atPath: weightsPath.path)
        
        let weightsIndexPath = path.appendingPathComponent("model.safetensors.index.json")
        let hasShardedWeights = FileManager.default.fileExists(atPath: weightsIndexPath.path)
        
        loadingProgress = 0.3
        
        if hasConfig && (hasWeights || hasShardedWeights) {
            print("🔄 [MLX] Found MLX model files, loading with MLX-Swift-LM...")
            
            #if canImport(MLXLLM) && canImport(MLXLMTokenizers)
            do {
                loadingProgress = 0.4
                
                print("🔄 [MLX] Loading model container from: \(path.path)")
                
                // Load the model using MLX-Swift-LM with TokenizersLoader
                let container = try await loadModelContainer(
                    from: path,
                    using: TokenizersLoader()
                )
                
                loadingProgress = 0.8
                
                self.modelContainer = container
                self.mlxModelLoaded = true
                loadingProgress = 0.95
                
                print("✅ [MLX] Model loaded with MLX-Swift-LM: \(modelName)")
                
            } catch {
                print("⚠️ [MLX] Failed to load with MLX-Swift-LM: \(error.localizedDescription)")
                print("📝 [MLX] Falling back to file validation mode")
                mlxModelLoaded = true
                modelContainer = nil
            }
            #else
            print("⚠️ [MLX] MLXLLM or MLXLMTokenizers not available, using validation mode")
            mlxModelLoaded = true
            #endif
            
        } else {
            print("📝 [MLX] Placeholder model (no MLX weights found)")
            mlxModelLoaded = false
        }
        
        modelPath = path
        currentModelName = modelName
        isModelLoaded = true
        loadingProgress = 1.0
        
        print("✅ [MLX] Model ready: \(modelName) (MLX: \(mlxModelLoaded), Container: \(modelContainer != nil))")
    }
    
    // MARK: - Generate Text
    func generate(prompt: String, params: MLXGenerationParams = MLXGenerationParams()) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            self.generationTask = Task { @MainActor in
                guard self.isModelLoaded else {
                    continuation.finish(throwing: MLXRunnerError.modelNotLoaded)
                    return
                }
                
                #if canImport(MLXLLM)
                guard let container = self.modelContainer else {
                    print("⚠️ [MLX] No model container available, falling back to placeholder")
                    continuation.finish(throwing: MLXRunnerError.inferenceNotReady)
                    return
                }
                
                self.isGenerating = true
                
                do {
                    print("🤖 [MLX] Starting real inference...")
                    print("   📝 Prompt length: \(prompt.count) characters")
                    print("   🌡️ Temperature: \(params.temperature)")
                    print("   📊 Max tokens: \(params.maxTokens)")
                    
                    // Prepare the input
                    let userInput = UserInput(prompt: prompt)
                    let input = try await container.prepare(input: userInput)
                    
                    // Set generation parameters
                    let generateParams = GenerateParameters(
                        maxTokens: params.maxTokens,
                        temperature: Float(params.temperature),
                        topP: Float(params.topP),
                        repetitionPenalty: Float(params.repetitionPenalty)
                    )
                    
                    var tokenCount = 0
                    let startTime = Date()
                    
                    // Generate text stream
                    let stream = try await container.generate(input: input, parameters: generateParams)
                    
                    for try await generation in stream {
                        if Task.isCancelled {
                            print("⏹️ [MLX] Generation cancelled")
                            break
                        }
                        
                        switch generation {
                        case .chunk(let text):
                            tokenCount += 1
                            continuation.yield(text)
                            
                        case .info(let info):
                            self.tokensPerSecond = info.tokensPerSecond
                            print("📊 [MLX] Generation info: \(info.tokensPerSecond) tok/s")
                            
                        case .toolCall:
                            break
                        }
                    }
                    
                    let elapsed = Date().timeIntervalSince(startTime)
                    if elapsed > 0 {
                        self.tokensPerSecond = Double(tokenCount) / elapsed
                    }
                    
                    print("✅ [MLX] Generation complete: \(tokenCount) tokens in \(String(format: "%.2f", elapsed))s")
                    print("   📊 Speed: \(String(format: "%.1f", self.tokensPerSecond)) tok/s")
                    
                    self.isGenerating = false
                    continuation.finish()
                    
                } catch {
                    self.isGenerating = false
                    print("❌ [MLX] Generation failed: \(error.localizedDescription)")
                    continuation.finish(throwing: MLXRunnerError.generationFailed(error.localizedDescription))
                }
                
                #else
                print("⚠️ [MLX] MLXLLM not available")
                continuation.finish(throwing: MLXRunnerError.mlxNotAvailable)
                #endif
            }
        }
    }
    
    // MARK: - Unload Model
    func unloadModel() {
        #if canImport(MLXLLM)
        modelContainer = nil
        #endif
        
        modelPath = nil
        isModelLoaded = false
        mlxModelLoaded = false
        currentModelName = nil
        loadingProgress = 0
        tokensPerSecond = 0
        isGenerating = false
        generationTask?.cancel()
        generationTask = nil
        
        print("✅ [MLX] Model unloaded")
    }
    
    // MARK: - Get Memory Usage
    func getMemoryUsage() -> (used: UInt64, total: UInt64) {
        let processInfo = ProcessInfo.processInfo
        let totalMemory = processInfo.physicalMemory
        
        var usedMemory: UInt64 = 0
        if isModelLoaded {
            #if canImport(MLXLLM)
            if modelContainer != nil {
                usedMemory = totalMemory / 4
            } else {
                usedMemory = totalMemory / 8
            }
            #else
            usedMemory = totalMemory / 8
            #endif
        }
        
        return (usedMemory, totalMemory)
    }
    
    // MARK: - Cancel Generation
    func cancelGeneration() {
        generationTask?.cancel()
        isGenerating = false
        print("⏹️ [MLX] Generation cancelled")
    }
}

// MARK: - MLX Runner Errors
enum MLXRunnerError: Error, LocalizedError {
    case mlxNotAvailable
    case modelNotLoaded
    case configNotFound
    case loadFailed(String)
    case generationFailed(String)
    case inferenceNotReady
    
    var errorDescription: String? {
        switch self {
        case .mlxNotAvailable:
            return "MLX framework is not available on this device."
        case .modelNotLoaded:
            return "No model is currently loaded. Please download and select a model."
        case .configNotFound:
            return "Model configuration file not found. The model may be corrupted."
        case .loadFailed(let reason):
            return "Failed to load model: \(reason)"
        case .generationFailed(let reason):
            return "Text generation failed: \(reason)"
        case .inferenceNotReady:
            return "MLX model container not ready. Using placeholder mode."
        }
    }
}
