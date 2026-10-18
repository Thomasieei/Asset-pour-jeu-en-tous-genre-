extends Node3D
class_name WorldWorker
var worker_name := "Élise"
var job: Dictionary = {}
var model: Node3D
var label: Label3D
var time := 0.0
var eyes_clock := 0.0
var fatigue := 0.0
var eyes: Dictionary = {}
var world: Node3D
var player: AnimationPlayer

func _ready() -> void:
	add_to_group("world_observable")
	set_meta("world_id", worker_name)
	set_meta("kind", "habitant")
	var file := "Mage" if worker_name == "Élise" else "Rogue"
	model = WorldAssets.instantiate_model("res://packs/kaykit-character-pack-adventures-1.0/addons/kaykit_character_pack_adventures/Characters/gltf/"+file+".glb",1.8)
	if model:
		add_child(model)
		player = _find_player(model)
	label = Label3D.new()
	label.position.y = 2.2
	label.font_size = 32
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found:
			return found
	return null

func animate(hint: String) -> void:
	if player:
		var exact: String = {"idle":"Idle","walk":"Walking_A","interact":"Interact"}.get(hint,hint)
		if player.has_animation(exact):
			if player.current_animation != exact: player.play(exact)
			return
		for clip in player.get_animation_list():
			if hint in clip.to_lower():
				if player.current_animation != clip:
					player.play(clip)
				return

func available() -> bool:
	return job.is_empty() and fatigue < 75

func _physics_process(delta: float) -> void:
	time += delta
	eyes_clock += delta
	if eyes_clock>=3:
		eyes_clock = 0
		eyes = WorldEyes.observe(self)
	if job.is_empty():
		fatigue = maxf(0,fatigue - delta * 4)
		label.text = worker_name
		animate("idle")
		return
	var p: Array = job.position
	var destination := Vector3(float(p[0]),0,float(p[2]))
	var direction := destination - position
	if direction.length() > 1.7:
		# Steering avoids occupied building footprints on the flat prototype terrain.
		var next: Vector3 = world.steer(position, destination, delta * 3.0)
		if model:
			model.rotation.y = atan2(next.x-position.x,next.z-position.z)
		position = next
		animate("walk")
		label.text = worker_name
	else:
		animate("interact")
		job.progress = float(job.progress) + delta
		fatigue = minf(100,fatigue + delta * 0.6)
		label.text = worker_name
		if float(job.progress) >= float(job.duration):
			var done := job
			job = {}
			world.complete_project(done)
