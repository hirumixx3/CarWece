#version 300 es
precision highp float;
precision highp sampler2D;
in vec3 vPosition;
in vec3 vLocalPosition;
in vec3 vLocalNormal;
in vec3 vNormal;
in vec3 vColor;
in vec2 vUv;
flat in int vMaterial;
in vec4 vShadow;
uniform vec3 uCamera;
uniform vec3 uLight;
uniform vec3 uSunColor;
uniform vec3 uSky;
uniform float uTime;
uniform float uNight;
uniform float uShadowTexel;
uniform sampler2D uDepth;
out vec4 fragColor;
float hash21(vec2 p) {
  // Sin-free hash: the classic sin hash is slow and bands on mobile GPUs.
  vec3 p3=fract(vec3(p.xyx)*0.1031);
  p3+=dot(p3,p3.yzx+33.33);
  return fract((p3.x+p3.y)*p3.z);
}
float noise(vec2 p) {
  vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
  return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
vec3 filmic(vec3 x) { return clamp((x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14),0.0,1.0); }
uniform float uShadowQuality;
uniform float uPerfMode;
float visibility(vec3 n) {
  vec3 p=vShadow.xyz/vShadow.w*0.5+0.5;
  if(p.z>1.0||p.z<0.0||any(lessThan(p.xy,vec2(0)))||any(greaterThan(p.xy,vec2(1))))return 1.0;
  float bias=max(0.00018,0.00065*(1.0-max(dot(n,uLight),0.0)));
  // Shadow LOD: past ~60 m the PCF kernel is subpixel, and past ~110 m a
  // single tap is indistinguishable from 25. Most of the screen is far
  // scenery, so this is where the high quality mode spent its frame.
  float fragDist=length(vPosition-uCamera);
  float q=uShadowQuality;
  if(fragDist>110.0)q=0.0;
  else if(fragDist>60.0 && q>2.0)q=2.0;
  // Weak GPUs tighten the same LOD sooner; near shadows stay filtered.
  if(uPerfMode>0.5) {
    if(fragDist>85.0)q=0.0;
    else if(fragDist>45.0 && q>2.0)q=2.0;
  }
  float occluded;
  if(q<.5) {
    occluded=p.z-bias<=texture(uDepth,p.xy).r?0.0:1.0;
  } else if(q<1.5) {
    float sum=0.0;
    for(int i=0;i<4;i++) {
      vec2 offset=vec2((i==0||i==2)?-.5:.5,i<2?-.5:.5)*uShadowTexel;
      sum+=p.z-bias<=texture(uDepth,p.xy+offset).r?0.0:1.0;
    }
    occluded=sum*.25;
  } else if(q<2.5) {
    float sum=0.0;
    for(int x=-1;x<=1;x++)for(int y=-1;y<=1;y++) {
      float depth=texture(uDepth,p.xy+vec2(float(x),float(y))*uShadowTexel).r;
      sum+=p.z-bias<=depth?0.0:1.0;
    }
    occluded=sum/9.0;
  } else {
    float sum=0.0;
    for(int x=-2;x<=2;x++)for(int y=-2;y<=2;y++) {
      float depth=texture(uDepth,p.xy+vec2(float(x),float(y))*uShadowTexel*1.5).r;
      sum+=p.z-bias<=depth?0.0:1.0;
    }
    occluded=sum/25.0;
  }
  float result=1.0-0.75*occluded;
  // Fade shadows out at the edge of the light frustum instead of cutting
  // them off in a hard square where the shadow camera ends.
  float edge=smoothstep(0.0,0.045,min(min(p.x,1.0-p.x),min(p.y,1.0-p.y)));
  float faded=mix(1.0,result,edge);
  return mix(faded,1.0,smoothstep(150.0,260.0,fragDist)*0.85);
}
void main() {
  // Status billboards retain their UI colors and receive no scene lighting.
  if(vMaterial==18){fragColor=vec4(vColor,1.0);return;}
  vec3 n=normalize(vNormal);
  if(!gl_FrontFacing)n=-n;
  vec3 base=pow(vColor,vec3(2.2));
  vec3 viewDir=normalize(uCamera-vPosition);
  // These effects are unlit in the final image. Exit before material noise,
  // PCF shadow reads and GGX: their discarded lighting used to run per pixel.
  if(vMaterial==11 || vMaterial==12 || vMaterial==16 || vMaterial==17) {
    vec3 color;float alpha=1.0;
    if(vMaterial==11) {
      float rim=pow(1.0-abs(dot(n,viewDir)),2.0);
      color=vec3(.03,.7,1.0)*(0.6+rim*2.0);alpha=.08+rim*.52;
    } else if(vMaterial==17) {
      float rim=pow(1.0-abs(dot(n,viewDir)),2.0);
      float cracks=smoothstep(.65,.82,noise(vPosition.xz*4.0+vPosition.y));
      color=vec3(.30,.75,1.0)*(1.0+cracks);alpha=.18+rim*.45;
    } else if(vMaterial==12) {
      vec3 ambient=mix(vec3(.19,.22,.27),vec3(.16,.19,.31),uNight);
      ambient*=mix(.72,1.08,n.y*.5+.5);
      ambient+=vec3(.035,.025,.014)*(1.0-abs(n.y));
      color=base*(ambient+vec3(.25));alpha=.26;
    } else {
      float flame=noise(vPosition.xz*2.1+uTime*vec2(7.0,4.0));
      float heat=clamp(n.y*.25+flame*.85,0.0,1.0);
      color=mix(vec3(3.5,.17,.008),vec3(5.5,3.6,.55),heat);
    }
    fragColor=vec4(pow(filmic(color*1.28),vec3(1.0/2.2)),alpha);return;
  }
  float rough=0.58,metal=0.0,emissive=0.0;
  vec2 plane=abs(n.y)>.65?vPosition.xz:(abs(n.x)>.65?vPosition.zy:vPosition.xy);
  // Object-space plane for moving parts: world-space noise crawled across
  // paint, tires and attachments as they moved through the scene.
  vec2 localPlane=abs(vLocalNormal.y)>.65?vLocalPosition.xz:
    (abs(vLocalNormal.x)>.65?vLocalPosition.zy:vLocalPosition.xy);
  float footprint=max(length(dFdx(plane)),length(dFdy(plane)));
  float detail=1.0-smoothstep(.12,1.4,footprint);
  if(vMaterial==0) {
    // Automotive paint: dielectric base with a tight clearcoat response.
    rough=0.12;metal=0.22;
    base*=0.987+0.013*noise(localPlane*70.0);
  }
  if(vMaterial==1) { rough=0.91;base*=0.70+0.30*noise(localPlane*29.0); }
  if(vMaterial==2) { rough=0.10;metal=0.75; }
  if(vMaterial==3) {
    float brush=noise(vec2(localPlane.x*3.0,localPlane.y*.065));
    rough=.21+brush*.15;metal=.86;
    base*=.91+brush*.12;
  }
  if(vMaterial==4) {
    vec2 coord=vec2(vPosition.x/18.0,vPosition.z/85.0);
    coord.y+=mod(floor(coord.x),2.0)*0.5;
    vec2 plank=floor(coord),uv=fract(coord);
    float seam=smoothstep(0.0,0.009,uv.x)*smoothstep(0.0,0.009,1.0-uv.x)*smoothstep(0.0,0.003,uv.y)*smoothstep(0.0,0.003,1.0-uv.y);
    float grain=sin(uv.x*170.0+noise(vec2(uv.y*11.0,plank.x))*9.0)*0.035*detail;
    float knot=noise(vec2(uv.x*9.0,uv.y*57.0));
    base*=mix(0.24,1.0,seam)*(0.79+hash21(plank)*0.3+grain+knot*0.13);
    rough=0.51;
    n=normalize(n+vec3(grain*0.23,0,grain*0.06));
  }
  if(vMaterial==5) {
    float filtering=1.0-smoothstep(.04,.14,max(length(dFdx(vPosition)),length(dFdy(vPosition))));
    float weave=sin(vPosition.x*25.0)*sin(vPosition.z*25.0)*filtering;
    base*=0.83+0.15*noise(vPosition.xz*3.1)+weave*0.025;rough=0.93;
  }
  if(vMaterial==6) { base*=0.94+noise(plane*2.0)*0.06;rough=0.92; }
  if(vMaterial==7) {
    // Tarmac: matte, patchy and worn instead of glossy plastic.
    float wear=noise(vPosition.xz*.18+vPosition.y*.2);
    float micro=noise(plane*15.0)*detail;
    rough=.52+wear*.28;
    base*=.88+wear*.16+micro*.012;
  }
  if(vMaterial==8)rough=0.43;
  if(vMaterial==9) { emissive=1.8;rough=0.27; }
  if(vMaterial==10){rough=.44+noise(localPlane*.4)*.18;base*=.96+noise(localPlane*2.5)*.055;}
  if(vMaterial==13) {
    vec2 uv=fract(plane/32.0), tile=floor(plane/32.0);
    float grout=smoothstep(.0,.018,uv.x)*smoothstep(.0,.018,uv.y)*
      smoothstep(.0,.018,1.0-uv.x)*smoothstep(.0,.018,1.0-uv.y);
    float vein=noise(plane*.055+noise(plane*.17)*2.3);
    base*=mix(.30,.86+hash21(tile)*.13+vein*.10,grout);rough=mix(.78,.20,grout);
    n=normalize(n+vec3(noise(plane*1.1)*.006,0,noise(plane.yx)*.006)*detail);
  }
  if(vMaterial==14) { rough=.13;metal=.06; }
  if(vMaterial==15) {
    float aggregate=noise(plane*2.6),mottle=noise(plane*.045);
    float speck=smoothstep(.76,.91,aggregate)*detail;
    base*=.79+mottle*.23+aggregate*.10-speck*.12;rough=.74+aggregate*.16;
    n=normalize(n+vec3(noise(plane*4.3)-.5,0,noise(plane.yx*4.3)-.5)*.025*detail);
  }
  float ndl=max(dot(n,uLight),0.0),ndv=max(dot(n,viewDir),0.001);
  vec3 halfDir=normalize(viewDir+uLight);
  float vis=visibility(n);
  vec3 f0=mix(vec3(0.04),base,metal);
  vec3 fresnel=f0+(1.0-f0)*pow(1.0-ndv,5.0);
  float shine=mix(180.0,9.0,rough*rough);
  float spec=pow(max(dot(n,halfDir),0.0),shine)*(shine+2.0)/35.0;
  vec3 reflected=reflect(-viewDir,n);
  float window=pow(max(0.0,1.0-abs(reflected.x*.7+reflected.z*.45-.25)*5.0),6.0)*
    smoothstep(.0,.35,reflected.y);
  vec3 env=mix(vec3(0.12,0.15,0.19),uSky*0.8+vec3(0.20),smoothstep(-0.2,0.8,reflected.y));
  env+=vec3(.55,.65,.72)*window;
  float strip=pow(max(0.0,1.0-abs(reflected.z+.12)*14.0),4.0)*smoothstep(.15,.65,reflected.y);
  env+=vec3(.8,.76,.66)*strip;
  vec3 ambient=mix(vec3(0.19,0.22,0.27),vec3(0.16,0.19,0.31),uNight);
  ambient*=mix(.72,1.08,n.y*.5+.5);
  ambient+=vec3(.035,.025,.014)*(1.0-abs(n.y));
  // Soft bounce fill from the opposite azimuth, so shadow sides keep
  // readable form like a photographed scene instead of going flat.
  vec3 fillDir=normalize(vec3(-uLight.x,0.28,-uLight.z));
  ambient+=uSky*max(dot(n,fillDir),0.0)*0.38;
  // Energy-conserving GGX direct specular with a diffuse room bounce.
  // Surfaces rougher than .85 have no readable GGX lobe; skipping the
  // distribution/geometry math there saves real ALU on most world pixels.
  vec3 color=base*(ambient+uSunColor*ndl*vis*1.18)*(1.0-metal*.38);
  float ggxLimit=uPerfMode>0.5 ? 0.70 : 0.85;
  if(rough<ggxLimit) {
    float alphaR=max(.035,rough*rough), a2=alphaR*alphaR;
    float ndh=max(dot(n,halfDir),0.0), vdh=max(dot(viewDir,halfDir),0.0);
    float denominator=ndh*ndh*(a2-1.0)+1.0;
    float distribution=a2/(3.141593*denominator*denominator);
    float k=(rough+1.0)*(rough+1.0)/8.0;
    float geometry=ndv/(ndv*(1.0-k)+k)*ndl/(ndl*(1.0-k)+k);
    vec3 schlick=f0+(1.0-f0)*pow(1.0-vdh,5.0);
    color+=schlick*distribution*geometry/max(.01,4.0*ndv*ndl)*uSunColor*ndl*vis*.36;
  }
  color+=fresnel*env*(1.0-rough)*1.12;
  if(vMaterial==0 || vMaterial==14 || vMaterial==13) {
    float coat=pow(max(dot(n,halfDir),0.0),210.0);
    color+=vec3(.20)*coat*vis+env*pow(1.0-ndv,4.0)*.17;
  }
  color+=base*emissive;
  // Reflective dark blue windscreens retain a readable highlight even in shade.
  if(vMaterial==2)color=(mix(base*.16,env*.40,clamp(fresnel+vec3(.07),0.0,1.0))+uSunColor*spec*.24)*(.38+.62*vis);
  // Mild warm film response, with gamma conversion for the sRGB window surface.
  vec3 display=pow(filmic(color*1.28),vec3(1.0/2.2));
  // Photographic grade in display space, where every channel is in 0..1:
  // the same S-curve in HDR turned negative past ~2.37 and punched black
  // and magenta holes into the brightest clearcoat highlights.
  float luma=dot(display,vec3(0.2126,0.7152,0.0722));
  display=mix(vec3(luma),display,0.88);
  vec3 curved=display*display*(3.0-2.0*display);
  display=mix(display,curved,0.16);
  display*=mix(vec3(0.96,1.0,1.06),vec3(1.05,1.0,0.93),clamp(luma*1.4,0.0,1.0));
  fragColor=vec4(display,1.0);
}
