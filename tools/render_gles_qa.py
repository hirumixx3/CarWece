#!/usr/bin/env python3
"""Run the Android GLES shaders and exported meshes on Mesa EGL for visual QA.

Requires Python, numpy, Pillow and Mesa EGL; does not emulate Android lifecycle.
Usage: python tools/render_gles_qa.py EXPORT_DIRECTORY OUTPUT_DIRECTORY
"""
import ctypes as c
import json
import math
import sys
from pathlib import Path
import numpy as np
from PIL import Image

U, I, F, B, P = c.c_uint, c.c_int, c.c_float, c.c_ubyte, c.c_void_p
PI, PU, PF = c.POINTER(I), c.POINTER(U), c.POINTER(F)
egl=c.CDLL('libEGL.so.1')
egl.eglGetProcAddress.argtypes=[c.c_char_p];egl.eglGetProcAddress.restype=P
def proc(name,result,args):
    address=egl.eglGetProcAddress(name.encode())
    if not address:raise RuntimeError('Missing GL entry point '+name)
    return c.CFUNCTYPE(result,*args)(address)
def ebind(name,result,args):
    f=getattr(egl,name);f.restype=result;f.argtypes=args;return f
get_display=proc('eglGetPlatformDisplayEXT',P,[U,P,PI])
display=get_display(0x31DD,None,None)
major,minor=I(),I()
assert ebind('eglInitialize',U,[P,PI,PI])(display,c.byref(major),c.byref(minor))
assert ebind('eglBindAPI',U,[U])(0x30A0)
attrs=(I*15)(0x3033,1,0x3040,0x0040,0x3024,8,0x3023,8,0x3022,8,0x3021,8,0x3025,24,0x3038)
config=P();count=I()
assert ebind('eglChooseConfig',U,[P,PI,c.POINTER(P),I,PI])(display,attrs,c.byref(config),1,c.byref(count)) and count.value
width,height=1280,720
pbuf=(I*5)(0x3057,width,0x3056,height,0x3038)
surface=ebind('eglCreatePbufferSurface',P,[P,P,PI])(display,config,pbuf)
context=ebind('eglCreateContext',P,[P,P,P,PI])(display,config,None,(I*3)(0x3098,3,0x3038))
assert surface and context
assert ebind('eglMakeCurrent',U,[P,P,P,P])(display,surface,surface,context)

specs={
 'glCreateShader':(U,[U]),'glShaderSource':(None,[U,I,c.POINTER(c.c_char_p),PI]),'glCompileShader':(None,[U]),
 'glGetShaderiv':(None,[U,U,PI]),'glGetShaderInfoLog':(None,[U,I,PI,P]),'glCreateProgram':(U,[]),
 'glAttachShader':(None,[U,U]),'glLinkProgram':(None,[U]),'glGetProgramiv':(None,[U,U,PI]),
 'glGetProgramInfoLog':(None,[U,I,PI,P]),'glUseProgram':(None,[U]),'glGetString':(c.c_char_p,[U]),
 'glGenBuffers':(None,[I,PU]),'glBindBuffer':(None,[U,U]),'glBufferData':(None,[U,c.c_ssize_t,P,U]),
 'glGenTextures':(None,[I,PU]),'glBindTexture':(None,[U,U]),'glTexImage2D':(None,[U,I,I,I,I,I,U,U,P]),
 'glTexParameteri':(None,[U,U,I]),'glGenFramebuffers':(None,[I,PU]),'glBindFramebuffer':(None,[U,U]),
 'glFramebufferTexture2D':(None,[U,U,U,U,I]),'glDrawBuffers':(None,[I,PU]),'glReadBuffer':(None,[U]),
 'glCheckFramebufferStatus':(U,[U]),'glGetUniformLocation':(I,[U,c.c_char_p]),
 'glUniformMatrix4fv':(None,[I,I,B,PF]),'glUniform1i':(None,[I,I]),'glUniform1f':(None,[I,F]),
 'glUniform3f':(None,[I,F,F,F]),'glEnableVertexAttribArray':(None,[U]),'glVertexAttribPointer':(None,[U,I,U,B,I,P]),
 'glDrawArrays':(None,[U,I,I]),'glEnable':(None,[U]),'glDisable':(None,[U]),'glViewport':(None,[I,I,I,I]),
 'glClear':(None,[U]),'glClearColor':(None,[F,F,F,F]),'glDepthMask':(None,[B]),'glDepthFunc':(None,[U]),
 'glPolygonOffset':(None,[F,F]),'glActiveTexture':(None,[U]),'glBlendFunc':(None,[U,U]),
 'glFrontFace':(None,[U]),'glReadPixels':(None,[I,I,I,I,U,U,P]),'glFinish':(None,[]),'glGetError':(U,[]),
 'glGenVertexArrays':(None,[I,PU]),'glBindVertexArray':(None,[U]),'glDrawElements':(None,[U,I,U,P]),
 'glGenRenderbuffers':(None,[I,PU]),'glBindRenderbuffer':(None,[U,U]),'glRenderbufferStorage':(None,[U,U,I,I]),
 'glFramebufferRenderbuffer':(None,[U,U,U,U]),'glBlitFramebuffer':(None,[I,I,I,I,I,I,I,I,U,U]),'glScissor':(None,[I,I,I,I]),
}
for name,(result,args) in specs.items():globals()[name]=proc(name,result,args)
print('GLES:',glGetString(0x1F02).decode(),'renderer:',glGetString(0x1F01).decode(),flush=True)
root=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
optimized=json.loads((root/'optimized.json').read_text()) if (root/'optimized.json').is_file() else None
probe_frames={f['name']:f for f in optimized['frames']} if optimized else {}
shader_root=next((Path(a) for a in sys.argv[3:] if not a.startswith('--')),root)
auto_scale=next((float(a.split('=')[1]) for a in sys.argv[3:] if a.startswith('--auto=')),None)
def shader(kind,name):
    s=glCreateShader(kind);source=(shader_root/name).read_bytes();sources=(c.c_char_p*1)(source)
    glShaderSource(s,1,sources,None);glCompileShader(s);ok=I();glGetShaderiv(s,0x8B81,c.byref(ok))
    if not ok.value:
        log=c.create_string_buffer(16000);glGetShaderInfoLog(s,len(log),None,log);raise RuntimeError(log.value.decode())
    return s
