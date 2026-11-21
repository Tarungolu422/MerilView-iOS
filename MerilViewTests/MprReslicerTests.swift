import XCTest
@testable import MerilViewCore

final class MprReslicerTests: XCTestCase {
    
    func testSpatialCoordinateCalculations() {
        let origin = Vector3D(-150.0, -150.0, 100.0)
        let rowDir = Vector3D(1.0, 0.0, 0.0)
        let colDir = Vector3D(0.0, 1.0, 0.0)
        let normalDir = SpatialGeometry.computeNormal(rowDirection: rowDir, colDirection: colDir)
        let spacing = Vector3D(0.75, 0.75, 2.0)
        
        XCTAssertEqual(normalDir.x, 0.0, accuracy: 1e-4)
        XCTAssertEqual(normalDir.y, 0.0, accuracy: 1e-4)
        XCTAssertEqual(normalDir.z, 1.0, accuracy: 1e-4)
        
        // Voxel (0, 0, 0) -> Origin
        let pt0 = SpatialGeometry.voxelToPatient(
            voxel: Vector3D(0, 0, 0),
            origin: origin,
            rowDir: rowDir,
            colDir: colDir,
            normalDir: normalDir,
            spacing: spacing
        )
        XCTAssertEqual(pt0.x, -150.0, accuracy: 1e-4)
        XCTAssertEqual(pt0.y, -150.0, accuracy: 1e-4)
        XCTAssertEqual(pt0.z, 100.0, accuracy: 1e-4)
        
        // Voxel (100, 200, 10)
        let pt1 = SpatialGeometry.voxelToPatient(
            voxel: Vector3D(100, 200, 10),
            origin: origin,
            rowDir: rowDir,
            colDir: colDir,
            normalDir: normalDir,
            spacing: spacing
        )
        XCTAssertEqual(pt1.x, -150.0 + 100.0 * 0.75, accuracy: 1e-4)
        XCTAssertEqual(pt1.y, -150.0 + 200.0 * 0.75, accuracy: 1e-4)
        XCTAssertEqual(pt1.z, 100.0 + 10.0 * 2.0, accuracy: 1e-4)
        
        // Inverse Mapping (Patient back to Voxel)
        let voxReconstructed = SpatialGeometry.patientToVoxel(
            patientPoint: pt1,
            origin: origin,
            rowDir: rowDir,
            colDir: colDir,
            normalDir: normalDir,
            spacing: spacing
        )
        XCTAssertEqual(voxReconstructed.x, 100.0, accuracy: 1e-3)
        XCTAssertEqual(voxReconstructed.y, 200.0, accuracy: 1e-3)
        XCTAssertEqual(voxReconstructed.z, 10.0, accuracy: 1e-3)
    }
    
    func testAnatomicalLabels() {
        XCTAssertEqual(SpatialGeometry.getAnatomicalLabel(vector: Vector3D(1, 0, 0)), "L")
        XCTAssertEqual(SpatialGeometry.getAnatomicalLabel(vector: Vector3D(-1, 0, 0)), "R")
        XCTAssertEqual(SpatialGeometry.getAnatomicalLabel(vector: Vector3D(0, 1, 0)), "P")
        XCTAssertEqual(SpatialGeometry.getAnatomicalLabel(vector: Vector3D(0, -1, 0)), "A")
        XCTAssertEqual(SpatialGeometry.getAnatomicalLabel(vector: Vector3D(0, 0, 1)), "S")
        XCTAssertEqual(SpatialGeometry.getAnatomicalLabel(vector: Vector3D(0, 0, -1)), "I")
    }
}
