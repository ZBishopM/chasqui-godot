extends "res://codigo/banco.gd"
## Nivel 1 — Vilcashuamán (Ayacucho), prólogo Acto I: el pueblo, el camino al Templo del Sol con el pozo, y el templo.
## Hereda del banco las manos, los poderes, el HUD y el cambio de candidatos; cambia el entorno por un cielo con el sol y
## la luna donde estaban de verdad (Sky3D, latitud y fecha reales) y la arena por el escenario.
## Teclas extra: RePág / AvPág una hora mas / menos · Inicio salto al amanecer · Fin pausa el reloj · F2 vuelve al banco.

const LATITUD := -13.653     # grados: Vilcashuaman
const LONGITUD := -73.953
const UTC := -5.0
const FECHA := [1532, 6, 21]  # Inti Raymi, el solsticio de junio (invierno austral): el sol sale por el noreste
const HORA_INICIAL := 6.0
const MINUTOS_POR_DIA := 20.0  # un dia entero dura 20 min de juego
const AMANECER := 6.25         # hora a la que salta Inicio (el sol asoma hacia las 6:20)

var cielo: Sky3D
var terreno: Terreno
var _hora: Label


func _ready() -> void:
	super._ready()
	jugador.camara.far = 40000.0   # el fondo llega a ~20 km en cada direccion
	jugador.position.y = terreno.altura(jugador.position.x, jugador.position.z) + 0.3
	cielo.sun.directional_shadow_max_distance = 600.0   # las lomas cercanas tambien dan sombra
	_hora = Label.new()
	_hora.position = Vector2(16, 300)
	_hora.add_theme_font_size_override("font_size", 18)
	_hora.add_theme_color_override("font_outline_color", Color.BLACK)
	_hora.add_theme_constant_override("outline_size", 6)
	_hud.get_parent().add_child(_hora)


func _escena_alterna() -> String:
	return "res://escenas/banco.tscn"


func _crear_entorno() -> void:
	cielo = Sky3D.new()
	add_child(cielo)
	var tod := cielo.tod
	tod.latitude = deg_to_rad(LATITUD)
	tod.longitude = deg_to_rad(LONGITUD)
	tod.utc = UTC
	tod.year = FECHA[0]
	tod.month = FECHA[1]
	tod.day = FECHA[2]
	cielo.current_time = HORA_INICIAL
	cielo.minutes_per_day = MINUTOS_POR_DIA
	# Niebla para un valle andino seco de ~40 km (la de Sky3D viene para 1 km). Su "nivel del mar" corta los rayos que
	# bajan de y = 0 (la plaza) y dibujaba una raya recta en el horizonte: se baja por debajo de todo el relieve.
	cielo.sky.fog_sea_level = -2000.0
	cielo.sky.fog_density = 0.00006
	cielo.sky.fog_end = 30000.0
	cielo.sky.fog_falloff = 1.0
	var env := cielo.environment
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.ssao_enabled = true


## El relieve real de Vilcashuaman (Terreno): la plaza en el origen, +X este, -Z norte.
func _crear_arena() -> void:
	terreno = Terreno.new()
	add_child(terreno)


func _montar_dummies() -> void:
	_dummies.clear()   # el nivel no tiene munecos de prueba


func _unhandled_input(ev: InputEvent) -> void:
	super._unhandled_input(ev)
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	match (ev as InputEventKey).keycode:
		KEY_PAGEUP:
			cielo.current_time = fposmod(cielo.current_time + 1.0, 24.0)
		KEY_PAGEDOWN:
			cielo.current_time = fposmod(cielo.current_time - 1.0, 24.0)
		KEY_HOME:
			cielo.current_time = AMANECER
		KEY_END:
			cielo.game_time_enabled = not cielo.game_time_enabled


func _process(dt: float) -> void:
	super._process(dt)
	if _hora != null:
		var h := cielo.current_time
		_hora.text = "%02d:%02d  21 jun 1532, Vilcashuaman%s   ·   RePag/AvPag hora · Inicio amanecer · Fin pausa · F2 banco" % [
			int(h), int(fmod(h, 1.0) * 60.0), "" if cielo.game_time_enabled else " (pausa)"]
		_hora.visible = _hud.visible
