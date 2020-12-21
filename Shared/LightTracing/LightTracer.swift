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

struct TracerConfiguration {
    let batchSize: Int
    let batchCount: Int
    let lightPathLength: Int

    var raysPerBounce: Int {
        batchSize * batchCount
    }

    var rayCount: Int {
        raysPerBounce * lightPathLength
    }

    var batchSideLength: Int {
        Int(Double(batchSize).squareRoot())
    }

    init(batchSize: Int = 1024 * 1024, batchCount: Int = 1, lightPathLength: Int = 2) {
        let batchSqrt = Double(batchSize).squareRoot()
        guard batchSqrt.rounded() == batchSqrt else { fatalError("Batch size is not a squared number!") }

        self.batchSize = batchSize
        self.batchCount = batchCount
        self.lightPathLength = lightPathLength
    }
}

class LightTracer {
    public enum Error: Swift.Error {
        case deviceInitializationFailed
        case libraryUnavailable
        case bufferAllocationFailed
        case deviceFamilyUnsupported
        case commandBufferCreationFailed
    }

    static let supportedGPUFamilies: [MTLGPUFamily] = [.apple5, .mac1, .macCatalyst1]

    public let config: TracerConfiguration
    public var rayData: RayData {
        RayData(config: config, rayBuffer: rayBuffer, intersectionBuffer: intersectionBuffer)
    }

    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue

    private let intersectionPipelineState: MTLComputePipelineState
    private let brdfPipelineState: MTLComputePipelineState

    private let primitiveBuffer: MTLBuffer
    private let rayBuffer: MTLBuffer
    private let intersectionBuffer: MTLBuffer

    convenience init(config: TracerConfiguration = TracerConfiguration()) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let commandQueue = device.makeCommandQueue() else {
            throw Error.deviceInitializationFailed
        }

        try self.init(commandQueue: commandQueue, config: config)
    }

    init(commandQueue: MTLCommandQueue, config: TracerConfiguration) throws {
        device = commandQueue.device
        self.commandQueue = commandQueue
        self.config = config

        guard let library = device.makeDefaultLibrary(),
              let computeIntersection = library.makeFunction(name: "computeIntersection"),
              let computeBRDF = library.makeFunction(name: "computeBRDF") else {
            throw Error.libraryUnavailable
        }

        intersectionPipelineState = try device.makeComputePipelineState(function: computeIntersection)
        brdfPipelineState = try device.makeComputePipelineState(function: computeBRDF)

        let primitiveCount = 1

        let primitivesData = [
            Primitive(src: (512, 512), dst: (-512, 256)),
//            Primitive(src: (512, 512), dst: (512, -512)), // right, top bottom
//            Primitive(src: (512, -512), dst: (512, 512)), // right, bottom top
//            Primitive(src: (0, 512), dst: (512, -512)), // right, left diagonal
//            Primitive(src: (512, -512), dst: (0, 512)), // right, left diagonal
        ]

        let firstRayBatch = generateRays(origin: (0, 0), count: config.raysPerBounce, initialAngle: -Double.pi / 4 + Double.pi / 2, range: Double.pi / 4)
        let emptyRayBatches = Array(repeating: Ray.zero, count: config.raysPerBounce * (config.lightPathLength - 1))
        let rayData = firstRayBatch + emptyRayBatches

        guard let primitiveBuffer = device.makeBuffer(bytes: primitivesData, length: Primitive.size * primitiveCount, options: [.storageModeShared]),
              let rayBuffer = device.makeBuffer(bytes: rayData, length: Ray.size * config.rayCount, options: [.storageModeShared]),
              let intersectionBuffer = device.makeBuffer(length: Intersection.size * config.rayCount, options: [.storageModePrivate]) else {
            throw Error.bufferAllocationFailed
        }

        self.primitiveBuffer = primitiveBuffer
        self.rayBuffer = rayBuffer
        self.intersectionBuffer = intersectionBuffer

        let gpuSupported = LightTracer.supportedGPUFamilies.reduce(false) { $0 || device.supportsFamily($1) }
        if !gpuSupported {
            throw Error.deviceFamilyUnsupported
        }
    }

    func run() throws {
        var commandBuffer: MTLCommandBuffer?

        for i in 0..<config.batchCount {
            commandBuffer = try enqueue(batch: i)
        }

        commandBuffer?.waitUntilCompleted()
    }

    func enqueue(batch batchID: Int) throws -> MTLCommandBuffer {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw Error.commandBufferCreationFailed
        }

        commandBuffer.label = "Light tracing batch #\(batchID)"

        for bounceID in 0..<config.lightPathLength {
            calculateIntersections(commandBuffer, batchID, bounceID)
            calculateBRDF(commandBuffer, batchID, bounceID)
        }

        commandBuffer.commit()
        return commandBuffer
    }

    func calculateIntersections(_ commandBuffer: MTLCommandBuffer, _ batchID: Int, _ bounceID: Int) {
        let indexOffset = (config.batchSize * batchID + config.raysPerBounce * bounceID)

        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }

        commandEncoder.label = "Intersections bounce #\(bounceID)"

        commandEncoder.setComputePipelineState(intersectionPipelineState)
        commandEncoder.setBuffers([primitiveBuffer, rayBuffer, intersectionBuffer], offsets: [0, indexOffset * Ray.size, indexOffset * Intersection.size])
        commandEncoder.dispatch(sideLength: config.batchSideLength, computePipelineState: intersectionPipelineState)
        commandEncoder.endEncoding()
    }

    func calculateBRDF(_ commandBuffer: MTLCommandBuffer, _ batchID: Int, _ bounceID: Int) {
        let sourceIndexOffset = (config.batchSize * batchID + config.raysPerBounce * bounceID)
        let destinationIndexOffset = (config.batchSize * batchID + config.raysPerBounce * (bounceID + 1))

        // Skip BRDF calculation for the last bounce. It is not needed because the rays won't be reflected anymore.
        guard bounceID < config.lightPathLength - 1, let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }

        commandEncoder.label = "BRDF bounce #\(bounceID)"

        commandEncoder.setComputePipelineState(brdfPipelineState)
        commandEncoder.setBuffers([rayBuffer, rayBuffer, intersectionBuffer], offsets: [sourceIndexOffset * Ray.size, destinationIndexOffset * Ray.size, sourceIndexOffset * Intersection.size])
        commandEncoder.dispatch(sideLength: config.batchSideLength, computePipelineState: brdfPipelineState)
        commandEncoder.endEncoding()
    }
}
