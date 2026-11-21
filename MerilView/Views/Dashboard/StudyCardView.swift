import SwiftUI

/// Clinical study item card on dashboard.
public struct StudyCardView: View {
    public let study: DicomStudy
    public let onSelect: () -> Void
    public let onOpenMpr: () -> Void
    
    public init(study: DicomStudy, onSelect: @escaping () -> Void, onOpenMpr: @escaping () -> Void) {
        self.study = study
        self.onSelect = onSelect
        self.onOpenMpr = onOpenMpr
    }
    
    public var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                // Header row: Patient Name & Modality Chips
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(study.patientName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(MerilTheme.textPrimary)
                            .lineLimit(1)
                        
                        Text("ID: \(study.patientId)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(MerilTheme.textMuted)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        if study.isLocal {
                            Image(systemName: "internaldrive.fill")
                                .font(.system(size: 11))
                                .foregroundColor(MerilTheme.success)
                        }
                        ModalityChipView(study.modalities)
                    }
                }
                
                // Study description
                Text(study.studyDescription)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(MerilTheme.textSecondary)
                    .lineLimit(2)
                
                Divider().background(MerilTheme.border)
                
                // Metadata footer & Quick Actions
                HStack {
                    HStack(spacing: 14) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11))
                            Text(study.formattedStudyDate)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(MerilTheme.textMuted)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "square.stack.3d.down.right.fill")
                                .font(.system(size: 11))
                            Text("\(study.numberOfSeries) Ser / \(study.numberOfInstances) Img")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(MerilTheme.textMuted)
                    }
                    
                    Spacer()
                    
                    // Quick MPR Launch button if volumetric CT/MR
                    if study.modalities.contains("CT") || study.modalities.contains("MR") {
                        Button(action: onOpenMpr) {
                            HStack(spacing: 4) {
                                Image(systemName: "cube.transparent")
                                    .font(.system(size: 12, weight: .bold))
                                Text("3D MPR")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(MerilTheme.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(MerilTheme.accent.opacity(0.15))
                            .cornerRadius(6)
                        }
                    }
                }
            }
            .padding(14)
            .background(MerilTheme.surface)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MerilTheme.border, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
}
