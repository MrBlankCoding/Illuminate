//
//  ColorShaders.metal
//  Illuminate
//
//  Created by Ethan Hall on 4/20/26.
//

#include <metal_stdlib>
using namespace metal;

float aa_step(float edge, float x) {
    float df = fwidth(x);
    return smoothstep(edge - df, edge + df, x);
}

float sd_rounded_rect(float2 p, float2 size, float radius) {
    float2 d = abs(p) - (size - radius);
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
}

float noise_grain(float2 p, float time) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}


[[ stitchable ]]
half4 shellGradientShader(
    float2 position,
    half4  color,
    float2 size,
    half4  topColor,
    half4  bottomColor,
    float  grainIntensity
) {
    float2 uv = position / size;
    
    float t = smoothstep(0.0, 1.0, uv.y);
    half4 finalColor = mix(topColor, bottomColor, half(t));
    
    if (grainIntensity > 0.0) {
        float grain = noise_grain(position, 0.0);
        finalColor.rgb = mix(finalColor.rgb, finalColor.rgb + (half(grain) - 0.5) * 0.1, half(grainIntensity));
    }
    
    return finalColor;
}

[[ stitchable ]]
half4 glassShader(
    float2 position,
    half4  color,
    float2 size,
    half4  accentColor,
    float  blurIntensity, // Used as a blend factor for the glass effect
    float  cornerRadius
) {
    float2 center = size * 0.5;
    float d = sd_rounded_rect(position - center, center, cornerRadius);
    float mask = 1.0 - aa_step(0.0, d);
    if (mask <= 0.0) return half4(0.0);
    
    half4 glassBase = half4(1.0, 1.0, 1.0, 0.03);
    if (accentColor.a > 0.0) {
        glassBase = mix(glassBase, accentColor, 0.1);
    }
    
    float fresnel = 1.0 - abs(d) / cornerRadius;
    fresnel = pow(clamp(fresnel, 0.0, 1.0), 3.0);
    
    float2 uv = position / size;
    float spec = exp(-pow((uv.y - 0.1) * 10.0, 2.0)) * 0.15;
    
    half4 result = mix(glassBase, half4(1.0, 1.0, 1.0, 0.2), half(fresnel * 0.5));
    result.rgb += half(spec);
    
    result.a *= half(mask);
    return result;
}

[[ stitchable ]]
half4 chromeShader(
    float2 position,
    half4  color,
    float2 size,
    half4  baseColor,
    half4  accentColor,
    float  strokeWidth
) {
    float2 uv = position / size;
    
    float shadow = smoothstep(0.0, 0.15, uv.y) * 0.1;
    float highlight = (1.0 - smoothstep(0.0, 0.02, uv.y)) * 0.2;
    
    half4 finalColor = baseColor;
    finalColor.rgb += half(highlight - shadow);
    if (accentColor.a > 0.0) {
        finalColor = mix(finalColor, accentColor, 0.05);
    }
    
    float edgeDist = min(min(position.x, size.x - position.x),
                         min(position.y, size.y - position.y));
    float strokeMask = 1.0 - aa_step(strokeWidth, edgeDist);
    
    half4 strokeColor = baseColor + half4(0.15, 0.15, 0.15, 0.0);
    return mix(finalColor, strokeColor, half(strokeMask));
}

[[ stitchable ]]
half4 ambientGlowShader(
    float2 position,
    half4  color,
    float2 size,
    half4  glowColor,
    float  radiusScale
) {
    float2 center = size * 0.5;
    float2 uv = (position - center) / (min(size.x, size.y) * radiusScale);
    float dist = length(uv);
    
    float falloff = exp(-dist * dist * 4.0);
    return color + glowColor * half(falloff);
}

[[ stitchable ]]
half4 noiseShader(
    float2 position,
    half4  color,
    float2 size,
    float  intensity,
    float  time
) {
    float n = noise_grain(position, time);
    return half4(half(n), half(n), half(n), half(intensity)) * color.a;
}
