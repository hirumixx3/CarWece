from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont,ImageOps

root=Path(__file__).resolve().parent.parent
renders=root/'previews/v012_gles'
out=root/'previews';out.mkdir(exist_ok=True)
fontroot=Path('/usr/share/fonts/truetype/dejavu')
def font(size,bold=False):return ImageFont.truetype(str(fontroot/('DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf')),size)
canvas=Image.new('RGB',(1920,2130),'#101c2b');d=ImageDraw.Draw(canvas)
d.text((46,30),'CARWECE 0.12',font=font(58,True),fill='#fff0d3')
d.text((48,108),'44 equipamentos próprios · mira contínua · colisão nas laterais',font=font(25),fill='#73dce0')
d.text((48,151),'Poderes só por coleta no mapa. Munição limitada em Batalha e Explorar.',font=font(23),fill='#c4cdd0')
weapons=[('machineGun','METRALHADORA'),('scatterMissiles','SALVA DE MÍSSEIS'),('whiteLightning','BOBINAS ELÉTRICAS'),
 ('quantumAnnihilator','ANIQUILADOR QUÂNTICO'),('armorRepair','REPARO'),('radarJammer','BLOQUEADOR DE RADAR')]
for i,(name,label) in enumerate(weapons):
 x=40+(i%3)*630;y=210+(i//3)*340
 im=Image.open(renders/f'mount_{name}.png').convert('RGB').crop((330,170,990,650))
 canvas.paste(ImageOps.fit(im,(610,290)),(x,y))
 d.text((x+12,y+299),label,font=font(19,True),fill='#ffe0b6')
d.text((45,911),'PISTAS, RAMPAS E SALAS',font=font(33,True),fill='#fff0d3')
scenes=[('arena_1_ramp','RAMPAS FECHADAS E REFORÇADAS'),('arena_3_loop_1','JUNTAS E CONEXÕES NO PLÁSTICO'),
 ('arena_1_drive','MADEIRA, CAIXAS E ACABAMENTOS'),('arena_3_drive','CERÂMICA E REJUNTE'),
 ('arena_4_overview','COZINHA · ARENA ABERTA'),('arena_2_room','FERRAGENS E DETALHES NAS SALAS')]
for i,(name,label) in enumerate(scenes):
 x=40+(i%3)*630;y=975+(i//3)*370
 im=Image.open(renders/f'{name}.png').convert('RGB')
 canvas.paste(ImageOps.fit(im,(610,330)),(x,y))
 d.text((x+10,y+339),label,font=font(17,True),fill='#c5d8dc')
d.text((47,1752),'Sem encaixe automático pela lateral.',font=font(30,True),fill='#ffb273')
d.text((47,1801),'Suba pela entrada baixa da rampa ou pouse por cima. Pontes permitem passagem por baixo.',font=font(23),fill='#d5dce0')
d.text((47,1870),'31 CARROS   /   26 CIRCUITOS   /   6 ARENAS   /   20 MÚSICAS',font=font(28,True),fill='#75dce0')
d.text((47,1945),'Renderizações do motor GLES em Mesa, com cenas preparadas.',font=font(22),fill='#a5b8c6')
d.text((47,1983),'Não são capturas de celular. Ainda falta testar em aparelho Android físico.',font=font(22),fill='#a5b8c6')
canvas.save(out/'CarWece_v0.12_Preview.png',optimize=True)

catalog=json.loads((root/'verification/battle_catalog_v012.json').read_text())['weapons']
sheet=Image.new('RGB',(1920,2180),'#101c2b');draw=ImageDraw.Draw(sheet)
draw.text((34,25),'CARWECE · 44 EQUIPAMENTOS COLETÁVEIS',font=font(35,True),fill='#fff0d3')
draw.text((36,82),'Modelos do jogo renderizados em GLES/Mesa. Munição finita; inventário vazio na largada.',font=font(20),fill='#82dce0')
for i,w in enumerate(catalog):
 x=i%6*320;y=140+i//6*250
 im=Image.open(renders/f'mount_{w["id"]}.png').convert('RGB').crop((330,170,990,650))
 sheet.paste(ImageOps.fit(im,(312,218)),(x,y))
 draw.text((x+7,y+224),w['name'],font=font(13,True),fill='#eee4d0')
sheet.save(out/'CarWece_v0.12_Arsenal.png',optimize=True)
print('Created preview and all 44 equipment views.')
