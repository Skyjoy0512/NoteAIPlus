import Foundation
import Combine

class ModelManager: ObservableObject, ModelManagerProtocol {
    // MARK: - Properties
    
    @Published var availableModels: [WhisperModelType] = []
    @Published var downloadedModels: Set<WhisperModelType> = []
    @Published var currentDownloads: [WhisperModelType: DownloadProgress] = [:]
    
    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    private let urlSession = URLSession.shared
    
    // MARK: - Initialization
    
    init() {
        self.cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WhisperModels")
        
        setupCacheDirectory()
        loadAvailableModels()
        Task {
            await scanDownloadedModels()
        }
    }
    
    // MARK: - ModelManagerProtocol
    
    func ensureModelAvailable(_ modelType: WhisperModelType) async throws {
        if !downloadedModels.contains(modelType) {
            try await downloadModel(modelType)
        }
        
        // Verify model integrity
        let modelPath = try await getModelPath(modelType)
        guard fileManager.fileExists(atPath: modelPath.path) else {
            throw TranscriptionError.modelCorrupted(modelType)
        }
    }
    
    func getModelPath(_ modelType: WhisperModelType) async throws -> URL {
        let modelURL = cacheDirectory.appendingPathComponent("\(modelType.rawValue)")
        
        guard fileManager.fileExists(atPath: modelURL.path) else {
            throw TranscriptionError.modelNotLoaded
        }
        
        return modelURL
    }
    
    func downloadModel(_ modelType: WhisperModelType) async throws {
        guard !downloadedModels.contains(modelType) else { return }
        
        // Check if already downloading
        if currentDownloads[modelType] != nil {
            throw ModelManagerError.downloadInProgress
        }
        
        // Check available storage
        let availableSpace = try await getAvailableSpace()
        guard availableSpace >= modelType.fileSize else {
            throw TranscriptionError.insufficientStorage(
                required: modelType.fileSize,
                available: availableSpace
            )
        }
        
        let downloadURL = try getModelDownloadURL(modelType)
        let destinationURL = cacheDirectory.appendingPathComponent("\(modelType.rawValue)")
        
        // Initialize download progress
        await MainActor.run {
            currentDownloads[modelType] = DownloadProgress(
                fractionCompleted: 0.0,
                totalBytes: modelType.fileSize,
                downloadedBytes: 0
            )
        }
        
        do {
            try await downloadWithProgress(from: downloadURL, to: destinationURL, modelType: modelType)
            try await verifyModel(at: destinationURL, modelType: modelType)
            
            await MainActor.run {
                downloadedModels.insert(modelType)
                currentDownloads.removeValue(forKey: modelType)
            }
            
        } catch {
            await MainActor.run {
                currentDownloads.removeValue(forKey: modelType)
            }
            
            // Clean up partial download
            if fileManager.fileExists(atPath: destinationURL.path) {
                try? fileManager.removeItem(at: destinationURL)
            }
            
            throw error
        }
    }
    
    func deleteModel(_ modelType: WhisperModelType) async throws {
        let modelURL = cacheDirectory.appendingPathComponent("\(modelType.rawValue)")
        
        if fileManager.fileExists(atPath: modelURL.path) {
            try fileManager.removeItem(at: modelURL)
        }
        
        await MainActor.run {
            downloadedModels.remove(modelType)
        }
    }
    
