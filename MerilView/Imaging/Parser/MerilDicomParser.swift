import Foundation

/// Fast, binary-accurate DICOM Part 10 parser for Apple iOS.
public final class MerilDicomParser {
    
    public enum ParserError: Error, LocalizedError {
        case fileTooShort
        case invalidMagic
        case invalidTag
        case truncatedData
        
        public var errorDescription: String? {
            switch self {
            case .fileTooShort: return "File is too short to be a valid DICOM dataset."
            case .invalidMagic: return "File does not contain valid DICOM header or magic bytes."
            case .invalidTag: return "Corrupted or unreadable DICOM element encountered."
            case .truncatedData: return "Data ended prematurely while parsing DICOM elements."
            }
        }
    }
    
    /// Quickly validates if data represents a DICOM Part 10 file.
    public static func isDicom(data: Data) -> Bool {
        guard data.count >= 132 else { return false }
        // Standard Part 10 preamble check
        if data[128] == 0x44 && data[129] == 0x49 && data[130] == 0x43 && data[131] == 0x4D {
            return true
        }
        // Non-preamble check (starts directly with Group 0x0008 or 0x0002)
        let g0 = data[0]
        let g1 = data[1]
        if (g0 == 0x08 && g1 == 0x00) || (g0 == 0x02 && g1 == 0x00) ||
           (g0 == 0x00 && g1 == 0x08) || (g0 == 0x00 && g1 == 0x02) {
            return true
        }
        return false
    }
    
    /// Parses a DICOM file from URL.
    public static func parse(fileURL: URL) throws -> DicomMetadata {
        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        return try parse(data: data)
    }
    
    /// Parses DICOM metadata from raw Data buffer.
    public static func parse(data: Data) throws -> DicomMetadata {
        guard data.count >= 132 else { throw ParserError.fileTooShort }
        
        let hasMagic = data[128] == 0x44 && data[129] == 0x49 && data[130] == 0x43 && data[131] == 0x4D
        var offset = hasMagic ? 132 : 0
        let len = data.count
        
        var patientName = "Anonymous"
        var patientId = "UNKNOWN"
        var patientBirthDate = ""
        var patientSex = "O"
        var studyInstanceUid = ""
        var studyDate = ""
        var studyTime = ""
        var modality = "CT"
        var studyDescription = ""
        var seriesInstanceUid = ""
        var seriesDescription = ""
        var seriesNumber = 1
        var sopInstanceUid = ""
        var instanceNumber = 1
        var rows = 512
        var columns = 512
        var bitsAllocated = 16
        var bitsStored = 12
        var highBit = 11
        var pixelRepresentation = 0
        var pixelSpacing = [1.0, 1.0]
        var sliceThickness = 2.0
        var sliceLocation = 0.0
        var imagePosition = [0.0, 0.0, 0.0]
        var imageOrientation = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0]
        var rescaleSlope = 1.0
        var rescaleIntercept = 0.0
        var windowCenter = 40.0
        var windowWidth = 400.0
        var transferSyntaxUid = "1.2.840.10008.1.2.1" // Explicit VR Little Endian default
        var pixelDataOffset = -1
        var pixelDataLength = 0
        
        var isExplicitVR = true
        var isLittleEndian = true
        
