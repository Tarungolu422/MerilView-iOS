import SwiftUI

/// Active root screens in the iOS application.
public enum AppScreen {
    case login
    case studies
    case studyDetails
    case dicomViewer
    case mprViewer
    case segmentationStudio
}

/// Central application state coordinator.
public final class AppState: ObservableObject {
    @Published public var isAuthenticated: Bool = false
    @Published public var currentScreen: AppScreen = .login
    @Published public var selectedStudy: DicomStudy?
    @Published public var selectedSeries: DicomSeries?
    
    public let pacsClient = MerilPacsClient()
    
    public init() {}
}
