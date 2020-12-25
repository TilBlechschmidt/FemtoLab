//
//  RayShaders.metal
//  FemtoPhoto
//
//  Created by Til Blechschmidt on 19.12.20.
//

#include <metal_stdlib>
#include "Structs.metal"
#include "Helpers.metal"

using namespace metal;

// Vertex shader outputs and fragment shader inputs
struct RasterizerData {
    float4 position [[position]];
    float4 color;
};

vertex RasterizerData vertexFunction(
    uint vertexID [[vertex_id]],
    const device Ray *rays [[ buffer(0) ]],
    const device Intersection *intersections [[ buffer(1) ]]
) {
    RasterizerData out;

    Ray ray = rays[vertexID / 2];
    float2 raySource = ray.origin;
    float2 rayDestination = intersections[vertexID / 2].location;
    float2 rayDirection = rayDestination - raySource;
    float biasCorrection = clamp(length(rayDirection)/max(abs(rayDirection.x), abs(rayDirection.y)), 1.0, 1.414214);

    // Index into the array of positions to get the current vertex.
    // The positions are specified in pixel dimensions (i.e. a value of 100
    // is 100 pixels from the origin).
    float2 pixelSpacePosition = vertexID % 2 == 0 ? raySource : rayDestination;

    // Get the viewport size and cast to float.
    float2 viewportSize = { 2048, 2048 };

    // To convert from positions in pixel space to positions in clip-space,
    //  divide the pixel coordinates by half the size of the viewport.
    out.position = vector_float4(0.0, 0.0, 0.0, 1.0);
    out.position.xy = pixelSpacePosition / (viewportSize / 2.0);

    // Pass the input color directly to the rasterizer.
    float3 color = wavelengthToRGB(ray.wavelength);
    out.color = float4(color * 0.0002 * biasCorrection, 1);

    return out;
}

fragment float4 fragmentFunction(RasterizerData in [[stage_in]]) {
    return in.color;
}
