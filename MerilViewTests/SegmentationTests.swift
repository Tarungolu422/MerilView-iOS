import XCTest
@testable import MerilViewCore

final class SegmentationTests: XCTestCase {
    
    func testLabelmapVolumeCalculations() {
        let mgr = MerilLabelmapManager.shared
        
        let dummyVol = MerilVolumeState(
            seriesUid: "test_series",
            nx: 100,
            ny: 100,
            nz: 10,
            sx: 1.0,
            sy: 1.0,
            sz: 2.0,
            origin: Vector3D(0, 0, 0),
            rowDir: Vector3D(1, 0, 0),
            colDir: Vector3D(0, 1, 0),
            normalDir: Vector3D(0, 0, 1),
            voxels: [Int16](repeating: 50, count: 100 * 100 * 10),
            minHu: 0,
            maxHu: 100,
            instances: []
        )
        
        mgr.initialize(for: dummyVol)
        
        // Paint 1000 voxels with Segment ID 1
        for z in 0..<10 {
            for y in 0..<10 {
                for x in 0..<10 {
                    mgr.setVoxel(x: x, y: y, z: z, value: 1)
                }
            }
        }
        
        // Single voxel physical volume: 1.0 * 1.0 * 2.0 mm3 = 2.0 mm3 = 0.002 cm3
        // 1000 voxels: 2000 mm3 = 2.0 cm3
        let exp = expectation(description: "volume_recalculated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let seg1 = mgr.segments.first(where: { $0.id == 1 })
            XCTAssertNotNil(seg1)
            XCTAssertEqual(seg1?.voxelCount, 1000)
            XCTAssertEqual(seg1?.volumeCm3 ?? 0.0, 2.0, accuracy: 1e-4)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
}
