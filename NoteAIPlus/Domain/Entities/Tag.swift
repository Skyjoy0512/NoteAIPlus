import Foundation

struct Tag: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let name: String
    let color: TagColor
    let category: TagCategory
    let createdAt: Date
    var usageCount: Int
    
    init(
        id: UUID = UUID(),
        name: String,
        color: TagColor = .blue,
        category: TagCategory = .general,
        usageCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.category = category
        self.createdAt = Date()
        self.usageCount = usageCount
    }
    
    enum TagColor: String, Codable, CaseIterable {
        case red
        case orange
        case yellow
        case green
        case blue
        case purple
        case pink
        case gray
        
        var displayName: String {
            switch self {
            case .red: return "赤"
            case .orange: return "オレンジ"
            case .yellow: return "黄"
            case .green: return "緑"
            case .blue: return "青"
            case .purple: return "紫"
            case .pink: return "ピンク"
            case .gray: return "グレー"
            }
        }
    }
    
    enum TagCategory: String, Codable, CaseIterable {
        case general = "一般"
        case meeting = "会議"
        case lecture = "講義"
        case interview = "インタビュー"
        case memo = "メモ"
        case learning = "学習"
        case work = "仕事"
        case personal = "個人"
        case research = "研究"
        case project = "プロジェクト"
        
        var icon: String {
            switch self {
            case .general: return "tag"
            case .meeting: return "person.3"
            case .lecture: return "graduationcap"
            case .interview: return "mic"
            case .memo: return "note.text"
            case .learning: return "book"
            case .work: return "briefcase"
            case .personal: return "person"
            case .research: return "magnifyingglass"
            case .project: return "folder"
            }
        }
    }
    
    // Helper methods
    mutating func incrementUsage() {
        usageCount += 1
    }
    
    // Static predefined tags
    static let defaultTags: [Tag] = [
        Tag(name: "会議", color: .blue, category: .meeting),
        Tag(name: "講義", color: .green, category: .lecture),
        Tag(name: "インタビュー", color: .orange, category: .interview),
        Tag(name: "メモ", color: .yellow, category: .memo),
        Tag(name: "学習", color: .purple, category: .learning),
        Tag(name: "仕事", color: .red, category: .work),
        Tag(name: "個人", color: .pink, category: .personal),
        Tag(name: "研究", color: .gray, category: .research)
    ]
}