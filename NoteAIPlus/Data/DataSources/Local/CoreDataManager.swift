import Foundation
import CoreData
import Combine

@MainActor
class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()
    
    @Published var isReady = false
    
    private init() {
        setupContainer()
    }
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DataModel")
        
        // Configure for background processing
        container.persistentStoreDescriptions.forEach { description in
            description.shouldInferMappingModelAutomatically = true
            description.shouldMigrateStoreAutomatically = true
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores { [weak self] _, error in
            if let error = error as NSError? {
                fatalError("Core Data failed to load: \(error), \(error.userInfo)")
            }
            
            DispatchQueue.main.async {
                self?.isReady = true
            }
        }
        
        // Configure contexts
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    private func setupContainer() {
        // Setup is done lazily in persistentContainer
    }
    
    // MARK: - Background Context
    
    func performBackgroundTask<T>(_ task: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                do {
                    let result = try task(context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    // MARK: - Save Operations
    
    func save() async throws {
        let context = viewContext
        
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            throw CoreDataError.saveFailed(error)
        }
    }
    
    func saveBackground(_ context: NSManagedObjectContext) async throws {
        guard context.hasChanges else { return }
        
        try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: CoreDataError.saveFailed(error))
                }
            }
        }
    }
    
    // MARK: - Fetch Operations
    
    func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) async throws -> [T] {
        return try await withCheckedThrowingContinuation { continuation in
            viewContext.perform {
                do {
                    let results = try self.viewContext.fetch(request)
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: CoreDataError.fetchFailed(error))
                }
            }
        }
    }
    
    func fetchFirst<T: NSManagedObject>(_ request: NSFetchRequest<T>) async throws -> T? {
        request.fetchLimit = 1
        let results = try await fetch(request)
        return results.first
    }
    
    func count<T: NSManagedObject>(_ request: NSFetchRequest<T>) async throws -> Int {
        return try await withCheckedThrowingContinuation { continuation in
            viewContext.perform {
                do {
                    let count = try self.viewContext.count(for: request)
                    continuation.resume(returning: count)
                } catch {
                    continuation.resume(throwing: CoreDataError.countFailed(error))
                }
            }
        }
    }
    
    // MARK: - Delete Operations
    
    func delete(_ object: NSManagedObject) async throws {
        viewContext.delete(object)
        try await save()
    }
    
    func batchDelete<T: NSManagedObject>(
        entity: T.Type,
        predicate: NSPredicate
    ) async throws {
        let request = NSBatchDeleteRequest(fetchRequest: T.fetchRequest())
        request.predicate = predicate
        request.resultType = .resultTypeObjectIDs
        
        let result = try await performBackgroundTask { context in
            try context.execute(request) as? NSBatchDeleteResult
        }
        
        guard let deleteResult = result,
              let objectIDs = deleteResult.result as? [NSManagedObjectID] else {
            return
        }
        
        let changes = [NSDeletedObjectsKey: objectIDs]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [viewContext])
    }
    
    // MARK: - Utility Methods
    
    func reset() async throws {
        let context = viewContext
        context.reset()
        
        // Delete all stores
        for store in persistentContainer.persistentStoreCoordinator.persistentStores {
            try persistentContainer.persistentStoreCoordinator.remove(store)
            if let url = store.url {
                try FileManager.default.removeItem(at: url)
            }
        }
        
        // Reload
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to reload Core Data: \(error)")
            }
        }
    }
    
    func export() async throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportURL = documentsPath.appendingPathComponent("backup_\(Date().timeIntervalSince1970).sqlite")
        
        for store in persistentContainer.persistentStoreCoordinator.persistentStores {
            if let storeURL = store.url {
                try FileManager.default.copyItem(at: storeURL, to: exportURL)
                break
            }
        }
        
        return exportURL
    }
}

// MARK: - Error Handling

enum CoreDataError: LocalizedError {
    case saveFailed(Error)
    case fetchFailed(Error)
    case countFailed(Error)
    case deleteFailed(Error)
    case migrationFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "データの保存に失敗しました: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "データの取得に失敗しました: \(error.localizedDescription)"
        case .countFailed(let error):
            return "データの数量取得に失敗しました: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "データの削除に失敗しました: \(error.localizedDescription)"
        case .migrationFailed(let error):
            return "データベースの移行に失敗しました: \(error.localizedDescription)"
        }
    }
}

// MARK: - Publisher Extensions

extension CoreDataManager {
    func publisher<T: NSManagedObject>(
        for fetchRequest: NSFetchRequest<T>
    ) -> AnyPublisher<[T], Never> {
        return NotificationCenter.default
            .publisher(for: .NSManagedObjectContextDidSave, object: viewContext)
            .compactMap { _ in
                try? self.viewContext.fetch(fetchRequest)
            }
            .prepend(try! viewContext.fetch(fetchRequest))
            .eraseToAnyPublisher()
    }
}