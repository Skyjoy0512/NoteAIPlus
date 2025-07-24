import SwiftUI

struct RecordingView: View {
    @StateObject private var viewModel = RecordingViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var showingSettings = false
    @State private var showingRecordingsList = false
    @State private var showingTranscriptionPrompt = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()
                
                // Recording Status
                recordingStatusSection
                
                // Waveform Display
                waveformSection
                
                // Recording Time
                recordingTimeSection
                
                Spacer()
                
                // Main Record Button
                recordButtonSection
                
                // Control Buttons
                controlButtonsSection
                
                Spacer()
                
                // Quick Actions
                quickActionsSection
            }
            .padding()
            .navigationTitle("録音")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("録音一覧") {
                        showingRecordingsList = true
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("設定") {
                        showingSettings = true
                    }
                }
            }
            .alert("エラー", isPresented: $viewModel.isShowingError) {
                Button("OK") {
                    viewModel.isShowingError = false
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $showingSettings) {
                RecordingSettingsView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingRecordingsList) {
                RecordingsListView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingTranscriptionPrompt) {
                if let latestRecording = viewModel.recordings.first {
                    TranscriptionPromptView(recording: latestRecording) { recording in
                        appState.startTranscriptionForRecording(recording)
                        showingTranscriptionPrompt = false
                    }
                }
            }
            .onChange(of: viewModel.recordings.count) { _, newCount in
                // Show transcription prompt when a new recording is added
                if newCount > 0, let latestRecording = viewModel.recordings.first {
                    // Only show if this is a newly created recording
                    if latestRecording.date.timeIntervalSinceNow > -10 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            showingTranscriptionPrompt = true
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var recordingStatusSection: some View {
        VStack(spacing: 8) {
            // Recording state indicator
            HStack {
                Circle()
                    .fill(viewModel.isRecording ? .red : .gray)
                    .frame(width: 12, height: 12)
                    .scaleEffect(viewModel.isRecording ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), 
                              value: viewModel.isRecording)
                
                Text(recordingStatusText)
                    .font(.headline)
                    .foregroundColor(viewModel.isRecording ? .red : .primary)
            }
            
            // Current session info
            if let session = viewModel.currentSession {
                Text(session.title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var waveformSection: some View {
        VStack(spacing: 16) {
            // Waveform visualization
            WaveformView(
                audioLevels: viewModel.audioLevels,
                isRecording: viewModel.isRecording
            )
            
            // Audio level meter
            if viewModel.isRecording {
                AudioLevelMeter(level: viewModel.currentAudioLevel)
                    .frame(height: 30)
            }
        }
        .padding(.horizontal)
    }
    
    private var recordingTimeSection: some View {
        Text(viewModel.formattedRecordingTime)
            .font(.system(size: 48, weight: .light, design: .monospaced))
            .foregroundColor(viewModel.isRecording ? .red : .primary)
            .contentTransition(.numericText())
    }
    
    private var recordButtonSection: some View {
        RecordButton(
            isRecording: viewModel.isRecording,
            isEnabled: viewModel.canStartRecording || viewModel.canStopRecording
        ) {
            viewModel.toggleRecording()
        }
    }
    
    private var controlButtonsSection: some View {
        HStack(spacing: 40) {
            // Pause/Resume Button
            if viewModel.isRecording {
                Button(action: viewModel.togglePause) {
                    Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .disabled(!viewModel.canPauseRecording && !viewModel.canResumeRecording)
                .accessibilityLabel(viewModel.pauseButtonTitle)
            }
            
            // Cancel Button
            if viewModel.isRecording {
                Button(action: viewModel.cancelRecording) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .accessibilityLabel("録音キャンセル")
            }
        }
        .animation(.easeInOut, value: viewModel.isRecording)
    }
    
    private var quickActionsSection: some View {
        VStack(spacing: 16) {
            // Recording title input (when not recording)
            if !viewModel.isRecording {
                TextField("録音タイトル（任意）", text: viewModel.recordingTitleBinding)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        if !viewModel.recordingTitle.isEmpty {
                            viewModel.startRecording()
                        }
                    }
            }
            
            // Quick stats
            if !viewModel.recordings.isEmpty {
                HStack {
                    VStack {
                        Text("\(viewModel.recordings.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("録音数")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack {
                        Text(formatTotalDuration())
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("総時間")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack {
                        Text("\(transcribedCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("文字起こし済")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var recordingStatusText: String {
        if viewModel.isPaused {
            return "一時停止中"
        } else if viewModel.isRecording {
            return "録音中"
        } else if viewModel.isProcessing {
            return "処理中"
        } else {
            return "待機中"
        }
    }
    
    private var transcribedCount: Int {
        viewModel.recordings.filter { $0.hasTranscription }.count
    }
    
    // MARK: - Helper Methods
    
    private func formatTotalDuration() -> String {
        let totalDuration = viewModel.recordings.reduce(0) { $0 + $1.duration }
        let hours = Int(totalDuration) / 3600
        let minutes = Int(totalDuration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Supporting Views

struct RecordingSettingsView: View {
    @ObservedObject var viewModel: RecordingViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("音質設定") {
                    Picker("音質", selection: viewModel.selectedAudioQualityBinding) {
                        ForEach(AudioQuality.allCases) { quality in
                            Text(quality.displayName).tag(quality)
                        }
                    }
                }
                
                Section("ファイル形式") {
                    Picker("形式", selection: viewModel.selectedAudioFormatBinding) {
                        ForEach(AudioFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                }
                
                Section("情報") {
                    HStack {
                        Text("録音数")
                        Spacer()
                        Text("\(viewModel.recordings.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("文字起こし済み")
                        Spacer()
                        Text("\(viewModel.recordings.filter { $0.hasTranscription }.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("録音設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct RecordingsListView: View {
    @ObservedObject var viewModel: RecordingViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.recordings) { recording in
                    RecordingRowView(recording: recording, viewModel: viewModel)
                }
                .onDelete(perform: deleteRecordings)
            }
            .navigationTitle("録音一覧")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .refreshable {
                viewModel.refreshRecordings()
            }
        }
    }
    
    private func deleteRecordings(offsets: IndexSet) {
        for index in offsets {
            let recording = viewModel.recordings[index]
            viewModel.deleteRecording(recording)
        }
    }
}

struct RecordingRowView: View {
    let recording: Recording
    @ObservedObject var viewModel: RecordingViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(recording.title)
                    .font(.headline)
                
                Spacer()
                
                Text(recording.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(recording.date, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if recording.hasTranscription {
                Label("文字起こし済み", systemImage: "text.bubble")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
        }
        .contextMenu {
            Button("複製") {
                viewModel.duplicateRecording(recording)
            }
            
            Button("削除", role: .destructive) {
                viewModel.deleteRecording(recording)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RecordingView()
}