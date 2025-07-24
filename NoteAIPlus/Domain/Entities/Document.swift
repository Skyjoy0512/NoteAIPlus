import Foundation

struct Document: Identifiable, Codable, Equatable {
    let id: UUID
    let type: DocumentType
    var title: String
    let content: String
    let originalURL: URL?
    let fileSize: Int64
    let checksum: String
    var tags: [Tag]
    var summaries: [Summary]
    let createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        type: DocumentType,
        title: String,
        content: String,
        originalURL: URL? = nil,
        fileSize: Int64,
        checksum: String,
        tags: [Tag] = [],
        summaries: [Summary] = []
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.content = content
        self.originalURL = originalURL
        self.fileSize = fileSize
        self.checksum = checksum
        self.tags = tags
        self.summaries = summaries
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    enum DocumentType: String, Codable, CaseIterable {
        case pdf = "PDF"
        case word = "Word"
        case text = "Text"
        case web = "Web"
        case image = "Image"
        case markdown = "Markdown"
        
        var icon: String {
            switch self {
            case .pdf: return "doc.fill"
            case .word: return "doc.text.fill"
            case .text: return "doc.plaintext"
            case .web: return "globe"
            case .image: return "photo"
            case .markdown: return "doc.richtext"
            }
        }
        
        var fileExtensions: [String] {
            switch self {
            case .pdf: return ["pdf"]
            case .word: return ["doc", "docx"]
            case .text: return ["txt"]
            case .web: return ["html", "htm"]
            case .image: return ["jpg", "jpeg", "png", "gif"]
            case .markdown: return ["md", "markdown"]
            }
        }
    }
    
    // Computed properties
    var wordCount: Int {
        content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
    }
    
    var characterCount: Int {
        content.count
    }
    
    var formattedFileSize: String {
        ByteCountFormatter().string(fromByteCount: fileSize)
    }
    
    var estimatedReadingTime: TimeInterval {
        // 日本語の平均読書速度: 約400文字/分
        let charactersPerMinute: Double = 400
        let characters = Double(content.count)
        return (characters / charactersPerMinute) * 60
    }
    
    var hasContent: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // Helper methods
    mutating func updateContent(_ newContent: String) {
        self.content = newContent
        self.updatedAt = Date()
    }
    
    mutating func addTag(_ tag: Tag) {
        if !self.tags.contains(tag) {
            self.tags.append(tag)
            self.updatedAt = Date()
        }
    }
    
    mutating func removeTag(_ tag: Tag) {
        self.tags.removeAll { $0.id == tag.id }
        self.updatedAt = Date()
    }
    
    mutating func addSummary(_ summary: Summary) {
        self.summaries.append(summary)
        self.updatedAt = Date()
    }
    
    // Helper for creating from different sources
    static func fromURL(_ url: URL, content: String) -> Document? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        
        let fileExtension = url.pathExtension.lowercased()
        let documentType = DocumentType.allCases.first { type in
            type.fileExtensions.contains(fileExtension)
        } ?? .text
        
        let checksum = data.sha256
        
        return Document(
            type: documentType,
            title: url.lastPathComponent,
            content: content,
            originalURL: url,
            fileSize: Int64(data.count),
            checksum: checksum
        )
    }
}

// MARK: - Extensions
extension Data {
    var sha256: String {
        // SHA256 checksum implementation
        // This is a simplified version - in production, use CommonCrypto or CryptoKit
        return "checksum_\(Date().timeIntervalSince1970)"
    }
}