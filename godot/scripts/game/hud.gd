## Interfaz: menú principal, HUD de partida, bloc de notas (Tab), mapa (M), inventario (I),
## tienda, ascensor, minijuego, pausa, ajustes, final y cinemáticas.
class_name Hud
extends CanvasLayer

signal start_requested(opt: Dictionary)
signal elev_chosen(fl: int)
signal resume_requested
signal menu_requested
signal shop_buy(id: String)
signal elev_cut
signal settings_changed
signal quit_requested
signal minigame_done(ok: bool)

const FL_SHORT := ["Sót.", "PB", "P2", "P10", "P20", "P30", "Azotea"]
const C_BG := Color(0.03, 0.05, 0.07, 0.86)
const C_LINE := Color("#2f4152")
const C_GOLD := Color("#ebd08a")
const C_TEXT := Color("#efe8d4")
const C_MUT := Color("#a9b2b8")
const C_RED := Color("#ff6a78")
const C_WARN := Color("#f0b04a")
const C_BLUE := Color("#6fb8ff")
const CONTROLS := "WASD / flechas: moverse · Shift: correr · E o clic: hablar, comprar, ascensor · E mantenido: encargos y cerraduras\nQ: cambiar lo que llevas en la mano · clic derecho: apuntar · clic izquierdo: usar · Tab: bloc de notas · M: mapa · I: inventario\nRueda: zoom · Esc: pausa · F11: pantalla completa · Espacio: cambiar de personaje (espectador)"
const HOW := "[b][color=#ebd08a]DOS BANDOS[/color][/b]\n[b]Cazadores[/b] (máx. 2): policía secreta infiltrada. Ganan eliminando a los dos retratados en su cartel.\n[b]Corredores[/b] (máx. 4): mafia contratada. Ganan si todos terminan sus encargos, si aguantan hasta que llegue el cliente o si caen los cazadores.\n\n[b][color=#ebd08a]CORREDORES[/color][/b]\nCada uno tiene 8-10 encargos en el bloc de notas (Tab). Las habitaciones ajenas están cerradas: fuerza la cerradura o busca la llave maestra; si te ven, te denuncian y a la tercera quedas fichado. El contacto del bar (Planta 2) vende material y ofrece trabajos extra por dinero. El primero en terminar recibe una pistola y el chivatazo de quién es un cazador. Los demás pueden hacer encargos de sus compañeros.\n\n[b][color=#ebd08a]CAZADORES[/color][/b]\n8 balas y un cuchillo (Q para cambiar). Si te ven matar, llaman a la policía y reparten un cartel con tu aspecto: cámbiate de ropa. El vigilante de la entrada te vende material.\n\n[b][color=#ebd08a]LA POLICÍA[/color][/b]\nSe puede matar a un policía, pero sube la alarma. [b]Nivel 1:[/b] refuerzos y cacheos; si llevas algo encima, te esposan en el vestíbulo 1:30 (soborno, ganzúa o llave de las esposas para salir). [b]Nivel 2:[/b] llegan los federales y registran todo; el bando culpable paga en tiempo. [b]Nivel 3, BLUEGEDDON:[/b] la policía dispara a cualquiera; los corredores pueden escapar con una cuerda (azotea) o la llave del muelle (sótano)."

var opt := {"role": "runner", "minutes": 12, "hunters": 2, "runners": 4, "perk": "silencer"}
var root: Control
var title_panel: Control
var menu_box: VBoxContainer
var lobby_panel: PanelContainer
var info_panel: PanelContainer
var info_text: RichTextLabel
var play_root: Control
var mini_frame: PanelContainer
var minimap: Minimap
var mini_title: Label
var floor_banner: Label
var floor_banner_t := 0.0
var last_floor := -1
var clock: Stopwatch
var badges: VBoxContainer
var badge_labels := {}
var sus_box: VBoxContainer
var sus_lbl: Label
var sus_bar: ProgressBar
var poster_box: VBoxContainer
var poster_title: Label
var portraits: Array = []
var quick: QuickBar
var hint_box: VBoxContainer
var hint_lbl: Label
var hint_bar: ProgressBar
var status_lbl: Label
var toasts: VBoxContainer
var notes_panel: Control
var notebook: Notebook
var map_panel: PanelContainer
var map_big: Minimap
var map_title: Label
var map_floor := -1
var inv_panel: PanelContainer
var inv_text: RichTextLabel
var elev_panel: PanelContainer
var elev_buttons: Array = []
var cut_btn: Button
var shop_panel: PanelContainer
var shop_title: Label
var shop_money: Label
var shop_list: VBoxContainer
var pause_panel: PanelContainer
var end_panel: PanelContainer
var end_title: Label
var end_reason: Label
var end_stats: Label
var settings_panel: PanelContainer
var pick: PickGame
var fade: ColorRect
var vignette: TextureRect
var bar_top: ColorRect
var bar_bot: ColorRect
var cine_banner: PanelContainer
var cine_label: Label
var big_label: Label
var big_sub: Label
var perk_row: HBoxContainer
var role_buttons := {}
var last_log := 0
var log_list: Array = []

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_vignette()
	_build_play()
	_build_cine()
	_build_notes()
	_build_map()
	_build_inv()
	_build_elev()
	_build_shop()
	_build_pick()
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

# ---------------------------------------------------------------- utilidades

