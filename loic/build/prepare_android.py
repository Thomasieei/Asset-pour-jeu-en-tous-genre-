#!/usr/bin/env python3
"""Stage a small offline Android project, retaining model dependencies and licenses."""
from pathlib import Path
import argparse,json,shutil

ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('destination',type=Path)
args=parser.parse_args()
dest=args.destination.resolve()
if dest == ROOT or ROOT in dest.parents:
    raise SystemExit('Use a separate build directory outside the repository.')
dest.mkdir(parents=True,exist_ok=True)
shutil.copy(ROOT/'project.godot',dest/'project.godot')
shutil.copytree(ROOT/'loic/scripts',dest/'loic/scripts',dirs_exist_ok=True)
shutil.copytree(ROOT/'loic/scenes',dest/'loic/scenes',dirs_exist_ok=True)
shutil.copytree(ROOT/'loic/native',dest/'loic/native',dirs_exist_ok=True,ignore=shutil.ignore_patterns('src','*.os','*.o','*.py','SConstruct','build_profile.json','.*','models','*.linux.*'))
(dest/'loic/native/models').mkdir(exist_ok=True)
shutil.copy(ROOT/'loic/native/models/Qwen3-0.6B-Q4_K_M.gguf',dest/'loic/native/models/Qwen3-0.6B-Q4_K_M.gguf')
# The desktop importer needs its matching extension to discover the class.
shutil.copy(ROOT/'loic/native/libloic_ai.linux.x86_64.so',dest/'loic/native/libloic_ai.linux.x86_64.so')
paths=set()
characters='packs/kaykit-character-pack-adventures-1.0/addons/kaykit_character_pack_adventures/Characters/gltf/'
for name in ['Knight','Mage','Rogue','Barbarian']: paths.add(characters+name+'.glb')
paths.add('packs/kaykit-character-pack-skeletons-1.0/addons/kaykit_character_pack_skeletons/Characters/gltf/Skeleton_Warrior.glb')
for name in ['Tree_1_A_Color1','Tree_2_A_Color1','Rock_1_A_Color1']: paths.add('packs/kaykit-forest-free/Assets/gltf/'+name+'.gltf')
for name in ['home_A','blacksmith','market','windmill','well']:
    paths.add('packs/kaykit-medieval-hexagon-pack-1.0/addons/kaykit_medieval_hexagon_pack/Assets/gltf/buildings/blue/building_'+name+'_blue.gltf')
paths.add('packs/nature-kit/Models/GLTF format/crops_wheatStageB.glb')

def copy_asset(path):
    src=ROOT/path;out=dest/path
    out.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy(src,out)
    if src.suffix=='.gltf':
        data=json.loads(src.read_text())
        for item in data.get('buffers',[])+data.get('images',[]):
            uri=item.get('uri','')
            if uri and not uri.startswith('data:'):
                from urllib.parse import unquote
                copy_asset(str(Path(path).parent/unquote(uri)))

for path in paths:copy_asset(path)
catalog=json.loads((ROOT/'catalog.json').read_text())
used={p.split('/')[1] for p in paths}
catalog['models']=[m for m in catalog['models'] if m['path'] in paths]
catalog['assets']=[]
catalog['packs']=[p for p in catalog['packs'] if p.get('id',p.get('name')) in used]
(dest/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False))
for pack in used:
    for item in (ROOT/'packs'/pack).rglob('*'):
        if item.is_file() and ('license' in item.name.lower() or item.name.lower().startswith('copying')):
            target=dest/item.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy(item,target)
shutil.copytree(ROOT/'ai/royaume-vivant/licenses',dest/'loic/native/licenses',dirs_exist_ok=True)
print('Staged',len(paths),'models in',dest)
