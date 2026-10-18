#!/usr/bin/env python3
"""Launch Godot and the pinned existing Qwen bundle (Linux x86_64)."""
import argparse
import hashlib
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / '.loic-runtime'
BUNDLE_SHA = '9c9828193722b3e17275df5222c85bef1c1bc3fe2f1bd92fa7716faca1319399'
MODEL_SHA = '15e434d8ddf0af38fe3f7003af6ce6eac4edada6df34324aa45979f9cc79f02e'
URL = 'https://github.com/Thomasieei/Asset-pour-jeu-en-tous-genre-/releases/download/royaume-vivant-ia-v1/Royaume-Vivant-IA-Locale.zip'


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024*1024), b''):
            h.update(chunk)
    return h.hexdigest()


def prepare():
    if platform.system() != 'Linux' or platform.machine() not in ('x86_64', 'AMD64'):
        raise RuntimeError('Le runtime livré exige Linux x86_64. Sur Windows/Android, utiliser --sans-ia ou un serveur compatible via LOIC_AI_ENDPOINT.')
    CACHE.mkdir(exist_ok=True)
    (CACHE / '.gdignore').touch()
    bundle = CACHE / 'Royaume-Vivant-IA-Locale'
    model = bundle / 'Qwen3-0.6B-Q4_K_M-requantized.gguf'
    if not model.exists() or not (bundle / 'runtime/llama-server').exists():
        archive = CACHE / 'bundle.zip'
        temporary = CACHE / 'bundle.part'
        print('Téléchargement du modèle local (~416 Mo), une seule fois…', flush=True)
        with urllib.request.urlopen(URL, timeout=120) as source, temporary.open('wb') as dest:
            shutil.copyfileobj(source, dest, 1024*1024)
        if digest(temporary) != BUNDLE_SHA:
            temporary.unlink()
            raise RuntimeError('Archive différente de la version vérifiée (SHA-256).')
        temporary.replace(archive)
        with zipfile.ZipFile(archive) as z:
            for name in z.namelist():
                if not (CACHE / name).resolve().is_relative_to(CACHE.resolve()):
                    raise RuntimeError('Chemin interdit dans le bundle.')
            z.extractall(CACHE)
    if digest(model) != MODEL_SHA:
        raise RuntimeError('Poids du modèle corrompus (SHA-256).')
    server = bundle / 'runtime/llama-server'
    server.chmod(server.stat().st_mode | 0o111)
    return bundle


def healthy(endpoint):
    try:
        # Any HTTP response confirms that an existing local listener owns the port.
        with urllib.request.urlopen(endpoint.rsplit('/v1/', 1)[0] + '/health', timeout=1) as response:
            return response.status == 200
    except (urllib.error.URLError, TimeoutError):
        return False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=shutil.which('godot') or shutil.which('godot4'))
    parser.add_argument('--sans-ia', action='store_true', help='Règles locales sans téléchargement')
    parser.add_argument('--preparer-ia', action='store_true', help='Télécharger et vérifier seulement')
    args = parser.parse_args()
    if args.preparer_ia:
        print(prepare())
        return 0
    if not args.godot:
        raise RuntimeError('Godot 4.3+ introuvable : préciser --godot /chemin/vers/Godot.')
    process = None
    endpoint = os.environ.get('LOIC_AI_ENDPOINT', 'http://127.0.0.1:8765/v1/chat/completions')
    try:
        if not args.sans_ia and not healthy(endpoint):
            if endpoint != 'http://127.0.0.1:8765/v1/chat/completions':
                raise RuntimeError('Serveur LOIC_AI_ENDPOINT indisponible.')
            bundle = prepare()
            env = os.environ.copy()
            env['LD_LIBRARY_PATH'] = str(bundle/'runtime') + ':' + env.get('LD_LIBRARY_PATH', '')
            process = subprocess.Popen([sys.executable, str(bundle/'lancer_serveur.py')], env=env, start_new_session=True)
            deadline = time.monotonic()+90
            while not healthy(endpoint):
                if process.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError('Le serveur IA ne démarre pas. Voir les messages llama.cpp.')
                time.sleep(0.25)
        env = os.environ.copy()
        if args.sans_ia:
            env['LOIC_DISABLE_AI'] = '1'
        return subprocess.call([args.godot, '--path', str(ROOT)], env=env)
    finally:
        if process and process.poll() is None:
            import signal
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(timeout=10)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (RuntimeError, OSError) as error:
        sys.exit(str(error))