        while offset <= len - 8 {
            let group: UInt16
            let element: UInt16
            
            if isLittleEndian {
                group = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
                element = UInt16(data[offset + 2]) | (UInt16(data[offset + 3]) << 8)
            } else {
                group = (UInt16(data[offset]) << 8) | UInt16(data[offset + 1])
                element = (UInt16(data[offset + 2]) << 8) | UInt16(data[offset + 3])
            }
            offset += 4
            
            // Pixel Data tag reached: (7FE0, 0010)
            if group == 0x7FE0 && element == 0x0010 {
                if isExplicitVR {
                    if offset + 4 <= len {
                        let vr0 = data[offset]
                        let vr1 = data[offset + 1]
                        let isLongVR = (vr0 == 0x4F && vr1 == 0x57) || // OW
                                       (vr0 == 0x4F && vr1 == 0x42) || // OB
                                       (vr0 == 0x4F && vr1 == 0x46) || // OF
                                       (vr0 == 0x55 && vr1 == 0x54) || // UT
                                       (vr0 == 0x55 && vr1 == 0x4E) || // UN
                                       (vr0 == 0x53 && vr1 == 0x51)    // SQ
                        if isLongVR {
                            offset += 4 // Skip 2 VR bytes + 2 reserved bytes
                            if offset + 4 <= len {
                                pixelDataLength = Int(UInt32(data[offset]) |
                                                      (UInt32(data[offset + 1]) << 8) |
                                                      (UInt32(data[offset + 2]) << 16) |
                                                      (UInt32(data[offset + 3]) << 24))
                                offset += 4
                            }
                        } else {
                            offset += 2 // Skip 2 VR bytes
                            if offset + 2 <= len {
                                pixelDataLength = Int(UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8))
                                offset += 2
                            }
                        }
                    }
                } else {
                    if offset + 4 <= len {
                        pixelDataLength = Int(UInt32(data[offset]) |
                                              (UInt32(data[offset + 1]) << 8) |
                                              (UInt32(data[offset + 2]) << 16) |
                                              (UInt32(data[offset + 3]) << 24))
                        offset += 4
                    }
                }
                pixelDataOffset = offset
                break
            }
            
            // Calculate Value Length based on VR
            var valLen = 0
            var vrString = ""
            