    func getStorageUsage() async -> Int64 {
        var totalSize: Int64 = 0
        
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            } catch {
                continue
            }
        }
        
        return totalSize
    }
    
    // MARK: - Private Methods
    
    private func setupCacheDirectory() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func loadAvailableModels() {
        availableModels = WhisperModelType.allCases
    }
    
    private func scanDownloadedModels() async {
        let modelURLs = availableModels.map { modelType in
            cacheDirectory.appendingPathComponent("\(modelType.rawValue)")
        }
        
        var downloaded: Set<WhisperModelType> = []
        
        for (index, modelURL) in modelURLs.enumerated() {
            if fileManager.fileExists(atPath: modelURL.path) {
                downloaded.insert(availableModels[index])
            }
        }
        
        await MainActor.run {
            self.downloadedModels = downloaded
        }
    }
    
    private func getModelDownloadURL(_ modelType: WhisperModelType) throws -> URL {
        // WhisperKit models are typically hosted on Hugging Face
        let baseURL = "https://huggingface.co/argmaxinc/whisperkit-coreml/resolve/main"
        let modelPath = "\(modelType.rawValue)_\(modelType.rawValue).zip"
        
        guard let url = URL(string: "\(baseURL)/\(modelPath)") else {
            throw ModelManagerError.invalidModelURL
        }
        
        return url
    }
    
    private func downloadWithProgress(from url: URL, to destination: URL, modelType: WhisperModelType) async throws {
        let (localURL, _) = try await urlSession.download(from: url) { [weak self] totalBytesWritten, totalBytesExpectedToWrite in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                let progress = DownloadProgress(
                    fractionCompleted: Double(totalBytesWritten) / Double(totalBytesExpectedToWrite),
                    totalBytes: totalBytesExpectedToWrite,
                    downloadedBytes: totalBytesWritten
                )
                
                self.currentDownloads[modelType] = progress
            }
        }
        
        // Move downloaded file to final destination
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        
        try fileManager.moveItem(at: localURL, to: destination)
        
        // If it's a zip file, extract it
        if destination.pathExtension == "zip" {
            try await extractModel(at: destination)
        }
    }
    
    private func extractModel(at zipURL: URL) async throws {
        // Extract zip file using Foundation's NSFileManager
        // This is a simplified implementation
        let extractionURL = zipURL.deletingPathExtension()
        
        try fileManager.createDirectory(at: extractionURL, withIntermediateDirectories: true)
        
        // In a real implementation, you would use a proper zip extraction library
        // For now, we'll assume the file is already in the correct format
    }
    
    private func verifyModel(at url: URL, modelType: WhisperModelType) async throws {
        // Verify file exists and has reasonable size
        guard fileManager.fileExists(atPath: url.path) else {
            throw TranscriptionError.modelCorrupted(modelType)
        }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            // Check if file size is reasonable (at least 50% of expected size)
            let minExpectedSize = Int64(Double(modelType.fileSize) * 0.5)
            guard fileSize >= minExpectedSize else {
                throw TranscriptionError.modelCorrupted(modelType)
            }
            
        } catch {
            throw TranscriptionError.modelCorrupted(modelType)
        }
    }
    
    private func getAvailableSpace() async throws -> Int64 {
        let resourceValues = try cacheDirectory.resourceValues(forKeys: [.volumeAvailableCapacityKey])
        return Int64(resourceValues.volumeAvailableCapacity ?? 0)
    }
}

// MARK: - Supporting Types

struct DownloadProgress {
    let fractionCompleted: Double
    let totalBytes: Int64
    let downloadedBytes: Int64
    
    var percentageCompleted: Int {
        Int(fractionCompleted * 100)
    }
    
    var remainingBytes: Int64 {
        totalBytes - downloadedBytes
    }
    
    var formattedProgress: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        
        let downloaded = formatter.string(fromByteCount: downloadedBytes)
        let total = formatter.string(fromByteCount: totalBytes)
        
        return "\(downloaded) / \(total) (\(percentageCompleted)%)"
    }
}

enum ModelManagerError: LocalizedError {
    case downloadInProgress
    case invalidModelURL
    case extractionFailed
    case checksumMismatch
    
    var errorDescription: String? {
        switch self {
        case .downloadInProgress:
            return "モデルのダウンロードが既に進行中です。"
        case .invalidModelURL:
            return "モデルのダウンロードURLが無効です。"
        case .extractionFailed:
            return "モデルファイルの展開に失敗しました。"
        case .checksumMismatch:
            return "ダウンロードされたモデルファイルが破損しています。"
        }
    }
}

// MARK: - URLSession Extension

extension URLSession {
    func download(from url: URL, progressHandler: @escaping (Int64, Int64) -> Void) async throws -> (URL, URLResponse) {
        return try await withCheckedThrowingContinuation { continuation in
            let task = downloadTask(with: url) { localURL, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let localURL = localURL, let response = response {
                    continuation.resume(returning: (localURL, response))
                } else {
                    continuation.resume(throwing: URLError(.unknown))
                }
            }
            
            // Set up progress observation
            let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
                let totalBytes = progress.totalUnitCount
                let completedBytes = progress.completedUnitCount
                progressHandler(completedBytes, totalBytes)
            }
            
            task.resume()
            
            // Keep observation alive
            withExtendedLifetime(observation) {
                // Progress observation will be cleaned up automatically
            }
        }
    }
}