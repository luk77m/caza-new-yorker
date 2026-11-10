## Nodo raíz: controles, cámara, bucle de simulación, sonido y enlace con la interfaz.
extends Node2D

var w: World
var mode := "title"          # title, play, over
var paused := false
var tab_open := false
var elev_open := false
var shop_open := false
var elev_pend := -1
var elev_t := 0.0
var follow: Ent = null       # personaje que sigue la cámara (espectador, tras morir o en el menú)
var zoom := 2.0
var shake := 0.0
var step_t := {}             # id -> s hasta el siguiente paso
var view: WorldView
var cam: Camera2D
var hud: Hud
var sfx: Sfx

func _ready() -> void:
	Settings.load_cfg()
	Settings.apply()
	zoom = Settings.zoom
	_setup_input()
	Hotel.load_data()
	view = WorldView.new()
	add_child(view)
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	cam.zoom = Vector2(zoom, zoom)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 9.0
	sfx = Sfx.new()
	add_child(sfx)
	hud = Hud.new()
	add_child(hud)
	hud.start_requested.connect(_start)
	hud.elev_chosen.connect(_elev_choose)
	hud.elev_cut.connect(_elev_cut)
	hud.shop_buy.connect(_buy)
	hud.resume_requested.connect(func(): _set_pause(false))
	hud.menu_requested.connect(_to_menu)
	hud.settings_changed.connect(_settings_changed)
	_to_menu()

# ---------------------------------------------------------------- controles

func _key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

func _mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)

func _setup_input() -> void:
	_key("move_up", [KEY_W, KEY_UP])
	_key("move_down", [KEY_S, KEY_DOWN])
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("run", [KEY_SHIFT])
	_key("use", [KEY_E])
	_key("tab", [KEY_TAB])
	_key("pause", [KEY_ESCAPE, KEY_P])
	_key("next", [KEY_SPACE])
	_key("fullscreen", [KEY_F11])
	_mouse("aim", MOUSE_BUTTON_RIGHT)
	_mouse("fire", MOUSE_BUTTON_LEFT)

func _menu_open() -> bool:
	return tab_open or elev_open or shop_open or elev_pend >= 0 or hud.settings_panel.visible

func _read_input() -> Dictionary:
	var h := w.human
	if h == null or not h.alive:
		return {}
	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var blocked := _menu_open()
	var m := view.get_global_mouse_position()
	if elev_pend >= 0 or shop_open:
		mv = Vector2.ZERO
	return {
		"mx": mv.x, "my": mv.y,
		"run": Input.is_action_pressed("run"),
		"aim": Input.is_action_pressed("aim") and not blocked,
		"aim_x": m.x, "aim_y": m.y,
		"fire": Input.is_action_pressed("fire") and not blocked,
		"interact": Input.is_action_pressed("use") and not (tab_open or elev_open or shop_open or elev_pend >= 0),
	}

func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("fullscreen"):
		Settings.fullscreen = not Settings.fullscreen
		Settings.apply()
		Settings.save_cfg()
		return
	if mode == "title":
		return
	var mb := ev as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = clampf(zoom * 1.1, 1.0, 3.5)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = clampf(zoom / 1.1, 1.0, 3.5)
	if mode != "play":
		return
	if ev.is_action_pressed("pause"):
		if hud.settings_panel.visible:
			hud.close_settings()
		elif shop_open:
			_close_shop()
		elif elev_open:
			_close_elev()
		elif tab_open:
			_toggle_tab(false)
		else:
			_set_pause(not paused)
		return
	if paused:
		return
	if ev.is_action_pressed("tab"):
		_toggle_tab(not tab_open)
		get_viewport().set_input_as_handled()
		return
	if ev.is_action_pressed("next") and (w.role == "spectator" or w.human == null or not w.human.alive):
		_next_follow()
		return
	if ev.is_action_pressed("use") and not ev.is_echo():
		var h := w.human
		if shop_open:
			_close_shop()
			return
		if h == null or not h.alive or w.hint.is_empty() or elev_pend >= 0 or elev_open:
			return
		var ht: String = w.hint["type"]
		if ht == "elev":
			if w.time < h.elev_ready:
				hud.set_status("El ascensor acaba de salir. Espera " + str(ceili(h.elev_ready - w.time)) + " s.")
			else:
				elev_open = true
				hud.open_elev(h.fl, h.cutter)
				sfx.play("ui", 0.6)
		elif ht == "elevx":
			hud.set_status("Ascensor fuera de servicio." + (" Puedes romperlo más con la cizalla." if h.cutter else ""))
		elif ht == "shop":
			shop_open = true
			hud.open_shop(w, h)
			sfx.play("ui", 0.6)
		return
	var kev := ev as InputEventKey
	if elev_open and kev != null and kev.pressed:
		var k: int = kev.physical_keycode
		if k >= KEY_1 and k <= KEY_7:
			_elev_choose(k - KEY_1)

