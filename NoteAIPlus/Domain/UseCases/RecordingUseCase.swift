import Foundation
import Combine

class RecordingUseCase: ObservableObject {
    private let recordingRepository: RecordingRepositoryProtocol
    private let audioService: AudioRecordingServiceProtocol
    private let transcriptionService: TranscriptionServiceProtocol
    
    @Published var currentRecordingSession: RecordingSession?
    @Published var recordings: [Recording] = []
    @Published var isRecording = false
    @Published var isProcessing = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init(
        recordingRepository: RecordingRepositoryProtocol = RecordingRepository(),
        audioService: AudioRecordingServiceProtocol = AudioRecordingService(),
        transcriptionService: TranscriptionServiceProtocol? = nil
    ) {
        self.recordingRepository = recordingRepository
        self.audioService = audioService
        self.transcriptionService = transcriptionService ?? DummyTranscriptionService()
        
        setupBindings()
    }
    
    private func setupBindings() {
        recordingRepository.recordingsPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$recordings)
    }
    
    // MARK: - Recording Operations
    
    func startRecording(title: String? = nil) async throws -> RecordingSession {
        guard !isRecording else {
            throw RecordingError.alreadyRecording
        }
        
        let audioURL = try await audioService.startRecording()
        
        let session = RecordingSession(
            id: UUID(),
            title: title ?? generateDefaultTitle(),
            audioURL: audioURL,
            startTime: Date(),
            isActive: true
        )
        
        await MainActor.run {
            self.currentRecordingSession = session
            self.isRecording = true
        }
        
        return session
    }
    
    func stopRecording() async throws -> Recording {
        guard let session = currentRecordingSession, isRecording else {
            throw RecordingError.noActiveRecording
        }
        
        let result = try await audioService.stopRecording()
        let endTime = Date()
        let duration = endTime.timeIntervalSince(session.startTime)
        
        let recording = Recording(
            title: session.title,
            date: session.startTime,
            duration: duration,
            audioFileURL: result.audioURL
        )
        
        try await recordingRepository.save(recording)
        
        await MainActor.run {
            self.currentRecordingSession = nil
            self.isRecording = false
        }
        
        return recording
    }
    
    func pauseRecording() async throws {
        guard isRecording else {
            throw RecordingError.noActiveRecording
        }
        
        try await audioService.pauseRecording()
        
        await MainActor.run {
            self.currentRecordingSession?.isPaused = true
        }
    }
    
    func resumeRecording() async throws {
        guard let session = currentRecordingSession, session.isPaused else {
            throw RecordingError.cannotResume
        }
        
        try await audioService.resumeRecording()
        
        await MainActor.run {
            self.currentRecordingSession?.isPaused = false
        }
    }
    
    func cancelRecording() async throws {
        guard isRecording else { return }
        
        try await audioService.stopRecording()
        
        await MainActor.run {
            self.currentRecordingSession = nil
            self.isRecording = false
        }
    }
    
    // MARK: - Transcription Operations
    
    func transcribeRecording(_ recording: Recording, model: String = "base") async throws -> Recording {
        await MainActor.run {
            self.isProcessing = true
        }
        
        defer {
            Task {
                await MainActor.run {
                    self.isProcessing = false
                }
            }
        }
        
        let transcriptionResult = try await transcriptionService.transcribe(
            audioURL: recording.audioFileURL,
            model: model
        )
        
        var updatedRecording = recording
        updatedRecording.updateTranscription(transcriptionResult.text)
        
        try await recordingRepository.update(updatedRecording)
        
        return updatedRecording
    }
    
    // MARK: - Query Operations
    
    func getAllRecordings() async throws -> [Recording] {
        return try await recordingRepository.findAll()
    }
    
    func getRecording(by id: UUID) async throws -> Recording? {
        return try await recordingRepository.findById(id)
    }
    
    func searchRecordings(query: String) async throws -> [Recording] {
        return try await recordingRepository.searchTranscriptions(query: query)
    }
    
    func getRecordingsByDateRange(from: Date, to: Date) async throws -> [Recording] {
        return try await recordingRepository.findByDateRange(from: from, to: to)
    }
    
    func getRecordingsByTag(_ tag: Tag) async throws -> [Recording] {
        return try await recordingRepository.findByTag(tag)
    }
    
    // MARK: - Management Operations
    
    func deleteRecording(_ recording: Recording) async throws {
        try await recordingRepository.delete(id: recording.id)
    }
    
    func updateRecording(_ recording: Recording) async throws {
        try await recordingRepository.update(recording)
    }
    
    func duplicateRecording(_ recording: Recording) async throws -> Recording {
        let newRecording = Recording(
            title: "\(recording.title) - Copy",
            date: Date(),
            duration: recording.duration,
            audioFileURL: recording.audioFileURL,
            transcription: recording.transcription,
            whisperModel: recording.whisperModel,
            language: recording.language,
            speakers: recording.speakers,
            summaries: recording.summaries,
            tags: recording.tags
        )
        
        try await recordingRepository.save(newRecording)
        return newRecording
    }
    
    // MARK: - Statistics
    
    func getTotalRecordingTime() async throws -> TimeInterval {
        return try await recordingRepository.getTotalRecordingTime()
    }
    
    func getRecordingCount() async throws -> Int {
        return try await recordingRepository.getRecordingCount()
    }
    
    func getRecordingStatistics() async throws -> RecordingStatistics {
        let totalTime = try await getTotalRecordingTime()
        let count = try await getRecordingCount()
        let recordings = try await getAllRecordings()
        
        let transcribedCount = recordings.filter { $0.hasTranscription }.count
        let averageDuration = count > 0 ? totalTime / Double(count) : 0
        
        return RecordingStatistics(
            totalRecordings: count,
            totalDuration: totalTime,
            transcribedRecordings: transcribedCount,
            averageDuration: averageDuration
        )
    }
    
    // MARK: - Audio Levels and Time Publishers
    
    var audioLevels: AnyPublisher<Float, Never> {
        audioService.audioLevels
    }
    
    var recordingTime: AnyPublisher<TimeInterval, Never> {
        audioService.recordingTime
    }
    
    // MARK: - Helper Methods
    
    private func generateDefaultTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return "録音 \(formatter.string(from: Date()))"
    }
}

