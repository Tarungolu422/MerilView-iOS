import SwiftUI

/// Active interactive tool in 2D DICOM viewer.
public enum ViewerTool: String, CaseIterable, Identifiable {
    case scroll = "scroll"
    case windowLevel = "wl"
    case pan = "pan"
    case zoom = "zoom"
    case length = "length"
    case angle = "angle"
    case ellipseRoi = "ellipse_roi"
    case rectangleRoi = "rect_roi"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .scroll: return "Scroll"
        case .windowLevel: return "W/L"
        case .pan: return "Pan"
        case .zoom: return "Zoom"
        case .length: return "Caliper"
        case .angle: return "Angle"
        case .ellipseRoi: return "Ellipse"
        case .rectangleRoi: return "Rect"
        }
    }
    
    public var systemIcon: String {
        switch self {
        case .scroll: return "hand.draw"
        case .windowLevel: return "circle.lefthalf.filled"
        case .pan: return "arrow.up.and.down.and.arrow.left.and.right"
        case .zoom: return "plus.magnifyingglass"
        case .length: return "ruler"
        case .angle: return "angle"
        case .ellipseRoi: return "oval"
        case .rectangleRoi: return "rectangle"
        }
    }
}

/// Clinical toolbar for 2D viewer workstation.
public struct ViewerToolbarView: View {
    @Binding public var activeTool: ViewerTool
    public let onToggleInvert: () -> Void
    public let onReset: () -> Void
    public let onOpenPresets: () -> Void
    public let onOpenMetadata: () -> Void
    public let onToggleCine: () -> Void
    public let isCineActive: Bool
    public let onOpenMpr: () -> Void
    public let onOpenSegmentation: () -> Void
    
    public init(
        activeTool: Binding<ViewerTool>,
        onToggleInvert: @escaping () -> Void,
        onReset: @escaping () -> Void,
        onOpenPresets: @escaping () -> Void,
        onOpenMetadata: @escaping () -> Void,
        onToggleCine: @escaping () -> Void,
        isCineActive: Bool,
        onOpenMpr: @escaping () -> Void,
        onOpenSegmentation: @escaping () -> Void
    ) {
        self._activeTool = activeTool
        self.onToggleInvert = onToggleInvert
        self.onReset = onReset
        self.onOpenPresets = onOpenPresets
        self.onOpenMetadata = onOpenMetadata
        self.onToggleCine = onToggleCine
        self.isCineActive = isCineActive
        self.onOpenMpr = onOpenMpr
        self.onOpenSegmentation = onOpenSegmentation
    }
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Interactive Tools
                ForEach(ViewerTool.allCases) { tool in
                    Button(action: { activeTool = tool }) {
                        HStack(spacing: 4) {
                            Image(systemName: tool.systemIcon)
                                .font(.system(size: 13))
                            Text(tool.title)
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(activeTool == tool ? MerilTheme.background : MerilTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(activeTool == tool ? MerilTheme.accent : MerilTheme.surface)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(activeTool == tool ? MerilTheme.accent : MerilTheme.border, lineWidth: 1))
                    }
                }
                
                Divider().frame(height: 24).background(MerilTheme.border)
                
                // Action Buttons
                Button(action: onOpenPresets) {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Presets")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(MerilTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(MerilTheme.surface)
                    .cornerRadius(8)
                }
                
                Button(action: onToggleInvert) {
                    Image(systemName: "circle.righthalf.filled.inverse")
                        .font(.system(size: 14))
                        .foregroundColor(MerilTheme.textSecondary)
                        .padding(8)
                        .background(MerilTheme.surface)
                        .cornerRadius(8)
                }
                
                Button(action: onToggleCine) {
                    HStack(spacing: 4) {
                        Image(systemName: isCineActive ? "pause.fill" : "play.fill")
                        Text("Cine")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isCineActive ? MerilTheme.background : MerilTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(isCineActive ? MerilTheme.accent : MerilTheme.surface)
                    .cornerRadius(8)
                }
                
                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 13))
                        .foregroundColor(MerilTheme.textSecondary)
                        .padding(8)
                        .background(MerilTheme.surface)
                        .cornerRadius(8)
                }
                
                Button(action: onOpenMetadata) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(MerilTheme.textSecondary)
                        .padding(8)
                        .background(MerilTheme.surface)
                        .cornerRadius(8)
                }
                
                Divider().frame(height: 24).background(MerilTheme.border)
                
                // Jump to 3D MPR or Segmentation
                Button(action: onOpenMpr) {
                    HStack(spacing: 4) {
                        Image(systemName: "cube.transparent")
                        Text("3D MPR")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(MerilTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(MerilTheme.accent.opacity(0.15))
                    .cornerRadius(8)
                }
                
                Button(action: onOpenSegmentation) {
                    HStack(spacing: 4) {
                        Image(systemName: "paintbrush.pointed.fill")
                        Text("Segment")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(MerilTheme.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(MerilTheme.primary.opacity(0.15))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(MerilTheme.surface.opacity(0.9))
    }
}
