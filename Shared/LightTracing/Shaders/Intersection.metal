//
//  Intersection.metal
//  FemtoPhoto
//
//  Created by Til Blechschmidt on 19.12.20.
//

#include <metal_stdlib>
#include "Structs.metal"
#include "Helpers.metal"

using namespace metal;

#define LARGE_NUMBER 1000000
#define SMALL_NUMBER 0.001

kernel void computeIntersection(
    const device Primitive *primitives [[ buffer(0) ]],
    const device Ray *rays [[ buffer(1) ]],
    device Intersection *intersections [[ buffer(2) ]],
    uint2 gid [[thread_position_in_grid]],
    uint2 grid_dimensions [[threads_per_grid]]
) {
    uint index = thread_id(gid, grid_dimensions);

    Ray ray = rays[index];

    Primitive primitive = primitives[0];
    float2 v1 = ray.origin - primitive.src;
    float2 v2 = primitive.dst - primitive.src;
    float2 v3 = normalize({ -sin(ray.angle), cos(ray.angle) });

    float t1 = cross(float3(v2, 0), float3(v1, 0)).z / dot(v2, v3);
    float t2 = dot(v1, v3) / dot(v2, v3);
    bool do_intersect = t1 >= SMALL_NUMBER && t2 >= 0 && t2 < 1;

    Intersection intersection;

    if (do_intersect) {
        intersection.location = primitive.src + (primitive.dst - primitive.src) * t2;
        intersection.primitive_index = 0;

        float2 primitive_direction = primitive.dst - primitive.src;
        intersection.surface_normal = atan2(primitive_direction.y, primitive_direction.x);
    } else {
        intersection.location = { LARGE_NUMBER * cos(ray.angle), LARGE_NUMBER * sin(ray.angle) };
        intersection.primitive_index = __UINT32_MAX__;
        intersection.surface_normal = NAN;
    }
    intersections[index] = intersection;
}