// MARK: - Supporting Types

struct RecordingSession: Identifiable {
    let id: UUID
    let title: String
    let audioURL: URL
    let startTime: Date
    var isPaused: Bool = false
    var isActive: Bool
    
    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
}

struct RecordingResult {
    let audioURL: URL
    let duration: TimeInterval
    let fileSize: Int64
}

// TranscriptionResult and TranscriptionSegment are defined in Domain/Entities/TranscriptionResult.swift

struct RecordingStatistics {
    let totalRecordings: Int
    let totalDuration: TimeInterval
    let transcribedRecordings: Int
    let averageDuration: TimeInterval
    
    var transcriptionRate: Double {
        guard totalRecordings > 0 else { return 0 }
        return Double(transcribedRecordings) / Double(totalRecordings)
    }
}

enum RecordingError: LocalizedError, Equatable {
    case alreadyRecording
    case noActiveRecording
    case cannotResume
    case permissionDenied
    case deviceNotAvailable
    case fileSaveFailed
    case transcriptionFailed
    
    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "既に録音中です"
        case .noActiveRecording:
            return "アクティブな録音がありません"
        case .cannotResume:
            return "録音を再開できません"
        case .permissionDenied:
            return "マイクへのアクセス許可が必要です"
        case .deviceNotAvailable:
            return "録音デバイスが利用できません"
        case .fileSaveFailed:
            return "録音ファイルの保存に失敗しました"
        case .transcriptionFailed:
            return "文字起こしに失敗しました"
        }
    }
}

// MARK: - Service Protocols

protocol AudioRecordingServiceProtocol {
    func startRecording() async throws -> URL
    func stopRecording() async throws -> RecordingResult
    func pauseRecording() async throws
    func resumeRecording() async throws
    var audioLevels: AnyPublisher<Float, Never> { get }
    var recordingTime: AnyPublisher<TimeInterval, Never> { get }
}

// TranscriptionServiceProtocol is defined in Infrastructure/Services/WhisperService.swift

// MARK: - Dummy Implementation for Testing

class DummyTranscriptionService: TranscriptionServiceProtocol {
    private let progressSubject = PassthroughSubject<Float, Never>()
    
    var progress: AnyPublisher<Float, Never> {
        progressSubject.eraseToAnyPublisher()
    }
    
    func transcribe(audioURL: URL, model: String) async throws -> TranscriptionResult {
        // Simulate transcription progress
        for i in 1...10 {
            progressSubject.send(Float(i) / 10.0)
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        
        return TranscriptionResult(
            text: "ダミーの文字起こし結果です。実際の実装では WhisperKit を使用します。",
            confidence: 0.85,
            language: "ja",
            segments: []
        )
    }
    
    func cancelTranscription() {
        // Cancel any ongoing transcription
    }
}