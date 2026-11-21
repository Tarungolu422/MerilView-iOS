import Foundation
import UIKit
import CoreGraphics
import simd

/// Standard orthogonal and oblique MPR planes.
public enum MprPlaneType: String, CaseIterable, Identifiable {
    case axial
    case coronal
    case sagittal
    case mip
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .axial: return "Axial"
        case .coronal: return "Coronal"
        case .sagittal: return "Sagittal"
        case .mip: return "3D Volume MIP"
        }
    }
}

/// Extracted MPR slice frame result.
public struct MprSliceResult {
    public let plane: MprPlaneType
    public let sliceIndex: Int
    public let totalSlices: Int
    public let width: Int
    public let height: Int
    public let aspect: Double
    public let image: UIImage
    public let topMarker: String
    public let bottomMarker: String
    public let leftMarker: String
    public let rightMarker: String
    public let thicknessMm: Double
}

/// Real-time Multiplanar Reconstruction (MPR) and 3D Volume MIP reslicing engine.
public final class MerilMprReslicer {
    
    // In-memory cache for resliced plates
    private static var sliceCache: [String: MprSliceResult] = [:]
    private static let lock = NSLock()
    
    public static func clearCache() {
        lock.lock()
        sliceCache.removeAll()
        lock.unlock()
    }
    
