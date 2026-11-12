## Vista en primera persona al apuntar con la pistola (clic derecho).
## Es un raycaster sobre la planta 2D de la simulación:
##  - suelo y techo con un shader (baldosas, alfombras, parqué, luz de las lámparas)
##  - muros por columnas con papel pintado, zócalo, cornisa, cuadros, apliques y ventanas
##  - muebles como cajas 3D, personajes como figuras de frente/lado/espalda
##  - mano con la pistola con silenciador de los años 30, retroceso, fogonazo, humo y casquillos
## Q/E para asomarse (ladea la cabeza y desplaza el ojo y el cañón sin atravesar muros).
class_name FpsView
extends Control

const FOV := 1.25            # rad (unos 72°)
const EYE := 29.0            # altura de los ojos (px del mundo)
const WALL_H := 56.0         # altura de los muros
const DOOR_H := 42.0         # altura del dintel de las puertas
const NEAR := 3.0
const PAD := 96.0            # margen para que al ladear no se vean los bordes
const ROLL := 0.11           # inclinación máxima al asomarse (rad)

var w: World
var e: Ent
var yaw := 0.0
var pitch := 0.0
var lean := 0.0
var lean_off := Vector2.ZERO
var eye := Vector2.ZERO
var fw := Vector2.RIGHT
var rt := Vector2.DOWN
var horizon := 360.0
var proj := 800.0
var cx := 640.0
var vs := Vector2(1280, 720)
var anim := 0.0
var shake := 0.0
var target: Ent = null
var target_d := 0.0
var center_d := 200.0

# arma
var recoil := 0.0
var flash_t := 0.0
var hit_t := 0.0
var hurt_t := 0.0
var lag := 0.0
var help_t := 0.0
var _shot_at: Ent = null
var _shot_t := 0.0
var last_ammo := -1
var last_hp := -1
var parts: Array = []        # humo y casquillos: {k, p, v, t, t0, r}

# iluminación
var _sight := Cfg.SIGHT_PX
var _amb := Color(0.6, 0.6, 0.6)
var _lamp := 1.0
var _own := 0.15
var _own_r := 160.0
var _blackout := false

# capas
var stage: Control
var bg: ColorRect
var mat: ShaderMaterial
var walls: Control
var actors: Control
var occl: Control
var over: Control
var ui: Control
var _pool: Array = []
var gun: GunModel

# columnas de muro
var colw := 3.0
var ncols := 0
var _x0 := 0.0
var _wd := PackedFloat32Array()     # profundidad (px, perpendicular)
var _wk := PackedByteArray()        # 0 nada, 1 muro, 2 horizonte (azotea)
var _wu := PackedFloat32Array()     # coordenada a lo largo del muro (0-1)
var _ws := PackedByteArray()        # lado (0 x, 1 y)
var _wh := PackedInt32Array()       # hash de la cara del muro
var _wx := PackedByteArray()        # 1 si da al exterior (ventana)
var _wm := PackedColorArray()       # luz
var _wa := PackedFloat32Array()     # ángulo del rayo (horizonte)
var _dd := PackedFloat32Array()     # puerta: profundidad del dintel (-1 si no)
var _du := PackedFloat32Array()
var _dm := PackedColorArray()

var boxes: Array = []        # cajas proyectadas, de lejos a cerca
var sprites: Array = []      # personajes visibles, de lejos a cerca
var decals: Array = []       # [PackedVector2Array, Color, polyline?]

# planta cacheada
var _fi := -1
var _light := PackedColorArray()
var _tiles_tex: ImageTexture
var _light_tex: ImageTexture

const SHADER := """
shader_type canvas_item;
uniform vec2 vsize;
uniform float pad;
uniform vec2 eye;
uniform vec2 fw;
uniform vec2 rt;
uniform float horizon;
uniform float proj;
uniform float eye_h;
uniform float ceil_h;
uniform float sight;
uniform vec3 amb;
uniform float lamp_mul;
uniform float own;
uniform float own_r;
uniform float sky;
uniform float street;
uniform float open_from;
uniform float time;
uniform vec3 ceil_col;
uniform vec2 grid;
uniform float ts;
uniform sampler2D tiles : filter_nearest, repeat_disable;
uniform sampler2D lamps : filter_linear, repeat_disable;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float fogf(float d) {
	return clamp((sight - d) / (sight * 0.3), 0.0, 1.0) * (1.0 - 0.3 * clamp(d / sight, 0.0, 1.0));
}

vec3 lit(vec2 wp, float d) {
	vec3 li = texture(lamps, wp / ts / grid).rgb * 2.0 * lamp_mul;
	float o = own * max(0.0, 1.0 - d / own_r);
	return (amb + li + vec3(o)) * fogf(d);
}

vec3 outside(vec2 tc) {
	if (street > 0.5 && tc.y >= open_from) {
		vec3 c = vec3(0.10, 0.10, 0.11) * (0.9 + 0.2 * hash(floor(tc * 6.0)));
		if (tc.y < open_from + 2.0) { c = vec3(0.30, 0.29, 0.27); if (fract(tc.x) < 0.04) c *= 0.7; }
		if (abs(fract(tc.x * 0.5) - 0.5) < 0.2 && abs(tc.y - open_from - 4.5) < 0.06) c = vec3(0.7, 0.62, 0.3);
		return c;
	}
	if (sky > 0.5) {
		vec3 c = vec3(0.01, 0.015, 0.03);
		if (hash(floor(tc * 3.0)) > 0.93) c += vec3(0.5, 0.42, 0.2) * hash(floor(tc * 3.0) + 7.0);
		return c;
	}
	return vec3(0.02, 0.025, 0.03);
}

bool is_void(vec2 wp) {
	vec2 cell = floor(wp / ts);
	if (cell.x < 0.0 || cell.y < 0.0 || cell.x >= grid.x || cell.y >= grid.y) return true;
	return texture(tiles, (cell + 0.5) / grid).a * 255.0 < 0.5;
}

// La ciudad vista desde la azotea, treinta pisos más abajo: calles con farolas y coches, y azoteas con ventanas.
vec3 city(vec2 wp) {
	vec2 c = wp / 260.0;
	vec2 cell = floor(c);
	vec2 f = fract(c);
	float h = hash(cell);
	vec3 col;
	if (f.x < 0.16 || f.y < 0.16) {
		col = vec3(0.075, 0.07, 0.065);
		vec2 lc = floor(c * 7.0);
		vec2 lf = fract(c * 7.0);
		if (hash(lc) > 0.5 && length(lf - 0.5) < 0.2) col += vec3(0.95, 0.72, 0.36) * 0.6;
		float car = fract(c.x * 2.0 + time * 0.05 * (h > 0.5 ? 1.0 : -1.0));
		if (f.y < 0.16 && f.y > 0.05 && car < 0.025) col += vec3(0.9, 0.86, 0.7) * 0.7;
		float car2 = fract(c.y * 2.0 + time * 0.04 * (h > 0.5 ? -1.0 : 1.0));
		if (f.x < 0.16 && f.x > 0.05 && car2 < 0.025) col += vec3(0.8, 0.2, 0.15) * 0.7;
	} else {
		col = vec3(0.03, 0.036, 0.055) * (0.55 + 0.9 * h);
		vec2 wc = floor(c * 9.0);
		vec2 wf = fract(c * 9.0);
		if (hash(wc + 3.0) > 0.8 && wf.x > 0.25 && wf.y > 0.25) col += vec3(0.85, 0.65, 0.3) * 0.4;
		if (h > 0.8 && length(f - 0.6) < 0.1) col = vec3(0.09, 0.07, 0.06);
	}
	return col;
}

float solid_at(vec2 tc) {
	vec2 cell = floor(tc);
	if (cell.x < 0.0 || cell.y < 0.0 || cell.x >= grid.x || cell.y >= grid.y) return 0.0;
	float ty = floor(texture(tiles, (cell + 0.5) / grid).a * 255.0 + 0.5);
	return ty == 1.0 ? 1.0 : 0.0;
}

// Sombra de contacto: el suelo y el techo se oscurecen al pie de los muros.
float ao(vec2 tc) {
	float o = solid_at(tc + vec2(0.14, 0.0)) + solid_at(tc - vec2(0.14, 0.0)) + solid_at(tc + vec2(0.0, 0.14)) + solid_at(tc - vec2(0.0, 0.14));
	float o2 = solid_at(tc + vec2(0.34, 0.0)) + solid_at(tc - vec2(0.34, 0.0)) + solid_at(tc + vec2(0.0, 0.34)) + solid_at(tc - vec2(0.0, 0.34));
	return 1.0 - 0.13 * min(o, 2.0) - 0.08 * min(o2, 2.0);
}

vec3 floor_col(vec2 wp) {
	vec2 tc = wp / ts;
	vec2 cell = floor(tc);
	if (cell.x < 0.0 || cell.y < 0.0 || cell.x >= grid.x || cell.y >= grid.y) return outside(tc);
	vec4 t = texture(tiles, (cell + 0.5) / grid);
	float ty = floor(t.a * 255.0 + 0.5);
	vec3 c = t.rgb;
	vec2 f = fract(tc);
	if (ty < 0.5) return outside(tc);
	if (ty == 2.0) {
		float ch = mod(floor(tc.x * 2.0) + floor(tc.y * 2.0), 2.0);
		c *= mix(1.1, 0.84, ch);
		c += 0.035 * sin(tc.x * 9.0 + sin(tc.y * 7.0) * 2.0);
		vec2 g = fract(tc * 2.0);
		if (min(g.x, g.y) < 0.035) c *= 0.72;
	} else if (ty == 3.0 || ty == 14.0) {
		vec2 g = abs(fract(tc * 2.0) - 0.5);
		float dm = step(g.x + g.y, 0.17);
		c = mix(c, c * 1.4 + vec3(0.06, 0.05, 0.0), dm);
		c *= 0.94 + 0.06 * hash(floor(tc * 16.0));
	} else if (ty == 11.0) {
		float pl = floor(tc.y * 4.0);
		c *= 0.86 + 0.22 * hash(vec2(pl, floor(tc.x + hash(vec2(pl, 1.0)))));
		if (fract(tc.y * 4.0) < 0.07) c *= 0.65;
	} else if (ty == 5.0) {
		c = vec3(0.33, 0.22, 0.11);
	} else if (ty == 6.0) {
		c = vec3(0.32, 0.26, 0.13);
		vec2 g = fract(tc * 4.0);
		if (min(g.x, g.y) < 0.08) c = vec3(0.55, 0.45, 0.22);
	} else if (ty == 7.0 || ty == 8.0) {
		c *= 0.75 + 0.35 * step(0.5, fract(tc.y * 4.0));
	} else if (ty == 4.0 || ty == 10.0 || ty == 12.0) {
		c *= 0.88 + 0.18 * hash(floor(tc * 8.0));
		if (min(f.x, f.y) < 0.02) c *= 0.8;
	} else if (ty == 13.0) {
		c = vec3(0.35, 0.3, 0.2);
	}
	return c;
}

void fragment() {
	vec2 p = UV * (vsize + 2.0 * pad) - pad;
	float dy = p.y - horizon;
	float lx = (p.x - vsize.x * 0.5) / proj;
	vec2 rd = fw + rt * lx;
	vec3 col;
	if (dy > 0.0) {
		float d = eye_h * proj / max(dy, 0.001);
		vec2 wp = eye + rd * d;
		if (sky > 0.5 && is_void(wp)) {
			// más allá del borde de la azotea no hay suelo: se ve la ciudad muy abajo
			float d2 = (eye_h + 1500.0) * proj / max(dy, 0.001);
			vec2 wp2 = eye + rd * d2;
			float haze = clamp(dy / 240.0, 0.0, 1.0);
			col = mix(vec3(0.13, 0.11, 0.17), city(wp2), haze);
		} else {
			col = floor_col(wp) * lit(wp, length(wp - eye)) * ao(wp / ts);
		}
	} else if (sky > 0.5) {
		float k = clamp(-dy / 380.0, 0.0, 1.0);
		col = mix(vec3(0.15, 0.12, 0.2), vec3(0.012, 0.02, 0.055), k);
		col += vec3(0.26, 0.15, 0.08) * exp(dy / 55.0);
		float a = atan(rd.y, rd.x);
		// luna
		float da = atan(sin(a + 2.2), cos(a + 2.2));
		float mr = length(vec2(da * proj, -dy - 310.0));
		col += vec3(0.25, 0.26, 0.32) * exp(-mr / 70.0) * 0.5;
		col = mix(col, vec3(0.93, 0.9, 0.78), 1.0 - smoothstep(24.0, 27.0, mr));
		vec2 sp = vec2(floor(a * 160.0), floor(-dy / 4.0));
		float s = hash(sp);
		if (s > 0.988 && dy < -40.0) col += vec3(0.75) * (0.6 + 0.4 * sin(time * 2.0 + s * 60.0));
	} else {
		float d = ceil_h * proj / max(-dy, 0.001);
		vec2 wp = eye + rd * d;
		vec2 tc = wp / ts;
		vec3 c = ceil_col;
		vec2 g = fract(tc);
		if (min(g.x, g.y) < 0.05) c *= 0.68;
		vec3 li = texture(lamps, tc / grid).rgb * 2.0 * lamp_mul;
		c += li * li * 0.5;
		col = c * lit(wp, length(wp - eye)) * ao(tc);
	}
	COLOR = vec4(col, 1.0);
}
"""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	bg = ColorRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = sh
	bg.material = mat
	stage.add_child(bg)
	walls = _layer(stage, _draw_walls)
	actors = Control.new()
	actors.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(actors)
	occl = _layer(stage, _draw_occl)
	over = _layer(stage, _draw_over)
	ui = _layer(self, _draw_ui)
	gun = GunModel.new()
	add_child(gun)

