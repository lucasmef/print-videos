from pathlib import Path
import os
PROJECT_ROOT = Path(__file__).resolve().parents[1]
BATCH_DIR = Path(os.environ.get('LOOKPRINT_BATCH_DIR', str(PROJECT_ROOT / 'analysis' / 'batch')))
from PIL import Image,ImageDraw
import json
out=BATCH_DIR
frames=[]
for folder in sorted((out/'Por vídeo').iterdir()):
 rp=folder/'extracao.json'
 if not rp.exists():continue
 r=json.loads(rp.read_text())
 for f in r['frames']:frames.append({'path':str(folder/f['file']),'video':Path(r['source']).name,'seconds':f['seconds']})
# Persistent identities across incremental sheets.
idfile=out/'itens.json';existing=json.loads(idfile.read_text()) if idfile.exists() else []
known={f['path'] for f in existing}
for f in frames:
 if f['path'] not in known:f['id']=len(existing)+1;existing.append(f);known.add(f['path'])
idfile.write_text(json.dumps(existing,ensure_ascii=False,indent=2))
review=out/'Revisão';review.mkdir(exist_ok=True)
for off in range(0,len(existing),36):
 batch=existing[off:off+36];sheet=Image.new('RGB',(6*220,6*400),'#eee');d=ImageDraw.Draw(sheet)
 for i,f in enumerate(batch):
  im=Image.open(f['path']);im.thumbnail((216,366));x=i%6*220;y=i//6*400
  sheet.paste(im,(x+(220-im.width)//2,y));d.text((x+3,y+369),f'{f["id"]} | {f["video"][:24]}',fill='black');d.text((x+3,y+384),f'{f["seconds"]:.2f}s',fill='black')
 sheet.save(review/f'prancha-{off//36+1:03}.jpg')
print(len(existing),'prints;',len(existing)//36+1,'pranchas')
