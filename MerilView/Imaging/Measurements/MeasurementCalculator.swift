import Foundation
import simd

/// Calibrated clinical measurement calculator using DICOM pixel spacing and physical geometry.
public final class MeasurementCalculator {
    
    /// Calculates Euclidean length in millimeters between two normalized points.
    public static func calculateLengthMm(
        p1: NormalizedPoint,
        p2: NormalizedPoint,
        rows: Int,
        cols: Int,
        pixelSpacing: [Double]
    ) -> Double {
        let sx = pixelSpacing.first ?? 1.0
        let sy = pixelSpacing.count > 1 ? pixelSpacing[1] : 1.0
        
        let dxMm = (p2.x - p1.x) * Double(cols) * sx
        let dyMm = (p2.y - p1.y) * Double(rows) * sy
        
        return sqrt(dxMm * dxMm + dyMm * dyMm)
    }
    
    /// Calculates angle in degrees given vertex point B and ray points A and C.
    public static func calculateAngleDeg(
        a: NormalizedPoint,
        b: NormalizedPoint, // vertex
        c: NormalizedPoint,
        rows: Int,
        cols: Int,
        pixelSpacing: [Double]
    ) -> Double {
        let sx = pixelSpacing.first ?? 1.0
        let sy = pixelSpacing.count > 1 ? pixelSpacing[1] : 1.0
        
        let v1 = SIMD2<Double>((a.x - b.x) * Double(cols) * sx, (a.y - b.y) * Double(rows) * sy)
        let v2 = SIMD2<Double>((c.x - b.x) * Double(cols) * sx, (c.y - b.y) * Double(rows) * sy)
        
        let len1 = simd_length(v1)
        let len2 = simd_length(v2)
        guard len1 > 1e-4, len2 > 1e-4 else { return 0.0 }
        
        let cosTheta = min(1.0, max(-1.0, simd_dot(v1, v2) / (len1 * len2)))
        return acos(cosTheta) * 180.0 / .pi
    }
    
    /// Evaluates scalar HU metrics (Mean, Min, Max, SD, Area) inside an elliptical ROI.
    public static func calculateEllipseStats(
        center: NormalizedPoint,
        rx: Double,
        ry: Double,
        pixels: [Int16],
        rows: Int,
        cols: Int,
        pixelSpacing: [Double]
    ) -> (areaMm2: Double, mean: Double, minVal: Double, maxVal: Double, stdDev: Double, count: Int) {
        let sx = pixelSpacing.first ?? 1.0
        let sy = pixelSpacing.count > 1 ? pixelSpacing[1] : 1.0
        
        let cxPixel = center.x * Double(cols)
        let cyPixel = center.y * Double(rows)
        let rxPixel = max(1.0, rx * Double(cols))
        let ryPixel = max(1.0, ry * Double(rows))
        
        let areaMm2 = .pi * rxPixel * sx * ryPixel * sy
        
        let minX = max(0, Int(floor(cxPixel - rxPixel)))
        let maxX = min(cols - 1, Int(ceil(cxPixel + rxPixel)))
        let minY = max(0, Int(floor(cyPixel - ryPixel)))
        let maxY = min(rows - 1, Int(ceil(cyPixel + ryPixel)))
        
        var sum = 0.0
        var sumSq = 0.0
        var minHu = Double.infinity
        var maxHu = -Double.infinity
        var count = 0
        
        for y in minY...maxY {
            let dy = (Double(y) - cyPixel) / ryPixel
            let dySq = dy * dy
            if dySq > 1.0 { continue }
            
            let rowOffset = y * cols
            for x in minX...maxX {
                let dx = (Double(x) - cxPixel) / rxPixel
                if (dx * dx + dySq) <= 1.0 {
                    let hu = Double(pixels[rowOffset + x])
                    sum += hu
                    sumSq += hu * hu
                    if hu < minHu { minHu = hu }
                    if hu > maxHu { maxHu = hu }
                    count += 1
                }
            }
        }
        
        guard count > 0 else {
            return (areaMm2, 0, 0, 0, 0, 0)
        }
        
        let mean = sum / Double(count)
        let variance = max(0.0, (sumSq / Double(count)) - (mean * mean))
        let stdDev = sqrt(variance)
        
        return (areaMm2, mean, minHu, maxHu, stdDev, count)
    }
    
    /// Evaluates scalar HU metrics inside a rectangular ROI.
    public static func calculateRectangleStats(
        topLeft: NormalizedPoint,
        width: Double,
        height: Double,
        pixels: [Int16],
        rows: Int,
        cols: Int,
        pixelSpacing: [Double]
    ) -> (areaMm2: Double, mean: Double, minVal: Double, maxVal: Double, stdDev: Double, count: Int) {
        let sx = pixelSpacing.first ?? 1.0
        let sy = pixelSpacing.count > 1 ? pixelSpacing[1] : 1.0
        
        let x0 = max(0, Int(floor(topLeft.x * Double(cols))))
        let y0 = max(0, Int(floor(topLeft.y * Double(rows))))
        let x1 = min(cols - 1, Int(ceil((topLeft.x + width) * Double(cols))))
        let y1 = min(rows - 1, Int(ceil((topLeft.y + height) * Double(rows))))
        
        let areaMm2 = Double(x1 - x0) * sx * Double(y1 - y0) * sy
        
        var sum = 0.0
        var sumSq = 0.0
        var minHu = Double.infinity
        var maxHu = -Double.infinity
        var count = 0
        
        for y in y0...y1 {
            let rowOffset = y * cols
            for x in x0...x1 {
                let hu = Double(pixels[rowOffset + x])
                sum += hu
                sumSq += hu * hu
                if hu < minHu { minHu = hu }
                if hu > maxHu { maxHu = hu }
                count += 1
            }
        }
        
        guard count > 0 else {
            return (areaMm2, 0, 0, 0, 0, 0)
        }
        
        let mean = sum / Double(count)
        let variance = max(0.0, (sumSq / Double(count)) - (mean * mean))
        let stdDev = sqrt(variance)
        
        return (areaMm2, mean, minHu, maxHu, stdDev, count)
    }
}
