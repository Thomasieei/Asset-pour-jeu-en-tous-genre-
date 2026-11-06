class_name ShadowsPanel
extends Control
## Shadow collection: illustrated card grid + detail sheet + equip/lock/sell + sorting.

signal closed

const SORTS := ["power", "rarity", "level", "recent"]
const SORT_LABELS := {"power": "Puissance", "rarity": "Rareté", "level": "Niveau", "recent": "Récent"}

var _sort_i := 0
var _desc := true
var _selected_uid := -1
var _win: Dictionary
var _grid: GridContainer
var _detail: VBoxContainer
var _count_label: Label
var _sort_btn: Button
var _dir_btn: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_win = UIKit.make_window("Ombres", "multiplayer", Vector2(1160, 640), close)
	add_child(_win["root"])
	var body: VBoxContainer = _win["body"]
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	body.add_child(top)
	_count_label = UIKit.label("", 24, UIKit.GOLD)
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_count_label)
	_sort_btn = UIKit.make_button("", Color(0.2, 0.35, 0.8), 20, Vector2(210, 50))
	_sort_btn.pressed.connect(_cycle_sort)
	top.add_child(_sort_btn)
	_dir_btn = UIKit.make_button("", Color(0.2, 0.35, 0.8), 20, Vector2(56, 50))
	_dir_btn.expand_icon = true
	_dir_btn.pressed.connect(_toggle_dir)
	top.add_child(_dir_btn)
	var best := UIKit.make_button("Équiper le meilleur", UIKit.GREEN.darkened(0.2), 20, Vector2(220, 50))
	best.pressed.connect(func():
		Game.equip_best()
		Sfx.play("ok", -6.0))
	top.add_child(best)
	var none := UIKit.make_button("Tout déséquiper", Color(0.75, 0.45, 0.15), 20, Vector2(200, 50))
	none.pressed.connect(func():
		Game.unequip_all()
		Sfx.play("click", -6.0))
	top.add_child(none)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	body.add_child(content)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)
	var dpanel := PanelContainer.new()
	dpanel.custom_minimum_size = Vector2(380, 0)
	dpanel.add_theme_stylebox_override("panel", UIKit.panel_style(UIKit.NAVY_LIGHT, Color(0.35, 0.45, 0.9), 16, 2))
	content.add_child(dpanel)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 6)
	dpanel.add_child(_detail)
	Game.shadows_changed.connect(_refresh)
	_refresh()


func close() -> void:
	Game.clear_new_flags()
	Sfx.play("close", -6.0)
	closed.emit()
	queue_free()


func _cycle_sort() -> void:
	_sort_i = (_sort_i + 1) % SORTS.size()
	Sfx.play("click", -8.0)
	_refresh()


func _toggle_dir() -> void:
	_desc = not _desc
	Sfx.play("click", -8.0)
	_refresh()


func _sorted() -> Array:
	var arr := Game.shadows.duplicate()
	var mode: String = SORTS[_sort_i]
	arr.sort_custom(func(a, b):
		var c := 0
		match mode:
			"power":
				c = Game.shadow_power(a).cmp(Game.shadow_power(b))
			"rarity":
				c = signi(int(Data.species(a["sp"])["rarity"]) - int(Data.species(b["sp"])["rarity"]))
				if c == 0:
					c = Game.shadow_power(a).cmp(Game.shadow_power(b))
			"level":
				c = signi(int(a["lvl"]) - int(b["lvl"]))
			"recent":
				c = signi(int(a["order"]) - int(b["order"]))
		if c == 0:
			c = signi(int(b["uid"]) - int(a["uid"]))
		return c > 0 if _desc else c < 0)
	return arr


