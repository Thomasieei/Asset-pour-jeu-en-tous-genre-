"""Level compiler: writes game/data/world.json + validation + preview renders.
Coordinates: x east, z south (north = -Z). Angles theta measured from north, clockwise.
Rotation ry (degrees) follows Godot: local +Z -> (sin ry, cos ry).
"""
import json, math, os, sys, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

GAME = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'game')
ENV = GAME + '/assets/env'

def gltf_bounds(rel):
    j = json.load(open(f'{ENV}/{rel}.gltf'))
    mn = [1e9] * 3; mx = [-1e9] * 3
    for m in j['meshes']:
        for p in m['primitives']:
            a = j['accessors'][p['attributes']['POSITION']]
            for i in range(3): mn[i] = min(mn[i], a['min'][i]); mx[i] = max(mx[i], a['max'][i])
    return mn, mx

def polar(theta, r, c=(0, 0)):
    t = math.radians(theta)
    return (c[0] + r * math.sin(t), c[1] - r * math.cos(t))

def face_ry(px, pz, tx, tz):
    return math.degrees(math.atan2(tx - px, tz - pz))

W = {'objects': [], 'inst': {}, 'roads': [], 'discs': [], 'boundary': [], 'spawns': {}, 'npcs': [], 'labels': []}
footprints = []   # (x, z, radius, name) for overlap checks
problems = []

def add_obj(model, x, z, ry=0.0, s=1.0, col='box', fn='', label='', y=0.0, shrink=0.88):
    mn, mx = gltf_bounds(model)
    W['objects'].append({'m': model, 'p': [round(x, 3), round(y, 3), round(z, 3)], 'r': round(ry, 2), 's': s,
                         'col': col, 'fn': fn, 'shrink': shrink})
    rad = max(mx[0] - mn[0], mx[2] - mn[2]) * s * 0.5
    footprints.append((x, z, rad * 0.8, model))
    if label:
        W['labels'].append({'text': label, 'p': [round(x, 2), round((mx[1]) * s + 1.2 + y, 2), round(z, 2)]})
    return mn, mx

def add_inst(kind, x, z, ry, s, col=False):
    W['inst'].setdefault(kind, []).append([round(x, 2), round(z, 2), round(ry, 1), round(s, 2), 1 if col else 0])

def road(kind, pts, w, h):
    W['roads'].append({'kind': kind, 'w': w, 'h': h, 'pts': [[round(a, 2), round(b, 2)] for a, b in pts]})

def disc(kind, x, z, r, h):
    W['discs'].append({'kind': kind, 'p': [x, z], 'r': r, 'h': h})

# ------------------------------------------------------------------ layout constants
C1 = (0.0, 0.0); R1 = 47.0          # village playable circle
C2 = (0.0, -88.0); R2 = 30.5        # hunting ground playable circle
WALL_Z = -51.0
PLAZA_R = 13.5

# ------------------------------------------------------------------ village
disc('plaza', 0, 0, PLAZA_R, 0.04)
add_obj('medieval/building_well_blue', 0, 0, 0, 4.2, 'cyl', 'well', '')

# north road (stone inside village, dirt outside the gate)
road('stone', [(0, -13.0), (0, -47.0)], 5.0, 0.03)
road('dirt', [(0, -47.0), (0, -56.0), (0.6, -64.0), (0, -74.0)], 5.0, 0.028)
disc('dirt', C2[0], -80.0, 7.5, 0.027)
# south road to the chapel
CH_S = 7.0
ch_mn, ch_mx = gltf_bounds('medieval/building_church_blue')
CH_Z = 36.0
add_obj('medieval/building_church_blue', 0, CH_Z, 180.0, CH_S, 'box', 'chapel', 'Chapelle')
road('stone', [(0, 13.0), (0, CH_Z - ch_mx[2] * CH_S + 0.3)], 4.5, 0.03)
disc('stone', 0, CH_Z - ch_mx[2] * CH_S - 1.5, 3.2, 0.031)

