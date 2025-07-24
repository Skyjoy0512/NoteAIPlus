# NoteAI Plus 開発要件定義書（Claude Code版）

## 1. プロジェクト概要

### 1.1 基本情報
- **プロジェクト名**: NoteAI Plus
- **プラットフォーム**: iOS (iPhone専用、将来的にiPad対応)
- **開発言語**: Swift 5.9+
- **最小対応OS**: iOS 16.0
- **開発ツール**: Xcode 15.0+, Claude Code
- **アーキテクチャ**: MVVM + Clean Architecture

### 1.2 プロジェクト構造
```
NoteAIPlus/
├── NoteAIPlus.xcodeproj
├── NoteAIPlus/
│   ├── App/
│   │   ├── NoteAIPlusApp.swift
│   │   └── Info.plist
│   ├── Presentation/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Components/
│   ├── Domain/
│   │   ├── Entities/
│   │   ├── UseCases/
│   │   └── Repositories/
│   ├── Data/
│   │   ├── Repositories/
│   │   ├── DataSources/
│   │   └── Models/
│   ├── Infrastructure/
│   │   ├── Services/
│   │   ├── Extensions/
│   │   └── Utilities/
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Localizable.strings
│       └── LaunchScreen.storyboard
├── NoteAIPlusTests/
├── NoteAIPlusUITests/
└── README.md
```

## 2. 開発環境セットアップ

### 2.1 必要なツール
```bash
# Xcodeプロジェクト作成
xcodegen generate

# SwiftLint設定
brew install swiftlint

# Swift Package Manager dependencies
```

### 2.2 Package.swift
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NoteAIPlus",
    platforms: [
        .iOS(.v16)
    ],
    dependencies: [
        // AI/ML
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.5.0"),
        
        // ネットワーク
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.8.0"),
        
        // データベース
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),
        
        // UI
        .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI", from: "2.2.0"),
        
        // 課金
        .package(url: "https://github.com/RevenueCat/purchases-ios", from: "4.0.0"),
        
        // Firebase
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0"),
        
        // Markdown
        .package(url: "https://github.com/johnxnguyen/Down", from: "0.11.0")
    ]
)
```

## 3. 機能要件

### 3.1 録音機能
- **基本録音機能**
  - バックグラウンド録音対応
  - 録音の一時停止・再開
  - 録音時間の表示
  - 音声レベルインジケーター
  - 音質設定（高/中/低）
  - ファイル形式選択（m4a/wav）

- **ウィジェット対応**
  - ホーム画面ウィジェットからワンタップで録音開始
  - 録音状態の表示（録音中/停止中）
  - 直近の録音へのクイックアクセス

### 3.2 文字起こし機能
- **ローカル処理**
  - WhisperKitによるオンデバイス文字起こし
  - モデルサイズ選択（tiny/base/small）
  - 多言語対応（日本語、英語を含む）
  - オフライン対応

- **話者分離機能（Pro版のみ）**
  - 自動話者識別
  - 話者ごとの発言時間統計
  - 話者名の手動ラベリング

### 3.3 AI機能
- **ローカルLLM（無料版）**
  - iOS向け軽量モデル
  - 基本的な要約・質問応答
  - オフライン動作

- **外部API連携（Basic/Pro版）**
  - ユーザー自身のAPIキー設定（Basic版）
  - 当社提供のAPI（Pro版）
  - 対応プロバイダー：
    - Google Gemini API
    - OpenAI API
    - Anthropic Claude API

### 3.4 RAG（Retrieval-Augmented Generation）
- **ドキュメントインポート**
  - PDF、Word、テキストファイル対応
  - Webページの取り込み
  - 画像ファイル（OCR処理）

- **統合検索**
  - 録音データとドキュメントの横断検索
  - AIによる関連性分析
  - ソース引用付き回答

### 3.5 外部連携
- **Limitless API統合（Pro版）**
  - Pendantデバイスとの連携
  - 録音データの自動同期
  - メタデータの統合

### 3.6 データ管理
- **ローカルストレージ**
  - Core Dataによるデータ管理
  - 効率的なファイル管理
  - 自動バックアップ

- **クラウド同期（Pro版）**
  - Firebase Cloud Storage
  - 複数デバイス間での同期

## 4. 料金プラン

### 4.1 無料プラン（Free）
- 録音機能（無制限）
- ローカル文字起こし（月10時間まで）
- 基本的な要約（ローカルLLM）
- 広告表示あり

### 4.2 Basicプラン（月額500円）
- 広告非表示
- ローカル文字起こし無制限
- ユーザー自身のAPIキー利用
- 基本的なRAG機能
- ドキュメントインポート（月50ファイル）

### 4.3 Proプラン（月額1,500円）
- Basicの全機能
- 当社提供のAPI利用枠
  - 文字起こし: 月20時間
  - LLM: 月100万トークン
- クラウドバックアップ（5GB）
- Limitless連携
- 話者分離機能
- 無制限ドキュメントインポート

## 5. 技術仕様

### 5.1 コア機能実装

#### 録音サービス
```swift
// Infrastructure/Services/AudioRecordingService.swift
import AVFoundation
import Combine

