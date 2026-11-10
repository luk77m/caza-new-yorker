## Nodo raíz: controles, cámara, bucle de simulación y enlace con la interfaz.
extends Node2D

var w: World
var mode := "title"          # title, play, over
var paused := false
var tab_open := false
var elev_open := false
var elev_pend := -1
var elev_t := 0.0
var follow: Ent = null       # personaje que sigue la cámara (espectador o tras morir)
var zoom := 2.0
var view: WorldView
var cam: Camera2D
var hud: Hud

func _ready() -> void:
	_setup_input()
	Hotel.load_data()
	view = WorldView.new()
	add_child(view)
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	cam.zoom = Vector2(zoom, zoom)
	hud = Hud.new()
	add_child(hud)
	hud.start_requested.connect(_start)
	hud.elev_chosen.connect(_elev_choose)
	hud.resume_requested.connect(func(): _set_pause(false))
	hud.menu_requested.connect(_to_menu)
	hud.show_title()

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

func _read_input() -> Dictionary:
	var h := w.human
	if h == null or not h.alive:
		return {}
	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var blocked := tab_open or elev_open or elev_pend >= 0
	var m := view.get_global_mouse_position()
	if elev_pend >= 0:
		mv = Vector2.ZERO
	return {
		"mx": mv.x, "my": mv.y,
		"run": Input.is_action_pressed("run"),
		"aim": Input.is_action_pressed("aim") and not blocked,
		"aim_x": m.x, "aim_y": m.y,
		"fire": Input.is_action_pressed("fire") and not blocked,
		"interact": Input.is_action_pressed("use") and not blocked,
	}

func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("fullscreen"):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
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
		if elev_open:
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
		if h != null and h.alive and not w.hint.is_empty() and w.hint["type"] == "elev" and elev_pend < 0 and not elev_open:
			elev_open = true
			hud.open_elev(h.fl)
		return
	var kev := ev as InputEventKey
	if elev_open and kev != null and kev.pressed:
		var k: int = kev.physical_keycode
		if k >= KEY_1 and k <= KEY_7:
			_elev_choose(k - KEY_1)

# ---------------------------------------------------------------- partida

func _start(opt: Dictionary) -> void:
	w = Sim.new_world(opt)
	mode = "play"
	paused = false
	tab_open = false
	elev_open = false
	elev_pend = -1
	follow = null
	if w.human == null:
		_next_follow()
	view.w = w
	view.role = w.role
	hud.show_play(w)
	hud.set_fade(0)

func _to_menu() -> void:
	mode = "title"
	paused = false
	w = null
	view.w = null
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

func _elev_choose(fl: int) -> void:
	var h := w.human
	if not elev_open or h == null or fl == h.fl or fl < 0 or fl >= Hotel.floors.size():
		return
	_close_elev()
	elev_pend = fl
	elev_t = 0.55

func _next_follow() -> void:
	var list: Array = w.ents.filter(func(e): return e.alive and (e.role == "runner" or e.role == "hunter"))
	if list.is_empty():
		return
	var i := list.find(follow)
	follow = list[(i + 1) % list.size()]

func view_ent() -> Ent:
	if w == null:
		return null
	if w.human != null and w.human.alive and w.role != "spectator":
		return w.human
	if follow == null or not follow.alive:
		_next_follow()
	return follow if follow != null else w.human

func _physics_process(delta: float) -> void:
	if mode != "play" or paused or w == null:
		return
	if elev_pend >= 0:
		elev_t -= delta
		hud.set_fade(clampf(1.0 - elev_t / 0.55, 0.0, 1.0))
		if elev_t <= 0:
			var h := w.human
			if h != null and h.alive:
				Sim.cancel_hold(w, h)
				Sim.ride_elevator(w, h, elev_pend)
			elev_pend = -1
			hud.set_fade(0)
	if elev_open and (w.hint.is_empty() or w.hint["type"] != "elev"):
		_close_elev()
	Sim.step(w, delta, _read_input())
	if w.is_over():
		mode = "over"
		tab_open = false
		hud.show_end(w)

func _process(_delta: float) -> void:
	if w == null:
		return
	var ve := view_ent()
	if ve == null:
		return
	view.view_ent = ve
	cam.zoom = cam.zoom.lerp(Vector2(zoom, zoom), 0.25)
	var vs := get_viewport().get_visible_rect().size / cam.zoom
	var world := Vector2(Cfg.W * Cfg.TS, Cfg.H * Cfg.TS)
	var target := Vector2(ve.x, ve.y)
	# centrar la planta si cabe entera; si no, seguir al personaje sin salirse mucho
	target.x = world.x / 2.0 if vs.x >= world.x + 128 else clampf(target.x, vs.x / 2.0 - 64, world.x - vs.x / 2.0 + 64)
	target.y = world.y / 2.0 if vs.y >= world.y + 128 else clampf(target.y, vs.y / 2.0 - 64, world.y - vs.y / 2.0 + 64)
	cam.position = target
	view.cam_rect = Rect2(target - vs / 2.0, vs)
	hud.pump_logs(w)
	hud.update_hud(w, ve)
