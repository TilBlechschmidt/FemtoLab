//
//  MTLComputeCommandEncoder+Parameters.swift
//  FemtoPhoto
//
//  Created by Til Blechschmidt on 20.12.20.
//

import Foundation
import Metal

extension MTLComputeCommandEncoder {
    func setParameters<T>(_ buffers: [MTLBuffer?], _ bytes: [T], offsets: [Int]? = nil) {
        setBuffers(buffers, offsets: offsets)
        setBytes(values: bytes, startingAtIndex: buffers.count)
    }

    func setBuffers(_ buffers: [MTLBuffer?], startingAtIndex startIndex: Int = 0, offsets: [Int]? = nil) {
        setBuffers(buffers, offsets: offsets ?? Array(repeating: 0, count: buffers.count), range: startIndex..<(startIndex + buffers.count))
    }

    func setBytes<T>(values: [T], startingAtIndex startIndex: Int = 0) {
        zip(values, startIndex..<(startIndex + values.count)).forEach {
            var (value, index) = $0
            setBytes(&value, index: index)
        }
    }

    func setBytes<T>(_ value: inout T, index: Int) {
        setBytes(&value, length: MemoryLayout.size(ofValue: value), index: index)
    }
}