    /// Reslices an orthogonal plane (Axial, Coronal, Sagittal) from the 3D volume.
    public static func reslicePlane(
        volume: MerilVolumeState,
        plane: MprPlaneType,
        sliceIndex: Int,
        windowCenter: Double = 40.0,
        windowWidth: Double = 400.0,
        invert: Bool = false
    ) -> MprSliceResult? {
        let key = "\(volume.seriesUid):\(plane.rawValue):\(sliceIndex):\(Int(windowCenter)):\(Int(windowWidth)):\(invert)"
        
        lock.lock()
        if let cached = sliceCache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        
        let nx = volume.nx
        let ny = volume.ny
        let nz = volume.nz
        let sx = volume.sx
        let sy = volume.sy
        let sz = volume.sz
        let voxels = volume.voxels
        
        let halfW = max(1.0, windowWidth) / 2.0
        let minHu = windowCenter - halfW
        let maxHu = windowCenter + halfW
        let huRange = max(1.0, maxHu - minHu)
        let invHuRange = 255.0 / huRange
        
        let width: Int
        let height: Int
        let actualSliceIndex: Int
        let totalSlices: Int
        let topMarker: String
        let bottomMarker: String
        let leftMarker: String
        let rightMarker: String
        let thicknessMm: Double
        var outPixels: [UInt32]
        
        switch plane {
        case .axial:
            actualSliceIndex = min(nz - 1, max(0, sliceIndex))
            totalSlices = nz
            width = nx
            height = ny
            topMarker = "A"
            bottomMarker = "P"
            leftMarker = "R"
            rightMarker = "L"
            thicknessMm = sz
            outPixels = [UInt32](repeating: 0, count: width * height)
            
            let zOffset = actualSliceIndex * (nx * ny)
            for y in 0..<height {
                let rowOffset = y * width
                let srcRowOffset = zOffset + y * nx
                for x in 0..<width {
                    let hu = Double(voxels[srcRowOffset + x])
                    var gray = Int((hu - minHu) * invHuRange)
                    if gray < 0 { gray = 0 }
                    else if gray > 255 { gray = 255 }
                    if invert { gray = 255 - gray }
                    
                    let u8 = UInt32(gray)
                    outPixels[rowOffset + x] = (0xFF << 24) | (u8 << 16) | (u8 << 8) | u8
                }
            }
            
        case .coronal:
            actualSliceIndex = min(ny - 1, max(0, sliceIndex))
            totalSlices = ny
            width = nx
            let physicalHeightMm = Double(nz) * sz
            height = max(nz, min(512, Int(round(physicalHeightMm / sx))))
            topMarker = "S"
            bottomMarker = "I"
            leftMarker = "R"
            rightMarker = "L"
            thicknessMm = sy
            outPixels = [UInt32](repeating: 0, count: width * height)
            
            let zStep = Double(nz - 1) / max(1.0, Double(height - 1))
            for d in 0..<height {
                let continuousZ = Double(height - 1 - d) * zStep
                let z0 = min(nz - 1, max(0, Int(continuousZ)))
                let z1 = min(nz - 1, z0 + 1)
                let alpha = continuousZ - Double(z0)
                
                let z0Offset = z0 * (nx * ny) + actualSliceIndex * nx
                let z1Offset = z1 * (nx * ny) + actualSliceIndex * nx
                let destRowOffset = d * width
                
                for x in 0..<width {
                    let hu0 = Double(voxels[z0Offset + x])
                    let hu1 = Double(voxels[z1Offset + x])
                    let hu = (1.0 - alpha) * hu0 + alpha * hu1
                    
                    var gray = Int((hu - minHu) * invHuRange)
                    if gray < 0 { gray = 0 }
                    else if gray > 255 { gray = 255 }
                    if invert { gray = 255 - gray }
                    
                    let u8 = UInt32(gray)
                    outPixels[destRowOffset + x] = (0xFF << 24) | (u8 << 16) | (u8 << 8) | u8
                }
            }
            
        case .sagittal:
            actualSliceIndex = min(nx - 1, max(0, sliceIndex))
            totalSlices = nx
            width = ny
            let physicalHeightMm = Double(nz) * sz
            height = max(nz, min(512, Int(round(physicalHeightMm / sy))))
            topMarker = "S"
            bottomMarker = "I"
            leftMarker = "A"
            rightMarker = "P"
            thicknessMm = sx
            outPixels = [UInt32](repeating: 0, count: width * height)
            
            let zStep = Double(nz - 1) / max(1.0, Double(height - 1))
            for d in 0..<height {
                let continuousZ = Double(height - 1 - d) * zStep
                let z0 = min(nz - 1, max(0, Int(continuousZ)))
                let z1 = min(nz - 1, z0 + 1)
                let alpha = continuousZ - Double(z0)
                
                let z0Base = z0 * (nx * ny) + actualSliceIndex
                let z1Base = z1 * (nx * ny) + actualSliceIndex
                let destRowOffset = d * width
                
                for y in 0..<width {
                    let hu0 = Double(voxels[z0Base + y * nx])
                    let hu1 = Double(voxels[z1Base + y * nx])
                    let hu = (1.0 - alpha) * hu0 + alpha * hu1
                    
                    var gray = Int((hu - minHu) * invHuRange)
                    if gray < 0 { gray = 0 }
                    else if gray > 255 { gray = 255 }
                    if invert { gray = 255 - gray }
                    
                    let u8 = UInt32(gray)
                    outPixels[destRowOffset + y] = (0xFF << 24) | (u8 << 16) | (u8 << 8) | u8
                }
            }
            
        case .mip:
            return generateVolumeMip(volume: volume, windowCenter: windowCenter, windowWidth: windowWidth)
        }
        
        guard let uiImage = createUIImage(pixels: &outPixels, width: width, height: height) else {
            return nil
        }
        
        let result = MprSliceResult(
            plane: plane,
            sliceIndex: actualSliceIndex,
            totalSlices: totalSlices,
            width: width,
            height: height,
            aspect: Double(width) / Double(height),
            image: uiImage,
            topMarker: topMarker,
            bottomMarker: bottomMarker,
            leftMarker: leftMarker,
            rightMarker: rightMarker,
            thicknessMm: thicknessMm
        )
        
        lock.lock()
        if sliceCache.count > 120 {
            sliceCache.removeAll()
        }
        sliceCache[key] = result
        lock.unlock()
        
        return result
    }
    
