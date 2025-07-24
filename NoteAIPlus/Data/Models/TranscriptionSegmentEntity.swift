import Foundation
import CoreData

@objc(TranscriptionSegmentEntity)
public class TranscriptionSegmentEntity: NSManagedObject {
    
    // MARK: - Core Data Properties
    
    @NSManaged public var id: UUID
    @NSManaged public var startTime: TimeInterval
    @NSManaged public var endTime: TimeInterval
    @NSManaged public var text: String
    @NSManaged public var confidence: Float
    @NSManaged public var speakerId: UUID?
    
    // Relationships
    @NSManaged public var transcription: TranscriptionEntity?
    @NSManaged public var tokens: NSSet?
    @NSManaged public var speaker: SpeakerEntity?
    
    // MARK: - Computed Properties
    
    var tokensArray: [TranscriptionTokenEntity] {
        let set = tokens as? Set<TranscriptionTokenEntity> ?? []
        return set.sorted { $0.startTime < $1.startTime }
    }
    
    var duration: TimeInterval {
        endTime - startTime
    }
    
    var wordsPerMinute: Double {
        guard duration > 0 else { return 0 }
        let wordCount = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
        return Double(wordCount) / (duration / 60)
    }
    
    // MARK: - Domain Model Conversion
    
    func toDomainModel() -> TranscriptionSegment {
        let domainTokens = tokensArray.map { $0.toDomainModel() }
        
        return TranscriptionSegment(
            id: id,
            startTime: startTime,
            endTime: endTime,
            text: text,
            confidence: confidence,
            tokens: domainTokens,
            speakerId: speakerId
        )
    }
    
    static func fromDomainModel(
        _ segment: TranscriptionSegment,
        context: NSManagedObjectContext
    ) -> TranscriptionSegmentEntity {
        
        let entity = TranscriptionSegmentEntity(context: context)
        
        entity.id = segment.id
        entity.startTime = segment.startTime
        entity.endTime = segment.endTime
        entity.text = segment.text
        entity.confidence = segment.confidence
        entity.speakerId = segment.speakerId
        
        // Create token entities
        let tokenEntities = Set(segment.tokens.map { token in
            TranscriptionTokenEntity.fromDomainModel(token, context: context)
        })
        entity.tokens = tokenEntities as NSSet
        
        return entity
    }
}

// MARK: - Generated accessors for tokens

extension TranscriptionSegmentEntity {
    
    @objc(addTokensObject:)
    @NSManaged public func addToTokens(_ value: TranscriptionTokenEntity)
    
    @objc(removeTokensObject:)
    @NSManaged public func removeFromTokens(_ value: TranscriptionTokenEntity)
    
    @objc(addTokens:)
    @NSManaged public func addToTokens(_ values: NSSet)
    
    @objc(removeTokens:)
    @NSManaged public func removeFromTokens(_ values: NSSet)
}

// MARK: - Fetch Request

extension TranscriptionSegmentEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TranscriptionSegmentEntity> {
        return NSFetchRequest<TranscriptionSegmentEntity>(entityName: "TranscriptionSegmentEntity")
    }
    
    static func fetchByTranscription(_ transcriptionId: UUID) -> NSFetchRequest<TranscriptionSegmentEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "transcription.id == %@", transcriptionId as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TranscriptionSegmentEntity.startTime, ascending: true)
        ]
        return request
    }
    
    static func fetchBySpeaker(_ speakerId: UUID) -> NSFetchRequest<TranscriptionSegmentEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "speakerId == %@", speakerId as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TranscriptionSegmentEntity.startTime, ascending: true)
        ]
        return request
    }
}