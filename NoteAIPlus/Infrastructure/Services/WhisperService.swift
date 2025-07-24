import Foundation
import Combine
import WhisperKit
import UIKit

class WhisperService: NSObject, TranscriptionServiceProtocol {
    // MARK: - Properties
    
    private var whisperKit: WhisperKit?
    private let modelManager: ModelManagerProtocol
    private let audioProcessor: AudioProcessorProtocol
    private let queue = DispatchQueue(label: "whisper.processing", qos: .userInitiated)
    
    // Publishers for progress tracking
    private let progressSubject = PassthroughSubject<TranscriptionProgress, Never>()
    private let isProcessingSubject = CurrentValueSubject<Bool, Never>(false)
    
    // Current processing state
    private var currentTask: Task<TranscriptionResult, Error>?
    private var isModelLoaded = false
    private var currentModelType: WhisperModelType?
    
    // MARK: - Initialization
    
    init(
        modelManager: ModelManagerProtocol = ModelManager(),
        audioProcessor: AudioProcessorProtocol = AudioProcessor()
    ) {
        self.modelManager = modelManager
        self.audioProcessor = audioProcessor
        super.init()
        
        setupNotifications()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - TranscriptionServiceProtocol
    
    var progress: AnyPublisher<TranscriptionProgress, Never> {
        progressSubject.eraseToAnyPublisher()
    }
    
    var isProcessing: AnyPublisher<Bool, Never> {
        isProcessingSubject.eraseToAnyPublisher()
    }
    
    func transcribe(audioURL: URL, options: TranscriptionOptions) async throws -> TranscriptionResult {
        // Prevent concurrent transcription
        guard !isProcessingSubject.value else {
            throw TranscriptionError.transcriptionInProgress
        }
        
        isProcessingSubject.send(true)
        progressSubject.send(.preparing)
        
        defer {
            isProcessingSubject.send(false)
            progressSubject.send(.idle)
        }
        
        do {
            // 1. Audio preprocessing
            progressSubject.send(.preprocessing)
            let processedAudioURL = try await preprocessAudio(audioURL, options: options)
            
            // 2. Model loading
            progressSubject.send(.loadingModel)
            try await ensureModelLoaded(options.modelType)
            
            // 3. Transcription execution
            progressSubject.send(.transcribing(0.0))
            let result = try await performTranscription(processedAudioURL, options: options)
            
            // 4. Post-processing
            progressSubject.send(.postprocessing)
            let finalResult = try await postProcessResult(result, options: options)
            
            progressSubject.send(.completed)
            return finalResult
            
        } catch {
            progressSubject.send(.error(error))
            throw error
        }
    }
    
    func transcribeWithProgress(audioURL: URL, options: TranscriptionOptions) -> AsyncThrowingStream<TranscriptionProgress, Error> {
        return AsyncThrowingStream { continuation in
            let cancellable = progress.sink { progress in
                continuation.yield(progress)
                if case .completed = progress {
                    continuation.finish()
                } else if case .error(let error) = progress {
                    continuation.finish(throwing: error)
                }
            }
            
            Task {
                do {
                    _ = try await transcribe(audioURL: audioURL, options: options)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }
    
    func isModelLoaded(_ modelType: WhisperModelType) -> Bool {
        return isModelLoaded && currentModelType == modelType
    }
    
    func loadModel(_ modelType: WhisperModelType) async throws {
        guard currentModelType != modelType || !isModelLoaded else {
            return // Model already loaded
        }
        
        // Unload current model if different
        if let current = currentModelType, current != modelType {
            await unloadModel()
        }
        
        // Ensure model is downloaded
        try await modelManager.ensureModelAvailable(modelType)
        
        // Load model
        let modelPath = try await modelManager.getModelPath(modelType)
        whisperKit = try await WhisperKit(modelFolder: modelPath.path)
        
        currentModelType = modelType
        isModelLoaded = true
    }
    
    func unloadModel() async {
        whisperKit = nil
        currentModelType = nil
        isModelLoaded = false
        
        // Force memory cleanup
        await MainActor.run {
            // Trigger garbage collection
        }
    }
    
    func cancelTranscription() {
        currentTask?.cancel()
        currentTask = nil
        progressSubject.send(.cancelled)
        isProcessingSubject.send(false)
    }
    
    // MARK: - Private Methods
    
    private func preprocessAudio(_ audioURL: URL, options: TranscriptionOptions) async throws -> URL {
        // Convert audio to Whisper-compatible format
        let convertedURL = try await audioProcessor.convertToWhisperFormat(audioURL)
        
        // Apply noise reduction if enabled
        if options.enableNoiseReduction {
            return try await audioProcessor.reduceNoise(
                convertedURL,
                level: options.noiseReductionLevel
            )
        }
        
        return convertedURL
    }
    
    private func ensureModelLoaded(_ modelType: WhisperModelType) async throws {
        if !isModelLoaded(modelType) {
            try await loadModel(modelType)
        }
    }
    
    private func performTranscription(_ audioURL: URL, options: TranscriptionOptions) async throws -> TranscriptionResult {
        guard let whisperKit = self.whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }
        
        let startTime = Date()
        
        // Configure transcription options
        let transcriptionOptions = WhisperKit.TranscriptionOptions(
            language: options.language,
            task: .transcribe,
            temperature: options.temperature,
            compressionRatioThreshold: options.compressionRatioThreshold,
            logProbThreshold: options.logProbThreshold,
            noSpeechThreshold: options.noSpeechThreshold,
            conditionOnPreviousText: options.conditionOnPreviousText,
            wordTimestamps: options.enableWordTimestamps
        )
        
        // Create task for cancellation support
        currentTask = Task {
            return try await whisperKit.transcribe(
                audioPath: audioURL.path,
                decodeOptions: transcriptionOptions
            ) { progress in
                self.progressSubject.send(.transcribing(progress))
            }
        }
        
        guard let task = currentTask else {
            throw TranscriptionError.transcriptionFailed("Failed to create transcription task")
        }
        
        let whisperResult = try await task.value
        let processingTime = Date().timeIntervalSince(startTime)
        
        return try convertWhisperResult(
            whisperResult,
            options: options,
            processingTime: processingTime,
            audioURL: audioURL
        )
    }
    
    private func convertWhisperResult(
        _ whisperResult: WhisperKit.TranscriptionResult,
        options: TranscriptionOptions,
        processingTime: TimeInterval,
        audioURL: URL
    ) throws -> TranscriptionResult {
        
        // Convert segments
        let segments = whisperResult.segments.map { whisperSegment in
            let tokens = whisperSegment.tokens.map { token in
                TranscriptionToken(
                    text: token.text,
                    startTime: token.startTime,
                    endTime: token.endTime,
                    confidence: token.confidence,
                    logProbability: token.logProbability
                )
            }
            
            return TranscriptionSegment(
                startTime: whisperSegment.startTime,
                endTime: whisperSegment.endTime,
                text: whisperSegment.text,
                confidence: whisperSegment.confidence,
                tokens: tokens
            )
        }
        
        // Create metadata
        let audioQuality = try? audioProcessor.analyzeAudioQuality(audioURL)
        let metadata = TranscriptionMetadata(
            audioQuality: audioQuality,
            processingInfo: ProcessingInfo()
        )
        
        return TranscriptionResult(
            recordingId: UUID(), // Will be set by use case
            text: whisperResult.text,
            language: whisperResult.language ?? options.language ?? "auto",
            confidence: whisperResult.confidence,
            modelType: options.modelType,
            processingTime: processingTime,
            segments: segments,
            metadata: metadata
        )
    }
    
    private func postProcessResult(_ result: TranscriptionResult, options: TranscriptionOptions) async throws -> TranscriptionResult {
        var processedText = result.text
        
        // Apply punctuation insertion
        if options.enablePunctuationInsertion {
            processedText = TextPostProcessor.insertPunctuation(processedText, language: result.language)
        }
        
        // Apply paragraph breaks
        if options.enableParagraphBreaks {
            processedText = TextPostProcessor.addParagraphBreaks(processedText, segments: result.segments)
        }
        
        // Apply custom dictionary
        if !options.customDictionary.isEmpty {
            let dictionary = Dictionary(uniqueKeysWithValues: options.customDictionary.map { ($0, $0) })
            processedText = TextPostProcessor.applyCustomDictionary(processedText, dictionary: dictionary)
        }
        
        return TranscriptionResult(
            id: result.id,
            recordingId: result.recordingId,
            text: processedText,
            language: result.language,
            confidence: result.confidence,
            modelType: result.modelType,
            processingTime: result.processingTime,
            segments: result.segments,
            speakers: result.speakers,
            metadata: result.metadata
        )
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        Task {
            if !isProcessingSubject.value {
                await unloadModel()
            }
        }
    }
    
    private func cleanup() {
        currentTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Supporting Types

enum TranscriptionProgress: Equatable {
    case idle
    case preparing
    case preprocessing
    case loadingModel
    case transcribing(Float)
    case postprocessing
    case completed
    case cancelled
    case error(Error)
    
    static func == (lhs: TranscriptionProgress, rhs: TranscriptionProgress) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.preparing, .preparing),
             (.preprocessing, .preprocessing),
             (.loadingModel, .loadingModel),
             (.postprocessing, .postprocessing),
             (.completed, .completed),
             (.cancelled, .cancelled):
            return true
        case (.transcribing(let lhsProgress), .transcribing(let rhsProgress)):
            return lhsProgress == rhsProgress
        case (.error, .error):
            return true // Simplified equality for errors
        default:
            return false
        }
    }
    
    var displayText: String {
        switch self {
        case .idle: return "待機中"
        case .preparing: return "準備中..."
        case .preprocessing: return "音声を前処理中..."
        case .loadingModel: return "モデルを読み込み中..."
        case .transcribing(let progress): return "文字起こし中... \(Int(progress * 100))%"
        case .postprocessing: return "後処理中..."
        case .completed: return "完了"
        case .cancelled: return "キャンセル済み"
        case .error: return "エラーが発生しました"
        }
    }
    
    var progressValue: Float {
        switch self {
        case .idle: return 0.0
        case .preparing: return 0.1
        case .preprocessing: return 0.2
        case .loadingModel: return 0.3
        case .transcribing(let progress): return 0.3 + (progress * 0.6)
        case .postprocessing: return 0.9
        case .completed: return 1.0
        case .cancelled, .error: return 0.0
        }
    }
}

struct TranscriptionOptions {
    // Model selection
    var modelType: WhisperModelType = .base
    var language: String? = nil // Auto-detect if nil
    
    // Quality settings
    var temperature: Float = 0.0
    var compressionRatioThreshold: Float = 2.4
    var logProbThreshold: Float = -1.0
    var noSpeechThreshold: Float = 0.6
    
    // Processing options
    var enableNoiseReduction: Bool = false
    var noiseReductionLevel: NoiseReductionLevel = .medium
    var enableSpeakerDiarization: Bool = false
    var maxSpeakers: Int = 8
    
    // Post-processing
    var enablePunctuationInsertion: Bool = true
    var enableParagraphBreaks: Bool = true
    var customDictionary: [String] = []
    
    // Performance
    var conditionOnPreviousText: Bool = true
    var enableWordTimestamps: Bool = true
    var chunkLength: TimeInterval = 30.0
}

enum NoiseReductionLevel: String, CaseIterable {
    case light = "軽度"
    case medium = "中程度"
    case aggressive = "強力"
    
    var processingIntensity: Float {
        switch self {
        case .light: return 0.3
        case .medium: return 0.6
        case .aggressive: return 0.9
        }
    }
}

enum TranscriptionError: LocalizedError, Equatable {
    case modelNotLoaded
    case modelDownloadFailed(WhisperModelType)
    case audioProcessingFailed
    case transcriptionFailed(String)
    case transcriptionInProgress
    case insufficientStorage(required: Int64, available: Int64)
    case unsupportedAudioFormat
    case audioFileTooLarge(size: Int64, maxSize: Int64)
    case modelCorrupted(WhisperModelType)
    case networkUnavailable
    
    static func == (lhs: TranscriptionError, rhs: TranscriptionError) -> Bool {
        switch (lhs, rhs) {
        case (.modelNotLoaded, .modelNotLoaded),
             (.audioProcessingFailed, .audioProcessingFailed),
             (.transcriptionInProgress, .transcriptionInProgress),
             (.unsupportedAudioFormat, .unsupportedAudioFormat),
             (.networkUnavailable, .networkUnavailable):
            return true
        case (.modelDownloadFailed(let lhsModel), .modelDownloadFailed(let rhsModel)):
            return lhsModel == rhsModel
        case (.transcriptionFailed(let lhsReason), .transcriptionFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.insufficientStorage(let lhsReq, let lhsAvail), .insufficientStorage(let rhsReq, let rhsAvail)):
            return lhsReq == rhsReq && lhsAvail == rhsAvail
        case (.audioFileTooLarge(let lhsSize, let lhsMax), .audioFileTooLarge(let rhsSize, let rhsMax)):
            return lhsSize == rhsSize && lhsMax == rhsMax
        case (.modelCorrupted(let lhsModel), .modelCorrupted(let rhsModel)):
            return lhsModel == rhsModel
        default:
            return false
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "文字起こしモデルが読み込まれていません。"
        case .modelDownloadFailed(let modelType):
            return "\(modelType.displayName)のダウンロードに失敗しました。"
        case .audioProcessingFailed:
            return "音声ファイルの処理に失敗しました。"
        case .transcriptionFailed(let reason):
            return "文字起こしに失敗しました: \(reason)"
        case .transcriptionInProgress:
            return "既に文字起こしが進行中です。"
        case .insufficientStorage(let required, let available):
            return "ストレージ容量が不足しています。必要: \(ByteCountFormatter().string(fromByteCount: required)), 利用可能: \(ByteCountFormatter().string(fromByteCount: available))"
        case .unsupportedAudioFormat:
            return "サポートされていない音声形式です。"
        case .audioFileTooLarge(let size, let maxSize):
            return "音声ファイルが大きすぎます。最大サイズ: \(ByteCountFormatter().string(fromByteCount: maxSize))"
        case .modelCorrupted(let modelType):
            return "\(modelType.displayName)が破損しています。再ダウンロードしてください。"
        case .networkUnavailable:
            return "ネットワーク接続が利用できません。"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .modelNotLoaded:
            return "設定からモデルをダウンロードしてください。"
        case .modelDownloadFailed:
            return "ネットワーク接続を確認して再試行してください。"
        case .audioProcessingFailed:
            return "音声ファイルが破損していないか確認してください。"
        case .transcriptionInProgress:
            return "現在の処理が完了するまでお待ちください。"
        case .insufficientStorage:
            return "不要なファイルを削除してから再試行してください。"
        case .unsupportedAudioFormat:
            return "サポートされた形式（M4A、WAV）で録音してください。"
        case .audioFileTooLarge:
            return "より短い音声ファイルを使用するか、音質を下げてください。"
        case .modelCorrupted:
            return "設定からモデルを削除して再ダウンロードしてください。"
        case .networkUnavailable:
            return "インターネット接続を確認してください。"
        default:
            return nil
        }
    }
}

// MARK: - Protocols

protocol TranscriptionServiceProtocol {
    var progress: AnyPublisher<TranscriptionProgress, Never> { get }
    var isProcessing: AnyPublisher<Bool, Never> { get }
    
    func transcribe(audioURL: URL, options: TranscriptionOptions) async throws -> TranscriptionResult
    func transcribeWithProgress(audioURL: URL, options: TranscriptionOptions) -> AsyncThrowingStream<TranscriptionProgress, Error>
    func isModelLoaded(_ modelType: WhisperModelType) -> Bool
    func loadModel(_ modelType: WhisperModelType) async throws
    func unloadModel() async
    func cancelTranscription()
}

protocol ModelManagerProtocol {
    func ensureModelAvailable(_ modelType: WhisperModelType) async throws
    func getModelPath(_ modelType: WhisperModelType) async throws -> URL
    func downloadModel(_ modelType: WhisperModelType) async throws
    func deleteModel(_ modelType: WhisperModelType) async throws
    func getStorageUsage() async -> Int64
}

protocol AudioProcessorProtocol {
    func convertToWhisperFormat(_ inputURL: URL) async throws -> URL
    func reduceNoise(_ inputURL: URL, level: NoiseReductionLevel) async throws -> URL
    func analyzeAudioQuality(_ audioURL: URL) async throws -> AudioQualityMetrics
}

// MARK: - Text Post Processor

class TextPostProcessor {
    static func insertPunctuation(_ text: String, language: String) -> String {
        // Simplified punctuation insertion
        var result = text
        
        // Add periods at natural breaks
        result = result.replacingOccurrences(of: " そして ", with: "。そして")
        result = result.replacingOccurrences(of: " それから ", with: "。それから")
        result = result.replacingOccurrences(of: " ただし ", with: "。ただし")
        
        // Ensure sentence ends with punctuation
        if !result.hasSuffix("。") && !result.hasSuffix("？") && !result.hasSuffix("！") {
            result += "。"
        }
        
        return result
    }
    
    static func addParagraphBreaks(_ text: String, segments: [TranscriptionSegment]) -> String {
        // Add paragraph breaks based on long pauses between segments
        var result = ""
        var previousEnd: TimeInterval = 0
        
        for segment in segments {
            let pause = segment.startTime - previousEnd
            
            if pause > 3.0 && !result.isEmpty { // 3 second pause = paragraph break
                result += "\n\n"
            } else if !result.isEmpty {
                result += " "
            }
            
            result += segment.text
            previousEnd = segment.endTime
        }
        
        return result.isEmpty ? text : result
    }
    
    static func applyCustomDictionary(_ text: String, dictionary: [String: String]) -> String {
        var result = text
        
        for (original, replacement) in dictionary {
            result = result.replacingOccurrences(of: original, with: replacement, options: .caseInsensitive)
        }
        
        return result
    }
}