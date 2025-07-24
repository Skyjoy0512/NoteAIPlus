# 文字起こし機能 - 技術設計

## アーキテクチャ概要

文字起こし機能はWhisperKitを中核としたオンデバイス音声認識システムとして設計される。Clean Architectureパターンに従い、既存の録音機能と疎結合で統合される。

```
Presentation Layer (TranscriptionView + TranscriptionViewModel)
    ↓
Domain Layer (TranscriptionUseCase + Transcription Entity)
    ↓
Data Layer (TranscriptionRepository + ModelRepository)
    ↓
Infrastructure Layer (WhisperService + ModelManager + SpeakerDiarization)
```

## システム構成要素

### 1. Core Components

#### WhisperService
```swift
class WhisperService: TranscriptionServiceProtocol {
    private var whisperKit: WhisperKit?
    private let modelManager: ModelManagerProtocol
    private let audioProcessor: AudioProcessorProtocol
    
    // Primary transcription methods
    func transcribe(audioURL: URL, options: TranscriptionOptions) async throws -> TranscriptionResult
    func transcribeWithProgress(audioURL: URL, options: TranscriptionOptions) -> AsyncThrowingStream<TranscriptionProgress, Error>
    
    // Model management
    func loadModel(_ modelType: WhisperModelType) async throws
    func unloadModel() async
    func isModelLoaded(_ modelType: WhisperModelType) -> Bool
    
    // Real-time transcription (future)
    func startRealtimeTranscription(options: TranscriptionOptions) async throws
    func stopRealtimeTranscription() async
}
```

#### ModelManager
```swift
class ModelManager: ModelManagerProtocol {
    private let cacheDirectory: URL
    private let downloadManager: ModelDownloadManager
    
    // Model lifecycle
    func downloadModel(_ modelType: WhisperModelType) async throws -> URL
    func deleteModel(_ modelType: WhisperModelType) async throws
    func getAvailableModels() async -> [WhisperModelType]
    func getModelSize(_ modelType: WhisperModelType) -> Int64
    
    // Cache management
    func clearCache() async throws
    func getStorageUsage() async -> Int64
    func optimizeStorage() async throws
}
```

### 2. Domain Entities

#### TranscriptionResult
```swift
struct TranscriptionResult: Identifiable, Codable {
    let id: UUID
    let recordingId: UUID
    let text: String
    let language: String
    let confidence: Float
    let modelType: WhisperModelType
    let processingTime: TimeInterval
    let segments: [TranscriptionSegment]
    let speakers: [Speaker]? // Pro版
    let metadata: TranscriptionMetadata
    let createdAt: Date
    
    // Quality metrics
    var wordCount: Int { text.components(separatedBy: .whitespacesAndNewlines).count }
    var averageConfidence: Float { segments.map(\.confidence).reduce(0, +) / Float(segments.count) }
    var hasTimestamps: Bool { !segments.isEmpty }
    var hasSpeakerDiarization: Bool { speakers?.isEmpty == false }
}
```

#### TranscriptionSegment
```swift
struct TranscriptionSegment: Identifiable, Codable {
    let id: UUID
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
    let confidence: Float
    let tokens: [TranscriptionToken]
    let speakerId: UUID? // Pro版
    
    var duration: TimeInterval { endTime - startTime }
    var wordsPerMinute: Double { Double(wordCount) / (duration / 60) }
    var wordCount: Int { text.components(separatedBy: .whitespacesAndNewlines).count }
}
```

#### WhisperModelType
```swift
enum WhisperModelType: String, CaseIterable, Identifiable {
    case tiny = "openai_whisper-tiny"
    case base = "openai_whisper-base" 
    case small = "openai_whisper-small"
    case medium = "openai_whisper-medium" // Pro版のみ
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .tiny: return "Tiny (39MB) - 最速"
        case .base: return "Base (74MB) - 推奨"
        case .small: return "Small (244MB) - 高精度"
        case .medium: return "Medium (769MB) - 最高精度"
        }
    }
    
    var fileSize: Int64 {
        switch self {
        case .tiny: return 39_000_000
        case .base: return 74_000_000
        case .small: return 244_000_000
        case .medium: return 769_000_000
        }
    }
    
    var recommendedFor: [UsageScenario] {
        switch self {
        case .tiny: return [.quickNotes, .batteryConstrained]
        case .base: return [.generalUse, .meetings, .lectures]
        case .small: return [.importantMeetings, .interviews, .accuracyRequired]
        case .medium: return [.transcriptionService, .professionalUse, .maxAccuracy]
        }
    }
}
```

