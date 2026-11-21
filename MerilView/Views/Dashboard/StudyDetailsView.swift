import SwiftUI

/// Comprehensive study overview and series selector view.
public struct StudyDetailsView: View {
    @EnvironmentObject var appState: AppState
    public let study: DicomStudy
    
    @State private var seriesList: [DicomSeries] = []
    @State private var isLoading = true
    
    public init(study: DicomStudy) {
        self.study = study
    }
    
    public var body: some View {
        ZStack {
            MerilTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Navigation Bar
                HStack {
                    Button(action: {
                        appState.currentScreen = .studies
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Studies")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(MerilTheme.accent)
                    }
                    
                    Spacer()
                    
                    Text("Study Overview")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(MerilTheme.textPrimary)
                    
                    Spacer()
                    
                    Button(action: {
                        appState.selectedStudy = study
                        appState.currentScreen = .dicomViewer
                    }) {
                        Text("Open 2D")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(MerilTheme.background)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(MerilTheme.accent)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(MerilTheme.surface)
                .overlay(Rectangle().frame(height: 1).foregroundColor(MerilTheme.border), alignment: .bottom)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Patient Demographics Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(study.patientName)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(MerilTheme.textPrimary)
                                Spacer()
                                ModalityChipView(study.modalities)
                            }
                            
                            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                                GridRow {
                                    Text("MRN / ID:").foregroundColor(MerilTheme.textMuted)
                                    Text(study.patientId).foregroundColor(MerilTheme.textPrimary).font(.system(size: 13, design: .monospaced))
                                }
                                GridRow {
                                    Text("Study Date:").foregroundColor(MerilTheme.textMuted)
                                    Text(study.formattedStudyDate).foregroundColor(MerilTheme.textPrimary)
                                }
                                GridRow {
                                    Text("Procedure:").foregroundColor(MerilTheme.textMuted)
                                    Text(study.studyDescription).foregroundColor(MerilTheme.textPrimary)
                                }
                                if let inst = study.institution {
                                    GridRow {
                                        Text("Institution:").foregroundColor(MerilTheme.textMuted)
                                        Text(inst).foregroundColor(MerilTheme.textSecondary)
                                    }
                                }
                            }
                            .font(.system(size: 13))
                        }
                        .padding(16)
                        .background(MerilTheme.surface)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MerilTheme.border, lineWidth: 1))
                        
                        // Series List Section Header
                        HStack {
                            Text("Imaging Series (\(seriesList.count))")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(MerilTheme.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                        
                        if isLoading {
                            ProgressView().tint(MerilTheme.accent).padding(.top, 20)
                        } else {
                            ForEach(seriesList) { series in
                                SeriesRowCard(
                                    series: series,
                                    onOpen2D: {
                                        appState.selectedStudy = study
                                        appState.selectedSeries = series
                                        appState.currentScreen = .dicomViewer
                                    },
                                    onOpenMpr: {
                                        appState.selectedStudy = study
                                        appState.selectedSeries = series
                                        appState.currentScreen = .mprViewer
                                    }
                                )
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .onAppear {
            loadSeries()
        }
    }
    
    private func loadSeries() {
        isLoading = true
        Task {
            let list = await appState.pacsClient.getSeries(studyInstanceUid: study.studyInstanceUid)
            await MainActor.run {
                self.seriesList = list
                self.isLoading = false
            }
        }
    }
}

struct SeriesRowCard: View {
    let series: DicomSeries
    let onOpen2D: () -> Void
    let onOpenMpr: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(series.seriesDescription)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(MerilTheme.textPrimary)
                Spacer()
                ModalityChipView(series.modality)
            }
            
            HStack(spacing: 16) {
                Text("Series #\(series.seriesNumber)")
                Text("\(series.numberOfInstances) Slices")
                if let thk = series.sliceThickness {
                    Text(String(format: "%.1f mm", thk))
                }
            }
            .font(.system(size: 12))
            .foregroundColor(MerilTheme.textMuted)
            
            HStack(spacing: 10) {
                Button(action: onOpen2D) {
                    HStack {
                        Image(systemName: "rectangle.inset.filled")
                        Text("2D View")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(MerilTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(MerilTheme.surfaceHover)
                    .cornerRadius(6)
                }
                
                if series.modality.contains("CT") || series.modality.contains("MR") {
                    Button(action: onOpenMpr) {
                        HStack {
                            Image(systemName: "cube.transparent")
                            Text("3D MPR")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(MerilTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(MerilTheme.accent.opacity(0.15))
                        .cornerRadius(6)
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(MerilTheme.surface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(MerilTheme.border, lineWidth: 1))
    }
}
