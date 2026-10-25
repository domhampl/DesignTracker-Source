extends Control

const SAVE_PATH := "user://tracker_data.json"
const OLD_PATH := "user://tasks.json"
const AMBER := Color("ffb02e")
const BASE_W := 360
const SIZE_MIN := 0.6
const SIZE_MAX := 1.3
const SIZE_DEFAULT := 0.8

# Task list height limits (at size 100%). The list scrolls after MAX_LIST.
const MIN_LIST := 90
const MAX_LIST := 340

# Task row font sizes (name is the biggest)
const FS_NAME := 22
const FS_CTRL := 13
const FS_META := 11
const FS_NOTE := 14

# Theme colors (set by _apply_theme)
var BG := Color("14141c")
var CARD := Color("1f1f2b")
var BORDER := Color("2e2e40")
var ACCENT := Color("7c5cff")
var ACCENT_SOFT := Color("b8a8ff")
var GREEN := Color("3ddc97")
var TEXT := Color("e8e8f0")
var MUTED := Color("8a8aa0")
var RED := Color("ff5c7a")

var data := {"current": "General", "theme": "dark", "size": 0.8, "mini": false, "projects": {"General": []}}
var ui_scale := 0.8
var is_mini := false
var note_target := -1
var filter := "all"
var pending_delete := ""
var placed := false
var fit_pending := false
var mini_idx := -1
var area_view := "tasks"

var panel_node: Control
var switch_btn: Button
var mini_btn: Button
var gear_btn: Button
var ring: Ring
var stats_box: VBoxContainer
var stat_total: Label
var stat_done: Label
var stat_left: Label
var stat_today: Label
var stat_all: Label
var mini_card: PanelContainer
var mini_tag: Label
var mini_text: Label
var mini_done_btn: Button
var filter_row: HBoxContainer
var filter_btns := {}
var clear_btn: Button
var area: VBoxContainer
var list_view: RichTextLabel
var proj_panel: PanelContainer
var proj_list: VBoxContainer
var new_project_input: LineEdit
var settings_panel: PanelContainer
var task_input: LineEdit

var dragging := false
var drag_offset := Vector2i.ZERO


# ---------- RING (circle dashboard) ----------

