import Foundation
import CoreData

@objc(RecordingEntity)
public class RecordingEntity: NSManagedObject {
    
    // Convert to domain model
    func toDomainModel() -> Recording {
        let speakers = (self.speakers?.allObjects as? [SpeakerEntity])?.map { $0.toDomainModel() } ?? []
        let summaries = (self.summaries?.allObjects as? [SummaryEntity])?.map { $0.toDomainModel() } ?? []
        let tags = (self.tags?.allObjects as? [TagEntity])?.map { $0.toDomainModel() } ?? []
        
        return Recording(
            id: self.id ?? UUID(),
            title: self.title ?? "",
            date: self.date ?? Date(),
            duration: self.duration,
            audioFileURL: URL(string: self.audioFileURLString ?? "") ?? URL(fileURLWithPath: ""),
            transcription: self.transcription,
            whisperModel: self.whisperModel ?? "base",
            language: self.language ?? "ja",
            isFromLimitless: self.isFromLimitless,
            speakers: speakers,
            summaries: summaries,
            tags: tags
        )
    }
    
    // Create from domain model
    static func fromDomainModel(_ recording: Recording, context: NSManagedObjectContext) -> RecordingEntity {
        let entity = RecordingEntity(context: context)
        entity.updateFromDomainModel(recording)
        return entity
    }
    
    // Update from domain model
    func updateFromDomainModel(_ recording: Recording) {
        self.id = recording.id
        self.title = recording.title
        self.date = recording.date
        self.duration = recording.duration
        self.audioFileURLString = recording.audioFileURL.absoluteString
        self.transcription = recording.transcription
        self.whisperModel = recording.whisperModel
        self.language = recording.language
        self.isFromLimitless = recording.isFromLimitless
        self.createdAt = recording.createdAt
        self.updatedAt = recording.updatedAt
        
        // Handle relationships separately
        // Note: Relationships should be handled in repository layer
    }
}

// MARK: - Core Data Properties

extension RecordingEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<RecordingEntity> {
        return NSFetchRequest<RecordingEntity>(entityName: "RecordingEntity")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var date: Date?
    @NSManaged public var duration: Double
    @NSManaged public var audioFileURLString: String?
    @NSManaged public var transcription: String?
    @NSManaged public var whisperModel: String?
    @NSManaged public var language: String?
    @NSManaged public var isFromLimitless: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    
    // Relationships
    @NSManaged public var speakers: NSSet?
    @NSManaged public var summaries: NSSet?
    @NSManaged public var tags: NSSet?
}

// MARK: - Generated accessors for speakers

extension RecordingEntity {
    
    @objc(addSpeakersObject:)
    @NSManaged public func addToSpeakers(_ value: SpeakerEntity)
    
    @objc(removeSpeakersObject:)
    @NSManaged public func removeFromSpeakers(_ value: SpeakerEntity)
    
    @objc(addSpeakers:)
    @NSManaged public func addToSpeakers(_ values: NSSet)
    
    @objc(removeSpeakers:)
    @NSManaged public func removeFromSpeakers(_ values: NSSet)
}

// MARK: - Generated accessors for summaries

extension RecordingEntity {
    
    @objc(addSummariesObject:)
    @NSManaged public func addToSummaries(_ value: SummaryEntity)
    
    @objc(removeSummariesObject:)
    @NSManaged public func removeFromSummaries(_ value: SummaryEntity)
    
    @objc(addSummaries:)
    @NSManaged public func addToSummaries(_ values: NSSet)
    
    @objc(removeSummaries:)
    @NSManaged public func removeFromSummaries(_ values: NSSet)
}

// MARK: - Generated accessors for tags

extension RecordingEntity {
    
    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: TagEntity)
    
    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: TagEntity)
    
    @objc(addTags:)
    @NSManaged public func addToTags(_ values: NSSet)
    
    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: NSSet)
}