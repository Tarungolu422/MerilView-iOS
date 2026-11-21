import SwiftUI

/// 4-Panel Synchronized Multiplanar Reconstruction (MPR) and 3D Volume Workstation.
public struct MprWorkstationView: View {
    @EnvironmentObject var appState: AppState
    public let study: DicomStudy
    public let series: DicomSeries?
    
    @State private var volume: MerilVolumeState?
    @State private var isLoading = true
    @State private var loadingStatus = "Reconstructing 3D Scalar Volume..."
    @State private var progress = 0.0
    
    // MPR Slice Indices & Synchronized Crosshair State
    @State private var axialIndex = 0
    @State private var coronalIndex = 0
    @State private var sagittalIndex = 0
    
    // Normalized Crosshair Coordinates [0.0 ... 1.0] per plane
    @State private var axialCrosshairX = 0.5 // Sagittal reference line (vertical)
    @State private var axialCrosshairY = 0.5 // Coronal reference line (horizontal)
    
    @State private var coronalCrosshairX = 0.5 // Sagittal reference line
    @State private var coronalCrosshairY = 0.5 // Axial reference line
    
    @State private var sagittalCrosshairX = 0.5 // Coronal reference line
    @State private var sagittalCrosshairY = 0.5 // Axial reference line
    
    // 3D MIP Angles
    @State private var mipAzimuth = 0.0
    @State private var mipElevation = 0.0
    
    // Windowing & Display Parameters
    @State private var windowCenter = 40.0
    @State private var windowWidth = 400.0
    @State private var interactMode: String = "crosshair" // "crosshair" or "scroll"
    @State private var maximizedPlane: MprPlaneType? = nil
    
    // Rendered Slice Frames
    @State private var axialResult: MprSliceResult?
    @State private var coronalResult: MprSliceResult?
    @State private var sagittalResult: MprSliceResult?
    @State private var mipResult: MprSliceResult?
    
    public init(study: DicomStudy, series: DicomSeries? = nil) {
        self.study = study
        self.series = series
    }
    
