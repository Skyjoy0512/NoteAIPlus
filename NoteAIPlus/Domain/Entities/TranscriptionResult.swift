import Foundation

struct TranscriptionResult: Identifiable, Codable, Equatable {
    let id: UUID
    let recordingId: UUID
    let text: String
    let language: String
    let confidence: Float
    let modelType: WhisperModelType
    let processingTime: TimeInterval
    let segments: [TranscriptionSegment]
    let speakers: [Speaker]? // Pro版のみ
    let metadata: TranscriptionMetadata
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        recordingId: UUID,
        text: String,
        language: String,
        confidence: Float,
        modelType: WhisperModelType,
        processingTime: TimeInterval,
        segments: [TranscriptionSegment] = [],
        speakers: [Speaker]? = nil,
        metadata: TranscriptionMetadata? = nil
    ) {
        self.id = id
        self.recordingId = recordingId
        self.text = text
        self.language = language
        self.confidence = confidence
        self.modelType = modelType
        self.processingTime = processingTime
        self.segments = segments
        self.speakers = speakers
        self.metadata = metadata ?? TranscriptionMetadata()
        self.createdAt = Date()
    }
    
    // Computed properties
    var wordCount: Int {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
    }
    
    var averageConfidence: Float {
        guard !segments.isEmpty else { return confidence }
        return segments.map(\.confidence).reduce(0, +) / Float(segments.count)
    }
    
    var hasTimestamps: Bool {
        !segments.isEmpty
    }
    
    var hasSpeakerDiarization: Bool {
        speakers?.isEmpty == false
    }
    
    var estimatedReadingTime: TimeInterval {
        // 日本語平均読書速度: 約400文字/分
        let charactersPerMinute: Double = 400
        return Double(text.count) / charactersPerMinute * 60
    }
    
    var qualityScore: TranscriptionQuality {
        switch averageConfidence {
        case 0.9...1.0: return .excellent
        case 0.8..<0.9: return .good
        case 0.7..<0.8: return .fair
        case 0.6..<0.7: return .poor
        default: return .veryPoor
        }
    }
    
    // Helper methods
    func withSpeakers(_ speakers: [Speaker], segments: [TranscriptionSegment]) -> TranscriptionResult {
        return TranscriptionResult(
            id: self.id,
            recordingId: self.recordingId,
            text: self.text,
            language: self.language,
            confidence: self.confidence,
            modelType: self.modelType,
            processingTime: self.processingTime,
            segments: segments,
            speakers: speakers,
            metadata: self.metadata
        )
    }
    
    func getSpeakerStatistics() -> [SpeakerStatistic] {
        guard let speakers = speakers, !segments.isEmpty else { return [] }
        
        return speakers.map { speaker in
            let speakerSegments = segments.filter { $0.speakerId == speaker.id }
            let totalDuration = speakerSegments.reduce(0) { $0 + $1.duration }
            let wordCount = speakerSegments.reduce(0) { $0 + $1.wordCount }
            
            return SpeakerStatistic(
                speaker: speaker,
                segmentCount: speakerSegments.count,
                totalDuration: totalDuration,
                wordCount: wordCount,
                averageConfidence: speakerSegments.isEmpty ? 0 : 
                    speakerSegments.map(\.confidence).reduce(0, +) / Float(speakerSegments.count)
            )
        }
    }
}

struct TranscriptionSegment: Identifiable, Codable, Equatable {
    let id: UUID
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
    let confidence: Float
    let tokens: [TranscriptionToken]
    let speakerId: UUID? // Pro版のみ
    
    init(
        id: UUID = UUID(),
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String,
        confidence: Float,
        tokens: [TranscriptionToken] = [],
        speakerId: UUID? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.confidence = confidence
        self.tokens = tokens
        self.speakerId = speakerId
    }
    
    var duration: TimeInterval {
        endTime - startTime
    }
    
    var wordsPerMinute: Double {
        guard duration > 0 else { return 0 }
        return Double(wordCount) / (duration / 60)
    }
    
    var wordCount: Int {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
    }
    
    var formattedTimeRange: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        
        let start = formatter.string(from: startTime) ?? "0:00"
        let end = formatter.string(from: endTime) ?? "0:00"
        return "\(start) - \(end)"
    }
}

struct TranscriptionToken: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Float
    let logProbability: Float
    
    init(
        id: UUID = UUID(),
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        confidence: Float,
        logProbability: Float
    ) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
        self.logProbability = logProbability
    }
}

