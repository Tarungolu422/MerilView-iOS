import SwiftUI

/// Medical workstation spinner with status message.
public struct MedicalLoadingView: View {
    public let message: String
    
    public init(_ message: String = "Loading Medical Dataset...") {
        self.message = message
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: MerilTheme.accent))
                .scaleEffect(1.4)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(MerilTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MerilTheme.background.opacity(0.85))
    }
}

/// Error state card with retry action.
public struct MedicalErrorView: View {
    public let title: String
    public let message: String
    public let onRetry: (() -> Void)?
    
    public init(title: String = "Unable to Load Study", message: String, onRetry: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.onRetry = onRetry
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(MerilTheme.warning)
            
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(MerilTheme.textPrimary)
            
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(MerilTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if let retry = onRetry {
                Button(action: retry) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(MerilTheme.background)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(MerilTheme.accent)
                    .cornerRadius(8)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MerilTheme.background)
    }
}
