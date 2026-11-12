## La torre del hotel en 3D para el menú principal: bloques escalonados art déco con pilastras,
## cornisas, almenas, ventanas encendidas, corona iluminada, depósitos de agua, marquesina y focos.
class_name TowerView
extends SubViewportContainer

var vp: SubViewport
var pivot: Node3D
var beams: Array = []
var blink: OmniLight3D
var t := 0.0

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp = SubViewport.new()
	vp.size = Vector2i(560, 760)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.32, 0.38, 0.55)
	e.ambient_light_energy = 0.55
	e.fog_enabled = true
	e.fog_light_color = Color(0.05, 0.07, 0.12)
	e.fog_density = 0.008
	env.environment = e
	world.add_child(env)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 19, 74)
	cam.fov = 42
	world.add_child(cam)
	cam.look_at(Vector3(0, 23.5, 0))
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.65, 0.72, 1.0)
	moon.light_energy = 0.55
	moon.rotation_degrees = Vector3(-35, 40, 0)
	world.add_child(moon)
	var street := OmniLight3D.new()
	street.light_color = Color(1.0, 0.75, 0.45)
	street.light_energy = 2.2
	street.omni_range = 26
	street.position = Vector3(0, -2, 12)
	world.add_child(street)
	pivot = Node3D.new()
	world.add_child(pivot)
	_build_tower()
	# focos que barren el cielo
	for i in 2:
		var sp := SpotLight3D.new()
		sp.light_color = Color(1.0, 0.95, 0.8)
		sp.light_energy = 6.0
		sp.spot_range = 80
		sp.spot_angle = 6
		sp.position = Vector3(-14 + i * 28, 0, 6)
		world.add_child(sp)
		beams.append(sp)

func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = pos
	pivot.add_child(m)
	return m

