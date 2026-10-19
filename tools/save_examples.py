from pathlib import Path
import shutil,json
src=Path(__file__).resolve().parents[1]/'analysis/release'
dest=Path.home()/'Downloads'/'LookPrint — 6 vídeos'
if dest.exists(): raise SystemExit('A pasta de destino já existe; não foi alterada.')
dest.mkdir()
for folder in sorted(src.iterdir()):
 if not folder.is_dir():continue
 r=json.loads((folder/'extracao.json').read_text());name=Path(r['source']).stem
 shutil.copytree(folder,dest/name)
(dest/'LEIA-ME.txt').write_text('46 prints extraídos dos seis vídeos de referência.\n\n49: 10\n120: 5\n125: 10\n139: 4\n152: 7\n122-mexido: 10\n\nJPGs em 1440 × 2560. Quadro inteiro preservado.\nCada combinação completa de acessórios é uma versão.\nPara extrair outros vídeos: botão direito no Finder → Extrair looks completos (pode aparecer dentro de Serviços).\n\nO detector foi ajustado para este formato de vídeo. Confira o resultado em edições diferentes.\n',encoding='utf-8')
print(dest)
