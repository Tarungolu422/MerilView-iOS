import Foundation
import CoreGraphics

/// Types of 2D measurements supported by the viewer.
public enum MeasurementType: String, Codable {
    case length
    case angle
    case ellipseRoi
    case rectangleRoi
}

/// Point in normalized coordinate space [0.0 ... 1.0].
public struct NormalizedPoint: Codable, Hashable {
    public var x: Double
    public var y: Double
    
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
    
    public var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

/// Calibrated clinical measurement model.
public struct DicomMeasurement: Identifiable, Codable, Hashable {
    public let id: String
    public let type: MeasurementType
    public let studyInstanceUid: String
    public let seriesInstanceUid: String
    public let sopInstanceUid: String?
    public let sliceIndex: Int
    public var points: [NormalizedPoint]
    public var value: Double // length (mm), angle (deg), or area (mm2)
    public var unit: String
    public var meanHu: Double?
    public var minHu: Double?
    public var maxHu: Double?
    public var stdDevHu: Double?
    public var pixelCount: Int?
    public var colorHex: String
    public var createdAt: Date
    
    public init(
        id: String = UUID().uuidString,
        type: MeasurementType,
        studyInstanceUid: String,
        seriesInstanceUid: String,
        sopInstanceUid: String? = nil,
        sliceIndex: Int,
        points: [NormalizedPoint],
        value: Double,
        unit: String,
        meanHu: Double? = nil,
        minHu: Double? = nil,
        maxHu: Double? = nil,
        stdDevHu: Double? = nil,
        pixelCount: Int? = nil,
        colorHex: String = "#00E5FF",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.studyInstanceUid = studyInstanceUid
        self.seriesInstanceUid = seriesInstanceUid
        self.sopInstanceUid = sopInstanceUid
        self.sliceIndex = sliceIndex
        self.points = points
        self.value = value
        self.unit = unit
        self.meanHu = meanHu
        self.minHu = minHu
        self.maxHu = maxHu
        self.stdDevHu = stdDevHu
        self.pixelCount = pixelCount
        self.colorHex = colorHex
        self.createdAt = createdAt
    }
    
    /// Formatted primary label for on-screen HUD
    public var displayLabel: String {
        switch type {
        case .length:
            return String(format: "%.1f %@", value, unit)
        case .angle:
            return String(format: "%.1f°", value)
        case .ellipseRoi, .rectangleRoi:
            if let mean = meanHu, let sd = stdDevHu {
                return String(format: "Area: %.1f mm²\nMean: %.1f HU\nSD: ±%.1f", value, mean, sd)
            }
            return String(format: "Area: %.1f mm²", value)
        }
    }
}
