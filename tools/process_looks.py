from pathlib import Path
import os
PROJECT_ROOT = Path(__file__).resolve().parents[1]
BATCH_DIR = Path(os.environ.get('LOOKPRINT_BATCH_DIR', str(PROJECT_ROOT / 'analysis' / 'batch')))
import subprocess,json,time,unicodedata
src=Path(os.environ['LOOKPRINT_VIDEO_DIR']).expanduser()
out=BATCH_DIR
out.mkdir(parents=True, exist_ok=True)
raw=out/'Por vídeo';raw.mkdir(exist_ok=True)
files=sorted((p for p in src.rglob('*') if p.suffix.lower() in ('.mov','.mp4','.m4v','.avi')),key=lambda p:str(p.relative_to(src)))
manifest=json.loads((out/'processamento.json').read_text()) if (out/'processamento.json').exists() else {'source':str(src),'videos':[str(p) for p in files],'results':[]}
done={r['source'] for r in manifest['results'] if r['status']=='ok'}
(out/'processamento.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
for n,p in enumerate(files,1):
 if str(p) in done:continue
 if getattr(p.stat(),'st_flags',0)&0x40000000:
  manifest['results'].append({'source':str(p),'status':'pendente-icloud','error':'Arquivo ainda somente no iCloud.'})
  (out/'processamento.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
  print('PENDENTE ICLOUD: '+p.name,flush=True)
  continue
 print(f'INÍCIO {n}/{len(files)}: {p.name}',flush=True)
 try:
  run=subprocess.run([str(PROJECT_ROOT / 'build' / 'look-cli'),str(raw),str(p)],capture_output=True,text=True,timeout=90)
 except subprocess.TimeoutExpired:
  manifest['results'].append({'source':str(p),'status':'erro','error':'Leitura excedeu 90 s; possível espera pelo iCloud.'})
  (out/'processamento.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
  print('TEMPO EXCEDIDO: '+p.name,flush=True)
  continue
 folders=[d for d in raw.iterdir() if d.is_dir() and (d/'extracao.json').exists() and json.loads((d/'extracao.json').read_text())['source']==str(p)]
 if run.returncode==0 and folders:
  folder=folders[-1];report=json.loads((folder/'extracao.json').read_text())
  # Full source filename preserves extension and distinguishes MOV/MP4 variants.
  prefix=unicodedata.normalize('NFC',p.name)
  if p.parent!=src:prefix=unicodedata.normalize('NFC',p.parent.name)+'__'+prefix
  for frame in report['frames']:
   new=prefix+'__'+frame['file'];(folder/frame['file']).rename(folder/new);frame['file']=new
  (folder/'extracao.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
  result={'source':str(p),'folder':str(folder),'count':len(report['frames']),'status':'ok'}
  print(f'OK {n}/{len(files)}: {p.name} — {result["count"]} prints',flush=True)
 else:
  result={'source':str(p),'status':'erro','error':run.stderr.strip()};print(f'ERRO: {result["error"]}',flush=True)
 manifest['results'].append(result)
 (out/'processamento.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
print('FINALIZADO',flush=True)
