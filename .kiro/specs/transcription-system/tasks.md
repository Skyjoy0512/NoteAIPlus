# 文字起こし機能 - 実装タスク

## タスク概要

WhisperKitを使用した文字起こし機能の実装を段階的に進める。各タスクは独立性を保ちつつ、Clean Architectureに従って構築する。

## Phase 1: 基盤実装 (12時間)

### Task 1.1: WhisperKit統合基盤
- [ ] WhisperKit依存関係の追加・設定
- [ ] 基本的なWhisperServiceプロトコル定義
- [ ] 簡単な文字起こし機能の実装
- [ ] エラーハンドリング基盤

**実装ファイル:**
- `Infrastructure/Services/WhisperService.swift`
- `Domain/Services/TranscriptionServiceProtocol.swift`

**詳細:**
```swift
protocol TranscriptionServiceProtocol {
    func transcribe(audioURL: URL, options: TranscriptionOptions) async throws -> TranscriptionResult
    func isModelLoaded(_ modelType: WhisperModelType) -> Bool
    func loadModel(_ modelType: WhisperModelType) async throws
}

class WhisperService: TranscriptionServiceProtocol {
    private var whisperKit: WhisperKit?
    
    func transcribe(audioURL: URL, options: TranscriptionOptions) async throws -> TranscriptionResult {
        // WhisperKit基本実装
    }
}
```

**受け入れ条件:**
- [ ] WhisperKitが正常に初期化される
- [ ] 基本的な文字起こしが動作する
- [ ] エラーが適切に処理される

### Task 1.2: TranscriptionエンティティとRepository
- [ ] Domain層のTranscriptionResult実装
- [ ] TranscriptionSegment実装
- [ ] TranscriptionRepository実装
- [ ] Core Dataエンティティ作成

**実装ファイル:**
- `Domain/Entities/TranscriptionResult.swift`
- `Domain/Entities/TranscriptionSegment.swift`
- `Data/Repositories/TranscriptionRepository.swift`
- `Data/Models/TranscriptionEntity.swift`

**詳細:**
```swift
struct TranscriptionResult: Identifiable, Codable {
    let id: UUID
    let recordingId: UUID
    let text: String
    let language: String
    let confidence: Float
    let modelType: WhisperModelType
    let segments: [TranscriptionSegment]
    let createdAt: Date
}

class TranscriptionRepository: TranscriptionRepositoryProtocol {
    func save(_ transcription: TranscriptionResult) async throws
    func findByRecordingId(_ recordingId: UUID) async throws -> TranscriptionResult?
    func searchTranscriptions(query: String) async throws -> [TranscriptionResult]
}
```

**受け入れ条件:**
- [ ] TranscriptionResultが正しく定義される
- [ ] Core Dataでの保存・取得が動作する
- [ ] 検索機能が実装される

### Task 1.3: TranscriptionUseCase実装
- [ ] ビジネスロジックの実装
- [ ] RecordingUseCaseとの連携
- [ ] 自動文字起こし機能
- [ ] 手動文字起こし機能

**実装ファイル:**
- `Domain/UseCases/TranscriptionUseCase.swift`

**詳細:**
```swift
class TranscriptionUseCase: ObservableObject {
    @Published var isProcessing = false
    @Published var currentProgress: TranscriptionProgress = .idle
    
    func transcribeRecording(_ recording: Recording, options: TranscriptionOptions) async throws -> TranscriptionResult
    func batchTranscribe(_ recordings: [Recording], options: TranscriptionOptions) async throws -> [TranscriptionResult]
    func searchTranscriptions(query: String) async throws -> [TranscriptionResult]
}
```

**受け入れ条件:**
- [ ] 録音から文字起こし結果を生成できる
- [ ] 複数録音の一括処理が可能
- [ ] 検索機能が動作する

### Task 1.4: 基本UI実装
- [ ] TranscriptionViewModel実装
- [ ] 基本的な文字起こし表示画面
- [ ] 処理進捗表示
- [ ] エラー表示

