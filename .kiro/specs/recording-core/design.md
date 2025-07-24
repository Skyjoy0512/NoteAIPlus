# 録音機能 - 技術設計

## アーキテクチャ概要

録音機能はClean Architectureパターンに従い、以下の層で構成される：

```
Presentation Layer (RecordingView + RecordingViewModel)
    ↓
Domain Layer (RecordingUseCase + Recording Entity)
    ↓ 
Data Layer (RecordingRepository)
    ↓
Infrastructure Layer (AudioRecordingService)
```

## コンポーネント設計

### 1. Presentation Layer

#### RecordingViewModel
```swift
class RecordingViewModel: ObservableObject {
    // Published Properties
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var recordingTime: TimeInterval = 0
    @Published var audioLevels: [Float] = []
    @Published var currentSession: RecordingSession?
    @Published var errorMessage: String?
    
    // Dependencies
    private let recordingUseCase: RecordingUseCase
    
    // Public Methods
    func startRecording()
    func stopRecording() 
    func pauseRecording()
    func resumeRecording()
    func cancelRecording()
}
```

#### RecordingView
```swift
struct RecordingView: View {
    @StateObject private var viewModel = RecordingViewModel()
    
    var body: some View {
        VStack {
            // 波形表示
            WaveformView(audioLevels: viewModel.audioLevels)
            
            // 録音時間
            Text(viewModel.formattedTime)
            
            // 録音ボタン
            RecordButton(isRecording: viewModel.isRecording) {
                viewModel.toggleRecording()
            }
            
            // コントロールボタン
            RecordingControlsView(viewModel: viewModel)
        }
    }
}
```

### 2. Domain Layer

#### Recording Entity
```swift
struct Recording: Identifiable {
    let id: UUID
    var title: String
    let date: Date
    let duration: TimeInterval
    let audioFileURL: URL
    let audioQuality: AudioQuality
    let fileFormat: AudioFormat
    var isFromBackground: Bool
    
    enum AudioQuality: String, CaseIterable {
        case high = "high"     // 256kbps
        case medium = "medium" // 128kbps  
        case low = "low"       // 64kbps
    }
    
    enum AudioFormat: String, CaseIterable {
        case m4a = "m4a"
        case wav = "wav"
    }
}
```

#### RecordingUseCase
```swift
class RecordingUseCase {
    private let recordingRepository: RecordingRepositoryProtocol
    private let audioService: AudioRecordingServiceProtocol
    
    func startRecording(title: String?, quality: AudioQuality, format: AudioFormat) async throws -> RecordingSession
    func stopRecording() async throws -> Recording
    func pauseRecording() async throws
    func resumeRecording() async throws
    func cancelRecording() async throws
    
    // Reactive properties
    var audioLevels: AnyPublisher<Float, Never>
    var recordingTime: AnyPublisher<TimeInterval, Never>
}
```

### 3. Infrastructure Layer

#### AudioRecordingService
```swift
class AudioRecordingService: NSObject, AudioRecordingServiceProtocol {
    private var audioEngine: AVAudioEngine
    private var audioFile: AVAudioFile?
    private var recordingSession: AVAudioSession
    private var timer: Timer?
    
    // Audio configuration
    private let audioFormat: AVAudioFormat
    private let bufferSize: AVAudioFrameCount = 1024
    
    func startRecording() async throws -> URL
    func stopRecording() async throws -> RecordingResult
    func pauseRecording() async throws
    func resumeRecording() async throws
    
    // Real-time monitoring
    var audioLevels: AnyPublisher<Float, Never>
    var recordingTime: AnyPublisher<TimeInterval, Never>
}
```

## 詳細設計

### 音声セッション設定

```swift
private func configureAudioSession() async throws {
    let session = AVAudioSession.sharedInstance()
    
    try await session.setCategory(
        .playAndRecord,
        mode: .default,
        options: [.allowBluetooth, .defaultToSpeaker]
    )
    
    try await session.setPreferredSampleRate(44100.0)
    try await session.setPreferredIOBufferDuration(0.005)
    try await session.setActive(true)
}
```

### バックグラウンド録音設定

```swift
// Info.plist
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>

// Swift implementation
private func enableBackgroundRecording() {
    let audioSession = AVAudioSession.sharedInstance()
    try? audioSession.setCategory(.record, options: .mixWithOthers)
    
    // Background task identifier
    var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    backgroundTaskID = UIApplication.shared.beginBackgroundTask {
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
}
```

### 音声レベル監視

```swift
private func setupAudioLevelMonitoring() {
    let inputNode = audioEngine.inputNode
    let recordingFormat = inputNode.outputFormat(forBus: 0)
    
    inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { [weak self] buffer, _ in
        self?.processAudioBuffer(buffer)
    }
}

private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
    guard let channelData = buffer.floatChannelData?[0] else { return }
    
    let frameLength = Int(buffer.frameLength)
    var sum: Float = 0
    
    for i in 0..<frameLength {
        sum += abs(channelData[i])
    }
    
    let averageLevel = sum / Float(frameLength)
    let decibelLevel = 20 * log10(averageLevel)
    
    DispatchQueue.main.async {
        self.audioLevelsSubject.send(decibelLevel)
    }
}
```

### ファイル保存処理