# ---------------------------------------------------------------- partida y menú

func _start(opt: Dictionary) -> void:
	w = Sim.new_world(opt)
	mode = "play"
	paused = false
	tab_open = false
	elev_open = false
	shop_open = false
	elev_pend = -1
	follow = null
	step_t = {}
	if w.human == null:
		_next_follow()
	view.w = w
	view.role = w.role
	hud.show_play(w)
	hud.set_fade(0)
	hud.set_status("")
	zoom = Settings.zoom

## En el menú principal se ve una partida entre bots de fondo.
func _to_menu() -> void:
	mode = "title"
	paused = false
	tab_open = false
	elev_open = false
	shop_open = false
	elev_pend = -1
	w = Sim.new_world({"role": "spectator", "minutes": 30})
	view.w = w
	view.role = "spectator"
	follow = null
	_next_follow()
	zoom = 1.6
	hud.show_title()

func _set_pause(on: bool) -> void:
	paused = on
	hud.set_pause(on)

func _toggle_tab(on: bool) -> void:
	tab_open = on
	hud.toggle_tab(on)

func _close_elev() -> void:
	elev_open = false
	hud.close_elev()

func _close_shop() -> void:
	shop_open = false
	hud.close_shop()

func _buy(id: String) -> void:
	var h := w.human
	if h == null or not h.alive:
		return
	var msg := Sim.buy(w, h, id)
	if msg != "" and h.money >= 0:
		hud.set_status("")
	hud.refresh_shop(w, h)

func _elev_choose(fl: int) -> void:
	var h := w.human
	if not elev_open or h == null or fl == h.fl or fl < 0 or fl >= Hotel.floors.size():
		return
	_close_elev()
	elev_pend = fl
	elev_t = Cfg.ELEV_WAIT
	hud.set_status("El ascensor viene de camino…")
	sfx.play("elev", 0.7)

func _elev_cut() -> void:
	var h := w.human
	if h == null or not h.cutter:
		return
	_close_elev()
	Sim.start_hold(w, h, "cut", null, Cfg.HOLD_CUT)
	h.hold.auto = true

func _settings_changed() -> void:
	Settings.apply()
	zoom = Settings.zoom

func _next_follow() -> void:
	var list: Array = w.ents.filter(func(e): return e.alive and (e.role == "runner" or e.role == "hunter"))
	if list.is_empty():
		return
	var i := list.find(follow)
	follow = list[(i + 1) % list.size()]

func view_ent() -> Ent:
	if w == null:
		return null
	if mode != "title" and w.human != null and w.human.alive and w.role != "spectator":
		return w.human
	if follow == null or not follow.alive:
		_next_follow()
	return follow if follow != null else w.human

# ---------------------------------------------------------------- bucle

func _physics_process(delta: float) -> void:
	if w == null or paused:
		return
	if mode == "title":
		Sim.step(w, delta, {})
		if w.is_over() or w.time > 600.0:
			_to_menu()
		return
	if mode != "play":
		return
	if elev_pend >= 0:
		elev_t -= delta
		hud.set_fade(clampf(1.0 - elev_t / 0.5, 0.0, 1.0))
		if elev_t <= 0:
			var h := w.human
			if h != null and h.alive:
				Sim.cancel_hold(w, h)
				if Sim.ride_elevator(w, h, elev_pend):
					h.elev_ready = w.time + Cfg.ELEV_CD
					sfx.play("elev", 0.5, 1.2)
			elev_pend = -1
			hud.set_fade(0)
			hud.set_status("")
	if elev_open and (w.hint.is_empty() or w.hint["type"] != "elev"):
		_close_elev()
	if shop_open and (w.hint.is_empty() or w.hint["type"] != "shop"):
		_close_shop()
	Sim.step(w, delta, _read_input())
	if w.is_over():
		mode = "over"
		tab_open = false
		_close_shop()
		_close_elev()
		hud.show_end(w)