**実装ファイル:**
- `Presentation/ViewModels/TranscriptionViewModel.swift`
- `Presentation/Views/Transcription/TranscriptionView.swift`

**詳細:**
```swift
@MainActor
class TranscriptionViewModel: ObservableObject {
    @Published var transcriptionState: TranscriptionState = .idle
    @Published var currentTranscription: TranscriptionResult?
    @Published var progress: Float = 0.0
    
    func startTranscription(for recording: Recording) async
    func cancelTranscription()
}
```

**受け入れ条件:**
- [ ] 文字起こし結果が表示される
- [ ] 進捗が適切に表示される
- [ ] ユーザーが操作できる

## Phase 2: モデル管理機能 (6時間)

### Task 2.1: ModelManager実装
- [ ] Whisperモデルのダウンロード管理
- [ ] モデルキャッシュ管理
- [ ] ストレージ使用量監視
- [ ] モデル切り替え機能

**実装ファイル:**
- `Infrastructure/Services/ModelManager.swift`
- `Domain/Entities/WhisperModelType.swift`

**詳細:**
```swift
class ModelManager: ObservableObject {
    @Published var availableModels: [WhisperModelType] = []
    @Published var downloadedModels: Set<WhisperModelType> = []
    @Published var currentDownloads: [WhisperModelType: DownloadProgress] = [:]
    
    func downloadModel(_ modelType: WhisperModelType) async throws
    func deleteModel(_ modelType: WhisperModelType) async throws
    func getStorageUsage() async -> Int64
}
```

**受け入れ条件:**
- [ ] モデルのダウンロード・削除が可能
- [ ] ストレージ使用量が監視される
- [ ] ダウンロード進捗が表示される

### Task 2.2: モデル選択UI
- [ ] モデル選択画面
- [ ] ダウンロード進捗表示
- [ ] ストレージ管理画面
- [ ] 推奨モデル表示

**実装ファイル:**
- `Presentation/Views/Settings/ModelManagementView.swift`

**詳細:**
```swift
struct ModelManagementView: View {
    @StateObject private var modelManager = ModelManager()
    
    var body: some View {
        List(WhisperModelType.allCases) { model in
            ModelRowView(model: model, manager: modelManager)
        }
    }
}
```

**受け入れ条件:**
- [ ] 利用可能モデルが一覧表示される
- [ ] ダウンロード状況が分かる
- [ ] モデル切り替えが可能

### Task 2.3: 自動モデル選択
- [ ] 状況に応じたモデル推奨
- [ ] バッテリー・ネットワーク考慮
- [ ] パフォーマンス最適化
- [ ] ユーザー設定の保存

**実装詳細:**
```swift
class ModelRecommendationEngine {
    func recommendModel(
        for recording: Recording,
        batteryLevel: Float,
        isOnWiFi: Bool,
        userPreference: ModelPreference
    ) -> WhisperModelType {
        // 推奨ロジック実装
    }
}
```

**受け入れ条件:**
- [ ] 状況に応じて適切なモデルが選択される
- [ ] ユーザー設定が尊重される
- [ ] パフォーマンスが最適化される

## Phase 3: 高度な機能 (4時間)

### Task 3.1: 音声前処理機能
- [ ] 音声フォーマット変換
- [ ] ノイズ除去（基本）
- [ ] 音質分析
- [ ] 音声品質警告

**実装ファイル:**
- `Infrastructure/Services/AudioProcessor.swift`

**詳細:**
```swift
class AudioProcessor {
    func convertToWhisperFormat(_ inputURL: URL) async throws -> URL
    func analyzeAudioQuality(_ audioURL: URL) async throws -> AudioQualityMetrics
    func reduceNoise(_ inputURL: URL, level: NoiseReductionLevel) async throws -> URL
}
```

**受け入れ条件:**
- [ ] 音声がWhisper用フォーマットに変換される
- [ ] 音質が分析・警告される
- [ ] 基本的なノイズ除去が動作

