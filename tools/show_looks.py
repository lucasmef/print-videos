import json,sys
from pathlib import Path
import os
PROJECT_ROOT = Path(__file__).resolve().parents[1]
BATCH_DIR = Path(os.environ.get('LOOKPRINT_BATCH_DIR', str(PROJECT_ROOT / 'analysis' / 'batch')))
from PIL import Image,ImageDraw
p=BATCH_DIR;items=json.loads((p/'itens.json').read_text());a,b=map(int,sys.argv[1:]);items=[f for f in items if a<=f['id']<=b];n=len(items)
im=Image.new('RGB',(1320,400*((n+5)//6)),'#eee');d=ImageDraw.Draw(im)
for i,f in enumerate(items):
 pic=Image.open(f['path']);pic.thumbnail((216,366));x=i%6*220;y=i//6*400;im.paste(pic,(x+(220-pic.width)//2,y));d.text((x+3,y+369),f'{f["id"]} | {f["video"][:24]}',fill='black');d.text((x+3,y+384),f'{f["seconds"]:.2f}s',fill='black')
im.save('/tmp/looks-review.jpg')
