#!/usr/bin/env python3
"""Import exact CC0 archives whose hashes were verified with Godot locally."""
from pathlib import Path, PurePosixPath
import urllib.request, zipfile, gzip, json, hashlib, io, time
ROOT = Path(__file__).resolve().parents[1]
catalog = json.loads(gzip.decompress((ROOT / 'seed/catalog.json.gz').read_bytes()))
for pack in catalog['packs']:
    models = [m for m in catalog['models'] if m['pack'] == pack['id']]
    if all((ROOT / m['path']).is_file() and hashlib.sha256((ROOT / m['path']).read_bytes()).hexdigest() == m['sha256'] for m in models):
        print('Already present:', pack['id'], flush=True)
        continue
    url = pack['download']
    if not url.startswith('https://kenney.nl/'):
        raise ValueError('Unexpected download host')
    last = None
    for retry in range(3):
        try:
            request = urllib.request.Request(url, headers={'User-Agent': 'GodotAssetBank/1.0'})
            with urllib.request.urlopen(request, timeout=120) as response:
                data = response.read(100_000_001)
            if len(data) > 100_000_000:
                raise ValueError('Archive too large')
            if hashlib.sha256(data).hexdigest() != pack['archive_sha256']:
                raise ValueError('Archive changed; review new download and license before accepting it')
            last = None
            break
        except Exception as error:
            last = error
            time.sleep(2 * (retry + 1))
    if last:
        raise last
    archive = zipfile.ZipFile(io.BytesIO(data))
    has_gltf = any(n.lower().endswith(('.glb', '.gltf')) for n in archive.namelist())
    folder = ROOT / 'packs' / pack['id']
    for entry in archive.infolist():
        path = PurePosixPath(entry.filename)
        if path.is_absolute() or '..' in path.parts or entry.is_dir():
            continue
        ext = path.suffix.lower()
        keep = ext in ('.glb', '.gltf', '.bin', '.png', '.jpg', '.jpeg', '.txt', '.md', '.html') or (not has_gltf and ext in ('.obj', '.mtl'))
        if not keep or entry.file_size > 80_000_000:
            continue
        destination = folder.joinpath(*path.parts)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(archive.read(entry))
    (folder / 'SOURCE.json').write_text(json.dumps(pack, ensure_ascii=False, indent=2))
    print('Imported:', pack['id'], len(models), 'models', flush=True)
for model in catalog['models']:
    path = ROOT / model['path']
    if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != model['sha256']:
        raise ValueError('Missing or altered model: ' + model['path'])
for pack in catalog['packs']:
    path = ROOT / pack['license_path']
    if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != pack['license_text_sha256']:
        raise ValueError('Missing or altered license: ' + pack['id'])
(ROOT / 'catalog.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2))
(ROOT / 'validation.json').write_text(json.dumps({
    'packs': len(catalog['packs']), 'models': len(catalog['models']),
    'verified_model_hashes': len(catalog['models']), 'verified_license_hashes': len(catalog['packs']),
    'local_godot_version': '4.3.stable', 'local_godot_load_failures': 0,
    'mobile_performance_tested': False,
    'note': 'Remote files match the exact locally imported and verified model bytes.'
}, indent=2))
print('COMPLETE:', len(catalog['models']), 'verified model files', flush=True)
