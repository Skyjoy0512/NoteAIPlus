import Foundation
import CoreData

@objc(TagEntity)
public class TagEntity: NSManagedObject {
    
    func toDomainModel() -> Tag {
        let color = Tag.TagColor(rawValue: self.colorString ?? "") ?? .blue
        let category = Tag.TagCategory(rawValue: self.categoryString ?? "") ?? .general
        
        return Tag(
            id: self.id ?? UUID(),
            name: self.name ?? "",
            color: color,
            category: category,
            usageCount: Int(self.usageCount)
        )
    }
    
    static func fromDomainModel(_ tag: Tag, context: NSManagedObjectContext) -> TagEntity {
        let entity = TagEntity(context: context)
        entity.updateFromDomainModel(tag)
        return entity
    }
    
    func updateFromDomainModel(_ tag: Tag) {
        self.id = tag.id
        self.name = tag.name
        self.colorString = tag.color.rawValue
        self.categoryString = tag.category.rawValue
        self.usageCount = Int32(tag.usageCount)
        self.createdAt = tag.createdAt
    }
}

// MARK: - Core Data Properties

extension TagEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TagEntity> {
        return NSFetchRequest<TagEntity>(entityName: "TagEntity")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var colorString: String?
    @NSManaged public var categoryString: String?
    @NSManaged public var usageCount: Int32
    @NSManaged public var createdAt: Date?
    
    // Relationships
    @NSManaged public var recordings: NSSet?
    @NSManaged public var documents: NSSet?
}

// MARK: - Generated accessors for recordings

extension TagEntity {
    
    @objc(addRecordingsObject:)
    @NSManaged public func addToRecordings(_ value: RecordingEntity)
    
    @objc(removeRecordingsObject:)
    @NSManaged public func removeFromRecordings(_ value: RecordingEntity)
    
    @objc(addRecordings:)
    @NSManaged public func addToRecordings(_ values: NSSet)
    
    @objc(removeRecordings:)
    @NSManaged public func removeFromRecordings(_ values: NSSet)
}

// MARK: - Generated accessors for documents

extension TagEntity {
    
    @objc(addDocumentsObject:)
    @NSManaged public func addToDocuments(_ value: DocumentEntity)
    
    @objc(removeDocumentsObject:)
    @NSManaged public func removeFromDocuments(_ value: DocumentEntity)
    
    @objc(addDocuments:)
    @NSManaged public func addToDocuments(_ values: NSSet)
    
    @objc(removeDocuments:)
    @NSManaged public func removeFromDocuments(_ values: NSSet)
}