### 3. Infrastructure Layer設計

#### WhisperKit統合
```swift
class WhisperService: NSObject, TranscriptionServiceProtocol {
    private var whisperKit: WhisperKit?
    private let queue = DispatchQueue(label: "whisper.processing", qos: .userInitiated)
    private let progressSubject = PassthroughSubject<TranscriptionProgress, Never>()
    
    func transcribe(audioURL: URL, options: TranscriptionOptions) async throws -> TranscriptionResult {
        // 1. Audio preprocessing
        let processedAudio = try await preprocessAudio(audioURL, options: options)
        
        // 2. Model loading
        try await ensureModelLoaded(options.modelType)
        
        // 3. Transcription execution
        let whisperResult = try await performTranscription(processedAudio, options: options)
        
        // 4. Post-processing
        let result = try await postProcessResult(whisperResult, options: options)
        
        // 5. Speaker diarization (Pro版)
        if options.enableSpeakerDiarization && SubscriptionManager.shared.isPro {
            result = try await applySpeakerDiarization(result, audioURL: audioURL)
        }
        
        return result
    }
    
    private func preprocessAudio(_ audioURL: URL, options: TranscriptionOptions) async throws -> URL {
        let processor = AudioProcessor()
        
        // Audio format conversion
        let convertedURL = try await processor.convertToRequiredFormat(audioURL)
        
        // Noise reduction (optional)
        if options.enableNoiseReduction {
            return try await processor.reduceNoise(convertedURL, level: options.noiseReductionLevel)
        }
        
        return convertedURL
    }
    
    private func performTranscription(_ audioURL: URL, options: TranscriptionOptions) async throws -> WhisperKit.TranscriptionResult {
        guard let whisperKit = self.whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }
        
        let transcriptionOptions = WhisperKit.TranscriptionOptions(
            language: options.language,
            task: .transcribe,
            temperature: options.temperature,
            compressionRatioThreshold: options.compressionRatioThreshold,
            logProbThreshold: options.logProbThreshold,
            noSpeechThreshold: options.noSpeechThreshold,
            conditionOnPreviousText: options.conditionOnPreviousText
        )
        
        return try await whisperKit.transcribe(
            audioPath: audioURL.path,
            decodeOptions: transcriptionOptions
        ) { progress in
            self.progressSubject.send(.processing(progress))
        }
    }
}
```

#### Model Management
```swift
class ModelManager: ObservableObject {
    @Published var availableModels: [WhisperModelType] = []
    @Published var downloadedModels: Set<WhisperModelType> = []
    @Published var currentDownloads: [WhisperModelType: DownloadProgress] = [:]
    
    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    
    init() {
        cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WhisperModels")
        
        setupCacheDirectory()
        loadAvailableModels()
    }
    
    func downloadModel(_ modelType: WhisperModelType) async throws {
        guard !downloadedModels.contains(modelType) else { return }
        
        let downloadURL = try getModelDownloadURL(modelType)
        let destinationURL = cacheDirectory.appendingPathComponent("\(modelType.rawValue).mlmodelc")
        
        // Check available storage
        try await checkStorageAvailability(requiredSpace: modelType.fileSize)
        
        // Download with progress tracking
        try await downloadWithProgress(from: downloadURL, to: destinationURL, modelType: modelType)
        
        // Verify downloaded model
        try await verifyModel(at: destinationURL, modelType: modelType)
        
        await MainActor.run {
            downloadedModels.insert(modelType)
            currentDownloads.removeValue(forKey: modelType)
        }
    }
    
    private func downloadWithProgress(from url: URL, to destination: URL, modelType: WhisperModelType) async throws {
        let (localURL, _) = try await URLSession.shared.download(from: url) { progress in
            Task { @MainActor in
                currentDownloads[modelType] = DownloadProgress(
                    fractionCompleted: progress.fractionCompleted,
                    totalBytes: progress.countOfBytesExpectedToReceive,
                    downloadedBytes: progress.countOfBytesReceived
                )
            }
        }
        
        try fileManager.moveItem(at: localURL, to: destination)
    }
}
```

### 4. Speaker Diarization (Pro版)

