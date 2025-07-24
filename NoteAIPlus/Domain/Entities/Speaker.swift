import Foundation

struct Speaker: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let displayName: String?
    let voiceEmbedding: VoiceEmbedding?
    let confidence: Float
    let voiceCharacteristics: VoiceCharacteristics?
    let createdAt: Date
    let lastSeenAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        displayName: String? = nil,
        voiceEmbedding: VoiceEmbedding? = nil,
        confidence: Float,
        voiceCharacteristics: VoiceCharacteristics? = nil,
        createdAt: Date = Date(),
        lastSeenAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.voiceEmbedding = voiceEmbedding
        self.confidence = confidence
        self.voiceCharacteristics = voiceCharacteristics
        self.createdAt = createdAt
        self.lastSeenAt = lastSeenAt
    }
    
    var effectiveDisplayName: String {
        displayName ?? name
    }
    
    static func createNew(from voiceEmbedding: VoiceEmbedding) -> Speaker {
        let speakerCount = UserDefaults.standard.integer(forKey: "speakerCount") + 1
        UserDefaults.standard.set(speakerCount, forKey: "speakerCount")
        
        return Speaker(
            name: "話者\(speakerCount)",
            voiceEmbedding: voiceEmbedding,
            confidence: 0.8
        )
    }
}

struct VoiceEmbedding: Codable, Equatable {
    let values: [Float]
    
    init(values: [Float]) {
        self.values = values
    }
    
    func similarity(to other: VoiceEmbedding) -> Float {
        guard values.count == other.values.count else { return 0.0 }
        
        // Calculate cosine similarity
        let dotProduct = zip(values, other.values).map(*).reduce(0, +)
        let norm1 = sqrt(values.map { $0 * $0 }.reduce(0, +))
        let norm2 = sqrt(other.values.map { $0 * $0 }.reduce(0, +))
        
        guard norm1 > 0 && norm2 > 0 else { return 0.0 }
        
        return dotProduct / (norm1 * norm2)
    }
}

struct VoiceCharacteristics: Codable, Equatable {
    let estimatedAge: Int?
    let estimatedGender: Gender?
    let voiceType: VoiceType?
    
    init(
        estimatedAge: Int? = nil,
        estimatedGender: Gender? = nil,
        voiceType: VoiceType? = nil
    ) {
        self.estimatedAge = estimatedAge
        self.estimatedGender = estimatedGender
        self.voiceType = voiceType
    }
}

enum Gender: String, CaseIterable, Codable {
    case male = "male"
    case female = "female"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .male: return "男性"
        case .female: return "女性"
        case .unknown: return "不明"
        }
    }
}

enum VoiceType: String, CaseIterable, Codable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var displayName: String {
        switch self {
        case .high: return "高音"
        case .medium: return "中音"
        case .low: return "低音"
        }
    }
}

// Legacy compatibility - deprecated but kept for backward compatibility
@available(*, deprecated, message: "Use Speaker with VoiceEmbedding instead")
struct VoiceProfile: Codable, Equatable {
    let characteristics: [String: Float]
    let embedding: [Float]
    let confidence: Float
    
    init(characteristics: [String: Float], embedding: [Float], confidence: Float) {
        self.characteristics = characteristics
        self.embedding = embedding
        self.confidence = confidence
    }
}

@available(*, deprecated, message: "Use TranscriptionSegment instead")
struct SpeechSegment: Identifiable, Codable, Equatable {
    let id: UUID
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
    let confidence: Float
    let speakerId: UUID
    
    init(
        id: UUID = UUID(),
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String,
        confidence: Float,
        speakerId: UUID
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.confidence = confidence
        self.speakerId = speakerId
    }
    
    var duration: TimeInterval {
        endTime - startTime
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