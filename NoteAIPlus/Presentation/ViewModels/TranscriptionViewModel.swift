import Foundation
import SwiftUI
import Combine

@MainActor
class TranscriptionViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var transcriptionState: TranscriptionState = .idle
    @Published var currentTranscription: TranscriptionResult?
    @Published var progress: Float = 0.0
    @Published var progressText: String = ""
    @Published var isProcessing: Bool = false
    @Published var error: TranscriptionError?
    @Published var showingError: Bool = false
    
    // Search and filter
    @Published var searchText: String = ""
    @Published var selectedLanguage: String = "all"
    @Published var selectedModel: WhisperModelType = .base
    @Published var transcriptions: [TranscriptionResult] = []
    @Published var filteredTranscriptions: [TranscriptionResult] = []
    
    // Model management
    @Published var availableModels: [WhisperModelType] = []
    @Published var downloadedModels: Set<WhisperModelType> = []
    @Published var modelDownloadProgress: [WhisperModelType: Float] = [:]
    @Published var isDownloadingModel: Bool = false
    
    // Statistics
    @Published var statistics: TranscriptionStatistics?
    
    // MARK: - Dependencies
    
    private let transcriptionUseCase: TranscriptionUseCase
    private let recordingUseCase: RecordingUseCase
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        transcriptionUseCase: TranscriptionUseCase = TranscriptionUseCase(),
        recordingUseCase: RecordingUseCase = RecordingUseCase()
    ) {
        self.transcriptionUseCase = transcriptionUseCase
        self.recordingUseCase = recordingUseCase
        
        setupObservers()
        loadInitialData()
    }
    
    // MARK: - Public Methods
    
    /// 録音を文字起こしする
    func transcribeRecording(_ recording: Recording) async {
        do {
            transcriptionState = .processing
            isProcessing = true
            error = nil
            showingError = false
            
            let options = createTranscriptionOptions()
            let result = try await transcriptionUseCase.transcribeRecording(recording, options: options)
            
            currentTranscription = result
            transcriptionState = .completed(result)
            
            // Refresh transcriptions list
            await loadTranscriptions()
            
        } catch let transcriptionError as TranscriptionError {
            self.error = transcriptionError
            self.showingError = true
            self.transcriptionState = .error(transcriptionError)
        } catch {
            let wrappedError = TranscriptionError.transcriptionFailed(error.localizedDescription)
            self.error = wrappedError
            self.showingError = true
            self.transcriptionState = .error(wrappedError)
        }
        
        isProcessing = false
    }
    
    /// 進捗付き文字起こし
    func transcribeWithProgress(_ recording: Recording) {
        Task {
            do {
                transcriptionState = .processing
                isProcessing = true
                error = nil
                
                let options = createTranscriptionOptions()
                let progressStream = transcriptionUseCase.transcribeWithProgress(
                    recording: recording,
                    options: options
                )
                
                for try await progressUpdate in progressStream {
                    await updateProgress(progressUpdate)
                }
                
                // Get final result
                if let result = try await transcriptionUseCase.getTranscriptionByRecordingId(recording.id) {
                    currentTranscription = result
                    transcriptionState = .completed(result)
                    await loadTranscriptions()
                }
                
            } catch let transcriptionError as TranscriptionError {
                await MainActor.run {
                    self.error = transcriptionError
                    self.showingError = true
                    self.transcriptionState = .error(transcriptionError)
                }
            } catch {
                await MainActor.run {
                    let wrappedError = TranscriptionError.transcriptionFailed(error.localizedDescription)
                    self.error = wrappedError
                    self.showingError = true
                    self.transcriptionState = .error(wrappedError)
                }
            }
            
            await MainActor.run {
                self.isProcessing = false
            }
        }
    }
    
    /// 文字起こしをキャンセル
    func cancelTranscription() {
        transcriptionUseCase.cancelTranscription()
        transcriptionState = .cancelled
        isProcessing = false
        progress = 0.0
        progressText = ""
    }
    
    /// 文字起こし結果を削除
    func deleteTranscription(_ transcription: TranscriptionResult) async {
        do {
            try await transcriptionUseCase.deleteTranscription(transcription)
            await loadTranscriptions()
            
            if currentTranscription?.id == transcription.id {
                currentTranscription = nil
                transcriptionState = .idle
            }
        } catch {
            self.error = TranscriptionError.transcriptionFailed("削除に失敗しました: \(error.localizedDescription)")
            self.showingError = true
        }
    }
    
    /// 検索を実行
    func performSearch() async {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await loadTranscriptions()
            return
        }
        
        do {
            let results = try await transcriptionUseCase.searchTranscriptions(query: searchText)
            transcriptions = results
            applyFilters()
        } catch {
            print("Search failed: \(error)")
        }
    }
    
    /// フィルターを適用
    func applyFilters() {
        var filtered = transcriptions
        
        // Language filter
        if selectedLanguage != "all" {
            filtered = filtered.filter { $0.language == selectedLanguage }
        }
        
        // Model filter (if needed)
        // filtered = filtered.filter { $0.modelType == selectedModel }
        
        filteredTranscriptions = filtered.sorted { $0.createdAt > $1.createdAt }
    }
    
    /// モデルをダウンロード
    func downloadModel(_ modelType: WhisperModelType) async {
        do {
            isDownloadingModel = true
            modelDownloadProgress[modelType] = 0.0
            
            try await transcriptionUseCase.downloadModel(modelType)
            
            modelDownloadProgress[modelType] = 1.0
            downloadedModels.insert(modelType)
            
        } catch {
            self.error = TranscriptionError.modelDownloadFailed(modelType)
            self.showingError = true
        }
        
        isDownloadingModel = false
        modelDownloadProgress.removeValue(forKey: modelType)
    }
    
    /// モデルを削除
    func deleteModel(_ modelType: WhisperModelType) async {
        do {
            try await transcriptionUseCase.deleteModel(modelType)
            downloadedModels.remove(modelType)
        } catch {
            self.error = TranscriptionError.transcriptionFailed("モデルの削除に失敗しました")
            self.showingError = true
        }
    }
    
    /// 統計を読み込み
    func loadStatistics() async {
        do {
            statistics = try await transcriptionUseCase.getTranscriptionStatistics()
        } catch {
            print("Failed to load statistics: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Search text changes
        $searchText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                Task {
                    await self?.performSearch()
                }
            }
            .store(in: &cancellables)
        
        // Language filter changes
        $selectedLanguage
            .sink { [weak self] _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)
        
        // Observe transcription use case
        transcriptionUseCase.$isProcessing
            .receive(on: DispatchQueue.main)
            .assign(to: \.isProcessing, on: self)
            .store(in: &cancellables)
        
        transcriptionUseCase.$currentProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.updateProgress(progress)
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialData() {
        Task {
            await loadTranscriptions()
            await loadModels()
            await loadStatistics()
        }
    }
    
    private func loadTranscriptions() async {
        do {
            transcriptions = try await transcriptionUseCase.getRecentTranscriptions(limit: 100)
            applyFilters()
        } catch {
            print("Failed to load transcriptions: \(error)")
        }
    }
    
    private func loadModels() async {
        availableModels = transcriptionUseCase.getAvailableModels()
        downloadedModels = transcriptionUseCase.getDownloadedModels()
    }
    
    private func updateProgress(_ progress: TranscriptionProgress) {
        self.progress = progress.progressValue
        self.progressText = progress.displayText
        
        switch progress {
        case .completed:
            self.transcriptionState = .idle
            Task {
                await loadTranscriptions()
            }
        case .error(let error):
            if let transcriptionError = error as? TranscriptionError {
                self.error = transcriptionError
            } else {
                self.error = TranscriptionError.transcriptionFailed(error.localizedDescription)
            }
            self.showingError = true
            self.transcriptionState = .error(self.error!)
        case .cancelled:
            self.transcriptionState = .cancelled
        default:
            break
        }
    }
    
    private func createTranscriptionOptions() -> TranscriptionOptions {
        var options = TranscriptionOptions()
        options.modelType = selectedModel
        options.enablePunctuationInsertion = true
        options.enableParagraphBreaks = true
        options.enableWordTimestamps = true
        return options
    }
}

// MARK: - Supporting Types

enum TranscriptionState: Equatable {
    case idle
    case processing
    case completed(TranscriptionResult)
    case cancelled
    case error(TranscriptionError)
    
    static func == (lhs: TranscriptionState, rhs: TranscriptionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.processing, .processing), (.cancelled, .cancelled):
            return true
        case (.completed(let lhsResult), .completed(let rhsResult)):
            return lhsResult.id == rhsResult.id
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

// MARK: - Extensions

extension TranscriptionProgress {
    var progressValue: Float {
        switch self {
        case .idle: return 0.0
        case .preparing: return 0.1
        case .preprocessing: return 0.2
        case .loadingModel: return 0.3
        case .transcribing(let progress): return 0.3 + (progress * 0.6)
        case .postprocessing: return 0.9
        case .completed: return 1.0
        case .cancelled, .error: return 0.0
        }
    }
    
    var displayText: String {
        switch self {
        case .idle: return "待機中"
        case .preparing: return "準備中..."
        case .preprocessing: return "音声を前処理中..."
        case .loadingModel: return "モデルを読み込み中..."
        case .transcribing(let progress): return "文字起こし中... \(Int(progress * 100))%"
        case .postprocessing: return "後処理中..."
        case .completed: return "完了"
        case .cancelled: return "キャンセル済み"
        case .error: return "エラーが発生しました"
        }
    }
}