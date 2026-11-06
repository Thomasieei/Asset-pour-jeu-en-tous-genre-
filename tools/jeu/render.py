"""Tiny software rasterizer for glTF/GLB static meshes (QA previews, no GPU)."""
import json, struct, os, base64, io
import numpy as np
from PIL import Image

CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}
_cache = {}

def _load_raw(path):
    b = open(path, 'rb').read()
    if b[:4] == b'glTF':
        off = 12; j = None; binc = b''
        while off < len(b):
            ln, typ = struct.unpack('<II', b[off:off + 8]); ch = b[off + 8:off + 8 + ln]
            if typ == 0x4E4F534A: j = json.loads(ch)
            else: binc = ch
            off += 8 + ln
        bufs = [binc]
    else:
        j = json.loads(b); d = os.path.dirname(path)
        bufs = [open(os.path.join(d, bf['uri']), 'rb').read() for bf in j['buffers']]
    return j, bufs

def _acc(j, bufs, i):
    a = j['accessors'][i]; bv = j['bufferViews'][a['bufferView']]
    n = NC[a['type']]; dt = CT[a['componentType']]
    off = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    stride = bv.get('byteStride', 0); isz = np.dtype(dt).itemsize * n
    buf = bufs[bv.get('buffer', 0)]
    if stride and stride != isz:
        arr = np.array([np.frombuffer(buf, dt, n, off + k * stride) for k in range(a['count'])])
    else:
        arr = np.frombuffer(buf, dt, a['count'] * n, off).reshape(a['count'], n)
    return arr.astype(np.float64) if dt == np.float32 else arr

def _node_mat(n):
    if 'matrix' in n: return np.array(n['matrix']).reshape(4, 4).T
    t = n.get('translation', [0, 0, 0]); r = n.get('rotation', [0, 0, 0, 1]); s = n.get('scale', [1, 1, 1])
    x, y, z, w = r
    R = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                  [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                  [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
    M = np.eye(4); M[:3, :3] = R * np.array(s); M[:3, 3] = t
    return M

def load(path):
    if path in _cache: return _cache[path]
    j, bufs = _load_raw(path)
    tex = None
    if j.get('images'):
        im = j['images'][0]
        if 'uri' in im: tex = Image.open(os.path.join(os.path.dirname(path), im['uri']))
        else:
            bv = j['bufferViews'][im['bufferView']]
            tex = Image.open(io.BytesIO(bufs[0][bv.get('byteOffset', 0):bv.get('byteOffset', 0) + bv['byteLength']]))
        tex = np.asarray(tex.convert('RGB')).astype(np.float64) / 255
    parts = []
    def walk(ni, M):
        n = j['nodes'][ni]; W = M @ _node_mat(n)
        if 'mesh' in n and 'skin' not in n or ('mesh' in n):
            for pr in j['meshes'][n['mesh']]['primitives']:
                P = _acc(j, bufs, pr['attributes']['POSITION'])
                uv = _acc(j, bufs, pr['attributes']['TEXCOORD_0']) if 'TEXCOORD_0' in pr['attributes'] else np.zeros((len(P), 2))
                I = _acc(j, bufs, pr['indices']).reshape(-1, 3).astype(np.int64)
                col = np.array([0.8, 0.8, 0.8])
                mi = pr.get('material')
                if mi is not None:
                    bc = j['materials'][mi].get('pbrMetallicRoughness', {}).get('baseColorFactor')
                    if bc: col = np.array(bc[:3])
                Ph = np.c_[P, np.ones(len(P))] @ W.T
                parts.append((Ph[:, :3], uv, I, col))
        for c in n.get('children', []): walk(c, W)
    for r in j['scenes'][j.get('scene', 0)]['nodes']: walk(r, np.eye(4))
    _cache[path] = (parts, tex)
    return _cache[path]

def look_at(eye, target, up=(0, 1, 0)):
    eye = np.array(eye, float); f = np.array(target, float) - eye; f /= np.linalg.norm(f)
    r = np.cross(f, up); r /= np.linalg.norm(r); u = np.cross(r, f)
    V = np.eye(4); V[0, :3] = r; V[1, :3] = u; V[2, :3] = -f; V[:3, 3] = -V[:3, :3] @ eye
    return V

def xform(pos=(0, 0, 0), rot_y_deg=0, scale=1.0):
    a = np.radians(rot_y_deg); c, s = np.cos(a), np.sin(a)
    M = np.eye(4); M[:3, :3] = np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]]) * scale; M[:3, 3] = pos
    return M