func _layer(parent: Control, cb: Callable) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	c.draw.connect(cb)
	return c

## Al empezar a apuntar: mira hacia donde estaba el ratón.
func begin(world: World, ent: Ent) -> void:
	w = world
	e = ent
	yaw = atan2(ent.aim_y - ent.y, ent.aim_x - ent.x)
	pitch = 0.0
	lean = 0.0
	recoil = 0.0
	flash_t = 0.0
	lag = 0.0
	parts.clear()
	last_ammo = ent.ammo
	last_hp = ent.hp
	visible = true

## Al salir de la primera persona deja de renderizar el arma.
func stop() -> void:
	visible = false
	if gun != null:
		gun.render_target_update_mode = SubViewport.UPDATE_DISABLED

func look(rel: Vector2) -> void:
	yaw = wrapf(yaw + rel.x * 0.0032, -PI, PI)
	pitch = clampf(pitch - rel.y * 0.9, -vs.y * 0.22, vs.y * 0.22)
	lag = clampf(lag - rel.x * 0.6, -28.0, 28.0)

## WASD relativo a la mirada.
func move_vec(mv: Vector2) -> Vector2:
	return fw * -mv.y + rt * mv.x

## Punto al que apunta la simulación: el personaje bajo la mira o el muro de enfrente.
func aim_point() -> Vector2:
	if target != null:
		return Vector2(target.x, target.y - 2)
	var body := Vector2(e.x, e.y)
	return body + fw * clampf(center_d, 40.0, 600.0)

# ---------------------------------------------------------------- actualización

func update_view(world: World, ent: Ent, delta: float, lean_in: float, shake_in: float) -> void:
	w = world
	e = ent
	anim += delta
	help_t += delta
	var f: FloorData = Hotel.floors[e.fl]
	if f.fi != _fi:
		_build_floor(f)
	# tamaño de la pantalla (el del Control puede quedarse a 0 dentro de un CanvasLayer)
	vs = get_viewport_rect().size
	position = Vector2.ZERO
	size = vs
	cx = vs.x / 2.0
	proj = cx / tan(FOV * 0.5)
	colw = maxf(3.0, vs.x / 420.0)
	_x0 = -PAD
	ncols = ceili((vs.x + PAD * 2.0) / colw)
	fw = Vector2(cos(yaw), sin(yaw))
	rt = Vector2(-fw.y, fw.x)
	# asomarse sin atravesar muros
	lean = move_toward(lean, lean_in, delta * 5.0)
	var body := Vector2(e.x, e.y)
	lean_off = Vector2.ZERO
	if absf(lean) > 0.01:
		var dv := rt * signf(lean)
		var room := Nav.ray_exact(f, body.x, body.y, dv.x, dv.y, Cfg.LEAN_PX + 7.0) - 7.0
		lean_off = dv * clampf(absf(lean) * Cfg.LEAN_PX, 0.0, maxf(room, 0.0))
	eye = body + lean_off
	horizon = vs.y / 2.0 + pitch + (sin(e.walk) * 2.0 if e.moving else 0.0)
	# disparo propio: retroceso, fogonazo, humo y casquillo
	if last_ammo >= 0 and e.ammo < last_ammo:
		_fired()
	last_ammo = e.ammo
	if last_hp >= 0 and e.hp < last_hp:
		hurt_t = 0.6
	last_hp = e.hp
	if _shot_at != null:
		_shot_t -= delta
		if not _shot_at.alive:
			hit_t = 0.45
			_shot_at = null
		elif _shot_t <= 0:
			_shot_at = null
	recoil *= exp(-delta * 10.0)
	flash_t = maxf(0.0, flash_t - delta)
	hit_t = maxf(0.0, hit_t - delta)
	hurt_t = maxf(0.0, hurt_t - delta)
	lag *= exp(-delta * 8.0)
	shake = shake_in
	_update_parts(delta)
	# luz
	_blackout = w.sab_blackout > w.time
	_sight = Cfg.SIGHT_PX * (Cfg.BLACKOUT_SIGHT if _blackout else 1.0) * (2.4 if f.sky else 1.0)   # al aire libre se ve lejos
	var ov := 0.72 if _blackout else (0.18 if f.roof else clampf(0.2 + f.dark * 0.7, 0.22, 0.5))
	var a := (1.0 - ov) * 0.8
	_amb = Color(a, a, a * 1.05)
	if w.sab_alarm > w.time:
		_amb.r += 0.2 * (0.5 + 0.5 * sin(anim * 7.0))
	_lamp = 0.0 if _blackout else 1.0
	_own = (0.55 if _blackout else 0.12) + flash_t * 6.0
	_own_r = 150.0 if _blackout else 170.0
	_cast(f)
	_build_decals(f)
	_build_boxes(f)
	_build_sprites(f)
	_pick_target()
	# capas
	stage.size = vs
	stage.pivot_offset = vs / 2.0
	stage.rotation = -lean * ROLL
	stage.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 5.0 if Settings.shake else Vector2.ZERO
	bg.position = Vector2(-PAD, -PAD)
	bg.size = vs + Vector2(PAD, PAD) * 2.0
	for c in [walls, actors, occl, over, ui]:
		(c as Control).size = vs
	_shader_params(f)
	_sync_actors()
	# arma en 3D
	var gs := Vector2i(int(vs.x), int(vs.y))
	if gun.size != gs:
		gun.size = gs
	gun.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var hl := _mult(e.x, e.y, 0.0)
	hl = Color(hl.r + flash_t * 6.0, hl.g + flash_t * 5.0, hl.b + flash_t * 3.0)
	var sb := 1.0 if e.ammo <= 0 else clampf(recoil * 1.6, 0.0, 1.0)
	gun.pose(recoil, _sway(), sb, flash_t / 0.07, hl, e.outfit.skin, e.outfit.coat)
	walls.queue_redraw()
	occl.queue_redraw()
	over.queue_redraw()
	ui.queue_redraw()

func _fired() -> void:
	recoil = 1.0
	flash_t = 0.07
	_shot_at = target
	_shot_t = 0.4
	var mz := _muzzle_screen()
	for i in 5:
		parts.append({"k": "smoke", "p": mz, "v": Vector2(randf_range(-20, 20), randf_range(-60, -25)), "t": 1.1 + i * 0.1, "t0": 1.1 + i * 0.1, "r": 4.0 + i})
	var s := vs.y / 720.0
	parts.append({"k": "shell", "p": gun.port_screen(), "v": Vector2(randf_range(240, 320), randf_range(-330, -260)) * s, "t": 0.7, "t0": 0.7, "r": randf_range(0, TAU)})

func _update_parts(delta: float) -> void:
	var keep: Array = []
	var s := vs.y / 720.0
	for p in parts:
		p["t"] = float(p["t"]) - delta
		if float(p["t"]) <= 0:
			continue
		var v: Vector2 = p["v"]
		if p["k"] == "shell":
			v.y += 1500.0 * s * delta
			p["r"] = float(p["r"]) + delta * 18.0
		else:
			v *= exp(-delta * 1.5)
			v.x += lag * 0.02
		p["v"] = v
		p["p"] = (p["p"] as Vector2) + v * delta
		keep.append(p)
	# un hilo de humo sale del silenciador justo después de disparar
	if recoil > 0.15 and randf() < 0.5:
		keep.append({"k": "smoke", "p": _muzzle_screen(), "v": Vector2(randf_range(-8, 8), -40), "t": 0.9, "t0": 0.9, "r": 3.0})
	parts = keep

# ---------------------------------------------------------------- planta: texturas de casillas y luz