RING = [  # theta, radius, model, scale, function, label
    (36, 26.5, 'building_blacksmith_blue', 7.5, 'forge', 'Forge'),
    (73, 25.5, 'building_home_A_blue', 8.0, '', ''),
    (110, 27.0, 'building_market_blue', 6.3, 'market', 'Marché (bientôt)'),
    (147, 25.5, 'building_home_B_blue', 7.5, '', ''),
    (213, 26.5, 'building_tavern_blue', 6.8, 'tavern', 'Taverne (bientôt)'),
    (250, 25.5, 'building_home_A_blue', 8.0, '', ''),
    (287, 25.5, 'building_home_B_blue', 7.5, '', ''),
    (324, 27.5, 'building_barracks_blue', 5.8, 'barracks', 'Caserne des ombres'),
]
doors = {}
for th, r, mdl, s, fn, label in RING:
    x, z = polar(th, r)
    ry = face_ry(x, z, 0, 0)
    mn, mx = add_obj('medieval/' + mdl, x, z, ry, s, 'box', fn, label)
    # door point = front face of the building, toward the plaza
    dx, dz = -x / r, -z / r
    door = (x + dx * (mx[2] * s), z + dz * (mx[2] * s))
    doors[fn or mdl + str(th)] = door
    start = polar(th, PLAZA_R - 0.5)
    road('stone', [start, (door[0] - dx * 0.2, door[1] - dz * 0.2)], 3.0, 0.029)
    disc('stone', door[0] + dx * 1.2, door[1] + dz * 1.2, 2.0, 0.0295)

# north fortification: two towers framing an open passage + walls into the forest
TW_S = 5.5
for sx in (-1, 1):
    add_obj('medieval/building_tower_A_blue', sx * 6.6, WALL_Z, 0.0, TW_S, 'box', '', '')
    for k in range(5):
        cx = sx * (9.3 + 6.0 + 12.0 * k)
        add_obj('medieval/wall_straight', cx, WALL_Z, 180.0, 6.0, 'box', '', '', shrink=0.98)
W['labels'].append({'text': 'Plaine des Tertres', 'p': [0, 7.5, WALL_Z + 3]})

# village props (hand placed, next to the buildings they belong to)
def near(fn, along, out, side_deg=0):
    """point relative to a ring building: 'along' = tangential offset, 'out' = toward plaza."""
    for th, r, mdl, s, f, l in RING:
        if f == fn:
            t = math.radians(th)
            radial = (math.sin(t), -math.cos(t)); tang = (math.cos(t), math.sin(t))
            bx, bz = polar(th, r)
            return (bx + tang[0] * along - radial[0] * out, bz + tang[1] * along - radial[1] * out)
    raise KeyError(fn)

px, pz = near('forge', -6.2, 1.5); add_obj('medieval/weaponrack', px, pz, face_ry(px, pz, 0, 0), 5.0, 'box')
px, pz = near('forge', -6.0, -1.8); add_obj('medieval/target', px, pz, face_ry(px, pz, 0, 0), 5.0, 'box')
px, pz = near('forge', 6.0, 1.0); add_obj('medieval/barrel', px, pz, 30, 5.0, 'cyl')
px, pz = near('market', 6.8, 0.5); add_obj('medieval/crate_A_big', px, pz, 15, 5.0, 'box')
px, pz = near('market', 7.2, -1.6); add_obj('medieval/crate_B_small', px, pz, 40, 5.0, 'box')
px, pz = near('market', -6.8, 0.5); add_obj('medieval/sack', px, pz, 70, 6.0, 'none')
px, pz = near('market', -7.0, -1.2); add_obj('medieval/barrel', px, pz, 0, 5.0, 'cyl')
px, pz = near('tavern', 6.2, 0.8); add_obj('medieval/barrel', px, pz, 10, 5.0, 'cyl')
px, pz = near('tavern', 6.6, -1.3); add_obj('medieval/barrel', px, pz, 50, 5.0, 'cyl')
px, pz = near('tavern', -6.0, 0.6); add_obj('medieval/crate_long_A' if os.path.exists(ENV + '/medieval/crate_long_A.gltf') else 'medieval/crate_A_big', px, pz, 0, 5.0, 'box')
for sgn in (-1, 1):
    px, pz = near('barracks', sgn * 5.6, 2.2); add_obj('medieval/flag_blue', px, pz, face_ry(px, pz, 0, 0), 9.0, 'cyl')
add_obj('medieval/bucket_water', 2.6, 2.4, 20, 5.0, 'none')
add_obj('medieval/wheelbarrow', -10.5, 33.5, 200, 5.0, 'box')
add_obj('medieval/resource_lumber', 10.5, 35.0, 75, 5.0, 'box')

# ------------------------------------------------------------------ hunting ground
for (x, z, ry) in [(-21, -80, 60), (-23.5, -90, 95), (-18, -99, 130)]:
    add_obj('medieval/tent', x, z, ry, 5.0, 'box')
