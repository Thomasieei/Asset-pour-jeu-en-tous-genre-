extends Node
## Autoload "Sfx": tiny pooled sound player (non-positional; the camera is always near the action).

const SOUNDS := {
	"hit": ["impactMetal_light_000", "impactMetal_light_001", "impactMetal_light_002"],
	"hit_heavy": ["impactPunch_medium_000"],
	"swing": ["knifeSlice", "knifeSlice2"],
	"step": ["footstep_grass_000", "footstep_grass_001", "footstep_grass_002", "footstep_grass_003"],
	"coins": ["handleCoins"],
	"click": ["click_002"],
	"open": ["open_002"],
	"close": ["close_002"],
	"error": ["error_004"],
	"ok": ["confirmation_002"],
	"extract": ["forceField_000"],
	"extract_fail": ["forceField_001"],
	"summon": ["maximize_006"],
	"draw": ["drawKnife1"],
	"levelup": ["jingles_STEEL00"],
	"rare": ["jingles_PIZZI01"],
}

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _last_play := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in SOUNDS.keys():
		var arr: Array = []
		for n in SOUNDS[key]:
			var path := "res://assets/audio/%s.ogg" % n
			if ResourceLoader.exists(path):
				arr.append(load(path))
		_streams[key] = arr
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)


func play(key: String, volume_db: float = 0.0, pitch_var: float = 0.08) -> void:
	var arr: Array = _streams.get(key, [])
	if arr.is_empty():
		return
	# avoid the same sound stacking dozens of times in one frame
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(key, -1000)) < 35:
		return
	_last_play[key] = now
	var vol: float = float(Game.settings.get("sfx", 0.8))
	if vol <= 0.01:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = arr[randi() % arr.size()]
	p.volume_db = volume_db + linear_to_db(vol)
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()