func _build_floor(f: FloorData) -> void:
	_fi = f.fi
	var W := Cfg.W
	var H := Cfg.H
	var TS := float(Cfg.TS)
	_light.resize(W * H)
	var timg := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	var limg := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	var lamps: Array = []
	for l in f.lamps:
		var tint := Color(0.25, 0.32, 0.42) if l["tint"] == "cold" else Color(0.42, 0.33, 0.18)
		lamps.append([Vector2(l["x"], l["y"]), float(l["r"]) * 1.1, tint])
	if f.roof:
		for o in f.furn:
			if o["k"] == "mast":
				lamps.append([Vector2((o["x"] + o["w"] / 2.0) * TS, (o["y"] + o["h"] / 2.0) * TS), 170.0, Color(0.32, 0.05, 0.04)])
	if f.fi == 1:
		for lx in [8, 15, 29, 36]:
			lamps.append([Vector2(lx * TS, 27.0 * TS + 6), 120.0, Color(0.4, 0.32, 0.16)])
	for ty in H:
		for tx in W:
			var p := Vector2((tx + 0.5) * TS, (ty + 0.5) * TS)
			var c := Color(0, 0, 0, 1)
			for L in lamps:
				var lp: Vector2 = L[0]
				var lr: float = L[1]
				var tint: Color = L[2]
				var k := 1.0 - p.distance_to(lp) / lr
				if k > 0.0:
					c.r += tint.r * k * k * 1.5
					c.g += tint.g * k * k * 1.5
					c.b += tint.b * k * k * 1.5
			_light[ty * W + tx] = c
			limg.set_pixel(tx, ty, Color(minf(c.r * 0.5, 1.0), minf(c.g * 0.5, 1.0), minf(c.b * 0.5, 1.0), 1.0))
			var t := f.at(tx, ty)
			var tc := Painter.tile_color(t)
			tc.a = t / 255.0
			timg.set_pixel(tx, ty, tc)
	_tiles_tex = ImageTexture.create_from_image(timg)
	_light_tex = ImageTexture.create_from_image(limg)

func _shader_params(f: FloorData) -> void:
	mat.set_shader_parameter("vsize", vs)
	mat.set_shader_parameter("pad", PAD)
	mat.set_shader_parameter("eye", eye)
	mat.set_shader_parameter("fw", fw)
	mat.set_shader_parameter("rt", rt)
	mat.set_shader_parameter("horizon", horizon)
	mat.set_shader_parameter("proj", proj)
	mat.set_shader_parameter("eye_h", EYE)
	mat.set_shader_parameter("ceil_h", WALL_H - EYE)
	mat.set_shader_parameter("sight", _sight)
	mat.set_shader_parameter("amb", Vector3(_amb.r, _amb.g, _amb.b))
	mat.set_shader_parameter("lamp_mul", _lamp)
	mat.set_shader_parameter("own", _own)
	mat.set_shader_parameter("own_r", _own_r)
	mat.set_shader_parameter("sky", 1.0 if f.sky else 0.0)
	mat.set_shader_parameter("street", 1.0 if f.fi == 1 else 0.0)
	mat.set_shader_parameter("open_from", float(f.open_from))
	mat.set_shader_parameter("time", anim)
	var cc := Color("#3a3128") if f.fi > 0 else Color("#2a2c2e")
	mat.set_shader_parameter("ceil_col", Vector3(cc.r, cc.g, cc.b))
	mat.set_shader_parameter("grid", Vector2(Cfg.W, Cfg.H))
	mat.set_shader_parameter("ts", float(Cfg.TS))
	mat.set_shader_parameter("tiles", _tiles_tex)
	mat.set_shader_parameter("lamps", _light_tex)

# ---------------------------------------------------------------- luz en un punto

func _fog(d: float) -> float:
	return clampf((_sight - d) / (_sight * 0.3), 0.0, 1.0) * (1.0 - 0.3 * clampf(d / _sight, 0.0, 1.0))

func _mult(wx: float, wy: float, d: float) -> Color:
	# luz interpolada entre las cuatro casillas vecinas: sin escalones de una casilla a otra
	var gx := clampf(wx / Cfg.TS - 0.5, 0.0, Cfg.W - 1.001)
	var gy := clampf(wy / Cfg.TS - 0.5, 0.0, Cfg.H - 1.001)
	var ix := floori(gx)
	var iy := floori(gy)
	var l00: Color = _light[iy * Cfg.W + ix]
	var l10: Color = _light[iy * Cfg.W + ix + 1]
	var l01: Color = _light[(iy + 1) * Cfg.W + ix]
	var l11: Color = _light[(iy + 1) * Cfg.W + ix + 1]
	var l: Color = l00.lerp(l10, gx - ix).lerp(l01.lerp(l11, gx - ix), gy - iy)
	var o := _own * maxf(0.0, 1.0 - d / _own_r)
	var k := _fog(d)
	return Color((_amb.r + l.r * _lamp + o) * k, (_amb.g + l.g * _lamp + o) * k, (_amb.b + l.b * _lamp + o) * k, 1.0)

static func _lit(c: Color, m: Color) -> Color:
	return Color(c.r * m.r, c.g * m.g, c.b * m.b, c.a)

# ---------------------------------------------------------------- muros (DDA por columnas)

func _cast(f: FloorData) -> void:
	_wd.resize(ncols); _wk.resize(ncols); _wu.resize(ncols); _ws.resize(ncols); _wh.resize(ncols)
	_wx.resize(ncols); _wm.resize(ncols); _wa.resize(ncols); _dd.resize(ncols); _du.resize(ncols); _dm.resize(ncols)
	var TS := float(Cfg.TS)
	var ox := eye.x / TS
	var oy := eye.y / TS
	for c in ncols:
		var sx := _x0 + (c + 0.5) * colw
		var rd := fw + rt * ((sx - cx) / proj)
		var rl := rd.length()
		var maxt := _sight / TS / rl
		var mx := floori(ox)
		var my := floori(oy)
		var ddx := absf(1.0 / rd.x) if absf(rd.x) > 1e-6 else 1e9
		var ddy := absf(1.0 / rd.y) if absf(rd.y) > 1e-6 else 1e9
		var stx := 1 if rd.x > 0 else -1
		var sty := 1 if rd.y > 0 else -1
		var sdx := ((mx + 1.0 - ox) if rd.x > 0 else (ox - mx)) * ddx
		var sdy := ((my + 1.0 - oy) if rd.y > 0 else (oy - my)) * ddy
		var side := 0
		var kind := 0
		var t := maxt
		var door := -1.0
		var door_u := 0.0
		var door_side := 0
		for _i in 80:
			if sdx < sdy:
				t = sdx
				sdx += ddx
				mx += stx
				side = 0
			else:
				t = sdy
				sdy += ddy
				my += sty
				side = 1
			if t > maxt:
				t = maxt
				break
			var inside := mx >= 0 and my >= 0 and mx < Cfg.W and my < Cfg.H
			var tt := f.at(mx, my)
			if my >= f.open_from:
				if not inside:
					break
				continue
			if tt == Cfg.T_VOID and f.sky:
				kind = 2
				break
			if tt == Cfg.T_ELEV:
				kind = 4     # puertas del ascensor
				break
			if tt == Cfg.T_WALL or tt == Cfg.T_VOID:
				kind = 1
				break
			if tt == Cfg.T_DOOR and not f.door_open(mx, my):
				kind = 3     # puerta cerrada
				break
			if tt == Cfg.T_DOOR and door < 0.0 and t > 0.05:
				door = t
				door_side = side
				door_u = fmod((oy + t * rd.y) if side == 0 else (ox + t * rd.x), 1.0)
		var d := t * TS
		_wa[c] = atan2(rd.y, rd.x)
		_wk[c] = kind
		if kind == 2:
			_wd[c] = 1e9
		else:
			_wd[c] = d
		_ws[c] = side
		var wx := (oy + t * rd.y) if side == 0 else (ox + t * rd.x)
		_wu[c] = wx - floorf(wx)
		_wh[c] = absi((mx * 73856093) ^ (my * 19349663) ^ ((side + 1) * 83492791)) % 1000003
		var bx := mx + (stx if side == 0 else 0)
		var by := my + (sty if side == 1 else 0)
		var bt := f.at(bx, by)
		_wx[c] = 1 if (kind == 1 and f.fi > 0 and bt == Cfg.T_VOID and by < f.open_from) else 0
		var fx := mx - (stx if side == 0 else 0)
		var fy := my - (sty if side == 1 else 0)
		# la luz se toma en el punto del muro (un poco hacia quien mira), no en el centro de la casilla
		var dl := maxf(d - 9.0, 0.0)
		_wm[c] = _mult(eye.x + rd.x * dl, eye.y + rd.y * dl, d * rl)
		if (fx + fy) < -9999:
			pass
		if door > 0.0:
			_dd[c] = door * TS
			_du[c] = door_u - floorf(door_u)
			var m := _mult(eye.x + rd.x * door * TS, eye.y + rd.y * door * TS, door * TS * rl)
			if door_side == 1:
				m = Color(m.r * 0.82, m.g * 0.82, m.b * 0.82)
			_dm[c] = m
		else:
			_dd[c] = -1.0

func _zy(z: float, d: float) -> float:
	return horizon + (EYE - z) * proj / d