func _refresh() -> void:
	if not is_inside_tree():
		return
	_count_label.text = "Armée %d/%d   ·   Ombres %d" % [Game.equipped_count(), Game.army_slots, Game.shadows.size()]
	_sort_btn.text = "Tri : " + str(SORT_LABELS[SORTS[_sort_i]])
	_dir_btn.icon = UIKit.icon("arrowDown" if _desc else "arrowUp")
	for c in _grid.get_children():
		c.queue_free()
	var list := _sorted()
	if list.is_empty():
		var l := UIKit.label("Aucune ombre pour l'instant.\nVainquez des squelettes dans la Plaine des Tertres,\npuis touchez ÉVEILLER près de leur dépouille.", 22, Color(0.8, 0.85, 1.0))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(600, 0)
		_grid.add_child(l)
		_selected_uid = -1
	else:
		if Game.get_shadow(_selected_uid).is_empty():
			_selected_uid = int(list[0]["uid"])
		for s in list:
			_grid.add_child(_card(s))
	_build_detail()


func _card(s: Dictionary) -> Control:
	var sp := Data.species(s["sp"])
	var rarity: int = int(sp["rarity"])
	var rc := Data.rarity_color(rarity)
	var selected: bool = int(s["uid"]) == _selected_uid
	var b := Button.new()
	b.custom_minimum_size = Vector2(160, 200)
	b.focus_mode = Control.FOCUS_NONE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(rc.r * 0.25, rc.g * 0.25, rc.b * 0.3, 0.95)
	st.border_color = rc
	st.set_border_width_all(3)
	st.set_corner_radius_all(12)
	if selected:
		# selection uses white/cyan glow, distinct from rarity colours
		st.border_color = Color(0.85, 1.0, 1.0)
		st.set_border_width_all(5)
		st.shadow_color = Color(0.4, 0.9, 1.0, 0.7)
		st.shadow_size = 10
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("pressed", st)
	b.add_theme_stylebox_override("focus", st)
	var uid: int = int(s["uid"])
	b.pressed.connect(func():
		_selected_uid = uid
		Sfx.play("click", -10.0)
		_refresh())
	var portrait := TextureRect.new()
	portrait.texture = Portraits.get_tex(s["sp"], true)
	if portrait.texture == null:
		portrait.texture = UIKit.icon(str(sp["weapon_r"]).get_basename().replace("Skeleton_", "Skeleton_"))
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(8, 22)
	portrait.size = Vector2(144, 136)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(portrait)
	var rank := UIKit.label(str(sp["rank"]), 26, rc, 7)
	rank.position = Vector2(10, 4)
	b.add_child(rank)
	var name_l := UIKit.label(str(sp["name"]), 17, Color.WHITE, 5)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.position = Vector2(0, 150)
	name_l.size = Vector2(160, 24)
	name_l.clip_text = true
	b.add_child(name_l)
	var lv := UIKit.label("Niv. %d" % int(s["lvl"]), 15, Color(0.8, 0.9, 1.0), 4)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.position = Vector2(0, 172)
	lv.size = Vector2(160, 20)
	b.add_child(lv)
	if s["equipped"]:
		var chk := UIKit.icon_rect("checkmark", 30, UIKit.GREEN)
		chk.position = Vector2(124, 6)      # top-right corner, away from the face
		b.add_child(chk)
	if s["locked"]:
		var lk := UIKit.icon_rect("locked", 26, UIKit.GOLD)
		lk.position = Vector2(126, 160)
		b.add_child(lk)
	if s.get("new", false):
		var dot := ColorRect.new()
		dot.color = UIKit.RED
		dot.size = Vector2(14, 14)
		dot.position = Vector2(46, 10)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(dot)
	return b


