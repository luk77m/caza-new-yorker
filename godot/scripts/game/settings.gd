## Ajustes del jugador, guardados en user://ajustes.cfg
class_name Settings
extends RefCounted

const PATH := "user://ajustes.cfg"

static var volume := 0.8      # volumen general (0-1)
static var steps := 0.4       # volumen de los pasos (0-1)
static var zoom := 2.0        # zoom inicial de la cámara
static var arrows := true     # flechas hacia los encargos
static var shake := true      # sacudida de cámara con los disparos
static var fog := 0.93        # opacidad de la niebla de visión
static var fullscreen := false

static func load_cfg() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return
	volume = float(c.get_value("audio", "volumen", volume))
	steps = float(c.get_value("audio", "pasos", steps))
	zoom = float(c.get_value("video", "zoom", zoom))
	arrows = bool(c.get_value("juego", "flechas", arrows))
	shake = bool(c.get_value("video", "sacudida", shake))
	fog = float(c.get_value("video", "niebla", fog))
	fullscreen = bool(c.get_value("video", "pantalla_completa", fullscreen))

static func save_cfg() -> void:
	var c := ConfigFile.new()
	c.set_value("audio", "volumen", volume)
	c.set_value("audio", "pasos", steps)
	c.set_value("video", "zoom", zoom)
	c.set_value("juego", "flechas", arrows)
	c.set_value("video", "sacudida", shake)
	c.set_value("video", "niebla", fog)
	c.set_value("video", "pantalla_completa", fullscreen)
	c.save(PATH)

static func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)
