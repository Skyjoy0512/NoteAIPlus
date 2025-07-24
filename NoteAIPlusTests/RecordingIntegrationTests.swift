import XCTest
import Combine
@testable import NoteAIPlus

class RecordingIntegrationTests: XCTestCase {
    var recordingUseCase: RecordingUseCase!
    var mockAudioService: MockAudioRecordingService!
    var mockRepository: MockRecordingRepository!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockAudioService = MockAudioRecordingService()
        mockRepository = MockRecordingRepository()
        recordingUseCase = RecordingUseCase(
            recordingRepository: mockRepository,
            audioService: mockAudioService,
            transcriptionService: DummyTranscriptionService()
        )
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        recordingUseCase = nil
        mockRepository = nil
        mockAudioService = nil
        super.tearDown()
    }
    
    // MARK: - Basic Recording Flow Tests
    
    func testCompleteRecordingFlow() async throws {
        // Given
        let expectedURL = URL(string: "file://test-recording.m4a")!
        mockAudioService.startRecordingResult = expectedURL
        mockAudioService.stopRecordingResult = RecordingResult(
            audioURL: expectedURL,
            duration: 10.0,
            fileSize: 1024
        )
        
        // When - Start recording
        let session = try await recordingUseCase.startRecording(title: "Test Recording")
        
        // Then - Verify recording started
        XCTAssertNotNil(session)
        XCTAssertEqual(session.title, "Test Recording")
        XCTAssertTrue(mockAudioService.startRecordingCalled)
        XCTAssertTrue(recordingUseCase.isRecording)
        
        // When - Stop recording
        let recording = try await recordingUseCase.stopRecording()
        
        // Then - Verify recording stopped and saved
        XCTAssertNotNil(recording)
        XCTAssertEqual(recording.title, "Test Recording")
        XCTAssertEqual(recording.audioFileURL, expectedURL)
        XCTAssertTrue(mockAudioService.stopRecordingCalled)
        XCTAssertTrue(mockRepository.saveCalled)
        XCTAssertFalse(recordingUseCase.isRecording)
    }
    
    func testRecordingWithPauseAndResume() async throws {
        // Given
        let expectedURL = URL(string: "file://test-recording.m4a")!
        mockAudioService.startRecordingResult = expectedURL
        
        // When - Start recording
        _ = try await recordingUseCase.startRecording()
        
        // When - Pause recording
        try await recordingUseCase.pauseRecording()
        
        // Then - Verify paused
        XCTAssertTrue(mockAudioService.pauseRecordingCalled)
        XCTAssertTrue(recordingUseCase.currentRecordingSession?.isPaused ?? false)
        
        // When - Resume recording
        try await recordingUseCase.resumeRecording()
        
        // Then - Verify resumed
        XCTAssertTrue(mockAudioService.resumeRecordingCalled)
        XCTAssertFalse(recordingUseCase.currentRecordingSession?.isPaused ?? true)
    }
    
    func testCancelRecording() async throws {
        // Given
        let expectedURL = URL(string: "file://test-recording.m4a")!
        mockAudioService.startRecordingResult = expectedURL
        
        // When - Start recording
        _ = try await recordingUseCase.startRecording()
        XCTAssertTrue(recordingUseCase.isRecording)
        
        // When - Cancel recording
        try await recordingUseCase.cancelRecording()
        
        // Then - Verify cancelled
        XCTAssertTrue(mockAudioService.stopRecordingCalled)
        XCTAssertFalse(recordingUseCase.isRecording)
        XCTAssertNil(recordingUseCase.currentRecordingSession)
        XCTAssertFalse(mockRepository.saveCalled) // Should not save when cancelled
    }
    
    // MARK: - Error Handling Tests
    
    func testRecordingErrorHandling() async throws {
        // Given
        mockAudioService.shouldThrowError = true
        mockAudioService.errorToThrow = RecordingError.permissionDenied
        
        // When & Then
        do {
            _ = try await recordingUseCase.startRecording()
            XCTFail("Expected error to be thrown")
        } catch let error as RecordingError {
            XCTAssertEqual(error, RecordingError.permissionDenied)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        // Verify state is reset
        XCTAssertFalse(recordingUseCase.isRecording)
        XCTAssertNil(recordingUseCase.currentRecordingSession)
    }
    
    func testDuplicateRecordingStart() async throws {
        // Given
        let expectedURL = URL(string: "file://test-recording.m4a")!
        mockAudioService.startRecordingResult = expectedURL
        
        // When - Start first recording
        _ = try await recordingUseCase.startRecording()
        
        // When & Then - Try to start another recording
        do {
            _ = try await recordingUseCase.startRecording()
            XCTFail("Expected error to be thrown")
        } catch let error as RecordingError {
            XCTAssertEqual(error, RecordingError.alreadyRecording)
        }
    }
    
    // MARK: - Repository Integration Tests
    
    func testRecordingPersistence() async throws {
        // Given
        let expectedURL = URL(string: "file://test-recording.m4a")!
        mockAudioService.startRecordingResult = expectedURL
        mockAudioService.stopRecordingResult = RecordingResult(
            audioURL: expectedURL,
            duration: 15.0,
            fileSize: 2048
        )
        
        // When
        _ = try await recordingUseCase.startRecording(title: "Persistence Test")
        let recording = try await recordingUseCase.stopRecording()
        
        // Then
        XCTAssertTrue(mockRepository.saveCalled)
        XCTAssertEqual(mockRepository.savedRecording?.title, "Persistence Test")
        XCTAssertEqual(mockRepository.savedRecording?.audioFileURL, expectedURL)
        XCTAssertEqual(mockRepository.savedRecording?.duration, 15.0)
    }
    
    func testRecordingsListUpdate() async throws {
        // Given
        let recordings = [
            createTestRecording(title: "Recording 1"),
            createTestRecording(title: "Recording 2")
        ]
        mockRepository.recordings = recordings
        
        // When
        let retrievedRecordings = try await recordingUseCase.getAllRecordings()
        
        // Then
        XCTAssertEqual(retrievedRecordings.count, 2)
        XCTAssertEqual(retrievedRecordings[0].title, "Recording 1")
        XCTAssertEqual(retrievedRecordings[1].title, "Recording 2")
    }
    
    // MARK: - Audio Level Monitoring Tests
    
    func testAudioLevelPublisher() {
        // Given
        let expectation = XCTestExpectation(description: "Audio level received")
        let testLevel: Float = 0.75
        
        // When
        recordingUseCase.audioLevels
            .sink { level in
                XCTAssertEqual(level, testLevel, accuracy: 0.01)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Simulate audio level
        mockAudioService.simulateAudioLevel(testLevel)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testRecordingTimePublisher() {
        // Given
        let expectation = XCTestExpectation(description: "Recording time received")
        let testTime: TimeInterval = 30.0
        
        // When
        recordingUseCase.recordingTime
            .sink { time in
                XCTAssertEqual(time, testTime, accuracy: 0.1)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Simulate recording time
        mockAudioService.simulateRecordingTime(testTime)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestRecording(title: String) -> Recording {
        return Recording(
            id: UUID(),
            title: title,
            date: Date(),
            duration: 10.0,
            audioFileURL: URL(string: "file://test.m4a")!,
            transcription: nil,
            whisperModel: "base",
            language: "ja",
            isFromLimitless: false,
            speakers: [],
            summaries: [],
            tags: []
        )
    }
}

// MARK: - Mock Classes

class MockAudioRecordingService: AudioRecordingServiceProtocol {
    var startRecordingCalled = false
    var stopRecordingCalled = false
    var pauseRecordingCalled = false
    var resumeRecordingCalled = false
    
    var shouldThrowError = false
    var errorToThrow: Error = RecordingError.deviceNotAvailable
    
    var startRecordingResult: URL = URL(string: "file://mock-recording.m4a")!
    var stopRecordingResult: RecordingResult = RecordingResult(
        audioURL: URL(string: "file://mock-recording.m4a")!,
        duration: 10.0,
        fileSize: 1024
    )
    
    private let audioLevelsSubject = PassthroughSubject<Float, Never>()
    private let recordingTimeSubject = PassthroughSubject<TimeInterval, Never>()
    
    var audioLevels: AnyPublisher<Float, Never> {
        audioLevelsSubject.eraseToAnyPublisher()
    }
    
    var recordingTime: AnyPublisher<TimeInterval, Never> {
        recordingTimeSubject.eraseToAnyPublisher()
    }
    
    func startRecording() async throws -> URL {
        startRecordingCalled = true
        if shouldThrowError {
            throw errorToThrow
        }
        return startRecordingResult
    }
    
    func stopRecording() async throws -> RecordingResult {
        stopRecordingCalled = true
        if shouldThrowError {
            throw errorToThrow
        }
        return stopRecordingResult
    }
    
    func pauseRecording() async throws {
        pauseRecordingCalled = true
        if shouldThrowError {
            throw errorToThrow
        }
    }
    
    func resumeRecording() async throws {
        resumeRecordingCalled = true
        if shouldThrowError {
            throw errorToThrow
        }
    }
    
    // Test helpers
    func simulateAudioLevel(_ level: Float) {
        audioLevelsSubject.send(level)
    }
    
    func simulateRecordingTime(_ time: TimeInterval) {
        recordingTimeSubject.send(time)
    }
}

class MockRecordingRepository: RecordingRepositoryProtocol {
    var saveCalled = false
    var savedRecording: Recording?
    var recordings: [Recording] = []
    
    private let recordingsSubject = CurrentValueSubject<[Recording], Never>([])
    private let recordingCountSubject = CurrentValueSubject<Int, Never>(0)
    
    var recordingsPublisher: AnyPublisher<[Recording], Never> {
        recordingsSubject.eraseToAnyPublisher()
    }
    
    var recordingCountPublisher: AnyPublisher<Int, Never> {
        recordingCountSubject.eraseToAnyPublisher()
    }
    
    func save(_ recording: Recording) async throws {
        saveCalled = true
        savedRecording = recording
        recordings.append(recording)
        recordingsSubject.send(recordings)
        recordingCountSubject.send(recordings.count)
    }
    
    func findById(_ id: UUID) async throws -> Recording? {
        return recordings.first { $0.id == id }
    }
    
    func findAll() async throws -> [Recording] {
        return recordings
    }
    
    func update(_ recording: Recording) async throws {
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            recordings[index] = recording
            recordingsSubject.send(recordings)
        }
    }
    
    func delete(id: UUID) async throws {
        recordings.removeAll { $0.id == id }
        recordingsSubject.send(recordings)
        recordingCountSubject.send(recordings.count)
    }
    
    // Simplified implementations for other required methods
    func findByDateRange(from: Date, to: Date) async throws -> [Recording] { return [] }
    func findByTitle(containing text: String) async throws -> [Recording] { return [] }
    func findWithTranscription() async throws -> [Recording] { return [] }
    func findByTag(_ tag: Tag) async throws -> [Recording] { return [] }
    func findByDuration(min: TimeInterval, max: TimeInterval) async throws -> [Recording] { return [] }
    func getTotalRecordingTime() async throws -> TimeInterval { return 0 }
    func getRecordingCount() async throws -> Int { return recordings.count }
    func getMostUsedTags(limit: Int) async throws -> [Tag] { return [] }
    func getRecordingsByMonth() async throws -> [String: Int] { return [:] }
    func searchTranscriptions(query: String) async throws -> [Recording] { return [] }
    func findSimilarRecordings(to recording: Recording, limit: Int) async throws -> [Recording] { return [] }
    func saveMultiple(_ recordings: [Recording]) async throws {}
    func deleteMultiple(ids: [UUID]) async throws {}
    func exportRecordings(ids: [UUID]) async throws -> URL { return URL(string: "file://export")! }
    func cleanupOrphanedFiles() async throws {}
    func getStorageUsage() async throws -> Int64 { return 0 }
}