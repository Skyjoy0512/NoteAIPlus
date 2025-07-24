import SwiftUI

struct RecordButton: View {
    let isRecording: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    init(
        isRecording: Bool,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.isRecording = isRecording
        self.isEnabled = isEnabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer circle
                Circle()
                    .fill(isRecording ? Color.red : Color.gray.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
                
                // Inner circle/square
                if isRecording {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .frame(width: 40, height: 40)
                } else {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 80, height: 80)
                }
            }
            .scaleEffect(isRecording ? 1.1 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.5)
        }
        .disabled(!isEnabled)
        .animation(.easeInOut(duration: 0.2), value: isRecording)
        .accessibilityLabel(isRecording ? "録音停止" : "録音開始")
        .accessibilityHint(isRecording ? "タップして録音を停止します" : "タップして録音を開始します")
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        RecordButton(isRecording: false) {
            print("Start recording")
        }
        
        RecordButton(isRecording: true) {
            print("Stop recording")
        }
        
        RecordButton(isRecording: false, isEnabled: false) {
            print("Disabled")
        }
    }
    .padding()
}