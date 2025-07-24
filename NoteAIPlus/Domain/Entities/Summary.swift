import Foundation

struct Summary: Identifiable, Codable, Equatable {
    let id: UUID
    let sourceId: UUID // Recording or Document ID
    let sourceType: SourceType
    let summaryType: SummaryType
    let content: String
    let model: String
    let prompt: String
    let keyPoints: [KeyPoint]
    let confidence: Float
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        sourceId: UUID,
        sourceType: SourceType,
        summaryType: SummaryType,
        content: String,
        model: String,
        prompt: String,
        keyPoints: [KeyPoint] = [],
        confidence: Float = 0.8
    ) {
        self.id = id
        self.sourceId = sourceId
        self.sourceType = sourceType
        self.summaryType = summaryType
        self.content = content
        self.model = model
        self.prompt = prompt
        self.keyPoints = keyPoints
        self.confidence = confidence
        self.createdAt = Date()
    }
    
    enum SourceType: String, Codable, CaseIterable {
        case recording
        case document
        case combined
    }
    
    enum SummaryType: String, Codable, CaseIterable {
        case brief = "簡潔要約"
        case detailed = "詳細要約"
        case keyPoints = "要点整理"
        case actionItems = "アクションアイテム"
        case meetingMinutes = "議事録"
        case qa = "Q&A形式"
        
        var icon: String {
            switch self {
            case .brief: return "doc.text"
            case .detailed: return "doc.text.fill"
            case .keyPoints: return "list.bullet"
            case .actionItems: return "checkmark.circle"
            case .meetingMinutes: return "person.3"
            case .qa: return "questionmark.circle"
            }
        }
    }
    
    // Computed properties
    var wordCount: Int {
        content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
    }
    
    var estimatedReadingTime: TimeInterval {
        // 日本語の平均読書速度: 約400文字/分
        let charactersPerMinute: Double = 400
        let characters = Double(content.count)
        return (characters / charactersPerMinute) * 60
    }
}

struct KeyPoint: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let description: String
    let importance: Importance
    let timestamp: TimeInterval? // 録音からのタイムスタンプ
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        importance: Importance = .medium,
        timestamp: TimeInterval? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.importance = importance
        self.timestamp = timestamp
    }
    
    enum Importance: String, Codable, CaseIterable {
        case low = "低"
        case medium = "中"
        case high = "高"
        
        var color: String {
            switch self {
            case .low: return "gray"
            case .medium: return "blue"
            case .high: return "red"
            }
        }
        
        var priority: Int {
            switch self {
            case .low: return 1
            case .medium: return 2
            case .high: return 3
            }
        }
    }
}