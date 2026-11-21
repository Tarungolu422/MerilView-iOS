import SwiftUI

/// Toolbar for volumetric segmentation studio.
public struct SegmentationToolbarView: View {
    @Binding public var activeTool: SegmentationTool
    @Binding public var brushRadiusMm: Double
    @Binding public var is3DMode: Bool
    public let onUndo: () -> Void
    public let onRedo: () -> Void
    public let onExportSeg: () -> Void
    public let onBack: () -> Void
    
    public init(
        activeTool: Binding<SegmentationTool>,
        brushRadiusMm: Binding<Double>,
        is3DMode: Binding<Bool>,
        onUndo: @escaping () -> Void,
        onRedo: @escaping () -> Void,
        onExportSeg: @escaping () -> Void,
        onBack: @escaping () -> Void
    ) {
        self._activeTool = activeTool
        self._brushRadiusMm = brushRadiusMm
        self._is3DMode = is3DMode
        self.onUndo = onUndo
        self.onRedo = onRedo
        self.onExportSeg = onExportSeg
        self.onBack = onBack
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Viewer")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(MerilTheme.accent)
            }
            
            Divider().frame(height: 20).background(MerilTheme.border)
            
            // Tools
            ForEach([SegmentationTool.brush2D, SegmentationTool.brush3D, SegmentationTool.eraser, SegmentationTool.threshold]) { tool in
                Button(action: { activeTool = tool }) {
                    HStack(spacing: 4) {
                        Image(systemName: tool.systemIcon)
                            .font(.system(size: 12))
                        Text(tool.title)
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(activeTool == tool ? MerilTheme.background : MerilTheme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(activeTool == tool ? MerilTheme.accent : MerilTheme.surface)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(activeTool == tool ? MerilTheme.accent : MerilTheme.border, lineWidth: 1))
                }
            }
            
            Divider().frame(height: 20).background(MerilTheme.border)
            
            // Brush Radius Indicator & Slider
            HStack(spacing: 4) {
                Text("\(Int(brushRadiusMm))mm")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(MerilTheme.textSecondary)
                Slider(value: $brushRadiusMm, in: 1...40, step: 1)
                    .tint(MerilTheme.accent)
                    .frame(width: 80)
            }
            
            Spacer()
            
            // Undo & Redo
            HStack(spacing: 6) {
                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 13))
                        .foregroundColor(MerilTheme.textSecondary)
                        .padding(6)
                        .background(MerilTheme.surface)
                        .cornerRadius(6)
                }
                
                Button(action: onRedo) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 13))
                        .foregroundColor(MerilTheme.textSecondary)
                        .padding(6)
                        .background(MerilTheme.surface)
                        .cornerRadius(6)
                }
            }
            
            // Export DICOM SEG
            Button(action: onExportSeg) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text("Export SEG")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(MerilTheme.background)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(MerilTheme.success)
                .cornerRadius(6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(MerilTheme.surface)
    }
}
