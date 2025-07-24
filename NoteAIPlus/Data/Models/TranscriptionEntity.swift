import Foundation
import CoreData

@objc(TranscriptionEntity)
public class TranscriptionEntity: NSManagedObject {
    
    // MARK: - Core Data Properties
    
    @NSManaged public var id: UUID
    @NSManaged public var recordingId: UUID
    @NSManaged public var text: String
    @NSManaged public var language: String
    @NSManaged public var confidence: Float
    @NSManaged public var modelType: String
    @NSManaged public var processingTime: TimeInterval
    @NSManaged public var createdAt: Date
    
    // Metadata
    @NSManaged public var audioFormat: String
    @NSManaged public var sampleRate: Int32
    @NSManaged public var channels: Int16
    @NSManaged public var bitRate: Int32
    
    // Audio Quality Metrics (optional)
    @NSManaged public var signalToNoiseRatio: Float
    @NSManaged public var dynamicRange: Float
    @NSManaged public var hasClipping: Bool
    @NSManaged public var averageLevel: Float
    @NSManaged public var peakLevel: Float
    @NSManaged public var spectralCentroid: Float
    
    // Processing Info
    @NSManaged public var deviceModel: String
    @NSManaged public var osVersion: String
    @NSManaged public var whisperKitVersion: String
    @NSManaged public var processingDate: Date
    @NSManaged public var preprocessingApplied: Data? // JSON encoded [String]
    @NSManaged public var postprocessingApplied: Data? // JSON encoded [String]
    
    // Relationships
    @NSManaged public var recording: RecordingEntity?
    @NSManaged public var segments: NSSet?
    @NSManaged public var speakers: NSSet?
    
    // MARK: - Computed Properties
    
    var segmentsArray: [TranscriptionSegmentEntity] {
        let set = segments as? Set<TranscriptionSegmentEntity> ?? []
        return set.sorted { $0.startTime < $1.startTime }
    }
    
    var speakersArray: [SpeakerEntity] {
        let set = speakers as? Set<SpeakerEntity> ?? []
        return set.sorted { $0.name < $1.name }
    }
    
    // MARK: - Domain Model Conversion
    
    func toDomainModel() -> TranscriptionResult {
        let audioQuality = AudioQualityMetrics(
            signalToNoiseRatio: signalToNoiseRatio,
            dynamicRange: dynamicRange,
            hasClipping: hasClipping,
            averageLevel: averageLevel,
            peakLevel: peakLevel,
            spectralCentroid: spectralCentroid > 0 ? spectralCentroid : nil
        )
        
        let preprocessingAppliedList = decodeStringArray(from: preprocessingApplied) ?? []
        let postprocessingAppliedList = decodeStringArray(from: postprocessingApplied) ?? []
        
        let processingInfo = ProcessingInfo(
            deviceModel: deviceModel,
            osVersion: osVersion,
            whisperKitVersion: whisperKitVersion,
            preprocessingApplied: preprocessingAppliedList,
            postprocessingApplied: postprocessingAppliedList
        )
        
        let metadata = TranscriptionMetadata(
            audioFormat: audioFormat,
            sampleRate: Int(sampleRate),
            channels: Int(channels),
            bitRate: bitRate > 0 ? Int(bitRate) : nil,
            audioQuality: audioQuality,
            processingInfo: processingInfo
        )
        
        let domainSegments = segmentsArray.map { $0.toDomainModel() }
        let domainSpeakers = speakersArray.isEmpty ? nil : speakersArray.map { $0.toDomainModel() }
        
        return TranscriptionResult(
            id: id,
            recordingId: recordingId,
            text: text,
            language: language,
            confidence: confidence,
            modelType: WhisperModelType(rawValue: modelType) ?? .base,
            processingTime: processingTime,
            segments: domainSegments,
            speakers: domainSpeakers,
            metadata: metadata
        )
    }
    
