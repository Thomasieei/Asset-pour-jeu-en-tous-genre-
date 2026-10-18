#!/usr/bin/env python3
"""Apply source corrections to a known Godot 4.3 debug APK. Re-sign afterward.
Retains imported art, native libraries and model bytes from the base APK.
"""
import argparse,hashlib,json,re,struct,zipfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('base',type=Path);p.add_argument('output',type=Path);a=p.parse_args()
root=Path(__file__).resolve().parents[2]
assert hashlib.sha256(a.base.read_bytes()).hexdigest()=='c101ed91172db3563b5d7d3b17c2e916aeebc40fcc758c7fabffe6a30d348b6d','Wrong base APK'
entries=[]
for script in sorted((root/'loic/scripts').glob('*.gd')):
 text=script.read_text();m=re.search(r'class_name (\w+)',text)
 if m:entries.append('{"base": &"'+re.search(r'extends (\w+)',text).group(1)+'", "class": &"'+m.group(1)+'", "icon": "", "language": &"GDScript", "path": "res://loic/scripts/'+script.name+'"}')
cache=('list=Array[Dictionary](['+',\n'.join(entries)+'])\n').encode()
def manifest(raw):
 data=bytearray(raw);data=data.replace(b'0.4-aurore',b'0.6-aurore').replace('0.4-aurore'.encode('utf-16le'),'0.6-aurore'.encode('utf-16le'))
 offset=8;code_index=None;changed=False
 while offset<len(data):
  kind,header,size=struct.unpack_from('<HHI',data,offset)
  if kind==0x180:
   values=struct.unpack_from('<'+'I'*((size-header)//4),data,offset+header)
   code_index=values.index(0x0101021b)
  if kind==0x102 and code_index is not None:
   start,attr_size,count=struct.unpack_from('<HHH',data,offset+24)
   for i in range(count):
    pos=offset+16+start+i*attr_size
    name=struct.unpack_from('<I',data,pos+4)[0]
    if name==code_index:
     assert data[pos+15]==0x10
     assert struct.unpack_from('<I',data,pos+16)[0]==4
     struct.pack_into('<I',data,pos+16,6);changed=True
  offset+=size
 assert changed,'Version code not found'
 return bytes(data)
with zipfile.ZipFile(a.base) as src,zipfile.ZipFile(a.output,'w') as dst:
 for info in src.infolist():
  name=info.filename
  if name.startswith('META-INF/') or name.startswith('assets/loic/scripts/'):continue
  if name=='assets/.godot/global_script_class_cache.cfg':dst.writestr(info,cache)
  elif name=='AndroidManifest.xml':dst.writestr(info,manifest(src.read(info)))
  else:dst.writestr(info,src.read(info))
 for script in sorted((root/'loic/scripts').glob('*.gd')):
  dst.writestr('assets/loic/scripts/'+script.name,script.read_bytes(),compress_type=zipfile.ZIP_DEFLATED)
print('Unsigned corrective APK:',a.output)
