from PIL import Image,ImageDraw
from pathlib import Path
folder=Path('build/AppIcon.iconset');folder.mkdir(exist_ok=True)
im=Image.new('RGBA',(1024,1024));d=ImageDraw.Draw(im)
d.rounded_rectangle((48,48,976,976),radius=220,fill='#252b2b')
# Viewfinder corners framing a hanger.
for coords in [[(240,390),(240,240),(390,240)],[(634,240),(784,240),(784,390)],[(784,634),(784,784),(634,784)],[(390,784),(240,784),(240,634)]]:d.line(coords,fill='#e5ad91',width=32,joint='curve')
d.arc((449,323,565,439),180,450,fill='#f5eadc',width=25)
d.line([(509,429),(509,470),(320,613),(704,613),(509,470)],fill='#f5eadc',width=25,joint='curve')
for size in [16,32,128,256,512]:
 for scale in [1,2]:
  im.resize((size*scale,size*scale),Image.Resampling.LANCZOS).save(folder/f'icon_{size}x{size}{"@2x" if scale==2 else ""}.png')