```swift
private func createAudioFile(format: AudioFormat, quality: AudioQuality) throws -> AVAudioFile {
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let recordingsDir = documentsPath.appendingPathComponent("Recordings")
    
    try FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
    
    let fileName = generateFileName(format: format)
    let fileURL = recordingsDir.appendingPathComponent(fileName)
    
    let settings = getAudioSettings(format: format, quality: quality)
    let audioFormat = AVAudioFormat(settings: settings)!
    
    return try AVAudioFile(forWriting: fileURL, settings: settings)
}

private func getAudioSettings(format: AudioFormat, quality: AudioQuality) -> [String: Any] {
    var settings: [String: Any] = [
        AVSampleRateKey: 44100.0,
        AVNumberOfChannelsKey: 1
    ]
    
    switch format {
    case .m4a:
        settings[AVFormatIDKey] = kAudioFormatMPEG4AAC
        settings[AVEncoderBitRateKey] = quality.bitRate
        
    case .wav:
        settings[AVFormatIDKey] = kAudioFormatLinearPCM
        settings[AVLinearPCMBitDepthKey] = 16
        settings[AVLinearPCMIsFloatKey] = false
        settings[AVLinearPCMIsBigEndianKey] = false
    }
    
    return settings
}
```

### エラーハンドリング

```swift
enum RecordingError: LocalizedError {
    case permissionDenied
    case deviceNotAvailable
    case audioSessionError(Error)
    case fileCreationError(Error)
    case diskSpaceInsufficient
    case recordingInProgress
    case noActiveRecording
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "マイクへのアクセス許可が必要です。設定アプリで許可してください。"
        case .deviceNotAvailable:
            return "録音デバイスが利用できません。マイクが接続されているか確認してください。"
        case .audioSessionError(let error):
            return "音声セッションエラー: \(error.localizedDescription)"
        case .fileCreationError(let error):
            return "録音ファイルの作成に失敗しました: \(error.localizedDescription)"
        case .diskSpaceInsufficient:
            return "ストレージ容量が不足しています。空き容量を確保してください。"
        case .recordingInProgress:
            return "録音が既に進行中です。"
        case .noActiveRecording:
            return "アクティブな録音がありません。"
        }
    }
}
```

### 状態管理

```swift
enum RecordingState {
    case idle
    case preparing
    case recording
    case paused
    case stopping
    case error(RecordingError)
    
    var canStart: Bool {
        self == .idle
    }
    
    var canStop: Bool {
        self == .recording || self == .paused
    }
    
    var canPause: Bool {
        self == .recording
    }
    
    var canResume: Bool {
        self == .paused
    }
}
```

## UI設計

### RecordButton Component
```swift
struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.gray.opacity(0.3))
                    .frame(width: 100, height: 100)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: isRecording ? 40 : 80)
                    .scaleEffect(isRecording ? 0.7 : 1.0)
            }
        }
        .scaleEffect(isRecording ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isRecording)
    }
}
```

### WaveformView Component
```swift
struct WaveformView: View {
    let audioLevels: [Float]
    let barCount: Int = 50
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
                    .frame(width: 3, height: CGFloat(getBarHeight(for: index)))
                    .animation(.easeInOut(duration: 0.1), value: audioLevels)
            }
        }
        .frame(height: 100)
    }
    
    private func getBarHeight(for index: Int) -> Float {
        guard index < audioLevels.count else { return 4 }
        let level = audioLevels[index]
        return max(4, min(100, level * 2))
    }
}
```

## データフロー

### 録音開始フロー
```
User Tap → RecordingViewModel.startRecording()
    ↓
RecordingUseCase.startRecording()
    ↓
AudioRecordingService.startRecording()
    ↓
AVAudioEngine configuration & start
    ↓
Real-time audio monitoring
    ↓
UI updates via Combine publishers
```

### 録音停止フロー
```
User Tap → RecordingViewModel.stopRecording()
    ↓
RecordingUseCase.stopRecording()
    ↓
AudioRecordingService.stopRecording()
    ↓
AVAudioEngine stop & file finalization
    ↓
Recording entity creation
    ↓
RecordingRepository.save()
    ↓
Core Data persistence
```

## パフォーマンス最適化

### メモリ管理
- AVAudioPCMBufferの適切な解放
- Timer・Publisher・Observer の適切なクリーンアップ
- Background task の適切な終了

### CPU使用率最適化
- 音声レベル計算の最適化
- UI更新頻度の制限（60fps以下）
- Background thread での重い処理

### バッテリー最適化
- 不要な音声処理の停止
- 画面オフ時のUI更新停止
- 効率的なオーディオ形式の使用

## セキュリティ考慮事項

### プライバシー保護
- 録音データの完全ローカル保存
- 外部送信の明示的な禁止
- ユーザー同意なしのデータ収集禁止

### 権限管理
- マイク権限の適切な要求
- 権限状態の定期的な確認
- 権限拒否時の代替フロー

## テスト戦略

### ユニットテスト
```swift
class RecordingUseCaseTests: XCTestCase {
    func testStartRecording_Success() async throws {
        // Given
        let mockAudioService = MockAudioRecordingService()
        let useCase = RecordingUseCase(audioService: mockAudioService)
        
        // When
        let session = try await useCase.startRecording()
        
        // Then
        XCTAssertNotNil(session)
        XCTAssertTrue(mockAudioService.startRecordingCalled)
    }
}
```

### 統合テスト
- 実際のAVAudioEngineを使用した録音テスト
- バックグラウンド録音の動作確認
- 長時間録音のストレステスト

### UIテスト
- 録音ボタンの操作確認
- 音声レベル表示の確認
- エラー状態の表示確認

## 監視・ログ

### ログ記録
```swift
private func logRecordingEvent(_ event: RecordingEvent) {
    Logger.shared.log(
        level: .info,
        category: .recording,
        message: event.description,
        metadata: event.metadata
    )
}
```

### メトリクス収集
- 録音成功率
- 平均録音時間
- エラー発生率
- パフォーマンス指標