def render(items, eye, target, W=640, H=400, fov=50, ortho=None, bg=(0.55, 0.75, 0.95), light=(-0.4, 0.8, 0.45)):
    """items: list of (path, 4x4 transform) or ('__tri__', (P,I,color))"""
    V = look_at(eye, target)
    img = np.zeros((H, W, 3)); img[:] = bg; zb = np.full((H, W), np.inf)
    L = np.array(light, float); L /= np.linalg.norm(L)
    f = 1 / np.tan(np.radians(fov) / 2)
    for path, M in items:
        if path == '__tri__':
            P, I, col = M; parts = [(P, np.zeros((len(P), 2)), I, np.array(col))]; tex = None; Mw = np.eye(4)
        else:
            parts, tex = load(path); Mw = M
        for P, uv, I, col in parts:
            Pw = np.c_[P, np.ones(len(P))] @ Mw.T
            Pv = Pw @ V.T
            z = -Pv[:, 2]
            if ortho:
                sx = (Pv[:, 0] / ortho * 0.5 * W * (H / W) + W / 2); sy = (H / 2 - Pv[:, 1] / ortho * 0.5 * H)
            else:
                zz = np.maximum(z, 1e-3)
                sx = W / 2 + Pv[:, 0] / zz * f * H / 2; sy = H / 2 - Pv[:, 1] / zz * f * H / 2
            tri = I
            a, b, c = Pw[tri[:, 0], :3], Pw[tri[:, 1], :3], Pw[tri[:, 2], :3]
            nrm = np.cross(b - a, c - a); nl = np.linalg.norm(nrm, axis=1) + 1e-12; nrm /= nl[:, None]
            shade = 0.45 + 0.55 * np.abs(nrm @ L)
            for k, t in enumerate(tri):
                if (z[t] <= 0.05).any() and not ortho: continue
                xs, ys = sx[t], sy[t]
                x0, x1 = int(max(0, np.floor(xs.min()))), int(min(W - 1, np.ceil(xs.max())))
                y0, y1 = int(max(0, np.floor(ys.min()))), int(min(H - 1, np.ceil(ys.max())))
                if x0 > x1 or y0 > y1: continue
                den = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
                if abs(den) < 1e-9: continue
                gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
                w0 = ((ys[1] - ys[2]) * (gx - xs[2]) + (xs[2] - xs[1]) * (gy - ys[2])) / den
                w1 = ((ys[2] - ys[0]) * (gx - xs[2]) + (xs[0] - xs[2]) * (gy - ys[2])) / den
                w2 = 1 - w0 - w1
                m = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4)
                if not m.any(): continue
                zt = z[t]; d = w0 * zt[0] + w1 * zt[1] + w2 * zt[2]
                sub = zb[y0:y1 + 1, x0:x1 + 1]
                m &= d < sub
                if not m.any(): continue
                if tex is not None:
                    u = w0 * uv[t[0], 0] + w1 * uv[t[1], 0] + w2 * uv[t[2], 0]
                    v = w0 * uv[t[0], 1] + w1 * uv[t[1], 1] + w2 * uv[t[2], 1]
                    th, tw = tex.shape[:2]
                    tx = np.clip((u % 1) * tw, 0, tw - 1).astype(int); ty = np.clip((v % 1) * th, 0, th - 1).astype(int)
                    cc = tex[ty, tx] * shade[k]
                else:
                    cc = np.broadcast_to(col * shade[k], gx.shape + (3,))
                sub[m] = d[m]
                img[y0:y1 + 1, x0:x1 + 1][m] = cc[m]
    return Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