func _sb(bg: Color, border: Color, bw: int = 1, pad: float = 8.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_content_margin_all(pad)
	return s

func _lbl(t: String, fs: int = 14, col: Color = C_TEXT) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _panel(bg: Color = C_BG, border: Color = C_LINE, pad: float = 8.0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _sb(bg, border, 1, pad)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 8
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _deco_panel(pad: float = 18.0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _sb(Color(0.035, 0.05, 0.075, 0.97), C_GOLD, 2, pad)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 14
	sb.set_corner_radius_all(2)
	p.add_theme_stylebox_override("panel", sb)
	return p

func _btn(t: String, cb: Callable, fs: int = 16) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_stylebox_override("normal", _sb(Color(0.06, 0.09, 0.12, 0.95), C_LINE, 1, 10))
	b.add_theme_stylebox_override("hover", _sb(Color(0.12, 0.1, 0.06, 0.98), C_GOLD, 1, 10))
	b.add_theme_stylebox_override("pressed", _sb(Color(0.16, 0.13, 0.07, 1), C_GOLD, 2, 10))
	b.add_theme_stylebox_override("disabled", _sb(Color(0.05, 0.06, 0.08, 0.8), Color(0.2, 0.24, 0.28), 1, 10))
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_color_override("font_hover_color", C_GOLD)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b

func _menu_btn(t: String, cb: Callable) -> Button:
	var b := _btn(t, cb, 20)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(300, 46)
	b.add_theme_stylebox_override("normal", _sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 12))
	var hv := _sb(Color(0.92, 0.82, 0.54, 0.12), C_GOLD, 0, 12)
	hv.border_width_left = 3
	b.add_theme_stylebox_override("hover", hv)
	return b

func _center(c: Control) -> void:
	var vs := get_viewport().get_visible_rect().size
	c.reset_size()
	c.position = (vs - c.size) / 2.0

func _badge(key: String, col: Color, border: Color) -> void:
	var p := _panel(C_BG, border, 5)
	var l := _lbl("", 13, col)
	l.uppercase = true
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p.add_child(l)
	badges.add_child(p)
	badge_labels[key] = [p, l]

func _set_badge(key: String, t: String) -> void:
	var b: Array = badge_labels[key]
	b[0].visible = t != ""
	b[1].text = t

static func _fmt(t: float) -> String:
	var s := maxi(0, ceili(t))
	return str(s / 60) + ":" + ("%02d" % (s % 60))

# ---------------------------------------------------------------- HUD de partida

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

func _build_play() -> void:
	play_root = Control.new()
	play_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	play_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(play_root)
	# minimapa con el nombre de la planta (arriba a la izquierda)
	mini_frame = _panel(Color(0.03, 0.05, 0.07, 0.9), C_GOLD, 4)
	mini_frame.position = Vector2(12, 12)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 3)
	mini_frame.add_child(mv)
	mini_title = _lbl("", 12, C_GOLD)
	mini_title.uppercase = true
	mv.add_child(mini_title)
	minimap = Minimap.new()
	minimap.custom_minimum_size = Vector2(230, 157)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mv.add_child(minimap)
	play_root.add_child(mini_frame)
	floor_banner = _lbl("", 30, C_GOLD)
	floor_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floor_banner.uppercase = true
	floor_banner.modulate.a = 0.0
	play_root.add_child(floor_banner)
	# reloj y avisos (arriba a la derecha)
	clock = Stopwatch.new()
	clock.custom_minimum_size = Vector2(130, 150)
	clock.size = Vector2(130, 150)
	clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_root.add_child(clock)
	badges = VBoxContainer.new()
	badges.alignment = BoxContainer.ALIGNMENT_BEGIN
	badges.add_theme_constant_override("separation", 4)
	badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_root.add_child(badges)
	_badge("alarm", Color.WHITE, C_RED)
	_badge("rep", C_RED, C_RED)
	_badge("sab", C_WARN, C_WARN)
	_badge("intel", C_RED, C_RED)
	_badge("follow", C_MUT, C_LINE)
	sus_box = VBoxContainer.new()
	sus_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sus_lbl = _lbl("SOSPECHA", 12, C_MUT)
	sus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sus_box.add_child(sus_lbl)
	sus_bar = ProgressBar.new()
	sus_bar.max_value = 100
	sus_bar.show_percentage = false
	sus_bar.custom_minimum_size = Vector2(200, 8)
	sus_bar.add_theme_stylebox_override("background", _sb(Color(0.03, 0.05, 0.07, 0.9), C_LINE, 1, 0))
	sus_bar.add_theme_stylebox_override("fill", _sb(C_WARN, C_WARN, 0, 0))
	sus_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sus_box.add_child(sus_bar)
	badges.add_child(sus_box)
	poster_box = VBoxContainer.new()
	poster_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	poster_title = _lbl("TU CARTEL", 12, C_GOLD)
	poster_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	poster_box.add_child(poster_title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	poster_box.add_child(row)
	for i in 2:
		var p := Portrait.new()
		p.custom_minimum_size = Vector2(60, 76)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(p)
		portraits.append(p)
	badges.add_child(poster_box)
	# inventario rápido (abajo a la izquierda)
	quick = QuickBar.new()
	quick.custom_minimum_size = Vector2(320, 110)
	quick.size = Vector2(320, 110)
	quick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_root.add_child(quick)
	# acción (abajo en el centro)
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
	status_lbl = _lbl("", 15, C_GOLD)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_root.add_child(status_lbl)
	# avisos (arriba en el centro)
	toasts = VBoxContainer.new()
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.add_theme_constant_override("separation", 4)
	play_root.add_child(toasts)
	# rótulo grande (alarma, Bluegeddon)
	big_label = _lbl("", 64, C_BLUE)
	big_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_label.add_theme_constant_override("outline_size", 10)
	big_label.modulate.a = 0.0
	play_root.add_child(big_label)
	big_sub = _lbl("", 18, C_TEXT)
	big_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_sub.modulate.a = 0.0
	play_root.add_child(big_sub)

func _build_cine() -> void:
	bar_top = ColorRect.new()
	bar_top.color = Color.BLACK
	bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar_top)
	bar_bot = ColorRect.new()
	bar_bot.color = Color.BLACK
	bar_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar_bot)
	cine_banner = _deco_panel(14)
	cine_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cine_label = _lbl("TODOS LOS ENCARGOS COMPLETADOS", 20, C_GOLD)
	cine_banner.add_child(cine_label)
	cine_banner.modulate.a = 0.0
	root.add_child(cine_banner)

