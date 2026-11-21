import SwiftUI

/// Layout arrangements for 2D multi-viewport clinical workstation.
public enum ViewportGridMode: String, CaseIterable, Identifiable {
    case single = "1x1"
    case splitHorizontal = "1x2"
    case splitVertical = "2x1"
    case quad = "2x2"
    
    public var id: String { rawValue }
}

/// Primary 2D Clinical DICOM Workstation View.
public struct DicomViewerHostView: View {
    @EnvironmentObject var appState: AppState
    public let study: DicomStudy
    public let initialSeries: DicomSeries?
    
    @State private var seriesList: [DicomSeries] = []
    @State private var activeSeries: DicomSeries?
    @State private var instances: [DicomInstance] = []
    
    // Viewport Parameters
    @State private var currentSliceIndex = 0
    @State private var windowCenter = 40.0
    @State private var windowWidth = 400.0
    @State private var invert = false
    @State private var activeTool: ViewerTool = .scroll
    @State private var gridMode: ViewportGridMode = .single
    
    // Cine loop state
    @State private var isCinePlaying = false
    @State private var cineFps = 15.0
    @State private var cineTimer: Timer?
    
    // Modals
    @State private var showPresets = false
    @State private var showMetadata = false
    @State private var showShareModal = false
    @State private var isLoading = true
    
    public init(study: DicomStudy, series: DicomSeries? = nil) {
        self.study = study
        self.initialSeries = series
    }
    
