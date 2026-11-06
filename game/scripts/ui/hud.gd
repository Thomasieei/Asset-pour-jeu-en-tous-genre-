class_name Hud
extends CanvasLayer
## Heads-up display + controls routing. Every number shown is read from Game / the player.

var player: Player
var army: Army
var world: WorldBuilder
var cam: CameraRig
var touch: TouchControls

var _hp_bar: ProgressBar
var _hp_text: Label
var _xp_bar: ProgressBar
var _xp_text: Label
var _lvl_label: Label
var _gold_label: Label
var _power_label: Label
var _army_label: Label
var _shadow_dot: ColorRect
var _toasts: VBoxContainer
var _boss_box: PanelContainer
var _boss_bar: ProgressBar
var _boss_name: Label
var _boss: Actor
var _dialog: PanelContainer
var _dialog_name: Label
var _dialog_text: Label
var _dialog_t: float = 0.0
var _quest_title: Label
var _quest_text: Label
var _panel_layer: Control
var _open_panel: Control
var _corpse: Node3D
var _interact: Dictionary = {}
var _ui_t: float = 0.0
var _quest_dirty: bool = true

const QUESTS := [
	["Accueil", "Parlez à l'Ancienne Ysolde, près du puits."],
	["Vers le nord", "Franchissez les tours et rejoignez la Plaine des Tertres."],
	["Premiers combats", "Vainquez des squelettes"],
	["L'éveil", "Touchez ÉVEILLER près d'une dépouille pour obtenir une ombre."],
	["La forge", "Renforcez votre arme chez Borin (Forge du village)."],
	["Le Seigneur", "Vainquez le Seigneur des Tertres, au fond de la plaine."],
	["Légion en marche", "Collectionnez des ombres rares et renforcez votre armée !"],
]


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	touch = TouchControls.new()
	root.add_child(touch)
	touch.action.connect(_on_action)
	_build_top_left(root)
	_build_top_right(root)
	_build_center(root)
	_panel_layer = Control.new()
	_panel_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_panel_layer)
	Game.gold_changed.connect(_refresh_stats)
	Game.xp_changed.connect(_refresh_stats)
	Game.level_up.connect(_on_level_up)
	Game.shadows_changed.connect(_refresh_stats)
	Game.army_changed.connect(_refresh_stats)
	Game.forge_changed.connect(_refresh_stats)
	Game.toast.connect(toast)
	Game.extraction_result.connect(_on_extraction)
	Game.boss_state.connect(_on_boss_state)


func bind(p: Player, a: Army, w: WorldBuilder, c: CameraRig) -> void:
	player = p
	army = a
	world = w
	cam = c
	player.hp_changed.connect(_refresh_hp)
	_refresh_hp()
	_refresh_stats()


# ------------------------------------------------------------------ layout
func _build_top_left(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.05, 0.07, 0.18, 0.8), Color(0.3, 0.6, 1.0), 16, 2))
	panel.position = Vector2(16, 14)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	panel.add_child(hb)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.35, 0.18, 0.7), Color(0.75, 0.6, 1.0), 40, 3))
	badge.custom_minimum_size = Vector2(76, 76)
	hb.add_child(badge)
	_lvl_label = UIKit.label("1", 30, Color.WHITE, 8)
	_lvl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lvl_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(_lvl_label)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	hb.add_child(vb)
	var hp_stack := Control.new()
	hp_stack.custom_minimum_size = Vector2(300, 26)
	vb.add_child(hp_stack)
	_hp_bar = UIKit.make_bar(Color(0.9, 0.22, 0.25), Vector2(300, 26))
	hp_stack.add_child(_hp_bar)
	_hp_text = UIKit.label("", 17, Color.WHITE, 5)
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text.size = Vector2(300, 26)
	hp_stack.add_child(_hp_text)
	var xp_stack := Control.new()
	xp_stack.custom_minimum_size = Vector2(300, 18)
	vb.add_child(xp_stack)
	_xp_bar = UIKit.make_bar(UIKit.PURPLE, Vector2(300, 18))
	xp_stack.add_child(_xp_bar)
	_xp_text = UIKit.label("", 14, Color.WHITE, 4)
	_xp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_text.size = Vector2(300, 18)
	xp_stack.add_child(_xp_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	row.add_child(UIKit.icon_rect("medal1", 24, UIKit.GOLD))
	_gold_label = UIKit.label("0", 22, UIKit.GOLD, 6)
	_gold_label.custom_minimum_size = Vector2(110, 0)
	row.add_child(_gold_label)
	row.add_child(UIKit.icon_rect("target", 22, Color(1.0, 0.5, 0.45)))
	_power_label = UIKit.label("0", 20, Color(1.0, 0.75, 0.7), 6)
	row.add_child(_power_label)


func _menu_button(parent: Control, icon_name: String, text: String, color: Color, cb: Callable) -> Button:
	var b := UIKit.make_button("", color, 16, Vector2(84, 84))
	b.icon = UIKit.icon(icon_name)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 46)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	touch.blockers.append(b)
	return b


