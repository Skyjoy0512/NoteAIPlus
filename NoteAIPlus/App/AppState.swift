import SwiftUI
import Combine

class AppState: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isInitialized: Bool = false
    @Published var currentRecording: Recording?
    @Published var selectedRecordingForTranscription: Recording?
    @Published var selectedTab: Int = 0
    
    // Permissions
    @Published var hasMicrophonePermission: Bool = false
    @Published var hasNotificationPermission: Bool = false
    
    // App lifecycle
    @Published var isActive: Bool = true
    @Published var isInBackground: Bool = false
    
    // Error handling
    @Published var currentError: AppError?
    @Published var showingError: Bool = false
    
    // MARK: - Dependencies
    
    private let recordingUseCase: RecordingUseCase
    private let transcriptionUseCase: TranscriptionUseCase
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        recordingUseCase: RecordingUseCase = RecordingUseCase(),
        transcriptionUseCase: TranscriptionUseCase = TranscriptionUseCase()
    ) {
        self.recordingUseCase = recordingUseCase
        self.transcriptionUseCase = transcriptionUseCase
        
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    func initialize() async {
        await checkPermissions()
        await initializeServices()
        
        await MainActor.run {
            self.isInitialized = true
        }
    }
    
    /// 録音完了後の文字起こし開始
    func startTranscriptionForRecording(_ recording: Recording) {
        selectedRecordingForTranscription = recording
        selectedTab = 2 // Switch to transcription tab
    }
    
    /// エラーを表示
    func showError(_ error: Error) {
        let appError: AppError
        
        if let existingError = error as? AppError {
            appError = existingError
        } else {
            appError = AppError.unknown(error.localizedDescription)
        }
        
        currentError = appError
        showingError = true
    }
    
    /// エラーを消去
    func dismissError() {
        currentError = nil
        showingError = false
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe recording completion
        recordingUseCase.$recordings
            .sink { [weak self] recordings in
                // Check if a new recording was added
                if let latestRecording = recordings.first,
                   self?.currentRecording?.id != latestRecording.id {
                    self?.handleNewRecording(latestRecording)
                }
            }
            .store(in: &cancellables)
        
        // Observe app lifecycle
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.isActive = true
                self?.isInBackground = false
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.isActive = false
                self?.isInBackground = true
            }
            .store(in: &cancellables)
    }
    
    private func checkPermissions() async {
        // Check microphone permission
        await MainActor.run {
            self.hasMicrophonePermission = AVAudioSession.sharedInstance().recordPermission == .granted
        }
        
        // Check notification permission
        let notificationCenter = UNUserNotificationCenter.current()
        let settings = await notificationCenter.notificationSettings()
        
        await MainActor.run {
            self.hasNotificationPermission = settings.authorizationStatus == .authorized
        }
    }
    
    private func initializeServices() async {
        do {
            // Initialize recording service
            // Any additional initialization if needed
            
            print("App services initialized successfully")
        } catch {
            await MainActor.run {
                self.showError(AppError.initializationFailed(error.localizedDescription))
            }
        }
    }
    
    private func handleNewRecording(_ recording: Recording) {
        currentRecording = recording
        
        // Show transcription option
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.selectedRecordingForTranscription = recording
        }
    }
}

// MARK: - App Error Types

enum AppError: LocalizedError, Identifiable {
    case initializationFailed(String)
    case permissionDenied(PermissionType)
    case serviceUnavailable(String)
    case networkError(String)
    case unknown(String)
    
    var id: String {
        switch self {
        case .initializationFailed: return "initialization_failed"
        case .permissionDenied: return "permission_denied"
        case .serviceUnavailable: return "service_unavailable"
        case .networkError: return "network_error"
        case .unknown: return "unknown"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .initializationFailed(let message):
            return "アプリの初期化に失敗しました: \(message)"
        case .permissionDenied(let permission):
            return "\(permission.displayName)の許可が必要です"
        case .serviceUnavailable(let service):
            return "\(service)サービスが利用できません"
        case .networkError(let message):
            return "ネットワークエラー: \(message)"
        case .unknown(let message):
            return "不明なエラー: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied(let permission):
            return "設定アプリから\(permission.displayName)を許可してください"
        case .networkError:
            return "インターネット接続を確認してください"
        default:
            return "アプリを再起動してみてください"
        }
    }
}

enum PermissionType {
    case microphone
    case notifications
    case storage
    
    var displayName: String {
        switch self {
        case .microphone: return "マイク"
        case .notifications: return "通知"
        case .storage: return "ストレージ"
        }
    }
}

// MARK: - Required Imports

import AVFoundation
import UserNotifications