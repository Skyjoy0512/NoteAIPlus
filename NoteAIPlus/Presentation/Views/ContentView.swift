import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    
    var body: some View {
        if appState.isInitialized {
            TabView(selection: $selectedTab) {
                // ホーム画面
                HomeView()
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("ホーム")
                    }
                    .tag(0)
                
                // 録音画面
                RecordingView()
                    .tabItem {
                        Image(systemName: "mic.circle.fill")
                        Text("録音")
                    }
                    .tag(1)
                
                // 文字起こし画面
                TranscriptionView()
                    .tabItem {
                        Image(systemName: "doc.text.fill")
                        Text("文字起こし")
                    }
                    .tag(2)
                
                // 設定画面
                SettingsView()
                    .tabItem {
                        Image(systemName: "gearshape.fill")
                        Text("設定")
                    }
                    .tag(3)
            }
        } else {
            // スプラッシュスクリーン
            SplashView()
                .onAppear {
                    initializeApp()
                }
        }
    }
    
    private func initializeApp() {
        // アプリ初期化処理
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                appState.isInitialized = true
            }
        }
    }
}

struct SplashView: View {
    var body: some View {
        VStack {
            Image(systemName: "waveform")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("NoteAI Plus")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            Text("AI-Powered Voice Recorder")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
}

// ホーム画面
struct HomeView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景色
                Color(red: 0.898, green: 0.898, blue: 0.902)
                    .ignoresSafeArea(.all)
                
                VStack {
                    // メインコンテンツがここに追加される
                    Text("NoteAI Plus")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .padding(.top, 60)
                    
                    Spacer()
                    
                    Text("録音一覧がここに表示されます")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Text("設定画面がここに表示されます")
                .navigationTitle("設定")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}