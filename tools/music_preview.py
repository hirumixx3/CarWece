#!/usr/bin/env python3
"""Compose exact Flutter widget captures; no gameplay or audio is simulated as proof."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
root=Path(__file__).resolve().parent.parent
out=root/'previews/music_v0101';out.mkdir(exist_ok=True)
font=root/'assets/fonts/Body.ttf';head=root/'assets/fonts/Display.ttf'
def f(size,bold=False):return ImageFont.truetype(str(head if bold else font),size)
im=Image.new('RGB',(1800,1230),'#0b1320');d=ImageDraw.Draw(im)
d.text((30,16),'CARWECE 0.10.1',font=f(52,True),fill='#f4ead9')
d.text((378,39),'SUA TRILHA NA CORRIDA',font=f(27),fill='#73d9d4')
d.text((32,96),'Menu: Legends Never Die em repetição · Corridas: outras 19 músicas, offline',font=f(25),fill='#f2ba80')
large=Image.open(out/'playlist_1280.png').convert('RGB');large.thumbnail((1380,777),Image.Resampling.LANCZOS)
im.paste(large,((1800-large.width)//2,144))
d.text((34,956),'PAUSA / MÚSICAS',font=f(32,True),fill='#73d9d4')
for y,text in [(1006,'Escolha uma faixa, pule, alterne o modo aleatório e ajuste o volume.'),(1044,'A música pode tocar enquanto o carro permanece pausado.'),(1082,'Feche o painel e toque CONTINUAR para retomar a corrida.')]:d.text((34,y),text,font=f(25),fill='#ece3d4')
d.text((34,1160),'Interface capturada em teste de widgets. Fundo 3D e estado do áudio simulados no teste.',font=f(21),fill='#aabacb')
d.text((34,1190),'Não é uma captura de aparelho físico.',font=f(21),fill='#aabacb')
im.save(root/'previews/release_v0101.png')
print('Created release_v0101.png from the tested Flutter music panel.')
