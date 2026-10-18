extends Node
signal status_changed(text: String)
const MODEL := "res://loic/native/models/Qwen3-0.6B-Q4_K_M.gguf"
const MODEL_SIZE := 396704416
const MODEL_SHA := "15e434d8ddf0af38fe3f7003af6ce6eac4edada6df34324aa45979f9cc79f02e"
var status := "IA locale en attente"
var queue: Array = []
var thread: Thread
var backend: Object
var active: Dictionary = {}
var loaded := false
var failed := false
var completed := 0
var last_duration := 0.0
var suspended := false
var active_canceled := false

func _ready() -> void:
	if LoicAIConfig.local_mode() and LoicAIConfig.enabled():
		queue.append({"warmup":true})

func request(body: Dictionary, callback: Callable, priority: int = 1, key: String = "") -> Error:
	if failed or not ClassDB.class_exists("LoicLocalAI"): return ERR_UNAVAILABLE
	if not key.is_empty():
		for job in queue:
			if job.get("key","") == key:
				job.body = body.duplicate(true)
				job.callback = callback
				job.created = Time.get_ticks_msec()
				return OK
	if queue.size() >= 6: return ERR_BUSY
	queue.append({"body":body.duplicate(true),"callback":callback,"priority":priority,"key":key,"created":Time.get_ticks_msec()})
	queue.sort_custom(func(a: Dictionary,b: Dictionary): return int(a.get("priority",100))>int(b.get("priority",100)))
	return OK

func _process(_delta: float) -> void:
	if suspended: return
	if thread != null and not thread.is_alive():
		var result: Dictionary = thread.wait_to_finish()
		thread = null
		if active_canceled: result["text"] = ""
		last_duration = float(result.get("duration",0))
		completed += 1
		loaded = bool(result.get("loaded",false))
		failed = not loaded
		_set_status("Qwen local prêt · sans Internet" if loaded else "IA indisponible · réponses simples")
		if active.has("callback"):
			var callback: Callable = active.callback
			if callback.is_valid():
				var text := str(result.get("text",""))
				var bytes := JSON.stringify({"choices":[{"message":{"content":text}}]}).to_utf8_buffer()
				callback.call(HTTPRequest.RESULT_SUCCESS if not text.is_empty() else HTTPRequest.RESULT_CANT_CONNECT,200 if not text.is_empty() else 503,PackedStringArray(),bytes)
		active = {}
	if thread == null and not queue.is_empty():
		active = queue.pop_front()
		active_canceled = false
		if not active.get("warmup",false) and Time.get_ticks_msec()-int(active.get("created",0))>45000:
			if active.callback.is_valid(): active.callback.call(HTTPRequest.RESULT_TIMEOUT,408,PackedStringArray(),PackedByteArray())
			active = {}
			return
		if backend == null and ClassDB.class_exists("LoicLocalAI"):
			backend = ClassDB.instantiate("LoicLocalAI")
		if backend == null:
			failed = true
			_set_status("Extension IA absente · réponses simples")
			queue.clear()
			return
		_set_status("Préparation de Qwen… premier démarrage plus long" if not loaded else "Qwen réfléchit…")
		thread = Thread.new()
		thread.start(_infer.bind(active))

func _set_status(text: String) -> void:
	status = text
	status_changed.emit(text)

func _model_present(path: String) -> bool:
	var file := FileAccess.open(path,FileAccess.READ)
	return file != null and file.get_length() == MODEL_SIZE and FileAccess.get_sha256(path)==MODEL_SHA

func _infer(job: Dictionary) -> Dictionary:
	if not loaded:
		var target := "user://Qwen3-0.6B-Q4_K_M.gguf"
		if not _model_present(target):
			var source := FileAccess.open(MODEL,FileAccess.READ)
			var output := FileAccess.open(target+".part",FileAccess.WRITE)
			if not source or not output: return {"loaded":false}
			while source.get_position() < source.get_length():
				output.store_buffer(source.get_buffer(1024*1024))
			output.close()
			if FileAccess.get_sha256(target+".part") != MODEL_SHA: return {"loaded":false}
			if DirAccess.rename_absolute(ProjectSettings.globalize_path(target+".part"),ProjectSettings.globalize_path(target)) != OK: return {"loaded":false}
		if not backend.load_model(ProjectSettings.globalize_path(target),mini(OS.get_processor_count(),4)):
			return {"loaded":false}
	if job.get("warmup",false): return {"loaded":true}
	var body: Dictionary = job.body
	var started := Time.get_ticks_msec()
	var messages: Array = body.get("messages",[]).duplicate(true)
	var prompt := _prompt(messages)
	while backend.token_count(prompt)>1650 and messages.size()>2:
		messages.remove_at(1)
		prompt = _prompt(messages)
	if backend.token_count(prompt)>1800: return {"loaded":true,"text":""}
	var grammar := _grammar(body)
	var text: String = backend.generate(prompt,grammar,mini(int(body.get("max_tokens",120)),160))
	return {"loaded":true,"text":text.strip_edges(),"duration":float(Time.get_ticks_msec()-started)/1000}

func _prompt(messages: Array) -> String:
	var prompt := ""
	for message in messages:
		prompt += "<|im_start|>"+str(message.get("role","user"))+"\n"+str(message.get("content","")).left(4500)+"<|im_end|>\n"
	return prompt+"<|im_start|>assistant\n<think>\n\n</think>\n\n"

func _grammar(body: Dictionary) -> String:
	var format: Dictionary = body.get("response_format",{})
	if format.get("type","") != "json_schema": return ""
	var schema: Dictionary = format.get("json_schema",{}).get("schema",{})
	var properties: Dictionary = schema.get("properties",{})
	var action: Dictionary = properties.get("action",{})
	if not action.has("enum"): return ""
	var options: Array[String] = []
	for name in action.enum:
		options.append(JSON.stringify(JSON.stringify(str(name))))
	var reason := "motive" if properties.has("motive") else "raison"
	var prefix := JSON.stringify("{\"action\":")
	var middle := JSON.stringify(",\""+reason+"\":")
	return "root ::= "+prefix+" ws action ws "+middle+" ws string ws \"}\" ws\n"+"action ::= "+" | ".join(options)+"\n"+"string ::= \"\\\"\" char{0,120} \"\\\"\"\n"+"char ::= [^\"\\\\\\x00-\\x1F] | \"\\\\\" [\"\\\\/bfnrt]\n"+"ws ::= [ \\t\\n\\r]*\n"

func _exit_tree() -> void:
	if backend: backend.cancel()
	if thread != null: thread.wait_to_finish()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		suspended = true
		active_canceled = true
		if backend: backend.cancel()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		suspended = false
