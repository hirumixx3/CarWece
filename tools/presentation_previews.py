#!/usr/bin/env python3
"""Contact sheets from unaltered GLES renders and maps from actual road vertices."""
import json,math,bisect
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
root=Path(__file__).resolve().parent.parent
out=root/'previews';out.mkdir(exist_ok=True)
font=root/'assets/fonts/Body.ttf';head=root/'assets/fonts/Display.ttf'
def f(size,bold=False):return ImageFont.truetype(str(head if bold else font),size)
tracks=json.loads((root/'gpu_qa_v09/circuits.json').read_text())
h=185+math.ceil(len(tracks)/3)*365
im=Image.new('RGB',(1800,h),'#0b1320');d=ImageDraw.Draw(im)
d.text((40,20),'CARWECE 0.9',font=f(54,True),fill='#f3e7d2')
d.text((390,42),'26 CIRCUITOS · 13 LOOPS VERTICAIS',font=f(27),fill='#71ded2')
d.text((43,106),'Laranja: plástico · Azul: chão · Verde: atalho · Vermelho: portão · L: loop',font=f(22),fill='#b4c0ce')
for i,t in enumerate(tracks):
 x=35+(i%3)*590;y=165+(i//3)*365
 d.rounded_rectangle((x,y,x+565,y+342),radius=16,fill='#172439')
 d.text((x+19,y+14),t['room'],font=f(17),fill='#78ded3');d.text((x+19,y+39),t['name'],font=f(26,True),fill='#eee5d6')
 pts=t['points'];cx=(min(p[0] for p in pts)+max(p[0] for p in pts))/2;cz=(min(p[2] for p in pts)+max(p[2] for p in pts))/2
 scale=min(510/(max(p[0] for p in pts)-min(p[0] for p in pts)),215/(max(p[2] for p in pts)-min(p[2] for p in pts)))
 def point(p):return (x+282+(p[0]-cx)*scale,y+187+(p[2]-cz)*scale)
 for j,p in enumerate(pts):
  q=pts[(j+1)%len(pts)];d.line([point(p),point(q)],fill='#fb8d43' if (p[1]+q[1])*.5>=.38 else '#64cbd0',width=3)
 for s in t['shortcuts']:
  d.line([point(p) for p in s['points']],fill='#a8e779',width=4);gx,gy=point(s['gate']);d.ellipse((gx-5,gy-5,gx+5,gy+5),fill='#ff6b64')
 dist=[0.0]
 for a,b in zip(pts,pts[1:]):dist.append(dist[-1]+math.dist(a,b))
 for n,loop in enumerate(t.get('loops',[]),1):
  a=pts[min(len(pts)-1,bisect.bisect_left(dist,loop['start']))];b=pts[min(len(pts)-1,bisect.bisect_left(dist,loop['end']))]
  px,py=point([(a[0]+b[0])/2,0,(a[2]+b[2])/2]);d.ellipse((px-10,py-10,px+10,py+10),outline='#e39bff',width=2);d.text((px+12,py-11),f'L{n}',font=f(15),fill='#ecc7ff')
 sx,sy=point(pts[0]);d.ellipse((sx-4,sy-4,sx+4,sy+4),fill='white')
 d.text((x+19,y+307),f"{t['stars']} estrelas · {len(t.get('loops',[]))} loop(s) · {len(t['shortcuts'])} atalho",font=f(17),fill='#b6c5d5')
im.save(out/'circuits_v09.png')
im=Image.new('RGB',(1800,1820),'#0b1320');d=ImageDraw.Draw(im)
d.text((25,14),'CARWECE 0.9',font=f(47,True),fill='#f3e7d2')
d.text((355,31),'31 CARROS · 26 PISTAS · 13 PODERES',font=f(28),fill='#73d9d4')
d.text((27,91),'15 CARROS NOVOS',font=f(27,True),fill='#f7a35d')
def shot(name,label,x,y,w,h):
 img=Image.open(root/'previews/gpu_v09'/f'{name}.png').convert('RGB');img.thumbnail((w-8,h-29),Image.Resampling.LANCZOS)
 im.paste(img,(x+4+(w-8-img.width)//2,y+(h-29-img.height)//2))
 d.rectangle((x+4,y+h-30,x+w-4,y+h-3),fill='#172439');d.text((x+13,y+h-26),label,font=f(17),fill='#eee5d6')
names=['AE86 TRUENO','MAZDA RX-8','HONDA S2000','NISSAN 370Z','GR SUPRA A90','GR YARIS','ECLIPSE GSX','BMW M3 E30','AUDI R8 V10','AMG GT R','CORVETTE C7 Z06','VIPER GTS','FORD GT 2005','MCLAREN 720S','ZONDA F']
for i,label in enumerate(names):shot(f'car_{i+17}',label,(i%5)*360,128+(i//5)*226,360,224)
d.text((27,818),'8 PISTAS NOVAS · UM OU DOIS LOOPS',font=f(27,True),fill='#f7a35d')
for i,t in enumerate(tracks[18:]):shot(t['id']+'_loop_1',f"{t['name']} · {len(t['loops'])} LOOP(S)",(i%4)*450,860+(i//4)*278,450,276)
d.text((27,1430),'4 PODERES NOVOS',font=f(27,True),fill='#f7a35d')
for i,(name,label) in enumerate([('grenade','GRANADA'),('shockwave','ONDA DE IMPACTO'),('spikes','ESPINHOS'),('repair','REPARO')]):shot('power_'+name,label,i*450,1470,450,276)
d.text((27,1771),'Cenas do motor GLES e da geometria do jogo. Não são capturas de celular físico.',font=f(21),fill='#b4c0ce')
im.save(out/'release_v09.png')
print('Created circuits_v09.png and release_v09.png from actual GLES renders/geometry.')
