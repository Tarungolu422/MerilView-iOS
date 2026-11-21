import Foundation

/// Active annotation tool modes.
public enum AnnotationTool: String, CaseIterable, Identifiable {
    case navigate = "navigate"
    case select = "select"
    case rectangle = "rectangle"
    case ellipse = "ellipse"
    case arrow = "arrow"
    case pin = "pin"
    case freeform = "freeform"
    case text = "text"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .navigate: return "Navigate"
        case .select: return "Select"
        case .rectangle: return "Rectangle"
        case .ellipse: return "Ellipse"
        case .arrow: return "Arrow"
        case .pin: return "Pin"
        case .freeform: return "Freehand"
        case .text: return "Text"
        }
    }
    
    public var systemIcon: String {
        switch self {
        case .navigate: return "hand.draw"
        case .select: return "arrow.up.left.and.down.right.magnifyingglass"
        case .rectangle: return "rectangle"
        case .ellipse: return "oval"
        case .arrow: return "arrow.up.right"
        case .pin: return "pin.fill"
        case .freeform: return "pencil.tip"
        case .text: return "textformat"
        }
    }
}

/// DICOM Graphic Type (PS 3.3 C.10.5)
public enum DicomGraphicType: String, Codable {
    case point = "POINT"
    case polyline = "POLYLINE"
    case rectangle = "RECTANGLE"
    case ellipse = "ELLIPSE"
    case text = "TEXT"
}

/// Unified clinical annotation model conforming to DICOM GSPS.
public struct DicomAnnotation: Identifiable, Codable, Hashable {
    public let id: String
    public var tool: String // rectangle, ellipse, arrow, pin, freeform, text
    public var graphicType: DicomGraphicType
    public let studyInstanceUid: String
    public let seriesInstanceUid: String
    public let sopInstanceUid: String?
    public var sliceIndex: Int
    public var colorHex: String
    public var lineWidth: Double
    public var label: String?
    public var comment: String?
    public var measurementText: String?
    
    // Geometry parameters in normalized coordinates [0.0 ... 1.0]
    public var points: [NormalizedPoint]
    public var rectX: Double?
    public var rectY: Double?
    public var rectW: Double?
    public var rectH: Double?
    
    public var ellipseCx: Double?
    public var ellipseCy: Double?
    public var ellipseRx: Double?
    public var ellipseRy: Double?
    
    public var arrowStartX: Double?
    public var arrowStartY: Double?
    public var arrowEndX: Double?
    public var arrowEndY: Double?
    
    public var textString: String?
    public var fontSize: Double?
    
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        tool: String,
        graphicType: DicomGraphicType,
        studyInstanceUid: String,
        seriesInstanceUid: String,
        sopInstanceUid: String? = nil,
        sliceIndex: Int,
        colorHex: String = "#00E5FF",
        lineWidth: Double = 2.0,
        label: String? = nil,
        comment: String? = nil,
        measurementText: String? = nil,
        points: [NormalizedPoint] = [],
        rectX: Double? = nil,
        rectY: Double? = nil,
        rectW: Double? = nil,
        rectH: Double? = nil,
        ellipseCx: Double? = nil,
        ellipseCy: Double? = nil,
        ellipseRx: Double? = nil,
        ellipseRy: Double? = nil,
        arrowStartX: Double? = nil,
        arrowStartY: Double? = nil,
        arrowEndX: Double? = nil,
        arrowEndY: Double? = nil,
        textString: String? = nil,
        fontSize: Double? = 14.0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.tool = tool
        self.graphicType = graphicType
        self.studyInstanceUid = studyInstanceUid
        self.seriesInstanceUid = seriesInstanceUid
        self.sopInstanceUid = sopInstanceUid
        self.sliceIndex = sliceIndex
        self.colorHex = colorHex
        self.lineWidth = lineWidth
        self.label = label
        self.comment = comment
        self.measurementText = measurementText
        self.points = points
        self.rectX = rectX
        self.rectY = rectY
        self.rectW = rectW
        self.rectH = rectH
        self.ellipseCx = ellipseCx
        self.ellipseCy = ellipseCy
        self.ellipseRx = ellipseRx
        self.ellipseRy = ellipseRy
        self.arrowStartX = arrowStartX
        self.arrowStartY = arrowStartY
        self.arrowEndX = arrowEndX
        self.arrowEndY = arrowEndY
        self.textString = textString
        self.fontSize = fontSize
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
