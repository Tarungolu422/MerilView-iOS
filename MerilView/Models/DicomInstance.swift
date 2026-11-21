import Foundation

/// Represents an individual DICOM slice / image instance.
public struct DicomInstance: Identifiable, Codable, Hashable {
    public var id: String { sopInstanceUid }
    
    public let sopInstanceUid: String
    public let seriesInstanceUid: String
    public let studyInstanceUid: String
    public let instanceNumber: Int
    public let rows: Int
    public let columns: Int
    public let bitsAllocated: Int
    public let bitsStored: Int
    public let pixelRepresentation: Int
    public let pixelSpacing: [Double]
    public let sliceThickness: Double
    public let sliceLocation: Double?
    public let imagePositionPatient: [Double]
    public let imageOrientationPatient: [Double]
    public let windowCenter: Double
    public let windowWidth: Double
    public let rescaleSlope: Double
    public let rescaleIntercept: Double
    public let filePath: String
    public let transferSyntaxUid: String
    
    public init(
        sopInstanceUid: String,
        seriesInstanceUid: String,
        studyInstanceUid: String,
        instanceNumber: Int,
        rows: Int = 512,
        columns: Int = 512,
        bitsAllocated: Int = 16,
        bitsStored: Int = 12,
        pixelRepresentation: Int = 0,
        pixelSpacing: [Double] = [1.0, 1.0],
        sliceThickness: Double = 2.0,
        sliceLocation: Double? = 0.0,
        imagePositionPatient: [Double] = [0.0, 0.0, 0.0],
        imageOrientationPatient: [Double] = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
        windowCenter: Double = 40.0,
        windowWidth: Double = 400.0,
        rescaleSlope: Double = 1.0,
        rescaleIntercept: Double = 0.0,
        filePath: String,
        transferSyntaxUid: String = "1.2.840.10008.1.2.1"
    ) {
        self.sopInstanceUid = sopInstanceUid
        self.seriesInstanceUid = seriesInstanceUid
        self.studyInstanceUid = studyInstanceUid
        self.instanceNumber = instanceNumber
        self.rows = rows
        self.columns = columns
        self.bitsAllocated = bitsAllocated
        self.bitsStored = bitsStored
        self.pixelRepresentation = pixelRepresentation
        self.pixelSpacing = pixelSpacing
        self.sliceThickness = sliceThickness
        self.sliceLocation = sliceLocation
        self.imagePositionPatient = imagePositionPatient
        self.imageOrientationPatient = imageOrientationPatient
        self.windowCenter = windowCenter
        self.windowWidth = windowWidth
        self.rescaleSlope = rescaleSlope
        self.rescaleIntercept = rescaleIntercept
        self.filePath = filePath
        self.transferSyntaxUid = transferSyntaxUid
    }
}
