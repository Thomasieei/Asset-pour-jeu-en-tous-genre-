extends Node3D
class_name WorldCreature
const ACTIONS := ["observer","patrouiller","menacer","attaquer","fuir","se_reposer"]
var realm: Node3D
var state: Dictionary = {}
var action := "observer"
var motive := "J'observe mon territoire."
var model: Node3D
var animator: AnimationPlayer
var label: Label3D
var destination := Vector3.ZERO
var decision_clock := 0.0
var thought_clock := 0.0
var attack_clock := 0.0
var pending := false

func _ready() -> void:
	position = Vector3(float(state.position[0]),0,float(state.position[1]))
	model = WorldAssets.instantiate_model("res://packs/kaykit-character-pack-skeletons-1.0/addons/kaykit_character_pack_skeletons/Characters/gltf/"+str(state.model)+".glb",2.0)
	if model:
		add_child(model)
		animator = _find_anim(model)
		WorldAssets.settle_actor(model,animator,2.0)
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 2.55
	label.font_size = 32
	label.pixel_size = 0.005
	add_child(label)
	set_meta("world_id",str(state.name))
	set_meta("kind","monstre_individuel")
	add_to_group("world_observable")
	destination = home()
	thought_clock = float(int(state.id)%9)

func _find_anim(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var found := _find_anim(child)
		if found: return found
	return null

func home() -> Vector3:
	return Vector3(float(state.home[0]),0,float(state.home[1]))

func facts() -> Dictionary:
	return {"nom":state.name,"caractere":state.personality,"vie":state.health,"faim":state.hunger,"confiance_joueur":state.trust,"territoire":state.home,"action":action,"souvenirs":state.memories.slice(-5),"position":[position.x,position.z],"distance_joueur":position.distance_to(realm.avatar.position)}

func _physics_process(delta: float) -> void:
	if float(state.health)<=0: return
	position.y = VillageScenery.walk_height(position.x,position.z)
	attack_clock = maxf(0,attack_clock-delta)
	decision_clock += delta
	thought_clock += delta
	state.hunger = minf(100,float(state.hunger)+delta*0.025)
	var distance: float = position.distance_to(realm.avatar.position)
	if decision_clock>4:
		decision_clock = 0
		decide_by_rules()
	if not LoicAIConfig.local_mode() and thought_clock>45 and distance<15 and realm.can_think():
		thought_clock = 0
		think()
	if action in ["patrouiller","attaquer","fuir"]:
		if action == "attaquer": destination = realm.avatar.position
		elif action == "fuir": destination = home()+(home()-realm.avatar.position).normalized()*6
		var heading := destination-position
		if heading.length()>1.5:
			position = realm.host.conductor.steer(position,destination,delta*(3.8 if action == "fuir" else 2.5))
			if model: model.rotation.y = atan2(heading.x,heading.z)
			_play("Walking_A")
		else: _play("Idle")
	if action == "attaquer" and position.distance_to(realm.avatar.position)<=2.3 and attack_clock<=0 and realm.avatar.position.length()>28 and WorldEyes.has_line_of_sight(self,realm.avatar):
		attack_clock = 2.2
		realm.avatar.take_damage(8)
		_play("1H_Melee_Attack_Chop")
	elif action == "se_reposer":
		state.health = minf(65,float(state.health)+delta*0.3)
		state.hunger = maxf(0,float(state.hunger)-delta*0.05)
		_play("Idle")
	elif action in ["observer","menacer"]: _play("Idle")
	label.text = str(state.name)+" · %d PV" % int(state.health)
	position.y = VillageScenery.walk_height(position.x,position.z)
	state.position = [position.x,position.z]

func _play(clip: String) -> void:
	if animator and animator.has_animation(clip) and animator.current_animation != clip: animator.play(clip)

func decide_by_rules() -> void:
	var distance: float = position.distance_to(realm.avatar.position)
	if float(state.health)<18:
		action = "fuir"
	elif realm.avatar.position.length()<28 or position.distance_to(home())>20:
		action = "patrouiller"
		destination = home()
	elif distance<5.5 and (float(state.trust)<-5 or float(state.aggression)>0.65) and float(state.trust)<4:
		action = "attaquer"
	elif distance<8 and float(state.aggression)>0.65 and float(state.trust)<4:
		action = "menacer"
	elif distance<8:
		action = "observer"
	elif float(state.hunger)>70 or float(state.health)<40:
		action = "se_reposer"
	else:
		action = "patrouiller"
		var phase := float(Time.get_ticks_msec())*0.0002+float(state.id)
		destination = home()+Vector3(cos(phase),0,sin(phase))*7

func accept_intent(intent: String, reason: String) -> bool:
	if intent not in ACTIONS or float(state.health)<=0: return false
	if intent == "attaquer" and (float(state.trust)>=0 or realm.avatar.position.length()<28 or position.distance_to(realm.avatar.position)>12): return false
	action = intent
	motive = reason.left(120)
	return true

func think() -> void:
	if pending or not LoicAIConfig.local_mode() or not LoicAIConfig.enabled(): return
	var schema := {"type":"object","properties":{"action":{"type":"string","enum":ACTIONS},"motive":{"type":"string"}},"required":["action","motive"],"additionalProperties":false}
	var body := {"messages":[{"role":"system","content":"Tu choisis une intention pour un monstre individuel. Respecte sa personnalité, ses souvenirs et ses besoins. JSON action et motive en français uniquement. /no_think"},{"role":"user","content":JSON.stringify(facts())}],"max_tokens":100,"response_format":{"type":"json_schema","json_schema":{"schema":schema}}}
	var err: Error = get_tree().root.get_node("LocalModel").request(body,_response,0,"creature_"+str(state.id))
	pending = err == OK

func _response(result: int, code: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
	pending = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200: return
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK or not parser.data is Dictionary: return
	var choices = parser.data.get("choices",[])
	if not choices is Array or choices.is_empty(): return
	var text := str(choices[0].get("message",{}).get("content",""))
	if parser.parse(text) == OK and parser.data is Dictionary:
		accept_intent(str(parser.data.get("action","")),str(parser.data.get("motive","")))

func hear(text: String, player_name: String) -> void:
	var lower := text.to_lower()
	if "bonjour" in lower or "paix" in lower or "ami" in lower: state.trust = minf(25,float(state.trust)+2)
	if "te tuer" in lower or "attaque" in lower:
		state.trust = maxf(-30,float(state.trust)-10)
	state.memories.append(player_name+" m'a dit : "+text.left(140))
	while state.memories.size()>16: state.memories.pop_front()
	decide_by_rules()
	realm.save_state()

func take_damage(amount: float) -> void:
	if float(state.health)<=0: return
	state.health = maxf(0,float(state.health)-maxf(0,amount))
	state.trust = -20
	state.memories.append("Le joueur m'a attaqué.")
	while state.memories.size()>16: state.memories.pop_front()
	if float(state.health)<=0:
		realm.avatar.experience += 25
		realm.avatar.save_profile()
		hide()
	else: decide_by_rules()
	realm.save_state()
