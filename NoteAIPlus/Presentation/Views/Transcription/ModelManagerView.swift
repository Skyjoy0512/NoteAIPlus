import SwiftUI

struct ModelManagerView: View {
    
    @ObservedObject var viewModel: TranscriptionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var modelToDelete: WhisperModelType?
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Header info
                    headerView
                    
                    // Models list
                    ForEach(viewModel.availableModels, id: \.rawValue) { model in
                        modelRowView(model)
                    }
                }
                .padding()
            }
            .navigationTitle("モデル管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
        .confirmationDialog(
            "モデルを削除しますか？",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            if let model = modelToDelete {
                Button("削除", role: .destructive) {
                    Task {
                        await viewModel.deleteModel(model)
                    }
                }
                Button("キャンセル", role: .cancel) { }
            }
        } message: {
            if let model = modelToDelete {
                Text("\(model.displayName)を削除すると、文字起こしで使用できなくなります。")
            }
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Whisperモデル")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Text("より高精度な文字起こしを行うには、大きなモデルをダウンロードしてください。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Storage info
            storageInfoView
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var storageInfoView: some View {
        HStack {
            Image(systemName: "internaldrive")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("ストレージ使用量")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("計算中...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.top, 8)
    }
    
    private func modelRowView(_ model: WhisperModelType) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Model icon
                ZStack {
                    Circle()
                        .fill(modelIconBackground(model))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: modelIconName(model))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(modelIconColor(model))
                }
                
                // Model info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        modelStatusBadge(model)
                    }
                    
                    Text(modelDescription(model))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Model specs
                    HStack(spacing: 12) {
                        specItem("サイズ", ByteCountFormatter().string(fromByteCount: model.fileSize))
                        specItem("精度", String(format: "%.0f%%", model.expectedAccuracy * 100))
                        
                        if model.isProOnly {
                            Text("Pro")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            // Download/Delete button
            if viewModel.downloadedModels.contains(model) {
                downloadedModelActions(model)
            } else {
                downloadModelButton(model)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func specItem(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
    
    private func modelStatusBadge(_ model: WhisperModelType) -> some View {
        Group {
            if viewModel.downloadedModels.contains(model) {
                Label("ダウンロード済み", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                    .labelStyle(.iconOnly)
            } else if viewModel.isDownloadingModel && viewModel.modelDownloadProgress[model] != nil {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Label("未ダウンロード", systemImage: "icloud.and.arrow.down")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .labelStyle(.iconOnly)
            }
        }
    }
    
    private func downloadModelButton(_ model: WhisperModelType) -> some View {
        VStack(spacing: 8) {
            if let progress = viewModel.modelDownloadProgress[model] {
                // Download progress
                VStack(spacing: 4) {
                    HStack {
                        Text("ダウンロード中...")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                }
                .padding(.top, 12)
            } else {
                Button(action: {
                    Task {
                        await viewModel.downloadModel(model)
                    }
                }) {
                    HStack {
                        Image(systemName: "icloud.and.arrow.down")
                        Text("ダウンロード")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        model.isProOnly && !isProUser ? Color.gray : Color.blue
                    )
                    .cornerRadius(8)
                }
                .disabled(model.isProOnly && !isProUser)
                .padding(.top, 12)
                
                if model.isProOnly && !isProUser {
                    Text("Pro版でご利用いただけます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
    }
    
    private func downloadedModelActions(_ model: WhisperModelType) -> some View {
        HStack(spacing: 12) {
            // Selected indicator for current model
            if viewModel.selectedModel == model {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("選択中")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            } else {
                Button("選択") {
                    viewModel.selectedModel = model
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            Button("削除") {
                modelToDelete = model
                showingDeleteConfirmation = true
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(.top, 12)
    }
    
    // MARK: - Helper Methods
    
    private func modelIconName(_ model: WhisperModelType) -> String {
        switch model {
        case .tiny: return "bolt"
        case .base: return "brain"
        case .small: return "cpu"
        case .medium: return "memorychip"
        }
    }
    
    private func modelIconColor(_ model: WhisperModelType) -> Color {
        switch model {
        case .tiny: return .green
        case .base: return .blue
        case .small: return .orange
        case .medium: return .purple
        }
    }
    
    private func modelIconBackground(_ model: WhisperModelType) -> Color {
        modelIconColor(model).opacity(0.2)
    }
    
    private func modelDescription(_ model: WhisperModelType) -> String {
        switch model {
        case .tiny:
            return "最小サイズ。高速処理が必要で精度は重視しない場合に適しています。"
        case .base:
            return "バランスの取れた推奨モデル。ほとんどの用途に適しており、速度と精度を両立します。"
        case .small:
            return "高精度モデル。重要な会議や講義など、正確な文字起こしが必要な場合におすすめです。"
        case .medium:
            return "最高精度モデル。プロフェッショナル用途や最高品質の文字起こしが必要な場合に使用します。"
        }
    }
    
    private var isProUser: Bool {
        // TODO: Implement proper Pro subscription check
        return true
    }
}

struct ModelManagerView_Previews: PreviewProvider {
    static var previews: some View {
        ModelManagerView(viewModel: TranscriptionViewModel())
    }
}