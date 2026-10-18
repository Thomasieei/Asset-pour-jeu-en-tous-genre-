extends Node3D
class_name PlayerAvatar
const SAVE := "user://player_avatar.json"
const MODELS := ["Knight","Mage","Rogue","Barbarian"]
var display_name := "Thomas"
var appearance := "Rogue"
var created := false
var conversations: Dictionary = {}
var memories: Dictionary = {}
var health := 100.0
var experience := 0
var world_extent := 1000.0
var attack_cooldown := 0.0
var model: Node3D
var animator: AnimationPlayer
var name_label: Label3D
var world: WorldConductor
var view_camera: Camera3D
var joystick := Vector2.ZERO
var destination := Vector3.ZERO
var has_destination := false
var save_clock := 0.0

func _ready() -> void:
	position = Vector3(2,0,5)
	load_profile()
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
	add_child(model)
	animator = _find_animation(model)
	name_label.text = display_name + " · toi"
	set_meta("world_id",display_name)
	_play("Idle")
	return true

func _find_animation(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var found := _find_animation(child)
		if found: return found
	return null

func _play(clip: String) -> void:
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
	var next := world.steer(position,position+heading*3,delta*4.2)
	position = Vector3(clampf(next.x,-world_extent,world_extent),0,clampf(next.z,-world_extent,world_extent))
	model.rotation.y = atan2(heading.x,heading.z)
	_play("Walking_A")

func _physics_process(delta: float) -> void:
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
			position = world.steer(position,destination,delta*4.2)
			model.rotation.y = atan2(remaining.x,remaining.z)
			_play("Walking_A")
	else:
		_play("Idle")
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
	if not nearest: return false
	attack_cooldown = 1.2
	_play("1H_Melee_Attack_Chop")
	nearest.take_damage(15)
	return true
