# NoteAI Plus - Project Structure

## ディレクトリ構造

```
NoteAIPlus/
├── NoteAIPlus.xcodeproj          # Xcodeプロジェクトファイル
├── Package.swift                 # Swift Package Manager設定
├── NoteAIPlus/                   # メインアプリターゲット
│   ├── App/                      # アプリケーション層
│   │   ├── NoteAIPlusApp.swift   # アプリエントリーポイント
│   │   └── Info.plist            # アプリ設定
│   ├── Presentation/             # プレゼンテーション層
│   │   ├── Views/                # SwiftUI Views
│   │   │   ├── Home/             # ホーム画面
│   │   │   ├── Recording/        # 録音画面
│   │   │   ├── Detail/           # 詳細画面
│   │   │   ├── Settings/         # 設定画面
│   │   │   └── Common/           # 共通UI部品
│   │   ├── ViewModels/           # ViewModels (MVVM)
│   │   │   ├── HomeViewModel.swift
│   │   │   ├── RecordingViewModel.swift
│   │   │   └── SettingsViewModel.swift
│   │   └── Components/           # 再利用可能コンポーネント
│   │       ├── WaveformView.swift
│   │       ├── RecordButton.swift
│   │       └── AudioPlayerView.swift
│   ├── Domain/                   # ドメイン層 (Clean Architecture)
│   │   ├── Entities/             # エンティティ・ドメインオブジェクト
│   │   │   ├── Recording.swift
│   │   │   ├── Document.swift
│   │   │   ├── Speaker.swift
│   │   │   └── Summary.swift
│   │   ├── UseCases/             # ユースケース・ビジネスロジック
│   │   │   ├── RecordingUseCase.swift
│   │   │   ├── TranscriptionUseCase.swift
│   │   │   └── RAGUseCase.swift
│   │   └── Repositories/         # リポジトリプロトコル
│   │       ├── RecordingRepositoryProtocol.swift
│   │       ├── DocumentRepositoryProtocol.swift
│   │       └── UserRepositoryProtocol.swift
│   ├── Data/                     # データ層
│   │   ├── Repositories/         # リポジトリ実装
│   │   │   ├── RecordingRepository.swift
│   │   │   ├── DocumentRepository.swift
│   │   │   └── UserRepository.swift
│   │   ├── DataSources/          # データソース
│   │   │   ├── Local/            # ローカルデータソース
│   │   │   │   ├── CoreDataManager.swift
│   │   │   │   └── GRDBManager.swift
│   │   │   └── Remote/           # リモートデータソース
│   │   │       ├── FirebaseService.swift
│   │   │       └── APIClient.swift
│   │   └── Models/               # データモデル
│   │       ├── RecordingEntity+CoreDataClass.swift
│   │       ├── DocumentEntity+CoreDataClass.swift
│   │       └── DataModel.xcdatamodeld
│   ├── Infrastructure/           # インフラストラクチャ層
│   │   ├── Services/             # 外部サービス
│   │   │   ├── AudioRecordingService.swift
│   │   │   ├── TranscriptionService.swift
│   │   │   ├── RAGService.swift
│   │   │   ├── APIKeyManager.swift
│   │   │   └── LLMService.swift
│   │   ├── Extensions/           # Swift拡張
│   │   │   ├── String+Extensions.swift
│   │   │   ├── Date+Extensions.swift
│   │   │   └── URL+Extensions.swift
│   │   └── Utilities/            # ユーティリティ
│   │       ├── Logger.swift
│   │       ├── Constants.swift
│   │       └── Helpers.swift
│   └── Resources/                # リソースファイル
│       ├── Assets.xcassets       # 画像・色・アイコン
│       ├── Localizable.strings   # 多言語対応
│       └── LaunchScreen.storyboard
├── NoteAIPlusTests/              # ユニットテスト
│   ├── UseCaseTests/
│   ├── ViewModelTests/
│   └── ServiceTests/
├── NoteAIPlusUITests/            # UIテスト
└── NoteAIPlusWidget/             # ウィジェット拡張（将来）
```

## Clean Architecture設計原則

### 依存関係ルール
```
Presentation → Domain ← Data ← Infrastructure
```

- **Presentation**: UIロジック、ViewModelがDomainに依存
- **Domain**: ビジネスロジック、他層に依存しない
- **Data**: データ永続化、Domainのプロトコルを実装
- **Infrastructure**: 外部サービス、Domainのプロトコルを実装

