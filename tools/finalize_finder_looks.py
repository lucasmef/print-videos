from pathlib import Path
import os
PROJECT_ROOT = Path(__file__).resolve().parents[1]
BATCH_DIR = Path(os.environ.get('LOOKPRINT_BATCH_DIR', str(PROJECT_ROOT / 'analysis' / 'batch')))
import json,subprocess,plistlib,unicodedata
stage=BATCH_DIR
flat=(PROJECT_ROOT / 'Prints dos vídeos');flat.mkdir(exist_ok=True)
tags={}
for line in (stage/'tags-visuais.txt').read_text().splitlines():
 if '|' in line:
  idx,colors,types=line.split('|');tags[int(idx)]=(colors.split(',') if colors else [],types.split(',') if types else [])
 elif '=' in line:
  idx,ref=line.split('=');tags[int(idx)]=tags[int(ref)]
colors={'azul':'Azul','azul-claro':'Azul','azul-marinho':'Azul','azul-royal':'Azul','azul-petróleo':'Azul','vinho':'Vinho','coral':'Laranja','prateado':'Prata','dourado':'Dourado','caramelo':'Caramelo','bege':'Bege','preto':'Preto','branco':'Branco','cinza':'Cinza','verde':'Verde','rosa':'Rosa','roxo':'Roxo','amarelo':'Amarelo','laranja':'Laranja','marrom':'Marrom','vermelho':'Vermelho'}
types={'blazer':'Blazer','calça':'Calças','bolsa':'Bolsas','scarpin':'Sapatos','sandália':'Sapatos','tênis':'Tênis','bota':'Sapatos','sapatilha':'Sapatos','short':'Shorts','saia':'Saias','vestido':'Vestidos','macacão':'Macacão','camisa':'Camisas','camiseta':'Blusas','blusa':'Blusas','regata':'Blusas','colete':'Colete','cardigan':'Tricot','suéter':'Tricot','moletom':'Casacos','jaqueta':'Jaquetas','terno':'Blazer','brincos':'Brincos','colar':'Colar','boné':'Boné','lenço':'Lenço','cachecol':'Cachecol','cinto':'Cintos','óculos':'Óculos','poá':'Estampados','listras':'Estampados','estampa-floral':'Estampados','animal-print':'Estampados','zebra':'Estampados','jeans':'Calças'}
items=json.loads((stage/'itens.json').read_text());rows=[]
for f in items:
 if f['id'] not in tags:continue
 src=Path(f['path']);dest=flat/src.name
 if not dest.exists():
  # Hard link keeps full quality without duplicating image data.
  import os;os.link(src,dest)
 c,t=tags[f['id']]
 if 'excluir' in t:
  dest.unlink(missing_ok=True)
  continue
 resolved=['videos']+list(dict.fromkeys([colors[x] for x in c if x in colors]+[types[x] for x in t if x in types]))
 rows.append({'path':str(dest),'tags':resolved})
manifest=stage/'tags-finder.json';manifest.write_text(json.dumps(rows,ensure_ascii=False,indent=2))
subprocess.run([str((PROJECT_ROOT / 'build' / 'apply-finder-tags')),str(manifest)],check=True)
print('Pasta única:',flat)
