import json, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from render import *

GAME = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'game')
W = json.load(open(GAME + '/data/world.json'))
ENV = GAME + '/assets/env/'
COL = {'stone': (0.66, 0.62, 0.55), 'dirt': (0.55, 0.42, 0.28), 'plaza': (0.72, 0.68, 0.6)}

def ribbon(pts, w, y):
    P = []; I = []
    for i in range(len(pts) - 1):
        (ax, az), (bx, bz) = pts[i], pts[i + 1]
        dx, dz = bx - ax, bz - az; L = math.hypot(dx, dz) or 1
        nx, nz = -dz / L * w / 2, dx / L * w / 2
        b = len(P)
        P += [(ax + nx, y, az + nz), (ax - nx, y, az - nz), (bx - nx, y, bz - nz), (bx + nx, y, bz + nz)]
        I += [(b, b + 1, b + 2), (b, b + 2, b + 3)]
    return np.array(P, float), np.array(I)

def disc_mesh(x, z, r, y, n=32):
    P = [(x, y, z)] + [(x + r * math.sin(2 * math.pi * k / n), y, z + r * math.cos(2 * math.pi * k / n)) for k in range(n)]
    I = [(0, 1 + k, 1 + (k + 1) % n) for k in range(n)]
    return np.array(P, float), np.array(I)

def items(skip_grass=True, skip_far=False, center=None, radius=1e9):
    it = []
    GP = []; GI = []
    for gx in range(-260, 260, 10):
        for gz in range(-280, 230, 10):
            b = len(GP); GP += [(gx, 0, gz), (gx + 10, 0, gz), (gx + 10, 0, gz + 10), (gx, 0, gz + 10)]; GI += [(b, b + 1, b + 2), (b, b + 2, b + 3)]
    it.append(('__tri__', (np.array(GP, float), np.array(GI), (0.42, 0.62, 0.3))))
    hc = W['ground']['hunt_center']; P, I = disc_mesh(hc[0], hc[1], W['ground']['hunt_radius'], 0.005, 48)
    it.append(('__tri__', (P, I, (0.5, 0.55, 0.36))))
    for rd in W['roads']:
        P, I = ribbon(rd['pts'], rd['w'], rd['h']); it.append(('__tri__', (P, I, COL[rd['kind']])))
        for (x, z) in (rd['pts'][0], rd['pts'][-1]):
            P, I = disc_mesh(x, z, rd['w'] / 2, rd['h'], 12); it.append(('__tri__', (P, I, COL[rd['kind']])))
    for dc in W['discs']:
        P, I = disc_mesh(dc['p'][0], dc['p'][1], dc['r'], dc['h']); it.append(('__tri__', (P, I, COL[dc['kind']])))
    def ok(x, z): return center is None or math.hypot(x - center[0], z - center[1]) < radius
    for o in W['objects']:
        if skip_far and o['fn'] == 'scenery': continue
        if not ok(o['p'][0], o['p'][2]) and o['fn'] != 'scenery': continue
        it.append((ENV + o['m'] + '.gltf', xform(o['p'], o['r'], o['s'])))
    for kind, lst in W['inst'].items():
        if skip_grass and kind.startswith('Grass'): continue
        for x, z, ry, s, col in lst:
            if not ok(x, z): continue
            it.append((ENV + 'forest/' + kind + '.gltf', xform((x, 0, z), ry, s)))
    return it

if __name__ == '__main__':
    mode = sys.argv[1]
    if mode == 'top':
        im = render(items(skip_far=True), (0, 300, -29.0), (0, 0, -30), W=900, H=900, ortho=150, fov=40)
        im.save('/tmp/world_top.png')
    elif mode == 'spawn':
        sp = W['spawns']['player']
        im = render(items(skip_grass=False, center=(0, -10), radius=90), (0, 7.5, 18.0), (0, 2.0, -6), W=960, H=540, fov=60)
        im.save('/tmp/world_spawn.png')
    elif mode == 'hunt':
        im = render(items(skip_grass=False, center=(0, -88), radius=80), (0, 10, -54), (0, 1, -94), W=960, H=540, fov=60)
        im.save('/tmp/world_hunt.png')