### Task 3.2: 文字起こし後処理
- [ ] 句読点自動挿入
- [ ] 段落分け
- [ ] 明らかな誤認識修正
- [ ] 専門用語辞書（基本）

**実装ファイル:**
- `Infrastructure/Services/TextPostProcessor.swift`

**詳細:**
```swift
class TextPostProcessor {
    func insertPunctuation(_ text: String, language: String) -> String
    func addParagraphBreaks(_ text: String, segments: [TranscriptionSegment]) -> String
    func applyCustomDictionary(_ text: String, dictionary: [String: String]) -> String
}
```

**受け入れ条件:**
- [ ] 句読点が適切に挿入される
- [ ] 読みやすい形式に整形される
- [ ] カスタム辞書が適用される

### Task 3.3: 一括処理機能
- [ ] 複数録音の一括文字起こし
- [ ] 処理キュー管理
- [ ] バックグラウンド処理
- [ ] 完了通知

**実装ファイル:**
- `Domain/UseCases/BatchTranscriptionUseCase.swift`

**詳細:**
```swift
class BatchTranscriptionUseCase {
    func processBatch(_ recordings: [Recording], options: TranscriptionOptions) async throws -> [TranscriptionResult]
    func addToQueue(_ recordings: [Recording], priority: TranscriptionPriority)
    func cancelBatch(_ batchId: UUID)
}
```

**受け入れ条件:**
- [ ] 複数録音を一括処理できる
- [ ] キューが適切に管理される
- [ ] バックグラウンド処理が継続される

## Phase 4: 話者分離機能（Pro版） (2時間)

### Task 4.1: Speaker Diarization基盤
- [ ] 音声特徴抽出
- [ ] 話者変化点検出
- [ ] 基本的な話者分離
- [ ] 話者ラベリング

**実装ファイル:**
- `Infrastructure/Services/SpeakerDiarizationService.swift`
- `Domain/Entities/Speaker.swift`

**詳細:**
```swift
class SpeakerDiarizationService {
    func performSpeakerDiarization(audioURL: URL, transcriptionResult: TranscriptionResult) async throws -> TranscriptionResult
    func detectSpeakerChanges(_ audioFeatures: AudioFeatures) async throws -> [SpeakerSegment]
    func identifySpeakers(_ segments: [SpeakerSegment]) async throws -> [UUID: Speaker]
}
```

**受け入れ条件:**
- [ ] 複数話者が識別される
- [ ] 話者ごとの発言が分離される
- [ ] 統計情報が生成される

### Task 4.2: Speaker Profile管理
- [ ] 話者プロファイル作成
- [ ] 音声特徴学習
- [ ] 話者照合機能
- [ ] プライバシー設定

**実装ファイル:**
- `Infrastructure/Services/VoiceProfileManager.swift`

**詳細:**
```swift
class VoiceProfileManager {
    func createSpeakerProfile(from audioSegment: AudioSegment) async throws -> Speaker
    func findSimilarSpeaker(_ voiceEmbedding: VoiceEmbedding) async throws -> Speaker?
    func updateSpeakerProfile(_ speaker: Speaker, with newSample: AudioSegment) async throws
}
```

**受け入れ条件:**
- [ ] 話者プロファイルが作成される
- [ ] 同一話者の認識精度が向上する
- [ ] プライバシー設定が動作する

## Phase 5: 統合・最適化 (2時間)

### Task 5.1: パフォーマンス最適化
- [ ] メモリ使用量最適化
- [ ] 処理速度向上
- [ ] バッテリー消費削減
- [ ] ストレージ効率化

**最適化項目:**
```swift
class TranscriptionOptimizer {
    func optimizeMemoryUsage() async
    func optimizeProcessingSpeed(for deviceCapability: DeviceCapability) async
    func manageBatteryConsumption(level: BatteryLevel) async
}
```

