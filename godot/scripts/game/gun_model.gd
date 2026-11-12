## Mano derecha con la pistola con silenciador de los años 30, modelada en 3D con piezas sencillas
## (corredera pavonada, cachas de nogal, silenciador con anillos, dedos que rodean la empuñadura,
## puño de la camisa y manga de la chaqueta). Se renderiza en un SubViewport transparente que la vista
## en primera persona pinta encima de la escena.
class_name GunModel
extends SubViewport

const BASE := Vector3(0.135, -0.125, -0.36)

var cam: Camera3D
var root: Node3D
var slide: Node3D
var flash: MeshInstance3D
var flash_light: OmniLight3D
var env: Environment
var key: DirectionalLight3D
var muzzle: Node3D
var port: Node3D
var m_skin: StandardMaterial3D
var m_skin2: StandardMaterial3D
var m_coat: StandardMaterial3D

func _ready() -> void:
	transparent_bg = true
	own_world_3d = true
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	var world := Node3D.new()
	add_child(world)
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.5)
	env.ambient_light_energy = 1.0
	we.environment = env
	world.add_child(we)
	cam = Camera3D.new()
	cam.fov = 55
	cam.near = 0.01
	cam.far = 5.0
	world.add_child(cam)
	key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55, -25, 0)
	key.light_color = Color(1.0, 0.9, 0.75)
	key.light_energy = 0.9
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 160, 0)
	rim.light_color = Color(0.6, 0.7, 1.0)
	rim.light_energy = 0.35
	world.add_child(rim)
	root = Node3D.new()
	world.add_child(root)
	_build()

# ---------------------------------------------------------------- piezas

