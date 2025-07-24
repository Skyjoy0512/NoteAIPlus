import Foundation
import Combine

protocol RecordingRepositoryProtocol {
    // CRUD operations
    func save(_ recording: Recording) async throws
    func findById(_ id: UUID) async throws -> Recording?
    func findAll() async throws -> [Recording]
    func update(_ recording: Recording) async throws
    func delete(id: UUID) async throws
    
    // Query operations
    func findByDateRange(from: Date, to: Date) async throws -> [Recording]
    func findByTitle(containing text: String) async throws -> [Recording]
    func findWithTranscription() async throws -> [Recording]
    func findByTag(_ tag: Tag) async throws -> [Recording]
    func findByDuration(min: TimeInterval, max: TimeInterval) async throws -> [Recording]
    
    // Statistical operations
    func getTotalRecordingTime() async throws -> TimeInterval
    func getRecordingCount() async throws -> Int
    func getMostUsedTags(limit: Int) async throws -> [Tag]
    func getRecordingsByMonth() async throws -> [String: Int]
    
    // Search operations
    func searchTranscriptions(query: String) async throws -> [Recording]
    func findSimilarRecordings(to recording: Recording, limit: Int) async throws -> [Recording]
    
    // Reactive operations
    var recordingsPublisher: AnyPublisher<[Recording], Never> { get }
    var recordingCountPublisher: AnyPublisher<Int, Never> { get }
    
    // Batch operations
    func saveMultiple(_ recordings: [Recording]) async throws
    func deleteMultiple(ids: [UUID]) async throws
    func exportRecordings(ids: [UUID]) async throws -> URL
    
    // File management
    func cleanupOrphanedFiles() async throws
    func getStorageUsage() async throws -> Int64
}