```swift
class SpeakerDiarizationService {
    private let audioAnalyzer: AudioAnalyzer
    private let voiceProfileManager: VoiceProfileManager
    
    func performSpeakerDiarization(
        audioURL: URL,
        transcriptionResult: TranscriptionResult
    ) async throws -> TranscriptionResult {
        
        // 1. Extract audio features
        let audioFeatures = try await audioAnalyzer.extractFeatures(from: audioURL)
        
        // 2. Segment audio by speaker changes
        let speakerSegments = try await segmentBySpeaker(audioFeatures)
        
        // 3. Identify speakers using voice profiles
        let identifiedSpeakers = try await identifySpeakers(speakerSegments)
        
        // 4. Map segments to transcription
        let updatedSegments = try mapSpeakersToTranscription(
            transcriptionSegments: transcriptionResult.segments,
            speakerSegments: speakerSegments,
            identifiedSpeakers: identifiedSpeakers
        )
        
        // 5. Generate speaker statistics
        let speakers = generateSpeakerStatistics(from: updatedSegments)
        
        return transcriptionResult.withSpeakers(speakers, segments: updatedSegments)
    }
    
    private func segmentBySpeaker(_ features: AudioFeatures) async throws -> [SpeakerSegment] {
        // Voice activity detection
        let voiceSegments = detectVoiceActivity(features)
        
        // Speaker change detection using clustering
        return try await detectSpeakerChanges(voiceSegments, features: features)
    }
    
    private func identifySpeakers(_ segments: [SpeakerSegment]) async throws -> [UUID: Speaker] {
        var identifiedSpeakers: [UUID: Speaker] = [:]
        
        for segment in segments {
            let voiceEmbedding = try await extractVoiceEmbedding(segment)
            
            if let existingSpeaker = try await voiceProfileManager.findSimilarSpeaker(voiceEmbedding) {
                identifiedSpeakers[segment.id] = existingSpeaker
            } else {
                let newSpeaker = Speaker.createNew(from: voiceEmbedding)
                identifiedSpeakers[segment.id] = newSpeaker
                try await voiceProfileManager.saveSpeaker(newSpeaker)
            }
        }
        
        return identifiedSpeakers
    }
}
```

### 5. Audio Processing Pipeline

```swift
class AudioProcessor {
    func convertToRequiredFormat(_ inputURL: URL) async throws -> URL {
        let outputURL = createTempURL(extension: "wav")
        
        let asset = AVAsset(url: inputURL)
        guard let assetTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw AudioProcessingError.noAudioTrack
        }
        
        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)
        exportSession?.outputURL = outputURL
        exportSession?.outputFileType = .wav
        
        // Configure audio settings for Whisper
        exportSession?.audioSettings = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000, // Whisper preferred sample rate
            AVNumberOfChannelsKey: 1, // Mono
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        try await exportSession?.export()
        return outputURL
    }
    
    func reduceNoise(_ inputURL: URL, level: NoiseReductionLevel) async throws -> URL {
        // Implement noise reduction using Core Audio or third-party library
        // This is a placeholder for advanced audio processing
        return inputURL
    }
    
    func analyzeAudioQuality(_ audioURL: URL) async throws -> AudioQualityMetrics {
        let asset = AVAsset(url: audioURL)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw AudioProcessingError.noAudioTrack
        }
        
        // Analyze SNR, dynamic range, clipping, etc.
        return AudioQualityMetrics(
            signalToNoiseRatio: try await calculateSNR(track),
            dynamicRange: try await calculateDynamicRange(track),
            hasClipping: try await detectClipping(track),
            averageLevel: try await calculateAverageLevel(track)
        )
    }
}
```

### 6. Data Layer設計

#### TranscriptionRepository
```swift
class TranscriptionRepository: TranscriptionRepositoryProtocol {
    private let coreDataManager: CoreDataManager
    
    func save(_ transcription: TranscriptionResult) async throws {
        try await coreDataManager.performBackgroundTask { context in
            let entity = TranscriptionEntity.fromDomainModel(transcription, context: context)
            
            // Link to recording
            let recordingRequest: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
            recordingRequest.predicate = NSPredicate(format: "id == %@", transcription.recordingId as CVarArg)
            
            if let recordingEntity = try context.fetch(recordingRequest).first {
                entity.recording = recordingEntity
            }
            
            try context.save()
        }
    }
    
    func findByRecordingId(_ recordingId: UUID) async throws -> TranscriptionResult? {
        let request: NSFetchRequest<TranscriptionEntity> = TranscriptionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "recordingId == %@", recordingId as CVarArg)
        request.fetchLimit = 1
        
        let entity = try await coreDataManager.fetchFirst(request)
        return entity?.toDomainModel()
    }
    
    func searchTranscriptions(query: String) async throws -> [TranscriptionResult] {
        let request: NSFetchRequest<TranscriptionEntity> = TranscriptionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "text CONTAINS[cd] %@", query)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TranscriptionEntity.createdAt, ascending: false)
        ]
        
        let entities = try await coreDataManager.fetch(request)
        return entities.map { $0.toDomainModel() }
    }
}
```

