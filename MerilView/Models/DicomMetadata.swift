import Foundation

/// Comprehensive metadata extracted from a DICOM Part 10 dataset.
public struct DicomMetadata: Codable, Hashable {
    public let patientName: String
    public let patientId: String
    public let patientBirthDate: String
    public let patientSex: String
    public let studyInstanceUid: String
    public let studyDate: String
    public let studyTime: String
    public let modality: String
    public let studyDescription: String
    public let seriesInstanceUid: String
    public let seriesDescription: String
    public let seriesNumber: Int
    public let sopInstanceUid: String
    public let instanceNumber: Int
    public let rows: Int
    public let columns: Int
    public let bitsAllocated: Int
    public let bitsStored: Int
    public let highBit: Int
    public let pixelRepresentation: Int
    public let pixelSpacing: [Double]
    public let sliceThickness: Double
    public let sliceLocation: Double
    public let imagePositionPatient: [Double]
    public let imageOrientationPatient: [Double]
    public let rescaleSlope: Double
    public let rescaleIntercept: Double
    public let windowCenter: Double
    public let windowWidth: Double
    public let transferSyntaxUid: String
    public let pixelDataOffset: Int
    public let pixelDataLength: Int
    
    public init(
        patientName: String = "Anonymous",
        patientId: String = "UNKNOWN",
        patientBirthDate: String = "",
        patientSex: String = "O",
        studyInstanceUid: String = "",
        studyDate: String = "",
        studyTime: String = "",
        modality: String = "CT",
        studyDescription: String = "",
        seriesInstanceUid: String = "",
        seriesDescription: String = "",
        seriesNumber: Int = 1,
        sopInstanceUid: String = "",
        instanceNumber: Int = 1,
        rows: Int = 512,
        columns: Int = 512,
        bitsAllocated: Int = 16,
        bitsStored: Int = 12,
        highBit: Int = 11,
        pixelRepresentation: Int = 0,
        pixelSpacing: [Double] = [1.0, 1.0],
        sliceThickness: Double = 2.0,
        sliceLocation: Double = 0.0,
        imagePositionPatient: [Double] = [0.0, 0.0, 0.0],
        imageOrientationPatient: [Double] = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
        rescaleSlope: Double = 1.0,
        rescaleIntercept: Double = 0.0,
        windowCenter: Double = 40.0,
        windowWidth: Double = 400.0,
        transferSyntaxUid: String = "1.2.840.10008.1.2.1",
        pixelDataOffset: Int = 132,
        pixelDataLength: Int = 0
    ) {
        self.patientName = patientName
        self.patientId = patientId
        self.patientBirthDate = patientBirthDate
        self.patientSex = patientSex
        self.studyInstanceUid = studyInstanceUid
        self.studyDate = studyDate
        self.studyTime = studyTime
        self.modality = modality
        self.studyDescription = studyDescription
        self.seriesInstanceUid = seriesInstanceUid
        self.seriesDescription = seriesDescription
        self.seriesNumber = seriesNumber
        self.sopInstanceUid = sopInstanceUid
        self.instanceNumber = instanceNumber
        self.rows = rows
        self.columns = columns
        self.bitsAllocated = bitsAllocated
        self.bitsStored = bitsStored
        self.highBit = highBit
        self.pixelRepresentation = pixelRepresentation
        self.pixelSpacing = pixelSpacing
        self.sliceThickness = sliceThickness
        self.sliceLocation = sliceLocation
        self.imagePositionPatient = imagePositionPatient
        self.imageOrientationPatient = imageOrientationPatient
        self.rescaleSlope = rescaleSlope
        self.rescaleIntercept = rescaleIntercept
        self.windowCenter = windowCenter
        self.windowWidth = windowWidth
        self.transferSyntaxUid = transferSyntaxUid
        self.pixelDataOffset = pixelDataOffset
        self.pixelDataLength = pixelDataLength
    }
}
