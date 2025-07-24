import Foundation

struct VectorEmbedding: Identifiable, Codable, Equatable {
    let id: UUID
    let sourceType: SourceType
    let sourceId: UUID
    let chunkText: String
    let vector: [Float]
    let metadata: VectorMetadata
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        sourceType: SourceType,
        sourceId: UUID,
        chunkText: String,
        vector: [Float],
        metadata: VectorMetadata
    ) {
        self.id = id
        self.sourceType = sourceType
        self.sourceId = sourceId
        self.chunkText = chunkText
        self.vector = vector
        self.metadata = metadata
        self.createdAt = Date()
    }
    
    enum SourceType: String, Codable, CaseIterable {
        case recording
        case document
        case summary
        case transcript
    }
    
    // Vector operations
    func cosineSimilarity(with other: VectorEmbedding) -> Float {
        guard self.vector.count == other.vector.count else { return 0.0 }
        
        let dotProduct = zip(self.vector, other.vector)
            .map(*)
            .reduce(0, +)
        
        let magnitudeA = sqrt(self.vector.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(other.vector.map { $0 * $0 }.reduce(0, +))
        
        guard magnitudeA > 0 && magnitudeB > 0 else { return 0.0 }
        
        return dotProduct / (magnitudeA * magnitudeB)
    }
    
    func euclideanDistance(to other: VectorEmbedding) -> Float {
        guard self.vector.count == other.vector.count else { return Float.infinity }
        
        let squaredDifferences = zip(self.vector, other.vector)
            .map { ($0 - $1) * ($0 - $1) }
            .reduce(0, +)
        
        return sqrt(squaredDifferences)
    }
    
    // Computed properties
    var dimension: Int {
        vector.count
    }
    
    var magnitude: Float {
        sqrt(vector.map { $0 * $0 }.reduce(0, +))
    }
    
    var chunkWordCount: Int {
        chunkText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
    }
}

struct VectorMetadata: Codable, Equatable {
    let documentId: UUID?
    let recordingId: UUID?
    let chunkIndex: Int
    let startOffset: Int
    let endOffset: Int
    let source: String
    let timestamp: TimeInterval?
    let language: String
    let confidence: Float
    let additionalData: [String: String]
    
    init(
        documentId: UUID? = nil,
        recordingId: UUID? = nil,
        chunkIndex: Int,
        startOffset: Int,
        endOffset: Int,
        source: String,
        timestamp: TimeInterval? = nil,
        language: String = "ja",
        confidence: Float = 1.0,
        additionalData: [String: String] = [:]
    ) {
        self.documentId = documentId
        self.recordingId = recordingId
        self.chunkIndex = chunkIndex
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.source = source
        self.timestamp = timestamp
        self.language = language
        self.confidence = confidence
        self.additionalData = additionalData
    }
}

// MARK: - Search Result
struct SearchResult: Identifiable, Equatable {
    let id: UUID
    let sourceId: UUID
    let sourceType: VectorEmbedding.SourceType
    let chunkText: String
    let similarity: Float
    let metadata: VectorMetadata
    let relevanceScore: Float
    
    init(
        id: UUID = UUID(),
        sourceId: UUID,
        sourceType: VectorEmbedding.SourceType,
        chunkText: String,
        similarity: Float,
        metadata: VectorMetadata,
        relevanceScore: Float? = nil
    ) {
        self.id = id
        self.sourceId = sourceId
        self.sourceType = sourceType
        self.chunkText = chunkText
        self.similarity = similarity
        self.metadata = metadata
        self.relevanceScore = relevanceScore ?? similarity
    }
    
    // Computed properties
    var formattedSimilarity: String {
        String(format: "%.2f", similarity * 100) + "%"
    }
    
    var isHighRelevance: Bool {
        similarity > 0.8
    }
    
    var isMediumRelevance: Bool {
        similarity > 0.6 && similarity <= 0.8
    }
    
    var isLowRelevance: Bool {
        similarity <= 0.6
    }
}