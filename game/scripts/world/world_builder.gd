class_name WorldBuilder
extends Node3D
## Builds the level from res://data/world.json (generated and validated by tools/build_world.py).
## Performance techniques: chunked MultiMesh vegetation (frustum culling per 40 m cell),
## visibility ranges, shadows only near the playable area, shared materials, cached scenes.

const ENV := "res://assets/env/"
const CHUNK := 40.0
const GROUND_SHADER := preload("res://shaders/ground.gdshader")
const ROAD_SHADER := preload("res://shaders/road.gdshader")

var data: Dictionary = {}
var interactables: Array = []        # {fn, pos: Vector3, radius, label}
var _scene_cache := {}
var _clouds: Array = []


func build() -> void:
	var txt := FileAccess.get_file_as_string("res://data/world.json")
	var parsed: Variant = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		push_error("world.json missing or invalid")
		return
	data = parsed
	_build_environment()
	_build_ground()
	_build_roads()
	_build_objects()
	_build_instances()
	_build_boundary()
	_build_labels()
	_build_clouds()


func spawn(key: String) -> Vector3:
	var s: Array = data["spawns"].get(key, [0, 0, 0, 0])
	return Vector3(float(s[0]), float(s[1]), float(s[2]))


func spawn_facing(key: String) -> float:
	var s: Array = data["spawns"].get(key, [0, 0, 0, 0])
	return deg_to_rad(float(s[3])) if s.size() > 3 else 0.0


func _process(delta: float) -> void:
	for c in _clouds:
		var n: Node3D = c
		n.position.x += delta * 0.8
		if n.position.x > 170.0:
			n.position.x = -170.0


# ------------------------------------------------------------------ helpers
func _scene(rel: String) -> PackedScene:
	if _scene_cache.has(rel):
		return _scene_cache[rel]
	var path := ENV + rel + ".gltf"
	var ps: PackedScene = load(path)
	if ps == null:
		push_error("Missing asset " + path)
	_scene_cache[rel] = ps
	return ps


## Merged AABB of every MeshInstance3D below root, in root's local space.
static func local_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		if mi.mesh == null:
			continue
		var xf: Transform3D = root.global_transform.affine_inverse() * mi.global_transform \
				if root.is_inside_tree() else _rel_xform(root, mi)
		var bb: AABB = xf * mi.mesh.get_aabb()
		if first:
			out = bb
			first = false
		else:
			out = out.merge(bb)
	return out


static func _rel_xform(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


func _set_shadows(root: Node, on: bool) -> void:
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ------------------------------------------------------------------ environment
func _build_environment() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.55, 0.92)
	sky_mat.sky_horizon_color = Color(0.72, 0.84, 0.96)
	sky_mat.ground_horizon_color = Color(0.72, 0.84, 0.96)
	sky_mat.ground_bottom_color = Color(0.35, 0.45, 0.3)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.4
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, 38.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 48.0
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	add_child(sun)


func _build_ground() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(560, 560)
	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	var g: Dictionary = data.get("ground", {})
	var hc: Array = g.get("hunt_center", [0, -88])
	mat.set_shader_parameter("hunt_center", Vector2(float(hc[0]), float(hc[1])))
	mat.set_shader_parameter("hunt_radius", float(g.get("hunt_radius", 34.0)))
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = mat
	mi.position = Vector3(0, 0, -25)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
	add_child(body)


