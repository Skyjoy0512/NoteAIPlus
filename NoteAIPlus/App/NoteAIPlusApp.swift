import SwiftUI
import Firebase
import RevenueCat

@main
struct NoteAIPlusApp: App {
    @StateObject private var appState = AppState()
    
    init() {
        // Firebase初期化
        FirebaseApp.configure()
        
        // RevenueCat初期化
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: "YOUR_REVENUECAT_API_KEY")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    // アプリ起動時の初期化処理
                    setupAudioSession()
                }
        }
    }
    
    private func setupAudioSession() {
        // 音声セッションの初期設定
        // バックグラウンド録音対応
    }
}

class AppState: ObservableObject {
    @Published var isInitialized = false
    @Published var currentUser: User?
    @Published var subscriptionStatus: SubscriptionStatus = .free
    
    enum SubscriptionStatus {
        case free
        case basic
        case pro
    }
}