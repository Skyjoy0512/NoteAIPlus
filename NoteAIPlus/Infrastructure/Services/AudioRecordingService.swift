import Foundation
import AVFoundation
import Combine

class AudioRecordingService: NSObject, AudioRecordingServiceProtocol {
    // MARK: - Properties
    
    private var audioEngine: AVAudioEngine
    private var audioFile: AVAudioFile?
    private var recordingSession: AVAudioSession
    private var recordingTimer: Timer?
    private var isCurrentlyRecording = false
    private var isPaused = false
    
    // Publishers for real-time data
    private let audioLevelsSubject = PassthroughSubject<Float, Never>()
    private let recordingTimeSubject = CurrentValueSubject<TimeInterval, Never>(0)
    
    // Recording state
    private var recordingStartTime: Date?
    private var pausedDuration: TimeInterval = 0
    
    // Audio configuration
    private let bufferSize: AVAudioFrameCount = 1024
    private var currentAudioFormat: AVAudioFormat?
    
    // MARK: - Initialization
    
    override init() {
        self.audioEngine = AVAudioEngine()
        self.recordingSession = AVAudioSession.sharedInstance()
        super.init()
        
        setupNotifications()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - AudioRecordingServiceProtocol
    
    var audioLevels: AnyPublisher<Float, Never> {
        audioLevelsSubject.eraseToAnyPublisher()
    }
    
    var recordingTime: AnyPublisher<TimeInterval, Never> {
        recordingTimeSubject.eraseToAnyPublisher()
    }
    
    func startRecording() async throws -> URL {
        guard !isCurrentlyRecording else {
            throw RecordingError.alreadyRecording
        }
        
        // Check microphone permission
        try await requestMicrophonePermission()
        
        // Configure audio session
        try await configureAudioSession()
        
        // Create audio file
        let audioFileURL = try createAudioFile()
        
        // Setup audio engine
        try setupAudioEngine(audioFileURL: audioFileURL)
        
        // Start recording
        try audioEngine.start()
        
        // Start monitoring
        startRecordingTimer()
        startAudioLevelMonitoring()
        
        // Update state
        isCurrentlyRecording = true
        isPaused = false
        recordingStartTime = Date()
        pausedDuration = 0
        recordingTimeSubject.send(0)
        
        return audioFileURL
    }
    
    func stopRecording() async throws -> RecordingResult {
        guard isCurrentlyRecording else {
            throw RecordingError.noActiveRecording
        }
        
        // Stop audio engine
        audioEngine.stop()
        stopRecordingTimer()
        
        // Finalize audio file
        guard let audioFile = audioFile else {
            throw RecordingError.fileSaveFailed
        }
        
        let fileURL = audioFile.url
        let duration = getCurrentRecordingDuration()
        let fileSize = try getFileSize(url: fileURL)
        
        // Cleanup
        cleanup()
        
        // Reset state
        isCurrentlyRecording = false
        isPaused = false
        recordingStartTime = nil
        pausedDuration = 0
        recordingTimeSubject.send(0)
        
        return RecordingResult(
            audioURL: fileURL,
            duration: duration,
            fileSize: fileSize
        )
    }
    
    func pauseRecording() async throws {
        guard isCurrentlyRecording && !isPaused else {
            throw RecordingError.cannotPause
        }
        
        // Pause audio engine
        audioEngine.pause()
        stopRecordingTimer()
        
        // Update paused duration
        if let startTime = recordingStartTime {
            pausedDuration += Date().timeIntervalSince(startTime)
        }
        
        isPaused = true
    }
    
    func resumeRecording() async throws {
        guard isCurrentlyRecording && isPaused else {
            throw RecordingError.cannotResume
        }
        
        // Resume audio engine
        try audioEngine.start()
        startRecordingTimer()
        
        // Reset start time for duration calculation
        recordingStartTime = Date()
        isPaused = false
    }
    
    // MARK: - Private Methods
    
    private func requestMicrophonePermission() async throws {
        let status = AVAudioSession.sharedInstance().recordPermission
        
        switch status {
        case .granted:
            return
        case .denied:
            throw RecordingError.permissionDenied
        case .undetermined:
            let granted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            
            if !granted {
                throw RecordingError.permissionDenied
            }
        @unknown default:
            throw RecordingError.permissionDenied
        }
    }
    
    private func configureAudioSession() async throws {
        do {
            try recordingSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.allowBluetooth, .defaultToSpeaker]
            )
            
            try recordingSession.setPreferredSampleRate(44100.0)
            try recordingSession.setPreferredIOBufferDuration(0.005)
            try recordingSession.setActive(true)
            
        } catch {
            throw RecordingError.audioSessionError(error)
        }
    }
    
    private func createAudioFile() throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documentsPath.appendingPathComponent("Recordings")
        
        // Create recordings directory if it doesn't exist
        try FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        
        // Generate unique filename
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let filename = "Recording_\(timestamp).m4a"
        let fileURL = recordingsDir.appendingPathComponent(filename)
        
        // Check available disk space
        try checkDiskSpace()
        
        // Create audio file
        let settings = getAudioSettings()
        
        do {
            audioFile = try AVAudioFile(forWriting: fileURL, settings: settings)
            return fileURL
        } catch {
            throw RecordingError.fileCreationError(error)
        }
    }
    
    private func setupAudioEngine(audioFileURL: URL) throws {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Store current format
        currentAudioFormat = recordingFormat
        
        // Install tap for recording
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self, let audioFile = self.audioFile else { return }
            
            do {
                try audioFile.write(from: buffer)
            } catch {
                print("Failed to write audio buffer: \(error)")
            }
            
            // Process audio level
            self.processAudioBuffer(buffer)
        }
        
        // Prepare audio engine
        audioEngine.prepare()
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let currentDuration = self.getCurrentRecordingDuration()
            self.recordingTimeSubject.send(currentDuration)
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func startAudioLevelMonitoring() {
        // Audio level monitoring is handled in the installTap callback
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0
        
        // Calculate RMS level
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(frameLength))
        let decibelLevel = 20 * log10(max(rms, 0.000001)) // Avoid log(0)
        
        // Normalize to 0-1 range for UI
        let normalizedLevel = max(0, min(1, (decibelLevel + 60) / 60)) // -60dB to 0dB range
        
        DispatchQueue.main.async {
            self.audioLevelsSubject.send(normalizedLevel)
        }
    }
    
    private func getCurrentRecordingDuration() -> TimeInterval {
        guard let startTime = recordingStartTime else { return pausedDuration }
        
        if isPaused {
            return pausedDuration
        } else {
            return pausedDuration + Date().timeIntervalSince(startTime)
        }
    }
    
    private func getAudioSettings() -> [String: Any] {
        return [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 128000,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
    }
    
    private func checkDiskSpace() throws {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw RecordingError.diskSpaceInsufficient
        }
        
        do {
            let values = try documentsPath.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            if let availableCapacity = values.volumeAvailableCapacity {
                // Require at least 100MB free space
                if availableCapacity < 100 * 1024 * 1024 {
                    throw RecordingError.diskSpaceInsufficient
                }
            }
        } catch {
            throw RecordingError.diskSpaceInsufficient
        }
    }
    
    private func getFileSize(url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Handle interruption began (e.g., phone call)
            if isCurrentlyRecording && !isPaused {
                Task {
                    try? await pauseRecording()
                }
            }
            
        case .ended:
            // Handle interruption ended
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) && isPaused {
                    Task {
                        try? await resumeRecording()
                    }
                }
            }
            
        @unknown default:
            break
        }
    }
    
    @objc private func handleAudioSessionRouteChange(notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .newDeviceAvailable:
            // New audio device connected
            break
        case .oldDeviceUnavailable:
            // Audio device disconnected
            if isCurrentlyRecording {
                // Optionally pause recording when device is disconnected
            }
        default:
            break
        }
    }
    
    private func cleanup() {
        // Remove tap
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // Stop timer
        stopRecordingTimer()
        
        // Reset audio file
        audioFile = nil
        currentAudioFormat = nil
        
        // Remove observers
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Supporting Types

struct RecordingResult {
    let audioURL: URL
    let duration: TimeInterval
    let fileSize: Int64
}

enum RecordingError: LocalizedError, Equatable {
    case alreadyRecording
    case noActiveRecording
    case cannotPause
    case cannotResume
    case permissionDenied
    case deviceNotAvailable
    case audioSessionError(Error)
    case fileCreationError(Error)
    case fileSaveFailed
    case diskSpaceInsufficient
    
    static func == (lhs: RecordingError, rhs: RecordingError) -> Bool {
        switch (lhs, rhs) {
        case (.alreadyRecording, .alreadyRecording),
             (.noActiveRecording, .noActiveRecording),
             (.cannotPause, .cannotPause),
             (.cannotResume, .cannotResume),
             (.permissionDenied, .permissionDenied),
             (.deviceNotAvailable, .deviceNotAvailable),
             (.fileSaveFailed, .fileSaveFailed),
             (.diskSpaceInsufficient, .diskSpaceInsufficient):
            return true
        case (.audioSessionError, .audioSessionError),
             (.fileCreationError, .fileCreationError):
            return true // Simplified equality for Error cases
        default:
            return false
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "録音が既に進行中です。"
        case .noActiveRecording:
            return "アクティブな録音がありません。"
        case .cannotPause:
            return "録音を一時停止できません。"
        case .cannotResume:
            return "録音を再開できません。"
        case .permissionDenied:
            return "マイクへのアクセス許可が必要です。設定アプリで許可してください。"
        case .deviceNotAvailable:
            return "録音デバイスが利用できません。マイクが接続されているか確認してください。"
        case .audioSessionError(let error):
            return "音声セッションエラー: \(error.localizedDescription)"
        case .fileCreationError(let error):
            return "録音ファイルの作成に失敗しました: \(error.localizedDescription)"
        case .fileSaveFailed:
            return "録音ファイルの保存に失敗しました。"
        case .diskSpaceInsufficient:
            return "ストレージ容量が不足しています。空き容量を確保してください。"
        }
    }
}