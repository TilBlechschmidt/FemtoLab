//
//  LightRenderer.swift
//  FemtoPhoto
//
//  Created by Til Blechschmidt on 20.12.20.
//

import Foundation
import Metal

typealias Size = (width: Int, height: Int)

struct RendererConfiguration {
    let resolution: Size = (2048, 2048)
}

struct RayData {
    let config: TracerConfiguration
    let rayBuffer: MTLBuffer
    let intersectionBuffer: MTLBuffer
}

class LightRenderer {
    public enum Error: Swift.Error {
        case libraryUnavailable
        case textureInitializationFailed
    }

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue

    private let renderPipelineState: MTLRenderPipelineState
    private let texture: MTLTexture

    init(commandQueue: MTLCommandQueue, config: RendererConfiguration = RendererConfiguration()) throws {
        device = commandQueue.device
        self.commandQueue = commandQueue

        guard let library = device.makeDefaultLibrary(),
              let vertexShader = library.makeFunction(name: "vertexFunction"),
              let fragmentShader = library.makeFunction(name: "fragmentFunction") else {
            throw Error.libraryUnavailable
        }

        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = MTLTextureType.type2D
        textureDescriptor.width = config.resolution.width
        textureDescriptor.height = config.resolution.height
        textureDescriptor.pixelFormat = .rgba32Float
        textureDescriptor.storageMode = .private
        textureDescriptor.usage = [.renderTarget, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            throw Error.textureInitializationFailed
        }
        self.texture = texture

        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = vertexShader
        renderPipelineDescriptor.fragmentFunction = fragmentShader
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = textureDescriptor.pixelFormat
        renderPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
    }

    func run(data: RayData) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        commandBuffer.label = "Light renderer"

        renderRays(commandBuffer, data: data)

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    func renderRays(_ commandBuffer: MTLCommandBuffer, data: RayData) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

        commandEncoder.label = "Render rays"

        commandEncoder.setRenderPipelineState(renderPipelineState)
        commandEncoder.setVertexBuffer(data.rayBuffer, offset: 0, index: 0)
        commandEncoder.setVertexBuffer(data.intersectionBuffer, offset: 0, index: 1)
        commandEncoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: data.config.rayCount * 2)

        commandEncoder.endEncoding()
    }
}