protocol AudioRecordingServiceProtocol {
    func startRecording() async throws -> URL
    func stopRecording() async throws -> RecordingResult
    func pauseRecording() throws
    func resumeRecording() throws
    var audioLevels: AnyPublisher<Float, Never> { get }
    var recordingTime: AnyPublisher<TimeInterval, Never> { get }
}

class AudioRecordingService: NSObject, AudioRecordingServiceProtocol {
    private var audioEngine: AVAudioEngine
    private var audioFile: AVAudioFile?
    private let audioLevelsSubject = PassthroughSubject<Float, Never>()
    private let recordingTimeSubject = CurrentValueSubject<TimeInterval, Never>(0)
    
    // バックグラウンド録音設定
    func configureBackgroundRecording() async throws {
        let session = AVAudioSession.sharedInstance()
        try await session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
        try await session.setActive(true)
    }
}
```

#### 文字起こしサービス
```swift
// Infrastructure/Services/TranscriptionService.swift
import WhisperKit

protocol TranscriptionServiceProtocol {
    func transcribe(audioURL: URL, model: WhisperModel) async throws -> TranscriptionResult
    func cancelTranscription()
    var progress: AnyPublisher<Float, Never> { get }
}

class TranscriptionService: TranscriptionServiceProtocol {
    private var whisperKit: WhisperKit?
    private let progressSubject = PassthroughSubject<Float, Never>()
    
    enum WhisperModel: String, CaseIterable {
        case tiny = "tiny"
        case base = "base"
        case small = "small"
        
        var displayName: String {
            switch self {
            case .tiny: return "Tiny (39M) - 最速"
            case .base: return "Base (74M) - バランス"
            case .small: return "Small (244M) - 高精度"
            }
        }
    }
    
    func initialize(model: WhisperModel) async throws {
        whisperKit = try await WhisperKit(model: model.rawValue)
    }
}
```

#### RAGサービス
```swift
// Infrastructure/Services/RAGService.swift
import CoreML
import SQLite3

protocol RAGServiceProtocol {
    func indexDocument(_ document: Document) async throws
    func search(query: String, limit: Int) async throws -> [SearchResult]
    func deleteIndex(for documentId: String) async throws
}

class RAGService: RAGServiceProtocol {
    private let embeddingService: EmbeddingServiceProtocol
    private let vectorStore: VectorStoreProtocol
    
    // チャンキング設定
    struct ChunkingConfig {
        let maxTokens: Int = 512
        let overlap: Int = 50
        let minChunkSize: Int = 100
    }
    