func _build_top_right(root: Control) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hb.offset_left = -300
	hb.offset_right = -16
	hb.offset_top = 14
	hb.alignment = BoxContainer.ALIGNMENT_END
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hb)
	var sb := _menu_button(hb, "multiplayer", "Ombres", Color(0.45, 0.22, 0.85), open_shadows)
	_shadow_dot = ColorRect.new()
	_shadow_dot.color = UIKit.RED
	_shadow_dot.size = Vector2(16, 16)
	_shadow_dot.position = Vector2(64, 4)
	_shadow_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow_dot.visible = false
	sb.add_child(_shadow_dot)
	_menu_button(hb, "star", "Bonus", Color(0.8, 0.55, 0.1), open_bonus)
	_menu_button(hb, "gear", "Réglages", Color(0.25, 0.35, 0.55), open_settings)
	_army_label = UIKit.label("", 20, Color(0.85, 0.75, 1.0), 6)
	_army_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_army_label.offset_left = -300
	_army_label.offset_right = -20
	_army_label.offset_top = 104
	_army_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_army_label)
	# objective tracker (right side, like the reference quest box)
	var qp := PanelContainer.new()
	qp.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.04, 0.05, 0.14, 0.72), Color(0.95, 0.75, 0.3), 12, 2))
	qp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	qp.offset_left = -330
	qp.offset_right = -16
	qp.offset_top = 140
	qp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(qp)
	var qv := VBoxContainer.new()
	qp.add_child(qv)
	_quest_title = UIKit.label("", 21, UIKit.GOLD, 6)
	qv.add_child(_quest_title)
	_quest_text = UIKit.label("", 17, Color(0.92, 0.94, 1.0), 4)
	_quest_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_text.custom_minimum_size = Vector2(290, 0)
	qv.add_child(_quest_text)


func _build_center(root: Control) -> void:
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.offset_left = -330
	_toasts.offset_right = 330
	_toasts.offset_top = 110
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toasts)
	_boss_box = PanelContainer.new()
	_boss_box.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.1, 0.03, 0.08, 0.85), Color(0.9, 0.2, 0.5), 12, 2))
	_boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_box.offset_left = -260
	_boss_box.offset_right = 260
	_boss_box.offset_top = 16
	_boss_box.visible = false
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_boss_box)
	var bv := VBoxContainer.new()
	_boss_box.add_child(bv)
	_boss_name = UIKit.label("", 22, Color(1.0, 0.6, 0.8), 6)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(_boss_name)
	_boss_bar = UIKit.make_bar(Color(0.85, 0.15, 0.55), Vector2(500, 22))
	bv.add_child(_boss_bar)
	_dialog = PanelContainer.new()
	_dialog.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.06, 0.08, 0.16, 0.92), Color(0.45, 0.85, 0.55), 16, 3))
	_dialog.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dialog.offset_left = -330
	_dialog.offset_right = 330
	_dialog.offset_top = -190
	_dialog.offset_bottom = -40
	_dialog.visible = false
	_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_dialog)
	var dv := VBoxContainer.new()
	_dialog.add_child(dv)
	_dialog_name = UIKit.label("", 22, Color(0.6, 1.0, 0.7), 6)
	dv.add_child(_dialog_name)
	_dialog_text = UIKit.label("", 20, Color.WHITE, 5)
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_text.custom_minimum_size = Vector2(620, 0)
	dv.add_child(_dialog_text)


# ------------------------------------------------------------------ refresh
func _refresh_hp() -> void:
	if player == null:
		return
	_hp_bar.value = player.hp_ratio()
	_hp_text.text = "%s / %s" % [player.hp.fmt(), player.max_hp.fmt()]


func _refresh_stats() -> void:
	_lvl_label.text = str(Game.level)
	var need: Big = Game.xp_needed()
	_xp_bar.value = clampf(Game.xp.ratio(need), 0.0, 1.0)
	_xp_text.text = "XP %s / %s" % [Game.xp.floor_big().fmt(), need.fmt()]
	_gold_label.text = Game.gold.fmt()
	_power_label.text = Game.total_power().fmt()
	_army_label.text = "Armée %d/%d%s" % [Game.equipped_count(), Game.army_slots, "" if (army == null or army.summoned) else " (rappelée)"]
	_shadow_dot.visible = Game.has_new_shadows()
	_quest_dirty = true


