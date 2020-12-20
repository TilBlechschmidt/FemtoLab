//
//  BRDF.metal
//  FemtoPhoto
//
//  Created by Til Blechschmidt on 19.12.20.
//

#include <metal_stdlib>
#include "Structs.metal"
#include "Helpers.metal"

using namespace metal;

float sellmeierIor(float3 b, float3 c, float lambda) {
    float lSq = (lambda * 1e-3) * (lambda * 1e-3);
    return 1.0 + dot((b * lSq) / (lSq - c), float3(1.0));
}

struct FresnelResult {
    float reflectance;
    float cosThetaT;
};

FresnelResult dielectricReflectance(float eta, float cosThetaI) {
    float cosThetaT;
    float sinThetaTSq = eta * eta * (1.0 - cosThetaI * cosThetaI);
    if (sinThetaTSq > 1.0) {
        cosThetaT = 0.0;
        return { 1.0, cosThetaT };
    }
    cosThetaT = sqrt(1.0 - sinThetaTSq);

    float Rs = (eta * cosThetaI - cosThetaT) / (eta * cosThetaI + cosThetaT);
    float Rp = (eta * cosThetaT - cosThetaI) / (eta * cosThetaT + cosThetaI);

    return { (Rs*Rs + Rp*Rp) * 0.5, cosThetaT };
}

float sampleMirror(const device Ray &ray, const device Intersection &intersection) {
    return 2 * (intersection.surface_normal - M_PI_2_F) - ray.angle;
}

float sampleDielectric(const device Ray &ray, const device Intersection &intersection, float ior, uint32_t v0, uint32_t v1) {
//    float eta = 1.0 / ior; // sin(intersection.surface_normal - ray.angle) < 0.0 ? ior : 1.0 / ior; // wi.y < 0.0 ? ior : 1.0 / ior;
    FresnelResult fresnel = dielectricReflectance(1.0 / ior, cos(ray.angle));

    uint64_t rng = rand(v0, v1);
    float random_number = float(rng) / float(__UINT32_MAX__);

    if (random_number < fresnel.reflectance)
        return sampleMirror(ray, intersection);
    else {
        float thetaT = acos(fresnel.cosThetaT);
        float delta = sin(ray.angle) < 0.0 ? -thetaT : thetaT;
        return ray.angle + (intersection.surface_normal - delta);// ray.angle;
//        float old_x = cos(ray.angle);
//        float old_y = sin(ray.angle);
//        float new_x = -old_x * eta;
//        float new_y = -fresnel.cosThetaT * sign(old_y);
//        return atan2(new_y, new_x);
//        return ray.angle - acos(fresnel.cosThetaT);
//        return ray.angle + acos(fresnel.cosThetaT); // float2(-wi.x*eta, -cosThetaT * sign(wi.y));
    }
}

kernel void computeBRDF(
    const device Ray *source_rays [[ buffer(0) ]],
    device Ray *destination_rays [[ buffer(1) ]],
    const device Intersection *intersections [[ buffer(2) ]],
    uint2 gid [[thread_position_in_grid]],
    uint2 grid_dimensions [[threads_per_grid]]
) {
    uint index = thread_id(gid, grid_dimensions);

    const device Intersection &intersection = intersections[index];
    const device Ray &sourceRay = source_rays[index];

//    float ior = sellmeierIor(float3(1.6215, 0.2563, 1.6445), float3(0.0122, 0.0596, 147.4688), sourceRay.wavelength) / 1.4;
//    1.43134930    0.65054713    5.3414021    5.2799261×10−3    1.42382647×10−2    325.017834
    float ior = sellmeierIor(float3(1.43134930, 0.65054713, 5.3414021), float3(0.0052799261, 0.0142382647, 325.017834), sourceRay.wavelength);

    Ray destinationRay;

    if (!did_intersect(intersection) || is_disabled(sourceRay)) {
        destinationRay.angle = NAN;
    } else {
        destinationRay.origin = intersection.location;
        destinationRay.angle = sampleDielectric(source_rays[index], intersections[index], ior, uint32_t(gid.x), uint32_t(gid.y));
    //    destinationRay.angle = sampleMirror(source_rays[index], intersections[index]);
        destinationRay.wavelength = sourceRay.wavelength;
    }

    destination_rays[index] = destinationRay;
}
