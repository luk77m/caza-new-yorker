## Nodo raíz: controles, cámara, bucle de simulación, sonido y enlace con la interfaz.
extends Node2D

var w: World
var mode := "title"          # title, play, over
var paused := false
var elev_pend := -1
var elev_t := 0.0
var pick_target := 0         # compañero al que se le fuerzan las esposas
var pend_hint := {}          # acción que espera al minijuego
var tut: Tutorial = null
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
var fps: FpsView                # primera persona al apuntar
var overlays: Overlays          # central, interrogatorio, registro y presentación de la ronda
var practice := ""              # rol de la partida de práctica en curso
var last_fl := -99              # planta del jugador en el paso anterior (para la animación de escaleras)

func _ready() -> void:
	# nitidez: filtrado lineal (luces y degradados suaves) y antialias en 2D
	get_viewport().canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	get_viewport().msaa_2d = Viewport.MSAA_4X
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
	var fl := CanvasLayer.new()
	fl.layer = 5
	add_child(fl)
	fps = FpsView.new()
	fps.visible = false
	fl.add_child(fps)
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
	hud.tutorial_requested.connect(func(): _start_tutorial("runner"))
	hud.pick.pick_broken.connect(_pick_broken)
	overlays = Overlays.new()
	hud.root.add_child(overlays)
	hud.root.move_child(overlays, hud.fade.get_index())
	overlays.sound.connect(func(nm: String): sfx.play(nm, 0.7))
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
	_key("drag", [KEY_F])
	_key("loot", [KEY_R])
	_key("pause", [KEY_ESCAPE, KEY_P])
	_key("next", [KEY_SPACE])
	_key("fullscreen", [KEY_F11])
	_mouse("aim", MOUSE_BUTTON_RIGHT)
	_mouse("fire", MOUSE_BUTTON_LEFT)

func _blocking() -> bool:
	return hud.elev_panel.visible or hud.shop_panel.visible or hud.pick.visible or hud.settings_panel.visible or elev_pend >= 0 or overlays.modal()

func _read_input() -> Dictionary:
	var h := w.human
	if h == null or not h.alive or h.escaped:
		return {}
	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var blocked := _blocking() or hud.notes_panel.visible or hud.map_panel.visible or hud.inv_panel.visible
	var m := view.get_global_mouse_position()
	if _blocking():
		mv = Vector2.ZERO
	if fps.visible:
		# primera persona: WASD relativo a la mirada, punto de mira y asomarse
		var ap := fps.aim_point()
		var aiming: bool = Input.is_action_pressed("aim") and not blocked
		return {
			"mx": fps.move_vec(mv).x, "my": fps.move_vec(mv).y,
			"run": Input.is_action_pressed("run") and not aiming,
			"aim": aiming,
			"aim_x": ap.x, "aim_y": ap.y,
			"lean_x": fps.lean_off.x, "lean_y": fps.lean_off.y,
			"fire": Input.is_action_pressed("fire") and not blocked and Time.get_ticks_msec() > no_fire_until,
			# en primera persona permanente E interactúa mientras no apuntes (apuntando sirve para asomarse)
			"interact": Settings.fps_always and not aiming and Input.is_action_pressed("use") and not _blocking(),
		}
	return {
		"mx": mv.x, "my": mv.y,
		"run": Input.is_action_pressed("run"),
		"aim": Input.is_action_pressed("aim") and not blocked,
		"aim_x": m.x, "aim_y": m.y,
		"fire": Input.is_action_pressed("fire") and not blocked and Time.get_ticks_msec() > no_fire_until,
		"interact": Input.is_action_pressed("use") and not _blocking(),
	}

