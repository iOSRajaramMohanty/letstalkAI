//
//  ModelDownloadManager.swift
//  letstalkAI
//
//  Manages downloading, storing, and deleting local LLM models
//  Supports both real MLX models from Hugging Face and placeholder mode
//

import Foundation
import Combine
import ResilientDownloader

// MARK: - Hugging Face MLX Model Repository IDs
struct MLXModelRepository {
    /// Maps model IDs to their Hugging Face MLX repository IDs
    /// These are 4-bit quantized models optimized for Apple Silicon
    /// Models without exact MLX versions use compatible alternatives
    static let repositories: [String: String] = [
        // ========== LLAMA MODELS ==========
        "llama-3.2-3b": "mlx-community/Llama-3.2-3B-Instruct-4bit",
        "llama-3.2-1b": "mlx-community/Llama-3.2-1B-Instruct-4bit",
        "llama-3.1-8b": "mlx-community/Meta-Llama-3.1-8B-Instruct-4bit",
        
        // ========== QWEN MODELS ==========
        "qwen-3.5-0.6b": "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
        "qwen-3.5-0.8b": "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
        "qwen-3.5-2.6b": "mlx-community/Qwen2.5-3B-Instruct-4bit",
        "qwen-3.5-5b": "mlx-community/Qwen2.5-7B-Instruct-4bit",
        
        // ========== GEMMA MODELS ==========
        "gemma-3-2b": "mlx-community/gemma-2-2b-it-4bit",
        "gemma-3-4b": "mlx-community/gemma-2-9b-it-4bit",
        
        // ========== PHI MODELS ==========
        "phi-4-mini": "mlx-community/Phi-3.5-mini-instruct-4bit",
        "phi-4": "mlx-community/Phi-3.5-mini-instruct-4bit",
        
        // ========== MISTRAL MODELS ==========
        "mistral-nemo-12b": "mlx-community/Mistral-Nemo-Instruct-2407-4bit",
        
        // ========== SMOLLM MODELS ==========
        "smollm-360m": "mlx-community/SmolLM-360M-Instruct-4bit",
        "smollm-1.7b": "mlx-community/SmolLM-1.7B-Instruct-4bit",
        
        // ========== DEEPSEEK MODELS ==========
        "deepseek-1.5b": "mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-4bit",
        
        // ========== BONSAI MODELS (PrismML) ==========
        // Note: Bonsai models don't have official MLX versions yet
        // Using Llama as compatible alternative
        "bonsai-8b": "mlx-community/Meta-Llama-3.1-8B-Instruct-4bit",
        "bonsai-1b": "mlx-community/Llama-3.2-1B-Instruct-4bit",
        
        // ========== LFM MODELS (Liquid AI) ==========
        // Note: LFM models don't have MLX versions yet
        // Using Qwen/Llama as compatible alternatives
        "lfm-2.5-vl-1.6b": "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
        "lfm-2.5-vl-450m": "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
        "lfm-2.5-thinking-1.2b": "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
        "lfm-2.5-1.2b": "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
        "lfm-2-vl-0.8b": "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
        "lfm-2-vl-1.8b": "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
        "lfm-2-vl-0.4b": "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
        "lfm-2-3b": "mlx-community/Qwen2.5-3B-Instruct-4bit",
        "lfm-2-1.2b": "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
        "lfm-1b": "mlx-community/Llama-3.2-1B-Instruct-4bit",
        "lfm-3b": "mlx-community/Llama-3.2-3B-Instruct-4bit",
    ]
    
    /// Required files for an MLX model (download fails if these are missing)
    static let requiredFiles = [
        "config.json",
        "tokenizer.json",
        "tokenizer_config.json",
        "model.safetensors"  // The actual model weights - REQUIRED
    ]
    
    /// Optional files that may be present
    static let optionalFiles = [
        "model.safetensors",
        "model.safetensors.index.json",
        "special_tokens_map.json",
        "generation_config.json"
    ]
    
    static func getRepositoryId(for modelId: String) -> String? {
        return repositories[modelId]
    }
    
    /// Get all files to download for a model
    static func getFilesToDownload() -> [String] {
        return [
            "config.json",
            "tokenizer.json", 
            "tokenizer_config.json",
            "special_tokens_map.json",
            "model.safetensors"
        ]
    }
}

