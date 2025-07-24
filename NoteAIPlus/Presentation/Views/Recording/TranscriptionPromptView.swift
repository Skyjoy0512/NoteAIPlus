import SwiftUI

struct TranscriptionPromptView: View {
    let recording: Recording
    let onTranscribe: (Recording) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedModel: WhisperModelType = .base
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                headerView
                
                // Recording info
                recordingInfoView
                
                // Model selection
                modelSelectionView
                
                Spacer()
                
                // Action buttons
                actionButtonsView
            }
            .padding()
            .navigationTitle("文字起こし")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("後で") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("録音を文字起こししますか？")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text("AIが録音内容を自動で文字起こしします")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var recordingInfoView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.title)
                        .font(.headline)
                    
                    HStack {
                        Text(recording.formattedDuration)
                        Text("•")
                        Text(recording.date, style: .date)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var modelSelectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("モデル選択")
                .font(.headline)
            
            Text("より大きなモデルほど精度が向上しますが、処理時間が長くなります")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                ForEach([WhisperModelType.tiny, .base, .small], id: \.rawValue) { model in
                    modelOptionView(model)
                }
            }
        }
    }
    
    private func modelOptionView(_ model: WhisperModelType) -> some View {
        Button(action: {
            selectedModel = model
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(modelDescription(model))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: selectedModel == model ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedModel == model ? .blue : .secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selectedModel == model ? Color.blue : Color(.systemGray4), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedModel == model ? Color.blue.opacity(0.1) : Color.clear)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            Button(action: {
                onTranscribe(recording)
            }) {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("文字起こしを開始")
                }
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .cornerRadius(12)
            }
            
            Button("後で実行する") {
                dismiss()
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }
    
    private func modelDescription(_ model: WhisperModelType) -> String {
        switch model {
        case .tiny:
            return "最速・最小サイズ（\(ByteCountFormatter().string(fromByteCount: model.fileSize))）"
        case .base:
            return "推奨・バランス型（\(ByteCountFormatter().string(fromByteCount: model.fileSize))）"
        case .small:
            return "高精度・大サイズ（\(ByteCountFormatter().string(fromByteCount: model.fileSize))）"
        case .medium:
            return "最高精度・Pro版（\(ByteCountFormatter().string(fromByteCount: model.fileSize))）"
        }
    }
}

struct TranscriptionPromptView_Previews: PreviewProvider {
    static var previews: some View {
        TranscriptionPromptView(
            recording: Recording(
                title: "テスト録音",
                fileURL: URL(fileURLWithPath: "/tmp/test.m4a"),
                duration: 120.0,
                date: Date()
            )
        ) { _ in
            // Preview action
        }
    }
}