func _build_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var s := Game.get_shadow(_selected_uid)
	if s.is_empty():
		_detail.add_child(UIKit.label("Sélectionnez une ombre", 22, Color(0.7, 0.75, 0.9)))
		return
	var sp := Data.species(s["sp"])
	var rc := Data.rarity_color(int(sp["rarity"]))
	var pic := TextureRect.new()
	pic.texture = Portraits.get_tex(s["sp"], true)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(0, 170)
	_detail.add_child(pic)
	var nm := UIKit.label(str(sp["name"]), 28, rc, 8)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.add_child(nm)
	var sub := UIKit.label("%s  ·  Rang %s  ·  %s" % [Data.rarity_name(int(sp["rarity"])), sp["rank"], _role_name(str(sp["role"]))], 18, Color(0.8, 0.85, 1.0))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.add_child(sub)
	var cap := Game.shadow_level_cap(s)
	var lvl_l := UIKit.label("Niveau %d / %d" % [int(s["lvl"]), cap], 20)
	_detail.add_child(lvl_l)
	var xpb := UIKit.make_bar(UIKit.PURPLE, Vector2(0, 16))
	xpb.value = 1.0 if int(s["lvl"]) >= cap else clampf(float(s["xp"]) / Game.shadow_xp_needed(s), 0.0, 1.0)
	_detail.add_child(xpb)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	_detail.add_child(grid)
	for row in [["Dégâts", Game.shadow_damage(s).fmt()], ["Points de vie", Game.shadow_max_hp(s).fmt()],
			["Puissance", Game.shadow_power(s).fmt()], ["Attaque / s", String.num(1.0 / float(sp["atk_cd"]), 2).replace(".", ",")]]:
		grid.add_child(UIKit.label(str(row[0]), 19, Color(0.7, 0.78, 0.95)))
		grid.add_child(UIKit.label(str(row[1]), 19, Color.WHITE))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(spacer)
	var uid: int = int(s["uid"])
	var reason := UIKit.label("", 16, Color(1.0, 0.6, 0.55), 4)
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	_detail.add_child(row1)
	if s["equipped"]:
		var ub := UIKit.make_button("Déséquiper", Color(0.75, 0.45, 0.15), 20, Vector2(0, 52))
		ub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ub.pressed.connect(func():
			Game.unequip(uid)
			Sfx.play("click", -6.0))
		row1.add_child(ub)
	else:
		var full := Game.equipped_count() >= Game.army_slots
		var eb := UIKit.make_button("Équiper", UIKit.GREEN.darkened(0.2), 20, Vector2(0, 52))
		eb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eb.disabled = full
		if full:
			reason.text = "Armée complète (%d/%d) : déséquipez une ombre d'abord." % [Game.equipped_count(), Game.army_slots]
		eb.pressed.connect(func():
			var r := Game.equip(uid)
			if r != "":
				Game.notify(r, UIKit.RED)
			else:
				Sfx.play("summon", -6.0))
		row1.add_child(eb)
	var lb := UIKit.make_button("", Color(0.55, 0.45, 0.1), 20, Vector2(60, 52))
	lb.icon = UIKit.icon("locked" if not s["locked"] else "unlocked")
	lb.expand_icon = true
	lb.tooltip_text = "Verrouiller" if not s["locked"] else "Déverrouiller"
	lb.pressed.connect(func():
		Game.toggle_lock(uid)
		Sfx.play("click", -6.0))
	row1.add_child(lb)
	var sell := UIKit.make_button("Vendre (+%s or)" % Game.sell_value(s).fmt(), Color(0.7, 0.15, 0.2), 19, Vector2(0, 50))
	var blocked: bool = s["locked"] or s["equipped"]
	sell.disabled = blocked
	if s["locked"]:
		reason.text = "Verrouillée : protégée contre la vente."
	elif s["equipped"] and reason.text == "":
		reason.text = "Équipée : déséquipez-la pour pouvoir la vendre."
	sell.pressed.connect(func():
		var r := Game.sell(uid)
		if r != "":
			Game.notify(r, UIKit.RED)
		else:
			Sfx.play("coins", -4.0))
	_detail.add_child(sell)
	_detail.add_child(reason)


func _role_name(r: String) -> String:
	match r:
		"tank":
			return "Défenseur"
		"ranged":
			return "Distance"
		"boss":
			return "Seigneur"
	return "Mêlée"
