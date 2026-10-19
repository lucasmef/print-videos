from pathlib import Path
from PIL import Image,ImageDraw
import json
root=Path('analysis/release')
for folder in root.iterdir():
 if not folder.is_dir(): continue
 r=json.loads((folder/'extracao.json').read_text());fs=r['frames'];cols=min(10,len(fs));cellw=160;cellh=310
 sheet=Image.new('RGB',(cellw*cols,cellh*((len(fs)+cols-1)//cols)), '#f1f1ee');d=ImageDraw.Draw(sheet)
 for i,f in enumerate(fs):
  with Image.open(folder/f['file']) as im:
   im.thumbnail((156,280));x=i%cols*cellw;y=i//cols*cellh;sheet.paste(im,(x,y));d.text((x+4,y+285),f"{i+1:02d} | {f['seconds']:.2f}s",fill='black')
 sheet.save(Path('analysis')/(Path(r['source']).stem+'-final.jpg'))
