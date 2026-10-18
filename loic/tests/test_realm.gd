extends SceneTree
var checks := 0
var failures: Array[String] = []
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures.append(text)
	print(("PASS " if ok else "FAIL ")+text)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene: Node3D = load("res://loic/scenes/monde_loic.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	var realm: WorldStream = scene.realm
	scene.avatar.set_physics_process(false)
	scene.loic.set_process(false)
	scene.brain.enabled = false
	scene.conductor.set_physics_process(false)
	check(realm.records.size()==32,"32 named persistent creatures exist")
	var names: Dictionary = {}
	for record in realm.records: names[record.name] = true
	check(names.size()==32,"Creature names are unique")
	check(scene.avatar.world_extent==1000,"World extends one kilometre from village in each direction")
	for i in range(12):
		realm._process(0.2)
		await process_frame
	check(realm.chunks.size()==9,"Only nine nearby zones loaded")
	check(realm.creatures.size()<=6,"Creature simulation budget respected")
	var old_keys := realm.chunks.keys()
	realm.travel(4)
	for i in range(12):
		realm._process(0.2)
		await process_frame
	check(scene.avatar.position.x==700 and scene.avatar.position.z==300,"Travel reaches distant region")
	check(realm.chunks.size()==9,"Streaming budget stays bounded after long travel")
	var overlap := false
	for key in old_keys:
		if realm.chunks.has(key): overlap = true
	check(not overlap,"Old terrain zones unloaded")
	realm.travel(1)
	for i in range(10): realm._process(0.2)
	await physics_frame
	var creature: WorldCreature = realm.find_creature("Silex")
	check(creature!=null,"Silex becomes an actual nearby character")
	if creature:
		creature.set_physics_process(false)
		scene.avatar.position = creature.position+Vector3(1.5,0,0)
		var previous := float(creature.state.trust)
		creature.hear("Bonjour, je viens en paix","Thomas")
		check(float(creature.state.trust)>previous,"Monster trust reacts to peaceful words")
		check(not creature.accept_intent("attaquer","test"),"Friendly monster rejects unjustified attack intention")
		var hp := float(creature.state.health)
		check(scene.avatar.strike(realm),"Player can strike a nearby real creature")
		check(float(creature.state.health)==hp-15,"Monster receives distance checked damage")
		check(not scene.avatar.strike(realm),"Attack cooldown prevents repeated instant hits")
		check(float(creature.state.trust)<0,"Attack changes monster relationship")
		creature.state.health = 10
		creature.decide_by_rules()
		check(creature.action=="fuir","Wounded monster chooses to flee")
		realm.save_state()
		var saved := StateStore.read_json(WorldStream.SAVE)
		check(saved.creatures[0].memories.size()>=2,"Monster experiences saved independently")
		scene.avatar.position = Vector3(700,0,300)
		realm.update_focus(true)
		await process_frame
		scene.avatar.position = Vector3(80,0,45)
		realm.update_focus(true)
		creature = realm.find_creature("Silex")
		check(creature!=null and float(creature.state.health)==10,"Monster identity and health survive unloading")
	check(not DialogueGuard.accepts("Je suis la mère de Thomas","Bonjour"),"Invented family relationship rejected")
	check(not DialogueGuard.accepts("Bonjour, ton nom ?","Bonjour, ton nom ?"),"Question echo rejected")
	var memory: Dictionary = {}
	NpcMemory.remember(memory,"Loïc","J'aime les pommes et les vergers")
	NpcMemory.remember(memory,"Loïc","Je préfère les montagnes")
	var recall := NpcMemory.recall(memory,"Loïc","Quels vergers et pommes ?",1)
	check(recall.size()==1 and "pommes" in str(recall[0]),"Relevant older memory retrieved by topic")
	for i in range(80): NpcMemory.remember(memory,"Loïc","Je suis le visiteur "+str(i))
	check(memory["Loïc"].size()==60,"Long term memory stays bounded")
	var path := "user://recovery_test.json"
	check(StateStore.write_json(path,{"value":1}) and StateStore.write_json(path,{"value":2}),"Atomic save writes and backs up")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string("interrupted {")
	file.close()
	check(StateStore.read_json(path).get("value")==1,"Corrupt current save recovers from previous complete copy")
	StateStore.write_json(path,{"value":3})
	check(StateStore.read_json(path+".bak").get("value")==1,"Recovery write preserves the last valid backup")
	scene.avatar.take_damage(1000)
	check(scene.avatar.health==100 and scene.avatar.position.length()<10,"Defeated player returns safely to village")
	var report := FileAccess.open(OS.get_environment("LOIC_TEST_REPORT"),FileAccess.WRITE)
	if report: report.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	scene.queue_free()
	await process_frame
	WorldAssets.loaded.clear()
	await process_frame
	quit(0 if failures.is_empty() else 1)
