import Foundation
import Combine

class TranscriptionUseCase: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isProcessing = false
    @Published var currentProgress: TranscriptionProgress = .idle
    @Published var currentTranscription: TranscriptionResult?
    @Published var processingQueue: [TranscriptionJob] = []
    @Published var error: Error?
    
    // MARK: - Dependencies
    
    private let transcriptionService: TranscriptionServiceProtocol
    private let transcriptionRepository: TranscriptionRepositoryProtocol
    private let recordingUseCase: RecordingUseCase
    private let modelManager: ModelManager
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var currentJob: TranscriptionJob?
    private let processingQueue_internal = DispatchQueue(label: "transcription.processing", qos: .userInitiated)
    
    // MARK: - Initialization
    
    init(
        transcriptionService: TranscriptionServiceProtocol = WhisperService(),
        transcriptionRepository: TranscriptionRepositoryProtocol = TranscriptionRepository(),
        recordingUseCase: RecordingUseCase = RecordingUseCase(),
        modelManager: ModelManager = ModelManager()
    ) {
        self.transcriptionService = transcriptionService
        self.transcriptionRepository = transcriptionRepository
        self.recordingUseCase = recordingUseCase
        self.modelManager = modelManager
        
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    /// 録音を文字起こしする
    func transcribeRecording(
        _ recording: Recording,
        options: TranscriptionOptions = TranscriptionOptions()
    ) async throws -> TranscriptionResult {
        
        // Check if transcription already exists
        if let existing = try await transcriptionRepository.findByRecordingId(recording.id) {
            await MainActor.run {
                self.currentTranscription = existing
            }
            return existing
        }
        
        await MainActor.run {
            self.isProcessing = true
            self.currentProgress = .preparing
            self.error = nil
        }
        
        defer {
            Task { @MainActor in
                self.isProcessing = false
                self.currentProgress = .idle
            }
        }
        
        do {
            // Ensure model is available
            await MainActor.run {
                self.currentProgress = .loadingModel
            }
            
            try await modelManager.ensureModelAvailable(options.modelType)
            
            // Perform transcription
            await MainActor.run {
                self.currentProgress = .transcribing(0.0)
            }
            
            let result = try await transcriptionService.transcribe(
                audioURL: recording.fileURL,
                options: options
            )
            
            // Create final result with proper recording ID
            let finalResult = TranscriptionResult(
                id: result.id,
                recordingId: recording.id,
                text: result.text,
                language: result.language,
                confidence: result.confidence,
                modelType: result.modelType,
                processingTime: result.processingTime,
                segments: result.segments,
                speakers: result.speakers,
                metadata: result.metadata
            )
            
            // Save to repository
            await MainActor.run {
                self.currentProgress = .postprocessing
            }
            
            try await transcriptionRepository.save(finalResult)
            
            await MainActor.run {
                self.currentTranscription = finalResult
                self.currentProgress = .completed
            }
            
            return finalResult
            
        } catch {
            await MainActor.run {
                self.error = error
                self.currentProgress = .error(error)
            }
            throw error
        }
    }
    
    /// 進捗付きで文字起こしを実行
    func transcribeWithProgress(
        recording: Recording,
        options: TranscriptionOptions = TranscriptionOptions()
    ) -> AsyncThrowingStream<TranscriptionProgress, Error> {
        
        return AsyncThrowingStream { continuation in
            let cancellable = transcriptionService.progress.sink { progress in
                continuation.yield(progress)
                
                if case .completed = progress {
                    continuation.finish()
                } else if case .error(let error) = progress {
                    continuation.finish(throwing: error)
                }
            }
            
            Task {
                do {
                    _ = try await transcribeRecording(recording, options: options)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }
    
    /// 複数録音の一括文字起こし
    func batchTranscribe(
        _ recordings: [Recording],
        options: TranscriptionOptions = TranscriptionOptions()
    ) async throws -> [TranscriptionResult] {
        
        var results: [TranscriptionResult] = []
        
        for (index, recording) in recordings.enumerated() {
            await MainActor.run {
                self.currentProgress = .preparing
            }
            
            do {
                let result = try await transcribeRecording(recording, options: options)
                results.append(result)
                
                // Update progress
                let overallProgress = Float(index + 1) / Float(recordings.count)
                await MainActor.run {
                    self.currentProgress = .transcribing(overallProgress)
                }
                
            } catch {
                // Continue with next recording on error
                print("Failed to transcribe recording \(recording.id): \(error)")
                continue
            }
        }
        
        await MainActor.run {
            self.currentProgress = .completed
        }
        
        return results
    }
    
    /// 文字起こし結果を検索
    func searchTranscriptions(query: String) async throws -> [TranscriptionResult] {
        return try await transcriptionRepository.searchTranscriptions(query: query)
    }
    
    /// 最近の文字起こし結果を取得
    func getRecentTranscriptions(limit: Int = 50) async throws -> [TranscriptionResult] {
        return try await transcriptionRepository.fetchRecent(limit: limit)
    }
    
    /// 文字起こし結果を削除
    func deleteTranscription(_ transcription: TranscriptionResult) async throws {
        try await transcriptionRepository.delete(transcription)
        
        await MainActor.run {
            if self.currentTranscription?.id == transcription.id {
                self.currentTranscription = nil
            }
        }
    }
    
    /// 録音IDに基づいて文字起こし結果を削除
    func deleteTranscriptionByRecordingId(_ recordingId: UUID) async throws {
        try await transcriptionRepository.deleteByRecordingId(recordingId)
        
        await MainActor.run {
            if self.currentTranscription?.recordingId == recordingId {
                self.currentTranscription = nil
            }
        }
    }
    
    /// 文字起こし結果を録音IDで取得
    func getTranscriptionByRecordingId(_ recordingId: UUID) async throws -> TranscriptionResult? {
        return try await transcriptionRepository.findByRecordingId(recordingId)
    }
    
    /// 文字起こしをキャンセル
    func cancelTranscription() {
        transcriptionService.cancelTranscription()
        
        Task { @MainActor in
            self.isProcessing = false
            self.currentProgress = .cancelled
        }
    }
    
    /// 利用可能なモデルを取得
    func getAvailableModels() -> [WhisperModelType] {
        return modelManager.availableModels
    }
    
    /// ダウンロード済みモデルを取得
    func getDownloadedModels() -> Set<WhisperModelType> {
        return modelManager.downloadedModels
    }
    
    /// モデルをダウンロード
    func downloadModel(_ modelType: WhisperModelType) async throws {
        try await modelManager.downloadModel(modelType)
    }
    
    /// モデルを削除
    func deleteModel(_ modelType: WhisperModelType) async throws {
        try await modelManager.deleteModel(modelType)
    }
    
    // MARK: - Statistics Methods
    
    /// 文字起こし統計を取得
    func getTranscriptionStatistics() async throws -> TranscriptionStatistics {
        let totalCount = try await transcriptionRepository.getTranscriptionCount()
        let languageCounts = try await transcriptionRepository.getTranscriptionCountByLanguage()
        let averageConfidence = try await transcriptionRepository.getAverageConfidence()
        let totalProcessingTime = try await transcriptionRepository.getTotalProcessingTime()
        
        return TranscriptionStatistics(
            totalCount: totalCount,
            languageCounts: languageCounts,
            averageConfidence: averageConfidence,
            totalProcessingTime: totalProcessingTime
        )
    }
    
    // MARK: - Advanced Search Methods
    
    func searchByLanguage(_ language: String) async throws -> [TranscriptionResult] {
        return try await transcriptionRepository.searchByLanguage(language)
    }
    
    func searchByModelType(_ modelType: WhisperModelType) async throws -> [TranscriptionResult] {
        return try await transcriptionRepository.searchByModelType(modelType)
    }
    
    func searchByDateRange(from startDate: Date, to endDate: Date) async throws -> [TranscriptionResult] {
        return try await transcriptionRepository.searchByDateRange(from: startDate, to: endDate)
    }
    
    func searchByConfidenceThreshold(_ threshold: Float) async throws -> [TranscriptionResult] {
        return try await transcriptionRepository.searchByConfidenceThreshold(threshold)
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe transcription service progress
        transcriptionService.progress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.currentProgress = progress
            }
            .store(in: &cancellables)
        
        // Observe transcription service processing state
        transcriptionService.isProcessing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isProcessing in
                self?.isProcessing = isProcessing
            }
            .store(in: &cancellables)
    }
}

// MARK: - Supporting Types

struct TranscriptionJob: Identifiable {
    let id = UUID()
    let recording: Recording
    let options: TranscriptionOptions
    let priority: TranscriptionPriority
    let createdAt = Date()
}

enum TranscriptionPriority: Int, CaseIterable {
    case low = 0
    case normal = 1
    case high = 2
    case urgent = 3
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .normal: return "通常"
        case .high: return "高"
        case .urgent: return "緊急"
        }
    }
}