## Una columna de muro: zócalo, moldura dorada, papel pintado y cornisa; con cuadros, apliques o ventanas.
func _draw_col(ci: CanvasItem, c: int) -> void:
	var k := _wk[c]
	var x := _x0 + c * colw
	var cw := colw + 0.6
	if k == 2:
		_draw_skyline(ci, c, x, cw)
		return
	if k == 3:
		_draw_door(ci, c, x, cw)
		return
	if k == 4:
		_draw_elev(ci, c, x, cw)
		return
	if k != 1:
		return
	var d := maxf(_wd[c], 1.0)
	var m: Color = _wm[c]
	if _ws[c] == 1:
		m = Color(m.r * 0.8, m.g * 0.8, m.b * 0.8)
	var u := _wu[c]
	var hh := _wh[c]
	var paper := Painter.wall_paper(_fi)
	var stripe := 1.07 if fmod(u * 6.0, 1.0) < 0.5 else 0.95
	if _fi == 0:
		# sótano: hormigón con una tubería
		_seg(ci, x, cw, 0, WALL_H, d, _lit(Color("#4a4f55") * (0.95 + 0.1 * fmod(float(hh % 7), 2.0)), m))
		_seg(ci, x, cw, 44, 47, d, _lit(Color("#2c3036"), m))
		_seg(ci, x, cw, 0, 3, d, _lit(Color("#26292d"), m))
		return
	var roofy: bool = Hotel.floors[_fi].sky
	if roofy:
		# estructuras de la azotea: ladrillo
		_seg(ci, x, cw, 0, WALL_H, d, _lit(Color("#6a3b2c"), m))
		for j in 7:
			var z0 := 4.0 + j * 7.5
			_seg(ci, x, cw, z0, z0 + 0.8, d, _lit(Color("#3a2018"), m))
		return
	_seg(ci, x, cw, 0, 3, d, _lit(Color("#1d140d"), m))
	_seg(ci, x, cw, 3, 17, d, _lit(Color("#3b2618") * (1.04 if fmod(u * 3.0, 1.0) < 0.9 else 0.8), m))
	_seg(ci, x, cw, 17, 18.6, d, _lit(Painter.GOLD2, m))
	_seg(ci, x, cw, 18.6, 50, d, _lit(paper * stripe, m))
	_seg(ci, x, cw, 50, 52, d, _lit(Color("#8f7a52"), m))
	_seg(ci, x, cw, 52, WALL_H, d, _lit(Color("#cdbf9c"), m))
	if _wx[c] == 1 and hh % 3 != 0:
		_window(ci, x, cw, u, hh, d, m)
	elif hh % 7 == 1 and u > 0.22 and u < 0.78:
		# cuadro con marco dorado
		var edge := u < 0.27 or u > 0.73
		_seg(ci, x, cw, 25, 45, d, _lit(Painter.GOLD2, m))
		if not edge:
			var pal := [Color("#3d5a40"), Color("#6b3d2e"), Color("#2e4a6b"), Color("#7a6a3a")]
			var base: Color = pal[int(hh / 7.0) % 4]
			_seg(ci, x, cw, 27, 35, d, _lit(base.darkened(0.2), m))
			_seg(ci, x, cw, 35, 43, d, _lit(base.lightened(0.35), m))
	elif hh % 7 == 3 and u > 0.42 and u < 0.58:
		# aplique de latón con bombilla (brilla aunque esté lejos)
		_seg(ci, x, cw, 32, 36, d, _lit(Color("#b8923f"), m))
		var glow := Color("#ffe6a8") if not _blackout else Color("#3a3226")
		_seg(ci, x, cw, 36, 40, d, glow * (0.4 + 0.6 * _fog(d)))
	# sombra en el encuentro con el techo y con el suelo: da volumen al muro
	_seg(ci, x, cw, WALL_H - 5.0, WALL_H, d, Color(0, 0, 0, 0.2))
	_seg(ci, x, cw, WALL_H - 2.0, WALL_H, d, Color(0, 0, 0, 0.18))
	_seg(ci, x, cw, 0, 2.4, d, Color(0, 0, 0, 0.26))

## Puertas del ascensor: marco de latón, dos hojas con abanico art déco e indicador de planta.
func _draw_elev(ci: CanvasItem, c: int, x: float, cw: float) -> void:
	var d := maxf(_wd[c], 1.0)
	var m: Color = _wm[c]
	if _ws[c] == 1:
		m = Color(m.r * 0.82, m.g * 0.82, m.b * 0.82)
	var u := _wu[c]
	_seg(ci, x, cw, 46, WALL_H, d, _lit(Color("#2a2018"), m))
	_seg(ci, x, cw, 44, 46, d, _lit(Painter.GOLD2, m))
	# indicador de planta sobre la puerta
	if absf(u - 0.5) < 0.17:
		_seg(ci, x, cw, 48.2, 53.6, d, _lit(Color("#120d08"), m))
		if absf(u - 0.5) < 0.035:
			_seg(ci, x, cw, 49.4, 52.4, d, Color("#ffd98a") * (0.5 + 0.5 * _fog(d)))
		elif absf(u - 0.5) > 0.14:
			_seg(ci, x, cw, 48.2, 53.6, d, _lit(Painter.GOLD2, m))
	if u < 0.07 or u > 0.93:
		_seg(ci, x, cw, 0, 44, d, _lit(Color("#8f7330"), m))
		return
	if absf(u - 0.5) < 0.012:
		_seg(ci, x, cw, 0, 44, d, _lit(Color("#120d08"), m))
		return
	var leaf := Color("#b8923f")
	_seg(ci, x, cw, 0, 44, d, _lit(leaf, m))
	var lu := (u - 0.07) / 0.43 if u < 0.5 else (u - 0.5) / 0.43     # 0-1 dentro de cada hoja
	if lu < 0.1 or lu > 0.9:
		_seg(ci, x, cw, 2.5, 41.5, d, _lit(leaf.darkened(0.28), m))
		return
	_seg(ci, x, cw, 2.5, 4.0, d, _lit(leaf.darkened(0.28), m))
	_seg(ci, x, cw, 40.0, 41.5, d, _lit(leaf.darkened(0.28), m))
	# abanico escalonado
	var kk := floorf(absf(lu - 0.5) * 2.0 * 5.0) / 5.0
	_seg(ci, x, cw, 9.0, 35.0 - kk * 17.0, d, _lit(Color("#dcc070"), m))
	_seg(ci, x, cw, 9.0, 10.2, d, _lit(leaf.darkened(0.3), m))
	if fmod(lu * 10.0, 2.0) < 0.35:
		_seg(ci, x, cw, 10.2, 35.0 - kk * 17.0, d, _lit(leaf.darkened(0.18), m))

## Puerta cerrada: hoja de madera con cuarterones y pomo de latón, dintel encima.
func _draw_door(ci: CanvasItem, c: int, x: float, cw: float) -> void:
	var d := maxf(_wd[c], 1.0)
	var m: Color = _wm[c]
	if _ws[c] == 1:
		m = Color(m.r * 0.82, m.g * 0.82, m.b * 0.82)
	var u := _wu[c]
	var paper := Painter.wall_paper(_fi)
	_seg(ci, x, cw, DOOR_H, 50, d, _lit(paper, m))
	_seg(ci, x, cw, 50, 52, d, _lit(Color("#8f7a52"), m))
	_seg(ci, x, cw, 52, WALL_H, d, _lit(Color("#cdbf9c"), m))
	if u < 0.07 or u > 0.93:
		_seg(ci, x, cw, 0, DOOR_H + 2, d, _lit(Color("#3e2616"), m))
		return
	_seg(ci, x, cw, DOOR_H, DOOR_H + 2, d, _lit(Color("#3e2616"), m))
	_seg(ci, x, cw, 0, DOOR_H, d, _lit(Color("#7a5232"), m))
	var inner := (u > 0.17 and u < 0.47) or (u > 0.53 and u < 0.83)
	if inner:
		_seg(ci, x, cw, 4, 17, d, _lit(Color("#664328"), m))
		_seg(ci, x, cw, 21, 38, d, _lit(Color("#664328"), m))
	if absf(u - 0.86) < 0.035:
		_seg(ci, x, cw, 19, 21.5, d, _lit(Painter.GOLD, m))

func _window(ci: CanvasItem, x: float, cw: float, u: float, hh: int, d: float, m: Color) -> void:
	if u < 0.18 or u > 0.82:
		return
	var frame := u < 0.23 or u > 0.77 or absf(u - 0.5) < 0.025
	if frame:
		_seg(ci, x, cw, 22, 47, d, _lit(Color("#d8ccaa"), m))
		return
	var k := _fog(d)
	_seg(ci, x, cw, 22, 47, d, Color("#0d1a33") * (0.5 + 0.5 * k))
	for j in 4:
		var hv := absi((hh + j * 131 + floori(u * 7.0) * 977) % 97)
		if hv < 30:
			var z := 25.0 + j * 5.5
			_seg(ci, x, cw, z, z + 1.6, d, Color(1.0, 0.85, 0.5) * (0.35 + 0.4 * k))
	_seg(ci, x, cw, 33.8, 34.8, d, _lit(Color("#d8ccaa"), m))
	# cortinas
	if u < 0.32 or u > 0.68:
		_seg(ci, x, cw, 22, 47, d, _lit(Color("#6e2731"), m))

func _seg(ci: CanvasItem, x: float, cw: float, z0: float, z1: float, d: float, col: Color) -> void:
	var y0 := _zy(z1, d)
	var y1 := _zy(z0, d)
	y0 = maxf(y0, -PAD * 2.0)
	y1 = minf(y1, vs.y + PAD * 2.0)
	if y1 > y0:
		ci.draw_rect(Rect2(x, y0, cw, y1 - y0), col)

## Desde la azotea: el skyline de Manhattan a lo lejos.
func _draw_skyline(ci: CanvasItem, c: int, x: float, cw: float) -> void:
	var s := vs.y / 720.0
	var b := floori(_wa[c] * 28.0)
	var hv := absf(sin(b * 12.9898) * 43758.5453)
	hv -= floorf(hv)
	var hgt := (30.0 + hv * 120.0) * s
	# segunda fila de rascacielos, más lejos y más clara por la bruma
	var b2 := floori(_wa[c] * 11.0 + 40.0)
	var hv2 := absf(sin(b2 * 4.1414) * 24634.6345)
	hv2 -= floorf(hv2)
	var hgt2 := (90.0 + hv2 * 150.0) * s
	ci.draw_rect(Rect2(x, horizon - hgt2, cw, hgt2 + 2), Color("#1a2238"))
	if hv2 > 0.82:
		ci.draw_rect(Rect2(x, horizon - hgt2 - 26.0 * s, cw, 26.0 * s), Color("#1a2238") if absf(fmod(_wa[c] * 11.0 + 40.0, 1.0) - 0.5) < 0.12 else Color(0, 0, 0, 0))
	ci.draw_rect(Rect2(x, horizon - hgt, cw, hgt + 2), Color("#0b1220"))
	for j in 6:
		var lv := absf(sin((b * 7 + j) * 78.233) * 12543.21)
		lv -= floorf(lv)
		if lv > 0.55 and 10.0 + j * 13.0 < hgt / s - 6.0:
			var col := Color(1.0, 0.82, 0.45, 0.6) if lv > 0.8 else Color(0.8, 0.85, 1.0, 0.35)
			if fmod(_wa[c] * 900.0, 3.0) < 1.6:
				ci.draw_rect(Rect2(x, horizon - hgt + (10.0 + j * 13.0) * s, cw, 3 * s), col)

func _draw_lintel(ci: CanvasItem, c: int) -> void:
	var d := _dd[c]
	if d <= 0.0:
		return
	var x := _x0 + c * colw
	var cw := colw + 0.6
	var m: Color = _dm[c]
	var paper := Painter.wall_paper(_fi)
	if Hotel.floors[_fi].sky:
		_seg(ci, x, cw, DOOR_H, WALL_H, d, _lit(Color("#6a3b2c"), m))
		return
	_seg(ci, x, cw, DOOR_H - 2.5, DOOR_H, d, _lit(Color("#4a2e1a"), m))
	_seg(ci, x, cw, DOOR_H, 50, d, _lit(paper, m))
	_seg(ci, x, cw, 50, 52, d, _lit(Color("#8f7a52"), m))
	_seg(ci, x, cw, 52, WALL_H, d, _lit(Color("#cdbf9c"), m))
	# marco de la puerta en los extremos
	var u := _du[c]
	if u < 0.08 or u > 0.92:
		_seg(ci, x, cw, 0, DOOR_H, d, _lit(Color("#4a2e1a"), m))