**受け入れ条件:**
- [ ] メモリ使用量が500MB以下
- [ ] 処理速度が要件を満たす
- [ ] バッテリー消費が適切

### Task 5.2: エラーハンドリング強化
- [ ] 包括的エラー処理
- [ ] 復旧機能
- [ ] ログ記録
- [ ] ユーザーフレンドリーなメッセージ

**実装詳細:**
```swift
enum TranscriptionError: LocalizedError {
    case modelNotLoaded
    case audioProcessingFailed
    case transcriptionFailed(String)
    case insufficientStorage(required: Int64, available: Int64)
    
    var errorDescription: String? {
        // 分かりやすいエラーメッセージ
    }
    
    var recoverySuggestion: String? {
        // 復旧方法の提案
    }
}
```

**受け入れ条件:**
- [ ] 全エラーケースが適切に処理される
- [ ] ユーザーに分かりやすいメッセージ
- [ ] 可能な場合は自動復旧

### Task 5.3: 統合テスト実装
- [ ] 文字起こしフロー全体のテスト
- [ ] パフォーマンステスト
- [ ] エラーケーステスト
- [ ] UI統合テスト

**テストファイル:**
- `NoteAIPlusTests/TranscriptionIntegrationTests.swift`

**テスト項目:**
```swift
func testCompleteTranscriptionFlow() async throws {
    // 録音 → 文字起こし → 保存 → 表示
}

func testModelSwitching() async throws {
    // モデル切り替えテスト
}

func testBatchProcessing() async throws {
    // 一括処理テスト
}

func testSpeakerDiarization() async throws {
    // 話者分離テスト（Pro版）
}
```

**受け入れ条件:**
- [ ] 全機能が統合された状態で動作
- [ ] パフォーマンス要件を満たす
- [ ] エラー処理が適切

## 最終検証 (2時間)

### Task 6.1: 品質検証
- [ ] 認識精度測定
- [ ] 処理速度測定
- [ ] メモリ・CPU使用量測定
- [ ] バッテリー消費測定

**検証項目:**
- 日本語認識精度 > 95%（Baseモデル）
- 1分音声の処理時間 < 30秒
- メモリ使用量 < 500MB
- バッテリー消費が適切な範囲

### Task 6.2: ユーザビリティテスト
- [ ] UI操作の直感性
- [ ] エラー時の対応
- [ ] アクセシビリティ
- [ ] 多言語対応

**テスト項目:**
- 3タップ以内で文字起こし開始
- エラー時の適切なガイダンス
- VoiceOver対応
- 言語自動検出の精度

### Task 6.3: ドキュメント更新
- [ ] API仕様書更新
- [ ] 使用方法ガイド
- [ ] トラブルシューティング
- [ ] パフォーマンス調整ガイド

## 依存関係・制約

### 外部依存
- **WhisperKit**: v0.5.0以上
- **モデルファイル**: インターネット接続でのダウンロード
- **デバイス性能**: iOS 16.0以上、十分なメモリ

### 内部依存
- [x] Phase 1録音機能（完了）
- [ ] Core Dataスキーマ拡張
- [ ] RecordingUseCaseとの連携

## リスク・対策

### 技術リスク
- **WhisperKit互換性**: バージョン依存問題
- **メモリ制限**: 大容量モデルでのクラッシュ
- **処理時間**: 長時間音声での性能劣化

### 対策
- 段階的実装とテスト
- メモリ監視・最適化
- チャンク処理による分割

## 完了定義

全タスクが完了し、以下の条件を満たした時点で文字起こし機能の実装完了とする：

1. **機能要件**: 全ての基本機能が動作
2. **品質要件**: 認識精度・性能基準をクリア
3. **統合性**: 録音機能との完全統合
4. **テスト**: 全テストケースが通過
5. **ドキュメント**: 仕様書・ガイドが整備

このタスク計画により、高品質な文字起こし機能を段階的に構築し、ユーザーに優れた体験を提供します。