# ---------------------------------------------------------------- paneles

func _build_notes() -> void:
	notes_panel = Control.new()
	notes_panel.visible = false
	notes_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notes_panel)
	notebook = Notebook.new()
	notebook.custom_minimum_size = Vector2(560, 620)
	notebook.size = Vector2(560, 620)
	notebook.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notes_panel.add_child(notebook)
	notes_panel.size = notebook.size

func _build_map() -> void:
	map_panel = _deco_panel(16)
	map_panel.visible = false
	root.add_child(map_panel)
	var v := VBoxContainer.new()
	map_panel.add_child(v)
	var top := HBoxContainer.new()
	map_title = _lbl("", 22, C_GOLD)
	map_title.uppercase = true
	map_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(map_title)
	top.add_child(_lbl("M o Esc para cerrar", 12, C_MUT))
	v.add_child(top)
	var fb := HBoxContainer.new()
	for i in 7:
		var fi := i
		fb.add_child(_btn(FL_SHORT[i], func(): map_floor = fi, 13))
	v.add_child(fb)
	map_big = Minimap.new()
	map_big.labels = true
	map_big.custom_minimum_size = Vector2(820, 560)
	v.add_child(map_big)
	v.add_child(_lbl("Dorado: encargos · azul: compañeros · rojo: cadáveres o chivatazos · cuadros: objetos", 12, C_MUT))

func _build_inv() -> void:
	inv_panel = _deco_panel(18)
	inv_panel.visible = false
	root.add_child(inv_panel)
	var v := VBoxContainer.new()
	inv_panel.add_child(v)
	var top := HBoxContainer.new()
	var t := _lbl("INVENTARIO", 22, C_GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(_lbl("I o Esc para cerrar", 12, C_MUT))
	v.add_child(top)
	inv_text = RichTextLabel.new()
	inv_text.bbcode_enabled = true
	inv_text.custom_minimum_size = Vector2(520, 380)
	inv_text.add_theme_font_size_override("normal_font_size", 15)
	inv_text.add_theme_color_override("default_color", C_TEXT)
	v.add_child(inv_text)

func _build_elev() -> void:
	elev_panel = _deco_panel(16)
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

func _build_shop() -> void:
	shop_panel = _deco_panel(18)
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

func _build_pick() -> void:
	pick = PickGame.new()
	pick.size = Vector2(440, 150)
	pick.visible = false
	pick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pick.finished.connect(func(ok: bool): _pick_done(ok))
	root.add_child(pick)

func _pick_done(ok: bool) -> void:
	pick.visible = false
	minigame_done.emit(ok)

func _build_pause() -> void:
	pause_panel = _deco_panel(24)
	pause_panel.visible = false
	root.add_child(pause_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pause_panel.add_child(v)
	v.add_child(_lbl("PAUSA", 28, C_GOLD))
	v.add_child(_lbl(CONTROLS, 12, C_MUT))
	v.add_child(_btn("Continuar", func(): resume_requested.emit()))
	v.add_child(_btn("Ajustes", func(): open_settings()))
	v.add_child(_btn("Menú principal", func(): menu_requested.emit()))

func _build_end() -> void:
	end_panel = _deco_panel(28)
	end_panel.visible = false
	root.add_child(end_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	end_panel.add_child(v)
	end_title = _lbl("", 36, C_GOLD)
	v.add_child(end_title)
	end_reason = _lbl("", 16)
	end_reason.autowrap_mode = TextServer.AUTOWRAP_WORD
	end_reason.custom_minimum_size = Vector2(480, 0)
	v.add_child(end_reason)
	end_stats = _lbl("", 13, C_MUT)
	end_stats.autowrap_mode = TextServer.AUTOWRAP_WORD
	end_stats.custom_minimum_size = Vector2(480, 0)
	v.add_child(end_stats)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(_btn("Otra partida", func(): start_requested.emit(opt.duplicate())))
	h.add_child(_btn("Menú principal", func(): menu_requested.emit()))
	v.add_child(h)

# ---------------------------------------------------------------- menú principal

func _build_title() -> void:
	title_panel = Control.new()
	title_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_panel)
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.03, 0.05, 0.94))
	g.set_color(1, Color(0.02, 0.03, 0.05, 0.25))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0.5)
	gt.fill_to = Vector2(1, 0.5)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_panel.add_child(shade)
	var left := VBoxContainer.new()
	left.position = Vector2(70, 70)
	left.add_theme_constant_override("separation", 6)
	title_panel.add_child(left)
	var t0 := _lbl("HOTEL NEW YORKER · 1930", 14, C_MUT)
	left.add_child(t0)
	var t1 := _lbl("CAZA EN EL", 30, C_GOLD)
	left.add_child(t1)
	var t2 := _lbl("NEW YORKER", 64, C_GOLD)
	t2.add_theme_constant_override("outline_size", 8)
	left.add_child(t2)
	var line := ColorRect.new()
	line.color = C_GOLD
	line.custom_minimum_size = Vector2(380, 2)
	left.add_child(line)
	left.add_child(_lbl("", 10))
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 2)
	left.add_child(menu_box)
	menu_box.add_child(_menu_btn("Partida rápida", func(): start_requested.emit(opt.duplicate())))
	menu_box.add_child(_menu_btn("Nueva partida", func(): _open_title_panel(lobby_panel)))
	menu_box.add_child(_menu_btn("Cómo se juega", func(): _open_info("CÓMO SE JUEGA", HOW + "\n\n[color=#a9b2b8]" + CONTROLS + "[/color]")))
	menu_box.add_child(_menu_btn("Ajustes", func(): open_settings()))
	menu_box.add_child(_menu_btn("Créditos", func(): _open_info("CRÉDITOS", "Prototipo v0.6 hecho con Godot 4.\nIdea y diseño: Luca Matonte Antúnez.\nProgramación con ayuda de Claude.\nGráficos y sonido generados por código.\n\nPuedes poner tus propias texturas en [b]assets/tiles/[/b] y música en [b]assets/music/menu.ogg[/b].")))
	menu_box.add_child(_menu_btn("Salir", func(): quit_requested.emit()))
	var ver := _lbl("Prototipo v0.6 · partida contra bots", 11, Color(0.5, 0.55, 0.6))
	ver.position = Vector2(70, 0)
	ver.name = "Version"
	title_panel.add_child(ver)
	_build_lobby()
	info_panel = _deco_panel(22)
	info_panel.visible = false
	title_panel.add_child(info_panel)
	var iv := VBoxContainer.new()
	info_panel.add_child(iv)
	info_text = RichTextLabel.new()
	info_text.bbcode_enabled = true
	info_text.custom_minimum_size = Vector2(620, 440)
	info_text.add_theme_font_size_override("normal_font_size", 14)
	info_text.add_theme_font_size_override("bold_font_size", 15)
	info_text.add_theme_color_override("default_color", C_TEXT)
	iv.add_child(info_text)
	iv.add_child(_btn("Volver", func(): info_panel.visible = false))

