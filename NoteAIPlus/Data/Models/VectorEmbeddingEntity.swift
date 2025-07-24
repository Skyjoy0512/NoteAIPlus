import Foundation
import CoreData

@objc(VectorEmbeddingEntity)
public class VectorEmbeddingEntity: NSManagedObject {
    
    func toDomainModel() -> VectorEmbedding {
        let sourceType = VectorEmbedding.SourceType(rawValue: self.sourceTypeString ?? "") ?? .recording
        
        // Decode metadata from JSON
        var metadata = VectorMetadata(
            chunkIndex: Int(self.chunkIndex),
            startOffset: Int(self.startOffset),
            endOffset: Int(self.endOffset),
            source: self.source ?? ""
        )
        
        if let metadataData = self.metadataJSON,
           let decodedMetadata = try? JSONDecoder().decode(VectorMetadata.self, from: metadataData) {
            metadata = decodedMetadata
        }
        
        // Decode vector from Data
        var vector: [Float] = []
        if let vectorData = self.vectorData {
            vector = vectorData.withUnsafeBytes { bytes in
                Array(bytes.bindMemory(to: Float.self))
            }
        }
        
        return VectorEmbedding(
            id: self.id ?? UUID(),
            sourceType: sourceType,
            sourceId: self.sourceId ?? UUID(),
            chunkText: self.chunkText ?? "",
            vector: vector,
            metadata: metadata
        )
    }
    
    static func fromDomainModel(_ embedding: VectorEmbedding, context: NSManagedObjectContext) -> VectorEmbeddingEntity {
        let entity = VectorEmbeddingEntity(context: context)
        entity.updateFromDomainModel(embedding)
        return entity
    }
    
    func updateFromDomainModel(_ embedding: VectorEmbedding) {
        self.id = embedding.id
        self.sourceTypeString = embedding.sourceType.rawValue
        self.sourceId = embedding.sourceId
        self.chunkText = embedding.chunkText
        self.createdAt = embedding.createdAt
        
        // Encode vector to Data
        self.vectorData = Data(bytes: embedding.vector, count: embedding.vector.count * MemoryLayout<Float>.size)
        
        // Encode metadata to JSON
        if let metadataData = try? JSONEncoder().encode(embedding.metadata) {
            self.metadataJSON = metadataData
        }
        
        // Store frequently accessed metadata fields separately for Core Data queries
        self.chunkIndex = Int32(embedding.metadata.chunkIndex)
        self.startOffset = Int32(embedding.metadata.startOffset)
        self.endOffset = Int32(embedding.metadata.endOffset)
        self.source = embedding.metadata.source
        self.language = embedding.metadata.language
        self.confidence = embedding.metadata.confidence
        self.timestamp = embedding.metadata.timestamp ?? 0
    }
}

// MARK: - Core Data Properties

extension VectorEmbeddingEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<VectorEmbeddingEntity> {
        return NSFetchRequest<VectorEmbeddingEntity>(entityName: "VectorEmbeddingEntity")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var sourceTypeString: String?
    @NSManaged public var sourceId: UUID?
    @NSManaged public var chunkText: String?
    @NSManaged public var vectorData: Data?
    @NSManaged public var metadataJSON: Data?
    @NSManaged public var createdAt: Date?
    
    // Frequently queried metadata fields (denormalized for performance)
    @NSManaged public var chunkIndex: Int32
    @NSManaged public var startOffset: Int32
    @NSManaged public var endOffset: Int32
    @NSManaged public var source: String?
    @NSManaged public var language: String?
    @NSManaged public var confidence: Float
    @NSManaged public var timestamp: Double
    
    // Relationships
    @NSManaged public var recording: RecordingEntity?
    @NSManaged public var document: DocumentEntity?
}

// MARK: - Convenience methods

extension VectorEmbeddingEntity {
    
    /// Get vector as Float array
    var vectorArray: [Float] {
        guard let vectorData = self.vectorData else { return [] }
        return vectorData.withUnsafeBytes { bytes in
            Array(bytes.bindMemory(to: Float.self))
        }
    }
    
    /// Calculate cosine similarity with another embedding
    func cosineSimilarity(with other: VectorEmbeddingEntity) -> Float {
        let vectorA = self.vectorArray
        let vectorB = other.vectorArray
        
        guard vectorA.count == vectorB.count, !vectorA.isEmpty else { return 0.0 }
        
        let dotProduct = zip(vectorA, vectorB).map(*).reduce(0, +)
        let magnitudeA = sqrt(vectorA.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(vectorB.map { $0 * $0 }.reduce(0, +))
        
        guard magnitudeA > 0 && magnitudeB > 0 else { return 0.0 }
        
        return dotProduct / (magnitudeA * magnitudeB)
    }
}