# ------------------------------------------------------------------ roads
func _road_material(kind: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ROAD_SHADER
	match kind:
		"dirt":
			m.set_shader_parameter("base_color", Color(0.56, 0.42, 0.28))
			m.set_shader_parameter("cobble", 0.0)
		"plaza":
			m.set_shader_parameter("base_color", Color(0.74, 0.70, 0.62))
			m.set_shader_parameter("cobble", 1.0)
			m.set_shader_parameter("cell_scale", 0.9)
		_:
			m.set_shader_parameter("base_color", Color(0.66, 0.62, 0.55))
			m.set_shader_parameter("cobble", 1.0)
			m.set_shader_parameter("cell_scale", 1.3)
	return m


func _build_roads() -> void:
	var mats := {}
	var tools := {}
	for kind in ["stone", "dirt", "plaza"]:
		mats[kind] = _road_material(kind)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[kind] = st
	for rd in data.get("roads", []):
		var st: SurfaceTool = tools.get(rd["kind"], tools["stone"])
		var pts: Array = rd["pts"]
		var w: float = float(rd["w"])
		var h: float = float(rd["h"])
		for i in range(pts.size() - 1):
			_ribbon(st, Vector2(pts[i][0], pts[i][1]), Vector2(pts[i + 1][0], pts[i + 1][1]), w, h)
		for i in range(pts.size()):
			_disc(st, Vector2(pts[i][0], pts[i][1]), w * 0.5, h - 0.001, 16)
	for dc in data.get("discs", []):
		var st2: SurfaceTool = tools.get(dc["kind"], tools["stone"])
		_disc(st2, Vector2(dc["p"][0], dc["p"][1]), float(dc["r"]), float(dc["h"]), 48)
	for kind in tools.keys():
		var st3: SurfaceTool = tools[kind]
		var mesh := st3.commit()
		if mesh.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mats[kind]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _ribbon(st: SurfaceTool, a: Vector2, b: Vector2, w: float, h: float) -> void:
	var d := b - a
	if d.length() < 0.01:
		return
	var n := Vector2(-d.y, d.x).normalized() * (w * 0.5)
	var p0 := Vector3(a.x + n.x, h, a.y + n.y)
	var p1 := Vector3(a.x - n.x, h, a.y - n.y)
	var p2 := Vector3(b.x - n.x, h, b.y - n.y)
	var p3 := Vector3(b.x + n.x, h, b.y + n.y)
	_vert(st, p0, Vector2(0, 0))
	_vert(st, p1, Vector2(1, 0))
	_vert(st, p2, Vector2(1, 1))
	_vert(st, p0, Vector2(0, 0))
	_vert(st, p2, Vector2(1, 1))
	_vert(st, p3, Vector2(0, 1))


## The road shader renders both faces and uses an explicit up normal, so winding does not matter.
func _vert(st: SurfaceTool, p: Vector3, uv: Vector2) -> void:
	st.set_normal(Vector3.UP)
	st.set_uv(uv)
	st.add_vertex(p)


func _disc(st: SurfaceTool, c: Vector2, r: float, h: float, seg: int) -> void:
	for k in seg:
		var a0 := TAU * float(k) / float(seg)
		var a1 := TAU * float(k + 1) / float(seg)
		_vert(st, Vector3(c.x, h, c.y), Vector2(0.5, 0.5))
		_vert(st, Vector3(c.x + r * sin(a0), h, c.y + r * cos(a0)), Vector2(0.0, 0.0))
		_vert(st, Vector3(c.x + r * sin(a1), h, c.y + r * cos(a1)), Vector2(0.0, 0.0))


# ------------------------------------------------------------------ static objects
func _build_objects() -> void:
	for o in data.get("objects", []):
		var ps := _scene(str(o["m"]))
		if ps == null:
			continue
		var inst: Node3D = ps.instantiate()
		var p: Array = o["p"]
		var s: float = float(o["s"])
		inst.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		inst.rotation.y = deg_to_rad(float(o["r"]))
		inst.scale = Vector3.ONE * s
		add_child(inst)
		var fn: String = str(o.get("fn", ""))
		if fn == "scenery":
			_set_shadows(inst, false)
			for n in inst.find_children("*", "GeometryInstance3D", true, false):
				(n as GeometryInstance3D).extra_cull_margin = 0.0
			continue
		var col: String = str(o.get("col", "box"))
		var shrink: float = float(o.get("shrink", 0.88))
		var bb := local_aabb(inst)
		if col != "none" and bb.size.length() > 0.0:
			_add_collider(inst, bb, s, col, shrink)
		if fn != "":
			var radius: float = maxf(bb.size.x, bb.size.z) * s * 0.5 + 3.5
			# interaction point = in front of the door (+Z of the model)
			var front := inst.global_transform.basis.z.normalized()
			var door: Vector3 = inst.position + front * (bb.end.z * s + 1.2)
			interactables.append({"fn": fn, "pos": door, "radius": minf(radius, 6.0), "center": inst.position})


func _add_collider(inst: Node3D, bb: AABB, s: float, col: String, shrink: float) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	# body is a child of the scaled instance: shapes are expressed in local (unscaled) units,
	# so we cancel the scale on the body and give real-world sizes.
	body.scale = Vector3.ONE / s
	if col == "cyl":
		var cyl := CylinderShape3D.new()
		cyl.radius = maxf(bb.size.x, bb.size.z) * 0.5 * s * shrink
		cyl.height = maxf(bb.size.y * s, 1.0)
		cs.shape = cyl
	else:
		var box := BoxShape3D.new()
		box.size = Vector3(bb.size.x * s * shrink, maxf(bb.size.y * s, 1.0), bb.size.z * s * shrink)
		cs.shape = box
	cs.position = bb.get_center() * s
	body.add_child(cs)
	inst.add_child(body)


# ------------------------------------------------------------------ instanced vegetation
func _build_instances() -> void:
	var inst_data: Dictionary = data.get("inst", {})
	var colliders := StaticBody3D.new()
	colliders.name = "VegetationColliders"
	add_child(colliders)
	for kind in inst_data.keys():
		var ps := _scene("forest/" + str(kind))
		if ps == null:
			continue
		var tmp: Node3D = ps.instantiate()
		var meshes := tmp.find_children("*", "MeshInstance3D", true, false)
		if meshes.is_empty():
			tmp.free()
			continue
		var mi0: MeshInstance3D = meshes[0]
		var mesh: Mesh = mi0.mesh
		var local_xf := _rel_xform(tmp, mi0)
		var aabb: AABB = local_xf * mesh.get_aabb()
		tmp.free()
		var is_grass := str(kind).begins_with("Grass")
		var is_bush := str(kind).begins_with("Bush")
		var is_tree := str(kind).begins_with("Tree")
		# group by chunk and by "near" flag (collidable = inside playable area)
		var groups := {}
		for row in inst_data[kind]:
			var x: float = float(row[0])
			var z: float = float(row[1])
			var near: int = int(row[4])
			var key := "%d_%d_%d" % [int(floor(x / CHUNK)), int(floor(z / CHUNK)), near]
			if not groups.has(key):
				groups[key] = []
			groups[key].append(row)
			if near == 1:
				var s: float = float(row[3])
				var cs := CollisionShape3D.new()
				var cyl := CylinderShape3D.new()
				var footprint: float = maxf(aabb.size.x, aabb.size.z) * s
				cyl.radius = clampf(footprint * (0.12 if is_tree else 0.38), 0.3, 2.5)
				cyl.height = 4.0
				cs.shape = cyl
				cs.position = Vector3(x, 2.0, z)
				colliders.add_child(cs)
		for key in groups.keys():
			var rows: Array = groups[key]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = rows.size()
			for i in rows.size():
				var r: Array = rows[i]
				var sc: float = float(r[3])
				var b := Basis(Vector3.UP, deg_to_rad(float(r[2]))).scaled(Vector3(sc, sc, sc))
				mm.set_instance_transform(i, Transform3D(b, Vector3(float(r[0]), 0.0, float(r[1]))) * local_xf)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			var near_flag: bool = str(key).ends_with("_1")
			if is_grass:
				mmi.visibility_range_end = 38.0
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			elif is_bush:
				mmi.visibility_range_end = 70.0
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			else:
				mmi.visibility_range_end = 135.0
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if near_flag \
						else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end_margin = 6.0
			add_child(mmi)


# ------------------------------------------------------------------ boundary
func _build_boundary() -> void:
	var body := StaticBody3D.new()
	body.name = "WorldBounds"
	body.collision_layer = 16     # characters collide with it, the camera arm does not
	body.collision_mask = 0
	for seg in data.get("boundary", []):
		var a := Vector2(float(seg[0][0]), float(seg[0][1]))
		var b := Vector2(float(seg[1][0]), float(seg[1][1]))
		var d := b - a
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, 8.0, d.length() + 0.6)
		cs.shape = box
		var mid := (a + b) * 0.5
		cs.position = Vector3(mid.x, 4.0, mid.y)
		cs.rotation.y = atan2(d.x, d.y)
		body.add_child(cs)
	add_child(body)


# ------------------------------------------------------------------ labels & clouds
func _build_labels() -> void:
	for lb in data.get("labels", []):
		var l := Label3D.new()
		l.text = str(lb["text"])
		var p: Array = lb["p"]
		l.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 72
		l.outline_size = 18
		l.pixel_size = 0.012
		l.modulate = Color(1.0, 0.95, 0.8)
		l.outline_modulate = Color(0.08, 0.06, 0.15)
		l.visibility_range_end = 55.0
		add_child(l)


func _build_clouds() -> void:
	for c in data.get("clouds", []):
		var ps := _scene("medieval/" + str(c[3]))
		if ps == null:
			continue
		var n: Node3D = ps.instantiate()
		n.position = Vector3(float(c[0]), float(c[1]), float(c[2]))
		n.scale = Vector3.ONE * float(c[4])
		_set_shadows(n, false)
		add_child(n)
		_clouds.append(n)
