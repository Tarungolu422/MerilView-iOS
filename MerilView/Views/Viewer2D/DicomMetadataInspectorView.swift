import SwiftUI

/// Inspector modal sheet for browsing DICOM tags.
public struct DicomMetadataInspectorView: View {
    @Environment(\.dismiss) var dismiss
    public let metadata: DicomMetadata
    
    public init(metadata: DicomMetadata) {
        self.metadata = metadata
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                MerilTheme.background.ignoresSafeArea()
                
                List {
                    Section(header: Text("Patient Demographics").foregroundColor(MerilTheme.accent)) {
                        TagRow(tag: "(0010,0010)", name: "Patient's Name", value: metadata.patientName)
                        TagRow(tag: "(0010,0020)", name: "Patient ID", value: metadata.patientId)
                        TagRow(tag: "(0010,0030)", name: "Patient's Birth Date", value: metadata.patientBirthDate)
                        TagRow(tag: "(0010,0040)", name: "Patient's Sex", value: metadata.patientSex)
                    }
                    .listRowBackground(MerilTheme.surface)
                    
                    Section(header: Text("Study Information").foregroundColor(MerilTheme.accent)) {
                        TagRow(tag: "(0020,000D)", name: "Study Instance UID", value: metadata.studyInstanceUid)
                        TagRow(tag: "(0008,0020)", name: "Study Date", value: metadata.studyDate)
                        TagRow(tag: "(0008,0030)", name: "Study Time", value: metadata.studyTime)
                        TagRow(tag: "(0008,0060)", name: "Modality", value: metadata.modality)
                        TagRow(tag: "(0008,1030)", name: "Study Description", value: metadata.studyDescription)
                    }
                    .listRowBackground(MerilTheme.surface)
                    
                    Section(header: Text("Series & Instance Hierarchy").foregroundColor(MerilTheme.accent)) {
                        TagRow(tag: "(0020,000E)", name: "Series Instance UID", value: metadata.seriesInstanceUid)
                        TagRow(tag: "(0008,103E)", name: "Series Description", value: metadata.seriesDescription)
                        TagRow(tag: "(0020,0011)", name: "Series Number", value: "\(metadata.seriesNumber)")
                        TagRow(tag: "(0008,0018)", name: "SOP Instance UID", value: metadata.sopInstanceUid)
                        TagRow(tag: "(0020,0013)", name: "Instance Number", value: "\(metadata.instanceNumber)")
                    }
                    .listRowBackground(MerilTheme.surface)
                    
                    Section(header: Text("Image Geometry & Pixel Scaling").foregroundColor(MerilTheme.accent)) {
                        TagRow(tag: "(0028,0010)", name: "Rows", value: "\(metadata.rows)")
                        TagRow(tag: "(0028,0011)", name: "Columns", value: "\(metadata.columns)")
                        TagRow(tag: "(0028,0100)", name: "Bits Allocated", value: "\(metadata.bitsAllocated)")
                        TagRow(tag: "(0028,0101)", name: "Bits Stored", value: "\(metadata.bitsStored)")
                        TagRow(tag: "(0028,0030)", name: "Pixel Spacing", value: metadata.pixelSpacing.map { String(format: "%.4f", $0) }.joined(separator: " \\ "))
                        TagRow(tag: "(0018,0050)", name: "Slice Thickness", value: String(format: "%.2f mm", metadata.sliceThickness))
                        TagRow(tag: "(0020,0032)", name: "Image Position (Patient)", value: metadata.imagePositionPatient.map { String(format: "%.2f", $0) }.joined(separator: " \\ "))
                        TagRow(tag: "(0020,0037)", name: "Image Orientation (Patient)", value: metadata.imageOrientationPatient.map { String(format: "%.2f", $0) }.joined(separator: " \\ "))
                        TagRow(tag: "(0028,1052)", name: "Rescale Intercept", value: "\(metadata.rescaleIntercept)")
                        TagRow(tag: "(0028,1053)", name: "Rescale Slope", value: "\(metadata.rescaleSlope)")
                        TagRow(tag: "(0028,1050)", name: "Window Center", value: "\(metadata.windowCenter)")
                        TagRow(tag: "(0028,1051)", name: "Window Width", value: "\(metadata.windowWidth)")
                        TagRow(tag: "(0002,0010)", name: "Transfer Syntax UID", value: metadata.transferSyntaxUid)
                    }
                    .listRowBackground(MerilTheme.surface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("DICOM Metadata")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundColor(MerilTheme.accent)
                }
            }
        }
    }
}

struct TagRow: View {
    let tag: String
    let name: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(tag)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(MerilTheme.accent)
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(MerilTheme.textSecondary)
            }
            Text(value.isEmpty ? "None" : value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(MerilTheme.textPrimary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }
}
