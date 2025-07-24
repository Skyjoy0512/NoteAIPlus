import Foundation

struct Recording: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    let date: Date
    let duration: TimeInterval
    let audioFileURL: URL
    
    // Computed property for backward compatibility
    var fileURL: URL { audioFileURL }
    var transcription: String?
    let whisperModel: String
    let language: String
    let isFromLimitless: Bool
    let createdAt: Date
    var updatedAt: Date
    
    // Relationships
    var speakers: [Speaker]
    var summaries: [Summary]
    var tags: [Tag]
    
    init(
        id: UUID = UUID(),
        title: String,
        date: Date = Date(),
        duration: TimeInterval,
        audioFileURL: URL,
        transcription: String? = nil,
        whisperModel: String = "base",
        language: String = "ja",
        isFromLimitless: Bool = false,
        speakers: [Speaker] = [],
        summaries: [Summary] = [],
        tags: [Tag] = []
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.duration = duration
        self.audioFileURL = audioFileURL
        self.transcription = transcription
        self.whisperModel = whisperModel
        self.language = language
        self.isFromLimitless = isFromLimitless
        self.createdAt = date
        self.updatedAt = date
        self.speakers = speakers
        self.summaries = summaries
        self.tags = tags
    }
    
    // Computed properties
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
    
    var hasTranscription: Bool {
        return transcription != nil && !transcription!.isEmpty
    }
    
    var isEmpty: Bool {
        return duration < 1.0
    }
    
    // Helper methods
    mutating func updateTranscription(_ text: String) {
        self.transcription = text
        self.updatedAt = Date()
    }
    
    mutating func addSummary(_ summary: Summary) {
        self.summaries.append(summary)
        self.updatedAt = Date()
    }
    
    mutating func addTag(_ tag: Tag) {
        if !self.tags.contains(tag) {
            self.tags.append(tag)
            self.updatedAt = Date()
        }
    }
}