func _process(delta: float) -> void:
	if w == null:
		return
	var ve := view_ent()
	if ve == null:
		return
	view.view_ent = ve
	if mode == "title":
		view.role = "spectator"
	cam.zoom = cam.zoom.lerp(Vector2(zoom, zoom), 0.2)
	view.zoom = cam.zoom.x
	var vs := get_viewport().get_visible_rect().size / cam.zoom
	var world := Vector2(Cfg.W * Cfg.TS, Cfg.H * Cfg.TS)
	var target := Vector2(ve.x, ve.y)
	# centrar la planta si cabe entera; si no, seguir al personaje sin salirse mucho
	target.x = world.x / 2.0 if vs.x >= world.x + 128 else clampf(target.x, vs.x / 2.0 - 64, world.x - vs.x / 2.0 + 64)
	target.y = world.y / 2.0 if vs.y >= world.y + 128 else clampf(target.y, vs.y / 2.0 - 64, world.y - vs.y / 2.0 + 64)
	cam.position = target
	shake = maxf(0.0, shake - delta * 6.0)
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 6.0 if Settings.shake else Vector2.ZERO
	view.cam_rect = Rect2(cam.get_screen_center_position() - vs / 2.0, vs)
	_events(ve)
	if mode == "title":
		return
	_steps(ve, delta)
	for kind in hud.pump_logs(w):
		if kind == "call" or kind == "report" or kind == "hunt":
			sfx.play("call", 0.5)
	hud.update_hud(w, ve)

## Sonidos y sacudidas a partir de los eventos de la simulación.
func _events(ve: Ent) -> void:
	for e in w.events:
		var same: bool = e["fl"] == ve.fl
		var d := Vector2(e["x"] - ve.x, e["y"] - ve.y).length()
		var near := clampf(1.0 - d / (18.0 * Cfg.TS), 0.0, 1.0) if same else 0.0
		var t: String = e["type"]
		if mode == "title":
			continue
		match t:
			"shot":
				sfx.play("shot", 0.25 + near * 0.6)
				if same and d < 10 * Cfg.TS:
					shake = maxf(shake, 0.35)
			"shot_police":
				sfx.play("shot_police", 0.4 + near * 0.6)
				if same:
					shake = maxf(shake, 0.9)
			"swing", "stab":
				sfx.play(t, near)
			"task":
				if e.get("who", 0) == (w.human.id if w.human != null else -1):
					sfx.play("task", 0.8)
			"cash", "pick", "buy", "door", "empty":
				sfx.play(t, near * 0.8)
			"sparks":
				sfx.play("sparks", 0.3 + near * 0.6)
				if same:
					shake = maxf(shake, 0.5)
			"sab_alarm":
				sfx.play("alarm", 0.7)
			"sab_blackout":
				sfx.play("blackout", 0.8)
			"sab_elev":
				sfx.play("sparks", 0.4)
	w.events.clear()

## Pasos muy bajos: los tuyos y los de quien tengas cerca.
func _steps(ve: Ent, delta: float) -> void:
	if Settings.steps <= 0.01:
		return
	for e in w.ents:
		if not e.alive or not e.moving or e.fl != ve.fl:
			continue
		var d := Vector2(e.x - ve.x, e.y - ve.y).length()
		if e != ve and d > 6 * Cfg.TS:
			continue
		var t: float = step_t.get(e.id, 0.0) - delta
		if t <= 0:
			var running: bool = e == w.human and Input.is_action_pressed("run")
			t = 0.27 if running else 0.4
			var g := (0.5 if e == ve else 0.25 * (1.0 - d / (6.0 * Cfg.TS))) * Settings.steps
			sfx.play("step", g, randf_range(0.85, 1.15))
		step_t[e.id] = t
