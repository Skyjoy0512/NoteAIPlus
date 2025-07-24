import Foundation
import CoreData

@objc(SpeakerEntity)
public class SpeakerEntity: NSManagedObject {
    
    // MARK: - Core Data Properties
    
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var displayName: String?
    @NSManaged public var voiceEmbedding: Data? // Vector representation
    @NSManaged public var confidence: Float
    @NSManaged public var createdAt: Date
    @NSManaged public var lastSeenAt: Date
    
    // Voice characteristics
    @NSManaged public var estimatedAge: Int16 // 0 if unknown
    @NSManaged public var estimatedGender: String? // "male", "female", "unknown"
    @NSManaged public var voiceType: String? // "high", "medium", "low"
    
    // Relationships
    @NSManaged public var transcriptions: NSSet?
    @NSManaged public var segments: NSSet?
    
    // MARK: - Computed Properties
    
    var transcriptionsArray: [TranscriptionEntity] {
        let set = transcriptions as? Set<TranscriptionEntity> ?? []
        return set.sorted { $0.createdAt > $1.createdAt }
    }
    
    var segmentsArray: [TranscriptionSegmentEntity] {
        let set = segments as? Set<TranscriptionSegmentEntity> ?? []
        return set.sorted { $0.startTime < $1.startTime }
    }
    
    // MARK: - Domain Model Conversion
    
    func toDomainModel() -> Speaker {
        let voiceCharacteristics = VoiceCharacteristics(
            estimatedAge: estimatedAge > 0 ? Int(estimatedAge) : nil,
            estimatedGender: estimatedGender.flatMap { Gender(rawValue: $0) },
            voiceType: voiceType.flatMap { VoiceType(rawValue: $0) }
        )
        
        return Speaker(
            id: id,
            name: name,
            displayName: displayName,
            voiceEmbedding: decodeVoiceEmbedding(from: voiceEmbedding),
            confidence: confidence,
            voiceCharacteristics: voiceCharacteristics,
            createdAt: createdAt,
            lastSeenAt: lastSeenAt
        )
    }
    
    static func fromDomainModel(
        _ speaker: Speaker,
        context: NSManagedObjectContext
    ) -> SpeakerEntity {
        
        let entity = SpeakerEntity(context: context)
        
        entity.id = speaker.id
        entity.name = speaker.name
        entity.displayName = speaker.displayName
        entity.voiceEmbedding = encodeVoiceEmbedding(speaker.voiceEmbedding)
        entity.confidence = speaker.confidence
        entity.createdAt = speaker.createdAt
        entity.lastSeenAt = speaker.lastSeenAt
        
        // Voice characteristics
        if let characteristics = speaker.voiceCharacteristics {
            entity.estimatedAge = Int16(characteristics.estimatedAge ?? 0)
            entity.estimatedGender = characteristics.estimatedGender?.rawValue
            entity.voiceType = characteristics.voiceType?.rawValue
        }
        
        return entity
    }
    
    // MARK: - Helper Methods
    
    private func decodeVoiceEmbedding(from data: Data?) -> VoiceEmbedding? {
        guard let data = data else { return nil }
        
        do {
            let floatArray = try JSONDecoder().decode([Float].self, from: data)
            return VoiceEmbedding(values: floatArray)
        } catch {
            print("Failed to decode voice embedding: \(error)")
            return nil
        }
    }
    
    private static func encodeVoiceEmbedding(_ embedding: VoiceEmbedding?) -> Data? {
        guard let embedding = embedding else { return nil }
        
        do {
            return try JSONEncoder().encode(embedding.values)
        } catch {
            print("Failed to encode voice embedding: \(error)")
            return nil
        }
    }
}

// MARK: - Generated accessors for transcriptions

extension SpeakerEntity {
    
    @objc(addTranscriptionsObject:)
    @NSManaged public func addToTranscriptions(_ value: TranscriptionEntity)
    
    @objc(removeTranscriptionsObject:)
    @NSManaged public func removeFromTranscriptions(_ value: TranscriptionEntity)
    
    @objc(addTranscriptions:)
    @NSManaged public func addToTranscriptions(_ values: NSSet)
    
    @objc(removeTranscriptions:)
    @NSManaged public func removeFromTranscriptions(_ values: NSSet)
}

// MARK: - Generated accessors for segments

extension SpeakerEntity {
    
    @objc(addSegmentsObject:)
    @NSManaged public func addToSegments(_ value: TranscriptionSegmentEntity)
    
    @objc(removeSegmentsObject:)
    @NSManaged public func removeFromSegments(_ value: TranscriptionSegmentEntity)
    
    @objc(addSegments:)
    @NSManaged public func addToSegments(_ values: NSSet)
    
    @objc(removeSegments:)
    @NSManaged public func removeFromSegments(_ values: NSSet)
}

// MARK: - Fetch Request

extension SpeakerEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SpeakerEntity> {
        return NSFetchRequest<SpeakerEntity>(entityName: "SpeakerEntity")
    }
    
    static func fetchByName(_ name: String) -> NSFetchRequest<SpeakerEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name)
        return request
    }
    
    static func fetchRecent(limit: Int = 20) -> NSFetchRequest<SpeakerEntity> {
        let request = fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \SpeakerEntity.lastSeenAt, ascending: false)
        ]
        request.fetchLimit = limit
        return request
    }
}