import Foundation
import Combine

protocol DocumentRepositoryProtocol {
    // CRUD operations
    func save(_ document: Document) async throws
    func findById(_ id: UUID) async throws -> Document?
    func findAll() async throws -> [Document]
    func update(_ document: Document) async throws
    func delete(id: UUID) async throws
    
    // Query operations
    func findByType(_ type: Document.DocumentType) async throws -> [Document]
    func findByTitle(containing text: String) async throws -> [Document]
    func findByTag(_ tag: Tag) async throws -> [Document]
    func findByDateRange(from: Date, to: Date) async throws -> [Document]
    func findByFileSize(min: Int64, max: Int64) async throws -> [Document]
    
    // Content operations
    func searchContent(query: String) async throws -> [Document]
    func findDuplicates() async throws -> [[Document]]
    func findByChecksum(_ checksum: String) async throws -> Document?
    
    // Statistical operations
    func getTotalStorageUsage() async throws -> Int64
    func getDocumentCount() async throws -> Int
    func getDocumentsByType() async throws -> [Document.DocumentType: Int]
    
    // Import/Export operations
    func importFromURL(_ url: URL) async throws -> Document
    func exportDocument(id: UUID, to url: URL) async throws
    func batchImport(from urls: [URL]) async throws -> [Document]
    
    // Reactive operations
    var documentsPublisher: AnyPublisher<[Document], Never> { get }
    var documentCountPublisher: AnyPublisher<Int, Never> { get }
    
    // RAG operations
    func getDocumentsForRAG(query: String, limit: Int) async throws -> [Document]
    func updateDocumentEmbeddings(id: UUID, embeddings: [VectorEmbedding]) async throws
    func findRelatedDocuments(to document: Document, limit: Int) async throws -> [Document]
    
    // Cleanup operations
    func cleanupOrphanedFiles() async throws
    func optimizeStorage() async throws
}