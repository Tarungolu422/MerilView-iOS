import Foundation
import UIKit
import CoreGraphics

/// Centralized 3D Labelmap Engine for clinical multi-label segmentation.
public final class MerilLabelmapManager: ObservableObject {
    
    public static let shared = MerilLabelmapManager()
    
    @Published public var segments: [SegmentItem] = SegmentItem.defaultPresets
    @Published public var activeSegmentId: UInt8 = 1
    @Published public var globalOpacity: Double = 0.65
    
    public private(set) var width: Int = 0
    public private(set) var height: Int = 0
    public private(set) var depth: Int = 0
    public private(set) var spacing: Vector3D = Vector3D(1, 1, 1)
    public private(set) var origin: Vector3D = Vector3D(0, 0, 0)
    
    // Contiguous 3D UInt8 scalar label buffer: Index(x, y, z) = z * (W * H) + y * W + x
    private var buffer: [UInt8] = []
    private let queue = DispatchQueue(label: "com.merilview.labelmap", attributes: .concurrent)
    
    private init() {}
    
    /// Initializes or reallocates the 3D labelmap for a given scalar volume.
    public func initialize(for volume: MerilVolumeState) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.width = volume.nx
            self.height = volume.ny
            self.depth = volume.nz
            self.spacing = Vector3D(volume.sx, volume.sy, volume.sz)
            self.origin = volume.origin
            
            let total = volume.nx * volume.ny * volume.nz
            self.buffer = [UInt8](repeating: 0, count: total)
            
