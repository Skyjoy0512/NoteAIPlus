import SwiftUI

struct WaveformView: View {
    let audioLevels: [Float]
    let barCount: Int
    let isRecording: Bool
    
    init(
        audioLevels: [Float],
        barCount: Int = 50,
        isRecording: Bool = true
    ) {
        self.audioLevels = audioLevels
        self.barCount = barCount
        self.isRecording = isRecording
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: index))
                    .frame(width: 3, height: CGFloat(getBarHeight(for: index)))
                    .animation(.easeInOut(duration: 0.1), value: audioLevels)
            }
        }
        .frame(height: 100)
        .opacity(isRecording ? 1.0 : 0.3)
    }
    
    // MARK: - Private Methods
    
    private func getBarHeight(for index: Int) -> Float {
        guard index < audioLevels.count else { return minBarHeight }
        
        let level = audioLevels[index]
        let normalizedLevel = max(0, min(1, level))
        let height = minBarHeight + (maxBarHeight - minBarHeight) * normalizedLevel
        
        return height
    }
    
    private func barColor(for index: Int) -> Color {
        let level = index < audioLevels.count ? audioLevels[index] : 0
        
        if level > 0.8 {
            return .red
        } else if level > 0.6 {
            return .orange
        } else if level > 0.3 {
            return .yellow
        } else {
            return .blue
        }
    }
    
    private let minBarHeight: Float = 4
    private let maxBarHeight: Float = 90
}

// MARK: - Audio Level Indicator

struct AudioLevelIndicator: View {
    let level: Float
    let maxLevel: Float = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                
                // Level indicator
                RoundedRectangle(cornerRadius: 4)
                    .fill(levelColor)
                    .frame(width: geometry.size.width * CGFloat(normalizedLevel))
                    .animation(.easeInOut(duration: 0.1), value: level)
            }
        }
        .frame(height: 8)
    }
    
    private var normalizedLevel: Float {
        max(0, min(1, level / maxLevel))
    }
    
    private var levelColor: Color {
        if level > 0.8 {
            return .red
        } else if level > 0.6 {
            return .orange
        } else if level > 0.3 {
            return .yellow
        } else {
            return .green
        }
    }
}

// MARK: - Audio Level Meter

struct AudioLevelMeter: View {
    let level: Float
    let showPeakWarning: Bool
    
    init(level: Float) {
        self.level = level
        self.showPeakWarning = level > 0.9
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Numerical level display
            Text(String(format: "%.0f%%", level * 100))
                .font(.caption)
                .foregroundColor(showPeakWarning ? .red : .primary)
            
            // Visual level meter
            AudioLevelIndicator(level: level)
            
            // Warning text
            if showPeakWarning {
                Text("音声レベルが高すぎます")
                    .font(.caption2)
                    .foregroundColor(.red)
                    .animation(.easeInOut, value: showPeakWarning)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        // Static waveform
        WaveformView(
            audioLevels: Array(repeating: 0.5, count: 50),
            isRecording: true
        )
        
        // Dynamic waveform simulation
        WaveformView(
            audioLevels: (0..<50).map { _ in Float.random(in: 0...1) },
            isRecording: true
        )
        
        // Audio level meter
        AudioLevelMeter(level: 0.7)
        
        // Peak warning
        AudioLevelMeter(level: 0.95)
    }
    .padding()
}