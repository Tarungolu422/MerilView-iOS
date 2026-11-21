import SwiftUI

/// OHIF-inspired sidebar for anatomical segment management and CT HU thresholding.
public struct SegmentationSidebarView: View {
    @ObservedObject var labelmapManager = MerilLabelmapManager.shared
    @Binding public var minHu: Double
    @Binding public var maxHu: Double
    public let onAddSegment: () -> Void
    
    public init(
        minHu: Binding<Double>,
        maxHu: Binding<Double>,
        onAddSegment: @escaping () -> Void
    ) {
        self._minHu = minHu
        self._maxHu = maxHu
        self.onAddSegment = onAddSegment
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Text("OHIF SEGMENTATION")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(MerilTheme.accent)
                Spacer()
                Button(action: onAddSegment) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add Segment")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(MerilTheme.background)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(MerilTheme.accent)
                    .cornerRadius(6)
                }
            }
            
            // Global Opacity Slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Overlay Opacity:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(MerilTheme.textSecondary)
                    Spacer()
                    Text("\(Int(labelmapManager.globalOpacity * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(MerilTheme.accent)
                }
                Slider(value: $labelmapManager.globalOpacity, in: 0.1...1.0)
                    .tint(MerilTheme.accent)
            }
            
            Divider().background(MerilTheme.border)
            
            // Segments List
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(labelmapManager.segments) { segment in
                        SegmentRowItem(
                            segment: segment,
                            isActive: labelmapManager.activeSegmentId == segment.id,
                            onSelect: {
                                labelmapManager.activeSegmentId = segment.id
                            },
                            onToggleVisibility: {
                                if let idx = labelmapManager.segments.firstIndex(where: { $0.id == segment.id }) {
                                    labelmapManager.segments[idx].isVisible.toggle()
                                }
                            },
                            onToggleLock: {
                                if let idx = labelmapManager.segments.firstIndex(where: { $0.id == segment.id }) {
                                    labelmapManager.segments[idx].isLocked.toggle()
                                }
                            }
                        )
                    }
                }
            }
            
            Divider().background(MerilTheme.border)
            
            // CT HU Threshold Dock
            VStack(alignment: .leading, spacing: 8) {
                Text("CT THRESHOLD DOCK")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(MerilTheme.textSecondary)
                
                // Diagnostic Presets
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(ThresholdPreset.standardPresets) { preset in
                            Button(action: {
                                minHu = preset.minHu
                                maxHu = preset.maxHu
                            }) {
                                Text(preset.name)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(minHu == preset.minHu && maxHu == preset.maxHu ? MerilTheme.background : MerilTheme.textPrimary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(minHu == preset.minHu && maxHu == preset.maxHu ? MerilTheme.accent : MerilTheme.surface)
                                    .cornerRadius(4)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(MerilTheme.border, lineWidth: 1))
                            }
                        }
                    }
                }
                
                // Sliders
                HStack {
                    Text("Min: \(Int(minHu)) HU").font(.system(size: 10, design: .monospaced)).foregroundColor(MerilTheme.textMuted)
                    Spacer()
                    Text("Max: \(Int(maxHu)) HU").font(.system(size: 10, design: .monospaced)).foregroundColor(MerilTheme.textMuted)
                }
            }
        }
        .padding(14)
        .background(MerilTheme.surface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MerilTheme.border, lineWidth: 1))
    }
}

struct SegmentRowItem: View {
    let segment: SegmentItem
    let isActive: Bool
    let onSelect: () -> Void
    let onToggleVisibility: () -> Void
    let onToggleLock: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Radio Selector
            Button(action: onSelect) {
                Image(systemName: isActive ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(isActive ? MerilTheme.accent : MerilTheme.textMuted)
            }
            
            // Color Swatch
            Circle()
                .fill(Color(hex: segment.colorHex))
                .frame(width: 12, height: 12)
            
            // Segment Label
            VStack(alignment: .leading, spacing: 2) {
                Text(segment.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(MerilTheme.textPrimary)
                    .lineLimit(1)
                
                Text(String(format: "%.1f cm³", segment.volumeCm3))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(MerilTheme.textMuted)
            }
            
            Spacer()
            
            // Lock Button
            Button(action: onToggleLock) {
                Image(systemName: segment.isLocked ? "lock.fill" : "lock.open")
                    .font(.system(size: 11))
                    .foregroundColor(segment.isLocked ? MerilTheme.warning : MerilTheme.textMuted)
            }
            
            // Visibility Eye Button
            Button(action: onToggleVisibility) {
                Image(systemName: segment.isVisible ? "eye.fill" : "eye.slash")
                    .font(.system(size: 12))
                    .foregroundColor(segment.isVisible ? MerilTheme.accent : MerilTheme.textMuted)
            }
        }
        .padding(8)
        .background(isActive ? MerilTheme.surfaceHover : MerilTheme.surface)
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(isActive ? MerilTheme.accent : MerilTheme.border, lineWidth: 1))
    }
}