            DispatchQueue.main.async {
                self.recalculateVolumes()
            }
        }
    }
    
    public func getVoxel(x: Int, y: Int, z: Int) -> UInt8 {
        queue.sync {
            guard x >= 0, x < width, y >= 0, y < height, z >= 0, z < depth else { return 0 }
            return buffer[z * (width * height) + y * width + x]
        }
    }
    
    public func setVoxel(x: Int, y: Int, z: Int, value: UInt8) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self,
                  x >= 0, x < self.width,
                  y >= 0, y < self.height,
                  z >= 0, z < self.depth else { return }
            
            let idx = z * (self.width * self.height) + y * self.width + x
            self.buffer[idx] = value
        }
    }
    
    // MARK: - Painting Tools
    
    /// Applies 2D or 3D brush stroke with optional CT HU threshold gating.
    public func applyBrush(
        center: Vector3D,
        radiusMm: Double,
        is3D: Bool,
        segmentId: UInt8,
        ctVolume: MerilVolumeState?,
        minHu: Double? = nil,
        maxHu: Double? = nil
    ) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self, self.width > 0, self.height > 0, self.depth > 0 else { return }
            
            // Check if active segment is locked
            if let seg = self.segments.first(where: { $0.id == segmentId }), seg.isLocked {
                return
            }
            
            let cx = Int(center.x)
            let cy = Int(center.y)
            let cz = Int(center.z)
            
            let rxVoxels = max(1, Int(round(radiusMm / self.spacing.x)))
            let ryVoxels = max(1, Int(round(radiusMm / self.spacing.y)))
            let rzVoxels = is3D ? max(1, Int(round(radiusMm / self.spacing.z))) : 0
            
            let minX = max(0, cx - rxVoxels)
            let maxX = min(self.width - 1, cx + rxVoxels)
            let minY = max(0, cy - ryVoxels)
            let maxY = min(self.height - 1, cy + ryVoxels)
            let minZ = max(0, cz - rzVoxels)
            let maxZ = min(self.depth - 1, cz + rzVoxels)
            
            let rxSq = Double(rxVoxels * rxVoxels)
            let rySq = Double(ryVoxels * ryVoxels)
            let rzSq = max(1.0, Double(rzVoxels * rzVoxels))
            
            for z in minZ...maxZ {
                let dz = is3D ? (Double(z - cz) * Double(z - cz)) / rzSq : 0.0
                if dz > 1.0 { continue }
                
                let zOffset = z * (self.width * self.height)
                for y in minY...maxY {
                    let dy = (Double(y - cy) * Double(y - cy)) / rySq
                    if (dy + dz) > 1.0 { continue }
                    
                    let rowOffset = zOffset + y * self.width
                    for x in minX...maxX {
                        let dx = (Double(x - cx) * Double(x - cx)) / rxSq
                        if (dx + dy + dz) <= 1.0 {
                            let idx = rowOffset + x
                            let currentVal = self.buffer[idx]
                            
                            // Check segment lock for existing label
                            if currentVal != 0, let existing = self.segments.first(where: { $0.id == currentVal }), existing.isLocked {
                                continue
                            }
                            
                            // CT HU Threshold Gating
                            if let ct = ctVolume, let minH = minHu, let maxH = maxHu {
                                let hu = Double(ct.voxels[idx])
                                if hu < minH || hu > maxH {
                                    continue
                                }
                            }
                            
                            self.buffer[idx] = segmentId
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.recalculateVolumes()
            }
        }
    }
    
    /// Applies 2D or 3D eraser tool.
    public func applyEraser(center: Vector3D, radiusMm: Double, is3D: Bool, targetSegmentOnly: Bool) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self, self.width > 0, self.height > 0, self.depth > 0 else { return }
            
            let cx = Int(center.x)
            let cy = Int(center.y)
            let cz = Int(center.z)
            
            let rxVoxels = max(1, Int(round(radiusMm / self.spacing.x)))
            let ryVoxels = max(1, Int(round(radiusMm / self.spacing.y)))
            let rzVoxels = is3D ? max(1, Int(round(radiusMm / self.spacing.z))) : 0
            
            let minX = max(0, cx - rxVoxels)
            let maxX = min(self.width - 1, cx + rxVoxels)
            let minY = max(0, cy - ryVoxels)
            let maxY = min(self.height - 1, cy + ryVoxels)
            let minZ = max(0, cz - rzVoxels)
            let maxZ = min(self.depth - 1, cz + rzVoxels)
            
            for z in minZ...maxZ {
                let zOffset = z * (self.width * self.height)
                for y in minY...maxY {
                    let rowOffset = zOffset + y * self.width
                    for x in minX...maxX {
                        let idx = rowOffset + x
                        let currentVal = self.buffer[idx]
                        if currentVal == 0 { continue }
                        
                        if let seg = self.segments.first(where: { $0.id == currentVal }), seg.isLocked {
                            continue
                        }
                        
                        if targetSegmentOnly && currentVal != self.activeSegmentId {
                            continue
                        }
                        
                        self.buffer[idx] = 0
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.recalculateVolumes()
            }
        }
    }
    
    // MARK: - 2D Overlay Rasterization
    
    /// Renders the segmentation overlay for an Axial slice (z) into a 32-bit RGBA UIImage.
    public func renderAxialOverlay(z: Int) -> UIImage? {
        queue.sync {
            guard width > 0, height > 0, z >= 0, z < depth else { return nil }
            var pixels = [UInt32](repeating: 0, count: width * height)
            let zOffset = z * (width * height)
            
            let colorLookup = buildColorTable()
            
            for i in 0..<(width * height) {
                let label = buffer[zOffset + i]
                if label != 0 {
                    pixels[i] = colorLookup[Int(label)]
                }
            }
            
            return createOverlayImage(pixels: &pixels, w: width, h: height)
        }
    }
    
    private func buildColorTable() -> [UInt32] {
        var table = [UInt32](repeating: 0, count: 256)
        for seg in segments {
            guard seg.isVisible else { continue }
            let color = UIColor(hex: seg.colorHex) ?? .red
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            
            let alphaU8 = UInt32(round(globalOpacity * seg.opacity * 255.0))
            let rU8 = UInt32(round(r * 255.0))
            let gU8 = UInt32(round(g * 255.0))
            let bU8 = UInt32(round(b * 255.0))
            
            // 32-bit Little-Endian ARGB: B, G, R, A
            table[Int(seg.id)] = (alphaU8 << 24) | (rU8 << 16) | (gU8 << 8) | bU8
        }
        return table
    }
    
    private func createOverlayImage(pixels: inout [UInt32], w: Int, h: Int) -> UIImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        
        guard let provider = CGDataProvider(data: Data(bytes: &pixels, count: pixels.count * 4) as CFData),
              let cgImage = CGImage(
                width: w,
                height: h,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: w * 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Metric Calculations
    
    private func recalculateVolumes() {
        var counts = [UInt8: Int]()
        for v in buffer where v != 0 {
            counts[v, default: 0] += 1
        }
        
        let voxelVolumeMm3 = spacing.x * spacing.y * spacing.z
        let voxelVolumeCm3 = voxelVolumeMm3 / 1000.0
        
        var updated = segments
        for i in 0..<updated.count {
            let id = updated[i].id
            let cnt = counts[id] ?? 0
            updated[i].voxelCount = cnt
            updated[i].volumeCm3 = Double(cnt) * voxelVolumeCm3
        }
        self.segments = updated
    }
}

// Color hex parser extension
extension UIColor {
    convenience init?(hex: String) {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if clean.hasPrefix("#") { clean.removeFirst() }
        guard clean.count == 6 else { return nil }
        
        var rgbValue: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&rgbValue)
        
        let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgbValue & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
