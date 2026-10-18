extends Node3D
class_name PlayerAvatar
const SAVE := "user://player_avatar.json"
const MODELS := ["Knight","Mage","Rogue","Barbarian"]
var display_name := "Thomas"
var appearance := "Knight"
var created := false
var conversations: Dictionary = {}
var memories: Dictionary = {}
var health := 100.0
var experience := 0
var world_extent := 1000.0
var attack_cooldown := 0.0
var visual_root: Node3D
var wave_cooldown := 0.0
var model: Node3D
var animator: AnimationPlayer
var name_label: Label3D
var world: WorldConductor
var view_camera: Camera3D
var joystick := Vector2.ZERO
var destination := Vector3.ZERO
var has_destination := false
var save_clock := 0.0
var crouched := false
var jump_time := 0.0
var action_time := 0.0
var model_base_y := 0.0

func _ready() -> void:
	position = Vector3(2,0,5)
	load_profile()
	position.y = VillageScenery.walk_height(position.x,position.z)
	visual_root = Node3D.new()
	add_child(visual_root)
	add_to_group("world_observable")
	set_meta("world_id",display_name)
	set_meta("kind","habitant_joueur")
	name_label = Label3D.new()
	name_label.position.y = 2.35
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.font_size = 40
	name_label.pixel_size = 0.012
	add_child(name_label)
	set_appearance(appearance)

func set_appearance(choice: String) -> bool:
	if choice not in MODELS: return false
	appearance = choice
	if model: model.queue_free()
	model = WorldAssets.instantiate_model("res://packs/kaykit-character-pack-adventures-1.0/addons/kaykit_character_pack_adventures/Characters/gltf/"+appearance+".glb",1.9)
	if not model: return false
	visual_root.add_child(model)
	model_base_y = model.position.y
	if appearance == "Knight": _blue_cape(model)
	animator = _find_animation(model)
	WorldAssets.settle_actor(model,animator,1.9)
	name_label.text = ""
	set_meta("world_id",display_name)
	model.rotation.y = PI
	_play("Idle")
	return true

func _find_animation(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var found := _find_animation(child)
		if found: return found
	return null

func _play(clip: String) -> void:
	if action_time>0 and clip in ["Idle","Walking_A"]: return
	if animator and animator.has_animation(clip) and animator.current_animation != clip:
		animator.play(clip)

func move_input(direction: Vector2, delta: float) -> void:
	if direction.length() < 0.05:
		_play("Idle")
		return
	has_destination = false
	var right := Vector3(view_camera.global_basis.x.x,0,view_camera.global_basis.x.z).normalized()
	var forward := Vector3(view_camera.global_basis.z.x,0,view_camera.global_basis.z.z).normalized()
	var heading := (right*direction.x+forward*direction.y).normalized()
	var next := world.steer(position,position+heading*3,delta*(2.0 if crouched else 4.2),false)
	position = Vector3(clampf(next.x,-world_extent,world_extent),VillageScenery.walk_height(next.x,next.z),clampf(next.z,-world_extent,world_extent))
	model.rotation.y = atan2(heading.x,heading.z)
	_play("Walking_A")

func _physics_process(delta: float) -> void:
	action_time = maxf(0,action_time-delta)
	if jump_time>0:
		jump_time = maxf(0,jump_time-delta)
		visual_root.position.y = sin((1.0-jump_time/0.75)*PI)*1.1
	else:
		visual_root.position.y = 0
	visual_root.scale.y = lerpf(visual_root.scale.y,0.62 if crouched else 1.0,minf(1,delta*18))
	wave_cooldown = maxf(0,wave_cooldown-delta)
	position.y = VillageScenery.walk_height(position.x,position.z)
	attack_cooldown = maxf(0,attack_cooldown-delta)
	if position.length()<30: health = minf(100,health+delta)
	var direction := joystick
	if not get_viewport().gui_get_focus_owner() is LineEdit:
		direction += Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_Z) or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if direction.length() > 0.05:
		move_input(direction.limit_length(),delta)
	elif has_destination:
		var remaining := destination-position
		if remaining.length() <= 0.25:
			has_destination = false
			_play("Idle")
		else:
			position = world.steer(position,destination,delta*(2.0 if crouched else 4.2))
			model.rotation.y = atan2(remaining.x,remaining.z)
			_play("Walking_A")
	else:
		_play("Idle")
	position.y = VillageScenery.walk_height(position.x,position.z)
	save_clock += delta
	if save_clock >= 5:
		save_clock = 0
		save_profile()

