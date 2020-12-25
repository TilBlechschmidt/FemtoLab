//
//  Structs.metal
//  FemtoPhoto
//
//  Created by Til Blechschmidt on 19.12.20.
//

#include <metal_stdlib>
using namespace metal;

struct Primitive {
    packed_float2 src;
    packed_float2 dst;
};

struct Material {
    packed_float3 sellmeier_coefficient_b;
    packed_float3 sellmeier_coefficient_c;
    float sellmeier_divisor;
};

/// Light ray.
/// Can be inactive if previous rays did not intersect.
/// This state is denoted by angle being NaN.
struct Ray {
    packed_float2 origin;
    float angle;
    float wavelength;
    float4 rng_state;
};

/// Intersection point of a ray and a primitive.
/// If the primitiveIndex is __UINT32_MAX__ then no intersection was encountered.
/// In that case, the location will be the source ray extrapolated to a distance of LARGE_NUMBER on each axis.
struct Intersection {
    packed_float2 location;
    uint16_t primitive_index;
    float surface_normal;
};

inline bool did_intersect(Intersection intersection) {
    return intersection.primitive_index != __UINT16_MAX__;
}

inline bool is_disabled(Ray ray) {
    return isnan(ray.angle);
}
