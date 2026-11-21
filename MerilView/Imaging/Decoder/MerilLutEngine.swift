import Foundation
import UIKit

/// Clinical window presets for medical imaging.
public enum WindowPreset: String, CaseIterable, Identifiable {
    case abdomen = "Abdomen"
    case lung = "Lung"
    case bone = "Bone"
    case brain = "Brain"
    case angiography = "Angiography"
    case mediastinum = "Mediastinum"
    case softTissue = "Soft Tissue"
    
    public var id: String { rawValue }
    
    public var center: Double {
        switch self {
        case .abdomen: return 40.0
        case .lung: return -600.0
        case .bone: return 300.0
        case .brain: return 40.0
        case .angiography: return 200.0
        case .mediastinum: return 50.0
        case .softTissue: return 40.0
        }
    }
    
    public var width: Double {
        switch self {
        case .abdomen: return 400.0
        case .lung: return 1500.0
        case .bone: return 2000.0
        case .brain: return 80.0
        case .angiography: return 600.0
        case .mediastinum: return 350.0
        case .softTissue: return 350.0
        }
    }
}

/// High-performance 16-bit to 8-bit Window/Level Lookup Table (LUT) engine.
public final class MerilLutEngine {
    
    private static let lock = NSLock()
    private static var lutCache: [String: [UInt32]] = [:]
    
    /// Generates or fetches a cached 65,536-entry 32-bit packed ARGB/RGBA color table.
    public static func getOrCreateLut(
        center: Double,
        width: Double,
        slope: Double = 1.0,
        intercept: Double = 0.0,
        invert: Bool = false,
        isSigned: Bool = false
    ) -> [UInt32] {
        let key = "\(Int(center)):\(Int(width)):\(slope):\(intercept):\(invert):\(isSigned)"
        
        lock.lock()
        if let cached = lutCache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        
        let halfW = max(1.0, width) / 2.0
        let minHu = center - halfW
        let maxHu = center + halfW
        let huRange = max(1.0, maxHu - minHu)
        let invHuRange = 255.0 / huRange
        
        var lut = [UInt32](repeating: 0, count: 65536)
        
        for rawU16 in 0..<65536 {
            let raw: Double
            if isSigned {
                let s16 = Int16(bitPattern: UInt16(rawU16))
                raw = Double(s16)
            } else {
                raw = Double(rawU16)
            }
            
            let hu = raw * slope + intercept
            var gray = Int((hu - minHu) * invHuRange)
            if gray < 0 { gray = 0 }
            else if gray > 255 { gray = 255 }
            
            if invert {
                gray = 255 - gray
            }
            
            let u8 = UInt32(gray)
            // 32-bit ARGB little-endian (Blue, Green, Red, Alpha)
            let pixel = (0xFF << 24) | (u8 << 16) | (u8 << 8) | u8
            lut[rawU16] = pixel
        }
        
        lock.lock()
        if lutCache.count > 128 {
            lutCache.removeAll()
        }
        lutCache[key] = lut
        lock.unlock()
        
        return lut
    }
}
