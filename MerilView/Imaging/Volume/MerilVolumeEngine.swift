import Foundation
import simd

/// Contiguous 3D scalar volume state reconstructed from a validated DICOM series.
public final class MerilVolumeState {
    public let seriesUid: String
    public let nx: Int
    public let ny: Int
    public let nz: Int
    public let sx: Double
    public let sy: Double
    public let sz: Double
    public let origin: Vector3D
    public let rowDir: Vector3D
    public let colDir: Vector3D
    public let normalDir: Vector3D
    public let voxels: [Int16]
    public let minHu: Double
    public let maxHu: Double
    public let instances: [DicomInstance]
    
    public init(
        seriesUid: String,
        nx: Int,
        ny: Int,
        nz: Int,
        sx: Double,
        sy: Double,
        sz: Double,
        origin: Vector3D,
        rowDir: Vector3D,
        colDir: Vector3D,
        normalDir: Vector3D,
        voxels: [Int16],
        minHu: Double,
        maxHu: Double,
        instances: [DicomInstance]
    ) {
        self.seriesUid = seriesUid
        self.nx = nx
        self.ny = ny
        self.nz = nz
        self.sx = sx
        self.sy = sy
        self.sz = sz
        self.origin = origin
        self.rowDir = rowDir
        self.colDir = colDir
        self.normalDir = normalDir
        self.voxels = voxels
        self.minHu = minHu
        self.maxHu = maxHu
        self.instances = instances
    }
}

/// Engine for constructing validated 3D scalar volumes from multi-slice DICOM series.
public final class MerilVolumeEngine {
    
    public enum VolumeError: Error, LocalizedError {
        case emptySeries
        case missingSliceFiles
        case memoryAllocationFailed
        
        public var errorDescription: String? {
            switch self {
            case .emptySeries: return "Cannot build 3D volume: series contains no slices."
            case .missingSliceFiles: return "Cannot build 3D volume: one or more slice files are missing on disk."
            case .memoryAllocationFailed: return "Insufficient memory to allocate 3D scalar volume."
            }
        }
    }
    
    private static var activeVolume: MerilVolumeState?
    private static let lock = NSLock()
    
    public static func getActiveVolume() -> MerilVolumeState? {
        lock.lock()
        defer { lock.unlock() }
        return activeVolume
    }
    
    public static func clearVolume() {
        lock.lock()
        activeVolume = nil
        lock.unlock()
    }
    
    /// Reconstructs a 3D scalar volume from a sorted array of DICOM instances.
    public static func buildVolume(
        seriesUid: String,
        instances: [DicomInstance],
        targetResolution: Int = 256,
        onProgress: ((_ current: Int, _ total: Int) -> Void)? = nil
    ) throws -> MerilVolumeState {
        lock.lock()
        if let current = activeVolume, current.seriesUid == seriesUid {
            lock.unlock()
            return current
        }
        lock.unlock()
        
        guard !instances.isEmpty else { throw VolumeError.emptySeries }
        
        let nz = instances.count
        let firstInst = instances[0]
        let origRows = firstInst.rows
        let origCols = firstInst.columns
        let origSx = firstInst.pixelSpacing.first ?? 0.75
        let origSy = firstInst.pixelSpacing.count > 1 ? firstInst.pixelSpacing[1] : 0.75
        
        let res = min(max(64, targetResolution), origCols)
        let nx = res
        let ny = res
        let scaleX = Double(origCols) / Double(nx)
        let scaleY = Double(origRows) / Double(ny)
        let sx = origSx * scaleX
        let sy = origSy * scaleY
        
        // Orientation Direction Cosines
        let iop = firstInst.imageOrientationPatient
        let rowDir = Vector3D(iop.count > 0 ? iop[0] : 1.0,
                              iop.count > 1 ? iop[1] : 0.0,
                              iop.count > 2 ? iop[2] : 0.0)
        let colDir = Vector3D(iop.count > 3 ? iop[3] : 0.0,
                              iop.count > 4 ? iop[4] : 1.0,
                              iop.count > 5 ? iop[5] : 0.0)
        let normalDir = SpatialGeometry.computeNormal(rowDirection: rowDir, colDirection: colDir)
        
        // Origin
        let ipp0 = firstInst.imagePositionPatient
        let origin = Vector3D(ipp0.count > 0 ? ipp0[0] : 0.0,
                              ipp0.count > 1 ? ipp0[1] : 0.0,
                              ipp0.count > 2 ? ipp0[2] : 0.0)
        
        // Compute slice thickness sz along series normal
        var sz = firstInst.sliceThickness
        if nz > 1 {
            let lastInst = instances[nz - 1]
            let ippLast = lastInst.imagePositionPatient
            let pos0 = origin
            let posLast = Vector3D(ippLast.count > 0 ? ippLast[0] : 0.0,
                                   ippLast.count > 1 ? ippLast[1] : 0.0,
                                   ippLast.count > 2 ? ippLast[2] : 0.0)
            let projectedDist = SpatialGeometry.computeProjectedDistance(pos1: pos0, pos2: posLast, normal: normalDir)
            if projectedDist > 0.1 {
                sz = projectedDist / Double(nz - 1)
            }
        }
        
        let totalVoxels = nx * ny * nz
        var voxels = [Int16](repeating: -1024, count: totalVoxels)
        var minVal = Double.infinity
        var maxVal = -Double.infinity
        
        for z in 0..<nz {
            let inst = instances[z]
            let fileUrl = URL(fileURLWithPath: inst.filePath)
            guard let data = try? Data(contentsOf: fileUrl, options: [.mappedIfSafe]),
                  let metadata = try? MerilDicomParser.parse(data: data),
                  let rawPixels = try? MerilDicomDecoder.decodePixels(data: data, metadata: metadata) else {
                continue
            }
            
            let slope = metadata.rescaleSlope
            let intercept = metadata.rescaleIntercept
            let isSigned = metadata.pixelRepresentation == 1
            let zOffset = z * (nx * ny)
            
            for y in 0..<ny {
                let srcY = min(origRows - 1, max(0, Int(Double(y) * scaleY)))
                let srcRowOffset = srcY * origCols
                let destRowOffset = zOffset + y * nx
                
                for x in 0..<nx {
                    let srcX = min(origCols - 1, max(0, Int(Double(x) * scaleX)))
                    let rawVal: Double
                    if isSigned {
                        rawVal = Double(rawPixels[srcRowOffset + srcX])
                    } else {
                        rawVal = Double(UInt16(bitPattern: rawPixels[srcRowOffset + srcX]))
                    }
                    
                    let hu = Int(round(rawVal * slope + intercept))
                    let clampedHu = Int16(min(4096, max(-2048, hu)))
                    voxels[destRowOffset + x] = clampedHu
                    
                    let dHu = Double(clampedHu)
                    if dHu < minVal { minVal = dHu }
                    if dHu > maxVal { maxVal = dHu }
                }
            }
            
            if (z + 1) % 25 == 0 || z == nz - 1 {
                onProgress?(z + 1, nz)
            }
        }
        
        let volume = MerilVolumeState(
            seriesUid: seriesUid,
            nx: nx,
            ny: ny,
            nz: nz,
            sx: sx,
            sy: sy,
            sz: sz,
            origin: origin,
            rowDir: rowDir,
            colDir: colDir,
            normalDir: normalDir,
            voxels: voxels,
            minHu: minVal.isFinite ? minVal : -1024.0,
            maxHu: maxVal.isFinite ? maxVal : 3071.0,
            instances: instances
        )
        
        lock.lock()
        activeVolume = volume
        lock.unlock()
        
        return volume
    }
}
