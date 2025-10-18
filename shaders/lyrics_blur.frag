#version 460 core
#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uOutputSize;
uniform vec2 uTextureSize;
uniform float uSigma;
uniform vec4 uColor;

out vec4 fragColor;

vec4 sampleGaussian(vec2 uv, vec2 texel, float sigma) {
  const int radius = 4;
  float twoSigmaSq = 2.0 * sigma * sigma;
  float weightSum = 0.0;
  vec4 accum = vec4(0.0);

  for (int x = -radius; x <= radius; x++) {
    for (int y = -radius; y <= radius; y++) {
      vec2 offset = vec2(float(x), float(y)) * texel;
      vec2 sampleUv = clamp(uv + offset, vec2(0.0), vec2(1.0));
      float weight = exp(-(float(x * x + y * y)) / twoSigmaSq);
      accum += texture(uTexture, sampleUv) * weight;
      weightSum += weight;
    }
  }

  return accum / weightSum;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / uOutputSize;
  vec4 baseColor = texture(uTexture, uv);

  if (uSigma <= 0.001) {
    fragColor = baseColor * uColor;
    return;
  }

  vec2 texel = 1.0 / uTextureSize;
  vec4 blurred = sampleGaussian(uv, texel, uSigma);
  fragColor = blurred * uColor;
}