    static func fromDomainModel(
        _ transcription: TranscriptionResult,
        context: NSManagedObjectContext
    ) -> TranscriptionEntity {
        
        let entity = TranscriptionEntity(context: context)
        
        entity.id = transcription.id
        entity.recordingId = transcription.recordingId
        entity.text = transcription.text
        entity.language = transcription.language
        entity.confidence = transcription.confidence
        entity.modelType = transcription.modelType.rawValue
        entity.processingTime = transcription.processingTime
        entity.createdAt = transcription.createdAt
        
        // Metadata
        entity.audioFormat = transcription.metadata.audioFormat
        entity.sampleRate = Int32(transcription.metadata.sampleRate)
        entity.channels = Int16(transcription.metadata.channels)
        entity.bitRate = Int32(transcription.metadata.bitRate ?? 0)
        
        // Audio Quality
        if let quality = transcription.metadata.audioQuality {
            entity.signalToNoiseRatio = quality.signalToNoiseRatio
            entity.dynamicRange = quality.dynamicRange
            entity.hasClipping = quality.hasClipping
            entity.averageLevel = quality.averageLevel
            entity.peakLevel = quality.peakLevel
            entity.spectralCentroid = quality.spectralCentroid ?? 0
        }
        
        // Processing Info
        let processingInfo = transcription.metadata.processingInfo
        entity.deviceModel = processingInfo.deviceModel
        entity.osVersion = processingInfo.osVersion
        entity.whisperKitVersion = processingInfo.whisperKitVersion
        entity.processingDate = processingInfo.processingDate
        entity.preprocessingApplied = encodeStringArray(processingInfo.preprocessingApplied)
        entity.postprocessingApplied = encodeStringArray(processingInfo.postprocessingApplied)
        
        // Create segment entities
        let segmentEntities = Set(transcription.segments.map { segment in
            TranscriptionSegmentEntity.fromDomainModel(segment, context: context)
        })
        entity.segments = segmentEntities as NSSet
        
        // Create speaker entities (if any)
        if let speakers = transcription.speakers, !speakers.isEmpty {
            let speakerEntities = Set(speakers.map { speaker in
                SpeakerEntity.fromDomainModel(speaker, context: context)
            })
            entity.speakers = speakerEntities as NSSet
        }
        
        return entity
    }
    
    // MARK: - Helper Methods
    
    private func decodeStringArray(from data: Data?) -> [String]? {
        guard let data = data else { return nil }
        
        do {
            return try JSONDecoder().decode([String].self, from: data)
        } catch {
            print("Failed to decode string array: \(error)")
            return nil
        }
    }
    
    private func encodeStringArray(_ array: [String]) -> Data? {
        do {
            return try JSONEncoder().encode(array)
        } catch {
            print("Failed to encode string array: \(error)")
            return nil
        }
    }
}

// MARK: - Generated accessors for segments

extension TranscriptionEntity {
    
    @objc(addSegmentsObject:)
    @NSManaged public func addToSegments(_ value: TranscriptionSegmentEntity)
    
    @objc(removeSegmentsObject:)
    @NSManaged public func removeFromSegments(_ value: TranscriptionSegmentEntity)
    
    @objc(addSegments:)
    @NSManaged public func addToSegments(_ values: NSSet)
    
    @objc(removeSegments:)
    @NSManaged public func removeFromSegments(_ values: NSSet)
}

// MARK: - Generated accessors for speakers

extension TranscriptionEntity {
    
    @objc(addSpeakersObject:)
    @NSManaged public func addToSpeakers(_ value: SpeakerEntity)
    
    @objc(removeSpeakersObject:)
    @NSManaged public func removeFromSpeakers(_ value: SpeakerEntity)
    
    @objc(addSpeakers:)
    @NSManaged public func addToSpeakers(_ values: NSSet)
    
    @objc(removeSpeakers:)
    @NSManaged public func removeFromSpeakers(_ values: NSSet)
}

// MARK: - Fetch Request

extension TranscriptionEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TranscriptionEntity> {
        return NSFetchRequest<TranscriptionEntity>(entityName: "TranscriptionEntity")
    }
    
    static func fetchByRecordingId(_ recordingId: UUID) -> NSFetchRequest<TranscriptionEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "recordingId == %@", recordingId as CVarArg)
        request.fetchLimit = 1
        return request
    }
    
    static func searchByText(_ query: String) -> NSFetchRequest<TranscriptionEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "text CONTAINS[cd] %@", query)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TranscriptionEntity.createdAt, ascending: false)
        ]
        return request
    }
    
    static func fetchRecent(limit: Int = 50) -> NSFetchRequest<TranscriptionEntity> {
        let request = fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TranscriptionEntity.createdAt, ascending: false)
        ]
        request.fetchLimit = limit
        return request
    }
}