## Con el ratón capturado (primera persona) el movimiento gira la mirada.
func _input(ev: InputEvent) -> void:
	var mm := ev as InputEventMouseMotion
	if mm != null and fps != null and fps.visible and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		fps.look(mm.relative * Settings.sens)

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
		elif overlays.loot_key != "":
			overlays.close_loot()
			w.flags["loot_closed"] = true
		elif overlays.modal():
			pass
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
	var key := _key_name(ev)
	if overlays.modal():
		if ev.is_action_pressed("loot"):
			overlays.close_loot()
			w.flags["loot_closed"] = true
		elif key != "":
			overlays.key(key)
		get_viewport().set_input_as_handled()
		return
	var ek := ev as InputEventKey
	if tut != null and tut.done() and ek != null and ek.pressed and ek.physical_keycode == KEY_ENTER:
		if practice == "runner":
			_start_tutorial("hunter")
		else:
			_to_menu()
		return
	if hud.pick.visible:
		if key != "":
			hud.pick.press(key)
			sfx.play("ui", 0.4, 1.4)
		return
	if h != null and not Combat.qte_for(w, h.id).is_empty():
		if key != "" and key != "use":
			Combat.qte_input(w, key)
			sfx.play("ui", 0.5, 1.2)
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
	if ev.is_action_pressed("next") and (w.role == "spectator" or h == null or not h.alive or h.escaped or h.away_t > 0):
		_next_follow()
		return
	if h == null or not h.alive or h.escaped or not w.cine.is_empty():
		return
	if fps.visible and Input.is_action_pressed("aim") and (ev.is_action_pressed("equip") or ev.is_action_pressed("use")):
		return   # apuntando, Q/E sirven para asomarse
	if ev.is_action_pressed("loot") and not hud.any_panel():
		# R: registrar el mueble o el cadáver que tengas al lado
		var near := Loot.nearest(w, h)
		if not near.is_empty():
			Sim.cancel_hold(w, h)
			overlays.open_loot(near)
			w.flags["loot_open"] = true
			sfx.play("ui", 0.5, 0.9)
		return
	if ev.is_action_pressed("drag") and not h.hidden and not h.cuffed and h.ko_t <= 0:
		# F: arrastrar el cuerpo más cercano o soltarlo
		if h.dragging != null:
			Stealth.drop(w, h)
			sfx.play("ui", 0.4, 0.8)
		else:
			var dg = Stealth.find_draggable(w, h)
			if dg != null:
				Sim.cancel_hold(w, h)
				Stealth.press(w, h, {"type": "drag", "ref": dg})
				sfx.play("ui", 0.5, 0.7)
		return
	if ev.is_action_pressed("equip"):
		Sim.cycle_equip(h)
		w.flags["equip"] = true
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
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not Input.is_action_pressed("aim") and not _blocking() and not fps.visible:
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
			w.flags["shop"] = true
			hud.open_shop(w, h)
			sfx.play("ui", 0.6)
		_:
			var r := Sim.press(w, h, hint)
			if r == "ok" and ht == "talk":
				w.flags["talked"] = true
			if r == "minigame":
				pend_hint = hint
				if ht == "unlock":
					var t: Ent = hint["ref"]
					pick_target = t.id
					hud.open_minigame("timing", "Forzar las esposas de " + t.nm, Cfg.UNLOCK_PINS)
				else:
					var m := _mode_for(hint)
					hud.open_minigame(m[0], str(hint["label"]), m[1])

## Qué minijuego toca a cada acción (siempre el mismo para el mismo encargo).
func _mode_for(hint: Dictionary) -> Array:
	var ht: String = hint["type"]
	if ht == "force":
		if w.human.picks_n > 0:
			hud.pick.tough = 2.0 if w.human.rperk == "cerrajero" else 1.0
			return ["lockpick", w.human.picks_n]
		return ["timing", 4]     # sin ganzúa: a lo bruto
	if ht == "vent":
		return ["timing", 4]     # los cuatro tornillos de la rejilla
	if ht == "job":
		return ["balance", 0]
	var t: Task = hint["ref"]
	if t.sab != "":
		return ["wires", 0]
	if t.nm.contains("micrófono"):
		return ["mic", 0]        # colocarlo sin que te vean y conectarlo
	if t.kind == "drop" or t.nm.begins_with("Esconder") or t.nm.begins_with("Dejar"):
		return ["stash", 2]      # esconderlo debajo de un mueble
	var modes := ["sequence", "timing", "balance", "wires"]
	return [modes[absi(hash(t.id)) % modes.size()], 3]