func toast(text: String, color: Color = Color.WHITE) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.05, 0.06, 0.15, 0.85), color, 12, 2))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UIKit.label(text, 22, color, 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	_toasts.add_child(p)
	while _toasts.get_child_count() > 3:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var tw := p.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func _on_level_up(lvl: int) -> void:
	toast("NIVEAU %d !  Vos dégâts et vos PV augmentent." % lvl, UIKit.GOLD)
	Sfx.play("levelup", -6.0, 0.0)
	if player:
		Fx.ring_burst(player.global_position, UIKit.GOLD)
	_refresh_stats()


func _on_extraction(ok: bool, inst: Dictionary, species_id: String, chance: float) -> void:
	var pop := SimplePanels.extraction(ok, inst, species_id, chance, func(): pass, open_shadows)
	_panel_layer.add_child(pop)
	_quest_dirty = true


func _on_boss_state(active: bool, actor: Node) -> void:
	_boss = actor as Actor if active else null
	_boss_box.visible = active
	if cam:
		cam.set_combat(active, 3.5)
	if active and _boss:
		_boss_name.text = "%s  —  Rang A" % _boss.display_name


func show_dialog(who: String, text: String) -> void:
	_dialog_name.text = who
	_dialog_text.text = text
	_dialog.visible = true
	_dialog_t = 5.5


# ------------------------------------------------------------------ panels
func _open(panel: Control) -> void:
	if _open_panel and is_instance_valid(_open_panel):
		_open_panel.queue_free()
	_open_panel = panel
	_panel_layer.add_child(panel)
	touch.release_all()
	touch.blocked = true
	if player:
		player.move_input = Vector2.ZERO
	Sfx.play("open", -6.0)


func _panel_closed() -> void:
	_open_panel = null
	touch.blocked = false
	_refresh_stats()


func is_panel_open() -> bool:
	return _open_panel != null and is_instance_valid(_open_panel)


func open_shadows() -> void:
	var p := ShadowsPanel.new()
	p.closed.connect(_panel_closed)
	_open(p)


func open_bonus() -> void:
	_open(SimplePanels.bonuses(_panel_closed))


func open_forge() -> void:
	_open(SimplePanels.forge(_panel_closed))


func open_settings() -> void:
	_open(SimplePanels.settings(_panel_closed, _apply_settings))


func _apply_settings() -> void:
	if cam:
		cam.sensitivity = float(Game.settings["cam_sens"])
		cam.base_distance = float(Game.settings["cam_dist"])


# ------------------------------------------------------------------ actions
func _on_action(n: String) -> void:
	if player == null or is_panel_open():
		return
	match n:
		"attack":
			player.request_attack()
		"dodge":
			player.request_dodge()
		"summon":
			var on := army.toggle_summon()
			toast("Armée invoquée" if on else "Armée rappelée", UIKit.PURPLE.lightened(0.3))
			_refresh_stats()
		"extract":
			if _corpse and is_instance_valid(_corpse) and player.can_cast():
				player.start_extract(_corpse)
				Sfx.play("extract", -10.0, 0.0)
		"interact":
			_do_interact()
		"extract_disabled":
			Sfx.play("error", -10.0)


func _do_interact() -> void:
	if _interact.is_empty():
		return
	Sfx.play("click", -6.0)
	match str(_interact.get("kind", "")):
		"npc":
			var npc: Npc = _interact["node"]
			show_dialog(npc.display_name, npc.talk())
			if npc.def.get("id", "") == "elder":
				_advance_quest_from(0)
			if npc.fn == "forge":
				open_forge()
		"forge":
			open_forge()
		"barracks":
			open_shadows()
		"chapel":
			show_dialog("Chapelle", "Point de renaissance : si vous tombez au combat, vous reviendrez ici, soigné.")
		"market", "tavern":
			show_dialog("Bientôt", "Ce bâtiment ouvrira ses portes dans une prochaine mise à jour.")


# ------------------------------------------------------------------ per-frame
func _process(delta: float) -> void:
	if player == null:
		return
	_handle_keyboard()
	if not touch.blocked:
		player.move_input = touch.move_vector + _key_move
		var drag := touch.consume_camera_drag()
		if drag != Vector2.ZERO and cam:
			cam.orbit(drag)
	touch.set_cooldown("dodge", clampf(player._dodge_cd / Player.DODGE_COOLDOWN, 0.0, 1.0))
	_ui_t -= delta
	if _ui_t <= 0.0:
		_ui_t = 0.12
		_scan_context()
		_update_quest()
	if _boss and is_instance_valid(_boss):
		_boss_bar.value = _boss.hp_ratio()
	if _dialog_t > 0.0:
		_dialog_t -= delta
		if _dialog_t <= 0.0:
			_dialog.visible = false


var _key_move := Vector2.ZERO


func _handle_keyboard() -> void:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1.0
	_key_move = v.normalized() if v != Vector2.ZERO else Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		match k.physical_keycode:
			KEY_J:
				_on_action("attack")
			KEY_K, KEY_SPACE:
				_on_action("dodge")
			KEY_E:
				_on_action("interact")
			KEY_F:
				_on_action("extract")
			KEY_R:
				_on_action("summon")
			KEY_ESCAPE:
				if is_panel_open():
					_open_panel.queue_free()
					_panel_closed()


func _scan_context() -> void:
	# extraction: nearest extractable corpse within 6 m
	_corpse = null
	var best := 6.0
	for c in get_tree().get_nodes_in_group("corpses"):
		var e: Enemy = c
		if not e.extractable:
			continue
		var d := player.flat_distance_to(e)
		if d < best:
			best = d
			_corpse = e
	if _corpse:
		var e2: Enemy = _corpse
		var pct := int(round(Game.extract_chance(e2.species_id) * 100.0))
		touch.set_button("extract", true, "ÉVEILLER %d%%" % pct, player.can_cast())
	else:
		touch.set_button("extract", false)
	# interaction: NPCs first, then buildings
	_interact = {}
	var bd := 3.4
	for n in get_tree().get_nodes_in_group("npcs"):
		var npc: Npc = n
		var to := npc.global_position - player.global_position
		to.y = 0.0
		if to.length() < bd:
			bd = to.length()
			_interact = {"kind": "npc", "node": npc, "label": "Parler"}
	if _interact.is_empty() and world:
		for it in world.interactables:
			var p: Vector3 = it["pos"]
			var d2 := Vector2(p.x - player.global_position.x, p.z - player.global_position.z).length()
			if d2 < float(it["radius"]):
				var labels := {"forge": "Forge", "barracks": "Caserne", "chapel": "Chapelle", "market": "Marché", "tavern": "Taverne"}
				if labels.has(it["fn"]):
					_interact = {"kind": it["fn"], "label": labels[it["fn"]]}
					break
	if _interact.is_empty():
		touch.set_button("interact", false)
	else:
		touch.set_button("interact", true, str(_interact["label"]))
	touch.set_button("summon", true, "Armée" if army.summoned else "Invoquer")


# ------------------------------------------------------------------ quests
func _advance_quest_from(stage: int) -> void:
	if int(Game.stats["quest"]) != stage:
		return
	var reward := Big.of(30.0 * float(stage + 1))
	Game.add_gold(reward, false)
	Game.stats["quest"] = stage + 1
	Game.stats["quest_base"] = _quest_counter(stage + 1)
	Game.mark_dirty()
	toast("Objectif accompli : %s  (+%s or)" % [QUESTS[stage][0], reward.fmt()], UIKit.GREEN)
	Sfx.play("ok", -4.0)
	_quest_dirty = true


func _quest_counter(stage: int) -> int:
	match stage:
		2:
			return int(Game.stats["kills"])
		3:
			return int(Game.stats["extract_ok"])
		5:
			return int(Game.stats["boss_kills"])
	return 0


func _update_quest() -> void:
	var q: int = clampi(int(Game.stats["quest"]), 0, QUESTS.size() - 1)
	var base: int = int(Game.stats["quest_base"])
	var detail: String = QUESTS[q][1]
	match q:
		1:
			if player.global_position.z < -62.0:
				_advance_quest_from(1)
				return
		2:
			var done: int = int(Game.stats["kills"]) - base
			detail = "%s  (%d/3)" % [QUESTS[q][1], mini(done, 3)]
			if done >= 3:
				_advance_quest_from(2)
				return
		3:
			if int(Game.stats["extract_ok"]) > base:
				_advance_quest_from(3)
				return
		4:
			if Game.forge_level >= 1:
				_advance_quest_from(4)
				return
		5:
			if int(Game.stats["boss_kills"]) > base:
				_advance_quest_from(5)
				return
	if _quest_dirty or _quest_title.text == "":
		_quest_dirty = false
		_quest_title.text = "Objectif : " + str(QUESTS[q][0])
		_quest_text.text = detail
	elif q == 2:
		_quest_text.text = detail
