// HLSL ports of assets/shaders/*.vert|frag (the GLSL ES 3.0 sources the Dart
// side still ships to Android). Matrices travel as four float4 columns and
// are applied manually, so the byte layout matches the game's column-major
// packets exactly, with no dependence on HLSL matrix packing rules.
// The only intentional divergence from the GLSL: the light clip position is
// produced from a Direct3D-adjusted light VP (z already in [0,1]), so the
// fragment shader uses p.z directly where GLSL remapped it by *0.5+0.5.
#pragma once

inline constexpr const char* kSceneShader = R"HLSL(
cbuffer FrameCB : register(b0) {
  float4 uVP0, uVP1, uVP2, uVP3;
  float4 uLVP0, uLVP1, uLVP2, uLVP3;
  float3 uCamera; float uPad0;
  float3 uLight; float uPad1;
  float3 uSunColor; float uPad2;
  float3 uSky; float uPad3;
  float uTime, uNight, uShadowTexel, uShadowQuality;
};
cbuffer ModelCB : register(b1) {
  float4 uM0, uM1, uM2, uM3;
  float4 uN0, uN1, uN2, uNPad;
};
float4 Apply(float4 c0, float4 c1, float4 c2, float4 c3, float4 v) {
  return c0 * v.x + c1 * v.y + c2 * v.z + c3 * v.w;
}
float4 Model(float4 v) { return Apply(uM0, uM1, uM2, uM3, v); }

struct VSInput {
  float3 position : POSITION;
  float3 normal : NORMAL;
  float3 color : COLOR;
  float2 uv : TEXCOORD0;
  float material : TEXCOORD1;
};
struct VSOut {
  float4 clip : SV_POSITION;
  float3 wpos : TEXCOORD0;
  float3 lpos : TEXCOORD1;
  float3 lnormal : TEXCOORD2;
  float3 wnormal : TEXCOORD3;
  float3 color : TEXCOORD4;
  float2 uv : TEXCOORD5;
  nointerpolation int material : TEXCOORD6;
  float4 shadow : TEXCOORD7;
};

VSOut VSMain(VSInput input) {
  VSOut o;
  float4 world = Model(float4(input.position, 1.0));
  o.wpos = world.xyz;
  o.lpos = input.position;
  o.lnormal = input.normal;
  o.wnormal = normalize(uN0.xyz * input.normal.x + uN1.xyz * input.normal.y +
                        uN2.xyz * input.normal.z);
  o.color = input.color;
  o.uv = input.uv;
  o.material = (int)(input.material + 0.5);
  o.shadow = Apply(uLVP0, uLVP1, uLVP2, uLVP3, world);
  o.clip = Apply(uVP0, uVP1, uVP2, uVP3, world);
  return o;
}

Texture2D uDepth : register(t0);
SamplerState sShadow : register(s0);

float hash21(float2 p) { return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }
float noise(float2 p) {
  float2 i = floor(p), f = frac(p);
  f = f * f * (3.0 - 2.0 * f);
  return lerp(lerp(hash21(i), hash21(i + float2(1, 0)), f.x),
              lerp(hash21(i + float2(0, 1)), hash21(i + float2(1, 1)), f.x), f.y);
}
float3 filmic(float3 x) {
  return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14),
               float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0));
}
float gmod(float x, float y) { return x - y * floor(x / y); }

