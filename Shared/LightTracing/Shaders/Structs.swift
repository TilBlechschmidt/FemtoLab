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

    static let size = MemoryLayout<Primitive>.size
}

struct Ray {
    let origin: Float2
    let angle: Float
    let wavelength: Float

    static let size = MemoryLayout<Ray>.size
    static let zero = Ray(origin: (0, 0), angle: 0, wavelength: 0)
}

struct Intersection {
    let location: Float2
    let primitiveIndex: UInt32
    let surfaceNormal: Float

    static let size = MemoryLayout<Intersection>.size
}
