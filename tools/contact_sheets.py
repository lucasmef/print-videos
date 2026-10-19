from PIL import Image, ImageOps, ImageDraw
from pathlib import Path
root=Path(__file__).resolve().parents[1]/'analysis'
for folder in root.iterdir():
    if not folder.is_dir(): continue
    files=sorted(folder.glob('*.jpg'))
    if not files: continue
    sheet=Image.new('RGB',(8*160, ((len(files)+7)//8)*300),'#eeeeee')
    d=ImageDraw.Draw(sheet)
    for i,p in enumerate(files):
        im=Image.open(p); im.thumbnail((156,272))
        x=(i%8)*160; y=(i//8)*300
        sheet.paste(im,(x+(160-im.width)//2,y))
        d.text((x+4,y+275),p.stem,fill='black')
    sheet.save(root/(folder.name+'.jpg'))
