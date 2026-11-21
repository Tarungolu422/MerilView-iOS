import Foundation
import Compression

/// Native ZIP archive extractor for DICOM study archives.
public final class ZipArchiveExtractor {
    
    public enum ZipError: Error, LocalizedError {
        case invalidZipHeader
        case decompressionFailed
        case destinationError
        
        public var errorDescription: String? {
            switch self {
            case .invalidZipHeader: return "Archive does not contain valid ZIP structure."
            case .decompressionFailed: return "Failed to decompress file entry in archive."
            case .destinationError: return "Could not create target extraction directory."
            }
        }
    }
    
    /// Unpacks a ZIP file into a target directory, returning URLs of all extracted files.
    public static func unzip(archiveURL: URL, destinationURL: URL) throws -> [URL] {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        
        let data = try Data(contentsOf: archiveURL, options: [.mappedIfSafe])
        var extractedFiles: [URL] = []
        var offset = 0
        let len = data.count
        
        while offset <= len - 30 {
            // Local file header signature: 0x04034b50 ("PK\003\004")
            let sig = UInt32(data[offset]) |
                      (UInt32(data[offset + 1]) << 8) |
                      (UInt32(data[offset + 2]) << 16) |
                      (UInt32(data[offset + 3]) << 24)
            
            guard sig == 0x04034b50 else {
                // Reached central directory or end of archive
                break
            }
            
            let method = UInt16(data[offset + 8]) | (UInt16(data[offset + 9]) << 8)
            let compSize = Int(UInt32(data[offset + 18]) |
                               (UInt32(data[offset + 19]) << 8) |
                               (UInt32(data[offset + 20]) << 16) |
                               (UInt32(data[offset + 21]) << 24))
            let uncompSize = Int(UInt32(data[offset + 22]) |
                                 (UInt32(data[offset + 23]) << 8) |
                                 (UInt32(data[offset + 24]) << 16) |
                                 (UInt32(data[offset + 25]) << 24))
            let nameLen = Int(UInt16(data[offset + 26]) | (UInt16(data[offset + 27]) << 8))
            let extraLen = Int(UInt16(data[offset + 28]) | (UInt16(data[offset + 29]) << 8))
            
            offset += 30
            guard offset + nameLen <= len else { break }
            
            let nameData = data.subdata(in: offset..<(offset + nameLen))
            let fileName = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .ascii) ?? "file"
            offset += nameLen + extraLen
            
            guard offset + compSize <= len else { break }
            let compData = data.subdata(in: offset..<(offset + compSize))
            offset += compSize
            
            // Skip macOS metadata and directories
            if fileName.contains("__MACOSX") || fileName.hasSuffix(".DS_Store") || fileName.hasSuffix("/") {
                continue
            }
            
            let destFileUrl = destinationURL.appendingPathComponent(fileName)
            try fileManager.createDirectory(at: destFileUrl.deletingLastPathComponent(), withIntermediateDirectories: true)
            
            if method == 0 {
                // Store (uncompressed)
                try compData.write(to: destFileUrl, options: .atomic)
                extractedFiles.append(destFileUrl)
            } else if method == 8 {
                // Deflate
                if let uncompressed = decompressDeflate(data: compData, uncompressedSize: uncompSize) {
                    try uncompressed.write(to: destFileUrl, options: .atomic)
                    extractedFiles.append(destFileUrl)
                }
            }
        }
        
        return extractedFiles
    }
    
    private static func decompressDeflate(data: Data, uncompressedSize: Int) -> Data? {
        guard uncompressedSize > 0 else { return Data() }
        var destData = Data(count: uncompressedSize)
        
        let decompressedCount = destData.withUnsafeMutableBytes { destBuffer in
            data.withUnsafeBytes { srcBuffer in
                compression_decode_buffer(
                    destBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    uncompressedSize,
                    srcBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        
        if decompressedCount > 0 {
            destData.count = decompressedCount
            return destData
        }
        return nil
    }
}
