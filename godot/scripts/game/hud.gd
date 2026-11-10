## Interfaz: menú principal, HUD de partida, panel Tab, ascensor, pausa y final.
class_name Hud
extends CanvasLayer

signal start_requested(opt: Dictionary)
signal elev_chosen(fl: int)
signal resume_requested
signal menu_requested
signal shop_buy(id: String)
signal elev_cut
signal settings_changed

const FL_SHORT := ["Sót.", "PB", "P2", "P10", "P20", "P30", "Azotea"]
const C_BG := Color(0.03, 0.05, 0.07, 0.86)
const C_LINE := Color("#2f4152")
const C_GOLD := Color("#ebd08a")
const C_TEXT := Color("#efe8d4")
const C_MUT := Color("#a9b2b8")
const C_RED := Color("#ff6a78")
const C_WARN := Color("#f0b04a")
const C_BLUE := Color("#6fb8ff")
const CONTROLS := "WASD / flechas: moverse · Shift: correr · E (mantener): interactuar, hablar · E: ascensor y tienda\nTab: mapa y encargos · Clic derecho: apuntar (cazador) · Clic izquierdo: disparar / cuchillo / llave inglesa\nRueda: zoom · Esc: pausa · F11: pantalla completa · Espacio: cambiar de personaje (espectador)"

var opt := {"role": "runner", "minutes": 12, "hunters": 2, "runners": 4}
var root: Control
var title_panel: Control
var play_root: Control
var chips: VBoxContainer
var chip_labels := {}
var sus_box: VBoxContainer
var sus_lbl: Label
var sus_bar: ProgressBar
var sus_flags: Label
var poster_box: VBoxContainer
var poster_title: Label
var portraits: Array = []
var hint_box: VBoxContainer
var hint_lbl: Label
var hint_bar: ProgressBar
var toasts: VBoxContainer
var minimap: Minimap
var tab_panel: PanelContainer
var tab_map: Minimap
var tab_text: RichTextLabel
var tab_title: Label
var tab_floor := -1
var elev_panel: PanelContainer
var elev_buttons: Array = []
var pause_panel: PanelContainer
var end_panel: PanelContainer
var end_title: Label
var end_reason: Label
var end_stats: Label
var fade: ColorRect
var last_log := 0
var log_list: Array = []
var role_buttons := {}
var shop_panel: PanelContainer
var shop_title: Label
var shop_money: Label
var shop_list: VBoxContainer
var settings_panel: PanelContainer
var cut_btn: Button
var status_lbl: Label
var vignette: TextureRect
var perk_row: HBoxContainer

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_vignette()
	_build_play()
	_build_tab()
	_build_elev()
	_build_shop()
	_build_pause()
	_build_end()
	_build_title()
	_build_settings()
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	get_viewport().size_changed.connect(_layout)
	_layout()

# ---------------------------------------------------------------- utilidades de construcción

