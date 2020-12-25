//
//  Structs.swift
//  FemtoPhoto
//
//  Created by Til Blechschmidt on 19.12.20.
//

import Foundation

typealias Float2 = (Float, Float)

/// Geometric primitive
/// For now just a basic line between two points
struct Primitive {
    let src: Float2
    let dst: Float2

    static let stride = MemoryLayout<Primitive>.stride
}

struct Ray {
    let origin: Float2
    let angle: Float
    let wavelength: Float

    let rngState: (Float, Float, Float, Float) = (Float.random(in: 0..<1), Float.random(in: 0..<1), Float.random(in: 0..<1), Float.random(in: 0..<1))

    static let stride = MemoryLayout<Ray>.stride
    static let zero = Ray(origin: (0, 0), angle: 0, wavelength: 0)
}

struct Intersection {
    let location: Float2
    let primitiveIndex: UInt16
    let surfaceNormal: Float

    static let stride = MemoryLayout<Intersection>.stride
}
