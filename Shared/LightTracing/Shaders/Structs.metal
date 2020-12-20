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

struct Ray {
    packed_float2 origin;
    float angle;
    float wavelength;
};

/// Intersection point of a ray and a primitive.
/// If the primitiveIndex is __UINT32_MAX__ then no intersection was encountered.
/// In that case, the location will be the source ray extrapolated to a distance of LARGE_NUMBER on each axis.
struct Intersection {
    packed_float2 location;
    uint32_t primitive_index;
    float surface_normal;
};
