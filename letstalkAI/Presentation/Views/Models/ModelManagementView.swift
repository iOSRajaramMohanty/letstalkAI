//
//  ModelManagementView.swift
//  letstalkAI
//
//  Model management view - Browse, download, and manage local LLM models
//

import SwiftUI

struct ModelManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var downloadManager = ModelDownloadManager.shared
    @State private var showDeleteAllAlert = false
    @State private var showModelSizeInfo = true
    @State private var selectedFamily: ModelFamily?
    @State private var showLegacyModels = false
    @State private var showExperimentalModels = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if showModelSizeInfo {
                        modelSizeInfoCard
                    }
                    
                    featuredSection
                    
                    if !ModelCatalog.legacyFamilies.isEmpty {
                        legacySection
                    }
                    
                    if !ModelCatalog.experimentalFamilies.isEmpty {
                        experimentalSection
                    }
                    
                    storageSection
                }
                .padding()
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Manage models")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                    }
                }
            }
            #elseif os(macOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .frame(minWidth: 500, minHeight: 600)
            #endif
            .sheet(item: $selectedFamily) { family in
                ModelFamilyDetailView(family: family)
            }
            .sheet(isPresented: $showLegacyModels) {
                LegacyModelsView()
            }
            .sheet(isPresented: $showExperimentalModels) {
                ExperimentalModelsView()
            }
            .alert("Delete All Models", isPresented: $showDeleteAllAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete All", role: .destructive) {
                    downloadManager.deleteAllModels()
                }
            } message: {
                Text("This will delete all downloaded models and free up \(downloadManager.storageUsedFormatted) of storage. This action cannot be undone.")
            }
        }
    }
    
    private var backgroundColor: Color {
        #if os(iOS)
        Color(.systemGroupedBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }
    
    private var cardBackground: Color {
        #if os(iOS)
        Color(.secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }
    
    // MARK: - Model Size Info Card
    
    private var modelSizeInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Understanding Model Sizes")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button {
                    withAnimation {
                        showModelSizeInfo = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Circle().fill(Color.gray.opacity(0.2)))
                }
            }
            
            Text("Local models come in different sizes, defined by their number of parameters, usually measured in billions (e.g., 0.6B, 1B, 3B). Bigger models are usually smarter, but also slower, as they use more memory and processing power. Choose a model that balances speed and quality for your needs.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Featured Section
    
    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Featured")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                ForEach(Array(ModelCatalog.featuredFamilies.enumerated()), id: \.element.id) { index, family in
                    modelFamilyRow(family)
                    
                    if index < ModelCatalog.featuredFamilies.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - Legacy Section
    
    private var legacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                showLegacyModels = true
            } label: {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Legacy models")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        
                        Text("Legacy models are older versions that may have limited functionality or performance compared to current models.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Experimental Section
    
    private var experimentalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                showExperimentalModels = true
            } label: {
                HStack {
                    Image(systemName: "flask.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.purple)
                        .frame(width: 32, height: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Experimental models")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        
                        Text("Experimental models may be unstable, lead to frequent crashes and produce unexpected results.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Storage Section
    
    private var storageSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Storage used")
                    .font(.body)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(downloadManager.storageUsedFormatted)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            if !downloadManager.downloadedModels.isEmpty {
                Button {
                    showDeleteAllAlert = true
                } label: {
                    Text("Delete all models")
                        .font(.body)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            
            Text("On-device AI models may produce inaccurate or incomplete information.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }
    
    // MARK: - Model Family Row
    
    private func modelFamilyRow(_ family: ModelFamily) -> some View {
        Button {
            selectedFamily = family
        } label: {
            HStack(spacing: 12) {
                providerIcon(family.providerIcon, provider: family.provider)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(family.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Text(family.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    
                    HStack(spacing: 4) {
                        Text("\(family.modelCount) model\(family.modelCount > 1 ? "s" : "")")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        
                        if !family.capabilities.isEmpty || !family.tags.isEmpty {
                            tagsView(capabilities: family.capabilities, tags: family.tags)
                        }
                        
                        // Show MLX badge if any model in family has MLX support
                        if familyHasMLXSupport(family) {
                            HStack(spacing: 2) {
                                Image(systemName: "cpu.fill")
                                    .font(.system(size: 8))
                                Text("MLX")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding()
        }
        .buttonStyle(.plain)
    }
    
    private func providerIcon(_ iconName: String, provider: String) -> some View {
        Group {
            if provider == "Google" {
                Text("G")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .red, .yellow, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else if provider == "Meta" {
                Image(systemName: "infinity")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.blue)
            } else if provider == "Qwen" {
                Image(systemName: "sparkles")
                    .font(.system(size: 18))
                    .foregroundStyle(.purple)
            } else if provider == "Liquid AI" {
                Image(systemName: "drop.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.orange)
            } else if provider == "IBM" {
                Text("IBM")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.blue)
            } else {
                Image(systemName: iconName)
                    .font(.system(size: 18))
                    .foregroundStyle(.green)
            }
        }
        .frame(width: 32, height: 32)
    }
    
    private func tagsView(capabilities: [ModelCapability], tags: [ModelTag]) -> some View {
        HStack(spacing: 6) {
            ForEach(capabilities.prefix(2), id: \.self) { capability in
                HStack(spacing: 2) {
                    Image(systemName: capability == .vision ? "eye" : "lightbulb.fill")
                        .font(.system(size: 8))
                    Text(capability.displayName)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(capability.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(capability.color.opacity(0.15))
                .clipShape(Capsule())
            }
            
            ForEach(tags.prefix(2), id: \.self) { tag in
                HStack(spacing: 2) {
                    if tag == .new {
                        Image(systemName: "sparkle")
                            .font(.system(size: 8))
                    } else if tag == .best {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 8))
                    } else if tag == .recommended {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 8))
                    }
                    Text(tag.displayName)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(tag.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(tag.color.opacity(0.15))
                .clipShape(Capsule())
            }
        }
    }
    
    // MARK: - MLX Support Badge
    
    private func mlxSupportBadge(for modelId: String) -> some View {
        Group {
            if MLXModelRepository.getRepositoryId(for: modelId) != nil {
                HStack(spacing: 2) {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 8))
                    Text("MLX")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.blue)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.blue.opacity(0.15))
                .clipShape(Capsule())
            }
        }
    }
    
    /// Check if any model in the family has MLX support
    private func familyHasMLXSupport(_ family: ModelFamily) -> Bool {
        family.models.contains { MLXModelRepository.getRepositoryId(for: $0.id) != nil }
    }
    
    /// Count of MLX supported models in family
    private func mlxModelCount(in family: ModelFamily) -> Int {
        family.models.filter { MLXModelRepository.getRepositoryId(for: $0.id) != nil }.count
    }
}

// MARK: - Legacy Models View

struct LegacyModelsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var downloadManager = ModelDownloadManager.shared
    
    private var legacyModels: [LocalLLMModel] {
        ModelCatalog.legacyFamilies.flatMap { $0.models }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(legacyModels) { model in
                        modelCard(model)
                    }
                }
                .padding()
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Legacy models")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                    }
                }
            }
            #elseif os(macOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                    }
                }
            }
            .frame(minWidth: 400, minHeight: 500)
            #endif
        }
    }
    
    private var backgroundColor: Color {
        #if os(iOS)
        Color(.systemGroupedBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }
    
    private var cardBackground: Color {
        #if os(iOS)
        Color(.secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }
    
    private func modelCard(_ model: LocalLLMModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                providerIcon(model.provider)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                downloadButton(for: model)
            }
            
            Text(model.platformDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
            
            Text(model.sizeFormatted)
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            HStack(spacing: 6) {
                // MLX support badge
                if MLXModelRepository.getRepositoryId(for: model.id) != nil {
                    HStack(spacing: 2) {
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 8))
                        Text("MLX")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.15))
                    .clipShape(Capsule())
                }
                
                // Capability badges
                ForEach(model.capabilities, id: \.self) { capability in
                    HStack(spacing: 2) {
                        Image(systemName: capability.iconName)
                            .font(.system(size: 8))
                        Text(capability.displayName)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(capability.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(capability.color.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    @ViewBuilder
    private func downloadButton(for model: LocalLLMModel) -> some View {
        let state = downloadManager.downloadState(for: model.id)
        
        switch state {
        case .notDownloaded:
            Button {
                Task {
                    await downloadManager.downloadModel(model)
                }
            } label: {
                Text("Download")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
        case .downloading(let progress):
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
        case .downloaded:
            Button {
                downloadManager.deleteModel(model.id)
            } label: {
                Text("Delete")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
        case .failed:
            Button {
                Task {
                    await downloadManager.downloadModel(model)
                }
            } label: {
                Text("Retry")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }
    
    private func providerIcon(_ provider: String) -> some View {
        Group {
            if provider == "Google" {
                Text("G")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .red, .yellow, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else if provider == "IBM" {
                Text("IBM")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.blue)
            } else if provider == "Qwen" {
                Image(systemName: "sparkles")
                    .font(.system(size: 18))
                    .foregroundStyle(.purple)
            } else {
                Image(systemName: "cpu")
                    .font(.system(size: 18))
                    .foregroundStyle(.blue)
            }
        }
        .frame(width: 32, height: 32)
    }
}

// MARK: - Experimental Models View

struct ExperimentalModelsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var downloadManager = ModelDownloadManager.shared
    
    private var experimentalModels: [LocalLLMModel] {
        ModelCatalog.experimentalFamilies.flatMap { $0.models }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(experimentalModels.enumerated()), id: \.element.id) { index, model in
                        modelCard(model)
                        
                        if index < experimentalModels.count - 1 {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding()
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Experimental models")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                    }
                }
            }
            #elseif os(macOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                    }
                }
            }
            .frame(minWidth: 400, minHeight: 500)
            #endif
        }
    }
    
    private var backgroundColor: Color {
        #if os(iOS)
        Color(.systemGroupedBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }
    
    private var cardBackground: Color {
        #if os(iOS)
        Color(.secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }
    
    private func modelCard(_ model: LocalLLMModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                providerIcon(model.provider)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                downloadButton(for: model)
            }
            
            Text(model.platformDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
            
            Text(model.sizeFormatted)
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            HStack(spacing: 6) {
                // MLX support badge
                if MLXModelRepository.getRepositoryId(for: model.id) != nil {
                    HStack(spacing: 2) {
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 8))
                        Text("MLX")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.15))
                    .clipShape(Capsule())
                }
                
                // Capability badges
                ForEach(model.capabilities, id: \.self) { capability in
                    HStack(spacing: 2) {
                        Image(systemName: capability.iconName)
                            .font(.system(size: 8))
                        Text(capability.displayName)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(capability.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(capability.color.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private func downloadButton(for model: LocalLLMModel) -> some View {
        let state = downloadManager.downloadState(for: model.id)
        
        switch state {
        case .notDownloaded:
            Button {
                Task {
                    await downloadManager.downloadModel(model)
                }
            } label: {
                Text("Down-\nload")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            
        case .downloading(let progress):
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
        case .downloaded:
            Button {
                downloadManager.deleteModel(model.id)
            } label: {
                Text("Delete")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            
        case .failed:
            Button {
                Task {
                    await downloadManager.downloadModel(model)
                }
            } label: {
                Text("Retry")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }
    
    private func providerIcon(_ provider: String) -> some View {
        Group {
            if provider == "Gökdeniz Gülmez" {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.orange)
            } else if provider == "Dolphin AI" {
                Image(systemName: "fish.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
            } else {
                Image(systemName: "cpu")
                    .font(.system(size: 18))
                    .foregroundStyle(.purple)
            }
        }
        .frame(width: 32, height: 32)
    }
}

#Preview {
    ModelManagementView()
}
