## La torre del Hotel New Yorker en 3D para el menú principal: bloques escalonados art déco con
## ventanas encendidas, el letrero rojo NEW YORKER, antena con luz y focos que barren el cielo.
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
	cam.position = Vector3(0, 14, 58)
	cam.fov = 42
	world.add_child(cam)
	cam.look_at(Vector3(0, 19, 0))
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

## Textura de fachada: ladrillo oscuro con ventanas, unas encendidas y otras no.
func _facade() -> StandardMaterial3D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var em := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color("#3a3226"))
	em.fill(Color(0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1930
	for gy in 8:
		for gx in 8:
			var lit := rng.randf() < 0.45
			var col := Color(1.0, 0.82, 0.48) if lit else Color("#1b2433")
			for y in range(gy * 8 + 2, gy * 8 + 7):
				for x in range(gx * 8 + 2, gx * 8 + 6):
					img.set_pixel(x, y, col)
					if lit:
						em.set_pixel(x, y, col)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.emission_enabled = true
	mat.emission_texture = ImageTexture.create_from_image(em)
	mat.emission_energy_multiplier = 1.6
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.35, 0.35, 0.35)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.9
	return mat

func _build_tower() -> void:
	var facade := _facade()
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color("#c9a24b")
	trim.metallic = 0.6
	trim.roughness = 0.35
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("#20242c")
	# escalonamientos del rascacielos (de abajo arriba)
	var levels := [[14.0, 9.0, 11.0], [12.0, 7.0, 9.5], [10.0, 6.0, 8.0], [8.2, 5.0, 6.6], [6.4, 4.0, 5.2], [4.8, 3.0, 4.0], [3.4, 2.4, 2.8]]
	var y := 0.0
	for lv in levels:
		var w: float = lv[0]
		var h: float = lv[1]
		var d: float = lv[2]
		_box(Vector3(w, h, d), Vector3(0, y + h / 2.0, 0), facade)
		_box(Vector3(w + 0.3, 0.25, d + 0.3), Vector3(0, y + h, 0), trim)
		y += h
	# alas laterales más bajas
	_box(Vector3(6, 14, 9), Vector3(-10, 7, -1), facade)
	_box(Vector3(6, 14, 9), Vector3(10, 7, -1), facade)
	_box(Vector3(6.3, 0.25, 9.3), Vector3(-10, 14, -1), trim)
	_box(Vector3(6.3, 0.25, 9.3), Vector3(10, 14, -1), trim)
	# letrero NEW YORKER sobre la azotea, con su estructura
	var sign_y := 9.0 + 7.0 + 6.0 + 5.0
	_box(Vector3(9.5, 0.2, 0.2), Vector3(0, sign_y + 0.6, 3.5), dark)
	for i in 5:
		_box(Vector3(0.12, 2.6, 0.12), Vector3(-4.4 + i * 2.2, sign_y + 1.3, 3.5), dark)
	var lbl := Label3D.new()
	lbl.text = "NEW YORKER"
	lbl.font = Painter.deco_font()
	lbl.font_size = 140
	lbl.pixel_size = 0.012
	lbl.modulate = Color(1.0, 0.25, 0.2)
	lbl.outline_modulate = Color(0.5, 0.0, 0.0, 0.8)
	lbl.outline_size = 18
	lbl.shaded = false
	lbl.double_sided = false
	lbl.position = Vector3(0, sign_y + 1.6, 3.65)
	pivot.add_child(lbl)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.2, 0.15)
	glow.light_energy = 3.0
	glow.omni_range = 9
	glow.position = Vector3(0, sign_y + 1.5, 6)
	pivot.add_child(glow)
	# antena con luz roja
	var top := y
	var ant := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.18
	cyl.height = 5.0
	ant.mesh = cyl
	ant.material_override = dark
	ant.position = Vector3(0, top + 2.5, 0)
	pivot.add_child(ant)
	blink = OmniLight3D.new()
	blink.light_color = Color(1, 0.1, 0.1)
	blink.omni_range = 4
	blink.position = Vector3(0, top + 5.1, 0)
	pivot.add_child(blink)
	var bulb := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.2
	sph.height = 0.4
	bulb.mesh = sph
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(1, 0.2, 0.2)
	bm.emission_enabled = true
	bm.emission = Color(1, 0.1, 0.1)
	bm.emission_energy_multiplier = 3.0
	bulb.material_override = bm
	bulb.position = blink.position
	pivot.add_child(bulb)
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
