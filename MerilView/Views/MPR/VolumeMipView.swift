import SwiftUI

/// 3D Volume Maximum Intensity Projection (MIP) viewport with interactive touch rotation.
public struct VolumeMipView: View {
    public let mipSlice: MprSliceResult?
    @Binding public var azimuth: Double
    @Binding public var elevation: Double
    public let isMaximized: Bool
    public let onToggleMaximize: () -> Void
    public let onRotate: (Double, Double) -> Void
    
    @State private var dragStartAzimuth: Double = 0
    @State private var dragStartElevation: Double = 0
    
    public init(
        mipSlice: MprSliceResult?,
        azimuth: Binding<Double>,
        elevation: Binding<Double>,
        isMaximized: Bool,
        onToggleMaximize: @escaping () -> Void,
        onRotate: @escaping (Double, Double) -> Void
    ) {
        self.mipSlice = mipSlice
        self._azimuth = azimuth
        self._elevation = elevation
        self.isMaximized = isMaximized
        self.onToggleMaximize = onToggleMaximize
        self.onRotate = onRotate
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                // 1. Rendered 3D MIP Image
                if let slice = mipSlice {
                    Image(uiImage: slice.image)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    ProgressView().tint(MerilTheme.accent)
                }
                
                // 2. Anatomical Orientation Markers
                VStack {
                    Text("S") // Superior
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(MerilTheme.accent.opacity(0.85))
                        .padding(.top, 4)
                    Spacer()
                    Text("I") // Inferior
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(MerilTheme.accent.opacity(0.85))
                        .padding(.bottom, 4)
                }
                
                HStack {
                    Text("R")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(MerilTheme.accent.opacity(0.85))
                        .padding(.leading, 4)
                    Spacer()
                    Text("L")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(MerilTheme.accent.opacity(0.85))
                        .padding(.trailing, 4)
                }
                
                // 3. Header HUD & Controls
                VStack {
                    HStack {
                        HStack(spacing: 6) {
                            Text("3D MIP")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(MerilTheme.accent)
                            
                            Text("\(Int(azimuth))° / \(Int(elevation))°")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(MerilTheme.textSecondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                        
                        Spacer()
                        
                        HStack(spacing: 6) {
                            Button(action: {
                                azimuth = 0
                                elevation = 0
                                onRotate(0, 0)
                            }) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(MerilTheme.textSecondary)
                                    .padding(5)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(4)
                            }
                            
                            Button(action: onToggleMaximize) {
                                Image(systemName: isMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(MerilTheme.textPrimary)
                                    .padding(5)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .padding(6)
                    
                    Spacer()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let dAz = Double(value.translation.width) * 0.8
                        let dEl = Double(-value.translation.height) * 0.8
                        let newAz = (dragStartAzimuth + dAz).truncatingRemainder(dividingBy: 360.0)
                        let newEl = min(45.0, max(-45.0, dragStartElevation + dEl))
                        azimuth = newAz >= 0 ? newAz : (360.0 + newAz)
                        elevation = newEl
                        onRotate(azimuth, elevation)
                    }
                    .onEnded { _ in
                        dragStartAzimuth = azimuth
                        dragStartElevation = elevation
                    }
            )
        }
        .clipped()
        .border(MerilTheme.border, width: 0.5)
    }
}
