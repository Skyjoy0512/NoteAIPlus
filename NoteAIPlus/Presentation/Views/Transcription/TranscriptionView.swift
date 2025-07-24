import SwiftUI

struct TranscriptionView: View {
    
    @StateObject private var viewModel = TranscriptionViewModel()
    @State private var selectedTab: TranscriptionTab = .current
    @State private var showingModelManager = false
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selector
                transcriptionTabSelector
                
                // Content based on selected tab
                switch selectedTab {
                case .current:
                    currentTranscriptionView
                case .history:
                    transcriptionHistoryView
                case .statistics:
                    statisticsView
                }
            }
            .navigationTitle("文字起こし")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("モデル管理") {
                            showingModelManager = true
                        }
                        Button("設定") {
                            showingSettings = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingModelManager) {
            ModelManagerView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingSettings) {
            TranscriptionSettingsView(viewModel: viewModel)
        }
        .alert("エラー", isPresented: $viewModel.showingError) {
            Button("OK") {
                viewModel.showingError = false
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "不明なエラーが発生しました")
        }
    }
    
    // MARK: - Tab Selector
    
    private var transcriptionTabSelector: some View {
        HStack {
            ForEach(TranscriptionTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 16, weight: .medium))
                        Text(tab.title)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedTab == tab ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Current Transcription View
    
    private var currentTranscriptionView: some View {
        VStack(spacing: 16) {
            if viewModel.isProcessing {
                processingView
            } else if let transcription = viewModel.currentTranscription {
                transcriptionResultView(transcription)
            } else {
                emptyStateView
            }
        }
        .padding()
    }
    
    private var processingView: some View {
        VStack(spacing: 20) {
            // Progress Circle
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 8)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: CGFloat(viewModel.progress))
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.progress)
                
                Text("\(Int(viewModel.progress * 100))%")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 8) {
                Text(viewModel.progressText)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                Text("処理中です。しばらくお待ちください。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("キャンセル") {
                viewModel.cancelTranscription()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func transcriptionResultView(_ transcription: TranscriptionResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header Info
                transcriptionHeaderView(transcription)
                
                // Transcription Text
                transcriptionTextView(transcription)
                
                // Segments (if available)
                if !transcription.segments.isEmpty {
                    segmentsView(transcription.segments)
                }
                
                // Speakers (if available)
                if let speakers = transcription.speakers, !speakers.isEmpty {
                    speakersView(speakers)
                }
                
                // Metadata
                metadataView(transcription)
            }
            .padding()
        }
    }
    
    private func transcriptionHeaderView(_ transcription: TranscriptionResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("文字起こし結果")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("作成日: \(transcription.createdAt, formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                qualityBadge(transcription.qualityScore)
            }
            
            HStack {
                Label(transcription.language.uppercased(), systemImage: "globe")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                
                Label(transcription.modelType.displayName, systemImage: "brain.head.profile")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(8)
                
                Spacer()
            }
        }
    }
    
    private func transcriptionTextView(_ transcription: TranscriptionResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("文字起こしテキスト")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("コピー") {
                    UIPasteboard.general.string = transcription.text
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            Text(transcription.text)
                .font(.body)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .textSelection(.enabled)
        }
    }
    
    private func segmentsView(_ segments: [TranscriptionSegment]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("セグメント詳細")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            LazyVStack(spacing: 8) {
                ForEach(segments.prefix(5), id: \.id) { segment in
                    segmentRowView(segment)
                }
                
                if segments.count > 5 {
                    Text("... 他 \(segments.count - 5) セグメント")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
    }
    
    private func segmentRowView(_ segment: TranscriptionSegment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(segment.formattedTimeRange)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                
                Spacer()
                
                confidenceBadge(segment.confidence)
            }
            
            Text(segment.text)
                .font(.subheadline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func speakersView(_ speakers: [Speaker]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("話者情報")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            LazyVStack(spacing: 8) {
                ForEach(speakers, id: \.id) { speaker in
                    speakerRowView(speaker)
                }
            }
        }
    }
    
    private func speakerRowView(_ speaker: Speaker) -> some View {
        HStack {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(speaker.name.prefix(1)))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(speaker.effectiveDisplayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let characteristics = speaker.voiceCharacteristics {
                    HStack {
                        if let gender = characteristics.estimatedGender {
                            Text(gender.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let age = characteristics.estimatedAge {
                            Text("約\(age)歳")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let voiceType = characteristics.voiceType {
                            Text(voiceType.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            confidenceBadge(speaker.confidence)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func metadataView(_ transcription: TranscriptionResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("詳細情報")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            VStack(spacing: 6) {
                metadataRow("単語数", "\(transcription.wordCount) 語")
                metadataRow("処理時間", String(format: "%.1f秒", transcription.processingTime))
                metadataRow("平均信頼度", String(format: "%.1f%%", transcription.averageConfidence * 100))
                
                if let audioQuality = transcription.metadata.audioQuality {
                    metadataRow("音質評価", audioQuality.qualityRating.rawValue)
                }
            }
        }
    }
    
    private func metadataRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("文字起こし結果なし")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("録音を選択して文字起こしを開始してください")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - History View
    
    private var transcriptionHistoryView: some View {
        VStack(spacing: 0) {
            // Search and filters
            searchAndFilterView
            
            if viewModel.filteredTranscriptions.isEmpty {
                emptyHistoryView
            } else {
                transcriptionListView
            }
        }
    }
    
    private var searchAndFilterView: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("文字起こし結果を検索", text: $viewModel.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !viewModel.searchText.isEmpty {
                    Button("クリア") {
                        viewModel.searchText = ""
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Language filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip("すべて", isSelected: viewModel.selectedLanguage == "all") {
                        viewModel.selectedLanguage = "all"
                    }
                    
                    ForEach(Array(Set(viewModel.transcriptions.map(\.language))).sorted(), id: \.self) { language in
                        filterChip(language.uppercased(), isSelected: viewModel.selectedLanguage == language) {
                            viewModel.selectedLanguage = language
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    private func filterChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var transcriptionListView: some View {
        List {
            ForEach(viewModel.filteredTranscriptions, id: \.id) { transcription in
                transcriptionListRow(transcription)
                    .onTapGesture {
                        viewModel.currentTranscription = transcription
                        selectedTab = .current
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("削除", role: .destructive) {
                            Task {
                                await viewModel.deleteTranscription(transcription)
                            }
                        }
                    }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private func transcriptionListRow(_ transcription: TranscriptionResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(transcription.text.prefix(100) + (transcription.text.count > 100 ? "..." : ""))
                        .font(.subheadline)
                        .lineLimit(2)
                    
                    Text(transcription.createdAt, formatter: relativeDateFormatter)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    qualityBadge(transcription.qualityScore)
                    
                    Text(transcription.language.uppercased())
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var emptyHistoryView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("履歴がありません")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("文字起こしを実行すると、ここに履歴が表示されます")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Statistics View
    
    private var statisticsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let stats = viewModel.statistics {
                    statisticsContentView(stats)
                } else {
                    statisticsLoadingView
                }
            }
            .padding()
        }
        .onAppear {
            Task {
                await viewModel.loadStatistics()
            }
        }
    }
    
    private func statisticsContentView(_ stats: TranscriptionStatistics) -> some View {
        VStack(spacing: 16) {
            // Overview Cards
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 150))
            ], spacing: 12) {
                statCard("総文字起こし数", "\(stats.totalCount)", systemImage: "doc.text")
                statCard("平均信頼度", String(format: "%.1f%%", stats.averageConfidence * 100), systemImage: "checkmark.seal")
                statCard("総処理時間", String(format: "%.1f分", stats.totalProcessingTime / 60), systemImage: "clock")
                statCard("平均処理時間", String(format: "%.1f秒", stats.averageProcessingTime), systemImage: "speedometer")
            }
            
            // Language breakdown
            if !stats.languageCounts.isEmpty {
                languageBreakdownView(stats.languageCounts)
            }
        }
    }
    
    private func statCard(_ title: String, _ value: String, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func languageBreakdownView(_ languageCounts: [String: Int]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("言語別内訳")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(languageCounts.sorted(by: { $0.value > $1.value }), id: \.key) { language, count in
                HStack {
                    Text(language.uppercased())
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(count)件")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    private var statisticsLoadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("統計を読み込み中...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Views
    
    private func qualityBadge(_ quality: TranscriptionQuality) -> some View {
        HStack(spacing: 4) {
            Image(systemName: quality.icon)
                .font(.caption2)
            
            Text(quality.rawValue)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(quality.color).opacity(0.2))
        .foregroundColor(Color(quality.color))
        .cornerRadius(8)
    }
    
    private func confidenceBadge(_ confidence: Float) -> some View {
        Text(String(format: "%.0f%%", confidence * 100))
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(confidenceColor(confidence).opacity(0.2))
            .foregroundColor(confidenceColor(confidence))
            .cornerRadius(6)
    }
    
    private func confidenceColor(_ confidence: Float) -> Color {
        switch confidence {
        case 0.9...1.0: return .green
        case 0.7..<0.9: return .blue
        case 0.5..<0.7: return .orange
        default: return .red
        }
    }
}

// MARK: - Supporting Types

enum TranscriptionTab: String, CaseIterable {
    case current = "current"
    case history = "history"
    case statistics = "statistics"
    
    var title: String {
        switch self {
        case .current: return "現在"
        case .history: return "履歴"
        case .statistics: return "統計"
        }
    }
    
    var iconName: String {
        switch self {
        case .current: return "doc.text"
        case .history: return "clock.arrow.circlepath"
        case .statistics: return "chart.bar"
        }
    }
}

// MARK: - Extensions

extension TranscriptionQuality {
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "yellow"
        case .poor: return "orange"
        case .veryPoor: return "red"
        }
    }
}

// MARK: - Formatters

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

private let relativeDateFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter
}()

struct TranscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        TranscriptionView()
    }
}