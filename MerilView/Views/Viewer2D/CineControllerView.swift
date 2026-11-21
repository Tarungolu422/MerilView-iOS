import SwiftUI

/// Floating bottom HUD for variable speed Cine playback.
public struct CineControllerView: View {
    @Binding public var isPlaying: Bool
    @Binding public var fps: Double
    public let onStepBack: () -> Void
    public let onStepForward: () -> Void
    
    public init(
        isPlaying: Binding<Bool>,
        fps: Binding<Double>,
        onStepBack: @escaping () -> Void,
        onStepForward: @escaping () -> Void
    ) {
        self._isPlaying = isPlaying
        self._fps = fps
        self.onStepBack = onStepBack
        self.onStepForward = onStepForward
    }
    
    public var body: some View {
        HStack(spacing: 16) {
            Button(action: onStepBack) {
                Image(systemName: "backward.frame.fill")
                    .foregroundColor(MerilTheme.textPrimary)
                    .font(.system(size: 16))
            }
            
            Button(action: { isPlaying.toggle() }) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .foregroundColor(MerilTheme.accent)
                    .font(.system(size: 32))
            }
            
            Button(action: onStepForward) {
                Image(systemName: "forward.frame.fill")
                    .foregroundColor(MerilTheme.textPrimary)
                    .font(.system(size: 16))
            }
            
            Divider().frame(height: 20).background(MerilTheme.border)
            
            // FPS slider
            HStack(spacing: 8) {
                Text("\(Int(fps)) FPS")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(MerilTheme.textSecondary)
                    .frame(width: 55, alignment: .leading)
                
                Slider(value: $fps, in: 5...60, step: 1)
                    .tint(MerilTheme.accent)
                    .frame(width: 120)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(MerilTheme.surface.opacity(0.95))
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(MerilTheme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
    }
}