struct TranscriptionStatistics {
    let totalCount: Int
    let languageCounts: [String: Int]
    let averageConfidence: Float
    let totalProcessingTime: TimeInterval
    
    var mostUsedLanguage: String? {
        languageCounts.max(by: { $0.value < $1.value })?.key
    }
    
    var averageProcessingTime: TimeInterval {
        guard totalCount > 0 else { return 0 }
        return totalProcessingTime / TimeInterval(totalCount)
    }
}

// MARK: - Repository Extensions

extension TranscriptionRepositoryProtocol {
    func searchByLanguage(_ language: String) async throws -> [TranscriptionResult] {
        // Default implementation for repositories that don't support this
        let allTranscriptions = try await getAllTranscriptions()
        return allTranscriptions.filter { $0.language == language }
    }
    
    func searchByModelType(_ modelType: WhisperModelType) async throws -> [TranscriptionResult] {
        // Default implementation for repositories that don't support this
        let allTranscriptions = try await getAllTranscriptions()
        return allTranscriptions.filter { $0.modelType == modelType }
    }
    
    func searchByDateRange(from startDate: Date, to endDate: Date) async throws -> [TranscriptionResult] {
        // Default implementation for repositories that don't support this
        let allTranscriptions = try await getAllTranscriptions()
        return allTranscriptions.filter { transcription in
            transcription.createdAt >= startDate && transcription.createdAt <= endDate
        }
    }
    