class Ring extends Control:
	var pct := 0.0
	var pct_all := 0.0
	var sub_fs := 14
	var col_main := Color.WHITE
	var col_all := Color.GREEN
	var col_track := Color.GRAY
	var col_text := Color.WHITE
	var col_sub := Color.GRAY

	func _draw() -> void:
		var c := size / 2.0
		var d := minf(size.x, size.y)
		var thick := maxf(8.0, d * 0.07)
		var r1 := d / 2.0 - thick
		var r2 := r1 - thick * 1.8
		var start := -PI / 2.0

		draw_arc(c, r1, 0.0, TAU, 96, col_track, thick, true)
		if pct > 0.0:
			draw_arc(c, r1, start, start + TAU * minf(pct, 100.0) / 100.0, 96, col_main, thick, true)

		draw_arc(c, r2, 0.0, TAU, 96, col_track, thick * 0.55, true)
		if pct_all > 0.0:
			draw_arc(c, r2, start, start + TAU * minf(pct_all, 100.0) / 100.0, 96, col_all, thick * 0.55, true)

		var font := ThemeDB.fallback_font
		var fs := int(d * 0.21)
		var s := "%d%%" % int(pct)
		var ts := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, Vector2(c.x - ts.x / 2.0, c.y + fs * 0.25), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col_text)
		var sub := "progress"
		var ss := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_fs)
		draw_string(font, Vector2(c.x - ss.x / 2.0, c.y + fs * 0.25 + sub_fs + 6.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_fs, col_sub)


func _f(n: int) -> int:
	return maxi(1, int(round(n * ui_scale)))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_load()
	ui_scale = clampf(float(data.get("size", SIZE_DEFAULT)), SIZE_MIN, SIZE_MAX)
	is_mini = bool(data.get("mini", false))

	var w := get_window()
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	w.content_scale_size = Vector2i.ZERO
	w.content_scale_factor = 1.0
	w.mode = Window.MODE_WINDOWED
	w.borderless = true
	w.always_on_top = true
	w.unresizable = true
	w.transparent = false
	get_viewport().transparent_bg = false
	get_tree().set_auto_accept_quit(false)

	_apply_theme()
	_build_ui()
	_apply_mode()
	_refresh()
	_place_window()


func _place_window() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_update_list_height()
	await get_tree().process_frame
	_update_list_height()
	var w := get_window()
	w.mode = Window.MODE_WINDOWED
	var usable := DisplayServer.screen_get_usable_rect(w.current_screen)
	var target := _target_size(usable)
	w.size = target
	w.position = Vector2i(usable.end.x - target.x - 12, usable.position.y + 40)
	placed = true
	_fit_window()


func _target_size(usable: Rect2i) -> Vector2i:
	var tx := mini(int(BASE_W * ui_scale), usable.size.x - 20)
	var content_h := 300
	if panel_node != null:
		content_h = int(ceil(panel_node.get_combined_minimum_size().y))
	var ty := mini(content_h, usable.size.y - 40)
	return Vector2i(tx, ty)


func _fit_window() -> void:
	if not placed:
		return
	var w := get_window()
	var usable := DisplayServer.screen_get_usable_rect(w.current_screen)
	var target := _target_size(usable)
	if w.size != target:
		w.size = target
	if w.position.x + target.x > usable.end.x:
		w.position.x = usable.end.x - target.x
	if w.position.y + target.y > usable.end.y:
		w.position.y = usable.end.y - target.y
	if w.position.x < usable.position.x:
		w.position.x = usable.position.x
	if w.position.y < usable.position.y:
		w.position.y = usable.position.y


# Window height follows the content (list height is capped, then it scrolls)
func _request_fit() -> void:
	if fit_pending:
		return
	fit_pending = true
	_do_fit()


func _do_fit() -> void:
	await get_tree().process_frame
	_update_list_height()
	await get_tree().process_frame
	_update_list_height()
	await get_tree().process_frame
	fit_pending = false
	_fit_window()


func _update_list_height() -> void:
	if list_view == null or proj_panel == null:
		return
	var maxh := float(_f(MAX_LIST))
	var minh := float(_f(MIN_LIST))
	var h := float(list_view.get_content_height()) + float(_f(16)) + 6.0
	list_view.custom_minimum_size.y = clampf(h, minh, maxh)
	var ph := float(data["projects"].size()) * float(_f(50)) + float(_f(46)) + float(_f(50))
	proj_panel.custom_minimum_size.y = clampf(ph, minh, maxh)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
		get_tree().quit()


func _apply_mode() -> void:
	var full := not is_mini
	stats_box.visible = full
	filter_row.visible = full
	area.visible = full
	task_input.visible = full
	gear_btn.visible = full
	mini_card.visible = is_mini
	mini_btn.text = "▢" if is_mini else "–"
	if is_mini:
		area_view = "tasks"
	_update_area_view()


func _update_area_view() -> void:
	list_view.visible = area_view == "tasks"
	proj_panel.visible = area_view == "projects"
	settings_panel.visible = area_view == "settings"
	if area_view == "settings":
		_style_button(gear_btn, ACCENT, ACCENT.lightened(0.1), Color.WHITE, 17)
	else:
		_style_button(gear_btn, CARD, BORDER, Color.TRANSPARENT, 17)
	_request_fit()


# ---------- DRAG (whole top bar) ----------

func _on_header_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		dragging = true
		drag_offset = DisplayServer.mouse_get_position() - get_window().position


func _input(e: InputEvent) -> void:
	if not dragging:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		dragging = false
		return
	if e is InputEventMouseMotion:
		get_window().position = DisplayServer.mouse_get_position() - drag_offset


# ---------- THEME / SCALE ----------

func _apply_theme() -> void:
	if str(data.get("theme", "dark")) == "light":
		BG = Color("f4f4f9")
		CARD = Color("ffffff")
		BORDER = Color("d8d8e6")
		ACCENT = Color("6a4cf0")
		ACCENT_SOFT = Color("5a3fd0")
		GREEN = Color("1fa36b")
		TEXT = Color("1c1c28")
		MUTED = Color("6a6a80")
		RED = Color("e03e5e")
	else:
		BG = Color("14141c")
		CARD = Color("1f1f2b")
		BORDER = Color("2e2e40")
		ACCENT = Color("7c5cff")
		ACCENT_SOFT = Color("b8a8ff")
		GREEN = Color("3ddc97")
		TEXT = Color("e8e8f0")
		MUTED = Color("8a8aa0")
		RED = Color("ff5c7a")


func _rebuild() -> void:
	note_target = -1
	pending_delete = ""
	dragging = false
	remove_child(panel_node)
	panel_node.queue_free()
	_build_ui()
	_apply_mode()
	_refresh()
	_request_fit()
	_save()


func _toggle_theme() -> void:
	data["theme"] = "light" if str(data.get("theme", "dark")) == "dark" else "dark"
	_apply_theme()
	_rebuild()


func _change_scale(delta: float) -> void:
	ui_scale = clampf(snappedf(ui_scale + delta, 0.1), SIZE_MIN, SIZE_MAX)
	data["size"] = ui_scale
	_rebuild()


func _toggle_mini() -> void:
	is_mini = not is_mini
	data["mini"] = is_mini
	_cancel_note()
	_apply_mode()
	_refresh()
	_save()


func _toggle_settings() -> void:
	if is_mini:
		return
	area_view = "tasks" if area_view == "settings" else "settings"
	pending_delete = ""
	_refresh_projects()
	_update_area_view()


# ---------- STYLE ----------

func _box(color: Color, radius := 10, border := 0, border_color := Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	s.content_margin_left = _f(10)
	s.content_margin_right = _f(10)
	s.content_margin_top = _f(8)
	s.content_margin_bottom = _f(8)
	return s


func _style_button(b: Button, color: Color, hover: Color, font_col := Color.TRANSPARENT, size := 15) -> void:
	var fc := TEXT if font_col == Color.TRANSPARENT else font_col
	b.add_theme_stylebox_override("normal", _box(color, 8))
	b.add_theme_stylebox_override("hover", _box(hover, 8))
	b.add_theme_stylebox_override("pressed", _box(hover, 8))
	b.add_theme_stylebox_override("focus", _box(color, 8))
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.add_theme_color_override("font_pressed_color", fc)
	b.add_theme_font_size_override("font_size", _f(size))
	b.focus_mode = Control.FOCUS_NONE


func _style_input(l: LineEdit, size := 17) -> void:
	l.add_theme_stylebox_override("normal", _box(CARD, 10, 1, BORDER))
	l.add_theme_stylebox_override("focus", _box(CARD, 10, 1, ACCENT))
	l.add_theme_color_override("font_color", TEXT)
	l.add_theme_color_override("font_placeholder_color", MUTED)
	l.add_theme_color_override("caret_color", ACCENT)
	l.add_theme_font_size_override("font_size", _f(size))
	l.custom_minimum_size = Vector2(0, _f(46))


func _mk_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", _f(size))
	l.add_theme_color_override("font_color", color)
	return l


# ---------- UI ----------

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(BG, 0, 1, BORDER))
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_node = panel

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, _f(12))
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", _f(10))
	margin.add_child(root)

	# ----- Header: the whole bar drags the window -----
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", _f(4))
	header.custom_minimum_size = Vector2(0, _f(40))
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header.gui_input.connect(_on_header_input)
	root.add_child(header)

	var title := _mk_label("⠿ DesignTracker", 16, MUTED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title)

	gear_btn = Button.new()
	gear_btn.text = "⚙"
	_style_button(gear_btn, CARD, BORDER, Color.TRANSPARENT, 17)
	gear_btn.pressed.connect(_toggle_settings)
	header.add_child(gear_btn)

	mini_btn = Button.new()
	mini_btn.text = "–"
	_style_button(mini_btn, CARD, BORDER, Color.TRANSPARENT, 17)
	mini_btn.pressed.connect(_toggle_mini)
	header.add_child(mini_btn)

	var close_btn := Button.new()
	close_btn.text = "✕"
	_style_button(close_btn, Color.TRANSPARENT, RED, Color.TRANSPARENT, 18)
	close_btn.pressed.connect(func(): _save(); get_tree().quit())
	header.add_child(close_btn)

	# ----- Project button -----
	switch_btn = Button.new()
	switch_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	switch_btn.clip_text = true
	switch_btn.custom_minimum_size = Vector2(0, _f(50))
	_style_button(switch_btn, CARD, BORDER, Color.TRANSPARENT, 19)
	switch_btn.add_theme_stylebox_override("normal", _box(CARD, 12, 1, BORDER))
	switch_btn.add_theme_stylebox_override("hover", _box(CARD, 12, 1, ACCENT))
	switch_btn.pressed.connect(_toggle_proj_panel)
	root.add_child(switch_btn)

	# ----- Circle in the middle -----
	var ring_center := CenterContainer.new()
	ring_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(ring_center)

	ring = Ring.new()
	ring.custom_minimum_size = Vector2(_f(200), _f(200))
	ring.sub_fs = _f(15)
	ring_center.add_child(ring)

	# ----- Mini card (only in minimized mode) -----
	mini_card = PanelContainer.new()
	mini_card.add_theme_stylebox_override("panel", _box(CARD, 12, 1, BORDER))
	root.add_child(mini_card)

	var mc := VBoxContainer.new()
	mc.add_theme_constant_override("separation", _f(6))
	mini_card.add_child(mc)

	mini_tag = _mk_label("NEXT TASK", 14, MUTED)
	mc.add_child(mini_tag)

	mini_text = _mk_label("", 20, TEXT)
	mini_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mini_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mc.add_child(mini_text)

	mini_done_btn = Button.new()
	mini_done_btn.text = "✓  Mark done"
	mini_done_btn.custom_minimum_size = Vector2(0, _f(42))
	_style_button(mini_done_btn, ACCENT, ACCENT.lightened(0.1), Color.WHITE, 16)
	mini_done_btn.pressed.connect(_mini_done)
	mc.add_child(mini_done_btn)

	# ----- Stats (full mode) -----
	stats_box = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", _f(4))
	root.add_child(stats_box)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", _f(10))
	grid.add_theme_constant_override("v_separation", _f(4))
	stats_box.add_child(grid)

	stat_total = _mk_label("", 18, TEXT)
	stat_done = _mk_label("", 18, GREEN)
	stat_left = _mk_label("", 18, ACCENT_SOFT)
	stat_today = _mk_label("", 18, AMBER)
	for l in [stat_total, stat_done, stat_left, stat_today]:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(l)

	stat_all = _mk_label("", 15, MUTED)
	stat_all.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_box.add_child(stat_all)

	# ----- Filter row (full mode) -----
	filter_row = HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", _f(6))
	root.add_child(filter_row)

	filter_btns.clear()
	for f in [["all", "All"], ["active", "Active"], ["done", "Done"]]:
		var fb := Button.new()
		fb.text = f[1]
		fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fb.custom_minimum_size = Vector2(0, _f(42))
		fb.pressed.connect(_set_filter.bind(f[0]))
		filter_row.add_child(fb)
		filter_btns[f[0]] = fb

	clear_btn = Button.new()
	clear_btn.text = "Clear 0"
	clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_btn.custom_minimum_size = Vector2(0, _f(42))
	_style_button(clear_btn, CARD, RED)
	clear_btn.pressed.connect(_clear_done)
	filter_row.add_child(clear_btn)

	# ----- Area: task list / project list / settings -----
	area = VBoxContainer.new()
	area.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(area)

	list_view = RichTextLabel.new()
	list_view.bbcode_enabled = true
	list_view.fit_content = false
	list_view.scroll_active = true
	list_view.selection_enabled = false
	list_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	list_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_view.custom_minimum_size = Vector2(0, _f(MIN_LIST))
	list_view.add_theme_color_override("default_color", TEXT)
	list_view.add_theme_font_size_override("normal_font_size", _f(FS_NAME))
	list_view.add_theme_stylebox_override("normal", _box(CARD, 12, 1, BORDER))
	list_view.meta_clicked.connect(_on_meta)
	area.add_child(list_view)

	# Project panel
	proj_panel = PanelContainer.new()
	proj_panel.visible = false
	proj_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	proj_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	proj_panel.custom_minimum_size = Vector2(0, _f(MIN_LIST))
	proj_panel.add_theme_stylebox_override("panel", _box(CARD, 12, 1, BORDER))
	area.add_child(proj_panel)

	var pp_box := VBoxContainer.new()
	pp_box.add_theme_constant_override("separation", _f(8))
	proj_panel.add_child(pp_box)

	var pp_scroll := ScrollContainer.new()
	pp_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pp_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pp_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pp_box.add_child(pp_scroll)

	proj_list = VBoxContainer.new()
	proj_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	proj_list.add_theme_constant_override("separation", _f(6))
	pp_scroll.add_child(proj_list)

	new_project_input = LineEdit.new()
	new_project_input.placeholder_text = "+ New project, press Enter"
	_style_input(new_project_input, 16)
	new_project_input.text_submitted.connect(_on_new_project)
	pp_box.add_child(new_project_input)

	# Settings panel
	settings_panel = PanelContainer.new()
	settings_panel.visible = false
	settings_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	settings_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_panel.add_theme_stylebox_override("panel", _box(CARD, 12, 1, BORDER))
	area.add_child(settings_panel)

	var sbox := VBoxContainer.new()
	sbox.add_theme_constant_override("separation", _f(14))
	settings_panel.add_child(sbox)

	sbox.add_child(_mk_label("Settings", 20, TEXT))

	# Theme row
	var theme_row := HBoxContainer.new()
	theme_row.add_theme_constant_override("separation", _f(8))
	sbox.add_child(theme_row)

	var theme_lbl := _mk_label("Theme", 17, TEXT)
	theme_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	theme_row.add_child(theme_lbl)

	var is_dark := str(data.get("theme", "dark")) == "dark"
	var theme_btn := Button.new()
	theme_btn.text = "Switch to Light" if is_dark else "Switch to Dark"
	theme_btn.custom_minimum_size = Vector2(0, _f(42))
	_style_button(theme_btn, BG, BORDER, Color.TRANSPARENT, 15)
	theme_btn.pressed.connect(_toggle_theme)
	theme_row.add_child(theme_btn)

	# Size row
	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", _f(8))
	sbox.add_child(size_row)

	var size_lbl := _mk_label("Size", 17, TEXT)
	size_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_row.add_child(size_lbl)

	var minus := Button.new()
	minus.text = "A-"
	minus.custom_minimum_size = Vector2(_f(54), _f(42))
	_style_button(minus, BG, BORDER, Color.TRANSPARENT, 16)
	minus.pressed.connect(_change_scale.bind(-0.1))
	size_row.add_child(minus)

	var size_val := _mk_label("%d%%" % int(round(ui_scale * 100.0)), 17, ACCENT_SOFT)
	size_val.custom_minimum_size = Vector2(_f(56), 0)
	size_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	size_val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	size_row.add_child(size_val)

	var plus := Button.new()
	plus.text = "A+"
	plus.custom_minimum_size = Vector2(_f(54), _f(42))
	_style_button(plus, BG, BORDER, Color.TRANSPARENT, 16)
	plus.pressed.connect(_change_scale.bind(0.1))
	size_row.add_child(plus)

	var hint := _mk_label("Drag the top bar to move the window anywhere on your screen.", 14, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(_f(200), 0)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sbox.add_child(hint)

	# ----- Input (fixed at the bottom, full mode) -----
	task_input = LineEdit.new()
	task_input.placeholder_text = "Add a task, press Enter"
	_style_input(task_input, 17)
	task_input.text_submitted.connect(_on_input_submitted)
	root.add_child(task_input)


func _set_filter(f: String) -> void:
	filter = f
	_refresh()


# ---------- PROJECTS ----------

func _tasks() -> Array:
	return data["projects"][data["current"]]


func _proj_counts(tasks: Array) -> Vector2i:
	var done := 0
	for t in tasks:
		if t["done"]:
			done += 1
	return Vector2i(done, tasks.size())


func _toggle_proj_panel() -> void:
	if is_mini:
		return
	area_view = "tasks" if area_view == "projects" else "projects"
	pending_delete = ""
	_refresh_projects()
	_update_area_view()


func _refresh_projects() -> void:
	for c in proj_list.get_children():
		proj_list.remove_child(c)
		c.queue_free()

	var cur := _proj_counts(_tasks())
	var arrow := ""
	if not is_mini:
		arrow = "▴  " if area_view == "projects" else "▾  "
	switch_btn.text = "%s%s    %d/%d" % [arrow, str(data["current"]), cur.x, cur.y]

	for key in data["projects"].keys():
		var pn := str(key)
		var cnt := _proj_counts(data["projects"][pn])
		var pct := 0
		if cnt.y > 0:
			pct = int(float(cnt.x) / cnt.y * 100.0)
		var is_cur := pn == str(data["current"])

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", _f(4))
		proj_list.add_child(row)

		var b := Button.new()
		b.text = "%s    %d/%d · %d%%" % [pn, cnt.x, cnt.y, pct]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.custom_minimum_size = Vector2(0, _f(44))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_cur:
			_style_button(b, ACCENT, ACCENT.lightened(0.1), Color.WHITE, 16)
		else:
			_style_button(b, BG, BORDER, Color.TRANSPARENT, 16)
		b.pressed.connect(_on_pick_project.bind(pn))
		row.add_child(b)

		var d := Button.new()
		d.custom_minimum_size = Vector2(_f(54), _f(44))
		if pending_delete == pn:
			d.text = "Sure?"
			_style_button(d, RED, RED, Color.WHITE, 14)
		else:
			d.text = "✕"
			_style_button(d, Color.TRANSPARENT, RED, Color.TRANSPARENT, 17)
		d.pressed.connect(_on_del_project.bind(pn))
		row.add_child(d)


func _close_proj_panel() -> void:
	area_view = "tasks"
	pending_delete = ""
	_update_area_view()


func _on_pick_project(pn: String) -> void:
	data["current"] = pn
	_close_proj_panel()
	_cancel_note()
	_save()
	_refresh()


func _on_new_project(text: String) -> void:
	text = text.strip_edges()
	if text == "" or data["projects"].has(text):
		return
	data["projects"][text] = []
	data["current"] = text
	new_project_input.clear()
	_close_proj_panel()
	_cancel_note()
	_save()
	_refresh()


func _on_del_project(pn: String) -> void:
	if pending_delete != pn:
		pending_delete = pn
		_refresh_projects()
		return
	pending_delete = ""
	if data["projects"].size() <= 1:
		data["projects"][pn] = []
	else:
		data["projects"].erase(pn)
		if str(data["current"]) == pn:
			data["current"] = str(data["projects"].keys()[0])
	_cancel_note()
	_save()
	_refresh()


# ---------- TASKS ----------

func _cancel_note() -> void:
	note_target = -1
	task_input.placeholder_text = "Add a task, press Enter"
	task_input.clear()


func _on_input_submitted(text: String) -> void:
	text = text.strip_edges()
	if note_target >= 0:
		if note_target < _tasks().size():
			_tasks()[note_target]["note"] = text
		_cancel_note()
	else:
		if text == "":
			return
		_tasks().append({
			"text": text,
			"done": false,
			"prio": 1,
			"created": Time.get_datetime_string_from_system(false, true),
			"completed": "",
			"note": ""
		})
		task_input.clear()
	_save()
	_refresh()


func _clear_done() -> void:
	var tasks := _tasks()
	var i := tasks.size() - 1
	while i >= 0:
		if bool(tasks[i].get("done", false)):
			tasks.remove_at(i)
		i -= 1
	_cancel_note()
	_save()
	_refresh()


func _visible_idxs() -> Array:
	var tasks := _tasks()
	var res := []
	for i in tasks.size():
		var d: bool = tasks[i]["done"]
		if filter == "active" and d:
			continue
		if filter == "done" and not d:
			continue
		res.append(i)
	return res


func _top_task() -> int:
	var tasks := _tasks()
	var best := -1
	var best_p := -1
	for i in tasks.size():
		if tasks[i]["done"]:
			continue
		var p := int(tasks[i].get("prio", 1))
		if p > best_p:
			best_p = p
			best = i
	return best


func _mini_done() -> void:
	if mini_idx < 0:
		return
	_on_meta("t%d" % mini_idx)


func _on_meta(meta) -> void:
	var s := str(meta)
	var kind := s.substr(0, 1)
	var idx := int(s.substr(1))
	var tasks := _tasks()
	if idx < 0 or idx >= tasks.size():
		return

	if kind == "t":
		var t: Dictionary = tasks[idx]
		t["done"] = not t["done"]
		t["completed"] = Time.get_datetime_string_from_system(false, true) if t["done"] else ""
	elif kind == "p":
		var cur := int(tasks[idx].get("prio", 1))
		tasks[idx]["prio"] = (cur + 1) % 3
	elif kind == "u" or kind == "v":
		var vis := _visible_idxs()
		var pos := vis.find(idx)
		var npos := pos - 1 if kind == "u" else pos + 1
		if pos >= 0 and npos >= 0 and npos < vis.size():
			var other: int = vis[npos]
			var tmp = tasks[idx]
			tasks[idx] = tasks[other]
			tasks[other] = tmp
		_cancel_note()
	elif kind == "d":
		tasks.remove_at(idx)
		_cancel_note()
	elif kind == "n":
		note_target = idx
		task_input.text = str(tasks[idx].get("note", ""))
		task_input.placeholder_text = "Note for: " + str(tasks[idx]["text"]).left(16) + "  (Enter)"
		task_input.grab_focus()
		task_input.caret_column = task_input.text.length()
	_save()
	_refresh()


func _esc(s: String) -> String:
	return s.replace("[", "[lb]")


func _refresh() -> void:
	_refresh_projects()
	_update_filters()

	var tasks := _tasks()
	var out := ""
	var c_text := TEXT.to_html(false)
	var c_muted := MUTED.to_html(false)
	var c_green := GREEN.to_html(false)
	var c_red := RED.to_html(false)
	var c_amber := AMBER.to_html(false)
	var c_acc := ACCENT_SOFT.to_html(false)
	var fs_name := _f(FS_NAME)
	var fs_ctrl := _f(FS_CTRL)
	var fs_meta := _f(FS_META)
	var fs_note := _f(FS_NOTE)

	var idxs := _visible_idxs()

	if idxs.is_empty():
		var msg := "No tasks yet. Type below and press Enter."
		if tasks.size() > 0:
			msg = "Nothing in this filter."
		out = "[color=#%s]%s[/color]" % [c_muted, msg]

	var pos := 0
	for i in idxs:
		pos += 1
		var t: Dictionary = tasks[i]
		var done: bool = t["done"]
		var box := "●" if done else "○"
		var box_col := c_green if done else c_acc
		var txt_col := c_muted if done else c_text
		var name_txt := _esc(str(t["text"]))
		if done:
			name_txt = "[s]" + name_txt + "[/s]"

		var prio := int(t.get("prio", 1))
		var p_txt := "MED"
		var p_col := c_amber
		if prio == 2:
			p_txt = "HIGH"
			p_col = c_red
		elif prio == 0:
			p_txt = "LOW"
			p_col = c_muted

		# Line 1: BIG task name (click = done / undone)
		out += "[font_size=%d][url=t%d][color=#%s]%d.[/color] [color=#%s]%s[/color]  [color=#%s]%s[/color][/url][/font_size]\n" % [fs_name, i, c_muted, pos, box_col, box, txt_col, name_txt]

		# Line 2: small controls
		out += "[font_size=%d]    [url=u%d][color=#%s]▲[/color][/url]   [url=v%d][color=#%s]▼[/color][/url]    [url=p%d][color=#%s]%s[/color][/url]    [url=n%d][color=#%s]✎[/color][/url]    [url=d%d][color=#%s]✕[/color][/url][/font_size]\n" % [fs_ctrl, i, c_acc, i, c_acc, i, p_col, p_txt, i, c_acc, i, c_red]

		# Line 3: small dates
		if done:
			out += "[font_size=%d][color=#%s]    done %s[/color][/font_size]\n" % [fs_meta, c_green, str(t["completed"]).substr(5, 11)]
		else:
			out += "[font_size=%d][color=#%s]    added %s[/color][/font_size]\n" % [fs_meta, c_muted, str(t.get("created", "")).substr(5, 11)]

		var note := str(t.get("note", ""))
		if note != "":
			out += "[font_size=%d][color=#%s]    note: %s[/color][/font_size]\n" % [fs_note, c_acc, _esc(note)]
		out += "\n"

	list_view.clear()
	list_view.append_text(out)
	list_view.scroll_to_line(0)
	_update_stats()
	_refresh_mini()
	_request_fit()


func _refresh_mini() -> void:
	mini_idx = _top_task()
	if mini_idx < 0:
		mini_tag.text = "NEXT TASK"
		mini_tag.add_theme_color_override("font_color", MUTED)
		mini_text.text = "No tasks yet" if _tasks().size() == 0 else "All tasks done"
		mini_done_btn.visible = false
		return

	var t: Dictionary = _tasks()[mini_idx]
	var prio := int(t.get("prio", 1))
	var tag := "MED"
	var col := AMBER
	if prio == 2:
		tag = "HIGH"
		col = RED
	elif prio == 0:
		tag = "LOW"
		col = MUTED
	mini_tag.text = "NEXT TASK  ·  " + tag
	mini_tag.add_theme_color_override("font_color", col)
	mini_text.text = str(t["text"])
	mini_done_btn.visible = true


func _update_filters() -> void:
	for key in filter_btns.keys():
		var b: Button = filter_btns[key]
		if key == filter:
			_style_button(b, ACCENT, ACCENT.lightened(0.1), Color.WHITE)
		else:
			_style_button(b, CARD, BORDER)


func _update_stats() -> void:
	var tasks := _tasks()
	var cnt := _proj_counts(tasks)
	var today_done := 0
	var today := Time.get_date_string_from_system()
	for t in tasks:
		if t["done"] and str(t["completed"]).begins_with(today):
			today_done += 1

	var pct := 0.0
	if cnt.y > 0:
		pct = float(cnt.x) / cnt.y * 100.0

	var all_done := 0
	var all_total := 0
	for key in data["projects"].keys():
		var c := _proj_counts(data["projects"][key])
		all_done += c.x
		all_total += c.y
	var pct_all := 0.0
	if all_total > 0:
		pct_all = float(all_done) / all_total * 100.0

	ring.pct = pct
	ring.pct_all = pct_all
	ring.col_main = GREEN if pct >= 100.0 else ACCENT
	ring.col_all = GREEN
	ring.col_track = BORDER
	ring.col_text = TEXT
	ring.col_sub = MUTED
	ring.queue_redraw()

	stat_total.text = "Total  %d" % cnt.y
	stat_done.text = "Done  %d" % cnt.x
	stat_left.text = "Left  %d" % (cnt.y - cnt.x)
	stat_today.text = "Today  %d" % today_done
	stat_all.text = "All projects: %d%%  (inner ring)" % int(pct_all)
	clear_btn.text = "Clear %d" % cnt.x


# ---------- SAVE / LOAD ----------

func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Save failed: " + str(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.flush()
	f.close()


func _load() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed is Dictionary and parsed.has("projects") and parsed["projects"].size() > 0:
				data = parsed
				if not data.has("theme"):
					data["theme"] = "dark"
				if not data.has("size"):
					data["size"] = SIZE_DEFAULT
				if not data.has("mini"):
					data["mini"] = false
				if not data["projects"].has(data.get("current", "")):
					data["current"] = str(data["projects"].keys()[0])
				return

	if FileAccess.file_exists(OLD_PATH):
		var old := FileAccess.open(OLD_PATH, FileAccess.READ)
		if old:
			var arr = JSON.parse_string(old.get_as_text())
			old.close()
			if arr is Array:
				for t in arr:
					t["created"] = ""
					t["completed"] = ""
					t["note"] = ""
					t["prio"] = 1
				data["projects"]["General"] = arr
				_save()
