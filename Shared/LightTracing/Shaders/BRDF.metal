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

float sellmeierEquation(float3 b, float3 c, float lambda) {
    float lSq = (lambda * 1e-3) * (lambda * 1e-3);
    return 1.0 + dot((pow(b, 2) * lSq) / (lSq - pow(c, 2)), float3(1.0));
}

float sampleMirror(const device Ray &ray, const device Intersection &intersection) {
    return 2 * (intersection.surface_normal - M_PI_2_F) - ray.angle;
}

float sampleDielectric(device Ray &ray, const device Intersection &intersection) {
    // Calculate wavelength dependent refraction indices for source and destination materials
//    float n_1 = 1; // sellmeierEquation(float3(1.43134930, 0.65054713, 5.3414021), float3(0.0052799261, 0.0142382647, 325.017834), ray.wavelength); // air
//    float n_2 = sellmeierEquation(float3(0.6961663, 0.4079426, 0.8974794), float3(0.0684043, 0.1162414, 9.896161), ray.wavelength); // fused silica

    float n_1 = sellmeierEquation(float3(sqrt(1.6215), sqrt(0.2563), sqrt(1.6445)), float3(sqrt(0.0122), sqrt(0.0596), sqrt(17.4688)), ray.wavelength) / 1.8;
    float n_2 = 1;

    // Calculate the incidence angle
    // Done by "rotating" the whole coordinate system so that the surface normal is aligned with the x-axis
    float surface_angle = intersection.surface_normal - M_PI_2_F;
    float theta_i = M_PI_2_F - (surface_angle - ray.angle);

    // Check if the angle is >90º
    // If so, flip the whole system around so the incidence is less than 90º
    // This is required because Snell's law does not particularly like angles larger than that (note: this is distinct from total internal reflection where theta_t is >90º).
    // It seems like Schlick's approximation could deal with it but better to be safe than sorry!
    bool is_flipped = cos(theta_i) < 0;
    if (is_flipped) {
        float tmp = n_2;
        n_2 = n_1;
        n_1 = tmp;
        theta_i += M_PI_F;
    }

    // Schlick's approximation to determine reflectance
    float R_0 = pow((n_1 - n_2) / (n_1 + n_2), 2);
    float R = R_0 + (1 - R_0) * pow(1 - cos(theta_i), 5);

    // Snell's law
    // Calculates refraction angle
    float theta_t = asin(n_1 / n_2 * sin(theta_i));

    // Account for total internal reflection and reflection based on fresnels law (or rather its approximation)
    float random_number = rand(ray.rng_state);
    bool total_internal_reflection = isnan(theta_t);
    bool fresnel_probabilistic_reflection = random_number < R;

    if (total_internal_reflection || fresnel_probabilistic_reflection)
        return sampleMirror(ray, intersection);

    // If we previously flipped the system, unflip it.
    if (is_flipped) theta_t -= M_PI_F;

    // Reverse the rotation we've done before
    return -M_PI_2_F + theta_t + surface_angle;
}

kernel void computeBRDF(
    device Ray *source_rays [[ buffer(0) ]],
    device Ray *destination_rays [[ buffer(1) ]],
    const device Intersection *intersections [[ buffer(2) ]],
    uint2 gid [[thread_position_in_grid]],
    uint2 grid_dimensions [[threads_per_grid]]
) {
    uint index = thread_id(gid, grid_dimensions);

    const device Intersection &intersection = intersections[index];
    const device Ray &sourceRay = source_rays[index];

    Ray destinationRay;

    if (!did_intersect(intersection) || is_disabled(sourceRay)) {
        destinationRay.angle = NAN;
    } else {
        destinationRay.origin = intersection.location;
//        destinationRay.angle = sampleDielectric(source_rays[index], intersections[index], uint32_t(gid.x * index), uint32_t(gid.y * index));
        destinationRay.angle = sampleDielectric(source_rays[index], intersections[index]);
//        destinationRay.angle = sampleDielectric(source_rays[index], intersections[index], ior, uint32_t(gid.x), uint32_t(gid.y));
    //    destinationRay.angle = sampleMirror(source_rays[index], intersections[index]);
        destinationRay.wavelength = sourceRay.wavelength;
        destinationRay.rng_state = sourceRay.rng_state;
    }

    destination_rays[index] = destinationRay;
}