func _key_name(ev: InputEvent) -> String:
	var k := ev as InputEventKey
	if k == null or not k.pressed or k.echo:
		return ""
	match k.physical_keycode:
		KEY_E, KEY_SPACE, KEY_ENTER:
			return "use"
		KEY_UP, KEY_W:
			return "up"
		KEY_DOWN, KEY_S:
			return "down"
		KEY_LEFT, KEY_A:
			return "left"
		KEY_RIGHT, KEY_D:
			return "right"
		KEY_1:
			return "1"
		KEY_2:
			return "2"
		KEY_3:
			return "3"
	return ""

func _minigame_done(ok: bool) -> void:
	if w == null:
		return
	var hint := pend_hint
	pend_hint = {}
	var h := w.human
	if hint.is_empty() or h == null:
		return
	if not ok:
		hud.set_status("Inténtalo otra vez.")
		return
	hud.set_status("")
	if hint["type"] == "unlock":
		var t: Ent = w.ent_by_id(pick_target)
		if t != null and t.cuffed:
			Alarm.free_prisoner(w, t, "ganzúa")
	else:
		Sim.complete_action(w, h, hint)

# ---------------------------------------------------------------- partida y menú

## Partida de práctica: primero de corredor y después de cazador.
func _start_tutorial(role: String) -> void:
	_start({"role": role, "hunters": 1, "runners": 2, "minutes": 60, "tutorial": true, "practice": role})
	practice = role
	tut = Tutorial.new()
	tut.begin(w, role)

## Se ha roto una ganzúa en el minijuego.
func _pick_broken() -> void:
	if w == null or w.human == null:
		return
	var h := w.human
	h.picks_n = maxi(0, h.picks_n - 1)
	h.lockpick = h.picks_n > 0
	if not (h.equip in Sim.equip_list(h)):
		h.equip = "fist"
	sfx.play("snap", 0.8)
	Sim.wlog(w, "Se te ha roto una ganzúa. Te quedan " + str(h.picks_n) + (". El vendedor de tu bando tiene más." if h.picks_n == 0 else "."), "report", h.id)

func _start(opt: Dictionary) -> void:
	tut = null
	practice = ""
	w = Sim.new_world(opt)
	overlays.begin(w, w.role != "spectator" and not w.tutorial)
	mode = "play"
	paused = false
	elev_pend = -1
	follow = null
	last_fl = -99
	step_t = {}
	if w.human == null:
		_next_follow()
	view.w = w
	view.role = w.role
	view.visible = true
	hud.show_play(w)
	hud.set_fade(0)
	hud.set_status("")
	zoom = Settings.zoom
	music.set_playing(false)

## En el menú principal se ve una partida entre bots de fondo y suena la música.
func _to_menu() -> void:
	if fps != null and fps.visible:
		_end_fps()
	mode = "title"
	paused = false
	elev_pend = -1
	tut = null
	practice = ""
	overlays.stop()
	w = Sim.new_world({"role": "spectator", "minutes": 30})
	view.w = w
	view.role = "spectator"
	follow = null
	_next_follow()
	zoom = 1.7
	view.visible = false
	hud.show_title()
	music.set_playing(true)

func _set_pause(on: bool) -> void:
	paused = on
	if on and fps.visible:
		_end_fps()
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
	overlays.start_travel("elev", h.fl, fl, h.outfit, Cfg.ELEV_WAIT + 0.4)
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
	var list: Array = w.ents.filter(func(e): return e.alive and not e.escaped and e.away_t <= 0 and e.fl >= 0 and e.type != "frozen" and (e.role == "runner" or e.role == "hunter"))
	# jugando (caído, detenido o expulsado) se sigue a los compañeros de tu bando
	var hm := w.human
	if hm != null and w.role != "spectator" and mode != "title":
		var mates: Array = list.filter(func(e): return e.role == hm.role and e != hm)
		if not mates.is_empty():
			list = mates
	if list.is_empty():
		return
	var i := list.find(follow)
	follow = list[(i + 1) % list.size()]

func view_ent() -> Ent:
	if w == null:
		return null
	if mode != "title" and w.human != null and w.human.alive and not w.human.escaped and w.human.away_t <= 0 and w.role != "spectator":
		return w.human
	if follow == null or not follow.alive or follow.escaped or follow.away_t > 0 or follow == w.human:
		_next_follow()
	return follow if follow != null else w.human