# ---------------------------------------------------------------- proyección

func _cam(p: Vector3) -> Vector3:
	var rx := p.x - eye.x
	var ry := p.y - eye.y
	return Vector3(rx * fw.x + ry * fw.y, rx * rt.x + ry * rt.y, p.z)

func _scr(c: Vector3) -> Vector2:
	return Vector2(cx + c.y / c.x * proj, horizon + (EYE - c.z) / c.x * proj)

## Polígono 3D del mundo a pantalla, recortado contra el plano cercano.
func _poly3(pts: Array) -> PackedVector2Array:
	var cam: Array = []
	for p in pts:
		cam.append(_cam(p))
	var res := PackedVector2Array()
	var n := cam.size()
	for i in n:
		var a: Vector3 = cam[i]
		var b: Vector3 = cam[(i + 1) % n]
		var ain := a.x >= NEAR
		var bin := b.x >= NEAR
		if ain:
			res.append(_scr(a))
		if ain != bin:
			res.append(_scr(a.lerp(b, (NEAR - a.x) / (b.x - a.x))))
	return res

static func _area(p: PackedVector2Array) -> float:
	var s := 0.0
	var n := p.size()
	for i in n:
		var a := p[i]
		var b := p[(i + 1) % n]
		s += a.x * b.y - b.x * a.y
	return absf(s) * 0.5

func _fill(ci: CanvasItem, p: PackedVector2Array, col: Color) -> void:
	if p.size() >= 3 and _area(p) > 1.0:
		ci.draw_colored_polygon(p, col)

func _ground_poly(cxw: float, cyw: float, ang: float, local: Array, z: float) -> PackedVector2Array:
	var pts: Array = []
	var ca := cos(ang)
	var sa := sin(ang)
	for v in local:
		var q: Vector2 = v
		pts.append(Vector3(cxw + q.x * ca - q.y * sa, cyw + q.x * sa + q.y * ca, z))
	return _poly3(pts)

func _ellipse_local(rx: float, ry: float, n: int = 14) -> Array:
	var l: Array = []
	for i in n:
		var a := TAU * i / n
		l.append(Vector2(cos(a) * rx, sin(a) * ry))
	return l

# ---------------------------------------------------------------- calcomanías del suelo (alfombras, cadáveres, tiza)

func _build_decals(f: FloorData) -> void:
	decals.clear()
	var TS := float(Cfg.TS)
	for o in f.furn:
		if o["k"] != "rug":
			continue
		var x0: float = o["x"] * TS + 2
		var y0: float = o["y"] * TS + 2
		var x1: float = (o["x"] + o["w"]) * TS - 2
		var y1: float = (o["y"] + o["h"]) * TS - 2
		var cxw := (x0 + x1) / 2.0
		var cyw := (y0 + y1) / 2.0
		if Vector2(cxw, cyw).distance_to(eye) > _sight + maxf(x1 - x0, y1 - y0):
			continue
		var m := _mult(cxw, cyw, Vector2(cxw, cyw).distance_to(eye))
		decals.append([_poly3([Vector3(x0, y0, 0.3), Vector3(x1, y0, 0.3), Vector3(x1, y1, 0.3), Vector3(x0, y1, 0.3)]), _lit(Painter.furn_color("rug"), m), false])
		decals.append([_poly3([Vector3(x0 + 4, y0 + 4, 0.4), Vector3(x1 - 4, y0 + 4, 0.4), Vector3(x1 - 4, y1 - 4, 0.4), Vector3(x0 + 4, y1 - 4, 0.4)]), _lit(Painter.GOLD2.darkened(0.2), m), true])
	# charcos de sangre, huellas y rastros
	for bp in w.pools:
		if int(bp["fl"]) != e.fl:
			continue
		var bx: float = bp["x"]
		var by: float = bp["y"]
		var bd := Vector2(bx, by).distance_to(eye)
		if bd > _sight + 30:
			continue
		var pr: float = float(bp["r"]) * clampf((w.time - float(bp["t"])) / 4.0, 0.35, 1.0)
		decals.append([_ground_poly(bx, by, 0.0, _ellipse_local(pr * 1.35, pr * 0.8), 0.2), _lit(Color(0.38, 0.02, 0.05, 0.85), _mult(bx, by, bd)), false])
	for ft in w.prints:
		if int(ft["fl"]) != e.fl:
			continue
		var fx2: float = ft["x"]
		var fy2: float = ft["y"]
		var fd := Vector2(fx2, fy2).distance_to(eye)
		if fd > _sight:
			continue
		var fade: float = clampf(1.0 - (w.time - float(ft["t"])) / Stealth.PRINT_LIFE, 0.0, 1.0)
		var shape := [Vector2(-10, -4), Vector2(10, -4), Vector2(10, 4), Vector2(-10, 4)]
		if not ft["drag"]:
			var sd: float = 3.5 if int(ft["s"]) == 0 else -3.5
			shape = [Vector2(-5, sd - 1.6), Vector2(3, sd - 1.6), Vector2(3, sd + 1.6), Vector2(-5, sd + 1.6)]
		decals.append([_ground_poly(fx2, fy2, float(ft["a"]), shape, 0.25), _lit(Color(0.42, 0.03, 0.06, 0.75 * fade), _mult(fx2, fy2, fd)), false])
	for c in w.corpses:
		if c.fl != e.fl or c.hidden:
			continue
		var dd := Vector2(c.x, c.y).distance_to(eye)
		if dd > _sight + 30:
			continue
		var m2 := _mult(c.x, c.y, dd)
		if c.chalk:
			var outline := [Vector2(-22, 0), Vector2(-20, -6), Vector2(-8, -7), Vector2(10, -6), Vector2(16, -8), Vector2(19, -3), Vector2(12, 0), Vector2(19, 3), Vector2(16, 8), Vector2(10, 6), Vector2(-8, 7), Vector2(-20, 6)]
			decals.append([_ground_poly(c.x, c.y + 4, c.ang, outline, 0.3), Color(0.92, 0.92, 0.88, 0.85 * _fog(dd)), true])
			continue
		decals.append([_ground_poly(c.x, c.y + 4, c.ang, [Vector2(-12, -5), Vector2(6, -5), Vector2(6, 5), Vector2(-12, 5)], 3.0), _lit(c.outfit.coat, m2), false])
		decals.append([_ground_poly(c.x, c.y + 4, c.ang, [Vector2(4, -4), Vector2(14, -4), Vector2(14, 4), Vector2(4, 4)], 2.5), _lit(c.outfit.pants, m2), false])
		var hl: Array = []
		for v in _ellipse_local(5.5, 5.5, 10):
			hl.append((v as Vector2) + Vector2(-14, 0))
		decals.append([_ground_poly(c.x, c.y + 4, c.ang, hl, 3.5), _lit(c.outfit.skin, m2), false])

# ---------------------------------------------------------------- muebles como cajas 3D

const FURN_H := {"plant": 11.0, "phone": 18.0, "bench": 9.0, "table": 15.0, "desk": 15.0, "night": 12.0, "shelf": 38.0, "mail": 34.0,
	"ward": 42.0, "stage": 5.0, "crate": 14.0, "bar": 21.0, "recdesk": 21.0, "boiler": 36.0, "gen": 26.0, "steel": 36.0, "vent": 14.0,
	"antenna": 90.0, "cart": 15.0, "washer": 17.0, "sink": 17.0, "stove": 17.0, "sofa": 8.0, "safe": 20.0, "piano": 21.0, "bed": 9.0,
	"scope": 24.0, "sign": 60.0, "mast": 300.0}

func _box(list: Array, x0: float, y0: float, x1: float, y1: float, z0: float, z1: float, col: Color, top: Color, extra: Dictionary = {}) -> void:
	var b := {"x0": x0, "y0": y0, "x1": x1, "y1": y1, "z0": z0, "z1": z1, "col": col, "top": top}
	b.merge(extra)
	list.append(b)

