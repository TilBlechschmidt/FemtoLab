//
//  LightTracer.swift
//  FemtoPhoto
//
//  Created by Til Blechschmidt on 19.12.20.
//

import Foundation
import Metal

fileprivate func generateRays(origin: Float2, count: Int, initialAngle: Double = 0.0, range: Double = 2 * Double.pi) -> [Ray] {
    let deltaAngle = range / Double(count)

    return (0...count).map { i in
        let angle = Double(i) * deltaAngle + initialAngle
        let wavelength = Float.random(in: 350...750)

        return Ray(origin: origin, angle: Float(angle), wavelength: wavelength)
    }
}

class LightTracer {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue

    let intersectionPipelineState: MTLComputePipelineState
    let brdfPipelineState: MTLComputePipelineState

    let primitiveBuffer: MTLBuffer
    let rayBuffer: MTLBuffer
    let intersectionBuffer: MTLBuffer

    let renderPipelineState: MTLRenderPipelineState
    let texture: MTLTexture

    let multiplier = 32
    let bounceLimit = 2

    init?(device: MTLDevice? = MTLCreateSystemDefaultDevice()) throws {
        guard let device = device,
              let library = device.makeDefaultLibrary(),
              let computeIntersection = library.makeFunction(name: "computeIntersection"),
              let computeBRDF = library.makeFunction(name: "computeBRDF"),
              let vertexShader = library.makeFunction(name: "vertexFunction"),
              let fragmentShader = library.makeFunction(name: "fragmentFunction"),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue

        intersectionPipelineState = try device.makeComputePipelineState(function: computeIntersection)
        brdfPipelineState = try device.makeComputePipelineState(function: computeBRDF)

        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = MTLTextureType.type2D
        textureDescriptor.width = 2048
        textureDescriptor.height = 2048
        textureDescriptor.pixelFormat = .rgba32Float
        textureDescriptor.storageMode = .private
        textureDescriptor.usage = [.renderTarget, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else { return nil }
        self.texture = texture

        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = vertexShader
        renderPipelineDescriptor.fragmentFunction = fragmentShader
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = textureDescriptor.pixelFormat
        renderPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)

        let primitiveCount = 1
        let emittedRayCount = multiplier * multiplier * multiplier * multiplier
        let rayCount = emittedRayCount * bounceLimit

        let primitivesData = [
            Primitive(src: (1024, 512), dst: (512, -512))
        ]

        let rayData = generateRays(origin: (0, 0), count: emittedRayCount, initialAngle: -Double.pi / 4, range: Double.pi / 2) + Array(repeating: Ray.zero, count: emittedRayCount * (bounceLimit - 1))

        guard let primitiveBuffer = device.makeBuffer(bytes: primitivesData, length: Primitive.size * primitiveCount, options: [.storageModeShared]),
              let rayBuffer = device.makeBuffer(bytes: rayData, length: Ray.size * rayCount, options: [.storageModeShared]),
              let intersectionBuffer = device.makeBuffer(length: Intersection.size * rayCount, options: [.storageModePrivate]) else {
            return nil
        }

        self.primitiveBuffer = primitiveBuffer
        self.rayBuffer = rayBuffer
        self.intersectionBuffer = intersectionBuffer

        print(device.maxThreadsPerThreadgroup)
        print(intersectionPipelineState.threadExecutionWidth)
        print(intersectionPipelineState.maxTotalThreadsPerThreadgroup)
        print("Rendering \(rayCount) rays")

        let supportedFamilies: [MTLGPUFamily] = [.apple5, .mac1, .macCatalyst1]
        let gpuSupported = supportedFamilies.reduce(false) { $0 || device.supportsFamily($1) }
        if !gpuSupported { fatalError("GPU Family not supported — missing feature: non-uniform threadgroups") }
    }

    func run() {
        let captureManager = MTLCaptureManager.shared()
        let captureDescriptor = MTLCaptureDescriptor()
        captureDescriptor.captureObject = device
        try! captureManager.startCapture(with: captureDescriptor)

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        calculateIntersections(commandBuffer, bufferOffset: 0)
        calculateBRDF(commandBuffer)
        calculateIntersections(commandBuffer, bufferOffset: Ray.size * multiplier * multiplier * multiplier * multiplier)
        renderRays(commandBuffer)

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        print("Intersection done! \(commandBuffer.gpuEndTime - commandBuffer.gpuStartTime)")

        captureManager.stopCapture()
    }

    func calculateIntersections(_ commandBuffer: MTLCommandBuffer, bufferOffset: Int) {
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }

        commandEncoder.label = "Calculate intersections"

        commandEncoder.setComputePipelineState(intersectionPipelineState)
        commandEncoder.setBuffers([primitiveBuffer, rayBuffer, intersectionBuffer], offsets: [0, bufferOffset, bufferOffset])
        commandEncoder.dispatch(sideLength: multiplier * multiplier, computePipelineState: intersectionPipelineState)
        commandEncoder.endEncoding()
    }

    func calculateBRDF(_ commandBuffer: MTLCommandBuffer) {
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }

        commandEncoder.label = "Calculate BRDF"

        commandEncoder.setComputePipelineState(brdfPipelineState)
        commandEncoder.setBuffers([rayBuffer, intersectionBuffer])
        commandEncoder.dispatch(sideLength: multiplier * multiplier, computePipelineState: brdfPipelineState)
        commandEncoder.endEncoding()
    }

    func renderRays(_ commandBuffer: MTLCommandBuffer) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

        commandEncoder.label = "Render rays"

        commandEncoder.setRenderPipelineState(renderPipelineState)
        commandEncoder.setVertexBuffer(rayBuffer, offset: 0, index: 0)
        commandEncoder.setVertexBuffer(intersectionBuffer, offset: 0, index: 1)
        commandEncoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: multiplier * multiplier * multiplier * multiplier * bounceLimit * 2)

        commandEncoder.endEncoding()
    }
}
