import Foundation
import simd

/// Standard 3D vector representing coordinates or directions in Patient LPS space (mm).
public typealias Vector3D = SIMD3<Double>

/// Mathematical utilities and spatial coordinate transformations for DICOM imaging.
public struct SpatialGeometry {
    
    /// Computes normal vector N = R x C from row and column direction cosines.
    public static func computeNormal(rowDirection: Vector3D, colDirection: Vector3D) -> Vector3D {
        let normal = simd_cross(rowDirection, colDirection)
        let len = simd_length(normal)
        return len > 1e-5 ? (normal / len) : Vector3D(0, 0, 1)
    }
    
    /// Transforms voxel grid indices (x, y, z) into Patient LPS coordinates (mm).
    public static func voxelToPatient(
        voxel: Vector3D,
        origin: Vector3D,
        rowDir: Vector3D,
        colDir: Vector3D,
        normalDir: Vector3D,
        spacing: Vector3D
    ) -> Vector3D {
        let px = voxel.x * spacing.x
        let py = voxel.y * spacing.y
        let pz = voxel.z * spacing.z
        
        return origin + (px * rowDir) + (py * colDir) + (pz * normalDir)
    }
    
    /// Transforms Patient LPS coordinates (mm) into fractional voxel indices (x, y, z).
    public static func patientToVoxel(
        patientPoint: Vector3D,
        origin: Vector3D,
        rowDir: Vector3D,
        colDir: Vector3D,
        normalDir: Vector3D,
        spacing: Vector3D
    ) -> Vector3D {
        let delta = patientPoint - origin
        let px = simd_dot(delta, rowDir)
        let py = simd_dot(delta, colDir)
        let pz = simd_dot(delta, normalDir)
        
        return Vector3D(
            px / max(1e-5, spacing.x),
            py / max(1e-5, spacing.y),
            pz / max(1e-5, spacing.z)
        )
    }
    
    /// Computes anatomical direction label (L, R, A, P, S, I or composite e.g. "L P") from vector.
    public static func getAnatomicalLabel(vector: Vector3D) -> String {
        let absX = abs(vector.x)
        let absY = abs(vector.y)
        let absZ = abs(vector.z)
        
        let xLabel = vector.x >= 0 ? "L" : "R"
        let yLabel = vector.y >= 0 ? "P" : "A"
        let zLabel = vector.z >= 0 ? "S" : "I"
        
        let components = [
            (label: xLabel, value: absX),
            (label: yLabel, value: absY),
            (label: zLabel, value: absZ)
        ].sorted { $0.value > $1.value }
        
        var result = components[0].label
        if components[1].value > 0.35 && components[1].value > (components[0].value * 0.4) {
            result += " " + components[1].label
        }
        return result
    }
    
    /// Projects a 3D distance between two slice positions onto the series normal vector.
    public static func computeProjectedDistance(pos1: Vector3D, pos2: Vector3D, normal: Vector3D) -> Double {
        let delta = pos2 - pos1
        let projected = abs(simd_dot(delta, normal))
        if projected > 0.05 {
            return projected
        }
        return simd_length(delta)
    }
}