float visibility(VSOut input, float3 n) {
  float3 p = input.shadow.xyz / input.shadow.w;
  p.xy = p.xy * 0.5 + 0.5;
  if (p.z > 1.0 || p.z < 0.0 || any(p.xy < 0.0) || any(p.xy > 1.0)) return 1.0;
  float bias = max(0.00018, 0.00065 * (1.0 - max(dot(n, uLight), 0.0)));
  float occluded;
  if (uShadowQuality < .5) {
    occluded = p.z - bias <= uDepth.Sample(sShadow, p.xy).r ? 0.0 : 1.0;
  } else if (uShadowQuality < 1.5) {
    float sum = 0.0;
    for (int i = 0; i < 4; i++) {
      float2 offset = float2((i == 0 || i == 2) ? -.5 : .5, i < 2 ? -.5 : .5) * uShadowTexel;
      sum += p.z - bias <= uDepth.Sample(sShadow, p.xy + offset).r ? 0.0 : 1.0;
    }
    occluded = sum * .25;
  } else {
    float sum = 0.0;
    for (int x = -1; x <= 1; x++)
      for (int y = -1; y <= 1; y++) {
        float depth = uDepth.Sample(sShadow, p.xy + float2((float)x, (float)y) * uShadowTexel).r;
        sum += p.z - bias <= depth ? 0.0 : 1.0;
      }
    occluded = sum / 9.0;
  }
  float result = 1.0 - 0.75 * occluded;
  float edge = smoothstep(0.0, 0.045, min(min(p.x, 1.0 - p.x), min(p.y, 1.0 - p.y)));
  return lerp(1.0, result, edge);
}

