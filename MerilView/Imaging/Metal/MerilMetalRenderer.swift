import Foundation
import Metal
import MetalKit
import UIKit

/// GPU-accelerated Metal rendering engine for 3D Volume MIP and 2D DICOM viewports.
public final class MerilMetalRenderer: NSObject, MTKViewDelegate {
    
    public let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineStateMIP: MTLRenderPipelineState?
    private var volumeTexture: MTLTexture?
    private var samplerState: MTLSamplerState?
    
    public var azimuth: Float = 0.0
    public var elevation: Float = 0.0
    public var windowCenter: Float = 300.0
    public var windowWidth: Float = 1500.0
    
    public override init() {
        guard let defaultDevice = MTLCreateSystemDefaultDevice(),
              let queue = defaultDevice.makeCommandQueue() else {
            fatalError("Metal is not supported on this device.")
        }
        self.device = defaultDevice
        self.commandQueue = queue
        super.init()
        
        setupPipeline()
        setupSampler()
    }
    
    private func setupPipeline() {
        guard let library = device.makeDefaultLibrary(),
              let vertexFunc = library.makeFunction(name: "vertex_main"),
              let fragmentMIP = library.makeFunction(name: "fragment_volume_mip") else {
            return
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunc
        descriptor.fragmentFunction = fragmentMIP
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        pipelineStateMIP = try? device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    private func setupSampler() {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = .linear
        descriptor.magFilter = .linear
        descriptor.mipFilter = .linear
        descriptor.sAddressMode = .clampToEdge
        descriptor.tAddressMode = .clampToEdge
        descriptor.rAddressMode = .clampToEdge
        samplerState = device.makeSamplerState(descriptor: descriptor)
    }
    
    /// Uploads a contiguous 3D scalar volume to a 3D Metal texture.
    public func uploadVolume(_ volume: MerilVolumeState) {
        let desc = MTLTextureDescriptor()
        desc.textureType = .type3D
        desc.pixelFormat = .r16Float
        desc.width = volume.nx
        desc.height = volume.ny
        desc.depth = volume.nz
        desc.usage = [.shaderRead]
        
        guard let texture = device.makeTexture(descriptor: desc) else { return }
        
        // Convert Int16 HU to normalized Float16
        let total = volume.nx * volume.ny * volume.nz
        var floatPixels = [Float32](repeating: 0, count: total)
        for i in 0..<total {
            floatPixels[i] = Float32(volume.voxels[i])
        }
        
        floatPixels.withUnsafeBytes { rawBuf in
            let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                   size: MTLSize(width: volume.nx, height: volume.ny, depth: volume.nz))
            texture.replace(region: region, mipmapLevel: 0, slice: 0,
                            withBytes: rawBuf.baseAddress!,
                            bytesPerRow: volume.nx * MemoryLayout<Float32>.size,
                            bytesPerImage: volume.nx * volume.ny * MemoryLayout<Float32>.size)
        }
        
        self.volumeTexture = texture
    }
    
    // MARK: - MTKViewDelegate
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDesc = view.currentRenderPassDescriptor,
              let pipeline = pipelineStateMIP,
              let texture = volumeTexture,
              let sampler = samplerState,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDesc) else {
            return
        }
        
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentSamplerState(sampler, index: 0)
        
        var az = azimuth
        var el = elevation
        var wc = windowCenter
        var ww = windowWidth
        encoder.setFragmentBytes(&az, length: MemoryLayout<Float>.size, index: 0)
        encoder.setFragmentBytes(&el, length: MemoryLayout<Float>.size, index: 1)
        encoder.setFragmentBytes(&wc, length: MemoryLayout<Float>.size, index: 2)
        encoder.setFragmentBytes(&ww, length: MemoryLayout<Float>.size, index: 3)
        
        // Draw fullscreen quad
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
