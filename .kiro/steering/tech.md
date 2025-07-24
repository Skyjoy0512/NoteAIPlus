# NoteAI Plus - Technology Stack

## 開発環境

### 基本環境
- **Xcode**: 15.0以上
- **Swift**: 5.9以上
- **最小対応OS**: iOS 16.0
- **Claude Code**: メイン開発ツール
- **Git**: バージョン管理

### セットアップコマンド
```bash
# プロジェクト初期化
xcodegen generate

# SwiftLint インストール
brew install swiftlint

# 依存関係更新
xcodebuild -resolvePackageDependencies

# ビルド実行
xcodebuild -scheme NoteAIPlus -configuration Debug build

# テスト実行
xcodebuild -scheme NoteAIPlus -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' test
```

## アーキテクチャ

### 設計パターン
- **Architecture**: Clean Architecture + MVVM
- **UI Framework**: SwiftUI
- **Dependency Injection**: Protocol-based DI
- **データフロー**: Combine + async/await

### レイヤー構成
```
Presentation Layer (SwiftUI Views + ViewModels)
    ↓
Domain Layer (Use Cases + Entities + Repository Protocols)
    ↓
Data Layer (Repository Implementations + Data Sources)
    ↓
Infrastructure Layer (Services + Extensions + Utilities)
```

## 技術スタック

### コアフレームワーク
- **UIフレームワーク**: SwiftUI
- **状態管理**: Combine + @StateObject/@ObservableObject  
- **ナビゲーション**: NavigationStack
- **非同期処理**: async/await + Task

### 外部依存関係
```swift
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
```

## AI/ML技術

### 文字起こし
- **エンジン**: WhisperKit (OpenAI Whisper on-device)
- **モデル**: tiny (39MB) / base (74MB) / small (244MB)
- **言語**: 多言語対応（日本語・英語メイン）
- **処理**: 完全ローカル、オフライン対応

### LLM統合
- **ローカルLLM**: iOS対応軽量モデル（無料版）
- **外部API**: OpenAI/Gemini/Claude（有料版）
- **プロンプト管理**: テンプレート化、バージョン管理

### RAG（検索拡張生成）
- **埋め込み**: ローカル埋め込みモデル
- **ベクトル検索**: SQLiteベースの軽量実装
- **チャンキング**: 512トークン、50トークンオーバーラップ

## データ管理

### ローカルストレージ
- **メインDB**: Core Data
- **検索DB**: GRDB.swift（全文検索用）
- **ファイル**: DocumentsDirectoryでの構造化管理
- **キャッシュ**: NSCache + URLCache

### Core Data設計
```swift
// 主要エンティティ
- Recording: 録音データ
- Document: インポートドキュメント  
- VectorEmbedding: RAG用ベクトルデータ
- Speaker:話者情報
- Summary: AI要約結果
- Tag: タグ・ラベル
```

### クラウド同期（Pro版）
- **ストレージ**: Firebase Cloud Storage
- **認証**: Firebase Authentication
- **同期戦略**: 差分同期、コンフリクト解決

## セキュリティ

### APIキー管理
- **保存**: Keychain Services
- **暗号化**: iOS標準暗号化
- **スコープ**: アプリ単位での分離

### データ保護
- **ローカル**: App Sandbox内での完全分離
- **通信**: TLS 1.3、証明書ピンニング
- **バックアップ**: 暗号化、選択的除外

## パフォーマンス

### 最適化戦略
- **メモリ**: モデル遅延ロード、適切な解放
- **ストレージ**: 音声ファイル圧縮、古いファイル自動削除
- **CPU**: バックグラウンド処理、優先度制御
- **バッテリー**: 処理優先度調整、不要処理停止

### モニタリング
- **メトリクス**: MetricKit使用
- **クラッシュ**: Firebase Crashlytics
- **パフォーマンス**: Instruments統合

## 開発ツール

### 品質管理
```bash
# リント実行
swiftlint

# フォーマット
swiftformat .

# テストカバレッジ
xcodebuild -scheme NoteAIPlus -enableCodeCoverage YES test

# 静的解析
xcodebuild analyze
```

### CI/CD（将来）
- **Xcode Cloud**: 自動ビルド・テスト
- **TestFlight**: ベータ配信
- **GitHub Actions**: カスタムワークフロー

## 開発ポート・URL

### ローカル開発
- **Simulator**: iOS 16.0+ simulators
- **デバイス**: 開発者登録済みiOSデバイス
- **ログ**: Console.app、Xcode Debugger

### 外部サービス
- **Firebase Console**: https://console.firebase.google.com
- **App Store Connect**: https://appstoreconnect.apple.com
- **RevenueCat Dashboard**: https://app.revenuecat.com

## プロダクション環境

### App Store配信
- **プロビジョニング**: App Store Distribution
- **コード署名**: Distribution Certificate
- **メタデータ**: App Store Connect

### 運用コスト最適化
- **無料版**: 完全ローカル処理（運用コスト0円）
- **Basic版**: ユーザーAPIキー（運用コスト0円）
- **Pro版**: 従量課金API（利用量ベース）

### 想定負荷
```
ユーザー数    月額コスト    月額収益    利益
100人        6,250円      30,000円    23,750円
1,000人      80,000円     450,000円   370,000円
```