float4 PSMain(VSOut input, bool front : SV_IsFrontFace) : SV_TARGET {
  int vMaterial = input.material;
  float3 vColor = input.color;
  float3 vPosition = input.wpos;
  float2 vUv = input.uv;
  if (vMaterial == 18) return float4(vColor, 1.0);
  float3 n = normalize(input.wnormal);
  if (!front) n = -n;
  float3 base = pow(vColor, 2.2);
  float3 viewDir = normalize(uCamera - vPosition);
  if (vMaterial == 11 || vMaterial == 12 || vMaterial == 16 || vMaterial == 17) {
    float3 color;
    float alpha = 1.0;
    if (vMaterial == 11) {
      float rim = pow(1.0 - abs(dot(n, viewDir)), 2.0);
      color = float3(.03, .7, 1.0) * (0.6 + rim * 2.0);
      alpha = .08 + rim * .52;
    } else if (vMaterial == 17) {
      float rim = pow(1.0 - abs(dot(n, viewDir)), 2.0);
      float cracks = smoothstep(.65, .82, noise(vPosition.xz * 4.0 + vPosition.y));
      color = float3(.30, .75, 1.0) * (1.0 + cracks);
      alpha = .18 + rim * .45;
    } else if (vMaterial == 12) {
      float3 ambient = lerp(float3(.19, .22, .27), float3(.16, .19, .31), uNight);
      ambient *= lerp(.72, 1.08, n.y * .5 + .5);
      ambient += float3(.035, .025, .014) * (1.0 - abs(n.y));
      color = base * (ambient + float3(.25, .25, .25));
      alpha = .26;
    } else {
      float flame = noise(vPosition.xz * 2.1 + uTime * float2(7.0, 4.0));
      float heat = clamp(n.y * .25 + flame * .85, 0.0, 1.0);
      color = lerp(float3(3.5, .17, .008), float3(5.5, 3.6, .55), heat);
    }
    return float4(pow(filmic(color * 1.28), 1.0 / 2.2), alpha);
  }
  float rough = 0.58, metal = 0.0, emissive = 0.0;
  float2 plane = abs(n.y) > .65 ? vPosition.xz : (abs(n.x) > .65 ? vPosition.zy : vPosition.xy);
  float2 localPlane = abs(input.lnormal.y) > .65
                          ? input.lpos.xz
                          : (abs(input.lnormal.x) > .65 ? input.lpos.zy : input.lpos.xy);
  float footprint = max(length(ddx(plane)), length(ddy(plane)));
  float detail = 1.0 - smoothstep(.12, 1.4, footprint);
  if (vMaterial == 0) {
    rough = 0.12;
    metal = 0.22;
    base *= 0.987 + 0.013 * noise(localPlane * 70.0);
  }
  if (vMaterial == 1) {
    rough = 0.91;
    base *= 0.70 + 0.30 * noise(localPlane * 29.0);
  }
  if (vMaterial == 2) {
    rough = 0.10;
    metal = 0.75;
  }
  if (vMaterial == 3) {
    float brush = noise(float2(localPlane.x * 3.0, localPlane.y * .065));
    rough = .21 + brush * .15;
    metal = .86;
    base *= .91 + brush * .12;
  }
  if (vMaterial == 4) {
    float2 coord = float2(vPosition.x / 18.0, vPosition.z / 85.0);
    coord.y += gmod(floor(coord.x), 2.0) * 0.5;
    float2 plank = floor(coord), uv = frac(coord);
    float seam = smoothstep(0.0, 0.009, uv.x) * smoothstep(0.0, 0.009, 1.0 - uv.x) *
                 smoothstep(0.0, 0.003, uv.y) * smoothstep(0.0, 0.003, 1.0 - uv.y);
    float grain = sin(uv.x * 170.0 + noise(float2(uv.y * 11.0, plank.x)) * 9.0) * 0.035 * detail;
    float knot = noise(float2(uv.x * 9.0, uv.y * 57.0));
    base *= lerp(0.24, 1.0, seam) * (0.79 + hash21(plank) * 0.3 + grain + knot * 0.13);
    rough = 0.51;
    n = normalize(n + float3(grain * 0.23, 0, grain * 0.06));
  }
  if (vMaterial == 5) {
    float filtering = 1.0 - smoothstep(.04, .14, max(length(ddx(vPosition)), length(ddy(vPosition))));
    float weave = sin(vPosition.x * 25.0) * sin(vPosition.z * 25.0) * filtering;
    base *= 0.83 + 0.15 * noise(vPosition.xz * 3.1) + weave * 0.025;
    rough = 0.93;
  }
  if (vMaterial == 6) {
    base *= 0.94 + noise(plane * 2.0) * 0.06;
    rough = 0.92;
  }
  if (vMaterial == 7) {
    float wear = noise(vPosition.xz * .18 + vPosition.y * .2);
    float micro = noise(plane * 15.0) * detail;
    rough = .52 + wear * .28;
    base *= .88 + wear * .16 + micro * .012;
  }
  if (vMaterial == 8) rough = 0.43;
  if (vMaterial == 9) {
    emissive = 1.8;
    rough = 0.27;
  }
  if (vMaterial == 10) {
    rough = .44 + noise(localPlane * .4) * .18;
    base *= .96 + noise(localPlane * 2.5) * .055;
  }
  if (vMaterial == 13) {
    float2 uv = frac(plane / 32.0), tile = floor(plane / 32.0);
    float grout = smoothstep(.0, .018, uv.x) * smoothstep(.0, .018, uv.y) *
                  smoothstep(.0, .018, 1.0 - uv.x) * smoothstep(.0, .018, 1.0 - uv.y);
    float vein = noise(plane * .055 + noise(plane * .17) * 2.3);
    base *= lerp(.30, .86 + hash21(tile) * .13 + vein * .10, grout);
    rough = lerp(.78, .20, grout);
    n = normalize(n + float3(noise(plane * 1.1) * .006, 0, noise(plane.yx) * .006) * detail);
  }
  if (vMaterial == 14) {
    rough = .13;
    metal = .06;
  }
  if (vMaterial == 15) {
    float aggregate = noise(plane * 2.6), mottle = noise(plane * .045);
    float speck = smoothstep(.76, .91, aggregate) * detail;
    base *= .79 + mottle * .23 + aggregate * .10 - speck * .12;
    rough = .74 + aggregate * .16;
    n = normalize(n + float3(noise(plane * 4.3) - .5, 0, noise(plane.yx * 4.3) - .5) * .025 * detail);
  }
  float ndl = max(dot(n, uLight), 0.0), ndv = max(dot(n, viewDir), 0.001);
  float3 halfDir = normalize(viewDir + uLight);
  float vis = visibility(input, n);
  float3 f0 = lerp(float3(0.04, 0.04, 0.04), base, metal);
  float3 fresnel = f0 + (1.0 - f0) * pow(1.0 - ndv, 5.0);
  float shine = lerp(180.0, 9.0, rough * rough);
  float spec = pow(max(dot(n, halfDir), 0.0), shine) * (shine + 2.0) / 35.0;
  float3 reflected = reflect(-viewDir, n);
  float window = pow(max(0.0, 1.0 - abs(reflected.x * .7 + reflected.z * .45 - .25) * 5.0), 6.0) *
                 smoothstep(.0, .35, reflected.y);
  float3 env = lerp(float3(0.12, 0.15, 0.19), uSky * 0.8 + float3(0.20, 0.20, 0.20),
                    smoothstep(-0.2, 0.8, reflected.y));
  env += float3(.55, .65, .72) * window;
  float strip = pow(max(0.0, 1.0 - abs(reflected.z + .12) * 14.0), 4.0) *
                smoothstep(.15, .65, reflected.y);
  env += float3(.8, .76, .66) * strip;
  float3 ambient = lerp(float3(0.19, 0.22, 0.27), float3(0.16, 0.19, 0.31), uNight);
  ambient *= lerp(.72, 1.08, n.y * .5 + .5);
  ambient += float3(.035, .025, .014) * (1.0 - abs(n.y));
  float3 fillDir = normalize(float3(-uLight.x, 0.28, -uLight.z));
  ambient += uSky * max(dot(n, fillDir), 0.0) * 0.38;
  float3 color = base * (ambient + uSunColor * ndl * vis * 1.18) * (1.0 - metal * .38);
  float alphaR = max(.035, rough * rough), a2 = alphaR * alphaR;
  float ndh = max(dot(n, halfDir), 0.0), vdh = max(dot(viewDir, halfDir), 0.0);
  float denominator = ndh * ndh * (a2 - 1.0) + 1.0;
  float distribution = a2 / (3.141593 * denominator * denominator);
  float k = (rough + 1.0) * (rough + 1.0) / 8.0;
  float geometry = ndv / (ndv * (1.0 - k) + k) * ndl / (ndl * (1.0 - k) + k);
  float3 schlick = f0 + (1.0 - f0) * pow(1.0 - vdh, 5.0);
  color += schlick * distribution * geometry / max(.01, 4.0 * ndv * ndl) * uSunColor * ndl * vis * .36;
  color += fresnel * env * (1.0 - rough) * 1.12;
  if (vMaterial == 0 || vMaterial == 14 || vMaterial == 13) {
    float coat = pow(max(dot(n, halfDir), 0.0), 210.0);
    color += float3(.20, .20, .20) * coat * vis + env * pow(1.0 - ndv, 4.0) * .17;
  }
  color += base * emissive;
  if (vMaterial == 2)
    color = (lerp(base * .16, env * .40,
                  clamp(fresnel + float3(.07, .07, .07), float3(0.0, 0.0, 0.0),
                        float3(1.0, 1.0, 1.0))) +
             uSunColor * spec * .24) *
            (.38 + .62 * vis);
  float3 display = pow(filmic(color * 1.28), 1.0 / 2.2);
  float luma = dot(display, float3(0.2126, 0.7152, 0.0722));
  display = lerp(float3(luma, luma, luma), display, 0.88);
  float3 curved = display * display * (3.0 - 2.0 * display);
  display = lerp(display, curved, 0.16);
  display *= lerp(float3(0.96, 1.0, 1.06), float3(1.05, 1.0, 0.93), clamp(luma * 1.4, 0.0, 1.0));
  return float4(display, 1.0);
}
)HLSL";

inline constexpr const char* kDepthShader = R"HLSL(
cbuffer FrameCB : register(b0) {
  float4 uVP0, uVP1, uVP2, uVP3;
  float4 uLVP0, uLVP1, uLVP2, uLVP3;
  float3 uCamera; float uPad0;
  float3 uLight; float uPad1;
  float3 uSunColor; float uPad2;
  float3 uSky; float uPad3;
  float uTime, uNight, uShadowTexel, uShadowQuality;
};
cbuffer ModelCB : register(b1) {
  float4 uM0, uM1, uM2, uM3;
  float4 uN0, uN1, uN2, uNPad;
};
float4 Apply(float4 c0, float4 c1, float4 c2, float4 c3, float4 v) {
  return c0 * v.x + c1 * v.y + c2 * v.z + c3 * v.w;
}
float4 VSMain(float3 position : POSITION) : SV_POSITION {
  float4 world = Apply(uM0, uM1, uM2, uM3, float4(position, 1.0));
  return Apply(uLVP0, uLVP1, uLVP2, uLVP3, world);
}
void PSMain() {}
)HLSL";
