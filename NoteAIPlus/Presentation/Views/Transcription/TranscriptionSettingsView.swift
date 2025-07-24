import SwiftUI

struct TranscriptionSettingsView: View {
    
    @ObservedObject var viewModel: TranscriptionViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempOptions = TranscriptionOptions()
    @State private var showingCustomDictionaryEditor = false
    @State private var newDictionaryEntry = ""
    
    var body: some View {
        NavigationView {
            Form {
                // Model Selection
                modelSelectionSection
                
                // Quality Settings
                qualitySettingsSection
                
                // Processing Options
                processingOptionsSection
                
                // Post-processing
                postProcessingSection
                
                // Performance Settings
                performanceSection
                
                // Custom Dictionary
                customDictionarySection
            }
            .navigationTitle("文字起こし設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveSettings()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    // MARK: - Form Sections
    
    private var modelSelectionSection: some View {
        Section {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Whisperモデル")
                        .font(.headline)
                    
                    Text(viewModel.selectedModel.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                NavigationLink("変更") {
                    ModelSelectionView(selectedModel: $viewModel.selectedModel, availableModels: viewModel.availableModels, downloadedModels: viewModel.downloadedModels)
                }
                .font(.subheadline)
            }
            .contentShape(Rectangle())
        } header: {
            Text("モデル設定")
        } footer: {
            Text("より大きなモデルほど精度が向上しますが、処理時間とストレージを多く消費します。")
        }
    }
    
    private var qualitySettingsSection: some View {
        Section {
            // Temperature
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Temperature")
                    Spacer()
                    Text(String(format: "%.1f", tempOptions.temperature))
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $tempOptions.temperature, in: 0.0...1.0, step: 0.1)
                    .accentColor(.blue)
                
                Text("値が高いほど創造的だが不安定、低いほど安定的だが保守的な出力になります。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Compression Ratio Threshold
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("圧縮率閾値")
                    Spacer()
                    Text(String(format: "%.1f", tempOptions.compressionRatioThreshold))
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $tempOptions.compressionRatioThreshold, in: 1.0...5.0, step: 0.1)
                    .accentColor(.blue)
                
                Text("異常に反復的な出力を検出するための閾値です。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // No Speech Threshold
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("無音検出閾値")
                    Spacer()
                    Text(String(format: "%.1f", tempOptions.noSpeechThreshold))
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $tempOptions.noSpeechThreshold, in: 0.0...1.0, step: 0.1)
                    .accentColor(.blue)
                
                Text("音声がないセグメントを検出するための閾値です。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("品質設定")
        }
    }
    
    private var processingOptionsSection: some View {
        Section {
            // Noise Reduction
            Toggle(isOn: $tempOptions.enableNoiseReduction) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ノイズ除去")
                    Text("背景雑音を軽減します")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if tempOptions.enableNoiseReduction {
                Picker("ノイズ除去レベル", selection: $tempOptions.noiseReductionLevel) {
                    ForEach(NoiseReductionLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Speaker Diarization
            Toggle(isOn: $tempOptions.enableSpeakerDiarization) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("話者分離")
                        if tempOptions.enableSpeakerDiarization {
                            Text("Pro")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(3)
                        }
                    }
                    Text("複数の話者を識別します（Pro版機能）")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(!isProUser)
            
            if tempOptions.enableSpeakerDiarization {
                Stepper(value: $tempOptions.maxSpeakers, in: 2...10) {
                    HStack {
                        Text("最大話者数")
                        Spacer()
                        Text("\(tempOptions.maxSpeakers)人")
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("処理オプション")
        }
    }
    
    private var postProcessingSection: some View {
        Section {
            Toggle(isOn: $tempOptions.enablePunctuationInsertion) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("句読点の自動挿入")
                    Text("文章を読みやすくします")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Toggle(isOn: $tempOptions.enableParagraphBreaks) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("段落の自動分割")
                    Text("長い沈黙で段落を分けます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Toggle(isOn: $tempOptions.enableWordTimestamps) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("単語レベルタイムスタンプ")
                    Text("各単語の時刻情報を記録します")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("後処理")
        }
    }
    
    private var performanceSection: some View {
        Section {
            Toggle(isOn: $tempOptions.conditionOnPreviousText) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("前のテキストを考慮")
                    Text("文脈を考慮してより自然な出力を生成します")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("チャンク長")
                    Spacer()
                    Text("\(Int(tempOptions.chunkLength))秒")
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $tempOptions.chunkLength, in: 10...60, step: 5)
                    .accentColor(.blue)
                
                Text("長い音声を分割する際の単位です。短いほどメモリ使用量が少なくなります。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("パフォーマンス")
        }
    }
    
    private var customDictionarySection: some View {
        Section {
            ForEach(tempOptions.customDictionary, id: \.self) { entry in
                HStack {
                    Text(entry)
                    Spacer()
                    Button("削除") {
                        tempOptions.customDictionary.removeAll { $0 == entry }
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
            .onDelete { indexSet in
                tempOptions.customDictionary.remove(atOffsets: indexSet)
            }
            
            HStack {
                TextField("新しい辞書エントリ", text: $newDictionaryEntry)
                
                Button("追加") {
                    if !newDictionaryEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        tempOptions.customDictionary.append(newDictionaryEntry.trimmingCharacters(in: .whitespacesAndNewlines))
                        newDictionaryEntry = ""
                    }
                }
                .disabled(newDictionaryEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } header: {
            Text("カスタム辞書")
        } footer: {
            Text("よく使用する専門用語や固有名詞を追加すると、認識精度が向上します。")
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadCurrentSettings() {
        // Load current settings - for now use defaults
        tempOptions = TranscriptionOptions()
        tempOptions.modelType = viewModel.selectedModel
    }
    
    private func saveSettings() {
        // Save settings to UserDefaults or Core Data
        UserDefaults.standard.set(tempOptions.enableNoiseReduction, forKey: "transcription.enableNoiseReduction")
        UserDefaults.standard.set(tempOptions.enableSpeakerDiarization, forKey: "transcription.enableSpeakerDiarization")
        UserDefaults.standard.set(tempOptions.enablePunctuationInsertion, forKey: "transcription.enablePunctuationInsertion")
        UserDefaults.standard.set(tempOptions.enableParagraphBreaks, forKey: "transcription.enableParagraphBreaks")
        UserDefaults.standard.set(tempOptions.enableWordTimestamps, forKey: "transcription.enableWordTimestamps")
        UserDefaults.standard.set(tempOptions.temperature, forKey: "transcription.temperature")
        UserDefaults.standard.set(tempOptions.chunkLength, forKey: "transcription.chunkLength")
        
        // Update selected model
        viewModel.selectedModel = tempOptions.modelType
    }
    
    private var isProUser: Bool {
        // TODO: Implement proper Pro subscription check
        return true
    }
}

// MARK: - Model Selection View

struct ModelSelectionView: View {
    @Binding var selectedModel: WhisperModelType
    let availableModels: [WhisperModelType]
    let downloadedModels: Set<WhisperModelType>
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            ForEach(availableModels, id: \.rawValue) { model in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("精度: \(String(format: "%.0f%%", model.expectedAccuracy * 100))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if downloadedModels.contains(model) {
                        if selectedModel == model {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("未DL")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if downloadedModels.contains(model) {
                        selectedModel = model
                        dismiss()
                    }
                }
                .disabled(!downloadedModels.contains(model))
            }
        }
        .navigationTitle("モデル選択")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TranscriptionSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        TranscriptionSettingsView(viewModel: TranscriptionViewModel())
    }
}