struct TranscriptionMetadata: Codable, Equatable {
    let audioFormat: String
    let sampleRate: Int
    let channels: Int
    let bitRate: Int?
    let audioQuality: AudioQualityMetrics?
    let processingInfo: ProcessingInfo
    
    init(
        audioFormat: String = "m4a",
        sampleRate: Int = 16000,
        channels: Int = 1,
        bitRate: Int? = nil,
        audioQuality: AudioQualityMetrics? = nil,
        processingInfo: ProcessingInfo = ProcessingInfo()
    ) {
        self.audioFormat = audioFormat
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitRate = bitRate
        self.audioQuality = audioQuality
        self.processingInfo = processingInfo
    }
}

struct ProcessingInfo: Codable, Equatable {
    let deviceModel: String
    let osVersion: String
    let whisperKitVersion: String
    let processingDate: Date
    let preprocessingApplied: [String]
    let postprocessingApplied: [String]
    
    init(
        deviceModel: String = UIDevice.current.model,
        osVersion: String = UIDevice.current.systemVersion,
        whisperKitVersion: String = "0.5.0", // 実際はWhisperKitから取得
        preprocessingApplied: [String] = [],
        postprocessingApplied: [String] = []
    ) {
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.whisperKitVersion = whisperKitVersion
        self.processingDate = Date()
        self.preprocessingApplied = preprocessingApplied
        self.postprocessingApplied = postprocessingApplied
    }
}

struct AudioQualityMetrics: Codable, Equatable {
    let signalToNoiseRatio: Float
    let dynamicRange: Float
    let hasClipping: Bool
    let averageLevel: Float
    let peakLevel: Float
    let spectralCentroid: Float?
    
    init(
        signalToNoiseRatio: Float,
        dynamicRange: Float,
        hasClipping: Bool,
        averageLevel: Float,
        peakLevel: Float,
        spectralCentroid: Float? = nil
    ) {
        self.signalToNoiseRatio = signalToNoiseRatio
        self.dynamicRange = dynamicRange
        self.hasClipping = hasClipping
        self.averageLevel = averageLevel
        self.peakLevel = peakLevel
        self.spectralCentroid = spectralCentroid
    }
    
    var qualityRating: AudioQualityRating {
        if hasClipping { return .poor }
        if signalToNoiseRatio < 10 { return .poor }
        if signalToNoiseRatio < 20 { return .fair }
        if signalToNoiseRatio < 30 { return .good }
        return .excellent
    }
}

struct SpeakerStatistic: Identifiable, Equatable {
    let id = UUID()
    let speaker: Speaker
    let segmentCount: Int
    let totalDuration: TimeInterval
    let wordCount: Int
    let averageConfidence: Float
    
    var speakingPercentage: Double {
        // Total recording durationが必要だが、ここでは簡略化
        return totalDuration
    }
    
    var wordsPerMinute: Double {
        guard totalDuration > 0 else { return 0 }
        return Double(wordCount) / (totalDuration / 60)
    }
}

enum TranscriptionQuality: String, CaseIterable {
    case excellent = "優秀"
    case good = "良好"
    case fair = "普通"
    case poor = "低い"
    case veryPoor = "非常に低い"
    
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "yellow"
        case .poor: return "orange"
        case .veryPoor: return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .fair: return "minus.circle"
        case .poor: return "exclamationmark.triangle"
        case .veryPoor: return "xmark.circle"
        }
    }
}

enum AudioQualityRating: String, CaseIterable {
    case excellent = "優秀"
    case good = "良好"
    case fair = "普通"
    case poor = "低い"
}

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
    
    var expectedAccuracy: Float {
        switch self {
        case .tiny: return 0.85
        case .base: return 0.90
        case .small: return 0.95
        case .medium: return 0.97
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
    
    var isProOnly: Bool {
        return self == .medium
    }
}

enum UsageScenario: String, CaseIterable {
    case quickNotes = "簡単なメモ"
    case generalUse = "一般的な使用"
    case meetings = "会議"
    case lectures = "講義"
    case interviews = "インタビュー"
    case batteryConstrained = "バッテリー制約"
    case accuracyRequired = "高精度が必要"
    case transcriptionService = "文字起こしサービス"
    case professionalUse = "プロフェッショナル用途"
    case maxAccuracy = "最高精度"
}