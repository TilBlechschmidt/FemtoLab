//
//  Helpers.metal
//  FemtoPhoto
//
//  Created by Til Blechschmidt on 19.12.20.
//

#include <metal_stdlib>
using namespace metal;

inline uint thread_id(uint2 gid, uint2 grid_dimensions) {
    return gid.y * grid_dimensions.x + gid.x;
}

inline uint64_t rand(uint32_t v0, uint32_t v1) {
    uint32_t sum = 0, delta = 0x9E3779b9, k0 = 0xA341316C, k1 = 0xC8013EA4, k2 = 0xAD90777D, k3 = 0x7E95761E;

    for (uint i = 0; i < 8; i++) {
        sum += delta;
        v0 += ((v1 << 4) + k0) ^ (v1 + sum) ^ ((v1 >> 5) + k1);
        v1 += ((v0 << 4) + k2) ^ (v0 + sum) ^ ((v0 >> 5) + k3);
    }

    return v1 << 16 | v0;
}

// --- Color conversion

/**
 * A multi-lobe, piecewise Gaussian fit of CIE 1931 XYZ Color Matching Functions by Wyman el al. from Nvidia. The
 * code here is adopted from the Listing 1 of the paper authored by Wyman et al.
 * <p>
 * Reference: Chris Wyman, Peter-Pike Sloan, and Peter Shirley, Simple Analytic Approximations to the CIE XYZ Color
 * Matching Functions, Journal of Computer Graphics Techniques (JCGT), vol. 2, no. 2, 1-11, 2013.
 *
 * @param wavelength wavelength in nm
 * @return XYZ in a float array in the order of X, Y, Z. each value in the range of [0.0, 1.0]
 */
inline float3 cie1931WavelengthToXYZFit(float wavelength) {
    float wave = wavelength;

    float x;
    {
        float t1 = (wave - 442.0) * ((wave < 442.0) ? 0.0624 : 0.0374);
        float t2 = (wave - 599.8) * ((wave < 599.8) ? 0.0264 : 0.0323);
        float t3 = (wave - 501.1) * ((wave < 501.1) ? 0.0490 : 0.0382);

        x =   0.362 * exp(-0.5 * t1 * t1)
            + 1.056 * exp(-0.5 * t2 * t2)
            - 0.065 * exp(-0.5 * t3 * t3);
    }

    float y;
    {
        float t1 = (wave - 568.8) * ((wave < 568.8) ? 0.0213 : 0.0247);
        float t2 = (wave - 530.9) * ((wave < 530.9) ? 0.0613 : 0.0322);

        y =   0.821 * exp(-0.5 * t1 * t1)
            + 0.286 * exp(-0.5 * t2 * t2);
    }

    float z;
    {
        float t1 = (wave - 437.0) * ((wave < 437.0) ? 0.0845 : 0.0278);
        float t2 = (wave - 459.0) * ((wave < 459.0) ? 0.0385 : 0.0725);

        z =   1.217 * exp(-0.5 * t1 * t1)
            + 0.681 * exp(-0.5 * t2 * t2);
    }

    return { x, y, z };
}

/**
 * helper function for {@link #srgbXYZ2RGB(float[])}
 */
inline float srgbXYZ2RGBPostprocess(float c) {
    // clip if c is out of range
    c = c > 1 ? 1 : (c < 0 ? 0 : c);

    // apply the color component transfer function
    c = c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1. / 2.4) - 0.055;

    return c;
}

/**
 * Convert XYZ to RGB in the sRGB color space
 * <p>
 * The conversion matrix and color component transfer function is taken from http://www.color.org/srgb.pdf, which
 * follows the International Electrotechnical Commission standard IEC 61966-2-1 "Multimedia systems and equipment -
 * Colour measurement and management - Part 2-1: Colour management - Default RGB colour space - sRGB"
 *
 * @param xyz XYZ values in a float array in the order of X, Y, Z. each value in the range of [0.0, 1.0]
 * @return RGB values in a float array, in the order of R, G, B. each value in the range of [0.0, 1.0]
 */
inline float3 srgbXYZ2RGB(float3 xyz) {
    float x = xyz.x;
    float y = xyz.y;
    float z = xyz.z;

    float rl =  3.2406255 * x + -1.537208  * y + -0.4986286 * z;
    float gl = -0.9689307 * x +  1.8757561 * y +  0.0415175 * z;
    float bl =  0.0557101 * x + -0.2040211 * y +  1.0569959 * z;

    return {
            srgbXYZ2RGBPostprocess(rl),
            srgbXYZ2RGBPostprocess(gl),
            srgbXYZ2RGBPostprocess(bl)
    };
}

/**
 * Convert a wavelength in the visible light spectrum to a RGB color value that is suitable to be displayed on a
 * monitor
 *
 * @param wavelength wavelength in nm
 * @return RGB color encoded in int. each color is represented with 8 bits and has a layout of
 * 00000000RRRRRRRRGGGGGGGGBBBBBBBB where MSB is at the leftmost
 */
inline float3 wavelengthToRGB(float wavelength){
    float3 xyz = cie1931WavelengthToXYZFit(wavelength);
    float3 rgb = srgbXYZ2RGB(xyz);

    return rgb;
//    int c = 0;
//    c |= (((int) (rgb[0] * 0xFF)) & 0xFF) << 16;
//    c |= (((int) (rgb[1] * 0xFF)) & 0xFF) << 8;
//    c |= (((int) (rgb[2] * 0xFF)) & 0xFF) << 0;
//
//    return c;
}
