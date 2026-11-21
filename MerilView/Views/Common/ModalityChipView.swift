import SwiftUI

/// Modality indicator badge (e.g. CT, MR, CR, DX, US).
public struct ModalityChipView: View {
    public let modality: String
    
    public init(_ modality: String) {
        self.modality = modality
    }
    
    public var body: some View {
        let color = MerilTheme.modalityColor(modality)
        Text(modality.uppercased())
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color.opacity(0.35), lineWidth: 1)
            )
    }
}