@MainActor
final class ModelDownloadManager: ObservableObject {
    static let shared = ModelDownloadManager()
    
    @Published private(set) var downloadStates: [String: ModelDownloadState] = [:]
    @Published private(set) var downloadedModels: [DownloadedModel] = []
    @Published private(set) var selectedModelId: String?
    @Published private(set) var totalStorageUsed: Int64 = 0
    @Published private(set) var currentDownloadFile: String?
    
    /// Whether to download real MLX models (true) or use placeholder (false)
    @Published var useRealMLXDownload: Bool = false
    
    private let fileManager = FileManager.default
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var progressObservations: [String: NSKeyValueObservation] = [:]
    
    private let modelsDirectoryName = "LocalModels"
    private let downloadedModelsKey = "downloadedModels"
    private let selectedModelKey = "selectedModelId"
    
    private init() {
        loadDownloadedModels()
        loadSelectedModel()
        calculateStorageUsed()
        
        Task {
            await resumePendingDownloads()
            await loadSelectedModelOnStartup()
        }
    }
    
    /// Loads the selected model into MLXModelRunner on app startup
    private func loadSelectedModelOnStartup() async {
        guard let modelId = selectedModelId,
              let model = ModelCatalog.model(withId: modelId),
              let modelPath = localPath(for: modelId) else {
            print("📝 [Startup] No model selected or model not found")
            return
        }
        
        print("🔄 [Startup] Loading selected model: \(model.displayName)")
        await autoLoadModel(model, from: modelPath)
    }
    
    var modelsDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelsDir = appSupport.appendingPathComponent(modelsDirectoryName, isDirectory: true)
        
        if !fileManager.fileExists(atPath: modelsDir.path) {
            try? fileManager.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        }
        
