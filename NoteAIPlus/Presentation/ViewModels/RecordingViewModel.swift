import Foundation
import SwiftUI
import Combine

@MainActor
class RecordingViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var recordingTime: TimeInterval = 0
    @Published var audioLevels: [Float] = Array(repeating: 0, count: 50)
    @Published var currentSession: RecordingSession?
    @Published var errorMessage: String?
    @Published var isShowingError = false
    @Published var recordings: [Recording] = []
    @Published var isProcessing = false
    
    // Recording state
    @Published var recordingState: RecordingState = .idle
    
    // Settings
    @Published var recordingTitle: String = ""
    @Published var selectedAudioQuality: AudioQuality = .medium
    @Published var selectedAudioFormat: AudioFormat = .m4a
    
    // MARK: - Private Properties
    
    private let recordingUseCase: RecordingUseCase
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(recordingUseCase: RecordingUseCase = RecordingUseCase()) {
        self.recordingUseCase = recordingUseCase
        setupBindings()
        loadInitialData()
    }
    
    // MARK: - Public Methods
    
    func startRecording() {
        Task {
            do {
                recordingState = .preparing
                
                let title = recordingTitle.isEmpty ? nil : recordingTitle
                let session = try await recordingUseCase.startRecording(title: title)
                
                currentSession = session
                isRecording = true
                isPaused = false
                recordingState = .recording
                recordingTitle = "" // Clear title after starting
                
            } catch {
                await handleError(error)
            }
        }
    }
    
    func stopRecording() {
        Task {
            do {
                recordingState = .stopping
                
                let recording = try await recordingUseCase.stopRecording()
                
                currentSession = nil
                isRecording = false
                isPaused = false
                recordingTime = 0
                recordingState = .idle
                
                // Optional: Show success message or navigate to recording detail
                
            } catch {
                await handleError(error)
            }
        }
    }
    
    func pauseRecording() {
        Task {
            do {
                try await recordingUseCase.pauseRecording()
                isPaused = true
                
            } catch {
                await handleError(error)
            }
        }
    }
    
    func resumeRecording() {
        Task {
            do {
                try await recordingUseCase.resumeRecording()
                isPaused = false
                
            } catch {
                await handleError(error)
            }
        }
    }
    
    func cancelRecording() {
        Task {
            do {
                try await recordingUseCase.cancelRecording()
                
                currentSession = nil
                isRecording = false
                isPaused = false
                recordingTime = 0
                recordingState = .idle
                
            } catch {
                await handleError(error)
            }
        }
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func togglePause() {
        if isPaused {
            resumeRecording()
        } else {
            pauseRecording()
        }
    }
    
    func refreshRecordings() {
        Task {
            do {
                let recordings = try await recordingUseCase.getAllRecordings()
                self.recordings = recordings
            } catch {
                await handleError(error)
            }
        }
    }
    
    func deleteRecording(_ recording: Recording) {
        Task {
            do {
                try await recordingUseCase.deleteRecording(recording)
                // Recording list will be updated automatically via publisher
            } catch {
                await handleError(error)
            }
        }
    }
    
    func duplicateRecording(_ recording: Recording) {
        Task {
            do {
                _ = try await recordingUseCase.duplicateRecording(recording)
                // Recording list will be updated automatically via publisher
            } catch {
                await handleError(error)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var formattedRecordingTime: String {
        formatTimeInterval(recordingTime)
    }
    
    var canStartRecording: Bool {
        recordingState.canStart
    }
    
    var canStopRecording: Bool {
        recordingState.canStop
    }
    
    var canPauseRecording: Bool {
        recordingState.canPause && isRecording && !isPaused
    }
    
    var canResumeRecording: Bool {
        recordingState.canResume && isRecording && isPaused
    }
    
    var recordingButtonTitle: String {
        switch recordingState {
        case .idle:
            return "録音開始"
        case .preparing:
            return "準備中..."
        case .recording:
            return "録音停止"
        case .stopping:
            return "停止中..."
        case .error:
            return "エラー"
        }
    }
    
    var pauseButtonTitle: String {
        if isPaused {
            return "再開"
        } else {
            return "一時停止"
        }
    }
    
    var currentAudioLevel: Float {
        audioLevels.last ?? 0.0
    }
    
    var averageAudioLevel: Float {
        let nonZeroLevels = audioLevels.filter { $0 > 0 }
        guard !nonZeroLevels.isEmpty else { return 0 }
        return nonZeroLevels.reduce(0, +) / Float(nonZeroLevels.count)
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Bind recording use case publishers
        recordingUseCase.$recordings
            .receive(on: DispatchQueue.main)
            .assign(to: &$recordings)
        
        recordingUseCase.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)
        
        recordingUseCase.$isProcessing
            .receive(on: DispatchQueue.main)
            .assign(to: &$isProcessing)
        
        recordingUseCase.$currentRecordingSession
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentSession)
        
        // Bind audio service publishers
        recordingUseCase.audioLevels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.updateAudioLevels(level)
            }
            .store(in: &cancellables)
        
        recordingUseCase.recordingTime
            .receive(on: DispatchQueue.main)
            .assign(to: &$recordingTime)
            .store(in: &cancellables)
    }
    
    private func loadInitialData() {
        refreshRecordings()
    }
    
    private func updateAudioLevels(_ newLevel: Float) {
        // Shift existing levels and add new level
        audioLevels.removeFirst()
        audioLevels.append(newLevel)
    }
    
    private func handleError(_ error: Error) async {
        recordingState = .error
        errorMessage = error.localizedDescription
        isShowingError = true
        
        // Reset recording state on error
        if isRecording {
            currentSession = nil
            isRecording = false
            isPaused = false
            recordingTime = 0
        }
        
        // Auto-hide error after 3 seconds
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        if recordingState == .error {
            recordingState = .idle
        }
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Supporting Types

enum RecordingState {
    case idle
    case preparing
    case recording
    case stopping
    case error
    
    var canStart: Bool {
        self == .idle
    }
    
    var canStop: Bool {
        self == .recording
    }
    
    var canPause: Bool {
        self == .recording
    }
    
    var canResume: Bool {
        self == .recording
    }
}

enum AudioQuality: String, CaseIterable, Identifiable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .high: return "高音質 (256kbps)"
        case .medium: return "中音質 (128kbps)"
        case .low: return "低音質 (64kbps)"
        }
    }
    
    var bitRate: Int {
        switch self {
        case .high: return 256000
        case .medium: return 128000
        case .low: return 64000
        }
    }
}

enum AudioFormat: String, CaseIterable, Identifiable {
    case m4a = "m4a"
    case wav = "wav"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .m4a: return "M4A (圧縮)"
        case .wav: return "WAV (非圧縮)"
        }
    }
    
    var fileExtension: String {
        rawValue
    }
}

// MARK: - Extensions

extension RecordingViewModel {
    // Convenience methods for SwiftUI
    
    func binding<T>(for keyPath: ReferenceWritableKeyPath<RecordingViewModel, T>) -> Binding<T> {
        Binding<T>(
            get: { self[keyPath: keyPath] },
            set: { self[keyPath: keyPath] = $0 }
        )
    }
    
    var recordingTitleBinding: Binding<String> {
        binding(for: \.recordingTitle)
    }
    
    var selectedAudioQualityBinding: Binding<AudioQuality> {
        binding(for: \.selectedAudioQuality)
    }
    
    var selectedAudioFormatBinding: Binding<AudioFormat> {
        binding(for: \.selectedAudioFormat)
    }
}