    func indexDocument(_ document: Document) async throws {
        // 1. テキスト抽出
        let text = try await extractText(from: document)
        
        // 2. チャンキング
        let chunks = chunkText(text, config: ChunkingConfig())
        
        // 3. エンベディング生成
        let embeddings = try await embeddingService.generateEmbeddings(for: chunks)
        
        // 4. ベクトルストアに保存
        try await vectorStore.store(
            embeddings: embeddings,
            metadata: chunks.enumerated().map { index, chunk in
                VectorMetadata(
                    documentId: document.id,
                    chunkIndex: index,
                    text: chunk,
                    source: document.source
                )
            }
        )
    }
}
```

### 5.2 データモデル

#### Core Dataエンティティ
```swift
// Recording Entity
entity Recording {
    id: UUID
    title: String
    date: Date
    duration: Double
    audioFileURL: String
    transcription: String?
    whisperModel: String
    language: String
    isFromLimitless: Bool
    createdAt: Date
    updatedAt: Date
    
    // Relationships
    speakers: [Speaker]
    summaries: [Summary]
    tags: [Tag]
}

// Document Entity
entity Document {
    id: UUID
    type: String // pdf, word, text, web
    title: String
    content: String
    originalURL: String?
    fileSize: Int64
    createdAt: Date
    
    // Relationships
    embeddings: [VectorEmbedding]
    highlights: [Highlight]
}

// VectorEmbedding Entity
entity VectorEmbedding {
    id: UUID
    sourceType: String
    sourceId: UUID
    chunkText: String
    vector: Data // シリアライズされたFloat配列
    metadata: Data // JSON
    createdAt: Date
}
```

### 5.3 APIキー管理
```swift
// Infrastructure/Services/APIKeyManager.swift
import Security

class APIKeyManager {
    enum APIProvider: String, CaseIterable {
        case openAI = "openai_api_key"
        case googleGemini = "gemini_api_key"
        case anthropic = "claude_api_key"
        case whisperAPI = "whisper_api_key"
        
        var displayName: String {
            switch self {
            case .openAI: return "OpenAI"
            case .googleGemini: return "Google Gemini"
            case .anthropic: return "Anthropic Claude"
            case .whisperAPI: return "Whisper API"
            }
        }
    }
    
    // Keychainへの安全な保存
    func saveAPIKey(_ key: String, for provider: APIProvider) throws {
        let data = key.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: provider.rawValue,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw APIKeyError.saveFailed
        }
    }
}
```

## 6. UI/UX設計

### 6.1 画面構成
1. **ホーム画面**
   - 録音一覧（グリッド表示）
   - 検索・フィルター機能
   - クイックアクション

2. **録音画面**
   - 大きな録音ボタン
   - 波形表示
   - 録音設定

3. **詳細画面**
   - 音声プレイヤー
   - 文字起こしテキスト
   - AI機能アクセス

4. **マイページ**
   - プロフィール
   - サブスクリプション管理
   - 設定

### 6.2 SwiftUI実装例
```swift
// Presentation/Views/Recording/RecordingView.swift
struct RecordingView: View {
    @StateObject private var viewModel = RecordingViewModel()
    @State private var isRecording = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                // 波形表示
                WaveformView(audioLevels: viewModel.audioLevels)
                    .frame(height: 120)
                    .padding(.horizontal)
                
                // 録音時間
                Text(viewModel.formattedTime)
                    .font(.system(size: 48, weight: .light, design: .monospaced))
                    .foregroundColor(.primary)
                
                // 録音ボタン
                RecordButton(isRecording: $isRecording) {
                    Task {
                        if isRecording {
                            try await viewModel.stopRecording()
                        } else {
                            try await viewModel.startRecording()
                        }
                    }
                }
                .frame(width: 100, height: 100)
                
                // 設定
                HStack(spacing: 40) {
                    Button(action: { viewModel.showingSettings = true }) {
                        Image(systemName: "gear")
                            .font(.title2)
                    }
                    
                    Button(action: { viewModel.showingImport = true }) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.title2)
                    }
                }
                .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle("録音")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
