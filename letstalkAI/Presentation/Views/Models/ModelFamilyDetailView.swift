//
//  ModelFamilyDetailView.swift
//  letstalkAI
//
//  Detail view showing models within a family
//

import SwiftUI

struct ModelFamilyDetailView: View {
    let family: ModelFamily
    @Environment(\.dismiss) private var dismiss
    @StateObject private var downloadManager = ModelDownloadManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(family.models) { model in
                        modelCard(model)
                    }
                }
                .padding()
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle(family.name)
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
            #endif
        }
        .frame(minWidth: 400, minHeight: 500)
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
                providerIcon(model.providerIcon, provider: model.provider)
                
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
            
            if !model.capabilities.isEmpty || !model.tags.isEmpty {
                tagsView(model: model)
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
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
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
    
    private func tagsView(model: LocalLLMModel) -> some View {
        HStack(spacing: 6) {
            // MLX support badge - show first if supported
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
            
            ForEach(model.capabilities, id: \.self) { capability in
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
            
            ForEach(model.tags, id: \.self) { tag in
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
}

#Preview {
    ModelFamilyDetailView(family: ModelCatalog.families.first!)
}
