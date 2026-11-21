import SwiftUI

/// Canvas overlay for rendering calibrated DICOM measurements and annotations.
public struct MeasurementOverlayView: View {
    public let measurements: [DicomMeasurement]
    public let activeTool: ViewerTool
    public let currentPoints: [NormalizedPoint]
    public let size: CGSize
    
    public init(
        measurements: [DicomMeasurement],
        activeTool: ViewerTool,
        currentPoints: [NormalizedPoint],
        size: CGSize
    ) {
        self.measurements = measurements
        self.activeTool = activeTool
        self.currentPoints = currentPoints
        self.size = size
    }
    
    public var body: some View {
        Canvas { context, canvasSize in
            // 1. Draw existing committed measurements
            for m in measurements {
                let color = Color(hex: m.colorHex)
                
                switch m.type {
                case .length:
                    if m.points.count >= 2 {
                        let p1 = CGPoint(x: m.points[0].x * canvasSize.width, y: m.points[0].y * canvasSize.height)
                        let p2 = CGPoint(x: m.points[1].x * canvasSize.width, y: m.points[1].y * canvasSize.height)
                        
                        var path = Path()
                        path.move(to: p1)
                        path.addLine(to: p2)
                        context.stroke(path, with: .color(color), lineWidth: 2)
                        
                        // Caliper end ticks
                        drawCaliperTick(context: context, p: p1, target: p2, color: color)
                        drawCaliperTick(context: context, p: p2, target: p1, color: color)
                        
                        // Text label
                        let mid = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
                        context.draw(Text(m.displayLabel).font(.system(size: 11, weight: .bold)).foregroundColor(color), at: mid)
                    }
                    
                case .angle:
                    if m.points.count >= 3 {
                        let p1 = CGPoint(x: m.points[0].x * canvasSize.width, y: m.points[0].y * canvasSize.height)
                        let vertex = CGPoint(x: m.points[1].x * canvasSize.width, y: m.points[1].y * canvasSize.height)
                        let p2 = CGPoint(x: m.points[2].x * canvasSize.width, y: m.points[2].y * canvasSize.height)
                        
                        var path = Path()
                        path.move(to: p1)
                        path.addLine(to: vertex)
                        path.addLine(to: p2)
                        context.stroke(path, with: .color(color), lineWidth: 2)
                        
                        context.draw(Text(m.displayLabel).font(.system(size: 11, weight: .bold)).foregroundColor(color), at: vertex)
                    }
                    
                case .ellipseRoi:
                    if m.points.count >= 2 {
                        let p1 = CGPoint(x: m.points[0].x * canvasSize.width, y: m.points[0].y * canvasSize.height)
                        let p2 = CGPoint(x: m.points[1].x * canvasSize.width, y: m.points[1].y * canvasSize.height)
                        let rect = CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p2.x - p1.x), height: abs(p2.y - p1.y))
                        
                        context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: 2)
                        context.draw(Text(m.displayLabel).font(.system(size: 11, weight: .bold)).foregroundColor(color), at: CGPoint(x: rect.midX, y: rect.maxY + 14))
                    }
                    
                case .rectangleRoi:
                    if m.points.count >= 2 {
                        let p1 = CGPoint(x: m.points[0].x * canvasSize.width, y: m.points[0].y * canvasSize.height)
                        let p2 = CGPoint(x: m.points[1].x * canvasSize.width, y: m.points[1].y * canvasSize.height)
                        let rect = CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p2.x - p1.x), height: abs(p2.y - p1.y))
                        
                        context.stroke(Path(rect), with: .color(color), lineWidth: 2)
                        context.draw(Text(m.displayLabel).font(.system(size: 11, weight: .bold)).foregroundColor(color), at: CGPoint(x: rect.midX, y: rect.maxY + 14))
                    }
                }
            }
            
            // 2. Draw active in-progress shape
            if currentPoints.count >= 2 {
                let p1 = CGPoint(x: currentPoints[0].x * canvasSize.width, y: currentPoints[0].y * canvasSize.height)
                let p2 = CGPoint(x: currentPoints[1].x * canvasSize.width, y: currentPoints[1].y * canvasSize.height)
                let draftColor = MerilTheme.accent
                
                switch activeTool {
                case .length:
                    var path = Path()
                    path.move(to: p1)
                    path.addLine(to: p2)
                    context.stroke(path, with: .color(draftColor), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                case .ellipseRoi:
                    let rect = CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p2.x - p1.x), height: abs(p2.y - p1.y))
                    context.stroke(Path(ellipseIn: rect), with: .color(draftColor), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                case .rectangleRoi:
                    let rect = CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p2.x - p1.x), height: abs(p2.y - p1.y))
                    context.stroke(Path(rect), with: .color(draftColor), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                default:
                    break
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private func drawCaliperTick(context: GraphicsContext, p: CGPoint, target: CGPoint, color: Color) {
        let dx = target.x - p.x
        let dy = target.y - p.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 1e-4 else { return }
        
        // Orthogonal tick vector
        let perpX = -dy / len * 6
        let perpY = dx / len * 6
        
        var tick = Path()
        tick.move(to: CGPoint(x: p.x - perpX, y: p.y - perpY))
        tick.addLine(to: CGPoint(x: p.x + perpX, y: p.y + perpY))
        context.stroke(tick, with: .color(color), lineWidth: 2)
    }
}
