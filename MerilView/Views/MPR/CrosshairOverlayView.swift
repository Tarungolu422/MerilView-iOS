import SwiftUI

/// Synchronized reference crosshair lines mapped in Patient LPS space.
public struct CrosshairOverlayView: View {
    public let plane: MprPlaneType
    public let normX: Double // 0.0 ... 1.0 (horizontal position)
    public let normY: Double // 0.0 ... 1.0 (vertical position)
    public let rotAngleDeg: Double
    public let isMaximized: Bool
    
    public init(
        plane: MprPlaneType,
        normX: Double,
        normY: Double,
        rotAngleDeg: Double = 0.0,
        isMaximized: Bool = false
    ) {
        self.plane = plane
        self.normX = normX
        self.normY = normY
        self.rotAngleDeg = rotAngleDeg
        self.isMaximized = isMaximized
    }
    
    public var body: some View {
        Canvas { context, size in
            guard plane != .mip else { return }
            
            let cx = normX * size.width
            let cy = normY * size.height
            
            // Standard clinical MPR crosshair colors:
            // Axial: Horizontal = Coronal (Green), Vertical = Sagittal (Yellow/Red)
            // Coronal: Horizontal = Axial (Blue), Vertical = Sagittal (Yellow/Red)
            // Sagittal: Horizontal = Axial (Blue), Vertical = Coronal (Green)
            let (hColor, vColor) = getLineColors(for: plane)
            
            // Horizontal Reference Line
            var hLine = Path()
            hLine.move(to: CGPoint(x: 0, y: cy))
            hLine.addLine(to: CGPoint(x: size.width, y: cy))
            context.stroke(hLine, with: .color(hColor.opacity(0.85)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 2]))
            
            // Vertical Reference Line
            var vLine = Path()
            vLine.move(to: CGPoint(x: cx, y: 0))
            vLine.addLine(to: CGPoint(x: cx, y: size.height))
            context.stroke(vLine, with: .color(vColor.opacity(0.85)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 2]))
            
            // Intersection Center Circle
            let circleRect = CGRect(x: cx - 6, y: cy - 6, width: 12, height: 12)
            context.stroke(Path(ellipseIn: circleRect), with: .color(MerilTheme.accent), lineWidth: 1.5)
        }
        .allowsHitTesting(false)
    }
    
    private func getLineColors(for plane: MprPlaneType) -> (Color, Color) {
        switch plane {
        case .axial:
            return (Color.green, Color.orange)
        case .coronal:
            return (Color.blue, Color.orange)
        case .sagittal:
            return (Color.blue, Color.green)
        case .mip:
            return (Color.clear, Color.clear)
        }
    }
}