```

## 7. 開発フェーズ

### Phase 1: 基盤構築（1週間）
- [ ] Xcodeプロジェクトセットアップ
- [ ] アーキテクチャ基盤実装
- [ ] Core Dataスキーマ設計
- [ ] 基本的なUI構造
- [ ] 依存関係の追加

### Phase 2: コア機能（2週間）
- [ ] 録音機能実装
- [ ] WhisperKit統合
- [ ] 基本的な文字起こし
- [ ] ファイル管理機能
- [ ] 設定画面

### Phase 3: 高度な機能（2週間）
- [ ] RAGシステム実装
- [ ] LLM連携（ローカル/API）
- [ ] ドキュメントインポート
- [ ] Limitless API連携
- [ ] 課金システム

### Phase 4: 仕上げ（1週間）
- [ ] UI/UXポリッシュ
- [ ] パフォーマンス最適化
- [ ] テスト実装
- [ ] App Store準備

## 8. 運用コスト最適化

### 8.1 コスト削減戦略
1. **ローカル処理優先**
   - 無料版は完全ローカル処理
   - API利用は必要最小限に

2. **ユーザーAPIキー活用**
   - Basic版はユーザー自身のAPIキー
   - 運用コストゼロ

3. **段階的スケーリング**
   - ユーザー数に応じてインフラ拡張
   - 初期は最小構成でスタート

### 8.2 想定コスト
| ユーザー数 | 月額コスト | 月額収益 | 利益 |
|-----------|------------|----------|------|
| 100人 | 6,250円 | 30,000円 | 23,750円 |
| 1,000人 | 80,000円 | 450,000円 | 370,000円 |

## 9. テスト戦略

### 9.1 ユニットテスト
```swift
// NoteAIPlusTests/RecordingUseCaseTests.swift
import XCTest
@testable import NoteAIPlus

class RecordingUseCaseTests: XCTestCase {
    var sut: RecordingUseCase!
    var mockAudioService: MockAudioRecordingService!
    var mockTranscriptionService: MockTranscriptionService!
    var mockRepository: MockRecordingRepository!
    
    override func setUp() {
        super.setUp()
        mockAudioService = MockAudioRecordingService()
        mockTranscriptionService = MockTranscriptionService()
        mockRepository = MockRecordingRepository()
        
        sut = RecordingUseCase(
            audioService: mockAudioService,
            transcriptionService: mockTranscriptionService,
            repository: mockRepository
        )
    }
    
    func testStartRecording() async throws {
        // Given
        let expectedURL = URL(string: "file://recording.m4a")!
        mockAudioService.startRecordingResult = expectedURL
        
        // When
        let session = try await sut.startRecording()
        
        // Then
        XCTAssertEqual(session.audioURL, expectedURL)
        XCTAssertTrue(mockAudioService.startRecordingCalled)
    }
}
```

### 9.2 UIテスト
- 録音フローのE2Eテスト
- 文字起こし結果の確認
- 課金フローのテスト

## 10. リリース準備

### 10.1 App Store対応
- [ ] アプリアイコン作成
- [ ] スクリーンショット準備
- [ ] プライバシーポリシー作成
- [ ] 利用規約作成
- [ ] App Store説明文

### 10.2 マーケティング
- [ ] ランディングページ作成
- [ ] Product Hunt準備
- [ ] SNS告知準備
- [ ] ブログ記事作成

## 11. 今後の拡張計画

### 11.1 短期計画（3-6ヶ月）
- iPad対応
- Apple Watch連携
- より多くのLLMプロバイダー対応

### 11.2 長期計画（6-12ヶ月）
- チーム機能
- Web版開発
- Android版検討
- API公開

## 12. 参考情報

### 12.1 競合アプリ
- Plaud Note
- Limitless AI
- Otter.ai
- Notta

### 12.2 技術リソース
- [WhisperKit Documentation](https://github.com/argmaxinc/WhisperKit)
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Swift Package Manager](https://swift.org/package-manager/)

### 12.3 デザインリソース
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [SF Symbols](https://developer.apple.com/sf-symbols/)

---

この要件定義書は、個人開発者がNoteAI Plusを効率的に開発できるよう、Claude Codeでの実装を前提に作成されています。各フェーズを順次実装し、継続的にアップデートしていくことを推奨します。