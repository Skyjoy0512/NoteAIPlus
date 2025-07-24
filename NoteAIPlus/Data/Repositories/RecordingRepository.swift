import Foundation
import CoreData
import Combine

class RecordingRepository: RecordingRepositoryProtocol {
    // MARK: - Properties
    
    private let coreDataManager: CoreDataManager
    private let recordingsSubject = CurrentValueSubject<[Recording], Never>([])
    private let recordingCountSubject = CurrentValueSubject<Int, Never>(0)
    
    // MARK: - Initialization
    
    init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
        self.coreDataManager = coreDataManager
        setupPublishers()
    }
    
    // MARK: - RecordingRepositoryProtocol
    
    var recordingsPublisher: AnyPublisher<[Recording], Never> {
        recordingsSubject.eraseToAnyPublisher()
    }
    
    var recordingCountPublisher: AnyPublisher<Int, Never> {
        recordingCountSubject.eraseToAnyPublisher()
    }
    
    // MARK: - CRUD Operations
    
    func save(_ recording: Recording) async throws {
        try await coreDataManager.performBackgroundTask { context in
            let entity = RecordingEntity.fromDomainModel(recording, context: context)
            try context.save()
        }
        
        await refreshPublishers()
    }
    
    func findById(_ id: UUID) async throws -> Recording? {
        let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        let entity = try await coreDataManager.fetchFirst(request)
        return entity?.toDomainModel()
    }
    
    func findAll() async throws -> [Recording] {
        let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \RecordingEntity.date, ascending: false)
        ]
        
        let entities = try await coreDataManager.fetch(request)
        return entities.map { $0.toDomainModel() }
    }
    
    func update(_ recording: Recording) async throws {
        try await coreDataManager.performBackgroundTask { context in
            let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", recording.id as CVarArg)
            request.fetchLimit = 1
            
            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.recordNotFound
            }
            
            entity.updateFromDomainModel(recording)
            try context.save()
        }
        
        await refreshPublishers()
    }
    
    func delete(id: UUID) async throws {
        try await coreDataManager.performBackgroundTask { context in
            let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            let entities = try context.fetch(request)
            for entity in entities {
                // Delete associated audio file
                if let urlString = entity.audioFileURLString,
                   let fileURL = URL(string: urlString) {
                    try? FileManager.default.removeItem(at: fileURL)
                }
                
                context.delete(entity)
            }
            
            try context.save()
        }
        
        await refreshPublishers()
    }
    
    // MARK: - Query Operations
    
    func findByDateRange(from: Date, to: Date) async throws -> [Recording] {
        let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", from as CVarArg, to as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \RecordingEntity.date, ascending: false)
        ]
        
        let entities = try await coreDataManager.fetch(request)
        return entities.map { $0.toDomainModel() }
    }
    
    func findByTitle(containing text: String) async throws -> [Recording] {
        let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
        request.predicate = NSPredicate(format: "title CONTAINS[cd] %@", text)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \RecordingEntity.date, ascending: false)
        ]
        
        let entities = try await coreDataManager.fetch(request)
        return entities.map { $0.toDomainModel() }
    }
    
    func findWithTranscription() async throws -> [Recording] {
        let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
        request.predicate = NSPredicate(format: "transcription != nil AND transcription != ''")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \RecordingEntity.date, ascending: false)
        ]
        
        let entities = try await coreDataManager.fetch(request)
        return entities.map { $0.toDomainModel() }
    }
    
    func findByTag(_ tag: Tag) async throws -> [Recording] {
        let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
        request.predicate = NSPredicate(format: "ANY tags.id == %@", tag.id as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \RecordingEntity.date, ascending: false)
        ]
        
        let entities = try await coreDataManager.fetch(request)
        return entities.map { $0.toDomainModel() }
    }
    
    func findByDuration(min: TimeInterval, max: TimeInterval) async throws -> [Recording] {
        let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
        request.predicate = NSPredicate(format: "duration >= %f AND duration <= %f", min, max)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \RecordingEntity.date, ascending: false)
        ]
        
        let entities = try await coreDataManager.fetch(request)
        return entities.map { $0.toDomainModel() }
    }
    
    // MARK: - Statistical Operations
    
    func getTotalRecordingTime() async throws -> TimeInterval {
        let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
        let entities = try await coreDataManager.fetch(request)
        return entities.reduce(0) { $0 + $1.duration }
    }
    
    func getRecordingCount() async throws -> Int {
        let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
        return try await coreDataManager.count(request)
    }
    
    func getMostUsedTags(limit: Int) async throws -> [Tag] {
        let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TagEntity.usageCount, ascending: false)
        ]
        request.fetchLimit = limit
        
        let entities = try await coreDataManager.fetch(request)
        return entities.map { $0.toDomainModel() }
    }
    
    func getRecordingsByMonth() async throws -> [String: Int] {
        let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
        let entities = try await coreDataManager.fetch(request)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        
        var result: [String: Int] = [:]
        for entity in entities {
            guard let date = entity.date else { continue }
            let monthKey = formatter.string(from: date)
            result[monthKey, default: 0] += 1
        }
        
        return result
    }
    
    // MARK: - Search Operations
    
    func searchTranscriptions(query: String) async throws -> [Recording] {
        let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
        request.predicate = NSPredicate(format: "transcription CONTAINS[cd] %@", query)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \RecordingEntity.date, ascending: false)
        ]
        
        let entities = try await coreDataManager.fetch(request)
        return entities.map { $0.toDomainModel() }
    }
    
    func findSimilarRecordings(to recording: Recording, limit: Int) async throws -> [Recording] {
        // This is a simplified implementation
        // In a real app, you would use vector similarity or content-based matching
        let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id != %@", recording.id as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \RecordingEntity.date, ascending: false)
        ]
        request.fetchLimit = limit
        
        let entities = try await coreDataManager.fetch(request)
        return entities.map { $0.toDomainModel() }
    }
    
    // MARK: - Batch Operations
    
    func saveMultiple(_ recordings: [Recording]) async throws {
        try await coreDataManager.performBackgroundTask { context in
            for recording in recordings {
                _ = RecordingEntity.fromDomainModel(recording, context: context)
            }
            try context.save()
        }
        
        await refreshPublishers()
    }
    
    func deleteMultiple(ids: [UUID]) async throws {
        try await coreDataManager.performBackgroundTask { context in
            for id in ids {
                let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                
                let entities = try context.fetch(request)
                for entity in entities {
                    // Delete associated audio file
                    if let urlString = entity.audioFileURLString,
                       let fileURL = URL(string: urlString) {
                        try? FileManager.default.removeItem(at: fileURL)
                    }
                    
                    context.delete(entity)
                }
            }
            
            try context.save()
        }
        
        await refreshPublishers()
    }
    
    func exportRecordings(ids: [UUID]) async throws -> URL {
        let recordings = try await findRecordings(by: ids)
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exportDir = documentsPath.appendingPathComponent("Export_\(Date().timeIntervalSince1970)")
        
        try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
        
        // Export audio files
        for recording in recordings {
            let sourceURL = recording.audioFileURL
            let fileName = "\(recording.title).\(sourceURL.pathExtension)"
            let destinationURL = exportDir.appendingPathComponent(fileName)
            
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        }
        
        // Create metadata file
        let metadata = recordings.map { recording in
            [
                "title": recording.title,
                "date": ISO8601DateFormatter().string(from: recording.date),
                "duration": recording.duration,
                "transcription": recording.transcription ?? ""
            ]
        }
        
        let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
        let metadataURL = exportDir.appendingPathComponent("metadata.json")
        try metadataData.write(to: metadataURL)
        
        return exportDir
    }
    
    // MARK: - File Management
    
    func cleanupOrphanedFiles() async throws {
        let recordingsDir = getRecordingsDirectory()
        
        // Get all recording file URLs from database
        let recordings = try await findAll()
        let databaseFileURLs = Set(recordings.map { $0.audioFileURL })
        
        // Get all files in recordings directory
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: recordingsDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: .skipsHiddenFiles
        )
        
        // Delete orphaned files
        for fileURL in fileURLs {
            if !databaseFileURLs.contains(fileURL) {
                try FileManager.default.removeItem(at: fileURL)
            }
        }
    }
    
    func getStorageUsage() async throws -> Int64 {
        let recordings = try await findAll()
        var totalSize: Int64 = 0
        
        for recording in recordings {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: recording.audioFileURL.path)
                if let fileSize = attributes[.size] as? Int64 {
                    totalSize += fileSize
                }
            } catch {
                // File might not exist, skip
                continue
            }
        }
        
        return totalSize
    }
    
    // MARK: - Private Methods
    
    private func setupPublishers() {
        Task {
            await refreshPublishers()
        }
        
        // Listen for Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in
                Task {
                    await self?.refreshPublishers()
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    @MainActor
    private func refreshPublishers() async {
        do {
            let recordings = try await findAll()
            recordingsSubject.send(recordings)
            recordingCountSubject.send(recordings.count)
        } catch {
            print("Failed to refresh publishers: \(error)")
        }
    }
    
    private func findRecordings(by ids: [UUID]) async throws -> [Recording] {
        let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", ids)
        
        let entities = try await coreDataManager.fetch(request)
        return entities.map { $0.toDomainModel() }
    }
    
    private func getRecordingsDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("Recordings")
    }
}

// MARK: - Error Types

enum RepositoryError: LocalizedError {
    case recordNotFound
    case invalidData
    case saveFailed(Error)
    case fetchFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .recordNotFound:
            return "レコードが見つかりません。"
        case .invalidData:
            return "無効なデータです。"
        case .saveFailed(let error):
            return "保存に失敗しました: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "データの取得に失敗しました: \(error.localizedDescription)"
        }
    }
}