func _furn_boxes(o: Dictionary, list: Array) -> void:
	var TS := float(Cfg.TS)
	var k: String = o["k"]
	var x0: float = o["x"] * TS + 5
	var y0: float = o["y"] * TS + 5
	var x1: float = (o["x"] + o["w"]) * TS - 5
	var y1: float = (o["y"] + o["h"]) * TS - 5
	var c := Painter.furn_color(k)
	var hgt: float = FURN_H.get(k, 24.0)
	match k:
		"column":
			list.append({"kind": "cyl", "x": (x0 + x1) / 2.0, "y": (y0 + y1) / 2.0, "r": minf(x1 - x0, y1 - y0) * 0.42, "col": c})
		"plant":
			var pcx := (x0 + x1) / 2.0
			var pcy := (y0 + y1) / 2.0
			_box(list, pcx - 5, pcy - 5, pcx + 5, pcy + 5, 0, 10, Color("#6b4a2a"), Color("#3a2a1a"))
			list.append({"kind": "ball", "x": pcx, "y": pcy, "z": 19.0, "r": 8.5, "col": c})
		"table", "desk":
			_box(list, x0, y0, x1, y1, hgt - 3, hgt, c, c.lightened(0.18))
			for q in [[x0, y0], [x1 - 3, y0], [x0, y1 - 3], [x1 - 3, y1 - 3]]:
				_box(list, q[0], q[1], q[0] + 3, q[1] + 3, 0, hgt - 3, c.darkened(0.3), c, {"notop": true})
			if k == "desk":
				_box(list, x0 + 4, y0 + 2, x0 + 10, y0 + 7, hgt, hgt + 7, Color("#2a2a2e"), Color("#ffe6a8"))
		"bench":
			_box(list, x0, y0, x1, y1, 6, 9, c, c.lightened(0.15))
			_box(list, x0, y0, x0 + 3, y1, 0, 6, c.darkened(0.3), c, {"notop": true})
			_box(list, x1 - 3, y0, x1, y1, 0, 6, c.darkened(0.3), c, {"notop": true})
		"sofa":
			_box(list, x0, y0, x1, y1, 0, 8, c, c.lightened(0.12))
			if x1 - x0 >= y1 - y0:
				_box(list, x0, y0, x1, y0 + 6, 8, 17, c.darkened(0.1), c.lightened(0.05))
			else:
				_box(list, x0, y0, x0 + 6, y1, 8, 17, c.darkened(0.1), c.lightened(0.05))
		"bed":
			_box(list, x0, y0, x1, y1, 0, 6, Color("#4a2f22"), Color("#5e3d24"))
			_box(list, x0 + 2, y0 + 2, x1 - 2, y1 - 2, 6, 10, c, c)
			_box(list, x0 + 2, y0 + (y1 - y0) * 0.42, x1 - 2, y1 - 2, 10, 11, Color("#7a2b37"), Color("#7a2b37"))
			_box(list, x0 + 4, y0 + 4, x1 - 4, y0 + 11, 10, 12.5, Color("#fbf7ec"), Color("#fbf7ec"))
			_box(list, x0, y0, x1, y0 + 3, 6, 19, Color("#4a2f22"), Color("#5e3d24"))
		"piano":
			_box(list, x0, y0, x1, y1, 0, hgt, c, Color("#1e1e26"))
			_box(list, x0 + 2, y1 - 2, x1 - 2, y1 + 3, 13, 15, Color("#efe9d9"), Color("#efe9d9"))
		"bar", "recdesk":
			_box(list, x0, y0, x1, y1, 0, hgt - 2, c, c)
			_box(list, x0 - 1, y0 - 1, x1 + 1, y1 + 1, hgt - 2, hgt, Color("#7a5232"), Color("#9a6a42"))
		"mast":
			# gran antena de radio: zócalo de hormigón, torre de celosía que se estrecha, brazos y baliza roja
			var mx := (x0 + x1) / 2.0
			var my := (y0 + y1) / 2.0
			var steel := Color("#7d8791")
			_box(list, mx - 27, my - 27, mx + 27, my + 27, 0, 7, Color("#4a4f57"), Color("#5c626b"))
			var zs: Array = [7.0, 62.0, 116.0, 166.0, 212.0, 252.0]
			var ws: Array = [15.0, 11.5, 8.5, 6.0, 3.8, 2.2]
			for i in 5:
				var wa: float = ws[i]
				var za: float = zs[i]
				var zb: float = zs[i + 1]
				for sx in [-1.0, 1.0]:
					for sy in [-1.0, 1.0]:
						var lx: float = mx + float(sx) * wa
						var ly: float = my + float(sy) * wa
						_box(list, lx - 1.2, ly - 1.2, lx + 1.2, ly + 1.2, za, zb, steel, steel, {"notop": true})
				_box(list, mx - wa - 1.2, my - wa - 1.2, mx + wa + 1.2, my + wa + 1.2, zb - 2.0, zb, steel.darkened(0.2), steel)
			_box(list, mx - 22, my - 1.5, mx + 22, my + 1.5, 150, 153, steel, steel)
			_box(list, mx - 1.5, my - 22, mx + 1.5, my + 22, 196, 199, steel, steel)
			_box(list, mx - 1.0, my - 1.0, mx + 1.0, my + 1.0, 252, 300, steel, steel, {"notop": true})
			var bcn := Color("#ff3a3a") if fmod(anim, 1.4) < 0.7 else Color("#5a1414")
			_box(list, mx - 2.5, my - 2.5, mx + 2.5, my + 2.5, 300, 305, bcn, bcn, {"emit": true})
		"antenna":
			var acx := (x0 + x1) / 2.0
			var acy := (y0 + y1) / 2.0
			_box(list, acx - 2, acy - 2, acx + 2, acy + 2, 0, hgt, Color("#5d666e"), Color("#ff3a3a"), {"emit_top": true})
		_:
			_box(list, x0, y0, x1, y1, 0, hgt, c, c.lightened(0.12))

func _build_boxes(f: FloorData) -> void:
	boxes.clear()
	var raw: Array = []
	var TS := float(Cfg.TS)
	for o in f.furn:
		if o["k"] == "rug":
			continue
		var ocx: float = (o["x"] + o["w"] / 2.0) * TS
		var ocy: float = (o["y"] + o["h"] / 2.0) * TS
		var rr: float = maxf(o["w"], o["h"]) * TS
		if o["k"] != "mast" and Vector2(ocx, ocy).distance_to(eye) > _sight + rr:
			continue
		var c := _cam(Vector3(ocx, ocy, 0))
		if c.x < -rr:
			continue
		_furn_boxes(o, raw)
	# barandillas de la azotea
	if f.sky:
		var r := mini(ceili(_sight / TS), 18)
		var ex := floori(eye.x / TS)
		var ey := floori(eye.y / TS)
		for ty in range(ey - r, ey + r + 1):
			for tx in range(ex - r, ex + r + 1):
				if f.at(tx, ty) == Cfg.T_RAIL:
					# pretil de ladrillo con albardilla de piedra y, encima, barandilla de hierro
					var ax := f.at(tx - 1, ty) == Cfg.T_RAIL or f.at(tx + 1, ty) == Cfg.T_RAIL
					var ay := f.at(tx, ty - 1) == Cfg.T_RAIL or f.at(tx, ty + 1) == Cfg.T_RAIL
					var bx0 := tx * TS
					var by0 := ty * TS
					if ax or not ay:
						_box(raw, bx0, by0 + 11, bx0 + TS, by0 + TS - 11, 0, 11, Color("#6a3b2c"), Color("#b9ae96"))
						_box(raw, bx0, by0 + 14.5, bx0 + TS, by0 + TS - 14.5, 18.5, 20, Color("#23262b"), Color("#3a3f46"))
					if ay:
						_box(raw, bx0 + 11, by0, bx0 + TS - 11, by0 + TS, 0, 11, Color("#6a3b2c"), Color("#b9ae96"))
						_box(raw, bx0 + 14.5, by0, bx0 + TS - 14.5, by0 + TS, 18.5, 20, Color("#23262b"), Color("#3a3f46"))
					if (tx + ty) % 2 == 0:
						_box(raw, bx0 + 14.8, by0 + 14.8, bx0 + TS - 14.8, by0 + TS - 14.8, 11, 18.5, Color("#23262b"), Color("#23262b"), {"notop": true})
	# lámparas del techo (arañas)
	if not f.sky:
		for l in f.lamps:
			raw.append({"kind": "lamp", "x": float(l["x"]), "y": float(l["y"]), "z": WALL_H - 7.0})
	# coches en la calle
	if f.fi == 1:
		for car in w.cars:
			var kx: float = car["x"]
			var ky: float = car["y"]
			var body := Color("#121216") if car["kind"] == "police" or car["kind"] == "hearse" else Color("#5a2a2a")
			_box(raw, kx - 34, ky - 13, kx + 34, ky + 13, 4, 17, body, body.lightened(0.1))
			_box(raw, kx - 16, ky - 11, kx + 14, ky + 11, 17, 29, Color("#1a2230"), body.lightened(0.05))
			if car["kind"] == "police":
				_box(raw, kx - 4, ky - 3, kx + 4, ky + 3, 29, 32, Color("#ff3030") if fmod(anim, 0.5) < 0.25 else Color("#3050ff"), Color("#ffffff"), {"emit": true})
	# objetos sueltos
	for p in w.picks:
		if p.fl != e.fl or p.box != "":
			continue
		var px: float = (p.x + 0.5) * TS
		var py: float = (p.y + 0.5) * TS
		var pc := Color("#d9b862") if p.kind == "cash" or p.kind == "money" else Color("#9aa3ab")
		_box(raw, px - 5, py - 4, px + 5, py + 4, 0, 4 + 1.5 * sin(anim * 4.0 + p.id), pc, pc.lightened(0.3), {"emit": true})
	# perros
	for pet in w.pets:
		if int(pet["fl"]) == e.fl:
			var qx: float = pet["x"]
			var qy: float = pet["y"]
			var qc := Color(str(pet["col"]))
			var dd: float = float(pet["dir"])
			var wk: float = sin(float(pet["walk"])) * 1.5
			var zo: float = 15.0 if int(pet["carried"]) != 0 else 0.0     # en brazos
			var dk := qc.darkened(0.25)
			# cuatro patas, cuerpo, cabeza, hocico, trufa, orejas y cola
			if zo == 0.0:
				for plx in [-5.0, 5.0]:
					for ply in [-2.0, 2.0]:
						var gx2: float = qx + float(plx)
						var gy2: float = qy + float(ply)
						_box(raw, gx2 - 1.0, gy2 - 1.0, gx2 + 1.0, gy2 + 1.0, 0, 5, dk, dk, {"notop": true})
			_box(raw, qx - 7, qy - 3, qx + 7, qy + 3, 5 + zo, 10.5 + zo, qc, qc.lightened(0.1))
			_box(raw, qx + dd * 6.0 - 2.6, qy - 2.6, qx + dd * 6.0 + 2.6, qy + 2.6, 9 + zo, 15 + zo, qc, qc.lightened(0.12))
			_box(raw, qx + dd * 9.6 - 2.0, qy - 1.5, qx + dd * 9.6 + 2.0, qy + 1.5, 9.5 + zo, 12 + zo, qc.lightened(0.2), qc.lightened(0.25))
			_box(raw, qx + dd * 11.4 - 0.7, qy - 0.8, qx + dd * 11.4 + 0.7, qy + 0.8, 10.6 + zo, 12.2 + zo, Color("#151515"), Color("#151515"))
			_box(raw, qx + dd * 5.0 - 1.0, qy - 2.9, qx + dd * 5.0 + 1.0, qy - 1.6, 15 + zo, 17.6 + zo, dk, dk)
			_box(raw, qx + dd * 5.0 - 1.0, qy + 1.6, qx + dd * 5.0 + 1.0, qy + 2.9, 15 + zo, 17.6 + zo, dk, dk)
			_box(raw, qx - dd * 8.5 - 0.9, qy - 0.8, qx - dd * 8.5 + 0.9, qy + 0.8, 9 + zo, 14 + zo + wk, dk, dk, {"notop": true})
	for b in raw:
		var pb: Dictionary = _project_box(b)
		if not pb.is_empty():
			boxes.append(pb)
	boxes.sort_custom(func(a, b): return float(a["d"]) > float(b["d"]))

