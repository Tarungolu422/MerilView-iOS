import SwiftUI

/// Main workstation dashboard displaying medical studies list, modality filters, and import controls.
public struct StudiesDashboardView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var studies: [DicomStudy] = []
    @State private var selectedModality: String = "ALL"
    @State private var searchText: String = ""
    @State private var isLoading = true
    @State private var showImportSheet = false
    @State private var showSettingsSheet = false
    
    private let modalities = ["ALL", "CT", "MR", "CR", "DX", "US"]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                MerilTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Bar
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("MERILVIEW")
                                .font(.system(size: 20, weight: .black, design: .monospaced))
                                .foregroundColor(MerilTheme.textPrimary)
                                .tracking(1.5)
                            Text("Studies Directory")
                                .font(.system(size: 12))
                                .foregroundColor(MerilTheme.textMuted)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Button(action: { showImportSheet = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 13, weight: .bold))
                                    Text("Import")
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .foregroundColor(MerilTheme.background)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(MerilTheme.accent)
                                .cornerRadius(8)
                            }
                            
                            Button(action: { showSettingsSheet = true }) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(MerilTheme.textSecondary)
                                    .padding(8)
                                    .background(MerilTheme.surface)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 10)
                    
                    // Search Bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(MerilTheme.textMuted)
                        TextField("Search by patient name, MRN, ID...", text: $searchText)
                            .foregroundColor(MerilTheme.textPrimary)
                            .font(.system(size: 14))
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(MerilTheme.textMuted)
                            }
                        }
                    }
                    .padding(10)
                    .background(MerilTheme.surface)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(MerilTheme.border, lineWidth: 1))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    
                    // Modality Filters ScrollView
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(modalities, id: \.self) { mod in
                                Button(action: {
                                    selectedModality = mod
                                    loadStudies()
                                }) {
                                    Text(mod)
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(selectedModality == mod ? MerilTheme.background : MerilTheme.textSecondary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(selectedModality == mod ? MerilTheme.accent : MerilTheme.surface)
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(selectedModality == mod ? MerilTheme.accent : MerilTheme.border, lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 12)
                    
                    // Studies List
                    if isLoading {
                        MedicalLoadingView("Querying Studies from Meril PACS...")
                    } else if studies.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 44))
                                .foregroundColor(MerilTheme.textMuted)
                            Text("No Clinical Studies Found")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(MerilTheme.textPrimary)
                            Text("Import DICOM files, folders, or ZIP archives from Files app to begin viewing.")
                                .font(.system(size: 13))
                                .foregroundColor(MerilTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredStudies) { study in
                                    StudyCardView(
                                        study: study,
                                        onSelect: {
                                            appState.selectedStudy = study
                                            appState.currentScreen = .studyDetails
                                        },
                                        onOpenMpr: {
                                            appState.selectedStudy = study
                                            appState.currentScreen = .mprViewer
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }
                        .refreshable {
                            loadStudies()
                        }
                    }
                }
            }
            .sheet(isPresented: $showImportSheet, onDismiss: { loadStudies() }) {
                DicomImportSheet()
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView()
            }
            .onAppear {
                loadStudies()
            }
        }
    }
    
    private var filteredStudies: [DicomStudy] {
        var list = studies
        if selectedModality != "ALL" {
            list = list.filter { $0.modalities.uppercased().contains(selectedModality) }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter {
                $0.patientName.lowercased().contains(q) ||
                $0.patientId.lowercased().contains(q) ||
                $0.studyDescription.lowercased().contains(q)
            }
        }
        return list
    }
    
    private func loadStudies() {
        isLoading = true
        Task {
            let results = await appState.pacsClient.getStudies(filters: QueryFilters(modalities: selectedModality))
            await MainActor.run {
                self.studies = results
                self.isLoading = false
            }
        }
    }
}
