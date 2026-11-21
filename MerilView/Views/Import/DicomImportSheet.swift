import SwiftUI
import UniformTypeIdentifiers

/// Sheet presenting native iOS document and folder pickers for DICOM ingestion.
public struct DicomImportSheet: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var showDocPicker = false
    @State private var isImporting = false
    @State private var currentProgress: MerilDicomImporter.ImportProgress?
    @State private var importResult: (imported: Int, skipped: Int)?
    @State private var errorMessage: String?
    
    private let importer = MerilDicomImporter()
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                MerilTheme.background.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.down.on.square.fill")
                            .font(.system(size: 48))
                            .foregroundColor(MerilTheme.accent)
                        
                        Text("Import DICOM Studies")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(MerilTheme.textPrimary)
                        
                        Text("Select single or multiple .dcm files, entire study folders, or .zip archives from your iPhone Files app.")
                            .font(.system(size: 13))
                            .foregroundColor(MerilTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 24)
                    
                    if isImporting {
                        VStack(spacing: 14) {
                            ProgressView().tint(MerilTheme.accent).scaleEffect(1.3)
                            
                            if let p = currentProgress {
                                Text("Processing: \(p.currentFileName)")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(MerilTheme.textMuted)
                                    .lineLimit(1)
                                
                                ProgressView(value: Double(p.current), total: Double(max(1, p.total)))
                                    .tint(MerilTheme.accent)
                                    .frame(width: 240)
                                
                                HStack(spacing: 20) {
                                    Text("Imported: \(p.importedCount)").foregroundColor(MerilTheme.success)
                                    Text("Duplicates: \(p.skippedCount)").foregroundColor(MerilTheme.warning)
                                }
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            }
                        }
                        .padding(24)
                        .background(MerilTheme.surface)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MerilTheme.border, lineWidth: 1))
                    } else if let res = importResult {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(MerilTheme.success)
                            Text("Import Completed Successfully")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(MerilTheme.textPrimary)
                            Text("Imported \(res.imported) instances (\(res.skipped) duplicates skipped)")
                                .font(.system(size: 13))
                                .foregroundColor(MerilTheme.textSecondary)
                            
                            Button("Done") {
                                dismiss()
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(MerilTheme.background)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(MerilTheme.accent)
                            .cornerRadius(8)
                            .padding(.top, 8)
                        }
                        .padding(24)
                        .background(MerilTheme.surface)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MerilTheme.border, lineWidth: 1))
                    } else {
                        VStack(spacing: 14) {
                            Button(action: { showDocPicker = true }) {
                                HStack {
                                    Image(systemName: "folder.badge.plus")
                                    Text("Browse Files & Folders")
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(MerilTheme.background)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(MerilTheme.accent)
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal, 32)
                    }
                    
                    if let err = errorMessage {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundColor(MerilTheme.danger)
                            .padding(.horizontal, 24)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(MerilTheme.accent)
                }
            }
            .sheet(isPresented: $showDocPicker) {
                DocumentPickerWrapper { urls in
                    startImport(urls: urls)
                }
            }
        }
    }
    
    private func startImport(urls: [URL]) {
        guard !urls.isEmpty else { return }
        isImporting = true
        errorMessage = nil
        
        Task {
            do {
                let res = try await importer.importURLs(urls) { progress in
                    Task { @MainActor in
                        self.currentProgress = progress
                    }
                }
                await MainActor.run {
                    self.importResult = res
                    self.isImporting = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Import error: \(error.localizedDescription)"
                    self.isImporting = false
                }
            }
        }
    }
}

/// UIViewControllerRepresentable wrapping UIDocumentPickerViewController.
struct DocumentPickerWrapper: UIViewControllerRepresentable {
    let onPick: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [
            UTType(filenameExtension: "dcm") ?? .data,
            .folder,
            .zip,
            .data
        ]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        init(onPick: @escaping ([URL]) -> Void) {
            self.onPick = onPick
        }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
    }
}
