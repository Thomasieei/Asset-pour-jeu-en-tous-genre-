extends SceneTree
var failures: Array[String] = []
var checks := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
	print(("PASS " if ok else "FAIL ") + description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: Node3D = load("res://loic/scenes/monde_loic.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var world: WorldConductor = scene.conductor
	world.use_qwen = false
	world.set_physics_process(false)
	scene.brain.enabled = false
	scene.loic.set_process(false)
	for worker in world.workers: worker.set_physics_process(false)
	check(WorldAssets.catalogue("",4000).size() >= 35,"Full or curated asset catalogue discoverable")
	check(scene.loic.player_anim != null,"Knight contains real AnimationPlayer")
	check(world.workers.size() == 2,"Two visible workers instantiated")
	var before := world.bois
	check(not world.propose("execute_code","invalid"),"Unknown action rejected")
	check(world.bois == before,"Rejected order cannot mutate stocks")
	check(world.propose("construire_maison","test"),"Building accepted")
	check(world.bois == before-20,"Construction cost reserved once")
	var worker: WorldWorker = world.workers[0]
	check(not worker.job.is_empty(),"Order reaches actual resident")
	var p: Array = worker.job.position
	var start := worker.position
	worker._physics_process(0.2)
	check(worker.position.distance_to(start)>0,"Resident walks toward job")
	var count := world.constructions.size()
	worker.position = Vector3(p[0],0,p[2])+Vector3(1,0,0)
	worker._physics_process(20)
	check(world.constructions.size() == count+1,"Arrival and work produce building in Godot")
	check(world.visual_nodes.size()==world.constructions.size(),"Every construction has a live scene node")
	before = world.nourriture
	check(world.propose("cultiver_champ","test"),"Field job accepted")
	for w in world.workers:
		if not w.job.is_empty():
			var at: Array = w.job.position
			w.position = Vector3(at[0],0,at[2])+Vector3(1,0,0)
			w._physics_process(20)
	check(world.nourriture == before,"Planting creates no instant food")
	check(not world.propose("recolter","too early"),"Unripe crops cannot be harvested")
	world._physics_process(75)
	world.set_physics_process(false)
	# Remove planner jobs created by the simulated cycle to isolate harvest.
	world.work_queue.clear()
	for w in world.workers:
		w.job = {}
		w.fatigue = 0
	check(world.propose("recolter","test"),"Ripe crop harvest accepted")
	before = world.nourriture
	for w in world.workers:
		if not w.job.is_empty():
			var at: Array = w.job.position
			w.position = Vector3(at[0],0,at[2])+Vector3(1,0,0)
			w._physics_process(20)
	check(world.nourriture == before+40,"Harvest yields food after worker completes it")
	world.bois = 0
	check(not world.propose("construire_maison","test"),"Unaffordable building rejected")
	check(world.propose("ramasser_bois","test"),"Mature forest supports wood gathering")
	for w in world.workers:
		if not w.job.is_empty():
			var at: Array = w.job.position
			w.position = Vector3(at[0],0,at[2])+Vector3(1,0,0)
			w._physics_process(20)
	check(world.bois==28,"Gathering replenishes building resources")
	world.autonomous = false
	check(not world.propose("planter_arbre","paused"),"Pause blocks new orders")
	var age := world.world_age
	world._physics_process(20)
	check(world.world_age==age,"Pause freezes world clock")
	world.autonomous = true
	world.bois = 100
	check(world.propose("construire_atelier","resume"),"Pending job prepared for save")
	world.save_world()
	var clone := WorldConductor.new()
	root.add_child(clone)
	clone.set_physics_process(false)
	clone.use_qwen = false
	check(clone.constructions.size()==world.constructions.size(),"Constructions survive reload")
	check(clone.work_queue.size()==world.work_queue.size(),"Pending job survives reload")
	check(clone.bois==world.bois,"Stocks survive reload")
	check(not clone.workers[0].job.is_empty(),"Reloaded job reassigned to real worker")
	check(not scene.loic.choisir("dormir"),"Loic cannot sleep outside home")
	check(WorldEyes.observe(scene.loic,80).visibles.size()>0,"Eyes perceive real nearby scene objects")
	# Verify line of sight with a known obstruction.
	var target := Node3D.new()
	target.position = Vector3(0,0,7)
	target.set_meta("world_id","occlusion_target")
	target.add_to_group("world_observable")
	scene.add_child(target)
	scene.loic.position = Vector3.ZERO
	await physics_frame
	var visible_before := JSON.stringify(WorldEyes.observe(scene.loic))
	var blocker := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4,5,1)
	collision.shape = box
	blocker.add_child(collision)
	blocker.position = Vector3(0,1,3)
	scene.add_child(blocker)
	await physics_frame
	await physics_frame
	check("occlusion_target" in visible_before and "occlusion_target" not in JSON.stringify(WorldEyes.observe(scene.loic)),"Walls occlude resident perception")
	# Simulate 30 minutes through the same clock, movement and work methods.
	world.use_qwen = false
	var lowest_food := world.nourriture
	for step in range(9000):
		world._physics_process(0.2)
		for resident in world.workers:
			resident._physics_process(0.2)
		lowest_food = mini(lowest_food,world.nourriture)
	check(world._count("construire_maison") >= 2,"Autonomous planner develops housing over time")
	check(world._count("cultiver_champ") >= 3,"Autonomous planner develops agriculture")
	check(lowest_food > 0,"Thirty simulated minutes without food depletion")
	check(world.bois >= 0 and world.pierre >= 0,"Autonomous economy never spends negative stocks")
	check(world.constructions.size() <= WorldConductor.MAX_ENTITIES,"World entity budget respected")
	var result := {"checks":checks,"failures":failures,"godot":Engine.get_version_info().string}
	print(JSON.stringify(result))
	var output := OS.get_environment("LOIC_TEST_REPORT")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(result,"  "))
	clone.queue_free()
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