            if isExplicitVR && group != 0xFFFE {
                let c0 = data[offset]
                let c1 = data[offset + 1]
                let isAlpha = (c0 >= 0x41 && c0 <= 0x5A) && (c1 >= 0x41 && c1 <= 0x5A)
                
                if isAlpha {
                    vrString = String(bytes: [c0, c1], encoding: .ascii) ?? ""
                    offset += 2
                    
                    let isLongVR = (vrString == "OB" || vrString == "OW" || vrString == "OF" ||
                                   vrString == "SQ" || vrString == "UT" || vrString == "UN")
                    if isLongVR {
                        offset += 2 // 2 reserved bytes
                        if offset + 4 <= len {
                            valLen = Int(UInt32(data[offset]) |
                                         (UInt32(data[offset + 1]) << 8) |
                                         (UInt32(data[offset + 2]) << 16) |
                                         (UInt32(data[offset + 3]) << 24))
                            offset += 4
                        }
                    } else {
                        if offset + 2 <= len {
                            valLen = Int(UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8))
                            offset += 2
                        }
                    }
                } else {
                    // Fallback to Implicit VR
                    if offset + 4 <= len {
                        valLen = Int(UInt32(data[offset]) |
                                     (UInt32(data[offset + 1]) << 8) |
                                     (UInt32(data[offset + 2]) << 16) |
                                     (UInt32(data[offset + 3]) << 24))
                        offset += 4
                    }
                }
            } else {
                // Implicit VR
                if offset + 4 <= len {
                    valLen = Int(UInt32(data[offset]) |
                                 (UInt32(data[offset + 1]) << 8) |
                                 (UInt32(data[offset + 2]) << 16) |
                                 (UInt32(data[offset + 3]) << 24))
                    offset += 4
                }
            }
            
            if valLen < 0 || offset + valLen > len {
                break
            }
            
            // Extract Known Metadata Tags
            switch (group, element) {
            case (0x0002, 0x0010): // Transfer Syntax UID
                if let str = readString(data: data, offset: offset, length: valLen) {
                    transferSyntaxUid = str
                    if transferSyntaxUid == "1.2.840.10008.1.2" {
                        isExplicitVR = false
                        isLittleEndian = true
                    } else if transferSyntaxUid == "1.2.840.10008.1.2.2" {
                        isExplicitVR = true
                        isLittleEndian = false
                    } else {
                        isExplicitVR = true
                        isLittleEndian = true
                    }
                }
            case (0x0010, 0x0010): // Patient Name
                if let str = readString(data: data, offset: offset, length: valLen) {
                    patientName = cleanDicomString(str)
                }
            case (0x0010, 0x0020): // Patient ID
                if let str = readString(data: data, offset: offset, length: valLen) {
                    patientId = cleanDicomString(str)
                }
            case (0x0010, 0x0030): // Patient Birth Date
                if let str = readString(data: data, offset: offset, length: valLen) {
                    patientBirthDate = cleanDicomString(str)
                }
            case (0x0010, 0x0040): // Patient Sex
                if let str = readString(data: data, offset: offset, length: valLen) {
                    patientSex = cleanDicomString(str)
                }
            case (0x0020, 0x000D): // Study Instance UID
                if let str = readString(data: data, offset: offset, length: valLen) {
                    studyInstanceUid = cleanDicomString(str)
                }
            case (0x0008, 0x0020): // Study Date
                if let str = readString(data: data, offset: offset, length: valLen) {
                    studyDate = cleanDicomString(str)
                }
            case (0x0008, 0x0030): // Study Time
                if let str = readString(data: data, offset: offset, length: valLen) {
                    studyTime = cleanDicomString(str)
                }
            case (0x0008, 0x0060): // Modality
                if let str = readString(data: data, offset: offset, length: valLen) {
                    modality = cleanDicomString(str)
                }
            case (0x0008, 0x1030): // Study Description
                if let str = readString(data: data, offset: offset, length: valLen) {
                    studyDescription = cleanDicomString(str)
                }
            case (0x0020, 0x000E): // Series Instance UID
                if let str = readString(data: data, offset: offset, length: valLen) {
                    seriesInstanceUid = cleanDicomString(str)
                }
            case (0x0008, 0x103E): // Series Description
                if let str = readString(data: data, offset: offset, length: valLen) {
                    seriesDescription = cleanDicomString(str)
                }
            case (0x0020, 0x0011): // Series Number
                if let num = readInt(data: data, offset: offset, length: valLen) {
                    seriesNumber = num
                }
            case (0x0008, 0x0018): // SOP Instance UID
                if let str = readString(data: data, offset: offset, length: valLen) {
                    sopInstanceUid = cleanDicomString(str)
                }
            case (0x0020, 0x0013): // Instance Number
                if let num = readInt(data: data, offset: offset, length: valLen) {
                    instanceNumber = num
                }
            case (0x0028, 0x0010): // Rows
                if valLen >= 2 {
                    rows = Int(UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8))
                }
            case (0x0028, 0x0011): // Columns
                if valLen >= 2 {
                    columns = Int(UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8))
                }
            case (0x0028, 0x0100): // Bits Allocated
                if valLen >= 2 {
                    bitsAllocated = Int(UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8))
                }
            case (0x0028, 0x0101): // Bits Stored
                if valLen >= 2 {
                    bitsStored = Int(UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8))
                }
            case (0x0028, 0x0102): // High Bit
                if valLen >= 2 {
                    highBit = Int(UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8))
                }
            case (0x0028, 0x0103): // Pixel Representation
                if valLen >= 2 {
                    pixelRepresentation = Int(UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8))
                }
            case (0x0028, 0x0030): // Pixel Spacing
                if let str = readString(data: data, offset: offset, length: valLen) {
                    let parts = str.split(separator: "\\").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                    if parts.count >= 2 {
                        pixelSpacing = parts
                    }
                }
            case (0x0018, 0x0050): // Slice Thickness
                if let str = readString(data: data, offset: offset, length: valLen), let d = Double(str.trimmingCharacters(in: .whitespaces)) {
                    sliceThickness = d
                }
            case (0x0020, 0x1041): // Slice Location
                if let str = readString(data: data, offset: offset, length: valLen), let d = Double(str.trimmingCharacters(in: .whitespaces)) {
                    sliceLocation = d
                }
            case (0x0020, 0x0032): // Image Position Patient
                if let str = readString(data: data, offset: offset, length: valLen) {
                    let parts = str.split(separator: "\\").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                    if parts.count >= 3 {
                        imagePosition = parts
                    }
                }
            case (0x0020, 0x0037): // Image Orientation Patient
                if let str = readString(data: data, offset: offset, length: valLen) {
                    let parts = str.split(separator: "\\").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                    if parts.count >= 6 {
                        imageOrientation = parts
                    }
                }
            case (0x0028, 0x1052): // Rescale Intercept
                if let str = readString(data: data, offset: offset, length: valLen), let d = Double(str.trimmingCharacters(in: .whitespaces)) {
                    rescaleIntercept = d
                }
            case (0x0028, 0x1053): // Rescale Slope
                if let str = readString(data: data, offset: offset, length: valLen), let d = Double(str.trimmingCharacters(in: .whitespaces)) {
                    rescaleSlope = d
                }
            case (0x0028, 0x1050): // Window Center
                if let str = readString(data: data, offset: offset, length: valLen) {
                    let first = str.split(separator: "\\").first.map(String.init) ?? str
                    if let d = Double(first.trimmingCharacters(in: .whitespaces)) {
                        windowCenter = d
                    }
                }
            case (0x0028, 0x1051): // Window Width
                if let str = readString(data: data, offset: offset, length: valLen) {
                    let first = str.split(separator: "\\").first.map(String.init) ?? str
                    if let d = Double(first.trimmingCharacters(in: .whitespaces)) {
                        windowWidth = d
                    }
                }
            default:
                break
            }
            
            offset += valLen
        }
        
        return DicomMetadata(
            patientName: patientName,
            patientId: patientId,
            patientBirthDate: patientBirthDate,
            patientSex: patientSex,
            studyInstanceUid: studyInstanceUid.isEmpty ? "STUDY_\(UUID().uuidString)" : studyInstanceUid,
            studyDate: studyDate.isEmpty ? "20261121" : studyDate,
            studyTime: studyTime,
            modality: modality,
            studyDescription: studyDescription.isEmpty ? "\(modality) Study" : studyDescription,
            seriesInstanceUid: seriesInstanceUid.isEmpty ? "SERIES_\(UUID().uuidString)" : seriesInstanceUid,
            seriesDescription: seriesDescription.isEmpty ? "Series \(seriesNumber)" : seriesDescription,
            seriesNumber: seriesNumber,
            sopInstanceUid: sopInstanceUid.isEmpty ? "SOP_\(UUID().uuidString)" : sopInstanceUid,
            instanceNumber: instanceNumber,
            rows: rows,
            columns: columns,
            bitsAllocated: bitsAllocated,
            bitsStored: bitsStored,
            highBit: highBit,
            pixelRepresentation: pixelRepresentation,
            pixelSpacing: pixelSpacing,
            sliceThickness: sliceThickness,
            sliceLocation: sliceLocation,
            imagePositionPatient: imagePosition,
            imageOrientationPatient: imageOrientation,
            rescaleSlope: rescaleSlope,
            rescaleIntercept: rescaleIntercept,
            windowCenter: windowCenter,
            windowWidth: windowWidth,
            transferSyntaxUid: transferSyntaxUid,
            pixelDataOffset: pixelDataOffset >= 0 ? pixelDataOffset : 132,
            pixelDataLength: pixelDataLength
        )
    }
    
    private static func readString(data: Data, offset: Int, length: Int) -> String? {
        guard offset + length <= data.count else { return nil }
        let sub = data.subdata(in: offset..<(offset + length))
        return String(data: sub, encoding: .utf8) ?? String(data: sub, encoding: .ascii)
    }
    
    private static func readInt(data: Data, offset: Int, length: Int) -> Int? {
        guard let str = readString(data: data, offset: offset, length: length) else { return nil }
        return Int(str.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    private static func cleanDicomString(_ str: String) -> String {
        return str.replacingOccurrences(of: "\0", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
