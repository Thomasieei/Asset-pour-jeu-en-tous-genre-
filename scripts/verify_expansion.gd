extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://catalog.json"))
	var failures: Array=[]
	var checked := 0
	for model in catalog.models:
		if model.get("godot_verified",false): continue
		var resource=load("res://"+model.path)
		model.godot_verified=resource is PackedScene and resource.can_instantiate()
		if not model.godot_verified: failures.append(model.path)
		checked+=1
	for asset in catalog.assets:
		var resource=load("res://"+asset.path)
		asset.godot_verified=resource!=null
		if not asset.godot_verified: failures.append(asset.path)
		if asset.format in ["wav","ogg","mp3"] and resource is AudioStream:
			asset.duration=resource.get_length()
			if asset.duration<=0: failures.append(asset.path+" zero duration")
		if asset.format=="tscn" and resource is PackedScene:
			var instance=resource.instantiate()
			root.add_child(instance)
			await process_frame
			instance.queue_free()
	for pack in catalog.packs:
		pack.godot_import_tested=true
		for model in catalog.models:
			if model.pack==pack.id and not model.godot_verified: pack.godot_import_tested=false
		for asset in catalog.assets:
			if asset.pack==pack.id and not asset.godot_verified: pack.godot_import_tested=false
	var out=FileAccess.open("res://catalog.json",FileAccess.WRITE)
	out.store_string(JSON.stringify(catalog,"  "))
	out.close()
	print("NEW_MODELS_CHECKED=",checked," ASSETS_CHECKED=",catalog.assets.size()," FAILURES=",failures.size())
	for fail in failures:print("FAIL ",fail)
	quit(0 if failures.is_empty() else 1)
