import Foundation
import Combine

protocol UserRepositoryProtocol {
    // User authentication
    func getCurrentUser() async throws -> User?
    func signIn(email: String, password: String) async throws -> User
    func signUp(email: String, password: String, displayName: String) async throws -> User
    func signOut() async throws
    func deleteAccount() async throws
    
    // User profile
    func updateProfile(_ user: User) async throws
    func updateDisplayName(_ name: String) async throws
    func updateEmail(_ email: String) async throws
    func changePassword(currentPassword: String, newPassword: String) async throws
    
    // User preferences
    func getPreferences() async throws -> UserPreferences
    func updatePreferences(_ preferences: UserPreferences) async throws
    
    // Subscription management
    func getSubscriptionStatus() async throws -> SubscriptionStatus
    func updateSubscription(_ status: SubscriptionStatus) async throws
    func getUsageStatistics() async throws -> UsageStatistics
    
    // API key management
    func saveAPIKey(_ key: String, for provider: APIProvider) async throws
    func getAPIKey(for provider: APIProvider) async throws -> String?
    func deleteAPIKey(for provider: APIProvider) async throws
    func getAllAPIKeys() async throws -> [APIProvider: String]
    
    // Reactive operations
    var userPublisher: AnyPublisher<User?, Never> { get }
    var subscriptionStatusPublisher: AnyPublisher<SubscriptionStatus, Never> { get }
    var preferencesPublisher: AnyPublisher<UserPreferences, Never> { get }
    
    // Cloud sync
    func enableCloudSync() async throws
    func disableCloudSync() async throws
    func syncToCloud() async throws
    func syncFromCloud() async throws
    func getCloudSyncStatus() async throws -> CloudSyncStatus
}

// MARK: - User Entity
struct User: Identifiable, Codable, Equatable {
    let id: UUID
    let email: String
    var displayName: String
    let createdAt: Date
    var updatedAt: Date
    var isEmailVerified: Bool
    var lastLoginAt: Date?
    
    init(
        id: UUID = UUID(),
        email: String,
        displayName: String,
        isEmailVerified: Bool = false
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isEmailVerified = isEmailVerified
        self.lastLoginAt = nil
    }
    
    mutating func updateLastLogin() {
        self.lastLoginAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - User Preferences
struct UserPreferences: Codable, Equatable {
    var defaultWhisperModel: String
    var defaultLanguage: String
    var autoTranscribe: Bool
    var enableSpeakerSeparation: Bool
    var audioQuality: AudioQuality
    var autoSummary: Bool
    var defaultSummaryType: Summary.SummaryType
    var notificationsEnabled: Bool
    var darkModeEnabled: Bool
    var autoBackup: Bool
    var maxStorageUsage: Int64
    var deleteAfterDays: Int?
    
    init() {
        self.defaultWhisperModel = "base"
        self.defaultLanguage = "ja"
        self.autoTranscribe = true
        self.enableSpeakerSeparation = false
        self.audioQuality = .high
        self.autoSummary = false
        self.defaultSummaryType = .brief
        self.notificationsEnabled = true
        self.darkModeEnabled = false
        self.autoBackup = false
        self.maxStorageUsage = 5_000_000_000 // 5GB
        self.deleteAfterDays = nil
    }
    
    enum AudioQuality: String, Codable, CaseIterable {
        case low = "低音質"
        case medium = "中音質"
        case high = "高音質"
        
        var bitRate: Int {
            switch self {
            case .low: return 64000
            case .medium: return 128000
            case .high: return 256000
            }
        }
    }
}

// MARK: - Subscription Status
enum SubscriptionStatus: String, Codable, CaseIterable {
    case free = "Free"
    case basic = "Basic"
    case pro = "Pro"
    
    var displayName: String {
        switch self {
        case .free: return "無料プラン"
        case .basic: return "Basicプラン"
        case .pro: return "Proプラン"
        }
    }
    
    var monthlyPrice: Int {
        switch self {
        case .free: return 0
        case .basic: return 500
        case .pro: return 1500
        }
    }
    
    var features: [String] {
        switch self {
        case .free:
            return ["録音機能無制限", "ローカル文字起こし(月10時間)", "基本要約"]
        case .basic:
            return ["広告非表示", "ローカル文字起こし無制限", "ユーザーAPIキー利用", "基本RAG機能"]
        case .pro:
            return ["Basicの全機能", "当社API利用果", "クラウドバックアップ", "Limitless連携", "話者分離"]
        }
    }
}

// MARK: - API Provider
enum APIProvider: String, Codable, CaseIterable {
    case openAI = "openai"
    case googleGemini = "gemini"
    case anthropic = "claude"
    case whisperAPI = "whisper"
    
    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .googleGemini: return "Google Gemini"
        case .anthropic: return "Anthropic Claude"
        case .whisperAPI: return "Whisper API"
        }
    }
}

// MARK: - Usage Statistics
struct UsageStatistics: Codable, Equatable {
    let recordingHours: Double
    let transcriptionHours: Double
    let apiCallsCount: Int
    let storageUsedBytes: Int64
    let period: StatsPeriod
    let updatedAt: Date
    
    enum StatsPeriod: String, Codable {
        case monthly = "monthly"
        case yearly = "yearly"
        case lifetime = "lifetime"
    }
}

// MARK: - Cloud Sync Status
struct CloudSyncStatus: Codable, Equatable {
    let isEnabled: Bool
    let lastSyncDate: Date?
    let pendingItemsCount: Int
    let syncInProgress: Bool
    let lastError: String?
}