    public var body: some View {
        ZStack {
            MerilTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Top Workstation Navigation Bar
                HStack {
                    Button(action: {
                        stopCine()
                        appState.currentScreen = .studies
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Studies")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(MerilTheme.accent)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text(study.patientName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(MerilTheme.textPrimary)
                            .lineLimit(1)
                        Text(activeSeries?.seriesDescription ?? study.studyDescription)
                            .font(.system(size: 11))
                            .foregroundColor(MerilTheme.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        // Grid Mode Toggle Button
                        Menu {
                            ForEach(ViewportGridMode.allCases) { mode in
                                Button(mode.rawValue) {
                                    gridMode = mode
                                }
                            }
                        } label: {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 15))
                                .foregroundColor(MerilTheme.textSecondary)
                                .padding(6)
                                .background(MerilTheme.surface)
                                .cornerRadius(6)
                        }
                        
                        // Share Button
                        Button(action: { showShareModal = true }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15))
                                .foregroundColor(MerilTheme.accent)
                                .padding(6)
                                .background(MerilTheme.surface)
                                .cornerRadius(6)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(MerilTheme.surface)
                
                // 2. Interactive Clinical Toolbar
                ViewerToolbarView(
                    activeTool: $activeTool,
                    onToggleInvert: { invert.toggle() },
                    onReset: {
                        windowCenter = 40.0
                        windowWidth = 400.0
                        invert = false
                    },
                    onOpenPresets: { showPresets = true },
                    onOpenMetadata: { showMetadata = true },
                    onToggleCine: { toggleCine() },
                    isCineActive: isCinePlaying,
                    onOpenMpr: {
                        stopCine()
                        appState.selectedStudy = study
                        appState.selectedSeries = activeSeries
                        appState.currentScreen = .mprViewer
                    },
                    onOpenSegmentation: {
                        stopCine()
                        appState.selectedStudy = study
                        appState.selectedSeries = activeSeries
                        appState.currentScreen = .segmentationStudio
                    }
                )
                
                // 3. Viewport Display Area
                if isLoading {
                    MedicalLoadingView("Loading Series Images...")
                } else if instances.isEmpty {
                    MedicalErrorView(title: "No Images in Series", message: "This series does not contain viewable DICOM slices.")
                } else {
                    renderViewportGrid()
                }
                
                // 4. Series Thumbnail Switcher Bar
                if seriesList.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(seriesList) { ser in
                                Button(action: {
                                    activeSeries = ser
                                    loadInstances(for: ser)
                                }) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(ser.seriesDescription)
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(activeSeries?.seriesInstanceUid == ser.seriesInstanceUid ? MerilTheme.accent : MerilTheme.textPrimary)
                                            .lineLimit(1)
                                        Text("\(ser.numberOfInstances) Slices")
                                            .font(.system(size: 10))
                                            .foregroundColor(MerilTheme.textMuted)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(activeSeries?.seriesInstanceUid == ser.seriesInstanceUid ? MerilTheme.surfaceHover : MerilTheme.surface)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(activeSeries?.seriesInstanceUid == ser.seriesInstanceUid ? MerilTheme.accent : MerilTheme.border, lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .background(MerilTheme.surface.opacity(0.8))
                }
            }
            
            // 5. Floating Cine Controller
            if isCinePlaying {
                VStack {
                    Spacer()
                    CineControllerView(
                        isPlaying: $isCinePlaying,
                        fps: $cineFps,
                        onStepBack: { stepSlice(delta: -1) },
                        onStepForward: { stepSlice(delta: 1) }
                    )
                    .padding(.bottom, 70)
                }
            }
        }
        .sheet(isPresented: $showPresets) {
            WindowLevelPresetSheet(
                currentWc: windowCenter,
                currentWw: windowWidth,
                onSelectPreset: { preset in
                    windowCenter = preset.center
                    windowWidth = preset.width
                },
                onCustomLut: { wc, ww in
                    windowCenter = wc
                    windowWidth = ww
                }
            )
        }
        .sheet(isPresented: $showMetadata) {
            if let inst = instances[safe: currentSliceIndex] {
                let meta = DicomMetadata(
                    patientName: study.patientName,
                    patientId: study.patientId,
                    patientBirthDate: study.patientBirthDate ?? "",
                    patientSex: study.patientSex ?? "O",
                    studyInstanceUid: study.studyInstanceUid,
                    studyDate: study.studyDate,
                    studyTime: study.studyTime ?? "",
                    modality: study.modalities,
                    studyDescription: study.studyDescription,
                    seriesInstanceUid: inst.seriesInstanceUid,
                    seriesDescription: activeSeries?.seriesDescription ?? "",
                    seriesNumber: activeSeries?.seriesNumber ?? 1,
                    sopInstanceUid: inst.sopInstanceUid,
                    instanceNumber: inst.instanceNumber,
                    rows: inst.rows,
                    columns: inst.columns,
                    bitsAllocated: inst.bitsAllocated,
                    bitsStored: inst.bitsStored,
                    highBit: 11,
                    pixelRepresentation: inst.pixelRepresentation,
                    pixelSpacing: inst.pixelSpacing,
                    sliceThickness: inst.sliceThickness,
                    sliceLocation: inst.sliceLocation ?? 0.0,
                    imagePositionPatient: inst.imagePositionPatient,
                    imageOrientationPatient: inst.imageOrientationPatient,
                    rescaleSlope: inst.rescaleSlope,
                    rescaleIntercept: inst.rescaleIntercept,
                    windowCenter: inst.windowCenter,
                    windowWidth: inst.windowWidth,
                    transferSyntaxUid: inst.transferSyntaxUid
                )
                DicomMetadataInspectorView(metadata: meta)
            }
        }
        .onAppear {
            loadInitialData()
        }
        .onDisappear {
            stopCine()
        }
    }
    
    // MARK: - Viewport Grid Render
    
    @ViewBuilder
    private func renderViewportGrid() -> some View {
        switch gridMode {
        case .single:
            Viewport2DView(
                instances: instances,
                currentSliceIndex: $currentSliceIndex,
                windowCenter: $windowCenter,
                windowWidth: $windowWidth,
                invert: $invert,
                activeTool: $activeTool
            )
            
        case .splitHorizontal:
            HStack(spacing: 2) {
                Viewport2DView(
                    instances: instances,
                    currentSliceIndex: $currentSliceIndex,
                    windowCenter: $windowCenter,
                    windowWidth: $windowWidth,
                    invert: $invert,
                    activeTool: $activeTool
                )
                Viewport2DView(
                    instances: instances,
                    currentSliceIndex: $currentSliceIndex,
                    windowCenter: $windowCenter,
                    windowWidth: $windowWidth,
                    invert: $invert,
                    activeTool: $activeTool
                )
            }
            
        case .splitVertical:
            VStack(spacing: 2) {
                Viewport2DView(
                    instances: instances,
                    currentSliceIndex: $currentSliceIndex,
                    windowCenter: $windowCenter,
                    windowWidth: $windowWidth,
                    invert: $invert,
                    activeTool: $activeTool
                )
                Viewport2DView(
                    instances: instances,
                    currentSliceIndex: $currentSliceIndex,
                    windowCenter: $windowCenter,
                    windowWidth: $windowWidth,
                    invert: $invert,
                    activeTool: $activeTool
                )
            }
            
        case .quad:
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    Viewport2DView(
                        instances: instances,
                        currentSliceIndex: $currentSliceIndex,
                        windowCenter: $windowCenter,
                        windowWidth: $windowWidth,
                        invert: $invert,
                        activeTool: $activeTool
                    )
                    Viewport2DView(
                        instances: instances,
                        currentSliceIndex: $currentSliceIndex,
                        windowCenter: $windowCenter,
                        windowWidth: $windowWidth,
                        invert: $invert,
                        activeTool: $activeTool
                    )
                }
                HStack(spacing: 2) {
                    Viewport2DView(
                        instances: instances,
                        currentSliceIndex: $currentSliceIndex,
                        windowCenter: $windowCenter,
                        windowWidth: $windowWidth,
                        invert: $invert,
                        activeTool: $activeTool
                    )
                    Viewport2DView(
                        instances: instances,
                        currentSliceIndex: $currentSliceIndex,
                        windowCenter: $windowCenter,
                        windowWidth: $windowWidth,
                        invert: $invert,
                        activeTool: $activeTool
                    )
                }
            }
        }
    }
    
    // MARK: - Cine Playback
    
    private func toggleCine() {
        if isCinePlaying {
            stopCine()
        } else {
            startCine()
        }
    }
    
    private func startCine() {
        guard instances.count > 1 else { return }
        isCinePlaying = true
        let interval = 1.0 / cineFps
        cineTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            stepSlice(delta: 1)
        }
    }
    
    private func stopCine() {
        isCinePlaying = false
        cineTimer?.invalidate()
        cineTimer = nil
    }
    
    private func stepSlice(delta: Int) {
        guard !instances.isEmpty else { return }
        currentSliceIndex = (currentSliceIndex + delta + instances.count) % instances.count
    }
    
    // MARK: - Data Loading
    
    private func loadInitialData() {
        isLoading = true
        Task {
            let list = await appState.pacsClient.getSeries(studyInstanceUid: study.studyInstanceUid)
            await MainActor.run {
                self.seriesList = list
                let targetSeries = self.initialSeries ?? list.first
                self.activeSeries = targetSeries
                if let ser = targetSeries {
                    loadInstances(for: ser)
                } else {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadInstances(for series: DicomSeries) {
        let localInstances = MerilStorageManager.shared.getInstances(seriesInstanceUid: series.seriesInstanceUid)
        if !localInstances.isEmpty {
            self.instances = localInstances
            self.currentSliceIndex = min(currentSliceIndex, max(0, localInstances.count - 1))
            self.isLoading = false
        } else {
            // Generate synthetic or demo instance wrappers if remote
            var demoInstances: [DicomInstance] = []
            let count = max(1, series.numberOfInstances)
            for i in 0..<count {
                demoInstances.append(DicomInstance(
                    sopInstanceUid: "\(series.seriesInstanceUid).\(i + 1)",
                    seriesInstanceUid: series.seriesInstanceUid,
                    studyInstanceUid: series.studyInstanceUid,
                    instanceNumber: i + 1,
                    rows: 512,
                    columns: 512,
                    bitsAllocated: 16,
                    bitsStored: 12,
                    pixelRepresentation: 0,
                    pixelSpacing: [0.75, 0.75],
                    sliceThickness: series.sliceThickness ?? 2.0,
                    sliceLocation: Double(i) * (series.sliceThickness ?? 2.0),
                    imagePositionPatient: [-150.0, -150.0, Double(i) * 2.0],
                    imageOrientationPatient: [1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
                    windowCenter: 40.0,
                    windowWidth: 400.0,
                    rescaleSlope: 1.0,
                    rescaleIntercept: -1024.0,
                    filePath: ""
                ))
            }
            self.instances = demoInstances
            self.currentSliceIndex = 0
            self.isLoading = false
        }
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
