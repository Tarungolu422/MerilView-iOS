import SwiftUI

/// Root content view routing dynamically based on AppState.
public struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    public init() {}
    
    public var body: some View {
        ZStack {
            MerilTheme.background.ignoresSafeArea()
            
            if !appState.isAuthenticated {
                LoginView()
            } else {
                switch appState.currentScreen {
                case .login:
                    LoginView()
                    
                case .studies:
                    StudiesDashboardView()
                    
                case .studyDetails:
                    if let study = appState.selectedStudy {
                        StudyDetailsView(study: study)
                    } else {
                        StudiesDashboardView()
                    }
                    
                case .dicomViewer:
                    if let study = appState.selectedStudy {
                        DicomViewerHostView(study: study, series: appState.selectedSeries)
                    } else {
                        StudiesDashboardView()
                    }
                    
                case .mprViewer:
                    if let study = appState.selectedStudy {
                        MprWorkstationView(study: study, series: appState.selectedSeries)
                    } else {
                        StudiesDashboardView()
                    }
                    
                case .segmentationStudio:
                    if let study = appState.selectedStudy {
                        SegmentationStudioView(study: study, series: appState.selectedSeries)
                    } else {
                        StudiesDashboardView()
                    }
                }
            }
        }
    }
}
