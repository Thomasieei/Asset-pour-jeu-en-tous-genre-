class_name SimplePanels
extends RefCounted
## Builders for the smaller windows: Forge, Bonus summary, Settings, Extraction result.
## Each returns a Control that frees itself and calls on_close when dismissed.


static func _closer(root: Control, on_close: Callable) -> Callable:
	return func():
		Sfx.play("close", -6.0)
		on_close.call()
		root.queue_free()


# ------------------------------------------------------------------ forge
static func forge(on_close: Callable) -> Control:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	var win := UIKit.make_window("Forge de Borin", "hammer", Vector2(720, 470), _closer(holder, on_close))
	holder.add_child(win["root"])
	var body: VBoxContainer = win["body"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	body.add_child(row)
	row.add_child(UIKit.icon_rect("sword_1handed", 170))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 8)
	row.add_child(info)
	var title := UIKit.label("", 28, UIKit.GOLD, 8)
	var dmg := UIKit.label("", 22)
	var cost := UIKit.label("", 22)
	var reason := UIKit.label("", 18, Color(1.0, 0.6, 0.55), 4)
	info.add_child(title)
	info.add_child(dmg)
	info.add_child(cost)
	info.add_child(reason)
	var btn := UIKit.make_button("Améliorer", UIKit.GREEN.darkened(0.15), 26, Vector2(0, 66))
	body.add_child(btn)
	var note := UIKit.label("Chaque niveau de forge ajoute +%d %% de dégâts à votre arme (bonus additif)." % int(Data.FORGE_DMG_PER_LEVEL * 100), 17, Color(0.75, 0.8, 0.95), 4)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	var refresh := func():
		var lvl: int = Game.forge_level
		title.text = "Épée du veilleur  +%d" % lvl
		var now: Big = Game.player_damage()
		var next_mult: float = (1.0 + (lvl + 1) * Data.FORGE_DMG_PER_LEVEL) / (1.0 + lvl * Data.FORGE_DMG_PER_LEVEL)
		dmg.text = "Dégâts : %s  →  %s" % [now.fmt(), now.mulf(next_mult).fmt()]
		var c: Big = Game.forge_cost()
		cost.text = "Coût : %s or   (vous avez %s)" % [c.fmt(), Game.gold.fmt()]
		var ok: bool = Game.gold.gte(c)
		btn.disabled = not ok
		reason.text = "" if ok else "Or insuffisant : il manque %s or." % c.sub(Game.gold).fmt()
	refresh.call()
	btn.pressed.connect(func():
		if Game.upgrade_forge():
			Sfx.play("ok", -2.0)
			Sfx.play("hit_heavy", -8.0)
			Game.notify("Arme renforcée : +%d" % Game.forge_level, UIKit.GOLD)
		else:
			Sfx.play("error", -6.0))
	Game.gold_changed.connect(refresh)
	Game.forge_changed.connect(refresh)
	# lambdas are not bound to the panel: disconnect explicitly when it closes
	holder.tree_exiting.connect(func():
		Game.gold_changed.disconnect(refresh)
		Game.forge_changed.disconnect(refresh))
	return holder


# ------------------------------------------------------------------ bonus summary
static func bonuses(on_close: Callable) -> Control:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	var win := UIKit.make_window("Bonus actifs", "star", Vector2(820, 560), _closer(holder, on_close))
	holder.add_child(win["root"])
	var body: VBoxContainer = win["body"]
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	list.add_child(UIKit.label("Totaux", 26, UIKit.CYAN, 6))
	for stat in Bonus.STAT_LABELS.keys():
		var txt := ""
		if stat == "crit_chance":
			txt = "%s : %s %%" % [Bonus.STAT_LABELS[stat], String.num(Game.crit_chance() * 100.0, 1).replace(".", ",")]
		else:
			txt = "%s : ×%s" % [Bonus.STAT_LABELS[stat], String.num(Game.factor(stat), 2).replace(".", ",")]
		list.add_child(UIKit.label(txt, 20))
	list.add_child(UIKit.label("Puissance totale : %s" % Game.total_power().fmt(), 22, UIKit.GOLD, 6))
	list.add_child(UIKit.label("Sources", 26, UIKit.CYAN, 6))
	var mods: Array = Game.mods()
	if mods.is_empty():
		list.add_child(UIKit.label("Aucun bonus pour l'instant : améliorez la forge, collectionnez des ombres, montez de niveau.", 18, Color(0.8, 0.85, 1.0)))
	for md in mods:
		var l := UIKit.label("•  %s   —   %s" % [Bonus.describe(md), md["source"]], 19, Color(0.9, 0.92, 1.0), 4)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(l)
	var formula := UIKit.label("Calcul : facteur = (1 + somme des bonus additifs) × produit des multiplicateurs. Puissance = dégâts du héros (crit. moyen inclus) + puissance des ombres équipées.", 16, Color(0.7, 0.75, 0.9), 4)
	formula.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(formula)
	return holder


