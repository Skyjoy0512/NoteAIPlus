import Foundation
import CoreData

@objc(TranscriptionTokenEntity)
public class TranscriptionTokenEntity: NSManagedObject {
    
    // MARK: - Core Data Properties
    
    @NSManaged public var id: UUID
    @NSManaged public var text: String
    @NSManaged public var startTime: TimeInterval
    @NSManaged public var endTime: TimeInterval
    @NSManaged public var confidence: Float
    @NSManaged public var logProbability: Float
    
    // Relationships
    @NSManaged public var segment: TranscriptionSegmentEntity?
    
    // MARK: - Domain Model Conversion
    
    func toDomainModel() -> TranscriptionToken {
        return TranscriptionToken(
            id: id,
            text: text,
            startTime: startTime,
            endTime: endTime,
            confidence: confidence,
            logProbability: logProbability
        )
    }
    
    static func fromDomainModel(
        _ token: TranscriptionToken,
        context: NSManagedObjectContext
    ) -> TranscriptionTokenEntity {
        
        let entity = TranscriptionTokenEntity(context: context)
        
        entity.id = token.id
        entity.text = token.text
        entity.startTime = token.startTime
        entity.endTime = token.endTime
        entity.confidence = token.confidence
        entity.logProbability = token.logProbability
        
        return entity
    }
}

// MARK: - Fetch Request

extension TranscriptionTokenEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TranscriptionTokenEntity> {
        return NSFetchRequest<TranscriptionTokenEntity>(entityName: "TranscriptionTokenEntity")
    }
    
    static func fetchBySegment(_ segmentId: UUID) -> NSFetchRequest<TranscriptionTokenEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "segment.id == %@", segmentId as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TranscriptionTokenEntity.startTime, ascending: true)
        ]
        return request
    }
}