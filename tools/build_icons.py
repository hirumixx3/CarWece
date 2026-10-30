#!/usr/bin/env python3
"""Build CarWece launcher resources from the two approved original PNG layers."""
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
RES=ROOT/'android/app/src/main/res'
PREVIEW=ROOT/'previews/branding'
PREVIEW.mkdir(parents=True,exist_ok=True)
foreground=Image.open(ROOT/'branding/ic_launcher_foreground.png').convert('RGBA')
background=Image.open(ROOT/'branding/ic_launcher_background.png').convert('RGBA')
assert foreground.size==(1024,1024)
assert foreground.getchannel('A').getextrema()==(0,255)
assert background.getchannel('A').getextrema()==(255,255)
resize=lambda image,size:image.resize((size,size),Image.Resampling.LANCZOS)
# Legacy icons correspond to the central 72dp viewport of the 108dp layers.
composite=Image.alpha_composite(resize(background,1536),resize(foreground,1536))
viewport=composite.crop((256,256,1280,1280))
def masked(image,shape):
    image=image.copy();mask=Image.new('L',image.size,0);draw=ImageDraw.Draw(mask)
    bounds=(0,0,image.width-1,image.height-1)
    if shape=='circle':draw.ellipse(bounds,fill=255)
    else:draw.rounded_rectangle(bounds,radius=image.width*.22,fill=255)
    image.putalpha(ImageChops.multiply(image.getchannel('A'),mask))
    return image
for density,factor in [('mdpi',1),('hdpi',1.5),('xhdpi',2),('xxhdpi',3),('xxxhdpi',4)]:
    directory=RES/f'mipmap-{density}';directory.mkdir(parents=True,exist_ok=True)
    layer_size=round(108*factor);legacy_size=round(48*factor)
    resize(foreground,layer_size).save(directory/'ic_launcher_foreground.png')
    resize(background,layer_size).save(directory/'ic_launcher_background.png')
    resize(masked(viewport,'squircle'),legacy_size).save(directory/'ic_launcher.png')
    resize(masked(viewport,'circle'),legacy_size).save(directory/'ic_launcher_round.png')
    assert Image.open(directory/'ic_launcher_background.png').getchannel('A').getextrema()==(255,255)
adaptive=RES/'mipmap-anydpi-v26';adaptive.mkdir(parents=True,exist_ok=True)
xml='''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
'''
for name in ['ic_launcher.xml','ic_launcher_round.xml']:(adaptive/name).write_text(xml)
for shape in ['circle','squircle']:
    resize(masked(viewport,shape),1024).save(PREVIEW/f'carwece_{shape}.png')
print('Built adaptive layers at 108/162/216/324/432px, legacy icons and round variants.')
print('Preview: '+str(PREVIEW/'carwece_squircle.png'))