# ------------------------------------------------------------------ settings
static func settings(on_close: Callable, apply: Callable) -> Control:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	var win := UIKit.make_window("Paramètres", "gear", Vector2(700, 470), _closer(holder, on_close))
	holder.add_child(win["root"])
	var body: VBoxContainer = win["body"]
	var defs := [["cam_sens", "Sensibilité caméra", 0.3, 2.5], ["cam_dist", "Distance caméra", 5.0, 14.0], ["sfx", "Volume des effets", 0.0, 1.0]]
	for d in defs:
		var key: String = d[0]
		var lab := UIKit.label("", 22)
		body.add_child(lab)
		var sl := HSlider.new()
		sl.min_value = float(d[2])
		sl.max_value = float(d[3])
		sl.step = 0.05
		sl.custom_minimum_size = Vector2(0, 44)
		sl.value = float(Game.settings[key])
		var name_txt: String = d[1]
		var upd := func(v: float):
			lab.text = "%s : %s" % [name_txt, String.num(v, 2).replace(".", ",")]
		upd.call(sl.value)
		sl.value_changed.connect(func(v: float):
			Game.settings[key] = v
			Game.mark_dirty()
			upd.call(v)
			apply.call())
		body.add_child(sl)
	var stats := UIKit.label("Statistiques : %d ennemis vaincus · %d ombres éveillées · %d échecs · %d boss" % [
		int(Game.stats["kills"]), int(Game.stats["extract_ok"]), int(Game.stats["extract_fail"]), int(Game.stats["boss_kills"])], 17, Color(0.75, 0.8, 0.95), 4)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(stats)
	return holder


# ------------------------------------------------------------------ extraction result
static func extraction(ok: bool, inst: Dictionary, species_id: String, chance: float, on_close: Callable, on_view: Callable) -> Control:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sp := Data.species(species_id)
	var rc := Data.rarity_color(int(sp["rarity"]))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.panel_style(UIKit.NAVY, rc if ok else Color(0.45, 0.45, 0.55), 20, 4))
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.custom_minimum_size = Vector2(520, 0)
	panel.offset_left = -260
	panel.offset_right = 260
	panel.offset_top = 90
	panel.add_to_group("ui_blocker")
	holder.add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	panel.add_child(hb)
	var pic := TextureRect.new()
	pic.texture = Portraits.get_tex(species_id, true)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(130, 130)
	pic.modulate = Color.WHITE if ok else Color(0.5, 0.5, 0.55, 0.7)
	hb.add_child(pic)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	var close_fn := _closer(holder, on_close)
	if ok:
		vb.add_child(UIKit.label("ÉVEIL RÉUSSI !", 30, UIKit.PURPLE.lightened(0.3), 8))
		vb.add_child(UIKit.label(str(sp["name"]), 26, rc, 7))
		vb.add_child(UIKit.label("%s · Rang %s · chance %d %%" % [Data.rarity_name(int(sp["rarity"])), sp["rank"], int(round(chance * 100.0))], 18, Color(0.85, 0.88, 1.0)))
		var eq_txt := "Rejoint votre armée" if inst.get("equipped", false) else "Ajoutée à la collection (armée complète)"
		vb.add_child(UIKit.label(eq_txt, 17, UIKit.GREEN if inst.get("equipped", false) else UIKit.GOLD, 4))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vb.add_child(row)
		var view := UIKit.make_button("Voir", UIKit.PURPLE.darkened(0.2), 20, Vector2(110, 48))
		view.pressed.connect(func():
			close_fn.call()
			on_view.call())
		row.add_child(view)
		var okb := UIKit.make_button("OK", Color(0.2, 0.4, 0.8), 20, Vector2(90, 48))
		okb.pressed.connect(close_fn)
		row.add_child(okb)
	else:
		vb.add_child(UIKit.label("L'essence se dissipe…", 26, Color(0.75, 0.75, 0.85), 7))
		vb.add_child(UIKit.label("%s · chance %d %%" % [sp["name"], int(round(chance * 100.0))], 18, Color(0.7, 0.72, 0.85)))
	# auto-dismiss so it never blocks gameplay
	var t := Timer.new()
	t.wait_time = 4.5 if ok else 2.2
	t.one_shot = true
	t.autostart = true
	t.timeout.connect(func():
		if is_instance_valid(holder):
			close_fn.call())
	holder.add_child(t)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = Vector2(260, 70)
	var tw := panel.create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.18)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return holder
