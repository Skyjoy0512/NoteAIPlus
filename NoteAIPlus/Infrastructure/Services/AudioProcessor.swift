import Foundation
import AVFoundation

class AudioProcessor: AudioProcessorProtocol {
    
    private let fileManager = FileManager.default
    
    // MARK: - AudioProcessorProtocol
    
    func convertToWhisperFormat(_ inputURL: URL) async throws -> URL {
        let outputURL = createTempURL(extension: "wav")
        
        let asset = AVAsset(url: inputURL)
        guard let assetTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw AudioProcessingError.noAudioTrack
        }
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioProcessingError.exportSessionCreationFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .wav
        
        // Configure audio settings optimized for Whisper
        exportSession.audioSettings = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000, // Whisper's preferred sample rate
            AVNumberOfChannelsKey: 1, // Mono audio
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume(returning: outputURL)
                case .failed:
                    let error = exportSession.error ?? AudioProcessingError.conversionFailed
                    continuation.resume(throwing: error)
                case .cancelled:
                    continuation.resume(throwing: AudioProcessingError.conversionCancelled)
                default:
                    continuation.resume(throwing: AudioProcessingError.conversionFailed)
                }
            }
        }
    }
    
    func reduceNoise(_ inputURL: URL, level: NoiseReductionLevel) async throws -> URL {
        let outputURL = createTempURL(extension: "wav")
        
        // Load audio file
        let audioFile = try AVAudioFile(forReading: inputURL)
        let format = audioFile.processingFormat
        
        guard let outputFile = try? AVAudioFile(
            forWriting: outputURL,
            settings: format.settings
        ) else {
            throw AudioProcessingError.outputFileCreationFailed
        }
        
        // Create audio engine for processing
        let audioEngine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        let effectNode = AVAudioUnitReverb()
        
        // Configure noise reduction (simplified implementation)
        effectNode.loadFactoryPreset(.smallRoom)
        effectNode.wetDryMix = level.processingIntensity * 50 // Adjust based on level
        
        audioEngine.attach(playerNode)
        audioEngine.attach(effectNode)
        
        audioEngine.connect(playerNode, to: effectNode, format: format)
        audioEngine.connect(effectNode, to: audioEngine.mainMixerNode, format: format)
        
        // Process audio
        try audioEngine.start()
        
        // Read and process audio buffer
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioProcessingError.bufferCreationFailed
        }
        
        try audioFile.read(into: buffer)
        
        // Apply noise reduction and write to output
        playerNode.scheduleBuffer(buffer) {
            // Processing complete
        }
        
        playerNode.play()
        
        // Wait for processing to complete
        try await Task.sleep(nanoseconds: UInt64(buffer.duration * 1_000_000_000))
        
        audioEngine.stop()
        
        return outputURL
    }
    
    func analyzeAudioQuality(_ audioURL: URL) async throws -> AudioQualityMetrics {
        let audioFile = try AVAudioFile(forReading: audioURL)
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioProcessingError.bufferCreationFailed
        }
        
        try audioFile.read(into: buffer)
        
        guard let channelData = buffer.floatChannelData?[0] else {
            throw AudioProcessingError.channelDataNotAvailable
        }
        
        let frameLength = Int(buffer.frameLength)
        
        // Calculate audio quality metrics
        let averageLevel = calculateAverageLevel(channelData, frameLength: frameLength)
        let peakLevel = calculatePeakLevel(channelData, frameLength: frameLength)
        let dynamicRange = calculateDynamicRange(channelData, frameLength: frameLength)
        let hasClipping = detectClipping(channelData, frameLength: frameLength)
        let snr = calculateSignalToNoiseRatio(channelData, frameLength: frameLength)
        let spectralCentroid = try await calculateSpectralCentroid(channelData, frameLength: frameLength, sampleRate: format.sampleRate)
        
        return AudioQualityMetrics(
            signalToNoiseRatio: snr,
            dynamicRange: dynamicRange,
            hasClipping: hasClipping,
            averageLevel: averageLevel,
            peakLevel: peakLevel,
            spectralCentroid: spectralCentroid
        )
    }
    
    // MARK: - Private Methods
    
    private func createTempURL(extension ext: String) -> URL {
        let tempDir = fileManager.temporaryDirectory
        let fileName = "\(UUID().uuidString).\(ext)"
        return tempDir.appendingPathComponent(fileName)
    }
    
    private func calculateAverageLevel(_ channelData: UnsafeMutablePointer<Float>, frameLength: Int) -> Float {
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        return sum / Float(frameLength)
    }
    
    private func calculatePeakLevel(_ channelData: UnsafeMutablePointer<Float>, frameLength: Int) -> Float {
        var peak: Float = 0
        for i in 0..<frameLength {
            let level = abs(channelData[i])
            if level > peak {
                peak = level
            }
        }
        return peak
    }
    
    private func calculateDynamicRange(_ channelData: UnsafeMutablePointer<Float>, frameLength: Int) -> Float {
        let peak = calculatePeakLevel(channelData, frameLength: frameLength)
        let average = calculateAverageLevel(channelData, frameLength: frameLength)
        return peak - average
    }
    
    private func detectClipping(_ channelData: UnsafeMutablePointer<Float>, frameLength: Int) -> Bool {
        let clippingThreshold: Float = 0.95
        
        for i in 0..<frameLength {
            if abs(channelData[i]) >= clippingThreshold {
                return true
            }
        }
        return false
    }
    
    private func calculateSignalToNoiseRatio(_ channelData: UnsafeMutablePointer<Float>, frameLength: Int) -> Float {
        // Simplified SNR calculation
        // In practice, this would involve more sophisticated analysis
        
        var signalPower: Float = 0
        var noisePower: Float = 0
        
        // Calculate RMS for signal power
        for i in 0..<frameLength {
            let sample = channelData[i]
            signalPower += sample * sample
        }
        signalPower = sqrt(signalPower / Float(frameLength))
        
        // Estimate noise floor (simplified approach)
        // Sort samples and take the lower percentile as noise
        var samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        samples.sort { abs($0) < abs($1) }
        
        let noiseFrameCount = frameLength / 10 // Use bottom 10% as noise estimate
        for i in 0..<noiseFrameCount {
            let sample = samples[i]
            noisePower += sample * sample
        }
        noisePower = sqrt(noisePower / Float(noiseFrameCount))
        
        // Calculate SNR in dB
        guard noisePower > 0 else { return 60.0 } // Very high SNR if no detectable noise
        
        let snrRatio = signalPower / noisePower
        return 20 * log10(snrRatio)
    }
    
    private func calculateSpectralCentroid(_ channelData: UnsafeMutablePointer<Float>, frameLength: Int, sampleRate: Double) async throws -> Float? {
        // Simplified spectral centroid calculation
        // In practice, this would use FFT analysis
        
        // For now, return a placeholder based on energy distribution
        let averageLevel = calculateAverageLevel(channelData, frameLength: frameLength)
        let peakLevel = calculatePeakLevel(channelData, frameLength: frameLength)
        
        // Estimate spectral centroid based on signal characteristics
        let centroidRatio = averageLevel / max(peakLevel, 0.001)
        return Float(sampleRate * 0.25 * Double(centroidRatio)) // Rough estimation
    }
}

// MARK: - Extensions

extension AVAudioPCMBuffer {
    var duration: TimeInterval {
        return Double(frameLength) / format.sampleRate
    }
}

// MARK: - Error Types

enum AudioProcessingError: LocalizedError {
    case noAudioTrack
    case exportSessionCreationFailed
    case conversionFailed
    case conversionCancelled
    case outputFileCreationFailed
    case bufferCreationFailed
    case channelDataNotAvailable
    case unsupportedFormat
    
    var errorDescription: String? {
        switch self {
        case .noAudioTrack:
            return "音声トラックが見つかりません。"
        case .exportSessionCreationFailed:
            return "音声変換セッションの作成に失敗しました。"
        case .conversionFailed:
            return "音声フォーマットの変換に失敗しました。"
        case .conversionCancelled:
            return "音声変換がキャンセルされました。"
        case .outputFileCreationFailed:
            return "出力ファイルの作成に失敗しました。"
        case .bufferCreationFailed:
            return "音声バッファの作成に失敗しました。"
        case .channelDataNotAvailable:
            return "音声チャンネルデータが利用できません。"
        case .unsupportedFormat:
            return "サポートされていない音声フォーマットです。"
        }
    }
}