def program(vertex,fragment):
    p=glCreateProgram();glAttachShader(p,shader(0x8B31,vertex));glAttachShader(p,shader(0x8B30,fragment));glLinkProgram(p)
    ok=I();glGetProgramiv(p,0x8B82,c.byref(ok))
    if not ok.value:
        log=c.create_string_buffer(16000);glGetProgramInfoLog(p,len(log),None,log);raise RuntimeError(log.value.decode())
    return p
main=program('scene.vert','scene.frag');depth=program('depth.vert','depth.frag')
def upload(path):
    if optimized:
        name=path.stem;meta=optimized['meshes'][name]
        data=np.fromfile(root/(name+'.vbo'),dtype=np.uint8)
        indices=np.fromfile(root/(name+'.ibo'),dtype=np.uint32)
        vao=U();glGenVertexArrays(1,c.byref(vao));glBindVertexArray(vao)
        handle=U();glGenBuffers(1,c.byref(handle));glBindBuffer(0x8892,handle)
        glBufferData(0x8892,data.nbytes,data.ctypes.data_as(P),0x88E4)
        ebo=U();glGenBuffers(1,c.byref(ebo));glBindBuffer(0x8893,ebo)
        glBufferData(0x8893,indices.nbytes,indices.ctypes.data_as(P),0x88E4)
        for i,(num,kind,norm,offset) in enumerate([(3,0x1406,0,0),(3,0x1402,1,12),(3,0x1401,1,18),(2,0x1406,0,24),(1,0x1401,0,21)]):
            glEnableVertexAttribArray(i);glVertexAttribPointer(i,num,kind,norm,32,P(offset))
        glBindVertexArray(0)
        assert len(indices)==meta['count'] and data.nbytes+indices.nbytes==meta['gpuBytes']
        return handle.value,len(indices),ebo.value,vao.value
    data=np.fromfile(path,dtype=np.float32)
    assert len(data)%36==0 and np.isfinite(data).all(),path
    handle=U();glGenBuffers(1,c.byref(handle));glBindBuffer(0x8892,handle)
    glBufferData(0x8892,data.nbytes,data.ctypes.data_as(P),0x88E4)
    return handle.value,len(data)//12