### 7. UI Layer設計

#### TranscriptionViewModel
```swift
@MainActor
class TranscriptionViewModel: ObservableObject {
    @Published var transcriptionState: TranscriptionState = .idle
    @Published var progress: TranscriptionProgress = .idle
    @Published var currentTranscription: TranscriptionResult?
    @Published var transcriptionQueue: [TranscriptionJob] = []
    @Published var availableModels: [WhisperModelType] = []
    @Published var selectedModel: WhisperModelType = .base
    @Published var transcriptionOptions = TranscriptionOptions()
    
    private let transcriptionUseCase: TranscriptionUseCase
    private let modelManager: ModelManager
    private var cancellables = Set<AnyCancellable>()
    
    func transcribeRecording(_ recording: Recording) async {
        let job = TranscriptionJob(
            id: UUID(),
            recording: recording,
            options: transcriptionOptions,
            priority: .normal
        )
        
        transcriptionQueue.append(job)
        
        if transcriptionState == .idle {
            await processNextJob()
        }
    }
    
    private func processNextJob() async {
        guard let job = transcriptionQueue.first else {
            transcriptionState = .idle
            return
        }
        
        transcriptionState = .processing(job)
        
        do {
            // Monitor progress
            let progressStream = transcriptionUseCase.transcribeWithProgress(
                recording: job.recording,
                options: job.options
            )
            
            for try await progressUpdate in progressStream {
                progress = progressUpdate
            }
            
            let result = try await transcriptionUseCase.transcribe(
                recording: job.recording,
                options: job.options
            )
            
            currentTranscription = result
            transcriptionQueue.removeFirst()
            
        } catch {
            handleTranscriptionError(error, job: job)
        }
        
        // Process next job
        await processNextJob()
    }
}
```

### 8. エラーハンドリング

```swift
enum TranscriptionError: LocalizedError, Equatable {
    case modelNotLoaded
    case modelDownloadFailed(WhisperModelType)
    case audioProcessingFailed
    case transcriptionFailed(String)
    case insufficientStorage(required: Int64, available: Int64)
    case unsupportedAudioFormat
    case audioFileTooLarge(size: Int64, maxSize: Int64)
    case modelCorrupted(WhisperModelType)
    case networkUnavailable
    
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
}
```

### 9. パフォーマンス最適化

#### メモリ管理
```swift
class WhisperMemoryManager {
    private var loadedModels: [WhisperModelType: WhisperKit] = [:]
    private let memoryPressureObserver = MemoryPressureObserver()
    
    func loadModel(_ modelType: WhisperModelType) async throws -> WhisperKit {
        // Check memory pressure
        if memoryPressureObserver.isUnderPressure {
            try await unloadLeastUsedModel()
        }
        
        if let existingModel = loadedModels[modelType] {
            return existingModel
        }
        
        let whisperKit = try await WhisperKit(modelFolder: modelType.rawValue)
        loadedModels[modelType] = whisperKit
        
        return whisperKit
    }
    
    private func unloadLeastUsedModel() async throws {
        guard let leastUsedModel = findLeastUsedModel() else { return }
        
        loadedModels.removeValue(forKey: leastUsedModel)
        // Force garbage collection
        autoreleasepool {
            // Release model resources
        }
    }
}
```

#### バッチ処理最適化
```swift
class BatchTranscriptionProcessor {
    private let maxConcurrentJobs = 2
    private let processingQueue = OperationQueue()
    
    init() {
        processingQueue.maxConcurrentOperationCount = maxConcurrentJobs
        processingQueue.qualityOfService = .userInitiated
    }
    
    func processBatch(_ jobs: [TranscriptionJob]) async throws -> [TranscriptionResult] {
        let operations = jobs.map { job in
            TranscriptionOperation(job: job, whisperService: whisperService)
        }
        
        processingQueue.addOperations(operations, waitUntilFinished: false)
        
        // Wait for completion and collect results
        return try await withThrowingTaskGroup(of: TranscriptionResult.self) { group in
            for operation in operations {
                group.addTask {
                    try await operation.result
                }
            }
            
            var results: [TranscriptionResult] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }
}
```

### 10. 設定・カスタマイゼーション

```swift
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
```

これらの設計により、高品質で効率的な文字起こし機能を実現し、ユーザーのプライバシーを保護しながら優れたUXを提供します。