import Foundation

/// Active segmentation tool modes.
public enum SegmentationTool: String, CaseIterable, Identifiable {
    case brush2D = "brush2d"
    case brush3D = "brush3d"
    case eraser = "eraser"
    case threshold = "threshold"
    case scissors = "scissors"
    case regionGrow = "region_grow"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .brush2D: return "2D Brush"
        case .brush3D: return "3D Sphere"
        case .eraser: return "Eraser"
        case .threshold: return "CT Threshold"
        case .scissors: return "Scissors"
        case .regionGrow: return "Region Grow"
        }
    }
    
    public var systemIcon: String {
        switch self {
        case .brush2D: return "paintbrush.pointed"
        case .brush3D: return "circle.circle"
        case .eraser: return "eraser"
        case .threshold: return "slider.horizontal.2"
        case .scissors: return "scissors"
        case .regionGrow: return "waveform.path.ecg"
        }
    }
}

/// Standard CT Hounsfield Unit Threshold Presets
public struct ThresholdPreset: Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public let minHu: Double
    public let maxHu: Double
    
    public static let standardPresets: [ThresholdPreset] = [
        ThresholdPreset(name: "Bone / Calcinosis", minHu: 200, maxHu: 2000),
        ThresholdPreset(name: "Cortical Bone / Metal", minHu: 500, maxHu: 3000),
        ThresholdPreset(name: "Soft Tissue / Organs", minHu: -50, maxHu: 150),
        ThresholdPreset(name: "Liver Parenchyma", minHu: 40, maxHu: 90),
        ThresholdPreset(name: "Lung Parenchyma", minHu: -950, maxHu: -400),
        ThresholdPreset(name: "Fat / Adipose", minHu: -120, maxHu: -50),
        ThresholdPreset(name: "Custom Full Range", minHu: -1000, maxHu: 3000)
    ]
}

/// Individual anatomical segment in the labelmap (matching OHIF segmentation item).
public struct SegmentItem: Identifiable, Codable, Hashable {
    public let id: UInt8 // 1 ... 255 unique label index (0 = background)
    public var label: String
    public var colorHex: String
    public var opacity: Double
    public var isVisible: Bool
    public var isLocked: Bool
    public var voxelCount: Int
    public var volumeCm3: Double
    
    public init(
        id: UInt8,
        label: String,
        colorHex: String,
        opacity: Double = 0.65,
        isVisible: Bool = true,
        isLocked: Bool = false,
        voxelCount: Int = 0,
        volumeCm3: Double = 0.0
    ) {
        self.id = id
        self.label = label
        self.colorHex = colorHex
        self.opacity = opacity
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.voxelCount = voxelCount
        self.volumeCm3 = volumeCm3
    }
    
    public static let defaultPresets: [SegmentItem] = [
        SegmentItem(id: 1, label: "Liver Parenchyma", colorHex: "#FF5252"),
        SegmentItem(id: 2, label: "Spleen", colorHex: "#448AFF"),
        SegmentItem(id: 3, label: "Kidneys (Bilateral)", colorHex: "#69F0AE"),
        SegmentItem(id: 4, label: "Tumor / Lesion", colorHex: "#FFD740"),
        SegmentItem(id: 5, label: "Vascular Tree", colorHex: "#E040FB"),
        SegmentItem(id: 6, label: "Bone Structure", colorHex: "#EEEEEE")
    ]
}
