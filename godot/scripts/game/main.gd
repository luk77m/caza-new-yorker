## Nodo raíz: controles, cámara, bucle de simulación, sonido y enlace con la interfaz.
extends Node2D

var w: World
var mode := "title"          # title, play, over
var paused := false
var elev_pend := -1
var elev_t := 0.0
var pick_target := 0         # compañero al que se le fuerzan las esposas
var follow: Ent = null       # personaje que sigue la cámara (espectador, tras caer o en el menú)
var zoom := 2.0
var shake := 0.0
var no_fire_until := 0       # tras un clic de interacción no se dispara
var step_t := {}
var view: WorldView
var cam: Camera2D
var hud: Hud
var sfx: Sfx
var music: Music

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
	music = Music.new()
	add_child(music)
	hud = Hud.new()
	add_child(hud)
	hud.start_requested.connect(_start)
	hud.elev_chosen.connect(_elev_choose)
	hud.elev_cut.connect(_elev_cut)
	hud.shop_buy.connect(_buy)
	hud.resume_requested.connect(func(): _set_pause(false))
	hud.menu_requested.connect(_to_menu)
	hud.settings_changed.connect(_settings_changed)
	hud.quit_requested.connect(func(): get_tree().quit())
	hud.minigame_done.connect(_minigame_done)
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
	_key("map", [KEY_M])
	_key("inv", [KEY_I])
	_key("equip", [KEY_Q])
	_key("pause", [KEY_ESCAPE, KEY_P])
	_key("next", [KEY_SPACE])
	_key("fullscreen", [KEY_F11])
	_mouse("aim", MOUSE_BUTTON_RIGHT)
	_mouse("fire", MOUSE_BUTTON_LEFT)

func _blocking() -> bool:
	return hud.elev_panel.visible or hud.shop_panel.visible or hud.pick.visible or hud.settings_panel.visible or elev_pend >= 0

