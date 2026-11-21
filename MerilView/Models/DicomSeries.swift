import Foundation

/// Represents a distinct series within a DICOM study.
public struct DicomSeries: Identifiable, Codable, Hashable {
    public var id: String { seriesInstanceUid }
    
    public let seriesInstanceUid: String
    public let studyInstanceUid: String
    public let seriesNumber: Int
    public let modality: String
    public let seriesDescription: String
    public let numberOfInstances: Int
    public let sliceThickness: Double?
    public let bodyPartExamined: String?
    public let isVolumetric: Bool
    public let instances: [DicomInstance]?
    
    public init(
        seriesInstanceUid: String,
        studyInstanceUid: String,
        seriesNumber: Int = 1,
        modality: String = "CT",
        seriesDescription: String = "",
        numberOfInstances: Int = 0,
        sliceThickness: Double? = 2.0,
        bodyPartExamined: String? = nil,
        isVolumetric: Bool = true,
        instances: [DicomInstance]? = nil
    ) {
        self.seriesInstanceUid = seriesInstanceUid
        self.studyInstanceUid = studyInstanceUid
        self.seriesNumber = seriesNumber
        self.modality = modality
        self.seriesDescription = seriesDescription.isEmpty ? "Series \(seriesNumber)" : seriesDescription
        self.numberOfInstances = numberOfInstances
        self.sliceThickness = sliceThickness
        self.bodyPartExamined = bodyPartExamined
        self.isVolumetric = isVolumetric
        self.instances = instances
    }
}
