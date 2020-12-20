//
//  RendererView.swift
//  FemtoPhoto
//
//  Created by Til Blechschmidt on 18.12.20.
//

import Foundation
import MetalKit
import Metal

class RendererView: MTKView {
    let vertexCount: Int
    let vertexBuffer: MTLBuffer!

    var renderPipelineState: MTLRenderPipelineState!
    var commandQueue: MTLCommandQueue!
    var viewportSize: CGSize = .zero

    init() {
        let device = MTLCreateSystemDefaultDevice()!
        let library = device.makeDefaultLibrary()!

        let vertexFunction = library.makeFunction(name: "vertexShader")
        let fragmentFunction = library.makeFunction(name: "fragmentShader")

        let lineCount = 120_000
        let vertices = RendererView.generateVertices(count: lineCount)
        vertexCount = lineCount * 2
        vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<(Float, Float, Float)>.size * vertices.count, options: [])
        
        super.init(frame: .zero, device: device)

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        renderPipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        commandQueue = device.makeCommandQueue()

        delegate = self
        clearColor = .init(red: 0, green: 0, blue: 0, alpha: 0)
        preferredFramesPerSecond = 1
//        enableSetNeedsDisplay = true
//        needsDisplay = true
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func generateVertices(count: Int) -> [(Float, Float, Float)] {
        let deltaAngle = 2 * Double.pi / Double(count)

        return (0...count).flatMap { (i: Int) -> [(Float, Float, Float)] in
            let angle = Double(i) * deltaAngle
            let length = 1000.0

            let x: Float = Float(length * cos(angle))
            let y: Float = Float(length * sin(angle))

            let bias = sqrt(pow(x, 2) + pow(y, 2)) / max(abs(x), abs(y))
            return [(0.0, 0.0, bias), (x, y, bias)]
        }
    }
}

extension RendererView: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize = size
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable, let commandBuffer = commandQueue.makeCommandBuffer(), let renderPassDescriptor = view.currentRenderPassDescriptor else { return }

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

        renderEncoder.setRenderPipelineState(renderPipelineState)

        let viewport = MTLViewport(originX: 0.0, originY: 0.0, width: Double(viewportSize.width), height: Double(viewportSize.height), znear: 0.0, zfar: 1.0)
        renderEncoder.setViewport(viewport)

        var viewportBytes: (Float, Float) = (Float(viewportSize.width), Float(viewportSize.height))
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes(&viewportBytes, length: MemoryLayout<(Float, Float, Float)>.size, index: 1)

        (0..<vertexCount / 1000).forEach {
            renderEncoder.drawPrimitives(type: .line, vertexStart: $0 * 1000, vertexCount: 1000)
        }
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