func _read_input() -> Dictionary:
	var h := w.human
	if h == null or not h.alive or h.escaped:
		return {}
	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var blocked := _blocking() or hud.notes_panel.visible or hud.map_panel.visible or hud.inv_panel.visible
	var m := view.get_global_mouse_position()
	if _blocking():
		mv = Vector2.ZERO
	return {
		"mx": mv.x, "my": mv.y,
		"run": Input.is_action_pressed("run"),
		"aim": Input.is_action_pressed("aim") and not blocked,
		"aim_x": m.x, "aim_y": m.y,
		"fire": Input.is_action_pressed("fire") and not blocked and Time.get_ticks_msec() > no_fire_until,
		"interact": Input.is_action_pressed("use") and not _blocking(),
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
		elif hud.pick.visible:
			hud.pick.cancel()
		elif hud.any_panel() and not hud.pause_panel.visible:
			hud.close_panels()
		else:
			_set_pause(not paused)
		return
	if paused:
		return
	var h := w.human
	if hud.pick.visible:
		if ev.is_action_pressed("use"):
			hud.pick.hit()
			sfx.play("door", 0.4, 1.6)
		return
	if ev.is_action_pressed("tab"):
		hud.toggle(hud.notes_panel, not hud.notes_panel.visible)
		get_viewport().set_input_as_handled()
		return
	if ev.is_action_pressed("map"):
		hud.toggle(hud.map_panel, not hud.map_panel.visible)
		return
	if ev.is_action_pressed("inv"):
		hud.toggle(hud.inv_panel, not hud.inv_panel.visible)
		return
	if ev.is_action_pressed("next") and (w.role == "spectator" or h == null or not h.alive or h.escaped):
		_next_follow()
		return
	if h == null or not h.alive or h.escaped or not w.cine.is_empty():
		return
	if ev.is_action_pressed("equip"):
		Sim.cycle_equip(h)
		sfx.play("ui", 0.5)
		return
	if ev.is_action_pressed("use") and not ev.is_echo():
		if hud.shop_panel.visible:
			hud.close_shop()
			return
		if not w.hint.is_empty() and elev_pend < 0 and not hud.elev_panel.visible:
			_press(w.hint)
		return
	# clic sobre algo con lo que se puede interactuar
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not Input.is_action_pressed("aim") and not _blocking():
		var hint := Sim.find_interact(w, h, view.get_global_mouse_position())
		if not hint.is_empty():
			no_fire_until = Time.get_ticks_msec() + 300
			if hint["type"] in Sim.PRESS_TYPES:
				_press(hint)
			elif h.hold == null:
				Sim.start_hold(w, h, hint["type"], hint["ref"], hint["dur"])
				h.hold.auto = true
			get_viewport().set_input_as_handled()
			return
	var kev := ev as InputEventKey
	if hud.elev_panel.visible and kev != null and kev.pressed:
		var k: int = kev.physical_keycode
		if k >= KEY_1 and k <= KEY_7:
			_elev_choose(k - KEY_1)

## Acciones de pulsar: ascensor, tienda, hablar, sobornar, liberar...
func _press(hint: Dictionary) -> void:
	var h := w.human
	var ht: String = hint["type"]
	match ht:
		"elev":
			if w.time < h.elev_ready:
				hud.set_status("El ascensor acaba de salir. Espera " + str(ceili(h.elev_ready - w.time)) + " s.")
			else:
				hud.open_elev(h.fl, h.cutter)
				sfx.play("ui", 0.6)
		"elevx":
			hud.set_status("Ascensor fuera de servicio." + (" Con la cizalla puedes romperlo más." if h.cutter else ""))
			if h.cutter:
				hud.open_elev(h.fl, true)
		"shop":
			hud.open_shop(w, h)
			sfx.play("ui", 0.6)
		_:
			var r := Sim.press(w, h, hint)
			if r == "minigame":
				var t: Ent = hint["ref"]
				pick_target = t.id
				hud.open_minigame()

func _minigame_done(ok: bool) -> void:
	var t: Ent = w.ent_by_id(pick_target) if w != null else null
	if ok and t != null and t.cuffed:
		Alarm.free_prisoner(w, t, "ganzúa")
	elif not ok:
		hud.set_status("Lo dejas a medias.")

# ---------------------------------------------------------------- partida y menú

func _start(opt: Dictionary) -> void:
	w = Sim.new_world(opt)
	mode = "play"
	paused = false
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
	music.set_playing(false)

## En el menú principal se ve una partida entre bots de fondo y suena la música.
func _to_menu() -> void:
	mode = "title"
	paused = false
	elev_pend = -1
	w = Sim.new_world({"role": "spectator", "minutes": 30})
	view.w = w
	view.role = "spectator"
	follow = null
	_next_follow()
	zoom = 1.7
	hud.show_title()
	music.set_playing(true)

func _set_pause(on: bool) -> void:
	paused = on
	hud.set_pause(on)

func _buy(id: String) -> void:
	var h := w.human
	if h == null or not h.alive:
		return
	Sim.buy(w, h, id)
	hud.refresh_shop(w, h)

func _elev_choose(fl: int) -> void:
	var h := w.human
	if not hud.elev_panel.visible or h == null or fl == h.fl or fl < 0 or fl >= Hotel.floors.size():
		return
	if Sim.elev_out(w):
		hud.set_status("Ascensor fuera de servicio.")
		return
	hud.close_elev()
	elev_pend = fl
	elev_t = Cfg.ELEV_WAIT
	hud.set_status("El ascensor viene de camino…")
	sfx.play("elev", 0.7)

func _elev_cut() -> void:
	var h := w.human
	if h == null or not h.cutter:
		return
	hud.close_elev()
	Sim.start_hold(w, h, "cut", null, Cfg.HOLD_CUT)
	h.hold.auto = true

func _settings_changed() -> void:
	Settings.apply()
	zoom = Settings.zoom

func _next_follow() -> void:
	var list: Array = w.ents.filter(func(e): return e.alive and not e.escaped and (e.role == "runner" or e.role == "hunter"))
	if list.is_empty():
		return
	var i := list.find(follow)
	follow = list[(i + 1) % list.size()]

func view_ent() -> Ent:
	if w == null:
		return null
	if mode != "title" and w.human != null and w.human.alive and not w.human.escaped and w.role != "spectator":
		return w.human
	if follow == null or not follow.alive or follow.escaped:
		_next_follow()
	return follow if follow != null else w.human

# ---------------------------------------------------------------- bucle

func _physics_process(delta: float) -> void:
	if w == null or paused:
		return
	if mode == "title":
		Sim.step(w, delta, {})
		if w.is_over() or w.time > 600.0:
			w = Sim.new_world({"role": "spectator", "minutes": 30})
			view.w = w
			follow = null
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
	if hud.elev_panel.visible and (w.hint.is_empty() or (w.hint["type"] != "elev" and w.hint["type"] != "elevx")):
		hud.close_elev()
	if hud.shop_panel.visible and (w.hint.is_empty() or w.hint["type"] != "shop"):
		hud.close_shop()
	Sim.step(w, delta, _read_input())
	if w.is_over():
		mode = "over"
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
	hud.update_hud(w, ve, delta)

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
