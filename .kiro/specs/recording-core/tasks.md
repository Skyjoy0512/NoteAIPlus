# 録音機能 - 実装タスク

## タスク概要

録音機能の実装を以下の順序で進める。各タスクは独立性を保ちつつ、段階的に機能を構築していく。

## Phase 1: 基盤実装 (8時間)

### Task 1.1: AudioRecordingService基本実装
- [ ] AVAudioEngineの初期化・設定
- [ ] 基本的な録音開始・停止機能
- [ ] 音声セッション設定
- [ ] エラーハンドリング基盤

**実装ファイル:**
- `Infrastructure/Services/AudioRecordingService.swift`

**詳細:**
```swift
class AudioRecordingService: NSObject, AudioRecordingServiceProtocol {
    private var audioEngine: AVAudioEngine
    private var audioFile: AVAudioFile?
    
    func startRecording() async throws -> URL
    func stopRecording() async throws -> RecordingResult
}
```

**受け入れ条件:**
- [ ] 基本的な録音・停止が動作する
- [ ] 音声ファイルが正常に保存される
- [ ] マイク権限エラーが適切に処理される

### Task 1.2: RecordingUseCase実装
- [ ] Domain層のビジネスロジック実装
- [ ] Repository との連携
- [ ] Recording Entity の作成・管理

**実装ファイル:**
- `Domain/UseCases/RecordingUseCase.swift`

**詳細:**
```swift
class RecordingUseCase: ObservableObject {
    @Published var currentRecordingSession: RecordingSession?
    @Published var isRecording = false
    
    func startRecording(title: String?) async throws -> RecordingSession
    func stopRecording() async throws -> Recording
}
```

**受け入れ条件:**
- [ ] Clean Architecture の依存関係が適切
- [ ] ビジネスルールが正しく実装される
- [ ] Repository への保存が動作する

### Task 1.3: RecordingRepository実装
- [ ] Core Data との連携実装
- [ ] CRUD操作の実装
- [ ] エンティティ変換の実装

**実装ファイル:**
- `Data/Repositories/RecordingRepository.swift`

**詳細:**
```swift
class RecordingRepository: RecordingRepositoryProtocol {
    func save(_ recording: Recording) async throws
    func findAll() async throws -> [Recording]
    func delete(id: UUID) async throws
}
```

**受け入れ条件:**
- [ ] Recording の保存・取得が動作する
- [ ] Domain Entity ↔ Core Data Entity変換が正確
- [ ] エラー処理が適切

### Task 1.4: 基本的なRecordingViewModel実装
- [ ] SwiftUI 用のViewModel作成
- [ ] 基本的な状態管理
- [ ] UseCase との連携

**実装ファイル:**
- `Presentation/ViewModels/RecordingViewModel.swift`

**詳細:**
```swift
class RecordingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    
    func startRecording() async
    func stopRecording() async
}
```

**受け入れ条件:**
- [ ] 基本的な録音制御が動作する
- [ ] UI状態が適切に更新される
- [ ] エラー状態が適切に表示される

## Phase 2: UI実装 (4時間)

### Task 2.1: RecordingView基本実装
- [ ] SwiftUI での録音画面作成
- [ ] 録音ボタンの実装
- [ ] 録音時間表示の実装

**実装ファイル:**
- `Presentation/Views/Recording/RecordingView.swift`

**詳細:**
```swift
struct RecordingView: View {
    @StateObject private var viewModel = RecordingViewModel()
    
    var body: some View {
        VStack {
            Text(viewModel.formattedTime)
            RecordButton(isRecording: viewModel.isRecording) {
                // 録音制御
            }
        }
    }
}
```

**受け入れ条件:**
- [ ] 直感的な録音UI が表示される
- [ ] 録音状態が視覚的に分かりやすい
- [ ] タップ操作が適切に動作する

### Task 2.2: RecordButton Component実装
- [ ] 再利用可能な録音ボタンコンポーネント
- [ ] 録音状態に応じたアニメーション
- [ ] アクセシビリティ対応

**実装ファイル:**
- `Presentation/Components/RecordButton.swift`

**詳細:**
```swift
struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            // 録音状態に応じたUI
        }
        .accessibilityLabel(isRecording ? "録音停止" : "録音開始")
    }
}
```

**受け入れ条件:**
- [ ] 録音状態が視覚的に明確
- [ ] アニメーションが自然
- [ ] VoiceOver で正しく読み上げられる

### Task 2.3: 録音時間表示実装
- [ ] リアルタイム時間更新
- [ ] 見やすいタイマー表示
- [ ] フォーマット処理

**実装詳細:**
```swift
extension RecordingViewModel {
    var formattedTime: String {
        let hours = Int(recordingTime) / 3600
        let minutes = Int(recordingTime) % 3600 / 60
        let seconds = Int(recordingTime) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
```

**受け入れ条件:**
- [ ] 時間が1秒間隔で正確に更新される
- [ ] 表示形式が適切（MM:SS または HH:MM:SS）
- [ ] 大きく見やすいフォント

## Phase 3: 高度な機能 (3時間)

### Task 3.1: 一時停止・再開機能
- [ ] 一時停止・再開のロジック実装
- [ ] UI状態の管理
- [ ] ファイル継続書き込み処理

**実装詳細:**
```swift
extension AudioRecordingService {
    func pauseRecording() async throws {
        audioEngine.pause()
        // 状態保存
    }
    
    func resumeRecording() async throws {
        try audioEngine.start()
        // 状態復元
    }
}
```

**受け入れ条件:**
- [ ] 一時停止・再開がスムーズに動作
- [ ] 音声ファイルが継続される
- [ ] UI状態が適切に表示される

