class_name UIKit
extends RefCounted
## Style helpers: dark navy panels with neon borders (reference screenshots), outlined text.

const NAVY := Color(0.06, 0.08, 0.2, 0.94)
const NAVY_LIGHT := Color(0.1, 0.14, 0.32, 0.96)
const CYAN := Color(0.25, 0.75, 1.0)
const GOLD := Color(1.0, 0.8, 0.25)
const PURPLE := Color(0.62, 0.36, 1.0)
const GREEN := Color(0.25, 0.85, 0.35)
const RED := Color(0.95, 0.25, 0.3)

static var _icons := {}


static func icon(name: String) -> Texture2D:
	if _icons.has(name):
		return _icons[name]
	var path := "res://assets/ui/%s.png" % name
	if not ResourceLoader.exists(path):
		path = "res://assets/icons/%s.png" % name
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_icons[name] = t
	return t


static func panel_style(bg: Color = NAVY, border: Color = CYAN, radius: int = 18, bw: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(border.r, border.g, border.b, 0.35)
	s.shadow_size = 8
	s.set_content_margin_all(12)
	s.anti_aliasing = true
	return s


static func button_style(base: Color, radius: int = 14) -> Dictionary:
	var n := StyleBoxFlat.new()
	n.bg_color = base
	n.border_color = base.lightened(0.45)
	n.set_border_width_all(3)
	n.set_corner_radius_all(radius)
	n.shadow_color = Color(0, 0, 0, 0.45)
	n.shadow_size = 4
	n.shadow_offset = Vector2(0, 3)
	n.set_content_margin_all(8)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = base.lightened(0.15)
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = base.darkened(0.25)
	p.shadow_offset = Vector2(0, 1)
	var d := n.duplicate() as StyleBoxFlat
	d.bg_color = Color(0.25, 0.27, 0.33, 0.9)
	d.border_color = Color(0.4, 0.42, 0.48)
	return {"normal": n, "hover": h, "pressed": p, "disabled": d, "focus": n}


static func style_button(b: Button, base: Color, font_size: int = 24) -> void:
	var st := button_style(base)
	for k in st.keys():
		b.add_theme_stylebox_override(k, st[k])
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	b.add_theme_color_override("font_disabled_color", Color(0.65, 0.66, 0.7))
	b.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.08))
	b.add_theme_constant_override("outline_size", 6)
	b.focus_mode = Control.FOCUS_NONE


static func make_button(text: String, base: Color, font_size: int = 24, min_size: Vector2 = Vector2(0, 56)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	style_button(b, base, font_size)
	return b


static func label(text: String, size: int = 22, color: Color = Color.WHITE, outline: int = 6) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.08))
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func bar_style(color: Color, radius: int = 8) -> Array:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.04, 0.1, 0.9)
	bg.border_color = Color(0.0, 0.0, 0.0, 0.9)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(radius)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(radius)
	fg.border_color = color.lightened(0.35)
	fg.border_width_top = 2
	return [bg, fg]


static func make_bar(color: Color, size: Vector2) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.custom_minimum_size = size
	pb.show_percentage = false
	pb.max_value = 1.0
	pb.step = 0.0
	var st := bar_style(color)
	pb.add_theme_stylebox_override("background", st[0])
	pb.add_theme_stylebox_override("fill", st[1])
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pb


static func icon_rect(name: String, size: float, modulate: Color = Color.WHITE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon(name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.modulate = modulate
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## A modal window: dims the screen, centred panel with title bar and close button.
static func make_window(title: String, icon_name: String, size: Vector2, on_close: Callable) -> Dictionary:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0.05, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style(NAVY, CYAN, 22, 4))
	panel.custom_minimum_size = size
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	vb.add_child(header)
	if icon_name != "":
		header.add_child(icon_rect(icon_name, 44, Color(0.8, 0.9, 1.0)))
	var tl := label(title, 34, Color.WHITE, 8)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(tl)
	var close := make_button("", RED, 24, Vector2(60, 56))
	close.icon = icon("cross")
	close.expand_icon = true
	close.pressed.connect(on_close)
	header.add_child(close)
	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	vb.add_child(body)
	return {"root": root, "panel": panel, "body": body, "header": header, "title": tl}