add_obj('medieval/crate_A_big', -16.5, -87, 20, 5.0, 'box')
add_obj('medieval/crate_B_small', -17.5, -84.6, 65, 5.0, 'box')
add_obj('medieval/barrel', -15.8, -92.8, 0, 5.0, 'cyl')
BOSS = (0.0, -107.0)
for k in range(7):
    th = 180 + 40 + k * (280 / 6)    # leave the south side (toward the camp) open
    x, z = polar(th, 8.5, BOSS)
    add_inst('Rock_3_C_Color1', x, z, (k * 53) % 360, 3.2 + (k % 3) * 0.5, True)
W['labels'].append({'text': 'Autel du Seigneur', 'p': [BOSS[0], 5.5, BOSS[1] - 9.5]})

# ------------------------------------------------------------------ spawns & NPCs
W['spawns']['player'] = [0.0, 0.0, 9.0, 180.0]
W['spawns']['respawn'] = [0.0, 0.0, CH_Z - ch_mx[2] * CH_S - 3.0, 180.0]   # x, y, z, facing ry (180 = look north)
rnd = random.Random(7)
enemy_pts = []
while len(enemy_pts) < 12:
    x, z = polar(rnd.uniform(0, 360), math.sqrt(rnd.random()) * 18.0, (0, -86))
    if math.hypot(x - BOSS[0], z - BOSS[1]) < 12 or z > -70: continue
    if any(math.hypot(x - a, z - b) < 4.5 for a, b in enemy_pts): continue
    enemy_pts.append((x, z))
W['spawns']['enemies'] = [[round(a, 2), round(b, 2)] for a, b in enemy_pts]
W['spawns']['camp_center'] = [0.0, -86.0]
W['spawns']['camp_leash'] = 27.0
W['spawns']['boss'] = [BOSS[0], BOSS[1]]
fx, fz = near('forge', 0.0, 6.0)
W['npcs'] = [
    {'id': 'elder', 'model': 'npc_mage.glb', 'name': 'Ancienne Ysolde', 'p': [3.2, 0, 6.0], 'face': [0, 9.0],
     'talk': "Les ombres répondent à ceux qui les vainquent. Va dans la Plaine des Tertres, au nord, et éveille-les !"},
    {'id': 'smith', 'model': 'npc_barbarian.glb', 'name': 'Borin le forgeron', 'p': [round(fx, 2), 0, round(fz, 2)], 'face': [0, 0],
     'talk': "Approche, je renforce ton arme contre de l'or.", 'fn': 'forge'},
    {'id': 'guard', 'model': 'npc_rogue.glb', 'name': 'Veilleur Aldric', 'path': 'ring', 'p': [0, 0, -12.2],
     'talk': "La plaine grouille d'os ce soir. Reste sur tes gardes."},
]

# ------------------------------------------------------------------ geometry helpers for validation
def seg_dist(px, pz, a, b):
    ax, az = a; bx, bz = b
    vx, vz = bx - ax, bz - az; L = vx * vx + vz * vz
    t = 0 if L == 0 else max(0, min(1, ((px - ax) * vx + (pz - az) * vz) / L))
    return math.hypot(px - (ax + t * vx), pz - (az + t * vz))

def road_dist(x, z):
    d = 1e9
    for rd in W['roads']:
        p = rd['pts']
        for i in range(len(p) - 1):
            d = min(d, seg_dist(x, z, p[i], p[i + 1]) - rd['w'] / 2)
    for dc in W['discs']:
        d = min(d, math.hypot(x - dc['p'][0], z - dc['p'][1]) - dc['r'])
    return d

def foot_dist(x, z):
    return min(math.hypot(x - a, z - b) - r for a, b, r, _ in footprints)

def in_play(x, z, margin=0.0):
    return math.hypot(x - C1[0], z - C1[1]) < R1 - margin or math.hypot(x - C2[0], z - C2[1]) < R2 - margin

# ------------------------------------------------------------------ vegetation
VILLAGE_TREES = ['Tree_1_A_Color1', 'Tree_2_A_Color1', 'Tree_4_A_Color1', 'Tree_1_B_Color1']
FOREST_TREES = ['Tree_1_A_Color1', 'Tree_1_B_Color1', 'Tree_2_A_Color1', 'Tree_2_C_Color1', 'Tree_4_A_Color1']
placed_trees = []

def tree_ok(x, z, clearance):
    if road_dist(x, z) < clearance: return False
    if foot_dist(x, z) < clearance: return False
    if any(math.hypot(x - a, z - b) < 3.6 for a, b in placed_trees): return False
    return True

