import Foundation
import UIKit

/// Coordinates ingestion of DICOM files, folders, and ZIP archives.
public final class MerilDicomImporter {
    
    public struct ImportProgress {
        public let current: Int
        public let total: Int
        public let importedCount: Int
        public let skippedCount: Int
        public let currentFileName: String
    }
    
    private let storage = MerilStorageManager.shared
    private let fileManager = FileManager.default
    
    public init() {}
    
    /// Imports a list of URLs (which may be files, directories, or ZIP archives).
    public func importURLs(
        _ urls: [URL],
        onProgress: ((ImportProgress) -> Void)? = nil
    ) async throws -> (imported: Int, skipped: Int) {
        // Collect all file URLs
        var candidateFiles: [URL] = []
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        
        for url in urls {
            let shouldStopAccess = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    // Traverse directory
                    if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey]) {
                        for case let fileURL as URL in enumerator {
                            candidateFiles.append(fileURL)
                        }
                    }
                } else if url.pathExtension.lowercased() == "zip" {
                    // Extract ZIP
                    if let unzipped = try? ZipArchiveExtractor.unzip(archiveURL: url, destinationURL: tempDir) {
                        candidateFiles.append(contentsOf: unzipped)
                    }
                } else {
                    candidateFiles.append(url)
                }
            }
        }
        
        let total = candidateFiles.count
        var importedCount = 0
        var skippedCount = 0
        
        for (index, fileUrl) in candidateFiles.enumerated() {
            onProgress?(ImportProgress(
                current: index + 1,
                total: total,
                importedCount: importedCount,
                skippedCount: skippedCount,
                currentFileName: fileUrl.lastPathComponent
            ))
            
            guard let data = try? Data(contentsOf: fileUrl, options: [.mappedIfSafe]),
                  MerilDicomParser.isDicom(data: data) else {
                continue
            }
            
            guard let metadata = try? MerilDicomParser.parse(data: data) else {
                continue
            }
            
            if storage.isDuplicate(sopInstanceUid: metadata.sopInstanceUid) {
                skippedCount += 1
                continue
            }
            
            do {
                _ = try storage.persistDicomFile(data: data, metadata: metadata)
                importedCount += 1
            } catch {
                print("[MerilDicomImporter] Failed to persist file \(fileUrl.lastPathComponent): \(error)")
            }
        }
        
        _ = try? fileManager.removeItem(at: tempDir)
        return (importedCount, skippedCount)
    }
}
