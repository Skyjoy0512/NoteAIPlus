import SwiftUI
import Firebase
import RevenueCat
import AVFoundation

@main
struct NoteAIPlusApp: App {
    @StateObject private var appState = AppState()
    
    init() {
        // Firebase初期化
        FirebaseApp.configure()
        
        // RevenueCat初期化
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: "YOUR_REVENUECAT_API_KEY")
        
        // Audio session setup
        setupAudioSession()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .task {
                    await appState.initialize()
                }
                .alert("エラー", isPresented: $appState.showingError) {
                    Button("OK") {
                        appState.dismissError()
                    }
                } message: {
                    if let error = appState.currentError {
                        VStack {
                            Text(error.localizedDescription)
                            if let suggestion = error.recoverySuggestion {
                                Text(suggestion)
                                    .font(.caption)
                            }
                        }
                    }
                }
        }
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
}