//
//  Shaders.metal
//  FemtoPhoto
//
//  Created by Til Blechschmidt on 18.12.20.
//

#include <metal_stdlib>
#include "LightTracing/Shaders/Helpers.metal"
using namespace metal;

// Vertex shader outputs and fragment shader inputs
struct RasterizerData {
    // The [[position]] attribute of this member indicates that this value
    // is the clip space position of the vertex when this structure is
    // returned from the vertex function.
    float4 position [[position]];

    // Since this member does not have a special attribute, the rasterizer
    // interpolates its value with the values of the other triangle vertices
    // and then passes the interpolated value to the fragment shader for each
    // fragment in the triangle.
    float4 color;
};

vertex RasterizerData vertexShader(uint vertexID [[vertex_id]], constant packed_float3 *vertices [[ buffer(0) ]], constant packed_float2 *viewportSizePointer [[buffer(1)]]) {
    RasterizerData out;

    // Index into the array of positions to get the current vertex.
    // The positions are specified in pixel dimensions (i.e. a value of 100
    // is 100 pixels from the origin).
    float2 pixelSpacePosition = vertices[vertexID].xy;

    // Get the viewport size and cast to float.
    float2 viewportSize = *viewportSizePointer;

    // To convert from positions in pixel space to positions in clip-space,
    //  divide the pixel coordinates by half the size of the viewport.
    out.position = vector_float4(0.0, 0.0, 0.0, 1.0);
    out.position.xy = pixelSpacePosition / (viewportSize / 2.0);

    // Pass the input color directly to the rasterizer.
    uint32_t seed1 = vertexID;
    uint32_t seed2 = vertexID;
    float correctionBias = vertices[vertexID].z;
    float red = float(rand(seed1, seed2)) / float(__UINT32_MAX__);
    float green = float(rand(seed1, seed2)) / float(__UINT32_MAX__);
    float blue = float(rand(seed1, seed2)) / float(__UINT32_MAX__);
    out.color = { red, green, blue, 0.1 * correctionBias };

    return out;
}

fragment float4 fragmentShader(RasterizerData in [[stage_in]]) {
    return in.color;
}