# inside the village: sparse groves between houses and along the edge (collidable)
rnd = random.Random(11)
tries = 0
while tries < 6000:
    tries += 1
    x, z = polar(rnd.uniform(0, 360), rnd.uniform(35.0, R1 - 1.0))
    if not tree_ok(x, z, 3.2): continue
    if rnd.random() > 0.16: continue
    placed_trees.append((x, z))
    add_inst(rnd.choice(VILLAGE_TREES), x, z, rnd.uniform(0, 360), rnd.uniform(1.35, 1.8), True)

# forest band outside the playable area (visual only, the boundary walls block the player)
rnd = random.Random(23)
step = 6.0
gx = -130.0
while gx <= 130.0:
    gz = -150.0
    while gz <= 110.0:
        x = gx + rnd.uniform(-2.4, 2.4); z = gz + rnd.uniform(-2.4, 2.4)
        gz += step
        if in_play(x, z, -1.6): continue
        # distance to the playable region boundary
        dout = min(math.hypot(x - C1[0], z - C1[1]) - R1, math.hypot(x - C2[0], z - C2[1]) - R2)
        if dout > 48: continue
        if abs(z - WALL_Z) < 8.5 and abs(x) < 76: continue      # keep the rampart readable
        if road_dist(x, z) < 2.5: continue
        if foot_dist(x, z) < 2.0: continue
        d1 = math.hypot(x - C1[0], z - C1[1]) - R1; d2 = math.hypot(x - C2[0], z - C2[1]) - R2
        if d2 < d1 and z < WALL_Z - 6:
            k = rnd.choice(['Tree_Bare_1_A_Color1', 'Tree_Bare_1_A_Color1', 'Tree_4_A_Color1', 'Tree_2_C_Color1'])
            add_inst(k, x, z, rnd.uniform(0, 360), rnd.uniform(2.0, 2.8) if 'Bare' in k else rnd.uniform(1.5, 2.1), False)
        else:
            add_inst(rnd.choice(FOREST_TREES), x, z, rnd.uniform(0, 360), rnd.uniform(1.5, 2.2), False)
    gx += step

# hunting ground edge: bare trees + rocks (collidable), centre left free for combat
rnd = random.Random(31)
hunting_props = []
tries = 0
while len(hunting_props) < 26 and tries < 4000:
    tries += 1
    x, z = polar(rnd.uniform(0, 360), rnd.uniform(21.0, R2 - 1.5), C2)
    if road_dist(x, z) < 2.5 or foot_dist(x, z) < 2.5: continue
    if math.hypot(x - BOSS[0], z - BOSS[1]) < 12.5: continue
    if any(math.hypot(x - a, z - b) < 4.0 for a, b in hunting_props): continue
    hunting_props.append((x, z))
    if rnd.random() < 0.5:
        add_inst('Tree_Bare_1_A_Color1', x, z, rnd.uniform(0, 360), rnd.uniform(1.9, 2.5), True)
    else:
        add_inst(rnd.choice(['Rock_1_A_Color1', 'Rock_2_B_Color1']), x, z, rnd.uniform(0, 360), rnd.uniform(2.4, 3.6), True)

# bushes hugging building flanks (no collision, small)
rnd = random.Random(41)
for th, r, mdl, s, fn, label in RING:
    for sgn in (-1, 1):
        t = math.radians(th); tang = (math.cos(t), math.sin(t)); rad = (math.sin(t), -math.cos(t))
        bx, bz = polar(th, r)
        mn, mx = gltf_bounds('medieval/' + mdl)
        half = (mx[0] - mn[0]) * s * 0.5 + 1.0
        x = bx + tang[0] * half * sgn + rad[0] * 1.5; z = bz + tang[1] * half * sgn + rad[1] * 1.5
        if road_dist(x, z) > 0.6:
            add_inst(rnd.choice(['Bush_2_A_Color1', 'Bush_4_A_Color1']), x, z, rnd.uniform(0, 360), rnd.uniform(2.6, 3.4), False)

# grass tufts
rnd = random.Random(53)
n = 0; tries = 0
while n < 1600 and tries < 40000:
    tries += 1
    if rnd.random() < 0.7:
        x, z = polar(rnd.uniform(0, 360), math.sqrt(rnd.random()) * (R1 + 6), C1)
    else:
        x, z = polar(rnd.uniform(0, 360), math.sqrt(rnd.random()) * (R2 + 6), C2)
    if road_dist(x, z) < 0.5 or foot_dist(x, z) < 0.3: continue
    g = 'Grass_1_A_Color1' if rnd.random() < 0.75 else 'Grass_2_A_Color1'
    add_inst(g, x, z, rnd.uniform(0, 360), rnd.uniform(1.0, 1.5) if g == 'Grass_1_A_Color1' else rnd.uniform(0.7, 1.0), False)
    n += 1

