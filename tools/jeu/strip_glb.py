"""Strip a GLB: keep only listed animations, drop listed mesh nodes, compact the binary buffer.
usage: strip_glb.py in.glb out.glb "Anim1,Anim2" "MeshNodeToDrop1,MeshNodeToDrop2"
"""
import json, struct, sys

def read_glb(p):
    b = open(p, 'rb').read()
    assert b[:4] == b'glTF'
    off = 12; j = None; binc = b''
    while off < len(b):
        ln, typ = struct.unpack('<II', b[off:off + 8])
        chunk = b[off + 8: off + 8 + ln]
        if typ == 0x4E4F534A: j = json.loads(chunk)
        elif typ == 0x004E4942: binc = chunk
        off += 8 + ln
    return j, binc

def write_glb(p, j, binc):
    js = json.dumps(j, separators=(',', ':')).encode()
    js += b' ' * ((4 - len(js) % 4) % 4)
    binc += b'\0' * ((4 - len(binc) % 4) % 4)
    total = 12 + 8 + len(js) + 8 + len(binc)
    with open(p, 'wb') as f:
        f.write(struct.pack('<III', 0x46546C67, 2, total))
        f.write(struct.pack('<II', len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack('<II', len(binc), 0x004E4942)); f.write(binc)

def main():
    src, dst, keep, drop = sys.argv[1], sys.argv[2], sys.argv[3], (sys.argv[4] if len(sys.argv) > 4 else '')
    keep = [k for k in keep.split(',') if k]; drop = set(d for d in drop.split(',') if d)
    j, binc = read_glb(src)
    names = [a.get('name') for a in j.get('animations', [])]
    missing = [k for k in keep if k not in names]
    if missing: sys.exit('missing animations: %s' % missing)
    j['animations'] = [a for a in j.get('animations', []) if a.get('name') in keep]
    # drop mesh nodes (keep node as transform so hierarchy indices stay valid)
    for n in j['nodes']:
        if n.get('name') in drop and 'mesh' in n:
            del n['mesh']; n.pop('skin', None)
    used_mesh = sorted({n['mesh'] for n in j['nodes'] if 'mesh' in n})
    mremap = {o: i for i, o in enumerate(used_mesh)}
    j['meshes'] = [j['meshes'][o] for o in used_mesh]
    for n in j['nodes']:
        if 'mesh' in n: n['mesh'] = mremap[n['mesh']]
    # used accessors
    acc = set()
    for m in j['meshes']:
        for pr in m['primitives']:
            acc.update(pr['attributes'].values())
            if 'indices' in pr: acc.add(pr['indices'])
            for t in pr.get('targets', []): acc.update(t.values())
    for s in j.get('skins', []):
        if 'inverseBindMatrices' in s: acc.add(s['inverseBindMatrices'])
    for a in j['animations']:
        for s in a['samplers']: acc.add(s['input']); acc.add(s['output'])
    acc = sorted(acc)
    aremap = {o: i for i, o in enumerate(acc)}
    used_bv = sorted({j['accessors'][a]['bufferView'] for a in acc if 'bufferView' in j['accessors'][a]} |
                     {im['bufferView'] for im in j.get('images', []) if 'bufferView' in im})
    bvremap = {}; newbin = bytearray(); newbv = []
    for o in used_bv:
        bv = dict(j['bufferViews'][o])
        data = binc[bv.get('byteOffset', 0): bv.get('byteOffset', 0) + bv['byteLength']]
        while len(newbin) % 4: newbin.append(0)
        bv['byteOffset'] = len(newbin); bv['buffer'] = 0
        newbin += data; bvremap[o] = len(newbv); newbv.append(bv)
    newacc = []
    for o in acc:
        a = dict(j['accessors'][o])
        assert 'sparse' not in a
        if 'bufferView' in a: a['bufferView'] = bvremap[a['bufferView']]
        newacc.append(a)
    j['accessors'] = newacc; j['bufferViews'] = newbv
    for im in j.get('images', []):
        if 'bufferView' in im: im['bufferView'] = bvremap[im['bufferView']]
    for m in j['meshes']:
        for pr in m['primitives']:
            pr['attributes'] = {k: aremap[v] for k, v in pr['attributes'].items()}
            if 'indices' in pr: pr['indices'] = aremap[pr['indices']]
            if 'targets' in pr: pr['targets'] = [{k: aremap[v] for k, v in t.items()} for t in pr['targets']]
    for s in j.get('skins', []):
        if 'inverseBindMatrices' in s: s['inverseBindMatrices'] = aremap[s['inverseBindMatrices']]
    for a in j['animations']:
        for s in a['samplers']: s['input'] = aremap[s['input']]; s['output'] = aremap[s['output']]
    j['buffers'] = [{'byteLength': len(newbin)}]
    write_glb(dst, j, bytes(newbin))
    print('%s -> %s : %d anims, %d meshes, %d KB' % (src.split('/')[-1], dst.split('/')[-1], len(j['animations']), len(j['meshes']), len(newbin) // 1024))

main()
