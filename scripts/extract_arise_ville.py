#!/usr/bin/env python3
"""Extract compiled 3D assets (not original GLB files) from AriseVille APK.
Only processes Godot imported models, import remaps and their textures.
"""
import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path
SCENE = re.compile(r"assets/\\.godot/imported/(.+)\\.glb-[0-9a-f]{32}\\.scn$")
TEX = re.compile(r"assets/\\.godot/imported/(.+)\\.(?:png|jpg|jpeg)-[0-9a-f]{32}\\.ctex$")
def run(apk, out):
    out.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(apk) as z:
        entries = {item.filename: item for item in z.infolist() if not item.is_dir()}
        models = {m.group(1): path for path in entries if (m := SCENE.fullmatch(path))}
        if not models:
            raise ValueError("Aucune scene 3D importee dans l'APK")
        selected = set(models.values())
        for name in models:
            remap = f"assets/assets/{name}.glb.import"
            if remap in entries:
                selected.add(remap)
        for path in entries:
            if path.startswith("assets/assets/") and path.endswith((".png.import", ".jpg.import", ".jpeg.import")):
                base = path[len("assets/assets/"):].split(".", 1)[0]
                if any(base.startswith(name + "_") for name in models):
                    selected.add(path)
            m = TEX.fullmatch(path)
            if m and any(m.group(1).startswith(name + "_") for name in models):
                selected.add(path)
        files = []
        for src in sorted(selected):
            rel = Path(src.removeprefix("assets/"))
            dst = out / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            content = z.read(src)
            dst.write_bytes(content)
            files.append({"path": str(rel), "sha256": hashlib.sha256(content).hexdigest(), "size": len(content)})
        (out / "extraction-manifest.json").write_text(json.dumps(
            {"source": str(apk), "scenes": models, "files": files,
             "note": "Godot compiled resources, not reusable .glb originals. Licenses not verified."},
            indent=2, ensure_ascii=False), encoding="utf8")
        print(f"{len(models)} scenes 3D, {len(files)} fichiers extraits vers {out}")
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("apk", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    run(args.apk, args.destination)