## Textura de fachada: ladrillo con ventanas de guillotina (alféizar claro), unas encendidas en cálido,
## otras en frío y otras apagadas.
func _facade() -> StandardMaterial3D:
	var img := Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	var em := Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color("#4a3b2c"))
	em.fill(Color(0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1930
	for y in 128:
		if y % 4 == 0:
			for x in 128:
				img.set_pixel(x, y, Color("#3e3125"))
	for gy in 8:
		for gx in 8:
			var r := rng.randf()
			var col := Color("#18202c")
			var lit := false
			if r < 0.38:
				col = Color(1.0, 0.8, 0.45)
				lit = true
			elif r < 0.48:
				col = Color(0.7, 0.8, 1.0)
				lit = true
			var x0 := gx * 16 + 4
			var y0 := gy * 16 + 3
			for y in range(y0, y0 + 10):
				for x in range(x0, x0 + 8):
					var c := col
					if y == y0 + 5 or x == x0 + 4:
						c = Color("#2a2420")     # travesaño y parteluz
					elif lit and y < y0 + 3 and rng.randf() < 0.6:
						c = col.darkened(0.45)   # cortina
					img.set_pixel(x, y, c)
					if lit and c == col:
						em.set_pixel(x, y, col)
			for x in range(x0 - 1, x0 + 9):
				img.set_pixel(x, y0 + 10, Color("#9a8a70"))   # alféizar
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.emission_enabled = true
	mat.emission_texture = ImageTexture.create_from_image(em)
	mat.emission_energy_multiplier = 1.5
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.3, 0.3, 0.3)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.roughness = 0.9
	return mat

func _plain(c: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m

func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

func _cyl(r0: float, r1: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r0
	c.bottom_radius = r1
	c.height = h
	c.radial_segments = 16
	m.mesh = c
	m.material_override = mat
	m.position = pos
	pivot.add_child(m)
	return m

## Un bloque del rascacielos con pilastras verticales, cornisa de piedra y almenas art déco.
func _block(w: float, h: float, d: float, cx: float, y: float, cz: float, facade: Material, brick: Material, stone: Material, trim: Material) -> void:
	_box(Vector3(w, h, d), Vector3(cx, y + h / 2.0, cz), facade)
	var nf := maxi(2, int(w / 1.15))
	for i in nf + 1:
		var x := cx - w / 2.0 + w * i / nf
		_box(Vector3(0.26, h, 0.22), Vector3(x, y + h / 2.0, cz + d / 2.0 + 0.08), brick)
	var ns := maxi(2, int(d / 1.15))
	for i in ns + 1:
		var z := cz - d / 2.0 + d * i / ns
		_box(Vector3(0.22, h, 0.26), Vector3(cx - w / 2.0 - 0.08, y + h / 2.0, z), brick)
		_box(Vector3(0.22, h, 0.26), Vector3(cx + w / 2.0 + 0.08, y + h / 2.0, z), brick)
	# cornisa y almenas escalonadas
	_box(Vector3(w + 0.45, 0.3, d + 0.45), Vector3(cx, y + h + 0.15, cz), stone)
	_box(Vector3(w + 0.5, 0.06, d + 0.5), Vector3(cx, y + h + 0.32, cz), trim)
	for i in nf:
		var x2 := cx - w / 2.0 + w * (i + 0.5) / nf
		_box(Vector3(0.45, 0.5, 0.25), Vector3(x2, y + h + 0.55, cz + d / 2.0 + 0.05), stone)
		_box(Vector3(0.25, 0.3, 0.2), Vector3(x2, y + h + 0.95, cz + d / 2.0 + 0.05), stone)
	# franja de piedra a media altura en los bloques altos
	if h > 6.0:
		_box(Vector3(w + 0.3, 0.2, d + 0.3), Vector3(cx, y + h * 0.5, cz), stone)

func _build_tower() -> void:
	var facade := _facade()
	var brick := _plain(Color("#5c4836"), 0.85)
	var stone := _plain(Color("#b4a487"), 0.6)
	var stone_dk := _plain(Color("#6e6352"), 0.7)
	var trim := _plain(Color("#c9a24b"), 0.35, 0.6)
	var dark := _plain(Color("#20242c"), 0.6)
	var shop := _glow(Color(1.0, 0.78, 0.45), 1.6)
	var bulb := _glow(Color(1.0, 0.92, 0.7), 3.0)
	# podio de piedra con escaparates iluminados y la marquesina de la entrada
	_box(Vector3(30, 3.2, 14), Vector3(0, 1.6, 0.5), stone_dk)
	_box(Vector3(30.3, 0.25, 14.3), Vector3(0, 3.3, 0.5), stone)
	for i in 9:
		_box(Vector3(2.4, 1.5, 0.08), Vector3(-12.0 + i * 3.0, 1.25, 7.52), shop)
	_box(Vector3(8, 0.35, 2.4), Vector3(0, 2.7, 8.7), dark)
	_box(Vector3(8.2, 0.12, 2.5), Vector3(0, 2.92, 8.7), trim)
	for i in 13:
		var b := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.08
		sp.height = 0.16
		b.mesh = sp
		b.material_override = bulb
		b.position = Vector3(-3.9 + i * 0.65, 2.5, 9.95)
		pivot.add_child(b)
	var door_light := OmniLight3D.new()
	door_light.light_color = Color(1.0, 0.8, 0.5)
	door_light.light_energy = 2.0
	door_light.omni_range = 7
	door_light.position = Vector3(0, 2.0, 10.5)
	pivot.add_child(door_light)
	# escalonamientos del rascacielos (de abajo arriba)
	var levels := [[14.0, 9.0, 11.0], [12.0, 7.0, 9.5], [10.0, 6.0, 8.0], [8.2, 5.0, 6.6], [6.4, 4.0, 5.2], [4.8, 3.0, 4.0], [3.4, 2.4, 2.8]]
	var y := 3.45
	for lv in levels:
		var w: float = lv[0]
		var h: float = lv[1]
		var d: float = lv[2]
		_block(w, h, d, 0.0, y, 0.0, facade, brick, stone, trim)
		y += h + 0.3
	# alas laterales más bajas, con depósitos de agua de madera en la azotea (típicos de Nueva York)
	for sx in [-1.0, 1.0]:
		_block(6.0, 14.0, 9.0, sx * 10.0, 3.45, -1.0, facade, brick, stone, trim)
		var tank_wood := _plain(Color("#5a3a22"), 0.9)
		_cyl(0.85, 0.85, 1.5, Vector3(sx * 10.0 + 1.2, 3.45 + 14.3 + 1.6, -2.0), tank_wood)
		_cyl(0.0, 0.95, 0.6, Vector3(sx * 10.0 + 1.2, 3.45 + 14.3 + 2.65, -2.0), dark)
		for k in 4:
			var a := TAU * k / 4.0 + 0.4
			_box(Vector3(0.08, 0.9, 0.08), Vector3(sx * 10.0 + 1.2 + cos(a) * 0.6, 3.45 + 14.3 + 0.45, -2.0 + sin(a) * 0.6), dark)
	# corona: aletas en las esquinas, linterna iluminada y remate escalonado
	var top := y
	var lantern := _glow(Color(1.0, 0.86, 0.55), 1.2)
	for k in 4:
		var fx := -1.5 if k % 2 == 0 else 1.5
		var fz := -1.2 if k < 2 else 1.2
		_box(Vector3(0.22, 3.2, 0.22), Vector3(fx, top + 1.6, fz), stone)
		_box(Vector3(0.12, 0.6, 0.12), Vector3(fx, top + 3.5, fz), trim)
	_box(Vector3(2.2, 2.2, 1.8), Vector3(0, top + 1.1, 0), lantern)
	for i in 5:
		_box(Vector3(0.12, 2.2, 0.12), Vector3(-0.9 + i * 0.45, top + 1.1, 0.92), stone)
	_box(Vector3(2.8, 0.3, 2.4), Vector3(0, top + 2.35, 0), stone)
	_box(Vector3(2.0, 0.5, 1.7), Vector3(0, top + 2.75, 0), stone)
	_box(Vector3(1.2, 0.5, 1.0), Vector3(0, top + 3.25, 0), stone)
	_box(Vector3(1.3, 0.06, 1.1), Vector3(0, top + 3.02, 0), trim)
	# focos que iluminan la corona desde abajo
	for sx2 in [-1.0, 1.0]:
		var up := SpotLight3D.new()
		up.light_color = Color(1.0, 0.85, 0.6)
		up.light_energy = 5.0
		up.spot_range = 14
		up.spot_angle = 28
		up.position = Vector3(sx2 * 3.0, top - 4.0, 4.0)
		pivot.add_child(up)
		up.look_at_from_position(up.position, Vector3(0, top + 1.5, 0), Vector3.UP)
	# antena con luz roja
	var ant := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.16
	cyl.height = 4.5
	ant.mesh = cyl
	ant.material_override = dark
	ant.position = Vector3(0, top + 3.5 + 2.25, 0)
	pivot.add_child(ant)
	blink = OmniLight3D.new()
	blink.light_color = Color(1, 0.1, 0.1)
	blink.omni_range = 4
	blink.position = Vector3(0, top + 8.1, 0)
	pivot.add_child(blink)
	var bl := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.2
	sph.height = 0.4
	bl.mesh = sph
	bl.material_override = _glow(Color(1, 0.15, 0.1), 3.0)
	bl.position = blink.position
	pivot.add_child(bl)
	# suelo: la calle mojada
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#0d1016")
	gm.metallic = 0.4
	gm.roughness = 0.3
	ground.material_override = gm
	ground.position = Vector3(0, -0.01, 0)
	pivot.add_child(ground)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	t += delta
	pivot.rotation.y = sin(t * 0.15) * 0.45 - 0.25
	for i in beams.size():
		var sp: SpotLight3D = beams[i]
		sp.rotation = Vector3(deg_to_rad(70 + sin(t * 0.4 + i) * 12), sin(t * 0.3 + i * 2.0) * 0.6, 0)
	blink.light_energy = 2.5 if fmod(t, 1.6) < 0.5 else 0.2
