extends SceneTree
var checks: Array = []
var failed: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
 checks.append({"test":title,"passed":ok})
 if not ok: failed.append(title)
func feet(model: Node3D) -> float:
 var nodes = [model]
 var y := INF
 while not nodes.is_empty():
  var n = nodes.pop_back()
  if n is Skeleton3D:
   n.force_update_all_bone_transforms()
   for i in range(n.get_bone_count()):
    if str(n.get_bone_name(i)) in ["toes.l","toes.r"]: y = minf(y,(n.global_transform*n.get_bone_global_pose(i)).origin.y)
  nodes.append_array(n.get_children())
 return y
func run() -> void:
 var scene = load("res://loic/scenes/monde_loic.tscn").instantiate()
 root.add_child(scene)
 scene.conductor.autonomous = false
 scene.brain.enabled = false
 for worker in scene.conductor.workers: worker.set_physics_process(false)
 await create_timer(0.6).timeout
 check(absf(feet(scene.avatar.model)-scene.avatar.position.y)<0.10,"Pieds du joueur au sol après animation")
 check(absf(feet(scene.loic.visual)-scene.loic.position.y)<0.10,"Pieds de Loïc au sol après animation")
 check(scene.realm.records.size()==192,"192 créatures persistantes")
 check(scene.realm.creatures.size()>=5,"Créatures présentes près du départ")
 check(scene.realm.creatures.size()<=12,"Budget de créatures actives borné")
 scene.avatar.jump()
 await create_timer(0.2).timeout
 check(scene.avatar.visual_root.position.y>0.4,"Saut déplace visiblement le personnage")
 await create_timer(0.65).timeout
 check(absf(scene.avatar.visual_root.position.y)<0.03,"Retour au sol après saut")
 scene.avatar.toggle_crouch()
 await create_timer(0.25).timeout
 check(scene.avatar.visual_root.scale.y<0.7,"Accroupissement modifie réellement la pose")
 scene.avatar.toggle_crouch()
 await create_timer(0.25).timeout
 check(scene.avatar.visual_root.scale.y>0.95,"Retour debout")
 var enemy = scene.realm.creatures.values()[0]
 enemy.set_physics_process(false)
 enemy.position = scene.avatar.position+Vector3(0,0,-2)
 enemy.state.health = 65
 scene.avatar.attack_cooldown = 0
 check(scene.avatar.strike(scene.realm),"Attaque acceptée")
 check(float(enemy.state.health)==47,"Attaque enlève effectivement 18 PV")
 check(not scene.avatar.strike(scene.realm),"Recharge empêche les coups instantanés")
 check(get_nodes_in_group("combat_effect").size()>0,"Effet de frappe créé dans le monde")
 enemy.state.health = 65
 scene.avatar.cast_wave(scene.realm)
 check(float(enemy.state.health)==33,"Onde de choc enlève effectivement 32 PV")
 check(not scene.avatar.cast_wave(scene.realm),"Recharge de l’onde appliquée")
 check(scene.avatar.animator.current_animation=="Spellcast_Raise","Animation de compétence réellement jouée")
 for point in [Vector2(5,5),Vector2(-20,-30)]:
  var sample = VillageScenery.ground_height(point.x,point.y)
  var query = PhysicsRayQueryParameters3D.create(Vector3(point.x,30,point.y),Vector3(point.x,-10,point.y),2)
  var hit = scene.get_world_3d().direct_space_state.intersect_ray(query)
  check(not hit.is_empty() and absf(hit.position.y-sample)<0.03,"Sol physique et visuel identiques : "+str(point))
 scene.avatar.position = Vector3(150,0,50)
 scene.realm.update_focus(true)
 scene.realm._create_chunk(Vector2i(2,0))
 await physics_frame
 await physics_frame
 var ray = PhysicsRayQueryParameters3D.create(Vector3(150,30,50),Vector3(150,-10,50),2)
 var distant = scene.get_world_3d().direct_space_state.intersect_ray(ray)
 check(not distant.is_empty() and absf(distant.position.y-VillageScenery.ground_height(150,50))<0.03,"Sol continu au-delà de l’ancien carré du village")
 check(scene.player_ui.wave_button!=null,"Bouton de compétence accessible")
 var report = {"checks":checks,"failures":failed,"platform":"Linux headless; Android untested"}
 var f = FileAccess.open("res://loic/tests/validation_correctifs.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(report,"  "))
 print("REPORT ",JSON.stringify(report))
 quit(0 if failed.is_empty() else 1)