func _mat(c: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = sc
	parent.add_child(mi)
	return mi

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(parent, b, pos, mat, rot)

## Cilindro a lo largo del eje Z (cañón, silenciador).
func _tube(parent: Node3D, r: float, length: float, z: float, y: float, mat: Material) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = length
	c.radial_segments = 20
	return _mesh(parent, c, Vector3(0, y, z), mat, Vector3(PI / 2.0, 0, 0))

func _cap(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material, rot: Vector3) -> MeshInstance3D:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 4
	return _mesh(parent, c, pos, mat, rot)

## Tronco de cono entre dos puntos (muñeca, puño de la camisa, manga).
func _limb(parent: Node3D, a: Vector3, b: Vector3, r0: float, r1: float, mat: Material) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.bottom_radius = r0
	c.top_radius = r1
	c.height = a.distance_to(b)
	c.radial_segments = 16
	var mi := _mesh(parent, c, (a + b) / 2.0, mat)
	mi.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return mi

func _build() -> void:
	var steel := _mat(Color("#2a2d34"), 0.85, 0.3)
	var steel_hi := _mat(Color("#3c414b"), 0.9, 0.22)
	var steel_dk := _mat(Color("#17181c"), 0.7, 0.45)
	var black := _mat(Color("#050506"), 0.0, 0.9)
	var wood := _mat(Color("#6b3a1f"), 0.0, 0.5)
	var wood_dk := _mat(Color("#4a2612"), 0.0, 0.6)
	var sup := _mat(Color("#1c1e23"), 0.55, 0.5)
	var sup_ring := _mat(Color("#33363d"), 0.8, 0.35)
	var shirt := _mat(Color("#efe9d9"), 0.0, 0.8)
	m_skin = _mat(Color("#d9a982"), 0.0, 0.65)
	m_skin2 = _mat(Color("#c4936d"), 0.0, 0.7)
	m_coat = _mat(Color("#2a2a33"), 0.0, 0.9)
	root.position = BASE
	root.rotation = Vector3(0.03, 0.12, 0)
	# corredera (se mueve al disparar)
	slide = Node3D.new()
	root.add_child(slide)
	_box(slide, Vector3(0.03, 0.03, 0.19), Vector3(0, 0.034, -0.064), steel)
	_box(slide, Vector3(0.012, 0.004, 0.185), Vector3(0, 0.0505, -0.064), steel_hi)
	_box(slide, Vector3(0.031, 0.006, 0.19), Vector3(0, 0.022, -0.064), steel_dk)
	for i in 6:
		_box(slide, Vector3(0.0312, 0.022, 0.0025), Vector3(0, 0.036, 0.024 - i * 0.006), steel_dk)
	_box(slide, Vector3(0.002, 0.012, 0.032), Vector3(0.0152, 0.039, -0.045), black)
	_box(slide, Vector3(0.007, 0.007, 0.006), Vector3(-0.007, 0.054, 0.026), steel_dk)
	_box(slide, Vector3(0.007, 0.007, 0.006), Vector3(0.007, 0.054, 0.026), steel_dk)
	port = Node3D.new()
	port.position = Vector3(0.02, 0.042, -0.045)
	slide.add_child(port)
	# armazón, guardamonte, gatillo y percutor
	_box(root, Vector3(0.027, 0.02, 0.15), Vector3(0, 0.009, -0.052), steel_dk)
	var tor := TorusMesh.new()
	tor.inner_radius = 0.011
	tor.outer_radius = 0.0145
	tor.rings = 16
	tor.ring_segments = 8
	_mesh(root, tor, Vector3(0, -0.012, -0.032), steel_dk, Vector3(0, 0, PI / 2.0), Vector3(1, 1, 1.35))
	_box(root, Vector3(0.004, 0.016, 0.004), Vector3(0, -0.007, -0.028), steel, Vector3(0.35, 0, 0))
	_box(root, Vector3(0.008, 0.018, 0.01), Vector3(0, 0.047, 0.034), steel_dk, Vector3(-0.55, 0, 0))
	# empuñadura de nogal con cachas y tornillo
	_box(root, Vector3(0.026, 0.1, 0.044), Vector3(0, -0.046, 0.02), steel_dk, Vector3(-0.28, 0, 0))
	_box(root, Vector3(0.03, 0.088, 0.036), Vector3(0, -0.046, 0.019), wood, Vector3(-0.28, 0, 0))
	for j in 5:
		_box(root, Vector3(0.0305, 0.002, 0.034), Vector3(0, -0.02 - j * 0.014, 0.012 + j * 0.004), wood_dk, Vector3(-0.28, 0, 0))
	var sc := CylinderMesh.new()
	sc.top_radius = 0.004
	sc.bottom_radius = 0.004
	sc.height = 0.032
	_mesh(root, sc, Vector3(0, -0.04, 0.018), steel_hi, Vector3(0, 0, PI / 2.0))
	# silenciador
	_tube(root, 0.0165, 0.2, -0.258, 0.033, sup)
	for z in [-0.17, -0.215, -0.26, -0.305]:
		_tube(root, 0.0172, 0.004, z, 0.033, sup_ring)
	_tube(root, 0.0175, 0.008, -0.356, 0.033, sup_ring)
	_tube(root, 0.0045, 0.002, -0.361, 0.033, black)
	muzzle = Node3D.new()
	muzzle.position = Vector3(0, 0.033, -0.37)
	root.add_child(muzzle)
	# fogonazo
	var fm := SphereMesh.new()
	fm.radius = 0.03
	fm.height = 0.06
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color(1.0, 0.85, 0.5, 0.85)
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash = _mesh(root, fm, muzzle.position + Vector3(0, 0, -0.02), fmat, Vector3.ZERO, Vector3(1, 1, 1.8))
	flash.visible = false
	flash_light = OmniLight3D.new()
	flash_light.light_color = Color(1.0, 0.75, 0.4)
	flash_light.omni_range = 1.2
	flash_light.light_energy = 0.0
	flash_light.position = muzzle.position
	root.add_child(flash_light)
	# mano: dorso, dedos alrededor de la empuñadura, índice estirado y pulgar por el otro lado
	var palm := SphereMesh.new()
	palm.radius = 0.045
	palm.height = 0.09
	_mesh(root, palm, Vector3(0.024, -0.036, 0.032), m_skin, Vector3(-0.28, 0, -0.15), Vector3(0.55, 1.0, 0.95))
	for i in 3:
		var y := -0.03 - i * 0.021
		var z := -0.006 + i * 0.006
		_cap(root, 0.0095, 0.058, Vector3(0.002, y, z), m_skin if i % 2 == 0 else m_skin2, Vector3(0, 0, PI / 2.0))
		_cap(root, 0.009, 0.03, Vector3(-0.022, y + 0.002, z + 0.014), m_skin2, Vector3(PI / 2.0, 0, 0))
	_cap(root, 0.0088, 0.058, Vector3(0.018, 0.004, -0.036), m_skin, Vector3(PI / 2.0, 0.08, 0))
	_cap(root, 0.0092, 0.06, Vector3(-0.019, 0.012, -0.01), m_skin, Vector3(PI / 2.0 - 0.15, -0.1, 0))
	# muñeca, puño de la camisa y manga de la chaqueta
	_limb(root, Vector3(0.03, -0.065, 0.055), Vector3(0.058, -0.115, 0.125), 0.027, 0.03, m_skin)
	_limb(root, Vector3(0.054, -0.108, 0.115), Vector3(0.068, -0.135, 0.155), 0.034, 0.035, shirt)
	_limb(root, Vector3(0.064, -0.128, 0.145), Vector3(0.2, -0.36, 0.5), 0.042, 0.055, m_coat)
	# el antebrazo sigue hasta bien fuera de la pantalla: al ladearte no se ve dónde termina
	_limb(root, Vector3(0.19, -0.34, 0.47), Vector3(0.36, -0.7, 0.95), 0.055, 0.075, m_coat)

# ---------------------------------------------------------------- cada fotograma

## Coloca el arma: retroceso (0-1), balanceo en píxeles, corredera atrás (0-1), fogonazo (0-1) y luz.
func pose(recoil: float, sway: Vector2, slide_back: float, flash_k: float, light: Color, skin: Color, coat: Color) -> void:
	root.position = BASE + Vector3(sway.x * 0.0005, -sway.y * 0.0005, recoil * 0.055)
	root.rotation = Vector3(0.03 + recoil * 0.24, 0.12 - sway.x * 0.0008, recoil * 0.05)
	slide.position = Vector3(0, 0, slide_back * 0.034)
	flash.visible = flash_k > 0.0
	flash.scale = Vector3(1, 1, 1.8) * (0.6 + flash_k * 0.8)
	flash_light.light_energy = flash_k * 4.0
	env.ambient_light_color = Color(clampf(light.r, 0.08, 1.2), clampf(light.g, 0.08, 1.2), clampf(light.b, 0.08, 1.2))
	key.light_energy = 0.35 + 0.75 * clampf((light.r + light.g + light.b) / 3.0, 0.0, 1.2)
	m_skin.albedo_color = skin
	m_skin2.albedo_color = skin.darkened(0.12)
	m_coat.albedo_color = coat

func muzzle_screen() -> Vector2:
	return cam.unproject_position(muzzle.global_position)

func port_screen() -> Vector2:
	return cam.unproject_position(port.global_position)
