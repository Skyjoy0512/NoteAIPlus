import Foundation
import CoreData
import Combine

protocol TranscriptionRepositoryProtocol {
    func save(_ transcription: TranscriptionResult) async throws
    func findByRecordingId(_ recordingId: UUID) async throws -> TranscriptionResult?
    func findById(_ id: UUID) async throws -> TranscriptionResult?
    func searchTranscriptions(query: String) async throws -> [TranscriptionResult]
    func fetchRecent(limit: Int) async throws -> [TranscriptionResult]
    func delete(_ transcription: TranscriptionResult) async throws
    func deleteByRecordingId(_ recordingId: UUID) async throws
    func getAllTranscriptions() async throws -> [TranscriptionResult]
    
    // Publishers for reactive UI
    var transcriptionsPublisher: AnyPublisher<[TranscriptionResult], Never> { get }
}

class TranscriptionRepository: TranscriptionRepositoryProtocol {
    
    private let coreDataManager: CoreDataManager
    private let transcriptionsSubject = CurrentValueSubject<[TranscriptionResult], Never>([])
    
    init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
        self.coreDataManager = coreDataManager
        
        // Initial load
        Task {
            await loadAllAndPublish()
        }
    }
    
    // MARK: - TranscriptionRepositoryProtocol
    
    var transcriptionsPublisher: AnyPublisher<[TranscriptionResult], Never> {
        transcriptionsSubject.eraseToAnyPublisher()
    }
    
    func save(_ transcription: TranscriptionResult) async throws {
        try await coreDataManager.performBackgroundTask { context in
            // Check if transcription already exists
            let existingRequest = TranscriptionEntity.fetchRequest()
            existingRequest.predicate = NSPredicate(format: "id == %@", transcription.id as CVarArg)
            existingRequest.fetchLimit = 1
            
            let existingEntity = try context.fetch(existingRequest).first
            
            if let existing = existingEntity {
                // Update existing entity
                self.updateEntity(existing, with: transcription, context: context)
            } else {
                // Create new entity
                let entity = TranscriptionEntity.fromDomainModel(transcription, context: context)
                
                // Link to recording if exists
                try self.linkToRecording(entity, recordingId: transcription.recordingId, context: context)
            }
            
            try context.save()
        }
        
        // Refresh published data
        await loadAllAndPublish()
    }
    
    func findByRecordingId(_ recordingId: UUID) async throws -> TranscriptionResult? {
        let request = TranscriptionEntity.fetchByRecordingId(recordingId)
        
        let entity = try await coreDataManager.fetchFirst(request)
        return entity?.toDomainModel()
    }
    
    func findById(_ id: UUID) async throws -> TranscriptionResult? {
        let request = TranscriptionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        let entity = try await coreDataManager.fetchFirst(request)
        return entity?.toDomainModel()
    }
    
    func searchTranscriptions(query: String) async throws -> [TranscriptionResult] {
        let request = TranscriptionEntity.searchByText(query)
        
        let entities = try await coreDataManager.fetch(request)
        return entities.map { $0.toDomainModel() }
    }
    
    func fetchRecent(limit: Int = 50) async throws -> [TranscriptionResult] {
        let request = TranscriptionEntity.fetchRecent(limit: limit)
        
        let entities = try await coreDataManager.fetch(request)
        return entities.map { $0.toDomainModel() }
    }
    
    func delete(_ transcription: TranscriptionResult) async throws {
        try await coreDataManager.performBackgroundTask { context in
            let request = TranscriptionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", transcription.id as CVarArg)
            
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            
            try context.save()
        }
        
        await loadAllAndPublish()
    }
    
    func deleteByRecordingId(_ recordingId: UUID) async throws {
        try await coreDataManager.performBackgroundTask { context in
            let request = TranscriptionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "recordingId == %@", recordingId as CVarArg)
            
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            
            try context.save()
        }
        
        await loadAllAndPublish()
    }
    
    func getAllTranscriptions() async throws -> [TranscriptionResult] {
        let request = TranscriptionEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TranscriptionEntity.createdAt, ascending: false)
        ]
        
        let entities = try await coreDataManager.fetch(request)
        return entities.map { $0.toDomainModel() }
    }
    
    // MARK: - Advanced Search Methods
    
    func searchByLanguage(_ language: String) async throws -> [TranscriptionResult] {
        let request = TranscriptionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "language == %@", language)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TranscriptionEntity.createdAt, ascending: false)
        ]
        
        let entities = try await coreDataManager.fetch(request)
        return entities.map { $0.toDomainModel() }
    }
    
    func searchByModelType(_ modelType: WhisperModelType) async throws -> [TranscriptionResult] {
        let request = TranscriptionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "modelType == %@", modelType.rawValue)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TranscriptionEntity.createdAt, ascending: false)
        ]
        
        let entities = try await coreDataManager.fetch(request)
        return entities.map { $0.toDomainModel() }
    }
    
    func searchByDateRange(from startDate: Date, to endDate: Date) async throws -> [TranscriptionResult] {
        let request = TranscriptionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "createdAt >= %@ AND createdAt <= %@", startDate as NSDate, endDate as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TranscriptionEntity.createdAt, ascending: false)
        ]
        
        let entities = try await coreDataManager.fetch(request)
        return entities.map { $0.toDomainModel() }
    }
    
    func searchByConfidenceThreshold(_ threshold: Float) async throws -> [TranscriptionResult] {
        let request = TranscriptionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "confidence >= %f", threshold)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TranscriptionEntity.confidence, ascending: false)
        ]
        
        let entities = try await coreDataManager.fetch(request)
        return entities.map { $0.toDomainModel() }
    }
    
    // MARK: - Statistics Methods
    
    func getTranscriptionCount() async throws -> Int {
        let request = TranscriptionEntity.fetchRequest()
        return try await coreDataManager.count(request)
    }
    
    func getTranscriptionCountByLanguage() async throws -> [String: Int] {
        let request = TranscriptionEntity.fetchRequest()
        let entities = try await coreDataManager.fetch(request)
        
        var counts: [String: Int] = [:]
        for entity in entities {
            counts[entity.language, default: 0] += 1
        }
        
        return counts
    }
    
    func getAverageConfidence() async throws -> Float {
        let request = TranscriptionEntity.fetchRequest()
        let entities = try await coreDataManager.fetch(request)
        
        guard !entities.isEmpty else { return 0.0 }
        
        let totalConfidence = entities.reduce(0.0) { $0 + $1.confidence }
        return totalConfidence / Float(entities.count)
    }
    
    func getTotalProcessingTime() async throws -> TimeInterval {
        let request = TranscriptionEntity.fetchRequest()
        let entities = try await coreDataManager.fetch(request)
        
        return entities.reduce(0.0) { $0 + $1.processingTime }
    }
    
    // MARK: - Private Methods
    
    private func updateEntity(_ entity: TranscriptionEntity, with transcription: TranscriptionResult, context: NSManagedObjectContext) {
        entity.text = transcription.text
        entity.language = transcription.language
        entity.confidence = transcription.confidence
        entity.modelType = transcription.modelType.rawValue
        entity.processingTime = transcription.processingTime
        
        // Update metadata
        entity.audioFormat = transcription.metadata.audioFormat
        entity.sampleRate = Int32(transcription.metadata.sampleRate)
        entity.channels = Int16(transcription.metadata.channels)
        entity.bitRate = Int32(transcription.metadata.bitRate ?? 0)
        
        // Update audio quality if available
        if let quality = transcription.metadata.audioQuality {
            entity.signalToNoiseRatio = quality.signalToNoiseRatio
            entity.dynamicRange = quality.dynamicRange
            entity.hasClipping = quality.hasClipping
            entity.averageLevel = quality.averageLevel
            entity.peakLevel = quality.peakLevel
            entity.spectralCentroid = quality.spectralCentroid ?? 0
        }
        
        // Update processing info
        let processingInfo = transcription.metadata.processingInfo
        entity.deviceModel = processingInfo.deviceModel
        entity.osVersion = processingInfo.osVersion
        entity.whisperKitVersion = processingInfo.whisperKitVersion
        entity.processingDate = processingInfo.processingDate
        entity.preprocessingApplied = encodeStringArray(processingInfo.preprocessingApplied)
        entity.postprocessingApplied = encodeStringArray(processingInfo.postprocessingApplied)
        
        // Update segments
        if let existingSegments = entity.segments {
            for segment in existingSegments {
                if let segmentEntity = segment as? TranscriptionSegmentEntity {
                    context.delete(segmentEntity)
                }
            }
        }
        
        let newSegments = Set(transcription.segments.map { segment in
            TranscriptionSegmentEntity.fromDomainModel(segment, context: context)
        })
        entity.segments = newSegments as NSSet
        
        // Update speakers if any
        if let speakers = transcription.speakers, !speakers.isEmpty {
            if let existingSpeakers = entity.speakers {
                for speaker in existingSpeakers {
                    if let speakerEntity = speaker as? SpeakerEntity {
                        context.delete(speakerEntity)
                    }
                }
            }
            
            let newSpeakers = Set(speakers.map { speaker in
                SpeakerEntity.fromDomainModel(speaker, context: context)
            })
            entity.speakers = newSpeakers as NSSet
        }
    }
    
    private func linkToRecording(_ entity: TranscriptionEntity, recordingId: UUID, context: NSManagedObjectContext) throws {
        let recordingRequest: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
        recordingRequest.predicate = NSPredicate(format: "id == %@", recordingId as CVarArg)
        
        if let recordingEntity = try context.fetch(recordingRequest).first {
            entity.recording = recordingEntity
        }
    }
    
    private func loadAllAndPublish() async {
        do {
            let transcriptions = try await getAllTranscriptions()
            await MainActor.run {
                self.transcriptionsSubject.send(transcriptions)
            }
        } catch {
            print("Failed to load transcriptions: \(error)")
            await MainActor.run {
                self.transcriptionsSubject.send([])
            }
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

// MARK: - Core Data Manager Extension

extension CoreDataManager {
    func fetchFirst<T: NSManagedObject>(_ request: NSFetchRequest<T>) async throws -> T? {
        request.fetchLimit = 1
        let results = try await fetch(request)
        return results.first
    }
    
    func count<T: NSManagedObject>(_ request: NSFetchRequest<T>) async throws -> Int {
        return try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                do {
                    let count = try context.count(for: request)
                    continuation.resume(returning: count)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}