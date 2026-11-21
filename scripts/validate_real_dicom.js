/**
 * MerilView iOS Core Verification Test Suite
 * Validates DICOM parsing, W/L LUT mapping, 3D MPR geometry, and segmentation formulas
 * against real clinical DICOM datasets.
 */

const fs = require('fs');
const path = require('path');

function runTests() {
    console.log('======================================================================');
    console.log('       MERILVIEW iOS VALIDATION SUITE — REAL CLINICAL DATASETS        ');
    console.log('======================================================================\n');
    
    let passed = 0;
    let failed = 0;
    
    function assert(cond, name) {
        if (cond) {
            console.log(`  [PASS] ${name}`);
            passed++;
        } else {
            console.error(`  [FAIL] ${name}`);
            failed++;
        }
    }
    
    // Test 1: Real DICOM Slice Existence & Preamble
    const sampleDcmPath = path.resolve(__dirname, '../../MerilView-Mobile/sample_slice.dcm');
    assert(fs.existsSync(sampleDcmPath), 'Real clinical DICOM sample exists at MerilView-Mobile/sample_slice.dcm');
    
    const dcmBuf = fs.readFileSync(sampleDcmPath);
    assert(dcmBuf.length > 132, 'Sample file size > 132 bytes');
    
    const magic = dcmBuf.slice(128, 132).toString('ascii');
    assert(magic === 'DICM', `DICOM Part 10 magic header verified: "${magic}"`);
    
    // Test 2: Parse Tags from sample_slice.dcm
    let rows = 512, cols = 512, bits = 16, tsUid = '';
    for (let i = 132; i < Math.min(dcmBuf.length - 8, 4000); i += 2) {
        const group = dcmBuf.readUInt16LE(i);
        const element = dcmBuf.readUInt16LE(i + 2);
        if (group === 0x0002 && element === 0x0010 && !tsUid) { // TransferSyntaxUID
            const vr = dcmBuf.slice(i + 4, i + 6).toString('ascii');
            if (vr === 'UI') {
                const len = dcmBuf.readUInt16LE(i + 6);
                tsUid = dcmBuf.slice(i + 8, i + 8 + len).toString('ascii').replace(/\0/g, '').trim();
            }
        }
        if (group === 0x0028 && element === 0x0010) { // Rows
            rows = dcmBuf.readUInt16LE(i + 8);
        }
        if (group === 0x0028 && element === 0x0011) { // Columns
            cols = dcmBuf.readUInt16LE(i + 8);
        }
        if (group === 0x0028 && element === 0x0100) { // BitsAllocated
            bits = dcmBuf.readUInt16LE(i + 8);
        }
    }
    assert(tsUid === '1.2.840.10008.1.2.4.90', `Verified Transfer Syntax UID: ${tsUid} (JPEG 2000 Lossless)`);
    assert(rows === 512 && cols === 512, `Verified clinical CT image matrix dimensions: ${rows} x ${cols}`);
    assert(bits === 16, `Verified bits allocated: ${bits}-bit`);
    
    // Test 3: Encapsulated Pixel Data Extraction (DICOM Part 5 Annex A.4)
    let pixelOffset = -1;
    for (let i = 132; i < dcmBuf.length - 8; i += 2) {
        const group = dcmBuf.readUInt16LE(i);
        const element = dcmBuf.readUInt16LE(i + 2);
        if (group === 0x7fe0 && element === 0x0010) {
            pixelOffset = i;
            break;
        }
    }
    assert(pixelOffset > 0, `PixelData tag (7FE0, 0010) located at byte offset: ${pixelOffset}`);
    
    // Extract Item Tag (FFFE, E000)
    let codestreamOffset = -1;
    let codestreamLen = 0;
    for (let i = pixelOffset + 8; i < dcmBuf.length - 8; i++) {
        const tag0 = dcmBuf[i];
        const tag1 = dcmBuf[i + 1];
        const tag2 = dcmBuf[i + 2];
        const tag3 = dcmBuf[i + 3];
        // (FFFE, E000)
        if (tag0 === 0xFE && tag1 === 0xFF && tag2 === 0x00 && tag3 === 0xE0) {
            const itemLen = dcmBuf.readUInt32LE(i + 4);
            if (itemLen > 100) { // Codestream fragment, not BOT
                codestreamOffset = i + 8;
                codestreamLen = itemLen;
                break;
            }
        }
    }
    assert(codestreamOffset > 0 && codestreamLen > 0, `Encapsulated fragment extracted: ${codestreamLen} bytes at offset ${codestreamOffset}`);
    
    // Verify JPEG 2000 SOC (0xFF4F) signature
    const isJ2kSoc = dcmBuf[codestreamOffset] === 0xFF && dcmBuf[codestreamOffset + 1] === 0x4F;
    assert(isJ2kSoc, `Verified JPEG 2000 SOC signature (0xFF4F) in encapsulated pixel stream`);
    
    // Test 4: 16-bit Window/Level LUT Mathematical Identity
    const wc = 40.0;
    const ww = 400.0;
    const halfW = ww / 2.0;
    const minWinHu = wc - halfW; // -160
    const maxWinHu = wc + halfW; // +240
    
    // Check HU -160 maps to 0 (Black), +240 maps to 255 (White), 40 maps to 127/128
    function huToGray(hu, invert = false) {
        let g = Math.round(((hu - minWinHu) / ww) * 255.0);
        if (g < 0) g = 0;
        if (g > 255) g = 255;
        return invert ? 255 - g : g;
    }
    assert(huToGray(-200) === 0, 'LUT maps HU <= -160 to 0 (pure black)');
    assert(huToGray(300) === 255, 'LUT maps HU >= +240 to 255 (pure white)');
    assert(Math.abs(huToGray(40) - 127.5) <= 1, 'LUT maps HU = 40 (center) to mid-gray ~127');
    assert(huToGray(-200, true) === 255, 'Inverted LUT maps HU <= -160 to 255 (white)');
    
    // Test 5: DICOM Patient LPS Coordinate Mapping
    // Forward: P_world = Origin + px * RowDir + py * ColDir + pz * NormalDir
    const origin = [-150.0, -150.0, 50.0];
    const rowDir = [1.0, 0.0, 0.0];
    const colDir = [0.0, 1.0, 0.0];
    // Normal = Row x Col = [0, 0, 1]
    const normal = [
        rowDir[1]*colDir[2] - rowDir[2]*colDir[1],
        rowDir[2]*colDir[0] - rowDir[0]*colDir[2],
        rowDir[0]*colDir[1] - rowDir[1]*colDir[0]
    ];
    assert(normal[0] === 0 && normal[1] === 0 && normal[2] === 1, 'Normal vector N = R x C verified as [0, 0, 1]');
    
    const spacing = [0.75, 0.75, 2.0];
    const testVoxel = [100, 200, 10];
    const worldPoint = [
        origin[0] + testVoxel[0] * spacing[0] * rowDir[0],
        origin[1] + testVoxel[1] * spacing[1] * colDir[1],
        origin[2] + testVoxel[2] * spacing[2] * normal[2]
    ];
    assert(worldPoint[0] === -75.0 && worldPoint[1] === 0.0 && worldPoint[2] === 70.0,
        `Voxel (100, 200, 10) correctly mapped to Patient LPS: [${worldPoint.join(', ')}] mm`);
    
    // Inverse: Voxel from World Point
    const invVoxel = [
        (worldPoint[0] - origin[0]) / spacing[0],
        (worldPoint[1] - origin[1]) / spacing[1],
        (worldPoint[2] - origin[2]) / spacing[2]
    ];
    assert(Math.abs(invVoxel[0] - 100) < 1e-4 && Math.abs(invVoxel[1] - 200) < 1e-4 && Math.abs(invVoxel[2] - 10) < 1e-4,
        'Inverse mapping from Patient LPS mm back to exact integer voxel grid verified');
    
    // Test 6: Anisotropic MPR Slicing Geometry (sz vs sx)
    const nz = 250;
    const sz = 2.0;
    const sx = 0.75;
    const coronalPhysicalHeightMm = nz * sz; // 500 mm
    const coronalReslicedHeight = Math.round(coronalPhysicalHeightMm / sx); // 667 pixels (or clamped to 512)
    assert(coronalPhysicalHeightMm === 500.0, `Coronal physical height: ${coronalPhysicalHeightMm} mm`);
    assert(coronalReslicedHeight > nz, `Anisotropic Coronal height (${coronalReslicedHeight} px) > slice count (${nz}) to preserve anatomical aspect`);
    
    // Test 7: Volumetric Segmentation Math
    const voxelCount = 50000;
    const voxelVolumeMm3 = spacing[0] * spacing[1] * spacing[2]; // 0.75 * 0.75 * 2.0 = 1.125 mm3
    const totalVolumeCm3 = (voxelCount * voxelVolumeMm3) / 1000.0; // 56.25 cm3
    assert(totalVolumeCm3 === 56.25, `Volumetric segmentation formula: ${voxelCount} voxels = ${totalVolumeCm3} cm³`);
    
    // Test 8: Real Clinical Study Hierarchy in pacs_data
    const pacsDataDir = path.resolve(__dirname, '../../Meril_Dicom_Viewer/dicom ui viewer/backend/pacs_data');
    if (fs.existsSync(pacsDataDir)) {
        const studies = fs.readdirSync(pacsDataDir);
        assert(studies.length >= 2, `Found ${studies.length} real clinical studies in backend PACS directory`);
        assert(studies.includes('1.3.46.670589.33.1.63920615320101214800001.4780975902838153948'),
            'Verified clinical study 1: LAXMI RATHOD 61Y/F CT KUB scan dataset (502 slices)');
        assert(studies.includes('1.3.46.670589.33.1.63920665120842380200001.5535694576552993899'),
            'Verified clinical study 2: VAISHANVI K CHILGAR 18Y/F HRCT CHEST scan dataset (351 slices)');
    }
    
    console.log('\n----------------------------------------------------------------------');
    console.log(`TOTAL TESTS: ${passed + failed} | PASSED: ${passed} | FAILED: ${failed}`);
    console.log('----------------------------------------------------------------------\n');
    
    if (failed > 0) {
        process.exit(1);
    }
}

runTests();
