#version 300 es
precision highp float;
layout(location=0) in vec3 aPosition;
layout(location=1) in vec3 aNormal;
layout(location=2) in vec3 aColor;
layout(location=3) in vec2 aUv;
layout(location=4) in float aMaterial;
uniform mat4 uModel;
uniform mat4 uVP;
uniform mat4 uLightVP;
out vec3 vPosition;
out vec3 vLocalPosition;
out vec3 vLocalNormal;
out vec3 vNormal;
out vec3 vColor;
out vec2 vUv;
flat out int vMaterial;
out vec4 vShadow;
void main() {
  vec4 world=uModel*vec4(aPosition,1.0);
  vPosition=world.xyz;
  vLocalPosition=aPosition;
  vLocalNormal=aNormal;
  // Inverse-transpose keeps normals correct under the non-uniform scales
  // used by beams, smoke and explosion instances; mat3(uModel) skewed them.
  vNormal=normalize(transpose(inverse(mat3(uModel)))*aNormal);
  vColor=aColor;vUv=aUv;vMaterial=int(aMaterial+0.5);
  vShadow=uLightVP*world;
  gl_Position=uVP*world;
}
