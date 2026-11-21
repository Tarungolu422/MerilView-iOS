import XCTest
@testable import MerilViewCore

final class DicomParserTests: XCTestCase {
    
    func testMagicByteValidation() {
        // Valid 132-byte header with DICM magic
        var validData = Data(count: 132)
        validData[128] = 0x44 // D
        validData[129] = 0x49 // I
        validData[130] = 0x43 // C
        validData[131] = 0x4D // M
        
        XCTAssertTrue(MerilDicomParser.isDicom(data: validData))
        
        // Invalid header
        var invalidData = Data(count: 132)
        invalidData[128] = 0x41
        XCTAssertFalse(MerilDicomParser.isDicom(data: invalidData))
    }
    
    func testNonPreambleValidation() {
        // Group 0x0008 at byte 0
        var group8Data = Data(count: 10)
        group8Data[0] = 0x08
        group8Data[1] = 0x00
        XCTAssertTrue(MerilDicomParser.isDicom(data: group8Data))
    }
    
    func testWindowLevelLutIdentity() {
        // Test Window 400, Level 40
        let lut = MerilLutEngine.getOrCreateLut(
            center: 40.0,
            width: 400.0,
            slope: 1.0,
            intercept: 0.0,
            invert: false,
            isSigned: false
        )
        
        XCTAssertEqual(lut.count, 65536)
        
        // At HU <= -160 (center - width/2), gray should be 0 (Black ARGB: 0xFF000000)
        // With intercept 0, slope 1, raw 0 -> HU 0 -> gray = (0 - (-160)) / 400 * 255 = 160/400 * 255 = 102
        let pixel0 = lut[0]
        let gray0 = pixel0 & 0xFF
        XCTAssertEqual(gray0, 102)
        
        // Inverted LUT check
        let lutInverted = MerilLutEngine.getOrCreateLut(
            center: 40.0,
            width: 400.0,
            slope: 1.0,
            intercept: 0.0,
            invert: true,
            isSigned: false
        )
        let pixelInv0 = lutInverted[0]
        let grayInv0 = pixelInv0 & 0xFF
        XCTAssertEqual(grayInv0, 255 - 102)
    }
}