## Proyecta una caja (o cilindro, bola, lámpara) y guarda sus polígonos, profundidad y recuadro en pantalla.
func _project_box(b: Dictionary) -> Dictionary:
	var kind: String = b.get("kind", "box")
	var polys: Array = []
	var d := 0.0
	if kind == "cyl" or kind == "ball" or kind == "lamp":
		var bx: float = b["x"]
		var by: float = b["y"]
		var cc := _cam(Vector3(bx, by, 0))
		if cc.x < NEAR + 4:
			return {}
		d = cc.x
		var dist := Vector2(bx, by).distance_to(eye)
		var m := _mult(bx, by, dist)
		var sc := proj / cc.x
		var sx := cx + cc.y * sc
		if kind == "cyl":
			var r: float = b["r"]
			var col: Color = b["col"]
			var y0 := _zy(WALL_H, cc.x)
			var y1 := _zy(0, cc.x)
			var hw := r * sc
			polys.append(["rect", Rect2(sx - hw, y0, hw * 2, y1 - y0), _lit(col.darkened(0.25), m)])
			polys.append(["rect", Rect2(sx - hw * 0.7, y0, hw * 1.2, y1 - y0), _lit(col, m)])
			polys.append(["rect", Rect2(sx - hw * 0.35, y0, hw * 0.45, y1 - y0), _lit(col.lightened(0.15), m)])
			polys.append(["rect", Rect2(sx - hw * 1.15, y0, hw * 2.3, (y1 - y0) * 0.06), _lit(Painter.GOLD2, m)])
			polys.append(["rect", Rect2(sx - hw * 1.15, y1 - (y1 - y0) * 0.05, hw * 2.3, (y1 - y0) * 0.05), _lit(Painter.GOLD2.darkened(0.3), m)])
			return {"polys": polys, "d": d, "bb": Rect2(sx - hw * 1.2, y0, hw * 2.4, y1 - y0), "fp": Rect2(bx - r, by - r, r * 2, r * 2)}
		var z: float = b["z"]
		var cy := _zy(z, cc.x)
		if kind == "ball":
			var rr: float = b["r"] * sc
			var col2: Color = b["col"]
			polys.append(["circle", Vector2(sx, cy), rr, _lit(col2, m)])
			polys.append(["circle", Vector2(sx - rr * 0.3, cy - rr * 0.3), rr * 0.55, _lit(col2.lightened(0.15), m)])
			var br: float = b["r"]
			return {"polys": polys, "d": d, "bb": Rect2(sx - rr, cy - rr, rr * 2, rr * 2), "fp": Rect2(bx - br, by - br, br * 2, br * 2)}
		# araña de luces: anillo de latón con bombillas encendidas
		var rl := 9.0 * sc
		var brass := _lit(Color("#b8923f"), m)
		polys.append(["rect", Rect2(sx - 0.6 * sc, _zy(WALL_H, cc.x), 1.2 * sc, cy - _zy(WALL_H, cc.x)), brass])
		polys.append(["ellipse", Vector2(sx, cy), rl, rl * 0.3, brass])
		var bulb := Color("#3a3226") if _blackout else Color("#fff0c0")
		if not _blackout:
			polys.append(["circle", Vector2(sx, cy), rl * 1.8, Color(1, 0.85, 0.5, 0.12 * _fog(dist))])
		for i in 5:
			var a := TAU * i / 5.0 + 0.3
			polys.append(["circle", Vector2(sx + cos(a) * rl, cy + sin(a) * rl * 0.3 - 1.5 * sc), 1.6 * sc, bulb * (0.5 + 0.5 * _fog(dist))])
		return {"polys": polys, "d": d, "bb": Rect2(sx - rl * 1.8, _zy(WALL_H, cc.x), rl * 3.6, cy - _zy(WALL_H, cc.x) + rl)}
	var x0: float = b["x0"]
	var y0b: float = b["y0"]
	var x1: float = b["x1"]
	var y1b: float = b["y1"]
	var z0: float = b["z0"]
	var z1: float = b["z1"]
	var ccx := (x0 + x1) / 2.0
	var ccy := (y0b + y1b) / 2.0
	var cen := _cam(Vector3(ccx, ccy, 0))
	if cen.x < -maxf(x1 - x0, y1b - y0b):
		return {}
	d = maxf(cen.x, NEAR)
	var dist2 := Vector2(ccx, ccy).distance_to(eye)
	var emit: bool = b.get("emit", false)
	var m2 := Color(1, 1, 1) if emit else _mult(ccx, ccy, dist2)
	if emit:
		var kf := 0.5 + 0.5 * _fog(dist2)
		m2 = Color(kf, kf, kf)
	var col3: Color = b["col"]
	var topc: Color = b["top"]
	var faces: Array = []
	if eye.y > y1b:
		faces.append([[Vector3(x0, y1b, z0), Vector3(x1, y1b, z0), Vector3(x1, y1b, z1), Vector3(x0, y1b, z1)], 0.9])
	if eye.y < y0b:
		faces.append([[Vector3(x0, y0b, z0), Vector3(x1, y0b, z0), Vector3(x1, y0b, z1), Vector3(x0, y0b, z1)], 0.9])
	if eye.x < x0:
		faces.append([[Vector3(x0, y0b, z0), Vector3(x0, y1b, z0), Vector3(x0, y1b, z1), Vector3(x0, y0b, z1)], 0.72])
	if eye.x > x1:
		faces.append([[Vector3(x1, y0b, z0), Vector3(x1, y1b, z0), Vector3(x1, y1b, z1), Vector3(x1, y0b, z1)], 0.72])
	var bb := Rect2()
	var has := false
	for fc in faces:
		var p := _poly3(fc[0])
		if p.size() < 3:
			continue
		var sh: float = fc[1]
		polys.append(["poly", p, _lit(Color(col3.r * sh, col3.g * sh, col3.b * sh, 1.0), m2)])
		var r2 := _bounds(p)
		bb = r2 if not has else bb.merge(r2)
		has = true
	if EYE > z1 and not b.get("notop", false):
		var tp := _poly3([Vector3(x0, y0b, z1), Vector3(x1, y0b, z1), Vector3(x1, y1b, z1), Vector3(x0, y1b, z1)])
		if tp.size() >= 3:
			var tm := Color(1, 1, 1) if b.get("emit_top", false) else m2
			polys.append(["poly", tp, _lit(topc, tm)])
			var r3 := _bounds(tp)
			bb = r3 if not has else bb.merge(r3)
			has = true
	if not has:
		return {}
	if bb.end.x < -PAD or bb.position.x > vs.x + PAD:
		return {}
	var out := {"polys": polys, "d": d, "bb": bb, "fp": Rect2(x0, y0b, x1 - x0, y1b - y0b)}
	if b.has("text"):
		var tcen := _cam(Vector3(ccx, ccy, (z0 + z1) / 2.0))
		if tcen.x > NEAR + 4:
			out["text"] = [b["text"], _scr(tcen), proj / tcen.x]
	return out

static func _bounds(p: PackedVector2Array) -> Rect2:
	var r := Rect2(p[0], Vector2.ZERO)
	for v in p:
		r = r.expand(v)
	return r

func _draw_box(ci: CanvasItem, b: Dictionary) -> void:
	for pp in b["polys"]:
		match String(pp[0]):
			"poly":
				_fill(ci, pp[1], pp[2])
			"rect":
				ci.draw_rect(pp[1], pp[2])
			"circle":
				ci.draw_circle(pp[1], pp[2], pp[3])
			"ellipse":
				var c: Vector2 = pp[1]
				Painter.ellipse(ci, c.x, c.y, pp[2], pp[3], pp[4], 14)
	if b.has("text"):
		var t: Array = b["text"]
		var fs := clampi(roundi(float(t[2]) * 13.0), 6, 160)
		var p: Vector2 = t[1]
		Painter.text(ci, p.x, p.y + fs * 0.35, String(t[0]), fs, Color("#ffe8c0"), 0)

## Columnas de muro más cercanas que d dentro de un recuadro de pantalla (para tapar lo que hay detrás).
func _redraw_cols(ci: CanvasItem, bb: Rect2, d: float) -> void:
	var c0 := clampi(floori((bb.position.x - _x0) / colw), 0, ncols - 1)
	var c1 := clampi(ceili((bb.end.x - _x0) / colw), 0, ncols - 1)
	for c in range(c0, c1 + 1):
		if (_wk[c] == 1 or _wk[c] == 3 or _wk[c] == 4) and _wd[c] < d:
			_draw_col(ci, c)
		if _dd[c] > 0.0 and _dd[c] < d:
			_draw_lintel(ci, c)

# ---------------------------------------------------------------- personajes

func _face_vec(dir: String) -> Vector2:
	match dir:
		"up": return Vector2(0, -1)
		"left": return Vector2(-1, 0)
		"right": return Vector2(1, 0)
	return Vector2(0, 1)

func _build_sprites(f: FloorData) -> void:
	sprites.clear()
	for o in w.ents:
		if o == e or not o.alive or o.fl != e.fl or o.escaped or o.away_t > 0 or o.hidden:
			continue
		var p := Vector2(o.x, o.y)
		var dist := p.distance_to(eye)
		if dist > _sight + 10 or dist < 4:
			continue
		var c := _cam(Vector3(o.x, o.y, 0))
		if c.x < 6.0:
			continue
		if not Nav.los(f, eye.x, eye.y, o.x, o.y):
			continue
		var sc := proj / c.x
		var sx := cx + c.y * sc
		var hw: float = 12.0 * sc * o.outfit.build
		if sx + hw < -PAD or sx - hw > vs.x + PAD:
			continue
		var tv := (eye - p).normalized()
		var fv := _face_vec(o.dir)
		var dt := fv.dot(tv)
		var dir := "down"
		if dt < -0.7:
			dir = "up"
		elif dt <= 0.7:
			dir = "right" if fv.dot(rt) > 0 else "left"
		var feet := horizon + EYE * sc
		var m := _mult(o.x, o.y, dist)
		sprites.append({"e": o, "sx": sx, "feet": feet, "sc": sc, "d": c.x, "dir": dir, "mod": Color(minf(m.r, 1.3), minf(m.g, 1.3), minf(m.b, 1.3), 1.0),
			"bb": Rect2(sx - hw, feet - 40.0 * sc, hw * 2.0, 40.0 * sc), "dist": dist})
	sprites.sort_custom(func(a, b): return float(a["d"]) > float(b["d"]))

func _sync_actors() -> void:
	while _pool.size() < sprites.size():
		var n := ActorNode.new()
		actors.add_child(n)
		_pool.append(n)
	for i in _pool.size():
		var n: ActorNode = _pool[i]
		if i < sprites.size():
			var s: Dictionary = sprites[i]
			n.visible = true
			n.ent = s["e"]
			n.dir = s["dir"]
			n.sx = s["sx"]
			n.feet = s["feet"]
			n.sc = s["sc"]
			n.modulate = s["mod"]
			n.queue_redraw()
		else:
			n.visible = false
			n.ent = null

func _pick_target() -> void:
	target = null
	var mid := int(ncols / 2.0)
	center_d = _wd[mid] if mid < ncols and (_wk[mid] == 1 or _wk[mid] == 3 or _wk[mid] == 4) else 600.0
	var ch := vs / 2.0
	var best := INF
	for s in sprites:
		var bb: Rect2 = s["bb"]
		var o: Ent = s["e"]
		if bb.grow(2.0).has_point(ch) and float(s["d"]) < best:
			best = s["d"]
			target = o
			target_d = s["dist"]

# ---------------------------------------------------------------- dibujo