func remember(target: String, role: String, text: String) -> void:
	if role == "user": NpcMemory.remember(memories,target,text)
	if not conversations.has(target): conversations[target] = []
	conversations[target].append({"role":role,"content":text.left(600)})
	while conversations[target].size() > 12: conversations[target].pop_front()
	save_profile()

func save_profile() -> void:
	StateStore.write_json(SAVE,{"name":display_name,"appearance":appearance,"created":created,"position":[position.x,position.z],"conversations":conversations,"memories":memories,"health":health,"experience":experience})

func load_profile() -> void:
	var data := StateStore.read_json(SAVE)
	if data.is_empty(): return
	display_name = str(data.get("name",display_name)).left(24)
	appearance = str(data.get("appearance",appearance))
	if appearance not in MODELS: appearance = "Rogue"
	created = bool(data.get("created",false))
	var p = data.get("position",[2,5])
	if p is Array and p.size() == 2: position = Vector3(clampf(float(p[0]),-world_extent,world_extent),0,clampf(float(p[1]),-world_extent,world_extent))
	if data.get("conversations",{}) is Dictionary: conversations = data.get("conversations",{})

	if data.get("memories",{}) is Dictionary: memories = data.get("memories",{})
	health = clampf(float(data.get("health",100)),1,100)
	experience = maxi(0,int(data.get("experience",0)))

func take_damage(amount: float) -> void:
	health = maxf(0,health-maxf(0,amount))
	if health <= 0:
		position = Vector3(2,0,5)
		health = 100
		has_destination = false
		joystick = Vector2.ZERO
		save_profile()

func strike(realm: WorldStream) -> bool:
	if attack_cooldown>0: return false
	var nearest: Node3D
	var distance := 3.0
	for creature in realm.creatures.values():
		var d: float = position.distance_to(creature.position)
		if float(creature.state.health)>0 and d<distance and WorldEyes.has_line_of_sight(self,creature):
			nearest = creature
			distance = d
	attack_cooldown = 0.7
	action_time = 0.65
	_play("1H_Melee_Attack_Chop")
	CombatEffect.spawn(get_parent(),position+Vector3.UP*0.7,1.8)
	if nearest: nearest.take_damage(18)
	return true

func jump() -> void:
	if jump_time>0 or crouched: return
	jump_time = 0.75
	_play("Jump_Full_Short")
	action_time = 0.75

func toggle_crouch() -> void:
	crouched = not crouched

func _blue_cape(node: Node3D) -> void:
	if node is MeshInstance3D and node.mesh:
		for i in range(node.mesh.get_surface_count()):
			var original: Material = node.get_active_material(i)
			if original is StandardMaterial3D and original.albedo_texture:
				var material := ShaderMaterial.new()
				material.shader = load("res://loic/shaders/knight_cape.gdshader")
				material.set_shader_parameter("albedo",original.albedo_texture)
				node.set_surface_override_material(i,material)
	for child in node.get_children():
		if child is Node3D: _blue_cape(child)

func cast_wave(realm: WorldStream) -> bool:
	if wave_cooldown>0: return false
	wave_cooldown = 6
	_play("Spellcast_Raise")
	action_time = 0.8
	CombatEffect.spawn(get_parent(),position+Vector3.UP*0.1,5.0)
	for creature in realm.creatures.values():
		if float(creature.state.health)>0 and creature.position.distance_to(position)<5 and WorldEyes.has_line_of_sight(self,creature): creature.take_damage(32)
	return true