world_names={s['world'] for s in json.loads((root/'frames.json').read_text())}
worlds={name:upload(root/(name+'.bin')) for name in world_names}
objects=[upload(root/f'object_{i}.bin') for i in range(len(list(root.glob('object_*.'+('vbo' if optimized else 'bin')))))]
opaque_objects={i for i in range(len(objects)) if not optimized['meshes'][f'object_{i}']['transparent']} if optimized else {i for i in range(len(objects)) if not np.isin(np.fromfile(root/f'object_{i}.bin',dtype=np.float32)[11::12],[11,12,17]).any()}
shadow_objects={i for i in opaque_objects if optimized['meshes'][f'object_{i}']['shadow']} if optimized else {i for i in opaque_objects if not np.isin(np.fromfile(root/f'object_{i}.bin',dtype=np.float32)[11::12],[18]).all()}
print('Triangle counts:',{k:v[1]//3 for k,v in worlds.items()},'car:',[m[1]//3 for m in objects[:4]],flush=True)
tex=U();glGenTextures(1,c.byref(tex));glBindTexture(0x0DE1,tex)
shadow_size=768 if auto_scale is not None else 1536
glTexImage2D(0x0DE1,0,0x81A6,shadow_size,shadow_size,0,0x1902,0x1405,None)
for name,value in [(0x2801,0x2600),(0x2800,0x2600),(0x2802,0x812F),(0x2803,0x812F)]:glTexParameteri(0x0DE1,name,value)
fbo=U();glGenFramebuffers(1,c.byref(fbo));glBindFramebuffer(0x8D40,fbo)
glFramebufferTexture2D(0x8D40,0x8D00,0x0DE1,tex,0);glDrawBuffers(1,(U*1)(0));glReadBuffer(0)
assert glCheckFramebufferStatus(0x8D40)==0x8CD5,'Incomplete depth framebuffer'
scene_fbo=0
if auto_scale is not None:
    color=U();glGenTextures(1,c.byref(color));glBindTexture(0x0DE1,color)
    glTexImage2D(0x0DE1,0,0x8058,width,height,0,0x1908,0x1401,None)
    for name in (0x2801,0x2800):glTexParameteri(0x0DE1,name,0x2601)
    rb=U();glGenRenderbuffers(1,c.byref(rb));glBindRenderbuffer(0x8D41,rb)
    glRenderbufferStorage(0x8D41,0x81A6,width,height)
    target=U();glGenFramebuffers(1,c.byref(target));glBindFramebuffer(0x8D40,target)
    glFramebufferTexture2D(0x8D40,0x8CE0,0x0DE1,color,0)
    glFramebufferRenderbuffer(0x8D40,0x8D00,0x8D41,rb)
    assert glCheckFramebufferStatus(0x8D40)==0x8CD5,'Incomplete adaptive framebuffer'
    scene_fbo=target.value
def mat(p,name,data):
    flat=np.asarray(data,dtype=np.float32).flatten(order='F')
    glUniformMatrix4fv(glGetUniformLocation(p,name.encode()),1,0,flat.ctypes.data_as(PF))
def vec(p,name,data):glUniform3f(glGetUniformLocation(p,name.encode()),*map(float,data))
def scalar(p,name,v):glUniform1f(glGetUniformLocation(p,name.encode()),v)
def normalize(v):
    a=np.asarray(v,dtype=np.float64);return a/np.linalg.norm(a)
def lookat(eye,target,up):
    f=normalize(np.asarray(target)-eye);s=normalize(np.cross(f,up));u=np.cross(s,f)
    m=np.eye(4);m[0,:3]=s;m[1,:3]=u;m[2,:3]=-f
    m[:3,3]=[-np.dot(s,eye),-np.dot(u,eye),np.dot(f,eye)];return m
def perspective(fov,aspect,near,far):
    f=1/math.tan(math.radians(fov)/2);m=np.zeros((4,4))
    m[0,0]=f/aspect;m[1,1]=f;m[2,2]=(far+near)/(near-far);m[2,3]=2*far*near/(near-far);m[3,2]=-1;return m
def ortho(span):
    m=np.eye(4);m[0,0]=m[1,1]=1/span;m[2,2]=-2/649;m[2,3]=-651/649;return m
def draw(mesh,program,model,depth_only=False,first=0,count=None):
    if optimized:
        handle,total,ebo,vao=mesh;mat(program,'uModel',model);glBindVertexArray(vao)
        glDrawElements(0x0004,total if count is None else count,0x1405,P(first*4));return
    handle,count=mesh;mat(program,'uModel',model);glBindBuffer(0x8892,handle)
    for i,(num,offset) in enumerate([(3,0),(3,12),(3,24),(2,36),(1,44)]):
        if depth_only and i>0:break
        glEnableVertexAttribArray(i);glVertexAttribPointer(i,num,0x1406,0,48,P(offset))
    glDrawArrays(0x0004,0,count)
def draw_world(shot,program,visibility,depth_only=False):
    if not optimized:draw(worlds[shot['world']],program,np.eye(4),depth_only);return
    ranges=optimized['meshes'][shot['world']]['ranges']
    for i in probe_frames[shot['name']][visibility]:
        r=ranges[i];draw(worlds[shot['world']],program,np.eye(4),depth_only,r['first'],r['count'])
for shot in json.loads((root/'frames.json').read_text()):
    d=np.array(shot['frame']);showroom=shot['showroom'];night=shot['night'];eye=d[:3];focus=d[10:13]
    projection=perspective(40 if showroom else 50,width/height,.1 if showroom else .18,2600)
    if not showroom:projection[0,0]*=-1
    glFrontFace(0x0901 if showroom else 0x0900)
    view=lookat(eye,d[3:6],d[6:9]);vp=projection@view
    light=np.array([-.455,.827,-.331]);lightvp=ortho(9 if showroom else 105)@lookat(focus+light*230,focus,[0,1,0])
    instances=[]
    for i in range(int(d[14])):
        offset=15+i*17;instances.append((int(d[offset]),d[offset+1:offset+17].reshape((4,4),order='F')))
    glEnable(0x0B71);glDepthFunc(0x0203);glDisable(0x0B44);glDisable(0x0BE2);glDepthMask(1)
    glBindFramebuffer(0x8D40,fbo);glViewport(0,0,shadow_size,shadow_size);glClear(0x00000100)
    glEnable(0x8037);glPolygonOffset(1.3,2);glUseProgram(depth);mat(depth,'uLightVP',lightvp)
    draw_world(shot,depth,'shadowWorld',True)
    for j,(index,model) in enumerate(instances):
        if optimized and j not in probe_frames[shot['name']]['shadowInstances']:continue
        if index in shadow_objects:draw(objects[index],depth,model,True)
    rw=int(width*(auto_scale or 1));rh=int(height*(auto_scale or 1))
    glDisable(0x8037);glBindFramebuffer(0x8D40,scene_fbo);glViewport(0,0,rw,rh)
    glEnable(0x0C11);glScissor(0,0,rw,rh)
    glClearColor(*([.046,.078,.125,1] if showroom else [.10,.15,.26,1] if night else [.43,.55,.64,1]))
    glClear(0x4000|0x0100);glDisable(0x0C11);glUseProgram(main);mat(main,'uVP',vp);mat(main,'uLightVP',lightvp)
    vec(main,'uCamera',eye);vec(main,'uLight',light);vec(main,'uSunColor',[.62,.76,1.10] if night else [1.08,.98,.84])
    vec(main,'uSky',[.17,.26,.47] if night else [.49,.65,.77]);scalar(main,'uTime',d[9]);scalar(main,'uNight',float(night))
    scalar(main,'uShadowTexel',1/shadow_size);glActiveTexture(0x84C0);glBindTexture(0x0DE1,tex)
    scalar(main,'uShadowQuality',2 if auto_scale is None else 0 if auto_scale<.6 else 1)
    glUniform1i(glGetUniformLocation(main,b'uDepth'),0);draw_world(shot,main,'visibleWorld')
    for p in range(2):
        if p==1:glEnable(0x0BE2);glBlendFunc(0x0302,0x0303);glDepthMask(0)
        for j,(index,model) in enumerate(instances):
            if optimized and j not in probe_frames[shot['name']]['visibleInstances']:continue
            if ((index not in opaque_objects) != (p==1)):continue
            draw(objects[index],main,model)
    glDepthMask(1);glDisable(0x0BE2)
    if auto_scale is not None:
        glBindFramebuffer(0x8CA8,scene_fbo);glBindFramebuffer(0x8CA9,0)
        glBlitFramebuffer(0,0,rw,rh,0,0,width,height,0x4000,0x2601)
        glBindFramebuffer(0x8D40,0)
    glFinish()
    error=glGetError();assert error==0,hex(error)
    pixels=np.zeros((height,width,4),dtype=np.uint8)
    glReadPixels(0,0,width,height,0x1908,0x1401,pixels.ctypes.data_as(P))
    assert pixels[:,:,:3].std()>15,'Blank or uniform render'
    image=Image.fromarray(pixels[::-1,:,:3]).copy();image.save(out/(shot['name']+'.png'))
    print('Rendered',shot['name'],flush=True)
print('Both shader programs compiled; all frames rendered without GLES errors.',flush=True)
