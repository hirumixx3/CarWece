#!/usr/bin/env python3
"""Generate the renderer's camera/light matrices for the pure Kotlin geometry QA."""
import json, math, sys
from pathlib import Path
import numpy as np

root=Path(sys.argv[1])
def unit(v):
 v=np.asarray(v,dtype=np.float64);return v/np.linalg.norm(v)
def look(eye,target,up):
 f=unit(np.asarray(target)-eye);s=unit(np.cross(f,up));u=np.cross(s,f)
 m=np.eye(4);m[0,:3]=s;m[1,:3]=u;m[2,:3]=-f
 m[:3,3]=[-np.dot(s,eye),-np.dot(u,eye),np.dot(f,eye)];return m
def values(m):return ','.join(map(str,np.asarray(m,dtype=np.float32).flatten(order='F')))
lines=[]
for shot in json.loads((root/'frames.json').read_text()):
 d=np.asarray(shot['frame']);eye=d[:3];focus=d[10:13];showroom=shot['showroom']
 near=.1 if showroom else .18;far=2600;f=1/math.tan(math.radians(40 if showroom else 50)/2)
 p=np.zeros((4,4));p[0,0]=f/(1280/720)*(1 if showroom else -1);p[1,1]=f
 p[2,2]=(far+near)/(near-far);p[2,3]=2*far*near/(near-far);p[3,2]=-1
 vp=p@look(eye,d[3:6],d[6:9])
 span=9 if showroom else 105;l=np.eye(4);l[0,0]=l[1,1]=1/span;l[2,2]=-2/649;l[2,3]=-651/649
 light=l@look(focus+np.array([-.455,.827,-.331])*230,focus,[0,1,0])
 fields=[shot['name'],shot['world'],values(vp),values(light)]
 for i in range(int(d[14])):
  at=15+i*17;fields.append(str(int(d[at]))+','+','.join(map(str,d[at+1:at+17])))
 lines.append('|'.join(fields))
(root/'probe_frames.txt').write_text('\n'.join(lines))
print('Prepared',len(lines),'camera/light visibility probes')
