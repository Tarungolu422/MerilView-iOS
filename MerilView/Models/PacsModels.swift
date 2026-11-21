import Foundation

/// Filter criteria for querying PACS studies.
public struct QueryFilters: Codable {
    public var patientName: String?
    public var patientId: String?
    public var modalities: String?
    public var studyDate: String?
    
    public init(
        patientName: String? = nil,
        patientId: String? = nil,
        modalities: String? = nil,
        studyDate: String? = nil
    ) {
        self.patientName = patientName
        self.patientId = patientId
        self.modalities = modalities
        self.studyDate = studyDate
    }
}

/// Request to generate an encrypted clinical share link.
public struct ShareStudyRequest: Codable {
    public let studyInstanceUid: String
    public let expiresInHours: Int
    public let password: String?
    public let permissions: SharePermissions
    
    public init(
        studyInstanceUid: String,
        expiresInHours: Int = 72,
        password: String? = nil,
        permissions: SharePermissions = SharePermissions()
    ) {
        self.studyInstanceUid = studyInstanceUid
        self.expiresInHours = expiresInHours
        self.password = password
        self.permissions = permissions
    }
}

public struct SharePermissions: Codable {
    public var view: Bool
    public var measure: Bool
    public var annotation: Bool
    public var download: Bool
    
    public init(view: Bool = true, measure: Bool = true, annotation: Bool = true, download: Bool = false) {
        self.view = view
        self.measure = measure
        self.annotation = annotation
        self.download = download
    }
}

/// Response returned from backend share-study endpoint.
public struct ShareStudyResponse: Codable {
    public let token: String
    public let shareUrl: String
    public let expiresAt: String
    public let permissions: SharePermissions
}

/// Configuration settings for remote PACS / DICOMweb node.
public struct PacsServerConfig: Codable, Hashable {
    public var host: String
    public var port: Int
    public var aeTitle: String
    public var callingAeTitle: String
    public var useSsl: Bool
    public var timeoutSeconds: Int
    
    public init(
        host: String = "127.0.0.1",
        port: Int = 3001,
        aeTitle: String = "MERIL_PACS",
        callingAeTitle: String = "MERIL_VIEW_IOS",
        useSsl: Bool = false,
        timeoutSeconds: Int = 15
    ) {
        self.host = host
        self.port = port
        self.aeTitle = aeTitle
        self.callingAeTitle = callingAeTitle
        self.useSsl = useSsl
        self.timeoutSeconds = timeoutSeconds
    }
    
    public var baseUrl: String {
        let scheme = useSsl ? "https" : "http"
        return "\(scheme)://\(host):\(port)"
    }
}
