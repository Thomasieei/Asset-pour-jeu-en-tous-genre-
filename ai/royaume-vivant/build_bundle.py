#!/usr/bin/env python3
"""Reproduce the actual validated local AI bundle without storing large blobs in Git."""
from pathlib import Path
import hashlib,json,shutil,subprocess,tarfile,urllib.request,zipfile
BASE=Path(__file__).resolve().parent
DIST=Path('dist');DIST.mkdir(exist_ok=True)
WORK=Path('.ai-build');WORK.mkdir(exist_ok=True)
BUNDLE=WORK/'Royaume-Vivant-IA-Locale';BUNDLE.mkdir(exist_ok=True)
PROOF=json.loads((BASE/'tests/build_manifest.json').read_text())
def digest(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def download(url,path,expected):
    if not path.exists():
        print('Downloading',path.name,flush=True)
        with urllib.request.urlopen(url,timeout=90) as r,path.open('wb') as out:
            shutil.copyfileobj(r,out,1024*1024)
    if digest(path)!=expected:raise RuntimeError('SHA-256 mismatch: '+path.name)
source=WORK/'Qwen3-0.6B-Q8_0.gguf'
download(PROOF['model']['source'],source,PROOF['model']['sha256'])
runtime_archive=WORK/'llama-b11598-bin-ubuntu-x64.tar.gz'
RUNTIME_SHA='187e55b3b056e3e98f549f46541b76323192d62361d25f1c94926c6125df0c89'
download('https://github.com/ggml-org/llama.cpp/releases/download/b11598/llama-b11598-bin-ubuntu-x64.tar.gz',runtime_archive,RUNTIME_SHA)
with tarfile.open(runtime_archive) as archive:archive.extractall(WORK/'runtime',filter='data')
runtime=WORK/'runtime/llama-b11598'
model=BUNDLE/PROOF['delivered_model']['file']
subprocess.run([str(runtime/'llama-quantize'),'--allow-requantize',str(source),str(model),'Q4_K_M'],check=True)
if digest(model)!=PROOF['delivered_model']['sha256']:raise RuntimeError('Requantized model differs from tested artifact')
for folder in ['licenses','tests']:
    shutil.copytree(BASE/folder,BUNDLE/folder,dirs_exist_ok=True)
for name in ['README.md','LICENSE','lancer_serveur.py']:shutil.copy(BASE/name,BUNDLE/name)
(BUNDLE/'runtime').mkdir(exist_ok=True)
shutil.copy(runtime/'llama-server',BUNDLE/'runtime/llama-server')
for f in runtime.glob('*.so*'):shutil.copy(f,BUNDLE/'runtime'/f.name)
output=DIST/'Royaume-Vivant-IA-Locale.zip'
with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED,compresslevel=1) as z:
    for f in sorted(BUNDLE.rglob('*')):
        if f.is_file():z.write(f,f.relative_to(WORK))
(DIST/'SHA256SUMS.txt').write_text(digest(output)+'  '+output.name+'\n'+digest(model)+'  '+model.name+'\n')
print('Published bundle ready:',output,output.stat().st_size,flush=True)
