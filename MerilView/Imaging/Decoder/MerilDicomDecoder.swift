import Foundation
import UIKit
import CoreGraphics
import Accelerate

/// Decodes DICOM pixel data buffers into calibrated scalar buffers and CoreGraphics images.
public final class MerilDicomDecoder {
    
    public enum DecoderError: Error, LocalizedError {
        case unsupportedTransferSyntax(String)
        case truncatedPixelData
        case frameExtractionFailed
        case imageCreationFailed
        
        public var errorDescription: String? {
            switch self {
            case .unsupportedTransferSyntax(let ts):
                return "Transfer syntax '\(ts)' is unsupported."
            case .truncatedPixelData:
                return "Pixel data buffer is truncated or smaller than expected dimensions."
            case .frameExtractionFailed:
                return "Failed to extract encapsulated image frame."
            case .imageCreationFailed:
                return "Failed to construct CGImage from decoded pixel buffer."
            }
        }
    }
    
    // In-memory pixel buffer cache (Int16 Hounsfield units)
    private static let pixelCache = NSCache<NSString, NSData>()
    
    public static func clearCache() {
        pixelCache.removeAllObjects()
    }
    
    /// Decodes raw DICOM bytes into an array of Int16 Hounsfield Units (HU).
    public static func decodePixels(data: Data, metadata: DicomMetadata) throws -> [Int16] {
        let numPixels = metadata.rows * metadata.columns
        guard numPixels > 0 else { return [] }
        
        let ts = metadata.transferSyntaxUid
        let offset = metadata.pixelDataOffset
        let isSigned = metadata.pixelRepresentation == 1
        
        // 1. Uncompressed Little Endian (Implicit or Explicit VR)
        if ts == "1.2.840.10008.1.2" || ts == "1.2.840.10008.1.2.1" {
            guard offset < data.count else { throw DecoderError.truncatedPixelData }
            var result = [Int16](repeating: 0, count: numPixels)
            
            if metadata.bitsAllocated == 16 {
                let bytesAvailable = min(data.count - offset, numPixels * 2)
                let count = bytesAvailable / 2
                data.withUnsafeBytes { rawBuffer in
                    guard let basePtr = rawBuffer.baseAddress?.advanced(by: offset) else { return }
                    if isSigned {
                        let srcPtr = basePtr.assumingMemoryBound(to: Int16.self)
                        for i in 0..<count {
                            result[i] = srcPtr[i]
                        }
                    } else {
                        let srcPtr = basePtr.assumingMemoryBound(to: UInt16.self)
                        for i in 0..<count {
                            result[i] = Int16(bitPattern: srcPtr[i])
                        }
                    }
                }
            } else if metadata.bitsAllocated == 8 {
                let bytesAvailable = min(data.count - offset, numPixels)
                for i in 0..<bytesAvailable {
                    result[i] = Int16(data[offset + i])
                }
            }
            return result
        }
        
        // 2. Uncompressed Big Endian
        if ts == "1.2.840.10008.1.2.2" {
            guard offset < data.count else { throw DecoderError.truncatedPixelData }
            var result = [Int16](repeating: 0, count: numPixels)
            let bytesAvailable = min(data.count - offset, numPixels * 2)
            let count = bytesAvailable / 2
            
            for i in 0..<count {
                let b0 = UInt16(data[offset + i * 2])
                let b1 = UInt16(data[offset + i * 2 + 1])
                let val = (b0 << 8) | b1
                result[i] = Int16(bitPattern: val)
            }
            return result
        }
        
        // 3. Encapsulated JPEG / JPEG 2000 / RLE
        if let frameData = extractEncapsulatedFrame(data: data, startOffset: offset) {
            if let uiImage = UIImage(data: frameData), let cgImage = uiImage.cgImage {
                return extractPixelsFromCGImage(cgImage: cgImage, expectedCount: numPixels)
            }
        }
        
        // Fallback or unsupported
        throw DecoderError.unsupportedTransferSyntax(ts)
    }
    
    /// Extracts encapsulated frame fragments (DICOM Item tags FFFE,E000)
    private static func extractEncapsulatedFrame(data: Data, startOffset: Int) -> Data? {
        var offset = startOffset >= 0 ? startOffset : 132
        let len = data.count
        
        while offset <= len - 8 {
            let tag0 = data[offset]
            let tag1 = data[offset + 1]
            let tag2 = data[offset + 2]
            let tag3 = data[offset + 3]
            
            let isItem = (tag0 == 0xFE && tag1 == 0xFF && tag2 == 0x00 && tag3 == 0xE0)
            let isDelim = (tag0 == 0xFE && tag1 == 0xFF && tag2 == 0xDD && tag3 == 0xE0)
            if isDelim { break }
            
            let itemLen = Int(UInt32(data[offset + 4]) |
                              (UInt32(data[offset + 5]) << 8) |
                              (UInt32(data[offset + 6]) << 16) |
                              (UInt32(data[offset + 7]) << 24))
            offset += 8
            
            guard itemLen >= 0, offset + itemLen <= len else { break }
            
            if isItem {
                // If this is an actual image codestream (JPEG/J2K header SOI or SOC)
                if itemLen >= 2 {
                    let b0 = data[offset]
                    let b1 = data[offset + 1]
                    // JPEG SOI: FF D8 or J2K SOC: FF 4F or JP2 box
                    let isJpeg = (b0 == 0xFF && b1 == 0xD8)
                    let isJ2k = (b0 == 0xFF && b1 == 0x4F) || (b0 == 0x00 && b1 == 0x00)
                    if isJpeg || isJ2k {
                        return data.subdata(in: offset..<(offset + itemLen))
                    }
                }
            }
            offset += itemLen
        }
        return nil
    }
    
    private static func extractPixelsFromCGImage(cgImage: CGImage, expectedCount: Int) -> [Int16] {
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return [Int16](repeating: 0, count: expectedCount)
        }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var result = [Int16](repeating: 0, count: expectedCount)
        let copyCount = min(expectedCount, pixels.count)
        for i in 0..<copyCount {
            result[i] = Int16(pixels[i])
        }
        return result
    }
    
    /// Renders a calibrated 2D slice into a displayable UIImage using Window/Level parameters.
    public static func renderSliceToImage(
        rawPixels: [Int16],
        width: Int,
        height: Int,
        metadata: DicomMetadata,
        windowCenter: Double,
        windowWidth: Double,
        invert: Bool
    ) -> UIImage? {
        guard rawPixels.count >= width * height, width > 0, height > 0 else { return nil }
        
        let lut = MerilLutEngine.getOrCreateLut(
            center: windowCenter,
            width: windowWidth,
            slope: metadata.rescaleSlope,
            intercept: metadata.rescaleIntercept,
            invert: invert,
            isSigned: metadata.pixelRepresentation == 1
        )
        
        var argbPixels = [UInt32](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            let rawU16 = UInt16(bitPattern: rawPixels[i])
            argbPixels[i] = lut[Int(rawU16)]
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue
        
        guard let provider = CGDataProvider(data: Data(bytes: &argbPixels, count: argbPixels.count * 4) as CFData) else {
            return nil
        }
        
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
}
