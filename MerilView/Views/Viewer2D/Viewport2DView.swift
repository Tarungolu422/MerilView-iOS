import SwiftUI

/// High-performance 2D medical viewport with touch gestures, clinical HUD, and orientation tags.
public struct Viewport2DView: View {
    public let instances: [DicomInstance]
    @Binding public var currentSliceIndex: Int
    @Binding public var windowCenter: Double
    @Binding public var windowWidth: Double
    @Binding public var invert: Bool
    @Binding public var activeTool: ViewerTool
    
    @State private var renderedImage: UIImage?
    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero
    @State private var dragStartPoint: CGPoint?
    @State private var draftPoints: [NormalizedPoint] = []
    @State private var measurements: [DicomMeasurement] = []
    
    private let cache = MerilCacheManager.shared
    
    public init(
        instances: [DicomInstance],
        currentSliceIndex: Binding<Int>,
        windowCenter: Binding<Double>,
        windowWidth: Binding<Double>,
        invert: Binding<Bool>,
        activeTool: Binding<ViewerTool>
    ) {
        self.instances = instances
        self._currentSliceIndex = currentSliceIndex
        self._windowCenter = windowCenter
        self._windowWidth = windowWidth
        self._invert = invert
        self._activeTool = activeTool
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                // 1. Slice Image Surface
                if let image = renderedImage {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(zoomScale)
                        .offset(panOffset)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    ProgressView().tint(MerilTheme.accent)
                }
                
                // 2. Calibrated Measurements Canvas
                MeasurementOverlayView(
                    measurements: measurements.filter { $0.sliceIndex == currentSliceIndex },
                    activeTool: activeTool,
                    currentPoints: draftPoints,
                    size: geometry.size
                )
                .scaleEffect(zoomScale)
                .offset(panOffset)
                
                // 3. Anatomical Orientation Markers
                VStack {
                    Text("A") // Anterior
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(MerilTheme.accent.opacity(0.85))
                        .padding(.top, 8)
                    Spacer()
                    Text("P") // Posterior
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(MerilTheme.accent.opacity(0.85))
                        .padding(.bottom, 36)
                }
                
                HStack {
                    Text("R") // Right
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(MerilTheme.accent.opacity(0.85))
                        .padding(.leading, 8)
                    Spacer()
                    Text("L") // Left
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(MerilTheme.accent.opacity(0.85))
                        .padding(.trailing, 8)
                }
                
                // 4. Clinical HUD Overlay
                VStack {
                    HStack(alignment: .top) {
                        // Top-Left: Slice Demographics
                        VStack(alignment: .leading, spacing: 2) {
                            if let inst = currentInstance {
                                Text("Slice \(currentSliceIndex + 1) / \(max(1, instances.count))")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(MerilTheme.textPrimary)
                                Text("Thickness: \(String(format: "%.1f mm", inst.sliceThickness))")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(MerilTheme.textSecondary)
                                Text("Matrix: \(inst.columns) x \(inst.rows)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(MerilTheme.textMuted)
                            }
                        }
                        
                        Spacer()
                        
                        // Top-Right: Window / Level Info
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("WL: \(Int(windowCenter))  WW: \(Int(windowWidth))")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(MerilTheme.accent)
                            if invert {
                                Text("INVERTED")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(MerilTheme.warning)
                            }
                            Text(String(format: "Zoom: %.1fx", zoomScale))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(MerilTheme.textMuted)
                        }
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.4))
                    
                    Spacer()
                }
            }
            // Gestures: Drag, Pinch, Double-Tap
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDragChanged(value: value, size: geometry.size)
                    }
                    .onEnded { value in
                        handleDragEnded(value: value, size: geometry.size)
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { scale in
                        zoomScale = max(0.5, min(8.0, scale))
                    }
            )
            .onTapGesture(count: 2) {
                // Double tap reset
                withAnimation(.spring()) {
                    zoomScale = 1.0
                    panOffset = .zero
                }
            }
        }
        .onAppear {
            loadSlice(index: currentSliceIndex)
        }
        .onChange(of: currentSliceIndex) { _, newIdx in
            loadSlice(index: newIdx)
        }
        .onChange(of: windowCenter) { _, _ in
            loadSlice(index: currentSliceIndex)
        }
        .onChange(of: windowWidth) { _, _ in
            loadSlice(index: currentSliceIndex)
        }
        .onChange(of: invert) { _, _ in
            loadSlice(index: currentSliceIndex)
        }
    }
    
    private var currentInstance: DicomInstance? {
        guard currentSliceIndex >= 0, currentSliceIndex < instances.count else { return instances.first }
        return instances[currentSliceIndex]
    }
    
    // MARK: - Gestures
    
    private func handleDragChanged(value: DragGesture.Value, size: CGSize) {
        switch activeTool {
        case .scroll:
            let dy = value.translation.height
            let sensitivity: CGFloat = 8.0
            let step = Int(-dy / sensitivity)
            if step != 0 {
                let next = max(0, min(instances.count - 1, currentSliceIndex + step))
                if next != currentSliceIndex {
                    currentSliceIndex = next
                }
            }
            
        case .windowLevel:
            let dx = Double(value.translation.width)
            let dy = Double(value.translation.height)
            windowWidth = max(1.0, windowWidth + dx * 2.0)
            windowCenter = windowCenter - dy * 1.5
            
        case .pan:
            panOffset = CGSize(
                width: lastPanOffset.width + value.translation.width,
                height: lastPanOffset.height + value.translation.height
            )
            
        case .length, .ellipseRoi, .rectangleRoi:
            let p1 = NormalizedPoint(x: value.startLocation.x / size.width, y: value.startLocation.y / size.height)
            let p2 = NormalizedPoint(x: value.location.x / size.width, y: value.location.y / size.height)
            draftPoints = [p1, p2]
            
        default:
            break
        }
    }
    
    private func handleDragEnded(value: DragGesture.Value, size: CGSize) {
        if activeTool == .pan {
            lastPanOffset = panOffset
        } else if (activeTool == .length || activeTool == .ellipseRoi || activeTool == .rectangleRoi) && draftPoints.count >= 2 {
            commitMeasurement(size: size)
            draftPoints = []
        }
    }
    
    private func commitMeasurement(size: CGSize) {
        guard let inst = currentInstance, draftPoints.count >= 2 else { return }
        let p1 = draftPoints[0]
        let p2 = draftPoints[1]
        
        switch activeTool {
        case .length:
            let mm = MeasurementCalculator.calculateLengthMm(
                p1: p1,
                p2: p2,
                rows: inst.rows,
                cols: inst.columns,
                pixelSpacing: inst.pixelSpacing
            )
            let m = DicomMeasurement(
                type: .length,
                studyInstanceUid: inst.studyInstanceUid,
                seriesInstanceUid: inst.seriesInstanceUid,
                sopInstanceUid: inst.sopInstanceUid,
                sliceIndex: currentSliceIndex,
                points: [p1, p2],
                value: mm,
                unit: "mm"
            )
            measurements.append(m)
            
        case .ellipseRoi:
            let rx = abs(p2.x - p1.x) / 2.0
            let ry = abs(p2.y - p1.y) / 2.0
            let center = NormalizedPoint(x: min(p1.x, p2.x) + rx, y: min(p1.y, p2.y) + ry)
            
            let cachedPixels = cache.getDecodedPixels(filePath: inst.filePath) ?? []
            let stats = MeasurementCalculator.calculateEllipseStats(
                center: center,
                rx: rx,
                ry: ry,
                pixels: cachedPixels,
                rows: inst.rows,
                cols: inst.columns,
                pixelSpacing: inst.pixelSpacing
            )
            
            let m = DicomMeasurement(
                type: .ellipseRoi,
                studyInstanceUid: inst.studyInstanceUid,
                seriesInstanceUid: inst.seriesInstanceUid,
                sopInstanceUid: inst.sopInstanceUid,
                sliceIndex: currentSliceIndex,
                points: [p1, p2],
                value: stats.areaMm2,
                unit: "mm²",
                meanHu: stats.mean,
                minHu: stats.minVal,
                maxHu: stats.maxVal,
                stdDevHu: stats.stdDev,
                pixelCount: stats.count
            )
            measurements.append(m)
            
        case .rectangleRoi:
            let w = abs(p2.x - p1.x)
            let h = abs(p2.y - p1.y)
            let topLeft = NormalizedPoint(x: min(p1.x, p2.x), y: min(p1.y, p2.y))
            let cachedPixels = cache.getDecodedPixels(filePath: inst.filePath) ?? []
            let stats = MeasurementCalculator.calculateRectangleStats(
                topLeft: topLeft,
                width: w,
                height: h,
                pixels: cachedPixels,
                rows: inst.rows,
                cols: inst.columns,
                pixelSpacing: inst.pixelSpacing
            )
            
            let m = DicomMeasurement(
                type: .rectangleRoi,
                studyInstanceUid: inst.studyInstanceUid,
                seriesInstanceUid: inst.seriesInstanceUid,
                sopInstanceUid: inst.sopInstanceUid,
                sliceIndex: currentSliceIndex,
                points: [p1, p2],
                value: stats.areaMm2,
                unit: "mm²",
                meanHu: stats.mean,
                minHu: stats.minVal,
                maxHu: stats.maxVal,
                stdDevHu: stats.stdDev,
                pixelCount: stats.count
            )
            measurements.append(m)
            
        default:
            break
        }
    }
    
    // MARK: - Image Rendering
    
    private func loadSlice(index: Int) {
        guard index >= 0, index < instances.count else { return }
        let inst = instances[index]
        
        if let cached = cache.getCachedImage(filePath: inst.filePath, wc: windowCenter, ww: windowWidth, invert: invert) {
            self.renderedImage = cached
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fileUrl = URL(fileURLWithPath: inst.filePath)
            guard let data = try? Data(contentsOf: fileUrl, options: [.mappedIfSafe]),
                  let metadata = try? MerilDicomParser.parse(data: data) else {
                return
            }
            
            var rawPixels = cache.getDecodedPixels(filePath: inst.filePath)
            if rawPixels == nil {
                rawPixels = try? MerilDicomDecoder.decodePixels(data: data, metadata: metadata)
                if let p = rawPixels {
                    cache.cacheDecodedPixels(p, filePath: inst.filePath)
                }
            }
            
            guard let pixels = rawPixels else { return }
            
            if let image = MerilDicomDecoder.renderSliceToImage(
                rawPixels: pixels,
                width: metadata.columns,
                height: metadata.rows,
                metadata: metadata,
                windowCenter: windowCenter,
                windowWidth: windowWidth,
                invert: invert
            ) {
                cache.cacheImage(image, filePath: inst.filePath, wc: windowCenter, ww: windowWidth, invert: invert)
                DispatchQueue.main.async {
                    if self.currentSliceIndex == index {
                        self.renderedImage = image
                    }
                }
            }
        }
    }
}