func _sb(bg: Color, border: Color, bw: int = 1, pad: float = 8.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_content_margin_all(pad)
	return s

func _lbl(t: String, size: int = 14, col: Color = C_TEXT) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _panel(bg: Color = C_BG, border: Color = C_LINE, pad: float = 8.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(bg, border, 1, pad))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _btn(t: String, cb: Callable, size: int = 16) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", _sb(Color(0.06, 0.09, 0.12, 0.95), C_LINE, 1, 10))
	b.add_theme_stylebox_override("hover", _sb(Color(0.1, 0.13, 0.17, 0.98), C_GOLD, 1, 10))
	b.add_theme_stylebox_override("pressed", _sb(Color(0.16, 0.13, 0.07, 1), C_GOLD, 2, 10))
	b.add_theme_stylebox_override("disabled", _sb(Color(0.05, 0.06, 0.08, 0.8), Color(0.2, 0.24, 0.28), 1, 10))
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_color_override("font_hover_color", C_GOLD)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b

func _chip(key: String, col: Color = C_TEXT, border: Color = C_LINE) -> void:
	var p := _panel(C_BG, border, 6)
	var l := _lbl("", 14, col)
	l.uppercase = true
	p.add_child(l)
	chips.add_child(p)
	chip_labels[key] = [p, l]

func _set_chip(key: String, t: String) -> void:
	var c: Array = chip_labels[key]
	c[0].visible = t != ""
	c[1].text = t

func _center(c: Control) -> void:
	var vs := get_viewport().get_visible_rect().size
	c.reset_size()
	c.position = (vs - c.size) / 2.0

# ---------------------------------------------------------------- construcción

func _build_play() -> void:
	play_root = Control.new()
	play_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	play_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(play_root)
	chips = VBoxContainer.new()
	chips.position = Vector2(10, 10)
	chips.add_theme_constant_override("separation", 5)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_root.add_child(chips)
	_chip("floor")
	_chip("time")
	_chip("deal")
	_chip("own", C_BLUE)
	_chip("rep", C_RED, C_RED)
	_chip("sab", C_WARN, C_WARN)
	_chip("money", C_GOLD)
	_chip("gear", C_TEXT)
	_chip("intel", C_RED, C_RED)
	_chip("follow", C_MUT)
	sus_box = VBoxContainer.new()
	sus_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sus_box.custom_minimum_size = Vector2(260, 0)
	play_root.add_child(sus_box)
	var sh := HBoxContainer.new()
	sus_lbl = _lbl("SOSPECHA", 13, C_MUT)
	sus_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(sus_lbl)
	sus_box.add_child(sh)
	sus_bar = ProgressBar.new()
	sus_bar.max_value = 100
	sus_bar.show_percentage = false
	sus_bar.custom_minimum_size = Vector2(260, 12)
	sus_bar.add_theme_stylebox_override("background", _sb(Color(0.03, 0.05, 0.07, 0.9), C_LINE, 1, 0))
	sus_bar.add_theme_stylebox_override("fill", _sb(C_WARN, C_WARN, 0, 0))
	sus_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sus_box.add_child(sus_bar)
	sus_flags = _lbl("", 12, C_WARN)
	sus_flags.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sus_box.add_child(sus_flags)
	poster_box = VBoxContainer.new()
	poster_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_root.add_child(poster_box)
	poster_title = _lbl("TU CARTEL", 13, C_GOLD)
	poster_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	poster_box.add_child(poster_title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	poster_box.add_child(row)
	for i in 2:
		var p := Portrait.new()
		p.custom_minimum_size = Vector2(76, 96)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(p)
		portraits.append(p)
	hint_box = VBoxContainer.new()
	hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_root.add_child(hint_box)
	var hp := _panel(C_BG, C_LINE, 7)
	hint_lbl = _lbl("", 15)
	hint_lbl.uppercase = true
	hp.add_child(hint_lbl)
	hint_box.add_child(hp)
	hint_bar = ProgressBar.new()
	hint_bar.max_value = 1.0
	hint_bar.step = 0.0
	hint_bar.show_percentage = false
	hint_bar.custom_minimum_size = Vector2(0, 5)
	hint_bar.add_theme_stylebox_override("background", _sb(Color(0, 0, 0, 0.5), Color(0, 0, 0, 0), 0, 0))
	hint_bar.add_theme_stylebox_override("fill", _sb(C_GOLD, C_GOLD, 0, 0))
	hint_box.add_child(hint_bar)
	toasts = VBoxContainer.new()
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.add_theme_constant_override("separation", 5)
	toasts.custom_minimum_size = Vector2(380, 0)
	play_root.add_child(toasts)
	status_lbl = _lbl("", 15, C_GOLD)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_root.add_child(status_lbl)
	minimap = Minimap.new()
	minimap.custom_minimum_size = Vector2(236, 161)
	minimap.size = Vector2(236, 161)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_root.add_child(minimap)

func _build_tab() -> void:
	tab_panel = _panel(Color(0.04, 0.06, 0.09, 0.97), C_GOLD, 16)
	tab_panel.visible = false
	root.add_child(tab_panel)
	var v := VBoxContainer.new()
	tab_panel.add_child(v)
	var top := HBoxContainer.new()
	tab_title = _lbl("", 22, C_GOLD)
	tab_title.uppercase = true
	tab_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tab_title)
	top.add_child(_lbl("Tab o Esc para cerrar · la partida sigue en marcha", 12, C_MUT))
	v.add_child(top)
	var fb := HBoxContainer.new()
	for i in 7:
		var fi := i
		fb.add_child(_btn(FL_SHORT[i], func(): tab_floor = fi, 13))
	v.add_child(fb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	tab_map = Minimap.new()
	tab_map.labels = true
	tab_map.custom_minimum_size = Vector2(560, 382)
	h.add_child(tab_map)
	tab_text = RichTextLabel.new()
	tab_text.bbcode_enabled = true
	tab_text.custom_minimum_size = Vector2(400, 382)
	tab_text.add_theme_font_size_override("normal_font_size", 14)
	tab_text.add_theme_font_size_override("bold_font_size", 15)
	tab_text.add_theme_color_override("default_color", C_TEXT)
	h.add_child(tab_text)

func _build_elev() -> void:
	elev_panel = _panel(Color(0.04, 0.06, 0.09, 0.97), C_GOLD, 16)
	elev_panel.visible = false
	root.add_child(elev_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	elev_panel.add_child(v)
	v.add_child(_lbl("ASCENSOR", 22, C_GOLD))
	v.add_child(_lbl("Elige planta (teclas 1-7) · Esc para cerrar", 12, C_MUT))
	for i in range(Hotel.floors.size() - 1, -1, -1):
		var fi := i
		var f: FloorData = Hotel.floors[i]
		var b := _btn(str(i + 1) + " · " + f.label + " — " + f.sub, func(): elev_chosen.emit(fi), 15)
		v.add_child(b)
		elev_buttons.append([fi, b])
	cut_btn = _btn("Romper el ascensor con la cizalla (quieto " + str(Cfg.HOLD_CUT) + " s)", func(): elev_cut.emit(), 14)
	cut_btn.add_theme_color_override("font_color", C_WARN)
	v.add_child(cut_btn)

func _build_pause() -> void:
	pause_panel = _panel(Color(0.04, 0.06, 0.09, 0.97), C_GOLD, 22)
	pause_panel.visible = false
	root.add_child(pause_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pause_panel.add_child(v)
	v.add_child(_lbl("PAUSA", 26, C_GOLD))
	v.add_child(_lbl(CONTROLS, 12, C_MUT))
	v.add_child(_btn("Continuar", func(): resume_requested.emit()))
	v.add_child(_btn("Ajustes", func(): open_settings()))
	v.add_child(_btn("Menú principal", func(): menu_requested.emit()))

func _build_end() -> void:
	end_panel = _panel(Color(0.04, 0.06, 0.09, 0.97), C_GOLD, 26)
	end_panel.visible = false
	root.add_child(end_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	end_panel.add_child(v)
	end_title = _lbl("", 34, C_GOLD)
	v.add_child(end_title)
	end_reason = _lbl("", 16)
	end_reason.autowrap_mode = TextServer.AUTOWRAP_WORD
	end_reason.custom_minimum_size = Vector2(460, 0)
	v.add_child(end_reason)
	end_stats = _lbl("", 13, C_MUT)
	end_stats.autowrap_mode = TextServer.AUTOWRAP_WORD
	end_stats.custom_minimum_size = Vector2(460, 0)
	v.add_child(end_stats)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(_btn("Otra partida", func(): start_requested.emit(opt.duplicate())))
	h.add_child(_btn("Menú principal", func(): menu_requested.emit()))
	v.add_child(h)

func _build_title() -> void:
	title_panel = ColorRect.new()
	title_panel.color = Color(0.03, 0.05, 0.08, 0.78)
	title_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(title_panel)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_panel.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	cc.add_child(v)
	var t1 := _lbl("CAZA EN EL NEW YORKER", 44, C_GOLD)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t1)
	var t2 := _lbl("Hotel New Yorker · Nueva York, 1930", 16, C_MUT)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t2)
	v.add_child(_lbl("", 8))
	var rl := _lbl("ELIGE BANDO", 14, C_MUT)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(rl)
	var roles := HBoxContainer.new()
	roles.alignment = BoxContainer.ALIGNMENT_CENTER
	roles.add_theme_constant_override("separation", 10)
	v.add_child(roles)
	for r in [["runner", "Corredor"], ["hunter", "Cazador"], ["spectator", "Espectador"]]:
		var key: String = r[0]
		var b := _btn(r[1], func(): _pick_role(key), 18)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(170, 46)
		roles.add_child(b)
		role_buttons[key] = b
	var role_txt := _lbl("", 13, C_TEXT)
	role_txt.name = "RoleText"
	role_txt.autowrap_mode = TextServer.AUTOWRAP_WORD
	role_txt.custom_minimum_size = Vector2(560, 60)
	role_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(role_txt)
	var o := HBoxContainer.new()
	o.alignment = BoxContainer.ALIGNMENT_CENTER
	o.add_theme_constant_override("separation", 10)
	v.add_child(o)
	o.add_child(_lbl("Duración", 14, C_MUT))
	var mins := OptionButton.new()
	mins.focus_mode = Control.FOCUS_NONE
	for m in [8, 12, 16]:
		mins.add_item(str(m) + " min", m)
	mins.select(1)
	mins.item_selected.connect(func(i): opt["minutes"] = mins.get_item_id(i))
	o.add_child(mins)
	o.add_child(_lbl("   Cazadores", 14, C_MUT))
	var hn := OptionButton.new()
	hn.focus_mode = Control.FOCUS_NONE
	hn.add_item("1", 1)
	hn.add_item("2", 2)
	hn.select(1)
	hn.item_selected.connect(func(i): opt["hunters"] = hn.get_item_id(i))
	o.add_child(hn)
	o.add_child(_lbl("   Corredores", 14, C_MUT))
	var rn := OptionButton.new()
	rn.focus_mode = Control.FOCUS_NONE
	for n in [2, 3, 4]:
		rn.add_item(str(n), n)
	rn.select(2)
	rn.item_selected.connect(func(i): opt["runners"] = rn.get_item_id(i))
	o.add_child(rn)
	perk_row = HBoxContainer.new()
	perk_row.alignment = BoxContainer.ALIGNMENT_CENTER
	perk_row.add_theme_constant_override("separation", 10)
	perk_row.add_child(_lbl("Ventaja del cazador", 14, C_MUT))
	var pk := OptionButton.new()
	pk.focus_mode = Control.FOCUS_NONE
	var perk_ids: Array = Sim.PERKS
	for i in perk_ids.size():
		pk.add_item(str(Sim.PERK_NAMES[perk_ids[i]]), i)
	pk.select(0)
	opt["perk"] = perk_ids[0]
	pk.item_selected.connect(func(i): opt["perk"] = perk_ids[i])
	perk_row.add_child(pk)
	perk_row.add_child(_lbl("silenciador: menos testigos · llave: abre habitaciones · munición: 12 balas · fondos: +$" + str(Cfg.MONEY_RICH), 11, C_MUT))
	v.add_child(perk_row)
	var go := _btn("Empezar partida", func(): start_requested.emit(opt.duplicate()), 20)
	go.custom_minimum_size = Vector2(260, 52)
	var gc := CenterContainer.new()
	gc.add_child(go)
	v.add_child(gc)
	var sc := CenterContainer.new()
	sc.add_child(_btn("Ajustes", func(): open_settings(), 15))
	v.add_child(sc)
	var ctl := _lbl(CONTROLS, 12, C_MUT)
	ctl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ctl)
	var ver := _lbl("Prototipo v0.5 · Godot · partida contra bots", 11, Color(0.5, 0.55, 0.6))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ver)
	_pick_role("runner")

func _pick_role(key: String) -> void:
	opt["role"] = key
	for k in role_buttons:
		role_buttons[k].button_pressed = k == key
	var txt := {
		"runner": "Mafia contratada. Tienes 8-10 encargos propios por el hotel; el trato se cierra cuando todos los corredores terminan. Las habitaciones ajenas están cerradas: fuerza la cerradura o busca la llave maestra, pero si te ven te denuncian. Cobras por encargo y tu contacto del bar te vende material. Tus compañeros se ven con el nombre en azul.",
		"hunter": "Policía secreta infiltrada. Tu cartel muestra a dos corredores: elimínalos sin testigos. Tienes " + str(Cfg.AMMO) + " balas y un cuchillo. Si te ven, llamarán a la policía; cámbiate de ropa para que no te reconozcan. El conserje de recepción te vende material.",
		"spectator": "Mira una partida completa entre bots, sin niebla. Espacio cambia el personaje al que sigues.",
	}
	if perk_row != null:
		perk_row.visible = key == "hunter"
	var rt := title_panel.find_child("RoleText", true, false) as Label
	if rt != null:
		rt.text = txt[key]

# ---------------------------------------------------------------- estado de pantallas

func show_title() -> void:
	shop_panel.visible = false
	settings_panel.visible = false
	status_lbl.text = ""
	vignette.modulate.a = 0.0
	title_panel.visible = true
	play_root.visible = false
	tab_panel.visible = false
	elev_panel.visible = false
	pause_panel.visible = false
	end_panel.visible = false

func show_play(w: World) -> void:
	title_panel.visible = false
	play_root.visible = true
	end_panel.visible = false
	pause_panel.visible = false
	tab_panel.visible = false
	elev_panel.visible = false
	last_log = 0
	log_list.clear()
	for c in toasts.get_children():
		c.queue_free()
	minimap.w = w
	tab_map.w = w
	tab_floor = -1
	_layout()

func set_pause(on: bool) -> void:
	pause_panel.visible = on
	if on:
		_center(pause_panel)

func toggle_tab(on: bool) -> void:
	tab_panel.visible = on
	tab_floor = -1
	if on:
		_center(tab_panel)

func open_elev(cur_fl: int, has_cutter: bool = false) -> void:
	cut_btn.visible = has_cutter
	for eb in elev_buttons:
		eb[1].disabled = eb[0] == cur_fl
	elev_panel.visible = true
	_center(elev_panel)

func close_elev() -> void:
	elev_panel.visible = false

func show_end(w: World) -> void:
	var win: String = w.over.get("winner", "")
	var me_side := "runners" if w.role == "runner" else ("hunters" if w.role == "hunter" else "")
	if me_side == "":
		end_title.text = "FIN DE LA PARTIDA · ganan los " + ("corredores" if win == "runners" else "cazadores")
	else:
		end_title.text = "VICTORIA" if win == me_side else "DERROTA"
	end_reason.text = w.over.get("reason", "")
	var s := w.stats
	end_stats.text = "Tiempo jugado " + _fmt(w.time) + " · encargos " + str(w.tasks_done) + "/" + str(w.quota) + " · bajas " + str(s["kills"]) + " · llamadas a la policía " + str(s["calls"]) + " · denuncias " + str(s["reports"]) + " · detenciones " + str(s["arrests"]) + " · cerraduras forzadas " + str(s["forced"])
	end_panel.visible = true
	tab_panel.visible = false
	elev_panel.visible = false
	_center(end_panel)

func set_fade(a: float) -> void:
	fade.color = Color(0, 0, 0, a)

func _layout() -> void:
	if root == null:
		return
	var vs := get_viewport().get_visible_rect().size
	sus_box.position = Vector2(vs.x - 270, 10)
	poster_box.reset_size()
	poster_box.position = Vector2(vs.x - poster_box.size.x - 10, 70)
	minimap.position = Vector2(vs.x - 246, vs.y - 171)
	hint_box.reset_size()
	hint_box.position = Vector2((vs.x - hint_box.size.x) / 2.0, vs.y - 64)
	toasts.reset_size()
	toasts.position = Vector2(10, vs.y - toasts.size.y - 10)
	for p in [tab_panel, elev_panel, pause_panel, end_panel, shop_panel, settings_panel]:
		if p.visible:
			_center(p)

# ---------------------------------------------------------------- actualización por fotograma

static func _fmt(t: float) -> String:
	var s := maxi(0, ceili(t))
	return str(s / 60) + ":" + ("%02d" % (s % 60))

func log_visible(l: Items.LogEntry, role: String, hm: Ent) -> bool:
	if role == "runner":
		return l.kind != "call" and l.kind != "hunt" and (l.kind != "report" or (hm != null and l.who == hm.id))
	if role == "hunter":
		return l.kind != "task" and l.kind != "poster" and l.kind != "report" and l.kind != "team"
	return true

func _toast_color(kind: String) -> Color:
	match kind:
		"alarm":
			return Color("#d64a55")
		"call", "report":
			return C_WARN
		"task", "team":
			return Color("#5aa8ff")
		"poster":
			return Color("#aaaaaa")
	return C_GOLD

func pump_logs(w: World) -> Array:
	var kinds: Array = []
	for l in w.logs:
		if l.id <= last_log:
			continue
		last_log = l.id
		if not log_visible(l, w.role, w.human):
			continue
		log_list.append(l)
		kinds.append(l.kind)
		if log_list.size() > 60:
			log_list.remove_at(0)
		var p := PanelContainer.new()
		var sb := _sb(Color(0.03, 0.05, 0.07, 0.88), _toast_color(l.kind), 0, 8)
		sb.border_width_left = 3
		p.add_theme_stylebox_override("panel", sb)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lb := _lbl(l.msg, 13)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD
		lb.custom_minimum_size = Vector2(360, 0)
		p.add_child(lb)
		p.set_meta("born", Time.get_ticks_msec())
		toasts.add_child(p)
	while toasts.get_child_count() > 4:
		var c := toasts.get_child(0)
		toasts.remove_child(c)
		c.queue_free()
	var now := Time.get_ticks_msec()
	for n in toasts.get_children():
		var c := n as Control
		var age: int = now - int(c.get_meta("born", now))
		c.modulate.a = clampf(1.0 - (age - 6000) / 700.0, 0.0, 1.0)
		if age > 6700:
			toasts.remove_child(c)
			c.queue_free()
	toasts.reset_size()
	var vs := get_viewport().get_visible_rect().size
	toasts.position = Vector2(10, vs.y - toasts.size.y - 10)
	return kinds

func task_state(w: World, hm: Ent, t: Task) -> Array:
	if t.done:
		return ["done", "Hecho"]
	if t.kind == "drop" and hm.carry != t.id:
		return ["lock", "Necesitas recoger el encargo antes"]
	if t.kind == "pick" and hm.carry != "":
		return ["lock", "Ya llevas un encargo"]
	if t.room_name != "":
		var rm := Hotel.room_by(t.fl, t.room_name)
		if rm != null and not Sim.can_pass(w, hm, rm):
			return ["rlock", "Puerta cerrada: fuerza la cerradura o busca la llave maestra"]
	if t.kind == "drop":
		return ["", "Llevas el encargo: entrégalo"]
	if t.own:
		return ["", "En tu habitación"]
	return ["", ""]

func hold_label(h: Hold) -> String:
	match h.type:
		"strip":
			return "Cogiendo su ropa…"
		"ward":
			return "Registrando el armario…"
		"wash":
			return "Lavando el traje…"
		"force":
			return "Forzando la cerradura…"
		"talk":
			return "Hablando…"
		"cut":
			return "Cortando los cables del ascensor…"
		"task":
			return h.ref.nm + "…"
	return "…"

func update_hud(w: World, view: Ent) -> void:
	if w == null or view == null:
		return
	var hm := w.human
	var role := w.role
	var f: FloorData = Hotel.floors[view.fl]
	_set_chip("floor", f.label + " · " + f.sub)
	var left := w.limit - w.time
	_set_chip("time", ("Cliente " if role == "runner" else "Tiempo ") + _fmt(left))
	if role == "runner":
		var mu := Sim.task_units(hm)
		_set_chip("deal", "Encargos " + str(mu.x) + "/" + str(mu.y) + " · equipo " + str(w.tasks_done) + "/" + str(w.quota))
		var rm := Hotel.room_by(hm.room_floor, hm.room)
		_set_chip("own", "Tu habitación " + rm.number() + " · " + FL_SHORT[hm.room_floor])
		if not hm.alive:
			_set_chip("rep", "Has caído · sigues viendo la partida")
		elif hm.arrest > 0:
			_set_chip("rep", "Detenido " + str(ceili(hm.arrest)) + " s")
		elif hm.marked:
			_set_chip("rep", "Fichado · la policía te detiene si te ve")
		elif hm.reports > 0:
			_set_chip("rep", "Denuncias " + str(hm.reports) + "/" + str(Cfg.STRIKES))
		else:
			_set_chip("rep", "")
		_set_chip("follow", "")
	elif role == "hunter":
		var alive := 0
		for e in w.ents:
			if e.id in w.targets and e.alive:
				alive += 1
		_set_chip("deal", "Objetivos vivos " + str(alive) + "/2")
		_set_chip("own", "")
		_set_chip("rep", "" if hm.alive else "Has caído · sigues viendo la partida")
		_set_chip("follow", "")
	else:
		_set_chip("deal", "Encargos del equipo " + str(w.tasks_done) + "/" + str(w.quota))
		_set_chip("own", "")
		_set_chip("rep", "")
		_set_chip("follow", "Sigues a " + view.nm + " · Espacio para cambiar")
	if hm != null and role != "spectator":
		_set_chip("money", "$ " + str(hm.money))
		var gear: Array = []
		if role == "hunter":
			gear.append("Balas " + str(hm.ammo) + "/" + str(hm.ammo_max) + " · cuchillo")
		if hm.masterkey:
			gear.append("llave maestra")
		if hm.lockpick:
			gear.append("ganzúa")
		if hm.cutter:
			gear.append("cizalla")
		if role == "runner":
			gear.append("llave inglesa" if hm.melee else "piezas " + str(mini(hm.scrap, Cfg.SCRAP_NEEDED)) + "/" + str(Cfg.SCRAP_NEEDED))
		_set_chip("gear", " · ".join(PackedStringArray(gear)))
		if hm.intel_until > w.time:
			if role == "runner":
				_set_chip("intel", "Chivatazo " + _fmt(hm.intel_until - w.time) + " · cazadores en " + Sim.floor_list(w, "hunter"))
			else:
				_set_chip("intel", "Rastro " + _fmt(hm.intel_until - w.time) + " · objetivos en " + Sim.floor_list(w, w.targets))
		else:
			_set_chip("intel", "")
	else:
		_set_chip("money", "")
		_set_chip("gear", "")
		_set_chip("intel", "")
	var sb: Array = []
	if w.sab_blackout > w.time:
		sb.append("Apagón " + _fmt(w.sab_blackout - w.time))
	if w.sab_alarm > w.time:
		sb.append("Alarma de incendios " + _fmt(w.sab_alarm - w.time))
	if w.sab_elev > w.time:
		sb.append("Ascensores averiados " + _fmt(w.sab_elev - w.time))
	_set_chip("sab", " · ".join(PackedStringArray(sb)))
	# sospecha
	if hm != null and hm.alive and role == "hunter":
		sus_box.visible = true
		sus_lbl.text = "SOSPECHA  " + str(roundi(hm.sus))
		sus_bar.value = hm.sus
		var fl := ""
		if hm.restricted:
			fl += "Zona restringida  "
		if hm.outfit.blood:
			fl += "Traje manchado  "
		if hm.aim:
			fl += "Arma fuera  "
		if Sim.is_hot(w, hm):
			fl += "La policía te describe"
		sus_flags.text = fl
	elif hm != null and hm.alive and role == "runner" and hm.sus > 2:
		sus_box.visible = true
		sus_lbl.text = "TE VIGILAN  " + str(roundi(hm.sus))
		sus_bar.value = hm.sus
		sus_flags.text = "Habitación ajena" if hm.restricted else ""
	else:
		sus_box.visible = false
	# carteles
	if role == "hunter":
		poster_box.visible = true
		poster_title.text = "TU CARTEL"
		for i in 2:
			var p: Portrait = portraits[i]
			var t: Ent = w.ent_by_id(w.targets[i]) if i < w.targets.size() else null
			p.visible = t != null
			if t != null:
				p.outfit = t.outfit
				p.dead = not t.alive
				p.grey = false
				p.caption = "Objetivo " + str(i + 1)
				p.queue_redraw()
	elif role == "runner" and not w.posters.is_empty():
		poster_box.visible = true
		poster_title.text = "SE BUSCA"
		for i in 2:
			var p: Portrait = portraits[i]
			p.visible = i < w.posters.size()
			if p.visible:
				var ps: Items.Poster = w.posters[i]
				p.outfit = ps.outfit
				p.grey = ps.state != "active"
				p.dead = false
				p.caption = "Cazador" if ps.state == "active" else "Ha cambiado"
				p.queue_redraw()
	else:
		poster_box.visible = false
	# acción
	var ht := ""
	var hv := -1.0
	if hm != null and hm.alive and view == hm:
		if hm.hold != null:
			ht = hold_label(hm.hold)
			hv = hm.hold.t / hm.hold.dur
		elif not w.hint.is_empty():
			var hint: Dictionary = w.hint
			ht = "[E] " + str(hint["label"])
			if hint["type"] != "elev" and hint["type"] != "elevx":
				ht += "  (mantén " + str(snappedf(hint["dur"], 0.1)) + " s)"
	hint_box.visible = ht != ""
	hint_lbl.text = ht
	hint_bar.visible = hv >= 0
	hint_bar.value = maxf(hv, 0.0)
	var vgt := 0.0
	if hm != null and hm.alive and (role == "hunter" or role == "runner") and hm.sus > Cfg.WARN_AT:
		vgt = clampf((hm.sus - Cfg.WARN_AT) / (100.0 - Cfg.WARN_AT), 0.0, 1.0) * 0.75
	if hm != null and hm.alive and hm.arrest > 0:
		vgt = 0.8
	vignette.modulate.a = lerpf(vignette.modulate.a, vgt, 0.1)
	if status_lbl.text != "":
		var vs3 := get_viewport().get_visible_rect().size
		status_lbl.reset_size()
		status_lbl.position = Vector2((vs3.x - status_lbl.size.x) / 2.0, vs3.y - 110)
	if hint_box.visible:
		hint_box.reset_size()
		var vs := get_viewport().get_visible_rect().size
		hint_box.position = Vector2((vs.x - hint_box.size.x) / 2.0, vs.y - 70)
	minimap.fl = view.fl
	minimap.view_ent = view
	minimap.role = role
	if poster_box.visible:
		poster_box.reset_size()
		var vs2 := get_viewport().get_visible_rect().size
		poster_box.position = Vector2(vs2.x - poster_box.size.x - 10, 70 if sus_box.visible else 10)
	if tab_panel.visible:
		_update_tab(w, view)

func _update_tab(w: World, view: Ent) -> void:
	var fl := view.fl if tab_floor < 0 else tab_floor
	var f: FloorData = Hotel.floors[fl]
	tab_title.text = f.label + " · " + f.sub
	tab_map.fl = fl
	tab_map.view_ent = view
	tab_map.role = w.role
	var hm := w.human
	var s := ""
	if w.role == "runner":
		var mu := Sim.task_units(hm)
		var own := Hotel.room_by(hm.room_floor, hm.room)
		s += "[color=#ebd08a][b]TUS ENCARGOS " + str(mu.x) + " / " + str(mu.y) + "[/b][/color]\n"
		s += "[color=#a9b2b8]Equipo " + str(w.tasks_done) + " / " + str(w.quota) + " · tu habitación: " + own.label() + " (" + Hotel.floors[own.fi].label + ")[/color]\n\n"
		var ts: Array = hm.tasks.duplicate()
		ts.sort_custom(func(a, b): return a.fl < b.fl)
		for t in ts:
			var st := task_state(w, hm, t)
			var col := "#efe8d4"
			if st[0] == "done":
				col = "#6a7682"
			elif st[0] == "lock":
				col = "#8a8f94"
			elif t.fl == fl:
				col = "#ebd08a"
			s += "[color=" + col + "]" + FL_SHORT[t.fl] + "  " + ("✓ " if t.done else "") + t.nm + "[/color]"
			if st[1] != "" and not t.done:
				s += "\n      [color=" + ("#f0b04a" if st[0] == "rlock" else "#a9b2b8") + "][font_size=12]" + st[1] + "[/font_size][/color]"
			s += "\n"
		s += "\n[color=#ebd08a][b]ESTADO[/b][/color]\n"
		s += "Dinero $" + str(hm.money) + " · Ganzúa " + ("✓" if hm.lockpick else "—") + " · Cizalla " + ("✓" if hm.cutter else "—") + "\n"
		s += "Llave maestra " + ("✓" if hm.masterkey else "—") + " · Llave inglesa " + ("✓" if hm.melee else str(mini(hm.scrap, Cfg.SCRAP_NEEDED)) + "/" + str(Cfg.SCRAP_NEEDED)) + " · Encargo " + ("en mano" if hm.carry != "" else "—") + " · Denuncias " + str(hm.reports) + "/" + str(Cfg.STRIKES) + "\n"
	elif w.role == "hunter":
		s += "[color=#ebd08a][b]CARTEL[/b][/color]\n"
		for i in w.targets.size():
			var t := w.ent_by_id(w.targets[i])
			s += "Objetivo " + str(i + 1) + ": " + ("vivo" if t != null and t.alive else "[color=#ff6a78]eliminado[/color]") + "\n"
		s += "\n[color=#ebd08a][b]TU ASPECTO[/b][/color]\n" + hm.outfit.describe() + ("  [color=#ff6a78](manchado de sangre)[/color]" if hm.outfit.blood else "") + "\n"
		s += "\n[color=#ebd08a][b]EQUIPO[/b][/color]\nDinero $" + str(hm.money) + " · Balas " + str(hm.ammo) + "/" + str(hm.ammo_max) + " · Ventaja: " + str(Sim.PERK_NAMES.get(hm.perk, "—")) + "\n"
		s += "\n[color=#ebd08a][b]ACCESOS[/b][/color]\nLlave maestra " + ("✓" if hm.masterkey else "—") + " · Insignia " + ("✓" if hm.badge else "—") + (" · Uniforme de personal ✓" if hm.outfit.staff_role != "" else "") + "\n"
	else:
		s += "[color=#ebd08a][b]CORREDORES[/b][/color]\n"
		for e in w.ents:
			if e.role == "runner":
				var mu := Sim.task_units(e)
				s += e.nm + ("" if e.alive else " [color=#ff6a78](caído)[/color]") + (" [color=#ebd08a](objetivo)[/color]" if e.id in w.targets else "") + " · " + str(mu.x) + "/" + str(mu.y) + " · denuncias " + str(e.reports) + "\n"
		s += "\n[color=#ebd08a][b]CAZADORES[/b][/color]\n"
		for e in w.ents:
			if e.role == "hunter":
				s += e.nm + ("" if e.alive else " [color=#ff6a78](caído)[/color]") + " · sospecha " + str(roundi(e.sus)) + "\n"
	s += "\n[color=#ebd08a][b]SUCESOS[/b][/color]\n"
	var n := 0
	for i in range(log_list.size() - 1, -1, -1):
		if n >= 7:
			break
		var l: Items.LogEntry = log_list[i]
		s += "[color=#6a7682]" + _fmt(l.t) + "[/color] [font_size=12]" + l.msg + "[/font_size]\n"
		n += 1
	if tab_text.text != s:
		tab_text.text = s

# ---------------------------------------------------------------- viñeta, tienda y ajustes

func _build_vignette() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.6, 0.02, 0.05, 0.0))
	g.set_color(1, Color(0.6, 0.02, 0.05, 0.85))
	g.add_point(0.55, Color(0.6, 0.02, 0.05, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 0.5)
	gt.width = 256
	gt.height = 256
	vignette = TextureRect.new()
	vignette.texture = gt
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.modulate.a = 0.0
	root.add_child(vignette)

func set_status(t: String) -> void:
	status_lbl.text = t

func _build_shop() -> void:
	shop_panel = _panel(Color(0.04, 0.06, 0.09, 0.97), C_GOLD, 18)
	shop_panel.visible = false
	root.add_child(shop_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	shop_panel.add_child(v)
	shop_title = _lbl("", 22, C_GOLD)
	v.add_child(shop_title)
	shop_money = _lbl("", 15, C_TEXT)
	v.add_child(shop_money)
	shop_list = VBoxContainer.new()
	shop_list.add_theme_constant_override("separation", 6)
	v.add_child(shop_list)
	v.add_child(_lbl("Esc o E para cerrar", 12, C_MUT))

func open_shop(w: World, e: Ent) -> void:
	shop_title.text = "EL CONTACTO DEL BAR" if e.role == "runner" else "EL CONSERJE DE RECEPCIÓN"
	refresh_shop(w, e)
	shop_panel.visible = true
	_center(shop_panel)

func refresh_shop(w: World, e: Ent) -> void:
	shop_money.text = "Tienes $" + str(e.money)
	for c in shop_list.get_children():
		shop_list.remove_child(c)
		c.queue_free()
	for it in Sim.shop_items(w, e):
		var id: String = it["id"]
		var price: int = it["price"]
		var ptxt := ("$" + str(price)) if price > 0 else ("te pagan $" + str(-price))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var b := _btn(str(it["name"]) + "  ·  " + ptxt, func(): shop_buy.emit(id), 15)
		b.custom_minimum_size = Vector2(300, 0)
		b.disabled = not it["ok"] or (price > 0 and e.money < price)
		row.add_child(b)
		var d := _lbl(str(it["desc"]) if it["ok"] else str(it["why"]), 12, C_MUT if it["ok"] else Color(0.55, 0.58, 0.6))
		d.custom_minimum_size = Vector2(330, 0)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.add_child(d)
		shop_list.add_child(row)
	shop_panel.reset_size()
	_center(shop_panel)

func close_shop() -> void:
	shop_panel.visible = false

func _build_settings() -> void:
	settings_panel = _panel(Color(0.04, 0.06, 0.09, 0.98), C_GOLD, 20)
	settings_panel.visible = false
	root.add_child(settings_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	settings_panel.add_child(v)
	v.add_child(_lbl("AJUSTES", 24, C_GOLD))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	_slider(grid, "Volumen general", 0.0, 1.0, Settings.volume, func(x): Settings.volume = x)
	_slider(grid, "Volumen de los pasos", 0.0, 1.0, Settings.steps, func(x): Settings.steps = x)
	_slider(grid, "Zoom de la cámara", 1.0, 3.5, Settings.zoom, func(x): Settings.zoom = x)
	_slider(grid, "Opacidad de la niebla", 0.6, 1.0, Settings.fog, func(x): Settings.fog = x)
	_check(grid, "Flechas hacia los encargos", Settings.arrows, func(x): Settings.arrows = x)
	_check(grid, "Sacudida de cámara", Settings.shake, func(x): Settings.shake = x)
	_check(grid, "Pantalla completa (F11)", Settings.fullscreen, func(x): Settings.fullscreen = x)
	v.add_child(_btn("Guardar y cerrar", func(): close_settings(), 16))

func _slider(grid: GridContainer, label: String, lo: float, hi: float, val: float, cb: Callable) -> void:
	grid.add_child(_lbl(label, 14))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = val
	s.custom_minimum_size = Vector2(240, 20)
	s.focus_mode = Control.FOCUS_NONE
	var on_change := func(x: float) -> void:
		cb.call(x)
		settings_changed.emit()
	s.value_changed.connect(on_change)
	grid.add_child(s)

func _check(grid: GridContainer, label: String, val: bool, cb: Callable) -> void:
	grid.add_child(_lbl(label, 14))
	var c := CheckBox.new()
	c.button_pressed = val
	c.focus_mode = Control.FOCUS_NONE
	var on_toggle := func(x: bool) -> void:
		cb.call(x)
		settings_changed.emit()
	c.toggled.connect(on_toggle)
	grid.add_child(c)

func open_settings() -> void:
	settings_panel.visible = true
	_center(settings_panel)

func close_settings() -> void:
	settings_panel.visible = false
	Settings.save_cfg()
	settings_changed.emit()