### Task 3.2: 音声レベル監視実装
- [ ] リアルタイム音声レベル取得
- [ ] 波形表示コンポーネント
- [ ] レベルメーター表示

**実装ファイル:**
- `Presentation/Components/WaveformView.swift`
- `Infrastructure/Services/AudioLevelMonitor.swift`

**詳細:**
```swift
private func setupAudioLevelMonitoring() {
    let inputNode = audioEngine.inputNode
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { buffer, _ in
        let level = self.calculateAudioLevel(buffer)
        self.audioLevelsSubject.send(level)
    }
}
```

**受け入れ条件:**
- [ ] 音声レベルがリアルタイムで表示される
- [ ] 波形が滑らかに描画される
- [ ] 音が小さい場合の警告表示

### Task 3.3: 音質・形式設定実装
- [ ] 設定画面での音質選択
- [ ] ファイル形式選択
- [ ] 設定の永続化

**実装ファイル:**
- `Presentation/Views/Settings/AudioSettingsView.swift`
- `Infrastructure/Services/AudioSettingsManager.swift`

**詳細:**
```swift
enum AudioQuality: String, CaseIterable {
    case high = "高音質"    // 256kbps
    case medium = "中音質"  // 128kbps
    case low = "低音質"     // 64kbps
}

enum AudioFormat: String, CaseIterable {
    case m4a = "M4A"
    case wav = "WAV"
}
```

**受け入れ条件:**
- [ ] 設定が永続化される
- [ ] 音質設定が録音に反映される
- [ ] ファイル形式が正しく選択される

## Phase 4: バックグラウンド・エラー処理 (1時間)

### Task 4.1: バックグラウンド録音実装
- [ ] Background Modes設定
- [ ] 音声セッション設定
- [ ] アプリ状態監視

**実装詳細:**
```swift
private func configureBackgroundRecording() {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playAndRecord, options: .mixWithOthers)
    
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleAppStateChange),
        name: UIApplication.didEnterBackgroundNotification,
        object: nil
    )
}
```

**受け入れ条件:**
- [ ] アプリを閉じても録音継続
- [ ] 画面ロック中も録音継続
- [ ] 通知で録音状態表示

### Task 4.2: 包括的エラーハンドリング
- [ ] マイク権限エラー処理
- [ ] 容量不足エラー処理
- [ ] デバイスエラー処理
- [ ] ユーザーフレンドリーなエラーメッセージ

**実装詳細:**
```swift
enum RecordingError: LocalizedError {
    case permissionDenied
    case diskSpaceInsufficient
    case deviceNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "マイクへのアクセス許可が必要です"
        // その他のエラー
        }
    }
}
```

**受け入れ条件:**
- [ ] 全てのエラーケースが適切に処理される
- [ ] エラーメッセージが分かりやすい
- [ ] 復旧可能なエラーには適切な案内

## 最終統合・テスト (2時間)

### Task 5.1: 統合テスト実装
- [ ] 録音フロー全体のテスト
- [ ] エラーケースのテスト
- [ ] パフォーマンステスト

**テストファイル:**
- `NoteAIPlusTests/RecordingIntegrationTests.swift`

**テスト項目:**
```swift
func testCompleteRecordingFlow() async throws {
    // 録音開始 → 一時停止 → 再開 → 停止 → 保存
}

func testBackgroundRecording() async throws {
    // バックグラウンド状態での録音継続
}

func testErrorHandling() async throws {
    // 各種エラー状況での適切な処理
}
```

### Task 5.2: パフォーマンス最適化
- [ ] メモリリーク修正
- [ ] CPU使用率最適化
- [ ] バッテリー消費最適化

**最適化項目:**
- 不要なオブザーバーの削除
- タイマーの適切な停止
- 音声バッファの効率的な処理

### Task 5.3: ドキュメント更新
- [ ] API仕様書更新
- [ ] 実装メモ作成
- [ ] トラブルシューティング情報

## 検証チェックリスト

### 機能検証
- [ ] 基本的な録音・停止が動作する
- [ ] 一時停止・再開が正常に動作する
- [ ] バックグラウンド録音が継続される
- [ ] 音声レベルがリアルタイム表示される
- [ ] 各種設定が適用される
- [ ] エラー時に適切なメッセージが表示される

### 品質検証
- [ ] 音質が選択した設定通りになる
- [ ] ファイルサイズが適切な範囲内
- [ ] UI操作がスムーズで直感的
- [ ] アクセシビリティが適切に動作

### パフォーマンス検証
- [ ] 録音開始の遅延が50ms以下
- [ ] 長時間録音（4時間以上）が安定動作
- [ ] メモリ使用量が50MB以下に維持
- [ ] CPU使用率が10%以下に維持

### セキュリティ検証
- [ ] 録音データがローカルのみに保存
- [ ] マイク権限が適切に管理される
- [ ] 不正なファイルアクセスがない

## 依存関係

### 前提条件
- [x] Clean Architecture基盤実装
- [x] Core Data設定
- [ ] 基本的なNavigation実装

### 後続タスク
- [ ] 文字起こし機能との連携
- [ ] 録音一覧表示機能
- [ ] 録音詳細表示機能
- [ ] 設定画面実装

## リスク・課題

### 技術リスク
- **AVAudioEngine の複雑性**: 詳細な調査とテストが必要
- **バックグラウンド処理制限**: iOS制限事項の詳細確認
- **メモリ管理**: 長時間録音でのメモリリーク対策

### 対策
- 段階的実装とテスト
- 実機での詳細検証
- メモリプロファイリング実施

## 完了定義

全てのタスクが完了し、検証チェックリストの全項目がクリアされた時点で、録音機能の実装完了とする。