    func searchByConfidenceThreshold(_ threshold: Float) async throws -> [TranscriptionResult] {
        // Default implementation for repositories that don't support this
        let allTranscriptions = try await getAllTranscriptions()
        return allTranscriptions.filter { $0.confidence >= threshold }
    }
    
    func getTranscriptionCount() async throws -> Int {
        // Default implementation
        let allTranscriptions = try await getAllTranscriptions()
        return allTranscriptions.count
    }
    
    func getTranscriptionCountByLanguage() async throws -> [String: Int] {
        // Default implementation
        let allTranscriptions = try await getAllTranscriptions()
        var counts: [String: Int] = [:]
        
        for transcription in allTranscriptions {
            counts[transcription.language, default: 0] += 1
        }
        
        return counts
    }
    
    func getAverageConfidence() async throws -> Float {
        // Default implementation
        let allTranscriptions = try await getAllTranscriptions()
        guard !allTranscriptions.isEmpty else { return 0.0 }
        
        let totalConfidence = allTranscriptions.reduce(0.0) { $0 + $1.confidence }
        return totalConfidence / Float(allTranscriptions.count)
    }
    
    func getTotalProcessingTime() async throws -> TimeInterval {
        // Default implementation
        let allTranscriptions = try await getAllTranscriptions()
        return allTranscriptions.reduce(0.0) { $0 + $1.processingTime }
    }
}