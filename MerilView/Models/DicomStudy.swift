import Foundation

/// Represents a clinical imaging study containing one or more series.
public struct DicomStudy: Identifiable, Codable, Hashable {
    public var id: String { studyInstanceUid }
    
    public let studyInstanceUid: String
    public let patientName: String
    public let patientId: String
    public let patientBirthDate: String?
    public let patientSex: String?
    public let studyDate: String
    public let studyTime: String?
    public let studyDescription: String
    public let modalities: String
    public let numberOfSeries: Int
    public let numberOfInstances: Int
    public let institution: String?
    public let accessionNumber: String?
    public let isLocal: Bool
    public let dateAdded: Date?
    
    public init(
        studyInstanceUid: String,
        patientName: String,
        patientId: String,
        patientBirthDate: String? = nil,
        patientSex: String? = nil,
        studyDate: String,
        studyTime: String? = nil,
        studyDescription: String,
        modalities: String,
        numberOfSeries: Int = 1,
        numberOfInstances: Int = 0,
        institution: String? = nil,
        accessionNumber: String? = nil,
        isLocal: Bool = true,
        dateAdded: Date? = Date()
    ) {
        self.studyInstanceUid = studyInstanceUid
        self.patientName = patientName
        self.patientId = patientId
        self.patientBirthDate = patientBirthDate
        self.patientSex = patientSex
        self.studyDate = studyDate
        self.studyTime = studyTime
        self.studyDescription = studyDescription
        self.modalities = modalities
        self.numberOfSeries = numberOfSeries
        self.numberOfInstances = numberOfInstances
        self.institution = institution
        self.accessionNumber = accessionNumber
        self.isLocal = isLocal
        self.dateAdded = dateAdded
    }
    
    /// Formatted display date (YYYYMMDD -> MM/DD/YYYY or DD-MMM-YYYY)
    public var formattedStudyDate: String {
        guard studyDate.count == 8 else { return studyDate }
        let year = studyDate.prefix(4)
        let month = studyDate.dropFirst(4).prefix(2)
        let day = studyDate.suffix(2)
        return "\(month)/\(day)/\(year)"
    }
}
