import SwiftUI

/// Single MPR orthogonal plane viewport with orientation labels, HUD, and crosshairs.
public struct MprSinglePlaneView: View {
    public let plane: MprPlaneType
    public let sliceResult: MprSliceResult?
    public let crosshairNormX: Double
    public let crosshairNormY: Double
    public let isMaximized: Bool
    public let interactMode: String // "crosshair" or "scroll"
    public let onMoveCrosshair: (Double, Double) -> Void
    public let onScrollSlice: (Int) -> Void
    public let onToggleMaximize: () -> Void
    
    public init(
        plane: MprPlaneType,
        sliceResult: MprSliceResult?,
        crosshairNormX: Double,
        crosshairNormY: Double,
        isMaximized: Bool,
        interactMode: String,
        onMoveCrosshair: @escaping (Double, Double) -> Void,
        onScrollSlice: @escaping (Int) -> Void,
        onToggleMaximize: @escaping () -> Void
    ) {
        self.plane = plane
        self.sliceResult = sliceResult
        self.crosshairNormX = crosshairNormX
        self.crosshairNormY = crosshairNormY
        self.isMaximized = isMaximized
        self.interactMode = interactMode
        self.onMoveCrosshair = onMoveCrosshair
        self.onScrollSlice = onScrollSlice
        self.onToggleMaximize = onToggleMaximize
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                // 1. Image Surface
                if let res = sliceResult {
                    Image(uiImage: res.image)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    ProgressView().tint(MerilTheme.accent)
                }
                
                // 2. Synchronized Crosshair Overlay
                CrosshairOverlayView(
                    plane: plane,
                    normX: crosshairNormX,
                    normY: crosshairNormY,
                    isMaximized: isMaximized
                )
                
                // 3. Anatomical Orientation Markers
                if let res = sliceResult {
                    VStack {
                        Text(res.topMarker)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(MerilTheme.accent.opacity(0.85))
                            .padding(.top, 4)
                        Spacer()
                        Text(res.bottomMarker)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(MerilTheme.accent.opacity(0.85))
                            .padding(.bottom, 4)
                    }
                    
                    HStack {
                        Text(res.leftMarker)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(MerilTheme.accent.opacity(0.85))
                            .padding(.leading, 4)
                        Spacer()
                        Text(res.rightMarker)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(MerilTheme.accent.opacity(0.85))
                            .padding(.trailing, 4)
                    }
                }
                
                // 4. Header HUD & Maximize Button
                VStack {
                    HStack {
                        HStack(spacing: 6) {
                            Text(plane.title.uppercased())
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(planeBadgeColor(for: plane))
                            
                            if let res = sliceResult {
                                Text("\(res.sliceIndex + 1)/\(res.totalSlices)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(MerilTheme.textSecondary)
                                Text(String(format: "%.1fmm", res.thicknessMm))
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(MerilTheme.textMuted)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                        
                        Spacer()
                        
                        Button(action: onToggleMaximize) {
                            Image(systemName: isMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(MerilTheme.textPrimary)
                                .padding(5)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(4)
                        }
                    }
                    .padding(6)
                    
                    Spacer()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if interactMode == "crosshair" {
                            let nx = min(1.0, max(0.0, value.location.x / geometry.size.width))
                            let ny = min(1.0, max(0.0, value.location.y / geometry.size.height))
                            onMoveCrosshair(nx, ny)
                        } else {
                            let dy = value.translation.height
                            let step = Int(-dy / 10.0)
                            if step != 0 {
                                onScrollSlice(step)
                            }
                        }
                    }
            )
        }
        .clipped()
        .border(MerilTheme.border, width: 0.5)
    }
    
    private func planeBadgeColor(for plane: MprPlaneType) -> Color {
        switch plane {
        case .axial: return Color.green
        case .coronal: return Color.blue
        case .sagittal: return Color.orange
        case .mip: return MerilTheme.accent
        }
    }
}
