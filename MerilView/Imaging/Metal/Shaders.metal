#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Fullscreen quad vertex shader
vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = in.position;
    out.texCoord = in.texCoord;
    return out;
}

// 2D slice sampling with 16-bit Window/Level LUT mapping
fragment float4 fragment_slice_lut(VertexOut in [[stage_in]],
                                  texture2d<float> sliceTexture [[texture(0)]],
                                  sampler textureSampler [[sampler(0)]],
                                  constant float &windowCenter [[buffer(0)]],
                                  constant float &windowWidth [[buffer(1)]],
                                  constant int &invert [[buffer(2)]]) {
    float rawValue = sliceTexture.sample(textureSampler, in.texCoord).r;
    float halfW = max(1.0, windowWidth) / 2.0;
    float minVal = windowCenter - halfW;
    float maxVal = windowCenter + halfW;
    float gray = clamp((rawValue - minVal) / max(1.0, maxVal - minVal), 0.0, 1.0);
    
    if (invert != 0) {
        gray = 1.0 - gray;
    }
    
    return float4(gray, gray, gray, 1.0);
}

// 3D Volume Maximum Intensity Projection (MIP) fragment shader
fragment float4 fragment_volume_mip(VertexOut in [[stage_in]],
                                   texture3d<float> volumeTexture [[texture(0)]],
                                   sampler volumeSampler [[sampler(0)]],
                                   constant float &azimuth [[buffer(0)]],
                                   constant float &elevation [[buffer(1)]],
                                   constant float &windowCenter [[buffer(2)]],
                                   constant float &windowWidth [[buffer(3)]]) {
    float2 uv = in.texCoord - 0.5;
    float radAz = azimuth * 3.14159265 / 180.0;
    float cosAz = cos(radAz);
    float sinAz = sin(radAz);
    
    float maxVal = 0.0;
    int numSteps = 128;
    float stepSize = 1.0 / float(numSteps);
    
    for (int i = 0; i < numSteps; i++) {
        float depth = (float(i) / float(numSteps)) - 0.5;
        float3 samplePos;
        samplePos.x = 0.5 + (uv.x * cosAz - depth * sinAz);
        samplePos.y = 0.5 + uv.y;
        samplePos.z = 0.5 + (uv.x * sinAz + depth * cosAz);
        
        if (samplePos.x >= 0.0 && samplePos.x <= 1.0 &&
            samplePos.y >= 0.0 && samplePos.y <= 1.0 &&
            samplePos.z >= 0.0 && samplePos.z <= 1.0) {
            float val = volumeTexture.sample(volumeSampler, samplePos).r;
            if (val > maxVal) {
                maxVal = val;
            }
        }
    }
    
    float halfW = max(1.0, windowWidth) / 2.0;
    float minVal = windowCenter - halfW;
    float maxV = windowCenter + halfW;
    float gray = clamp((maxVal - minVal) / max(1.0, maxV - minVal), 0.0, 1.0);
    
    return float4(gray, gray, gray, 1.0);
}