### プロトコル設計
```swift
// Domain層でプロトコル定義
protocol RecordingRepositoryProtocol {
    func save(_ recording: Recording) async throws
    func findAll() async throws -> [Recording]
    func delete(id: UUID) async throws
}

// Data層で実装
class RecordingRepository: RecordingRepositoryProtocol {
    // 実装詳細
}
```

## コーディング規約

### Swift Style Guide
- **Apple Swift API Design Guidelines**準拠
- **SwiftLint**設定適用
- **4スペース**インデント使用

### 命名規則
```swift
// ファイル名: PascalCase
RecordingService.swift
AudioPlayerView.swift

// クラス・構造体: PascalCase
class AudioRecordingService {}
struct RecordingSession {}

// プロパティ・関数: camelCase
var isRecording: Bool
func startRecording() async throws

// 定数: UPPER_SNAKE_CASE
static let MAX_RECORDING_DURATION = 3600.0

// プロトコル名: Protocol suffix
protocol AudioServiceProtocol {}
```

### 非同期処理パターン
```swift
// async/await優先
func transcribeAudio(url: URL) async throws -> String {
    let result = try await whisperService.transcribe(url)
    return result.text
}

// Combine for UI state
@Published var recordings: [Recording] = []
var recordingsPublisher: AnyPublisher<[Recording], Never> {
    $recordings.eraseToAnyPublisher()
}
```

## テストアーキテクチャ

### テスト構造
```
NoteAIPlusTests/
├── Mocks/                    # モックオブジェクト
│   ├── MockAudioService.swift
│   └── MockRepository.swift
├── UseCaseTests/             # ビジネスロジックテスト
├── ViewModelTests/           # ViewModelテスト
├── ServiceTests/             # サービステスト
└── Helpers/                  # テストヘルパー
    └── TestConstants.swift
```

### テストパターン
```swift
// Given-When-Then パターン
func testStartRecording() async throws {
    // Given
    let mockService = MockAudioRecordingService()
    let useCase = RecordingUseCase(audioService: mockService)
    
    // When
    let session = try await useCase.startRecording()
    
    // Then
    XCTAssertNotNil(session)
    XCTAssertTrue(mockService.startRecordingCalled)
}
```

## SwiftUI設計パターン

### View構造
```swift
struct RecordingView: View {
    @StateObject private var viewModel = RecordingViewModel()
    
    var body: some View {
        NavigationStack {
            VStack {
                // UI Components
            }
            .navigationTitle("録音")
        }
    }
}
```

### 状態管理
```swift
// ViewModelでの状態管理
@Published var recordingState: RecordingState = .idle
@Published var recordings: [Recording] = []
@Published var isLoading = false
```

## 依存関係注入

### プロトコルベースDI
```swift
// プロトコル定義
protocol AudioRecordingServiceProtocol {
    func startRecording() async throws
}

// ViewModel初期化時注入
class RecordingViewModel: ObservableObject {
    private let audioService: AudioRecordingServiceProtocol
    
    init(audioService: AudioRecordingServiceProtocol = AudioRecordingService()) {
        self.audioService = audioService
    }
}
```

## エラーハンドリング

### カスタムエラー定義
```swift
enum RecordingError: LocalizedError {
    case permissionDenied
    case deviceNotAvailable
    case fileSaveFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "マイクへのアクセス許可が必要です"
        case .deviceNotAvailable:
            return "録音デバイスが利用できません"
        case .fileSaveFailed:
            return "録音ファイルの保存に失敗しました"
        }
    }
}
```

## リソース管理

### Assets構造
```
Assets.xcassets/
├── AppIcon.appiconset/          # アプリアイコン
├── Colors/                      # カラーパレット
│   ├── Primary.colorset
│   ├── Secondary.colorset
│   └── Background.colorset
├── Icons/                       # システムアイコン
│   ├── record.imageset
│   └── pause.imageset
└── Images/                      # 画像リソース
    └── onboarding/
```

### 多言語対応
```
Localizable.strings (ja)
"recording.start" = "録音開始";
"recording.stop" = "録音停止";

Localizable.strings (en)
"recording.start" = "Start Recording";
"recording.stop" = "Stop Recording";
```

## ビルド設定

### Build Configurations
- **Debug**: 開発用、デバッグシンボル有効
- **Release**: 本番用、最適化有効

### Info.plist設定
```xml
<key>NSMicrophoneUsageDescription</key>
<string>録音機能のためにマイクのアクセス許可が必要です</string>

<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```