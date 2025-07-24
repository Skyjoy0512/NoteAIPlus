import Foundation
import CoreData

@objc(SummaryEntity)
public class SummaryEntity: NSManagedObject {
    
    func toDomainModel() -> Summary {
        let keyPoints = (self.keyPoints?.allObjects as? [KeyPointEntity])?.map { $0.toDomainModel() } ?? []
        
        let sourceType = Summary.SourceType(rawValue: self.sourceTypeString ?? "") ?? .recording
        let summaryType = Summary.SummaryType(rawValue: self.summaryTypeString ?? "") ?? .brief
        
        return Summary(
            id: self.id ?? UUID(),
            sourceId: self.sourceId ?? UUID(),
            sourceType: sourceType,
            summaryType: summaryType,
            content: self.content ?? "",
            model: self.model ?? "",
            prompt: self.prompt ?? "",
            keyPoints: keyPoints,
            confidence: self.confidence
        )
    }
    
    static func fromDomainModel(_ summary: Summary, context: NSManagedObjectContext) -> SummaryEntity {
        let entity = SummaryEntity(context: context)
        entity.updateFromDomainModel(summary)
        return entity
    }
    
    func updateFromDomainModel(_ summary: Summary) {
        self.id = summary.id
        self.sourceId = summary.sourceId
        self.sourceTypeString = summary.sourceType.rawValue
        self.summaryTypeString = summary.summaryType.rawValue
        self.content = summary.content
        self.model = summary.model
        self.prompt = summary.prompt
        self.confidence = summary.confidence
        self.createdAt = summary.createdAt
    }
}

// MARK: - Core Data Properties

extension SummaryEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SummaryEntity> {
        return NSFetchRequest<SummaryEntity>(entityName: "SummaryEntity")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var sourceId: UUID?
    @NSManaged public var sourceTypeString: String?
    @NSManaged public var summaryTypeString: String?
    @NSManaged public var content: String?
    @NSManaged public var model: String?
    @NSManaged public var prompt: String?
    @NSManaged public var confidence: Float
    @NSManaged public var createdAt: Date?
    
    // Relationships
    @NSManaged public var recording: RecordingEntity?
    @NSManaged public var document: DocumentEntity?
    @NSManaged public var keyPoints: NSSet?
}

// MARK: - Generated accessors for keyPoints

extension SummaryEntity {
    
    @objc(addKeyPointsObject:)
    @NSManaged public func addToKeyPoints(_ value: KeyPointEntity)
    
    @objc(removeKeyPointsObject:)
    @NSManaged public func removeFromKeyPoints(_ value: KeyPointEntity)
    
    @objc(addKeyPoints:)
    @NSManaged public func addToKeyPoints(_ values: NSSet)
    
    @objc(removeKeyPoints:)
    @NSManaged public func removeFromKeyPoints(_ values: NSSet)
}

// MARK: - KeyPointEntity

@objc(KeyPointEntity)
public class KeyPointEntity: NSManagedObject {
    
    func toDomainModel() -> KeyPoint {
        let importance = KeyPoint.Importance(rawValue: self.importanceString ?? "") ?? .medium
        
        return KeyPoint(
            id: self.id ?? UUID(),
            title: self.title ?? "",
            description: self.descriptionText ?? "",
            importance: importance,
            timestamp: self.timestamp > 0 ? self.timestamp : nil
        )
    }
    
    static func fromDomainModel(_ keyPoint: KeyPoint, context: NSManagedObjectContext) -> KeyPointEntity {
        let entity = KeyPointEntity(context: context)
        entity.updateFromDomainModel(keyPoint)
        return entity
    }
    
    func updateFromDomainModel(_ keyPoint: KeyPoint) {
        self.id = keyPoint.id
        self.title = keyPoint.title
        self.descriptionText = keyPoint.description
        self.importanceString = keyPoint.importance.rawValue
        self.timestamp = keyPoint.timestamp ?? 0
    }
}

extension KeyPointEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<KeyPointEntity> {
        return NSFetchRequest<KeyPointEntity>(entityName: "KeyPointEntity")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var descriptionText: String?
    @NSManaged public var importanceString: String?
    @NSManaged public var timestamp: Double
    
    // Relationships
    @NSManaged public var summary: SummaryEntity?
}