    public var body: some View {
        ZStack {
            MerilTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Navigation & Controls Bar
                HStack {
                    Button(action: {
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
                        Text("3D MPR Workstation")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(MerilTheme.textPrimary)
                        Text(study.patientName)
                            .font(.system(size: 11))
                            .foregroundColor(MerilTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        // Mode Toggle: Crosshairs vs Slice Scroll
                        Button(action: {
                            interactMode = interactMode == "crosshair" ? "scroll" : "crosshair"
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: interactMode == "crosshair" ? "scope" : "hand.draw")
                                Text(interactMode == "crosshair" ? "Crosshairs" : "Scroll")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(MerilTheme.background)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(MerilTheme.accent)
                            .cornerRadius(6)
                        }
                        
                        // Segmentation studio launch
                        Button(action: {
                            appState.selectedStudy = study
                            appState.selectedSeries = series
                            appState.currentScreen = .segmentationStudio
                        }) {
                            Image(systemName: "paintbrush.pointed.fill")
                                .font(.system(size: 13))
                                .foregroundColor(MerilTheme.primary)
                                .padding(6)
                                .background(MerilTheme.surface)
                                .cornerRadius(6)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(MerilTheme.surface)
                
                // Content Workspace
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView().tint(MerilTheme.accent).scaleEffect(1.3)
                        Text(loadingStatus)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(MerilTheme.textSecondary)
                        if progress > 0 {
                            ProgressView(value: progress, total: 1.0)
                                .tint(MerilTheme.accent)
                                .frame(width: 200)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if volume == nil {
                    MedicalErrorView(title: "Volumetric Reconstruction Failed", message: "Could not reconstruct 3D scalar volume from this series.")
                } else {
                    renderMprGrid()
                }
            }
        }
        .onAppear {
            initializeVolume()
        }
    }
    
    // MARK: - 4-Panel Grid
    
    @ViewBuilder
    private func renderMprGrid() -> some View {
        if let maxPlane = maximizedPlane {
            // Maximized Single Plane View
            renderSingleView(for: maxPlane, isMaximized: true)
        } else {
            // 2x2 Orthogonal Grid
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    // Top-Left: 3D Volume MIP
                    VolumeMipView(
                        mipSlice: mipResult,
                        azimuth: $mipAzimuth,
                        elevation: $mipElevation,
                        isMaximized: false,
                        onToggleMaximize: { maximizedPlane = .mip },
                        onRotate: { az, el in
                            updateMip(az: az, el: el)
                        }
                    )
                    
                    // Top-Right: Axial Plane
                    MprSinglePlaneView(
                        plane: .axial,
                        sliceResult: axialResult,
                        crosshairNormX: axialCrosshairX,
                        crosshairNormY: axialCrosshairY,
                        isMaximized: false,
                        interactMode: interactMode,
                        onMoveCrosshair: { nx, ny in
                            handleAxialCrosshairMove(nx: nx, ny: ny)
                        },
                        onScrollSlice: { delta in
                            scrollAxial(delta: delta)
                        },
                        onToggleMaximize: { maximizedPlane = .axial }
                    )
                }
                
                HStack(spacing: 2) {
                    // Bottom-Left: Coronal Plane
                    MprSinglePlaneView(
                        plane: .coronal,
                        sliceResult: coronalResult,
                        crosshairNormX: coronalCrosshairX,
                        crosshairNormY: coronalCrosshairY,
                        isMaximized: false,
                        interactMode: interactMode,
                        onMoveCrosshair: { nx, ny in
                            handleCoronalCrosshairMove(nx: nx, ny: ny)
                        },
                        onScrollSlice: { delta in
                            scrollCoronal(delta: delta)
                        },
                        onToggleMaximize: { maximizedPlane = .coronal }
                    )
                    
                    // Bottom-Right: Sagittal Plane
                    MprSinglePlaneView(
                        plane: .sagittal,
                        sliceResult: sagittalResult,
                        crosshairNormX: sagittalCrosshairX,
                        crosshairNormY: sagittalCrosshairY,
                        isMaximized: false,
                        interactMode: interactMode,
                        onMoveCrosshair: { nx, ny in
                            handleSagittalCrosshairMove(nx: nx, ny: ny)
                        },
                        onScrollSlice: { delta in
                            scrollSagittal(delta: delta)
                        },
                        onToggleMaximize: { maximizedPlane = .sagittal }
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private func renderSingleView(for plane: MprPlaneType, isMaximized: Bool) -> some View {
        switch plane {
        case .mip:
            VolumeMipView(
                mipSlice: mipResult,
                azimuth: $mipAzimuth,
                elevation: $mipElevation,
                isMaximized: true,
                onToggleMaximize: { maximizedPlane = nil },
                onRotate: { az, el in updateMip(az: az, el: el) }
            )
        case .axial:
            MprSinglePlaneView(
                plane: .axial,
                sliceResult: axialResult,
                crosshairNormX: axialCrosshairX,
                crosshairNormY: axialCrosshairY,
                isMaximized: true,
                interactMode: interactMode,
                onMoveCrosshair: { nx, ny in handleAxialCrosshairMove(nx: nx, ny: ny) },
                onScrollSlice: { delta in scrollAxial(delta: delta) },
                onToggleMaximize: { maximizedPlane = nil }
            )
        case .coronal:
            MprSinglePlaneView(
                plane: .coronal,
                sliceResult: coronalResult,
                crosshairNormX: coronalCrosshairX,
                crosshairNormY: coronalCrosshairY,
                isMaximized: true,
                interactMode: interactMode,
                onMoveCrosshair: { nx, ny in handleCoronalCrosshairMove(nx: nx, ny: ny) },
                onScrollSlice: { delta in scrollCoronal(delta: delta) },
                onToggleMaximize: { maximizedPlane = nil }
            )
        case .sagittal:
            MprSinglePlaneView(
                plane: .sagittal,
                sliceResult: sagittalResult,
                crosshairNormX: sagittalCrosshairX,
                crosshairNormY: sagittalCrosshairY,
                isMaximized: true,
                interactMode: interactMode,
                onMoveCrosshair: { nx, ny in handleSagittalCrosshairMove(nx: nx, ny: ny) },
                onScrollSlice: { delta in scrollSagittal(delta: delta) },
                onToggleMaximize: { maximizedPlane = nil }
            )
        }
    }
    
    // MARK: - Synchronized Crosshair Coordinations
    
    private func handleAxialCrosshairMove(nx: Double, ny: Double) {
        guard let vol = volume else { return }
        axialCrosshairX = nx
        axialCrosshairY = ny
        
        // nx corresponds to Sagittal plane (X index)
        // ny corresponds to Coronal plane (Y index)
        let newSagittalIdx = min(vol.nx - 1, max(0, Int(round(nx * Double(vol.nx - 1)))))
        let newCoronalIdx = min(vol.ny - 1, max(0, Int(round(ny * Double(vol.ny - 1)))))
        
        sagittalIndex = newSagittalIdx
        coronalIndex = newCoronalIdx
        
        coronalCrosshairX = nx
        sagittalCrosshairX = ny
        
        refreshCoronal()
        refreshSagittal()
    }
    
    private func handleCoronalCrosshairMove(nx: Double, ny: Double) {
        guard let vol = volume else { return }
        coronalCrosshairX = nx
        coronalCrosshairY = ny
        
        // nx corresponds to Sagittal plane (X index)
        // ny corresponds to Axial plane (Z index, inverted since top is Superior)
        let newSagittalIdx = min(vol.nx - 1, max(0, Int(round(nx * Double(vol.nx - 1)))))
        let newAxialIdx = min(vol.nz - 1, max(0, Int(round((1.0 - ny) * Double(vol.nz - 1)))))
        
        sagittalIndex = newSagittalIdx
        axialIndex = newAxialIdx
        
        axialCrosshairX = nx
        sagittalCrosshairY = ny
        
        refreshAxial()
        refreshSagittal()
    }
    
    private func handleSagittalCrosshairMove(nx: Double, ny: Double) {
        guard let vol = volume else { return }
        sagittalCrosshairX = nx
        sagittalCrosshairY = ny
        
        // nx corresponds to Coronal plane (Y index)
        // ny corresponds to Axial plane (Z index, inverted since top is Superior)
        let newCoronalIdx = min(vol.ny - 1, max(0, Int(round(nx * Double(vol.ny - 1)))))
        let newAxialIdx = min(vol.nz - 1, max(0, Int(round((1.0 - ny) * Double(vol.nz - 1)))))
        
        coronalIndex = newCoronalIdx
        axialIndex = newAxialIdx
        
        axialCrosshairY = nx
        coronalCrosshairY = ny
        
        refreshAxial()
        refreshCoronal()
    }
    
    private func scrollAxial(delta: Int) {
        guard let vol = volume else { return }
        axialIndex = min(vol.nz - 1, max(0, axialIndex + delta))
        let normZ = 1.0 - (Double(axialIndex) / Double(max(1, vol.nz - 1)))
        coronalCrosshairY = normZ
        sagittalCrosshairY = normZ
        refreshAxial()
    }
    
    private func scrollCoronal(delta: Int) {
        guard let vol = volume else { return }
        coronalIndex = min(vol.ny - 1, max(0, coronalIndex + delta))
        let normY = Double(coronalIndex) / Double(max(1, vol.ny - 1))
        axialCrosshairY = normY
        sagittalCrosshairX = normY
        refreshCoronal()
    }
    
    private func scrollSagittal(delta: Int) {
        guard let vol = volume else { return }
        sagittalIndex = min(vol.nx - 1, max(0, sagittalIndex + delta))
        let normX = Double(sagittalIndex) / Double(max(1, vol.nx - 1))
        axialCrosshairX = normX
        coronalCrosshairX = normX
        refreshSagittal()
    }
    
    // MARK: - Volume Initialization & Slicing
    
    private func initializeVolume() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let storage = MerilStorageManager.shared
            var insts: [DicomInstance] = []
            
            if let ser = self.series {
                insts = storage.getInstances(seriesInstanceUid: ser.seriesInstanceUid)
            }
            if insts.isEmpty {
                let allSeries = storage.getSeries(studyInstanceUid: self.study.studyInstanceUid)
                if let firstSer = allSeries.first {
                    insts = storage.getInstances(seriesInstanceUid: firstSer.seriesInstanceUid)
                }
            }
            
            guard !insts.isEmpty else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            do {
                let vol = try MerilVolumeEngine.buildVolume(
                    seriesUid: insts[0].seriesInstanceUid,
                    instances: insts,
                    targetResolution: 256
                ) { cur, total in
                    DispatchQueue.main.async {
                        self.progress = Double(cur) / Double(total)
                        self.loadingStatus = "Decoding Slices (\(cur)/\(total))..."
                    }
                }
                
                // Initialize Centralized Labelmap Engine
                MerilLabelmapManager.shared.initialize(for: vol)
                
                DispatchQueue.main.async {
                    self.volume = vol
                    self.axialIndex = vol.nz / 2
                    self.coronalIndex = vol.ny / 2
                    self.sagittalIndex = vol.nx / 2
                    
                    self.refreshAllPlates()
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func refreshAllPlates() {
        refreshAxial()
        refreshCoronal()
        refreshSagittal()
        updateMip(az: mipAzimuth, el: mipElevation)
    }
    
    private func refreshAxial() {
        guard let vol = volume else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let res = MerilMprReslicer.reslicePlane(
                volume: vol,
                plane: .axial,
                sliceIndex: self.axialIndex,
                windowCenter: self.windowCenter,
                windowWidth: self.windowWidth
            )
            DispatchQueue.main.async { self.axialResult = res }
        }
    }
    
    private func refreshCoronal() {
        guard let vol = volume else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let res = MerilMprReslicer.reslicePlane(
                volume: vol,
                plane: .coronal,
                sliceIndex: self.coronalIndex,
                windowCenter: self.windowCenter,
                windowWidth: self.windowWidth
            )
            DispatchQueue.main.async { self.coronalResult = res }
        }
    }
    
    private func refreshSagittal() {
        guard let vol = volume else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let res = MerilMprReslicer.reslicePlane(
                volume: vol,
                plane: .sagittal,
                sliceIndex: self.sagittalIndex,
                windowCenter: self.windowCenter,
                windowWidth: self.windowWidth
            )
            DispatchQueue.main.async { self.sagittalResult = res }
        }
    }
    
    private func updateMip(az: Double, el: Double) {
        guard let vol = volume else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let res = MerilMprReslicer.generateVolumeMip(
                volume: vol,
                azimuthDeg: az,
                elevationDeg: el,
                windowCenter: 300.0,
                windowWidth: 1500.0
            )
            DispatchQueue.main.async { self.mipResult = res }
        }
    }
}
