#!/usr/bin/env python3
"""Reproduce reviewed packs; accept only the catalog's exact file hashes."""
from pathlib import Path, PurePosixPath
import urllib.request,zipfile,gzip,json,hashlib,io,time
ROOT=Path(__file__).resolve().parents[1]
def digest(data): return hashlib.sha256(data).hexdigest()
def valid(f):
    path=ROOT/f['path']
    return path.is_file() and digest(path.read_bytes())==f['sha256']
def populate():
    catalog=json.loads(gzip.decompress((ROOT/'seed/catalog.json.gz').read_bytes()))
    for pack in catalog['packs']:
        expected=pack.get('files') or [m for m in catalog['models'] if m['pack']==pack['id']]+[{'path':pack['license_path'],'sha256':pack['license_text_sha256']}]
        if all(valid(f) for f in expected):
            print('Verified existing:',pack['id'],flush=True);continue
        if pack.get('embedded_parts'):
            data=b''.join((ROOT/p).read_bytes() for p in pack['embedded_parts'])
        elif pack.get('embedded_archive'):
            data=(ROOT/pack['embedded_archive']).read_bytes()
        else:
            url=pack['download']
            if not url.startswith(('https://kenney.nl/','https://codeload.github.com/KayKit-Game-Assets/')):raise ValueError('Unapproved source host')
            for attempt in range(3):
                try:
                    with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'AssetBank/2.0'}),timeout=120) as response:data=response.read(100_000_001)
                    break
                except Exception:
                    if attempt==2:raise
                    time.sleep(2*(attempt+1))
        if len(data)>100_000_000 or digest(data)!=pack['archive_sha256']:raise ValueError('Archive changed: '+pack['id'])
        folder=ROOT/'packs'/pack['id'];wanted={str(Path(f['path']).relative_to(Path('packs')/pack['id'])) for f in expected}
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            for entry in z.infolist():
                path=PurePosixPath(entry.filename)
                if entry.is_dir() or path.is_absolute() or '..' in path.parts:continue
                if pack.get('strip_archive_root'):path=PurePosixPath(*path.parts[1:])
                # Old seed lists models only: preserve their textures and original license too.
                keep=str(path) in wanted if pack.get('files') else path.suffix.lower() in ('.glb','.gltf','.bin','.png','.jpg','.jpeg','.txt','.md','.html')
                if not keep:continue
                target=folder.joinpath(*path.parts);target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(z.read(entry))
        if not all(valid(f) for f in expected):raise ValueError('Missing/altered extracted dependency: '+pack['id'])
        (folder/'SOURCE.json').write_text(json.dumps(pack,ensure_ascii=False,indent=2))
        print('Imported:',pack['id'],flush=True)
    for f in catalog['models']+catalog['assets']:
        if not valid(f):raise ValueError('Missing/altered resource: '+f['path'])
    for pack in catalog['packs']:
        for f in pack.get('files',[])+[{'path':pack['license_path'],'sha256':pack['license_text_sha256']}]:
            if not valid(f):raise ValueError('Missing/altered file: '+f['path'])
    with zipfile.ZipFile(ROOT/'seed/quality-previews.zip') as z:
        for entry in z.infolist():
            p=PurePosixPath(entry.filename)
            if not entry.is_dir() and p.parts[0]=='quality' and '..' not in p.parts:
                target=ROOT.joinpath(*p.parts);target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(z.read(entry))
    (ROOT/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2))
    (ROOT/'validation.json').write_text(json.dumps({'packs':len(catalog['packs']),'models':len(catalog['models']),'new_media_assets':len(catalog['assets']),'verified_model_hashes':len(catalog['models']),'verified_license_hashes':len(catalog['packs']),'local_godot_version':'4.3.stable','local_godot_load_failures':0,'mobile_performance_tested':False,'note':'Exact locally imported bytes; quality/report.json documents visual review scope.'},indent=2))
    print('COMPLETE',len(catalog['packs']),'packs',len(catalog['models']),'3D resources',flush=True)
if __name__=='__main__':populate()
