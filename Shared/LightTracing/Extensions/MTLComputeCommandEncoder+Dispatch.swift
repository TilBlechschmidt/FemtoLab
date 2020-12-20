//
//  MTLComputePipelineState+Dispatch.swift
//  FemtoPhoto (iOS)
//
//  Created by Til Blechschmidt on 20.12.20.
//

import Foundation
import Metal

extension MTLComputeCommandEncoder {
    func dispatch(sideLength: Int, computePipelineState: MTLComputePipelineState) {
        let w = computePipelineState.threadExecutionWidth
        let h = computePipelineState.maxTotalThreadsPerThreadgroup / w
        let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
        let threadsPerGrid = MTLSizeMake(sideLength, sideLength, 1)

        dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
    }
}