func _draw_walls() -> void:
	if w == null or e == null:
		return
	var ci := walls
	for dcl in decals:
		var p: PackedVector2Array = dcl[0]
		if dcl[2]:
			if p.size() >= 2:
				var closed := p.duplicate()
				closed.append(p[0])
				ci.draw_polyline(closed, dcl[1], 1.6)
		else:
			_fill(ci, p, dcl[1])
	for c in ncols:
		_draw_col(ci, c)
	for c in ncols:
		_draw_lintel(ci, c)
	for b in boxes:
		_draw_box(ci, b)
		_redraw_cols(ci, b["bb"], b["d"])

## Lo que tapa a los personajes: muros y muebles que están más cerca que ellos.
func _draw_occl() -> void:
	if w == null or e == null:
		return
	var ci := occl
	for s in sprites:
		var bb: Rect2 = s["bb"]
		var sd: float = s["d"]
		_redraw_cols(ci, bb, sd)
		var o: Ent = s["e"]
		for b in boxes:
			# un mueble tapa a alguien solo si está entre tus ojos y él
			if not b.has("fp") or not (b["bb"] as Rect2).intersects(bb):
				continue
			if _seg_hits(eye, Vector2(o.x, o.y), b["fp"]):
				_draw_box(ci, b)
				_redraw_cols(ci, b["bb"], b["d"])

## ¿Cruza el segmento a-b el rectángulo r? (Liang-Barsky)
static func _seg_hits(a: Vector2, b: Vector2, r: Rect2) -> bool:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	var p := [-d.x, d.x, -d.y, d.y]
	var q := [a.x - r.position.x, r.end.x - a.x, a.y - r.position.y, r.end.y - a.y]
	for i in 4:
		var pi_: float = p[i]
		var qi: float = q[i]
		if absf(pi_) < 1e-6:
			if qi < 0.0:
				return false
		else:
			var t := qi / pi_
			if pi_ < 0.0:
				t0 = maxf(t0, t)
			else:
				t1 = minf(t1, t)
			if t0 > t1:
				return false
	return t1 > 0.0 and t0 < 0.98

func _draw_over() -> void:
	if w == null or e == null:
		return
	var ci := over
	# balas de la policía, trazadoras y fogonazos de otros
	for b in w.bullets:
		if int(b["fl"]) != e.fl:
			continue
		var a := _cam(Vector3(b["x"], b["y"], 22))
		var bv := Vector2(b["vx"], b["vy"]).normalized()
		var b2 := _cam(Vector3(float(b["x"]) - bv.x * 18.0, float(b["y"]) - bv.y * 18.0, 22))
		if a.x > NEAR and b2.x > NEAR:
			ci.draw_line(_scr(a), _scr(b2), Color(1, 0.9, 0.55, 0.95), clampf(proj / a.x * 1.4, 1.0, 5.0))
	for fx in w.fx:
		if fx["fl"] != e.fl:
			continue
		match String(fx["type"]):
			"tracer":
				var t0 := _cam(Vector3(fx["x"], fx["y"], 22))
				var t1 := _cam(Vector3(fx["x2"], fx["y2"], 20))
				if t0.x > NEAR and t1.x > NEAR:
					ci.draw_line(_scr(t0), _scr(t1), Color(1, 0.88, 0.55, clampf(float(fx["t"]) * 6.0, 0, 0.8)), 1.5)
			"flash":
				var fc := _cam(Vector3(fx["x"], fx["y"], 24))
				if fc.x > 12.0:
					var big: bool = fx.get("big", false)
					var r := (14.0 if big else 6.0) * proj / fc.x
					ci.draw_circle(_scr(fc), r * 2.2, Color(1, 0.8, 0.4, 0.25))
					ci.draw_circle(_scr(fc), r, Color(1, 0.95, 0.7, 0.9))
			"blood":
				var bc := _cam(Vector3(fx["x"], fx["y"], 20))
				if bc.x > NEAR:
					var k := proj / bc.x
					for j in 6:
						var a3 := j * 1.05
						ci.draw_circle(_scr(bc) + Vector2(cos(a3), sin(a3)) * (10.0 * (1.0 - float(fx["t"]) / 0.6) + 3.0) * k, 2.4 * k, Color(0.6, 0.04, 0.08, 0.85))
	# nombres de los tuyos y bocadillos
	for s in sprites:
		var o: Ent = s["e"]
		var sc: float = s["sc"]
		var top: float = float(s["feet"]) - 40.0 * sc
		if o.role == w.role and (o.role == "runner" or o.role == "hunter"):
			Painter.text(ci, s["sx"], top - 4, o.nm, 13, Painter.BLUE if o.role == "runner" else Color("#ff9a9a"))
		if o.bubble != "" and float(s["dist"]) < 260.0:
			Painter.text(ci, s["sx"], top - 20, o.bubble, 14, Color("#f3efe2"))
		if o.role == "police" and o.spotting:
			Painter.text(ci, s["sx"], top - 8, "!", clampi(roundi(sc * 18.0), 12, 48), Color("#ff4a4a"))
	ci.draw_texture_rect(gun.get_texture(), Rect2(Vector2.ZERO, vs), false)
	for p in parts:
		var pp: Vector2 = p["p"]
		var k2: float = 1.0 - float(p["t"]) / float(p["t0"])
		if p["k"] == "smoke":
			var r2: float = (float(p["r"]) + k2 * 22.0) * vs.y / 720.0
			ci.draw_circle(pp, r2, Color(0.78, 0.78, 0.78, 0.22 * (1.0 - k2)))
		else:
			var s2 := vs.y / 720.0
			ci.draw_set_transform(pp, float(p["r"]), Vector2(s2, s2))
			ci.draw_rect(Rect2(-2.5, -6, 5, 12), Color("#d9b862"))
			ci.draw_rect(Rect2(-2.5, -6, 5, 2.5), Color("#8a6a2a"))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------------------------------------------------------------- mano y pistola (modelo 3D)

## Balanceo del arma al andar y al respirar, en píxeles.
func _sway() -> Vector2:
	if e != null and e.moving:
		return Vector2(cos(e.walk * 0.5) * 9.0, absf(sin(e.walk * 0.5)) * 11.0) + Vector2(lag, 0)
	return Vector2(lag, sin(anim * 1.6) * 3.0)

func _muzzle_screen() -> Vector2:
	return gun.muzzle_screen()

# ---------------------------------------------------------------- interfaz: mira, munición, viñeta

func _vignette(ci: CanvasItem, col: Color, inset: float) -> void:
	var a := Vector2.ZERO
	var b := vs
	var i := Vector2(vs.x * inset, vs.y * inset)
	var clear := Color(col.r, col.g, col.b, 0.0)
	var quads := [
		[a, Vector2(b.x, 0), Vector2(b.x, 0) + Vector2(-i.x, i.y), a + i],
		[Vector2(b.x, 0), b, b - i, Vector2(b.x, 0) + Vector2(-i.x, i.y)],
		[b, Vector2(0, b.y), Vector2(0, b.y) + Vector2(i.x, -i.y), b - i],
		[Vector2(0, b.y), a, a + i, Vector2(0, b.y) + Vector2(i.x, -i.y)],
	]
	for q in quads:
		ci.draw_polygon(PackedVector2Array(q), PackedColorArray([col, col, clear, clear]))

func _draw_ui() -> void:
	if w == null or e == null:
		return
	var ci := ui
	_vignette(ci, Color(0, 0, 0, 0.75 if _blackout else 0.5), 0.2)
	if hurt_t > 0:
		_vignette(ci, Color(0.7, 0.02, 0.04, 0.6 * hurt_t / 0.6), 0.25)
	if flash_t > 0:
		ci.draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 0.85, 0.5, flash_t * 0.8))
	# mira
	var c := vs / 2.0
	var in_range := target != null and target_d <= Cfg.KILL_RANGE * Cfg.TS
	var col := Color(0.94, 0.92, 0.86, 0.9)
	if e.ammo <= 0:
		col = Color(0.6, 0.6, 0.6, 0.7)
	elif in_range:
		col = Color(1.0, 0.36, 0.3, 0.95)
	var gap := 6.0 + recoil * 10.0
	for v in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		ci.draw_line(c + v * gap, c + v * (gap + 9.0), Color(0, 0, 0, 0.6), 3.5)
		ci.draw_line(c + v * gap, c + v * (gap + 9.0), col, 1.6)
	ci.draw_circle(c, 1.6, col)
	if hit_t > 0:
		var hc := Color(1, 1, 1, hit_t / 0.45)
		for v in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			ci.draw_line(c + v * 7.0, c + v * 15.0, hc, 2.2)
	if target != null:
		var txt := "EN ALCANCE" if in_range else "FUERA DE ALCANCE"
		Painter.text(ci, c.x, c.y + 40, txt, 12, col)
	if e.ammo <= 0:
		Painter.text(ci, c.x, c.y + 58, "SIN BALAS", 13, Painter.RED)
	# balas restantes
	var s := vs.y / 720.0
	var base := Vector2(vs.x - 36 * s, vs.y - 120 * s)
	for i in mini(e.ammo, 12):
		var p := base - Vector2(i * 11.0 * s, 0)
		ci.draw_rect(Rect2(p.x - 3 * s, p.y - 8 * s, 6 * s, 14 * s), Color("#d9b862"))
		ci.draw_rect(Rect2(p.x - 3 * s, p.y - 12 * s, 6 * s, 5 * s), Color("#b07a3a"))
	# ayuda de controles los primeros segundos
	if help_t < 5.0:
		var a := clampf(5.0 - help_t, 0.0, 1.0)
		Painter.text(ci, c.x, vs.y - 30, "Ratón: mirar   ·   Clic: disparar   ·   Q / E: asomarse   ·   Suelta el clic derecho para salir", 14, Color(0.92, 0.82, 0.54, a))
	if absf(lean) > 0.3:
		Painter.text(ci, c.x, 34, "<  ASOMADO" if lean < 0 else "ASOMADO  >", 12, Color(0.92, 0.82, 0.54, 0.8))

## Una figura (cada personaje visible es un nodo para poder oscurecerlo con la distancia).
class ActorNode extends Node2D:
	var ent: Ent = null
	var dir := "down"
	var sx := 0.0
	var feet := 0.0
	var sc := 1.0

	func _draw() -> void:
		if ent == null:
			return
		Painter.draw_actor(self, sx, feet - 11.0, ent.outfit, dir, ent.walk, false, 0.0, sc)
		if ent.ko_t > 0:
			for i in 3:
				var a := Time.get_ticks_msec() / 250.0 + i * TAU / 3.0
				draw_circle(Vector2(sx + cos(a) * 8.0 * sc, feet - 40.0 * sc + sin(a) * 3.0 * sc), 1.8 * sc, Color("#ffe066"))
