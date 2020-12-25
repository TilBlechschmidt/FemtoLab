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

struct IntersectionResult {
    bool did_intersect;
    float dist;
    float2 location;
    float normal;
    uint16_t primitive_index;
};

IntersectionResult lineIntersection(const device Primitive &primitive, const device Ray &ray) {
    float2 v1 = ray.origin - primitive.src;
    float2 v2 = primitive.dst - primitive.src;
    float2 v3 = normalize({ -sin(ray.angle), cos(ray.angle) });

    float t1 = cross(float3(v2, 0), float3(v1, 0)).z / dot(v2, v3);
    float t2 = dot(v1, v3) / dot(v2, v3);

    if (t1 >= SMALL_NUMBER && t2 >= 0 && t2 < 1) {
        float2 location = primitive.src + v2 * t2;
        float normal = atan2(v2.y, v2.x) + M_PI_2_F;

        return { true, t1, location, normal, 0 };
    } else {
        return { false, NAN, float2(NAN, NAN), NAN, 0 };
    }
}

kernel void computeIntersection(
    const device uint16_t *primitive_count [[ buffer(0) ]],
    const device Primitive *primitives [[ buffer(1) ]],
    const device Ray *rays [[ buffer(2) ]],
    device Intersection *intersections [[ buffer(3) ]],
    uint2 gid [[thread_position_in_grid]],
    uint2 grid_dimensions [[threads_per_grid]]
) {
    uint index = thread_id(gid, grid_dimensions);

    const device Ray &ray = rays[index];

    IntersectionResult closest_intersection = { false, NAN, float2(NAN, NAN), NAN, __UINT16_MAX__ };
    for (uint16_t i = 0; i < *primitive_count; i++) {
        IntersectionResult result = lineIntersection(primitives[i], ray);
        result.primitive_index = i;

        if (result.did_intersect && (result.dist < closest_intersection.dist || !closest_intersection.did_intersect)) {
            closest_intersection = result;
        }
    }

    Intersection out;

    out.primitive_index = closest_intersection.primitive_index;
    out.surface_normal = closest_intersection.normal;

    if (closest_intersection.did_intersect) {
        out.location = closest_intersection.location;
    } else {
        out.location = { LARGE_NUMBER * cos(ray.angle), LARGE_NUMBER * sin(ray.angle) };
    }

    intersections[index] = out;
//    const device Ray &ray = rays[index];
//    const device Primitive &primitive = primitives[0];
//
//    bool do_intersect = false;
//    float2 location;
//
//    if (!is_disabled(ray)) {
//        float2 v1 = ray.origin - primitive.src;
//        float2 v2 = primitive.dst - primitive.src;
//        float2 v3 = normalize({ -sin(ray.angle), cos(ray.angle) });
//
//        float t1 = cross(float3(v2, 0), float3(v1, 0)).z / dot(v2, v3);
//        float t2 = dot(v1, v3) / dot(v2, v3);
//        do_intersect = t1 >= SMALL_NUMBER && t2 >= 0 && t2 < 1;
//        location = primitive.src + (primitive.dst - primitive.src) * t2;
//    }
//
//    Intersection intersection;
//
//    if (do_intersect) {
//        intersection.location = location;
//        intersection.primitive_index = 0;
//
//        float2 primitive_direction = primitive.dst - primitive.src;
//        intersection.surface_normal = atan2(primitive_direction.y, primitive_direction.x) + M_PI_2_F;
//    } else {
//        intersection.location = { LARGE_NUMBER * cos(ray.angle), LARGE_NUMBER * sin(ray.angle) };
//        intersection.primitive_index = __UINT32_MAX__;
//        intersection.surface_normal = NAN;
//    }
//
//    intersections[index] = intersection;
}