# ------------------------------------------------------------------ distant scenery
rnd = random.Random(61)
for k in range(22):
    th = k * (360 / 22) + rnd.uniform(-5, 5)
    x, z = polar(th, rnd.uniform(225, 250), (0, -25))
    m = rnd.choice(['mountain_A_grass_trees', 'mountain_B_grass', 'hills_A_trees'])
    W['objects'].append({'m': 'medieval/' + m, 'p': [round(x, 1), -2.0, round(z, 1)], 'r': round(rnd.uniform(0, 360), 1),
                         's': round(rnd.uniform(26, 36), 1), 'col': 'none', 'fn': 'scenery', 'shrink': 1.0})
W['clouds'] = [[round(polar(k * 40 + rnd.uniform(0, 20), rnd.uniform(60, 140))[0], 1), round(rnd.uniform(55, 75), 1),
                round(polar(k * 40, rnd.uniform(60, 140))[1], 1), rnd.choice(['cloud_big', 'cloud_small']), round(rnd.uniform(7, 11), 1)]
               for k in range(9)]

# ------------------------------------------------------------------ boundary (invisible walls)
def circle_walls(c, r, gap_theta, gap_half):
    step = 7.5
    th = 0.0
    while th < 360:
        a, b = th, th + step
        mid = (a + b) / 2
        dd = abs(((mid - gap_theta) + 180) % 360 - 180)
        if dd > gap_half:
            p1 = polar(a, r, c); p2 = polar(b, r, c)
            W['boundary'].append([[round(p1[0], 2), round(p1[1], 2)], [round(p2[0], 2), round(p2[1], 2)]])
        th += step
circle_walls(C1, R1, 0.0, 9.0)
circle_walls(C2, R2, 180.0, 12.0)
# side walls of the corridor between the two circles (behind the towers)
for sx in (-1, 1):
    W['boundary'].append([[sx * 4.6, -44.0], [sx * 4.6, -48.5]])
    W['boundary'].append([[sx * 4.6, -53.8], [sx * 4.6, -59.0]])
W['ground'] = {'hunt_center': list(C2), 'hunt_radius': R2 + 4}

# ------------------------------------------------------------------ validation
for i, (x1, z1, r1, m1) in enumerate(footprints):
    for (x2, z2, r2, m2) in footprints[i + 1:]:
        if 'scenery' in m1 or 'scenery' in m2: continue
        if 'wall_straight' in m1 and 'wall_straight' in m2: continue
        if ('wall_straight' in m1 or 'wall_straight' in m2) and ('tower' in m1 or 'tower' in m2): continue
        if math.hypot(x1 - x2, z1 - z2) < (r1 + r2) * 0.85:
            problems.append(f'overlap: {m1} @({x1:.1f},{z1:.1f}) vs {m2} @({x2:.1f},{z2:.1f})')
for o in W['objects']:
    if o['fn'] in ('scenery',) or 'wall' in o['m'] or 'tower' in o['m'] or 'well' in o['m']: continue
    x, z = o['p'][0], o['p'][2]
    if not in_play(x, z, -2.0): problems.append(f'outside playable: {o["m"]} {x:.1f},{z:.1f}')
for fn, (dx, dz) in doors.items():
    if road_dist(dx, dz) > 0.5: problems.append(f'door not on road: {fn}')
for kind, lst in W['inst'].items():
    if kind.startswith('Tree') or kind.startswith('Rock'):
        for x, z, ry, s, col in lst:
            if col and road_dist(x, z) < 1.5: problems.append(f'{kind} blocks road at {x},{z}')
for x, z in enemy_pts:
    if not in_play(x, z, 2): problems.append(f'enemy spawn outside {x},{z}')

os.makedirs(GAME + '/data', exist_ok=True)
json.dump(W, open(GAME + '/data/world.json', 'w'), separators=(',', ':'))
print('objects', len(W['objects']), 'inst', {k: len(v) for k, v in W['inst'].items()}, 'roads', len(W['roads']), 'boundary', len(W['boundary']))
print('size KB', os.path.getsize(GAME + '/data/world.json') // 1024)
print('PROBLEMS:', len(problems)); [print(' ', p) for p in problems[:30]]