# ---------------------------------------------------------------- bucle

func _physics_process(delta: float) -> void:
	if w == null or paused:
		return
	if mode == "title":
		return
	if mode != "play":
		return
	if overlays.intro_t > 0.0:
		return     # presentación de los equipos: la partida aún no ha empezado
	if overlays.travel_t > 0.0 and overlays.travel_kind == "stairs":
		return     # subiendo o bajando la escalera
	if elev_pend >= 0:
		elev_t -= delta
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
	var hs := w.human
	if hs != null and hs.alive:
		# cambio de planta por la escalera: un par de segundos viendo al personaje subir o bajar
		if last_fl != -99 and absi(hs.fl - last_fl) == 1 and hs.stair_cd > 0.4 and hs.away_t <= 0 and hs.fl >= 0:
			overlays.start_travel("stairs", last_fl, hs.fl, hs.outfit, 1.5)
			sfx.play("step", 0.5, 0.8)
		last_fl = hs.fl
		if fps.visible and Settings.fps_always and not hs.moving and not hs.aim:
			hs.dir = Sim.dir_of(fps.fw.x, fps.fw.y)
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
	_update_fps(delta)
	_steps(ve, delta)
	for kind in hud.pump_logs(w):
		if kind == "call" or kind == "report" or kind == "hunt":
			sfx.play("call", 0.5)
	hud.update_hud(w, ve, delta)
	overlays.quiet = hud.any_panel() or paused or fps.visible or mode != "play"
	if tut != null:
		tut.update(w, hud)
		hud.set_tutorial(true, tut.step, tut.steps.size(), tut.text())
		view.tut_target = tut.target
	else:
		hud.set_tutorial(false, 0, 0, "")
		view.tut_target = Vector3(-1, 0, 0)

## Entra o sale de la primera persona. Vista mixta: solo al apuntar con la pistola.
## Primera persona permanente (ajustes): toda la partida, y el arma se levanta al apuntar.
func _update_fps(delta: float) -> void:
	var h := w.human
	var ok: bool = mode == "play" and not paused and h != null and h.alive and not h.escaped and h.away_t <= 0 \
		and w.cine.is_empty() and Combat.qte_for(w, h.id).is_empty() and overlays.intro_t <= 0.0 and overlays.travel_t <= 0.0
	var ui_open: bool = hud.any_panel() or overlays.modal()
	var aiming: bool = ok and h.aim and Input.is_action_pressed("aim") and not ui_open
	var want: bool = ok and (Settings.fps_always or (Settings.fps_aim and aiming))
	if want and not fps.visible:
		fps.begin(w, h)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		view.visible = false
		sfx.play("ui", 0.35, 0.7)
	elif not want and fps.visible:
		_end_fps()
	if fps.visible:
		fps.show_gun = aiming or not Settings.fps_always
		# con un panel abierto (mapa, tienda, registro...) el ratón queda libre
		var mm := Input.MOUSE_MODE_VISIBLE if ui_open else Input.MOUSE_MODE_CAPTURED
		if Input.mouse_mode != mm:
			Input.mouse_mode = mm
		var lean_in := 0.0
		if aiming:
			lean_in = (1.0 if Input.is_physical_key_pressed(KEY_E) else 0.0) - (1.0 if Input.is_physical_key_pressed(KEY_Q) else 0.0)
		fps.update_view(w, h, delta, lean_in, shake)
		h.cover = aiming and fps.cover and absf(fps.lean) < 0.3
	elif h != null:
		h.cover = false

## Vuelve a la vista cenital con el ratón donde miraba la cámara en primera persona.
func _end_fps() -> void:
	fps.stop()
	view.visible = mode != "title"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var h := w.human if w != null else null
	if h != null:
		var wp := Vector2(h.x, h.y) + fps.fw * 110.0
		Input.warp_mouse(get_viewport().get_canvas_transform() * wp)

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
			"punch":
				sfx.play("stab", near, 1.3)
				if same and d < 4 * Cfg.TS:
					shake = maxf(shake, 0.25)
			"cuff":
				sfx.play("door", near, 1.8)
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
			"radio":
				if e.get("fl", -9) == ve.fl:
					sfx.play("radio", 0.7)
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
