#!/usr/bin/env python3
"""Stage a small offline Android project, retaining model dependencies and licenses."""
from pathlib import Path
import argparse,json,shutil,struct

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
for folder in ['ui','shaders']:
    shutil.copytree(ROOT/'loic'/folder,dest/'loic'/folder,dirs_exist_ok=True)
shutil.copytree(ROOT/'loic/native',dest/'loic/native',dirs_exist_ok=True,ignore=shutil.ignore_patterns('src','*.os','*.o','*.py','SConstruct','build_profile.json','.*','models','*.linux.*'))
(dest/'loic/native/models').mkdir(exist_ok=True)
shutil.copy(ROOT/'loic/native/models/Qwen3-0.6B-Q4_K_M.gguf',dest/'loic/native/models/Qwen3-0.6B-Q4_K_M.gguf')
# The desktop importer needs its matching extension to discover the class.
if (ROOT/'loic/native/libloic_ai.linux.x86_64.so').exists():
    shutil.copy(ROOT/'loic/native/libloic_ai.linux.x86_64.so',dest/'loic/native/libloic_ai.linux.x86_64.so')
paths=set()
characters='packs/kaykit-character-pack-adventures-1.0/addons/kaykit_character_pack_adventures/Characters/gltf/'
for name in ['Knight','Mage','Rogue','Barbarian']: paths.add(characters+name+'.glb')
for name in ['Skeleton_Warrior','Skeleton_Mage','Skeleton_Rogue','Skeleton_Minion']:
    paths.add('packs/kaykit-character-pack-skeletons-1.0/addons/kaykit_character_pack_skeletons/Characters/gltf/'+name+'.glb')
for name in ['Tree_1_A_Color1','Tree_2_A_Color1','Rock_1_A_Color1']: paths.add('packs/kaykit-forest-free/Assets/gltf/'+name+'.gltf')
for name in ['home_A','blacksmith','market','windmill','well','tower_A','barracks']:
    paths.add('packs/kaykit-medieval-hexagon-pack-1.0/addons/kaykit_medieval_hexagon_pack/Assets/gltf/buildings/blue/building_'+name+'_blue.gltf')
paths.add('packs/nature-kit/Models/GLTF format/crops_wheatStageB.glb')

# The approved village uses these exact source models and their dependencies.
medieval='packs/kaykit-medieval-hexagon-pack-1.0/addons/kaykit_medieval_hexagon_pack/Assets/gltf/'
for name in ['home_A','home_B','tavern','watermill','tower_A','castle','market','well']:
    paths.add(medieval+'buildings/yellow/building_'+name+'_yellow.gltf')
paths.add(medieval+'buildings/neutral/fence_wood_straight.gltf')
for name in ['tower-square','wall']:
    paths.add('packs/castle-kit/Models/GLB format/'+name+'.glb')
for name in ['Bush_1_A_Color1','Grass_1_A_Color1']:
    paths.add('packs/kaykit-forest-free/Assets/gltf/'+name+'.gltf')
for name in ['flower_yellowA','flower_purpleA','tree_pineTallA_detailed','tree_oak','plant_bushDetailed','rock_largeA','grass_large']:
    paths.add('packs/nature-kit/Models/GLTF format/'+name+'.glb')

def copy_asset(path):
    src=ROOT/path;out=dest/path
    out.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy(src,out)
    if src.suffix in ('.gltf','.glb'):
        if src.suffix=='.glb':
            raw=src.read_bytes();length=struct.unpack_from('<I',raw,12)[0];data=json.loads(raw[20:20+length])
        else:
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