func _open_title_panel(p: Control) -> void:
	lobby_panel.visible = false
	info_panel.visible = false
	p.visible = true
	_layout()

func _open_info(title: String, body: String) -> void:
	info_text.text = "[font_size=22][color=#ebd08a]" + title + "[/color][/font_size]\n\n" + body
	_open_title_panel(info_panel)

func _build_lobby() -> void:
	lobby_panel = _deco_panel(22)
	lobby_panel.visible = false
	title_panel.add_child(lobby_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	lobby_panel.add_child(v)
	v.add_child(_lbl("NUEVA PARTIDA", 24, C_GOLD))
	var roles := HBoxContainer.new()
	roles.add_theme_constant_override("separation", 8)
	v.add_child(roles)
	for r in [["runner", "Corredor"], ["hunter", "Cazador"], ["spectator", "Espectador"]]:
		var key: String = r[0]
		var b := _btn(r[1], func(): _pick_role(key), 17)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(160, 44)
		roles.add_child(b)
		role_buttons[key] = b
	var role_txt := _lbl("", 13, C_TEXT)
	role_txt.name = "RoleText"
	role_txt.autowrap_mode = TextServer.AUTOWRAP_WORD
	role_txt.custom_minimum_size = Vector2(520, 64)
	v.add_child(role_txt)
	var o := GridContainer.new()
	o.columns = 2
	o.add_theme_constant_override("h_separation", 14)
	o.add_theme_constant_override("v_separation", 8)
	v.add_child(o)
	o.add_child(_lbl("Duración", 14, C_MUT))
	var mins := OptionButton.new()
	mins.focus_mode = Control.FOCUS_NONE
	for m in [8, 12, 16]:
		mins.add_item(str(m) + " min", m)
	mins.select(1)
	mins.item_selected.connect(func(i): opt["minutes"] = mins.get_item_id(i))
	o.add_child(mins)
	o.add_child(_lbl("Cazadores", 14, C_MUT))
	var hn := OptionButton.new()
	hn.focus_mode = Control.FOCUS_NONE
	hn.add_item("1", 1)
	hn.add_item("2", 2)
	hn.select(1)
	hn.item_selected.connect(func(i): opt["hunters"] = hn.get_item_id(i))
	o.add_child(hn)
	o.add_child(_lbl("Corredores", 14, C_MUT))
	var rn := OptionButton.new()
	rn.focus_mode = Control.FOCUS_NONE
	for n in [2, 3, 4]:
		rn.add_item(str(n), n)
	rn.select(2)
	rn.item_selected.connect(func(i): opt["runners"] = rn.get_item_id(i))
	o.add_child(rn)
	perk_row = HBoxContainer.new()
	perk_row.add_theme_constant_override("separation", 10)
	perk_row.add_child(_lbl("Ventaja del cazador", 14, C_MUT))
	var pk := OptionButton.new()
	pk.focus_mode = Control.FOCUS_NONE
	var perk_ids: Array = Sim.PERKS
	for i in perk_ids.size():
		pk.add_item(str(Sim.PERK_NAMES[perk_ids[i]]), i)
	pk.select(0)
	pk.item_selected.connect(func(i): opt["perk"] = perk_ids[i])
	perk_row.add_child(pk)
	v.add_child(perk_row)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var go := _btn("Empezar partida", func(): start_requested.emit(opt.duplicate()), 18)
	go.custom_minimum_size = Vector2(240, 48)
	h.add_child(go)
	h.add_child(_btn("Volver", func(): lobby_panel.visible = false, 16))
	v.add_child(h)
	_pick_role("runner")

func _pick_role(key: String) -> void:
	opt["role"] = key
	for k in role_buttons:
		role_buttons[k].button_pressed = k == key
	if perk_row != null:
		perk_row.visible = key == "hunter"
	var txt := {
		"runner": "Mafia contratada. Tienes 8-10 encargos en tu bloc de notas. Las habitaciones ajenas están cerradas y si te ven forzarlas te denuncian. El primero en acabar recibe una pistola y el chivatazo de un cazador.",
		"hunter": "Policía secreta infiltrada. Elimina a los dos corredores de tu cartel sin testigos. Tienes " + str(Cfg.AMMO) + " balas y un cuchillo; el vigilante de la entrada te vende material.",
		"spectator": "Mira una partida completa entre bots, sin niebla. Espacio cambia el personaje al que sigues.",
	}
	var rt := lobby_panel.find_child("RoleText", true, false) as Label
	if rt != null:
		rt.text = txt[key]

# ---------------------------------------------------------------- ajustes

func _build_settings() -> void:
	settings_panel = _deco_panel(20)
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
	_slider(grid, "Música", 0.0, 1.0, Settings.music, func(x): Settings.music = x)
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

# ---------------------------------------------------------------- cambios de pantalla

func any_panel() -> bool:
	return notes_panel.visible or map_panel.visible or inv_panel.visible or elev_panel.visible or shop_panel.visible or pick.visible or settings_panel.visible or pause_panel.visible

func close_panels() -> void:
	notes_panel.visible = false
	map_panel.visible = false
	inv_panel.visible = false
	elev_panel.visible = false
	shop_panel.visible = false

func show_title() -> void:
	close_panels()
	pick.visible = false
	pick.active = false
	settings_panel.visible = false
	pause_panel.visible = false
	end_panel.visible = false
	play_root.visible = false
	title_panel.visible = true
	lobby_panel.visible = false
	info_panel.visible = false
	status_lbl.text = ""
	vignette.modulate.a = 0.0
	_set_bars(0.0)
	_layout()

func show_play(w: World) -> void:
	title_panel.visible = false
	play_root.visible = true
	end_panel.visible = false
	pause_panel.visible = false
	close_panels()
	last_log = 0
	last_floor = -1
	log_list.clear()
	for c in toasts.get_children():
		c.queue_free()
	minimap.w = w
	map_big.w = w
	map_floor = -1
	_layout()

func set_pause(on: bool) -> void:
	pause_panel.visible = on
	if on:
		_center(pause_panel)

func toggle(p: Control, on: bool) -> void:
	close_panels()
	p.visible = on
	map_floor = -1
	if on:
		_center(p)

func open_elev(cur_fl: int, has_cutter: bool = false) -> void:
	cut_btn.visible = has_cutter
	for eb in elev_buttons:
		eb[1].disabled = eb[0] == cur_fl
	toggle(elev_panel, true)

func close_elev() -> void:
	elev_panel.visible = false

func open_minigame() -> void:
	close_panels()
	pick.start()
	_center(pick)

func show_end(w: World) -> void:
	var win: String = w.over.get("winner", "")
	var me_side := "runners" if w.role == "runner" else ("hunters" if w.role == "hunter" else "")
	if me_side == "":
		end_title.text = "FIN DE LA PARTIDA · ganan los " + ("corredores" if win == "runners" else "cazadores")
	else:
		end_title.text = "VICTORIA" if win == me_side else "DERROTA"
	end_reason.text = w.over.get("reason", "")
	var s := w.stats
	end_stats.text = "Tiempo jugado " + _fmt(w.time) + " · encargos " + str(w.tasks_done) + "/" + str(w.quota) + " · bajas " + str(s["kills"]) + " · policías caídos " + str(w.cop_kills) + " · llamadas " + str(s["calls"]) + " · denuncias " + str(s["reports"]) + " · detenciones " + str(s["arrests"]) + " · cerraduras forzadas " + str(s["forced"])
	close_panels()
	end_panel.visible = true
	_center(end_panel)

func set_fade(a: float) -> void:
	fade.color = Color(0, 0, 0, a)

func set_status(t: String) -> void:
	status_lbl.text = t

func _layout() -> void:
	if root == null:
		return
	var vs := get_viewport().get_visible_rect().size
	clock.position = Vector2(vs.x - clock.size.x - 12, 8)
	badges.reset_size()
	badges.position = Vector2(vs.x - maxf(badges.size.x, 210) - 14, 164)
	quick.position = Vector2(14, vs.y - quick.size.y - 10)
	floor_banner.reset_size()
	floor_banner.position = Vector2((vs.x - floor_banner.size.x) / 2.0, vs.y * 0.22)
	big_label.reset_size()
	big_label.position = Vector2((vs.x - big_label.size.x) / 2.0, vs.y * 0.3)
	big_sub.reset_size()
	big_sub.position = Vector2((vs.x - big_sub.size.x) / 2.0, vs.y * 0.3 + 86)
	cine_banner.reset_size()
	cine_banner.position = Vector2(vs.x - cine_banner.size.x - 24, vs.y - cine_banner.size.y - 24)
	bar_top.size = Vector2(vs.x, bar_top.size.y)
	bar_bot.size = Vector2(vs.x, bar_bot.size.y)
	bar_bot.position = Vector2(0, vs.y - bar_bot.size.y)
	var ver := title_panel.find_child("Version", true, false) as Label
	if ver != null:
		ver.position = Vector2(70, vs.y - 34)
	for p in [lobby_panel, info_panel]:
		if p.visible:
			p.reset_size()
			p.position = Vector2(maxf(480.0, (vs.x - p.size.x) / 2.0 + 160), (vs.y - p.size.y) / 2.0)
	for p in [notes_panel, map_panel, inv_panel, elev_panel, pause_panel, end_panel, shop_panel, settings_panel, pick]:
		if p.visible:
			_center(p)

func _set_bars(k: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	var h := vs.y * 0.11 * k
	bar_top.position = Vector2.ZERO
	bar_top.size = Vector2(vs.x, h)
	bar_bot.size = Vector2(vs.x, h)
	bar_bot.position = Vector2(0, vs.y - h)

# ---------------------------------------------------------------- avisos

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
		var sb := _sb(Color(0.03, 0.05, 0.07, 0.86), _toast_color(l.kind), 0, 7)
		sb.border_width_left = 3
		p.add_theme_stylebox_override("panel", sb)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lb := _lbl(l.msg, 13)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD
		lb.custom_minimum_size = Vector2(440, 0)
		p.add_child(lb)
		p.set_meta("born", Time.get_ticks_msec())
		toasts.add_child(p)
	while toasts.get_child_count() > 3:
		var c := toasts.get_child(0)
		toasts.remove_child(c)
		c.queue_free()
	var now := Time.get_ticks_msec()
	for n in toasts.get_children():
		var c := n as Control
		var age: int = now - int(c.get_meta("born", now))
		c.modulate.a = clampf(1.0 - (age - 6500) / 700.0, 0.0, 1.0)
		if age > 7200:
			toasts.remove_child(c)
			c.queue_free()
	toasts.reset_size()
	var vs := get_viewport().get_visible_rect().size
	toasts.position = Vector2((vs.x - toasts.size.x) / 2.0, 14)
	return kinds

# ---------------------------------------------------------------- contenido

func task_state(w: World, hm: Ent, t: Task) -> Array:
	if t.done:
		return ["done", "Hecho"]
	if t.kind == "drop" and hm.carry != t.id:
		return ["lock", "Primero recoge el encargo"]
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
		"cut":
			return "Cortando los cables del ascensor…"
		"job":
			return "Haciendo el trabajo…"
		"escape":
			return "Escapando…"
		"unlock":
			return "Forzando las esposas…"
		"task":
			return h.ref.nm + "…"
	return "…"

func _notes(w: World, view: Ent) -> void:
	var hm := w.human
	var lines: Array = []
	if w.role == "runner" and hm != null:
		var mu := Sim.task_units(hm)
		notebook.title = "Encargos de " + hm.nm + "  " + str(mu.x) + "/" + str(mu.y)
		var ts: Array = hm.tasks.duplicate()
		ts.sort_custom(func(a, b): return a.fl < b.fl)
		for t in ts:
			var st := task_state(w, hm, t)
			lines.append({"text": FL_SHORT[t.fl] + " — " + t.nm, "done": t.done, "note": st[1] if st[0] != "done" else "", "hl": t.fl == view.fl and not t.done})
		if hm.job != null:
			lines.append({"text": "Trabajo extra: " + hm.job.nm, "done": false, "note": "", "hl": true})
		lines.append({"text": "Equipo: " + str(w.tasks_done) + "/" + str(w.quota) + " · tu habitación: " + Hotel.room_by(hm.room_floor, hm.room).label(), "done": false, "note": "", "hl": false})
		if Reward.all_done(hm):
			lines.append({"text": "Todo hecho: ayuda a tus compañeros con sus encargos.", "done": false, "note": "", "hl": true})
	elif w.role == "hunter" and hm != null:
		notebook.title = "Cuaderno de " + hm.nm
		for i in w.targets.size():
			var t := w.ent_by_id(w.targets[i])
			var alive: bool = t != null and t.alive
			lines.append({"text": "Objetivo " + str(i + 1) + ": " + (t.outfit.describe() if t != null else "?"), "done": not alive, "note": "", "hl": alive and t.fl == view.fl})
		lines.append({"text": "Mi aspecto: " + hm.outfit.describe() + (" (manchado)" if hm.outfit.blood else ""), "done": false, "note": "", "hl": false})
		if hm.job != null:
			lines.append({"text": "Trabajillo: " + hm.job.nm, "done": false, "note": "", "hl": true})
		lines.append({"text": "Sospecha " + str(roundi(hm.sus)) + " · balas " + str(hm.ammo) + "/" + str(hm.ammo_max) + " · $" + str(hm.money), "done": false, "note": "", "hl": false})
	else:
		notebook.title = "La partida"
		for e in w.ents:
			if e.role == "runner":
				var mu2 := Sim.task_units(e)
				lines.append({"text": e.nm + " · " + str(mu2.x) + "/" + str(mu2.y) + (" · objetivo" if e.id in w.targets else ""), "done": not e.alive or e.escaped, "note": "", "hl": false})
		for e in w.ents:
			if e.role == "hunter":
				lines.append({"text": e.nm + " · sospecha " + str(roundi(e.sus)), "done": not e.alive, "note": "", "hl": false})
	notebook.lines = lines
	notebook.queue_redraw()

func _inventory(w: World) -> void:
	var hm := w.human
	if hm == null:
		inv_text.text = "Estás mirando la partida."
		return
	var s := "[color=#ebd08a][b]DINERO[/b][/color]\n$" + str(hm.money) + "\n\n[color=#ebd08a][b]ARMAS[/b][/color]\n"
	var arms: Array = []
	if hm.gun:
		arms.append("Pistola (" + str(hm.ammo) + "/" + str(hm.ammo_max) + " balas)")
	if hm.knife:
		arms.append("Cuchillo")
	if hm.melee:
		arms.append("Llave inglesa")
	if hm.role == "runner" and not hm.melee:
		arms.append("Piezas para la llave inglesa " + str(mini(hm.scrap, Cfg.SCRAP_NEEDED)) + "/" + str(Cfg.SCRAP_NEEDED))
	s += ("\n".join(PackedStringArray(arms)) if not arms.is_empty() else "Nada") + "\n\n[color=#ebd08a][b]OBJETOS[/b][/color]\n"
	var gad: Array = []
	if hm.masterkey:
		gad.append("Llave maestra")
	if hm.badge:
		gad.append("Insignia de botones")
	if hm.lockpick:
		gad.append("Ganzúa")
	if hm.cutter:
		gad.append("Cizalla")
	if hm.cuffkey:
		gad.append("Llave de esposas")
	if hm.rope:
		gad.append("Cuerda")
	if hm.dockkey:
		gad.append("Llave del muelle")
	if hm.carry != "":
		gad.append("Un encargo en la mano")
	if hm.role == "runner" and hm.melee and hm.scrap > 0:
		gad.append("Chatarra x" + str(hm.scrap))
	s += ("\n".join(PackedStringArray(gad)) if not gad.is_empty() else "Nada") + "\n\n[color=#ebd08a][b]ESTADO[/b][/color]\n"
	if hm.role == "hunter":
		s += "Ventaja: " + str(Sim.PERK_NAMES.get(hm.perk, "—")) + "\n"
	if hm.undercover:
		s += "Llevas placa de policía.\n"
	s += "Denuncias " + str(hm.reports) + "/" + str(Cfg.STRIKES) + (" · fichado" if hm.marked else "") + (" · esposado" if hm.cuffed else "")
	if inv_text.text != s:
		inv_text.text = s

func update_hud(w: World, view: Ent, delta: float) -> void:
	if w == null or view == null:
		return
	var hm := w.human
	var role := w.role
	var vs := get_viewport().get_visible_rect().size
	# minimapa y nombre de planta
	var fl := view.fl if view.fl >= 0 else 1
	var f: FloorData = Hotel.floors[fl]
	mini_title.text = f.label + " · " + f.sub
	minimap.fl = fl
	minimap.view_ent = view
	minimap.role = role
	if fl != last_floor:
		last_floor = fl
		floor_banner.text = f.label + " · " + f.sub
		floor_banner_t = 2.2
		floor_banner.reset_size()
		floor_banner.position = Vector2((vs.x - floor_banner.size.x) / 2.0, vs.y * 0.22)
	floor_banner_t = maxf(0.0, floor_banner_t - delta)
	floor_banner.modulate.a = clampf(floor_banner_t / 0.6, 0.0, 1.0)
	# reloj
	clock.left = w.limit - w.time
	clock.total = maxf(w.limit, 1.0)
	clock.label = "EL CLIENTE LLEGA" if role == "runner" else ("TIEMPO" if role == "spectator" else "EL CLIENTE")
	clock.queue_redraw()
	# avisos
	if w.alarm >= 3:
		_set_badge("alarm", "BLUEGEDDON")
	elif w.alarm == 2:
		_set_badge("alarm", "Alarma 2 · " + str(Alarm.SIDE_NAME.get(w.alarm_side, "")))
	elif w.alarm == 1:
		_set_badge("alarm", "Alarma 1 · cacheos")
	else:
		_set_badge("alarm", "")
	if hm != null and role != "spectator":
		if not hm.alive:
			_set_badge("rep", "Fuera de juego")
		elif hm.escaped:
			_set_badge("rep", "Has escapado")
		elif hm.cuffed:
			_set_badge("rep", ("Grilletes" if hm.shackled else "Esposado") + " · " + _fmt(hm.cuff_t))
		elif hm.arrest > 0:
			_set_badge("rep", "Detenido " + str(ceili(hm.arrest)) + " s")
		elif hm.marked:
			_set_badge("rep", "Fichado")
		elif hm.reports > 0:
			_set_badge("rep", "Denuncias " + str(hm.reports) + "/" + str(Cfg.STRIKES))
		else:
			_set_badge("rep", "")
		if hm.intel_until > w.time:
			if role == "runner":
				_set_badge("intel", "Cazadores en " + Sim.floor_list(w, "hunter") + " · " + _fmt(hm.intel_until - w.time))
			else:
				_set_badge("intel", "Objetivos en " + Sim.floor_list(w, w.targets) + " · " + _fmt(hm.intel_until - w.time))
		else:
			_set_badge("intel", "")
		_set_badge("follow", "")
	else:
		_set_badge("rep", "")
		_set_badge("intel", "")
		_set_badge("follow", "Sigues a " + view.nm + " · Espacio")
	var sb: Array = []
	if w.sab_blackout > w.time:
		sb.append("Apagón " + _fmt(w.sab_blackout - w.time))
	if w.sab_alarm > w.time:
		sb.append("Alarma de incendios " + _fmt(w.sab_alarm - w.time))
	if w.sab_elev > w.time:
		sb.append("Ascensores " + _fmt(w.sab_elev - w.time))
	_set_badge("sab", " · ".join(PackedStringArray(sb)))
	var alarm_b: Array = badge_labels["alarm"]
	alarm_b[1].add_theme_color_override("font_color", C_BLUE if w.alarm >= 3 else (C_RED if w.alarm == 2 else C_WARN))
	# sospecha
	if hm != null and hm.alive and not hm.escaped and (role == "hunter" or (role == "runner" and hm.sus > 2)):
		sus_box.visible = true
		sus_lbl.text = ("SOSPECHA " if role == "hunter" else "TE VIGILAN ") + str(roundi(hm.sus))
		sus_bar.value = hm.sus
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
	badges.reset_size()
	badges.position = Vector2(vs.x - maxf(badges.size.x, 210) - 14, 164)
	# inventario rápido
	quick.visible = hm != null and hm.alive and not hm.escaped and role != "spectator"
	if quick.visible:
		quick.items = Sim.equip_list(hm)
		quick.current = hm.equip
		quick.ammo = hm.ammo if hm.gun else -1
		quick.money = hm.money
		quick.queue_redraw()
	# acción
	var ht := ""
	var hv := -1.0
	if hm != null and hm.alive and view == hm and w.cine.is_empty():
		if hm.hold != null:
			ht = hold_label(hm.hold)
			hv = hm.hold.t / hm.hold.dur
		elif not w.hint.is_empty():
			var hint: Dictionary = w.hint
			var press: bool = hint["type"] in Sim.PRESS_TYPES
			ht = ("[E / clic] " if press else "[mantén E] ") + str(hint["label"])
			if not press:
				ht += "  (" + str(snappedf(hint["dur"], 0.1)) + " s)"
	hint_box.visible = ht != ""
	hint_lbl.text = ht
	hint_bar.visible = hv >= 0
	hint_bar.value = maxf(hv, 0.0)
	if hint_box.visible:
		hint_box.reset_size()
		hint_box.position = Vector2((vs.x - hint_box.size.x) / 2.0, vs.y - 74)
	if status_lbl.text != "":
		status_lbl.reset_size()
		status_lbl.position = Vector2((vs.x - status_lbl.size.x) / 2.0, vs.y - 112)
	# viñeta
	var vgt := 0.0
	if hm != null and hm.alive and (role == "hunter" or role == "runner") and hm.sus > Cfg.WARN_AT:
		vgt = clampf((hm.sus - Cfg.WARN_AT) / (100.0 - Cfg.WARN_AT), 0.0, 1.0) * 0.75
	if hm != null and hm.alive and (hm.arrest > 0 or hm.cuffed):
		vgt = 0.6
	vignette.modulate.a = lerpf(vignette.modulate.a, vgt, 0.1)
	# cinemática: franjas negras y rótulo
	var cine_on := not w.cine.is_empty()
	var k := clampf(bar_top.size.y / maxf(vs.y * 0.11, 1.0) + (delta * 2.5 if cine_on else -delta * 2.5), 0.0, 1.0)
	_set_bars(k)
	cine_banner.modulate.a = lerpf(cine_banner.modulate.a, 1.0 if cine_on else 0.0, 0.08)
	if cine_on:
		cine_label.text = "TODOS LOS ENCARGOS COMPLETADOS"
		cine_banner.reset_size()
		cine_banner.position = Vector2(vs.x - cine_banner.size.x - 24, vs.y - cine_banner.size.y - vs.y * 0.11 * k - 16)
	# rótulo grande
	if not w.announce.is_empty():
		var a: Dictionary = w.announce
		if big_label.text != str(a["text"]):
			big_label.text = str(a["text"])
			big_sub.text = str(a.get("sub", ""))
			big_label.add_theme_color_override("font_color", Color(str(a["color"])))
			big_label.reset_size()
			big_sub.reset_size()
			big_label.position = Vector2((vs.x - big_label.size.x) / 2.0, vs.y * 0.3)
			big_sub.position = Vector2((vs.x - big_sub.size.x) / 2.0, vs.y * 0.3 + 86)
		a["t"] = float(a["t"]) - delta
		var al := clampf(float(a["t"]) / 0.8, 0.0, 1.0)
		big_label.modulate.a = al
		big_sub.modulate.a = al
		if float(a["t"]) <= 0:
			w.announce = {}
			big_label.text = ""
	else:
		big_label.modulate.a = 0.0
		big_sub.modulate.a = 0.0
	if notes_panel.visible:
		_notes(w, view)
	if map_panel.visible:
		var mf := fl if map_floor < 0 else map_floor
		map_big.fl = mf
		map_big.view_ent = view
		map_big.role = role
		map_title.text = Hotel.floors[mf].label + " · " + Hotel.floors[mf].sub
	if inv_panel.visible:
		_inventory(w)

func open_shop(w: World, e: Ent) -> void:
	shop_title.text = "EL CONTACTO DEL BAR" if e.role == "runner" else "EL VIGILANTE DE LA ENTRADA"
	toggle(shop_panel, true)
	refresh_shop(w, e)

func refresh_shop(w: World, e: Ent) -> void:
	shop_money.text = "Tienes $" + str(e.money)
	for c in shop_list.get_children():
		shop_list.remove_child(c)
		c.queue_free()
	for it in Sim.shop_items(w, e):
		var id: String = it["id"]
		var price: int = it["price"]
		var ptxt := ("$" + str(price)) if price > 0 else ("te pagan $" + str(-price) if price < 0 else "gratis")
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