    /// Generates a 3D Volume Maximum Intensity Projection (MIP) with arbitrary rotation.
    public static func generateVolumeMip(
        volume: MerilVolumeState,
        azimuthDeg: Double = 0.0,
        elevationDeg: Double = 0.0,
        windowCenter: Double = 300.0,
        windowWidth: Double = 1500.0
    ) -> MprSliceResult? {
        let normAz = ((azimuthDeg.truncatingRemainder(dividingBy: 360.0)) + 360.0).truncatingRemainder(dividingBy: 360.0)
        let angleInt = (Int(round(normAz / 5.0)) * 5) % 360
        let elevInt = min(45, max(-45, Int(round(elevationDeg / 5.0)) * 5))
        
        let key = "mip:\(volume.seriesUid):\(angleInt):\(elevInt):\(Int(windowCenter)):\(Int(windowWidth))"
        
        lock.lock()
        if let cached = sliceCache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        
        let nx = volume.nx
        let ny = volume.ny
        let nz = volume.nz
        let sx = volume.sx
        let sz = volume.sz
        let voxels = volume.voxels
        
        let width = nx
        let physicalHeightMm = Double(nz) * sz
        let height = max(nz, min(512, Int(round(physicalHeightMm / sx))))
        
        let halfW = max(1.0, windowWidth) / 2.0
        let minHu = windowCenter - halfW
        let maxHu = windowCenter + halfW
        let huRange = max(1.0, maxHu - minHu)
        let invHuRange = 255.0 / huRange
        
        var outPixels = [UInt32](repeating: 0, count: width * height)
        let zStep = Double(nz - 1) / max(1.0, Double(height - 1))
        
        let radAz = Double(angleInt) * .pi / 180.0
        let cosAz = cos(radAz)
        let sinAz = sin(radAz)
        
        let cx = Double(nx - 1) / 2.0
        let cy = Double(ny - 1) / 2.0
        let maxRadius = sqrt(Double(nx * nx + ny * ny)) / 2.0
        let numSteps = min(256, max(64, Int(maxRadius * 2.0)))
        let stepSize = (maxRadius * 2.0) / Double(numSteps)
        
        for d in 0..<height {
            let continuousZ = Double(height - 1 - d) * zStep
            let z = min(nz - 1, max(0, Int(round(continuousZ))))
            let zOffset = z * (nx * ny)
            let destRowOffset = d * width
            
            for u in 0..<width {
                let uPrime = Double(u) - cx
                var maxHuFound: Int16 = -2048
                
                for step in 0..<numSteps {
                    let s = -maxRadius + Double(step) * stepSize
                    let vx = Int(round(cx + uPrime * cosAz - s * sinAz))
                    let vy = Int(round(cy + uPrime * sinAz + s * cosAz))
                    
                    if vx >= 0 && vx < nx && vy >= 0 && vy < ny {
                        let hu = voxels[zOffset + vy * nx + vx]
                        if hu > maxHuFound {
                            maxHuFound = hu
                        }
                    }
                }
                
                var gray = Int((Double(maxHuFound) - minHu) * invHuRange)
                if gray < 0 { gray = 0 }
                else if gray > 255 { gray = 255 }
                
                let u8 = UInt32(gray)
                outPixels[destRowOffset + u] = (0xFF << 24) | (u8 << 16) | (u8 << 8) | u8
            }
        }
        
        guard let uiImage = createUIImage(pixels: &outPixels, width: width, height: height) else {
            return nil
        }
        
        let result = MprSliceResult(
            plane: .mip,
            sliceIndex: angleInt,
            totalSlices: 360,
            width: width,
            height: height,
            aspect: Double(width) / Double(height),
            image: uiImage,
            topMarker: "S",
            bottomMarker: "I",
            leftMarker: "R",
            rightMarker: "L",
            thicknessMm: sz
        )
        
        lock.lock()
        sliceCache[key] = result
        lock.unlock()
        
        return result
    }
    
    private static func createUIImage(pixels: inout [UInt32], width: Int, height: Int) -> UIImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue
        
        guard let provider = CGDataProvider(data: Data(bytes: &pixels, count: pixels.count * 4) as CFData) else {
            return nil
        }
        
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
}
