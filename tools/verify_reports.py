"""Regression check of real-video extraction reports; no video-specific logic in the app."""
import json,sys
from pathlib import Path
from PIL import Image
expected={'49':10,'120':5,'125':10,'139':4,'152':7,'122-mexido':10}
root=Path(sys.argv[1]);seen=set();total=0
for p in sorted(root.glob('*/extracao.json')):
 r=json.loads(p.read_text());name=Path(r['source']).stem;seen.add(name)
 assert len(r['frames'])==expected[name],(name,len(r['frames']),expected[name])
 times=[f['seconds'] for f in r['frames']]
 assert times==sorted(set(times)) and all(0<=t<r['duration'] for t in times)
 for f in r['frames']:
  with Image.open(p.parent/f['file']) as im:
   assert im.size==(f['width'],f['height'])==(1440,2560)
   im.verify()
 total+=len(times)
 print(name,len(times),round(r['elapsedSeconds'],2),'s')
assert seen==set(expected),(seen,set(expected))
print('PASS:',total,'JPGs; counts, timestamps, dimensions and files verified.')
