import SwiftUI

/// Sheet for selecting standard clinical Window/Level presets.
public struct WindowLevelPresetSheet: View {
    @Environment(\.dismiss) var dismiss
    public let onSelectPreset: (WindowPreset) -> Void
    public let onCustomLut: (Double, Double) -> Void
    
    @State private var customWc: Double
    @State private var customWw: Double
    
    public init(
        currentWc: Double = 40.0,
        currentWw: Double = 400.0,
        onSelectPreset: @escaping (WindowPreset) -> Void,
        onCustomLut: @escaping (Double, Double) -> Void
    ) {
        self._customWc = State(initialValue: currentWc)
        self._customWw = State(initialValue: currentWw)
        self.onSelectPreset = onSelectPreset
        self.onCustomLut = onCustomLut
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                MerilTheme.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Clinical Presets List
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Clinical Window Presets")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(MerilTheme.textSecondary)
                        
                        ForEach(WindowPreset.allCases) { preset in
                            Button(action: {
                                onSelectPreset(preset)
                                dismiss()
                            }) {
                                HStack {
                                    Text(preset.rawValue)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(MerilTheme.textPrimary)
                                    Spacer()
                                    Text("WL: \(Int(preset.center))  WW: \(Int(preset.width))")
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(MerilTheme.accent)
                                }
                                .padding(12)
                                .background(MerilTheme.surface)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(MerilTheme.border, lineWidth: 1))
                            }
                        }
                    }
                    
                    Divider().background(MerilTheme.border)
                    
                    // Manual Sliders
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Custom Window Parameters")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(MerilTheme.textSecondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Window Center (Level):")
                                Spacer()
                                Text("\(Int(customWc)) HU").foregroundColor(MerilTheme.accent).font(.system(size: 13, design: .monospaced))
                            }
                            .font(.system(size: 13))
                            .foregroundColor(MerilTheme.textSecondary)
                            
                            Slider(value: $customWc, in: -1000...2000, step: 5)
                                .tint(MerilTheme.accent)
                                .onChange(of: customWc) { _, val in
                                    onCustomLut(val, customWw)
                                }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Window Width:")
                                Spacer()
                                Text("\(Int(customWw)) HU").foregroundColor(MerilTheme.accent).font(.system(size: 13, design: .monospaced))
                            }
                            .font(.system(size: 13))
                            .foregroundColor(MerilTheme.textSecondary)
                            
                            Slider(value: $customWw, in: 1...4000, step: 10)
                                .tint(MerilTheme.accent)
                                .onChange(of: customWw) { _, val in
                                    onCustomLut(customWc, val)
                                }
                        }
                    }
                    
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Window / Level")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundColor(MerilTheme.accent)
                }
            }
        }
    }
}