        return modelsDir
    }
    
    // MARK: - Download State
    
    func downloadState(for modelId: String) -> ModelDownloadState {
        if downloadedModels.contains(where: { $0.modelId == modelId }) {
            return .downloaded
        }
        return downloadStates[modelId] ?? .notDownloaded
    }
    
    func isDownloaded(_ modelId: String) -> Bool {
        downloadedModels.contains { $0.modelId == modelId }
    }
    
    // MARK: - Download Model
    
    /// Whether to use resilient downloader (recommended for poor networks)
    @Published var useResilientDownloader: Bool = true
    
    func downloadModel(_ model: LocalLLMModel) async {
        guard !isDownloaded(model.id) else { return }
        guard downloadStates[model.id] != .downloading(progress: 0) else { return }
        
        // Use real MLX download if enabled and repository mapping exists
        if useRealMLXDownload {
            if MLXModelRepository.getRepositoryId(for: model.id) != nil {
                if useResilientDownloader {
                    print("📦 [ModelDownload] Using RESILIENT download for: \(model.displayName)")
                    await downloadResilientMLXModel(model)
                } else {
                    print("📦 [ModelDownload] Using standard download for: \(model.displayName)")
                    await downloadRealMLXModel(model)
                }
                return
            } else {
                print("⚠️ [ModelDownload] No MLX repo for \(model.id), using placeholder")
            }
        }
        
        // Placeholder download
        await downloadPlaceholderModel(model)
    }
    
    /// Downloads a placeholder model (for demo/testing)
    private func downloadPlaceholderModel(_ model: LocalLLMModel) async {
        downloadStates[model.id] = .downloading(progress: 0)
        
        do {
            let destinationURL = modelsDirectory.appendingPathComponent("\(model.id).mlx")
            
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            let totalSteps = 20
            for step in 1...totalSteps {
                try await Task.sleep(nanoseconds: 150_000_000)
                let progress = Double(step) / Double(totalSteps)
                downloadStates[model.id] = .downloading(progress: progress)
            }
            
            let modelMetadata: [String: Any] = [
                "id": model.id,
                "name": model.name,
                "displayName": model.displayName,
                "provider": model.provider,
                "parameterCount": model.parameterCount,
                "version": model.version,
                "downloadedAt": ISO8601DateFormatter().string(from: Date()),
                "status": "ready",
                "isPlaceholder": true,
                "note": "Placeholder model - enable Real MLX Downloads for actual AI"
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: modelMetadata, options: .prettyPrinted)
            try jsonData.write(to: destinationURL)
            
            let fileSize = model.sizeBytes
            
            let downloadedModel = DownloadedModel(
                id: UUID().uuidString,
                modelId: model.id,
                localPath: destinationURL.path,
                downloadedAt: Date(),
                sizeBytes: fileSize,
                isSelected: downloadedModels.isEmpty
            )
            
            downloadedModels.append(downloadedModel)
            saveDownloadedModels()
            
            if downloadedModels.count == 1 {
                selectModel(model.id)
            }
            
            downloadStates[model.id] = .downloaded
            calculateStorageUsed()
            
            print("✅ [ModelDownload] Successfully downloaded (placeholder): \(model.displayName)")
            
        } catch {
            downloadStates[model.id] = .failed(error: error.localizedDescription)
            print("❌ [ModelDownload] Failed to download \(model.displayName): \(error)")
        }
    }
    
    func downloadModelFromURL(_ model: LocalLLMModel) async {
        guard !isDownloaded(model.id) else { return }
        guard downloadStates[model.id] != .downloading(progress: 0) else { return }
        
        downloadStates[model.id] = .downloading(progress: 0)
        
        guard let url = URL(string: model.downloadURL) else {
            downloadStates[model.id] = .failed(error: "Invalid download URL")
            return
        }
        
        do {
            let destinationURL = modelsDirectory.appendingPathComponent("\(model.id).safetensors")
            
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            let configuration = URLSessionConfiguration.default
            configuration.allowsCellularAccess = true
            configuration.timeoutIntervalForRequest = 60
            configuration.timeoutIntervalForResource = 3600
            
            let (asyncBytes, response) = try await URLSession(configuration: configuration).bytes(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                downloadStates[model.id] = .failed(error: "Download failed (HTTP \(statusCode))")
                return
            }
            
            let expectedLength = httpResponse.expectedContentLength
            var downloadedData = Data()
            downloadedData.reserveCapacity(expectedLength > 0 ? Int(expectedLength) : model.sizeBytes > 0 ? Int(model.sizeBytes) : 1_000_000)
            
            var downloadedBytes: Int64 = 0
            
            for try await byte in asyncBytes {
                downloadedData.append(byte)
                downloadedBytes += 1
                
                if downloadedBytes % 100_000 == 0 {
                    let progress = expectedLength > 0 ? Double(downloadedBytes) / Double(expectedLength) : 0.5
                    downloadStates[model.id] = .downloading(progress: min(progress, 0.99))
                }
            }
            
            try downloadedData.write(to: destinationURL)
            
            let fileAttributes = try fileManager.attributesOfItem(atPath: destinationURL.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? model.sizeBytes
            
            let downloadedModel = DownloadedModel(
                id: UUID().uuidString,
                modelId: model.id,
                localPath: destinationURL.path,
                downloadedAt: Date(),
                sizeBytes: fileSize,
                isSelected: downloadedModels.isEmpty
            )
            
            downloadedModels.append(downloadedModel)
            saveDownloadedModels()
            
            if downloadedModels.count == 1 {
                selectModel(model.id)
            }
            
            downloadStates[model.id] = .downloaded
            calculateStorageUsed()
            
            print("✅ [ModelDownload] Successfully downloaded: \(model.displayName)")
            
        } catch {
            downloadStates[model.id] = .failed(error: error.localizedDescription)
            print("❌ [ModelDownload] Failed to download \(model.displayName): \(error)")
        }
    }
    
    func updateProgress(for modelId: String, progress: Double) {
        downloadStates[modelId] = .downloading(progress: progress)
    }
    
    // MARK: - Download Real MLX Model from Hugging Face
    
    /// Downloads a complete MLX model from Hugging Face (config, tokenizer, weights)
    func downloadRealMLXModel(_ model: LocalLLMModel) async {
        guard !isDownloaded(model.id) else { return }
        guard downloadStates[model.id] != .downloading(progress: 0) else { return }
        
        guard let repoId = MLXModelRepository.getRepositoryId(for: model.id) else {
            print("⚠️ [MLX Download] No repository mapping for \(model.id), using placeholder")
            await downloadPlaceholderModel(model)
            return
        }
        
        downloadStates[model.id] = .downloading(progress: 0)
        
        let modelDirectory = modelsDirectory.appendingPathComponent(model.id, isDirectory: true)
        
        do {
            // Create model directory
            try fileManager.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
            
            let baseURL = "https://huggingface.co/\(repoId)/resolve/main/"
            
            // Files to download (essential + model weights)
            let filesToDownload = [
                "config.json",
                "tokenizer.json",
                "tokenizer_config.json",
                "special_tokens_map.json",
                "model.safetensors"
            ]
            
            var successfulDownloads = 0
            var totalProgress: Double = 0
            let progressPerFile = 1.0 / Double(filesToDownload.count)
            
            for (index, fileName) in filesToDownload.enumerated() {
                currentDownloadFile = fileName
                
                let fileURL = URL(string: baseURL + fileName)!
                let destURL = modelDirectory.appendingPathComponent(fileName)
                
                // Skip if file exists
                if fileManager.fileExists(atPath: destURL.path) {
                    print("📦 [MLX Download] File exists, skipping: \(fileName)")
                    totalProgress += progressPerFile
                    successfulDownloads += 1
                    downloadStates[model.id] = .downloading(progress: totalProgress)
                    continue
                }
                
                print("⬇️ [MLX Download] Downloading: \(fileName) from \(repoId)")
                
                do {
                    let configuration = URLSessionConfiguration.default
                    configuration.timeoutIntervalForResource = 14400 // 4 hours for large files
                    configuration.timeoutIntervalForRequest = 600 // 10 minutes between data chunks
                    configuration.allowsExpensiveNetworkAccess = true
                    configuration.allowsConstrainedNetworkAccess = true
                    
                    let (asyncBytes, response) = try await URLSession(configuration: configuration).bytes(from: fileURL)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        print("⚠️ [MLX Download] No HTTP response for: \(fileName)")
                        if MLXModelRepository.requiredFiles.contains(fileName) {
                            throw MLXDownloadError.fileFailed(fileName)
                        }
                        totalProgress += progressPerFile
                        continue
                    }
                    
                    // Handle 404 for optional files
                    if httpResponse.statusCode == 404 {
                        print("⚠️ [MLX Download] File not found (404): \(fileName)")
                        if MLXModelRepository.requiredFiles.contains(fileName) {
                            throw MLXDownloadError.fileFailed(fileName)
                        }
                        totalProgress += progressPerFile
                        downloadStates[model.id] = .downloading(progress: totalProgress)
                        continue
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        print("⚠️ [MLX Download] HTTP \(httpResponse.statusCode) for: \(fileName)")
                        if MLXModelRepository.requiredFiles.contains(fileName) {
                            throw MLXDownloadError.fileFailed(fileName)
                        }
                        totalProgress += progressPerFile
                        continue
                    }
                    
                    let expectedLength = httpResponse.expectedContentLength
                    var downloadedData = Data()
                    var downloadedBytes: Int64 = 0
                    
                    // Reserve capacity for better performance
                    if expectedLength > 0 {
                        downloadedData.reserveCapacity(Int(expectedLength))
                    }
                    
                    for try await byte in asyncBytes {
                        downloadedData.append(byte)
                        downloadedBytes += 1
                        
                        // Update progress every 1MB
                        if downloadedBytes % 1_000_000 == 0 {
                            let fileProgress = expectedLength > 0 ? Double(downloadedBytes) / Double(expectedLength) : 0.5
                            let overallProgress = totalProgress + (fileProgress * progressPerFile)
                            downloadStates[model.id] = .downloading(progress: min(overallProgress, 0.99))
                            
                            let mbDownloaded = Double(downloadedBytes) / 1_000_000
                            let mbTotal = expectedLength > 0 ? Double(expectedLength) / 1_000_000 : 0
                            print("📊 [MLX Download] \(fileName): \(String(format: "%.1f", mbDownloaded))MB / \(String(format: "%.1f", mbTotal))MB")
                        }
                    }
                    
                    try downloadedData.write(to: destURL)
                    
                    successfulDownloads += 1
                    totalProgress += progressPerFile
                    downloadStates[model.id] = .downloading(progress: totalProgress)
                    
                    let fileSizeMB = Double(downloadedData.count) / 1_000_000
                    print("✅ [MLX Download] Downloaded: \(fileName) (\(String(format: "%.2f", fileSizeMB)) MB)")
                    
                } catch {
                    print("⚠️ [MLX Download] Error downloading \(fileName): \(error.localizedDescription)")
                    if MLXModelRepository.requiredFiles.contains(fileName) {
                        throw error
                    }
                    totalProgress += progressPerFile
                }
            }
            
            currentDownloadFile = nil
            
            // Calculate total size
            var totalSize: Int64 = 0
            if let enumerator = fileManager.enumerator(at: modelDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
                while let fileURL = enumerator.nextObject() as? URL {
                    let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path)
                    totalSize += attributes?[.size] as? Int64 ?? 0
                }
            }
            
            // Save downloaded model
            let downloadedModel = DownloadedModel(
                id: UUID().uuidString,
                modelId: model.id,
                localPath: modelDirectory.path,
                downloadedAt: Date(),
                sizeBytes: totalSize,
                isSelected: downloadedModels.isEmpty
            )
            
            downloadedModels.append(downloadedModel)
            saveDownloadedModels()
            
            if downloadedModels.count == 1 {
                selectModel(model.id)
            }
            
            downloadStates[model.id] = .downloaded
            calculateStorageUsed()
            
            print("✅ [MLX Download] Model ready: \(model.displayName) (\(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)))")
            
            // Auto-load the model into MLXModelRunner
            await autoLoadModel(model, from: modelDirectory)
            
        } catch {
            currentDownloadFile = nil
            downloadStates[model.id] = .failed(error: error.localizedDescription)
            
            // Cleanup on failure
            try? fileManager.removeItem(at: modelDirectory)
            
            print("❌ [MLX Download] Failed: \(error)")
        }
    }
    
    func cancelDownload(_ modelId: String) {
        downloadTasks[modelId]?.cancel()
        downloadTasks.removeValue(forKey: modelId)
        progressObservations[modelId]?.invalidate()
        progressObservations.removeValue(forKey: modelId)
        downloadStates[modelId] = .notDownloaded
        
        Task {
            await ResilientDownloader.shared.cancel(taskId: modelId)
        }
    }
    
    // MARK: - Resilient Download (Recommended for Poor Networks)
    
    /// Downloads MLX model using ResilientDownloader with parallel chunks and auto-resume
    /// Optimized for poor internet connections and mobile networks
    func downloadResilientMLXModel(_ model: LocalLLMModel) async {
        guard !isDownloaded(model.id) else { return }
        guard downloadStates[model.id] != .downloading(progress: 0) else { return }
        
        guard let repoId = MLXModelRepository.getRepositoryId(for: model.id) else {
            print("⚠️ [Resilient] No repository mapping for \(model.id), using placeholder")
            await downloadPlaceholderModel(model)
            return
        }
        
        downloadStates[model.id] = .downloading(progress: 0)
        
        let modelDirectory = modelsDirectory.appendingPathComponent(model.id, isDirectory: true)
        
        do {
            try fileManager.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
            
            let baseURL = "https://huggingface.co/\(repoId)/resolve/main/"
            
            let filesToDownload = MLXModelRepository.getFilesToDownload()
            
            // Use model's expected size for accurate progress calculation
            let totalExpectedBytes: Int64 = model.sizeBytes > 0 ? model.sizeBytes : 700_000_000
            
            // Expected size of model.safetensors (approximately 95% of total)
            let expectedModelFileSize: Int64 = Int64(Double(totalExpectedBytes) * 0.90)
            
            // Calculate base progress from ONLY small config files (not model.safetensors)
            // This prevents counting partial model files
            var baseDownloadedBytes: Int64 = 0
            for fileName in filesToDownload where fileName != "model.safetensors" {
                let destURL = modelDirectory.appendingPathComponent(fileName)
                if fileManager.fileExists(atPath: destURL.path) {
                    let attrs = try? fileManager.attributesOfItem(atPath: destURL.path)
                    let fileSize = attrs?[.size] as? Int64 ?? 0
                    if fileSize > 100 && fileSize < 50_000_000 { // Config files are < 50MB
                        baseDownloadedBytes += fileSize
                    }
                }
            }
            
            let downloader = ResilientDownloader.shared
            let config = downloader.optimalConfiguration()
            
            print("📦 [Resilient] Network: \(downloader.connectionType), Quality: \(downloader.networkQuality)")
            print("📦 [Resilient] Config: \(config.chunkSize / 1024)KB chunks, \(config.maxConcurrentChunks) concurrent")
            print("📦 [Resilient] Expected total: \(ByteCountFormatter.string(fromByteCount: totalExpectedBytes, countStyle: .file))")
            print("📦 [Resilient] Base offset (config files): \(ByteCountFormatter.string(fromByteCount: baseDownloadedBytes, countStyle: .file))")
            
            var downloadedBytes: Int64 = baseDownloadedBytes
            
            for fileName in filesToDownload {
                currentDownloadFile = fileName
                
                let fileURL = URL(string: baseURL + fileName)!
                let destURL = modelDirectory.appendingPathComponent(fileName)
                
                if fileManager.fileExists(atPath: destURL.path) {
                    let attrs = try? fileManager.attributesOfItem(atPath: destURL.path)
                    let fileSize = attrs?[.size] as? Int64 ?? 0
                    
                    // For model.safetensors, only skip if it's at least 90% of expected size
                    let isModelFile = fileName == "model.safetensors"
                    let minRequiredSize: Int64 = isModelFile ? expectedModelFileSize : 100
                    
                    if fileSize >= minRequiredSize {
                        print("📦 [Resilient] File complete: \(fileName) (\(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)))")
                        if isModelFile {
                            downloadedBytes += fileSize
                        }
                        let overallProgress = Double(downloadedBytes) / Double(totalExpectedBytes)
                        downloadStates[model.id] = .downloading(progress: min(overallProgress, 0.99))
                        continue
                    } else if fileSize > 0 {
                        // File is partial/incomplete, delete and re-download
                        print("⚠️ [Resilient] Partial file detected, re-downloading: \(fileName) (\(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)) < expected \(ByteCountFormatter.string(fromByteCount: minRequiredSize, countStyle: .file)))")
                        try? fileManager.removeItem(at: destURL)
                    }
                }
                
                // Use network-adaptive configuration for all files
                // The ResilientDownloader will auto-adjust chunk size based on file size
                let downloadConfig: DownloadConfiguration = downloader.optimalConfiguration()
                
                let chunkSizeKB = downloadConfig.chunkSize / 1024
                let concurrentChunks = downloadConfig.maxConcurrentChunks
                print("⬇️ [Resilient] Downloading: \(fileName)")
                print("   📊 Config: \(chunkSizeKB)KB chunks, \(concurrentChunks) concurrent, \(downloadConfig.maxRetries) retries")
                
                do {
                    var lastPrintedPercent = -10
                    var lastUIUpdate = Date.distantPast
                    var lastLoggedProgress: Double = -1
                    var maxProgressSeen: Double = 0  // Track highest progress (never go backwards)
                    
                    // Capture current downloaded bytes for this file's progress calculation
                    let progressBaseOffset = downloadedBytes
                    
                    _ = try await downloader.downloadAsync(
                        url: fileURL,
                        to: destURL,
                        configuration: downloadConfig
                    ) { [weak self] progress in
                        Task { @MainActor in
                            // Calculate overall progress: already downloaded + current file progress
                            let overallDownloaded = progressBaseOffset + progress.downloadedBytes
                            var overallProgress = Double(overallDownloaded) / Double(totalExpectedBytes)
                            
                            // Progress should only go UP, never backwards (prevents flickering)
                            if overallProgress > maxProgressSeen {
                                maxProgressSeen = overallProgress
                            } else {
                                overallProgress = maxProgressSeen
                            }
                            
                            let overallPercent = Int(overallProgress * 100)
                            
                            // Throttle UI updates to every 500ms to prevent flickering
                            let now = Date()
                            let timeSinceLastUpdate = now.timeIntervalSince(lastUIUpdate)
                            
                            if timeSinceLastUpdate >= 0.5 || progress.progress >= 0.99 {
                                lastUIUpdate = now
                                self?.downloadStates[model.id] = .downloading(progress: min(max(overallProgress, 0), 0.99))
                            }
                            
                            let percent = Int(progress.progress * 100)
                            
                            // Print every 10% file progress
                            let shouldPrint = percent >= lastPrintedPercent + 10 || 
                                              (overallProgress - lastLoggedProgress >= 0.05) ||
                                              percent >= 99
                            
                            if shouldPrint {
                                lastPrintedPercent = percent
                                lastLoggedProgress = overallProgress
                                
                                let downloaded = ByteCountFormatter.string(fromByteCount: progress.downloadedBytes, countStyle: .file)
                                let total = ByteCountFormatter.string(fromByteCount: progress.totalBytes, countStyle: .file)
                                let speed = progress.speedDescription
                                
                                if let eta = progress.etaDescription {
                                    print("   📦 File: \(percent)% (\(downloaded)/\(total)) | Overall: \(overallPercent)% | \(speed) | ETA: \(eta)")
                                } else {
                                    print("   📦 File: \(percent)% (\(downloaded)/\(total)) | Overall: \(overallPercent)% | \(speed)")
                                }
                            }
                        }
                    }
                    
                    // Add completed file size to running total
                    let attrs = try? fileManager.attributesOfItem(atPath: destURL.path)
                    let completedFileSize = attrs?[.size] as? Int64 ?? 0
                    downloadedBytes += completedFileSize
                    
                    let overallProgress = Double(downloadedBytes) / Double(totalExpectedBytes)
                    downloadStates[model.id] = .downloading(progress: min(overallProgress, 0.99))
                    print("✅ [Resilient] Downloaded: \(fileName) (\(ByteCountFormatter.string(fromByteCount: completedFileSize, countStyle: .file))) | Overall: \(Int(overallProgress * 100))%")
                    
                } catch {
                    print("⚠️ [Resilient] Error downloading \(fileName): \(error.localizedDescription)")
                    if MLXModelRepository.requiredFiles.contains(fileName) {
                        throw error
                    }
                }
            }
            
            currentDownloadFile = nil
            
            var totalSize: Int64 = 0
            if let enumerator = fileManager.enumerator(at: modelDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
                while let fileURL = enumerator.nextObject() as? URL {
                    let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path)
                    totalSize += attributes?[.size] as? Int64 ?? 0
                }
            }
            
            let downloadedModel = DownloadedModel(
                id: UUID().uuidString,
                modelId: model.id,
                localPath: modelDirectory.path,
                downloadedAt: Date(),
                sizeBytes: totalSize,
                isSelected: downloadedModels.isEmpty
            )
            
            downloadedModels.append(downloadedModel)
            saveDownloadedModels()
            
            downloadStates[model.id] = .downloaded
            calculateStorageUsed()
            
            print("✅ [Resilient] Model ready: \(model.displayName) (\(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)))")
            
            // Select and auto-load the model (selectModel already calls autoLoadModel)
            if downloadedModels.count == 1 || selectedModelId == nil {
                selectModel(model.id)
            } else {
                // Auto-load without selecting if another model is already selected
                await autoLoadModel(model, from: modelDirectory)
            }
            
        } catch {
            currentDownloadFile = nil
            downloadStates[model.id] = .failed(error: error.localizedDescription)
            try? fileManager.removeItem(at: modelDirectory)
            print("❌ [Resilient] Failed: \(error)")
        }
    }
    
    /// Check for resumable downloads and resume them
    func resumePendingDownloads() async {
        let resumables = await ResilientDownloader.shared.getResumableDownloads()
        
        for state in resumables {
            let modelId = state.destination.deletingLastPathComponent().lastPathComponent
            print("📦 [Resume] Found resumable download for: \(modelId)")
            
            downloadStates[modelId] = .downloading(progress: state.progress)
            
            do {
                _ = try await ResilientDownloader.shared.resume(taskId: state.id) { [weak self] progress in
                    Task { @MainActor in
                        self?.downloadStates[modelId] = .downloading(progress: progress.progress)
                    }
                }
                downloadStates[modelId] = .downloaded
                print("✅ [Resume] Completed: \(modelId)")
            } catch {
                downloadStates[modelId] = .failed(error: error.localizedDescription)
                print("❌ [Resume] Failed: \(error)")
            }
        }
    }
    
    // MARK: - Auto-Load Model After Download
    
    /// Automatically loads the downloaded model into MLXModelRunner
    private func autoLoadModel(_ model: LocalLLMModel, from directory: URL) async {
        print("🔄 [AutoLoad] Loading model into MLXModelRunner: \(model.displayName)")
        
        do {
            try await MLXModelRunner.shared.loadModel(from: directory, modelName: model.displayName)
            print("✅ [AutoLoad] Model loaded successfully: \(model.displayName)")
            print("✅ [AutoLoad] MLX Status: \(MLXModelRunner.shared.mlxStatusDescription)")
        } catch {
            print("⚠️ [AutoLoad] Failed to load model: \(error.localizedDescription)")
            print("📝 [AutoLoad] Model files are ready, will load on next use")
        }
    }
    
    // MARK: - Delete Model
    
    func deleteModel(_ modelId: String) {
        guard let index = downloadedModels.firstIndex(where: { $0.modelId == modelId }) else { return }
        
        let model = downloadedModels[index]
        
        do {
            if fileManager.fileExists(atPath: model.localPath) {
                try fileManager.removeItem(atPath: model.localPath)
            }
            
            downloadedModels.remove(at: index)
            saveDownloadedModels()
            downloadStates[modelId] = .notDownloaded
            
            if selectedModelId == modelId {
                selectedModelId = downloadedModels.first?.modelId
                saveSelectedModel()
            }
            
            calculateStorageUsed()
            print("✅ [ModelDownload] Deleted model: \(modelId)")
            
        } catch {
            print("❌ [ModelDownload] Failed to delete model: \(error)")
        }
    }
    
    func deleteAllModels() {
        for model in downloadedModels {
            try? fileManager.removeItem(atPath: model.localPath)
        }
        
        downloadedModels.removeAll()
        downloadStates.removeAll()
        selectedModelId = nil
        totalStorageUsed = 0
        
        saveDownloadedModels()
        saveSelectedModel()
        
        print("✅ [ModelDownload] All models deleted")
    }
    
    // MARK: - Model Selection
    
    func selectModel(_ modelId: String) {
        guard downloadedModels.contains(where: { $0.modelId == modelId }) else { return }
        
        selectedModelId = modelId
        saveSelectedModel()
        
        print("✅ [ModelDownload] Selected model: \(modelId)")
        
        // Auto-load the selected model
        if let model = ModelCatalog.model(withId: modelId),
           let modelPath = localPath(for: modelId) {
            Task {
                await autoLoadModel(model, from: modelPath)
            }
        }
    }
    
    var selectedModel: LocalLLMModel? {
        guard let id = selectedModelId else { return nil }
        return ModelCatalog.model(withId: id)
    }
    
    // MARK: - Storage
    
    var storageUsedFormatted: String {
        if totalStorageUsed == 0 {
            return "Zero kB"
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalStorageUsed)
    }
    
    private func calculateStorageUsed() {
        totalStorageUsed = downloadedModels.reduce(0) { $0 + $1.sizeBytes }
    }
    
    // MARK: - Persistence
    
    private func loadDownloadedModels() {
        guard let data = UserDefaults.standard.data(forKey: downloadedModelsKey),
              let models = try? JSONDecoder().decode([DownloadedModel].self, from: data) else {
            downloadedModels = []
            return
        }
        
        downloadedModels = models.filter { fileManager.fileExists(atPath: $0.localPath) }
        
        if downloadedModels.count != models.count {
            saveDownloadedModels()
        }
        
        for model in downloadedModels {
            downloadStates[model.modelId] = .downloaded
        }
    }
    
    private func saveDownloadedModels() {
        guard let data = try? JSONEncoder().encode(downloadedModels) else { return }
        UserDefaults.standard.set(data, forKey: downloadedModelsKey)
    }
    
    private func loadSelectedModel() {
        selectedModelId = UserDefaults.standard.string(forKey: selectedModelKey)
        
        if let id = selectedModelId, !downloadedModels.contains(where: { $0.modelId == id }) {
            selectedModelId = downloadedModels.first?.modelId
            saveSelectedModel()
        }
    }
    
    private func saveSelectedModel() {
        if let id = selectedModelId {
            UserDefaults.standard.set(id, forKey: selectedModelKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedModelKey)
        }
    }
    
    // MARK: - Model Path
    
    func localPath(for modelId: String) -> URL? {
        guard let model = downloadedModels.first(where: { $0.modelId == modelId }) else { return nil }
        return URL(fileURLWithPath: model.localPath)
    }
}

// MARK: - MLX Download Error

enum MLXDownloadError: Error, LocalizedError {
    case noRepositoryMapping
    case fileFailed(String)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .noRepositoryMapping:
            return "No MLX repository found for this model"
        case .fileFailed(let file):
            return "Failed to download: \(file)"
        case .invalidResponse:
            return "Invalid response from Hugging Face"
        }
    }
}

// MARK: - Download Delegate

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let modelId: String
    private weak var manager: ModelDownloadManager?
    
    init(modelId: String, manager: ModelDownloadManager) {
        self.modelId = modelId
        self.manager = manager
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.manager?.updateProgress(for: self.modelId, progress: progress)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    }
}
