#!/usr/bin/env python3
"""Compose actual GLES renders and separately labelled widget captures for review."""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont

root=Path(__file__).resolve().parent.parent
out=root/'previews/battle_v011';out.mkdir(parents=True,exist_ok=True)
catalog=json.loads((root/'verification/battle_catalog_v011.json').read_text())
def font(size,heading=False):
    return ImageFont.truetype(str(root/'assets/fonts'/('Display.ttf' if heading else 'Body.ttf')),size)
def paste(canvas,path,box):
    im=Image.open(path).convert('RGB');im.thumbnail((box[2],box[3]),Image.Resampling.LANCZOS)
    canvas.paste(im,(box[0]+(box[2]-im.width)//2,box[1]+(box[3]-im.height)//2))

im=Image.new('RGB',(1920,2190),'#0b1320');d=ImageDraw.Draw(im)
d.text((26,14),'CARWECE 0.11',font=font(58,True),fill='#ff9452')
d.text((370,30),'BATALHA / MUNDO ABERTO',font=font(42,True),fill='#f4ead7')
d.text((28,84),'6 arenas abertas  ·  9 loops  ·  44 poderes e variações  ·  100 de vida por carro',font=font(24),fill='#6ee0d0')
paste(im,out/'arenas_1280.png',(24,132,924,520))
paste(im,root/'previews/battle_gles/weapon_invasion.png',(972,132,924,520))
d.text((26,660),'SELEÇÃO DE ARENAS — interface em teste de widgets',font=font(21),fill='#c4d4dc')
d.text((974,660),'BATALHA — sondas, raios e vida no motor GLES',font=font(21),fill='#c4d4dc')
for i,a in enumerate(catalog['arenas']):
    x=24+(i%3)*632;y=716+(i//3)*400
    paste(im,root/f"previews/battle_gles/{a['id']}_overview.png",(x,y,608,342))
    d.text((x,y+349),f"{a['room']}  ·  {a['loops']} LOOP{'S' if a['loops']>1 else ''}",font=font(21,True),fill='#ffb273')
    d.text((x,y+376),a['name'],font=font(16),fill='#c4d4dc')
paste(im,root/'previews/battle_gles/weapon_discoInferno.png',(24,1524,924,520))
paste(im,root/'previews/battle_gles/weapon_jetBoosters.png',(972,1524,924,520))
d.text((26,2053),'GLOBO DO CAOS — flares disparados ao redor do carro',font=font(21),fill='#c4d4dc')
d.text((974,2053),'PROPULSORES — aceleração, colisão e efeito de jato',font=font(21),fill='#c4d4dc')
d.text((26,2113),'Vistas 3D do motor GLES com cenas preparadas para revisão. Menu capturado em teste de widgets.',font=font(20),fill='#93a6b5')
d.text((26,2150),'Não são capturas de celular físico. Desempenho e reprodução em aparelho ainda precisam ser testados.',font=font(20),fill='#93a6b5')
im.save(root/'previews/CarWece_v0.11_Batalha.png')

sheet=Image.new('RGB',(2560,1380),'#0b1320');draw=ImageDraw.Draw(sheet)
draw.text((18,10),'44 PODERES — REVISÃO DOS EFEITOS NO MOTOR GLES',font=font(35,True),fill='#f4ead7')
for i,w in enumerate(catalog['weapons']):
    x=(i%8)*320;y=66+(i//8)*216
    paste(sheet,root/f"previews/battle_gles/weapon_{w['id']}.png",(x,y,318,179))
    draw.text((x+5,y+182),w['name'],font=font(14),fill='#ffb273')
sheet.save(out/'powers_contact.png')
print('Created CarWece_v0.11_Batalha.png and internal powers contact sheet.')
