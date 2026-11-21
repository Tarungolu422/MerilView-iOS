import Foundation
import simd

/// Generates 3D surface mesh vertices and normals from the active volumetric labelmap.
public final class SurfaceMeshGenerator {
    
    public struct MeshVertex {
        public let position: SIMD3<Float>
        public let normal: SIMD3<Float>
    }
    
    /// Extracts 3D surface quad faces for visible voxels of target segment.
    public static func generateSurfaceMesh(
        labelmap: MerilLabelmapManager,
        segmentId: UInt8,
        step: Int = 2
    ) -> [MeshVertex] {
        let w = labelmap.width
        let h = labelmap.height
        let d = labelmap.depth
        guard w > 0, h > 0, d > 0 else { return [] }
        
        let sx = Float(labelmap.spacing.x)
        let sy = Float(labelmap.spacing.y)
        let sz = Float(labelmap.spacing.z)
        
        var vertices: [MeshVertex] = []
        vertices.reserveCapacity(5000)
        
        // Face normals
        let nxPos = SIMD3<Float>(1, 0, 0)
        let nxNeg = SIMD3<Float>(-1, 0, 0)
        let nyPos = SIMD3<Float>(0, 1, 0)
        let nyNeg = SIMD3<Float>(0, -1, 0)
        let nzPos = SIMD3<Float>(0, 0, 1)
        let nzNeg = SIMD3<Float>(0, 0, -1)
        
        for z in stride(from: 0, to: d, by: step) {
            for y in stride(from: 0, to: h, by: step) {
                for x in stride(from: 0, to: w, by: step) {
                    let v = labelmap.getVoxel(x: x, y: y, z: z)
                    guard v == segmentId else { continue }
                    
                    let px = Float(x) * sx
                    let py = Float(y) * sy
                    let pz = Float(z) * sz
                    
                    // Check 6 adjacent neighbours to identify boundary faces
                    // +X Face
                    if x + step >= w || labelmap.getVoxel(x: x + step, y: y, z: z) != segmentId {
                        appendQuad(p: SIMD3<Float>(px + sx, py, pz),
                                   u: SIMD3<Float>(0, sy, 0),
                                   v: SIMD3<Float>(0, 0, sz),
                                   n: nxPos, into: &vertices)
                    }
                    // -X Face
                    if x - step < 0 || labelmap.getVoxel(x: x - step, y: y, z: z) != segmentId {
                        appendQuad(p: SIMD3<Float>(px, py, pz),
                                   u: SIMD3<Float>(0, 0, sz),
                                   v: SIMD3<Float>(0, sy, 0),
                                   n: nxNeg, into: &vertices)
                    }
                    // +Y Face
                    if y + step >= h || labelmap.getVoxel(x: x, y + step, z: z) != segmentId {
                        appendQuad(p: SIMD3<Float>(px, py + sy, pz),
                                   u: SIMD3<Float>(0, 0, sz),
                                   v: SIMD3<Float>(sx, 0, 0),
                                   n: nyPos, into: &vertices)
                    }
                    // -Y Face
                    if y - step < 0 || labelmap.getVoxel(x: x, y - step, z: z) != segmentId {
                        appendQuad(p: SIMD3<Float>(px, py, pz),
                                   u: SIMD3<Float>(sx, 0, 0),
                                   v: SIMD3<Float>(0, 0, sz),
                                   n: nyNeg, into: &vertices)
                    }
                    // +Z Face
                    if z + step >= d || labelmap.getVoxel(x: x, y, z: z + step) != segmentId {
                        appendQuad(p: SIMD3<Float>(px, py, pz + sz),
                                   u: SIMD3<Float>(sx, 0, 0),
                                   v: SIMD3<Float>(0, sy, 0),
                                   n: nzPos, into: &vertices)
                    }
                    // -Z Face
                    if z - step < 0 || labelmap.getVoxel(x: x, y, z: z - step) != segmentId {
                        appendQuad(p: SIMD3<Float>(px, py, pz),
                                   u: SIMD3<Float>(0, sy, 0),
                                   v: SIMD3<Float>(sx, 0, 0),
                                   n: nzNeg, into: &vertices)
                    }
                }
            }
        }
        
        return vertices
    }
    
    private static func appendQuad(
        p: SIMD3<Float>,
        u: SIMD3<Float>,
        v: SIMD3<Float>,
        n: SIMD3<Float>,
        into: inout [MeshVertex]
    ) {
        let p0 = p
        let p1 = p + u
        let p2 = p + u + v
        let p3 = p + v
        
        // Triangle 1: p0, p1, p2
        into.append(MeshVertex(position: p0, normal: n))
        into.append(MeshVertex(position: p1, normal: n))
        into.append(MeshVertex(position: p2, normal: n))
        
        // Triangle 2: p0, p2, p3
        into.append(MeshVertex(position: p0, normal: n))
        into.append(MeshVertex(position: p2, normal: n))
        into.append(MeshVertex(position: p3, normal: n))
    }
}
