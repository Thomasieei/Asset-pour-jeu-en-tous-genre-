import json,struct,sys,os
def load(p):
    b=open(p,'rb').read()
    if b[:4]==b'glTF':
        cl=struct.unpack('<I',b[12:16])[0]; return json.loads(b[20:20+cl])
    return json.load(open(p))
for p in sys.argv[1:]:
    j=load(p)
    mins=[1e9]*3;maxs=[-1e9]*3
    for m in j.get('meshes',[]):
        for pr in m['primitives']:
            a=j['accessors'][pr['attributes']['POSITION']]
            for i in range(3): mins[i]=min(mins[i],a['min'][i]); maxs[i]=max(maxs[i],a['max'][i])
    an=[a.get('name') for a in j.get('animations',[])]
    print(os.path.basename(p), os.path.getsize(p)//1024,'KB','size',[round(maxs[i]-mins[i],2) for i in range(3)],'miny',round(mins[1],2),'skins',len(j.get('skins',[])),'nodes',len(j['nodes']),'anims',len(an), an[:80] if len(sys.argv)<4 else '')
