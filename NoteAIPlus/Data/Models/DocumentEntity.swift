import Foundation
import CoreData

@objc(DocumentEntity)
public class DocumentEntity: NSManagedObject {
    
    func toDomainModel() -> Document {
        let documentType = Document.DocumentType(rawValue: self.typeString ?? "") ?? .text
        let tags = (self.tags?.allObjects as? [TagEntity])?.map { $0.toDomainModel() } ?? []
        let summaries = (self.summaries?.allObjects as? [SummaryEntity])?.map { $0.toDomainModel() } ?? []
        
        let originalURL: URL?
        if let urlString = self.originalURLString, !urlString.isEmpty {
            originalURL = URL(string: urlString)
        } else {
            originalURL = nil
        }
        
        return Document(
            id: self.id ?? UUID(),
            type: documentType,
            title: self.title ?? "",
            content: self.content ?? "",
            originalURL: originalURL,
            fileSize: self.fileSize,
            checksum: self.checksum ?? "",
            tags: tags,
            summaries: summaries
        )
    }
    
    static func fromDomainModel(_ document: Document, context: NSManagedObjectContext) -> DocumentEntity {
        let entity = DocumentEntity(context: context)
        entity.updateFromDomainModel(document)
        return entity
    }
    
    func updateFromDomainModel(_ document: Document) {
        self.id = document.id
        self.typeString = document.type.rawValue
        self.title = document.title
        self.content = document.content
        self.originalURLString = document.originalURL?.absoluteString
        self.fileSize = document.fileSize
        self.checksum = document.checksum
        self.createdAt = document.createdAt
        self.updatedAt = document.updatedAt
    }
}

// MARK: - Core Data Properties

extension DocumentEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DocumentEntity> {
        return NSFetchRequest<DocumentEntity>(entityName: "DocumentEntity")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var typeString: String?
    @NSManaged public var title: String?
    @NSManaged public var content: String?
    @NSManaged public var originalURLString: String?
    @NSManaged public var fileSize: Int64
    @NSManaged public var checksum: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    
    // Relationships
    @NSManaged public var tags: NSSet?
    @NSManaged public var summaries: NSSet?
    @NSManaged public var embeddings: NSSet?
}

// MARK: - Generated accessors for tags

extension DocumentEntity {
    
    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: TagEntity)
    
    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: TagEntity)
    
    @objc(addTags:)
    @NSManaged public func addToTags(_ values: NSSet)
    
    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: NSSet)
}

// MARK: - Generated accessors for summaries

extension DocumentEntity {
    
    @objc(addSummariesObject:)
    @NSManaged public func addToSummaries(_ value: SummaryEntity)
    
    @objc(removeSummariesObject:)
    @NSManaged public func removeFromSummaries(_ value: SummaryEntity)
    
    @objc(addSummaries:)
    @NSManaged public func addToSummaries(_ values: NSSet)
    
    @objc(removeSummaries:)
    @NSManaged public func removeFromSummaries(_ values: NSSet)
}

// MARK: - Generated accessors for embeddings

extension DocumentEntity {
    
    @objc(addEmbeddingsObject:)
    @NSManaged public func addToEmbeddings(_ value: VectorEmbeddingEntity)
    
    @objc(removeEmbeddingsObject:)
    @NSManaged public func removeFromEmbeddings(_ value: VectorEmbeddingEntity)
    
    @objc(addEmbeddings:)
    @NSManaged public func addToEmbeddings(_ values: NSSet)
    
    @objc(removeEmbeddings:)
    @NSManaged public func removeFromEmbeddings(_ values: NSSet)
}