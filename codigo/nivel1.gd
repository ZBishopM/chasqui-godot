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
var _hora: Label


func _ready() -> void:
	super._ready()
	jugador.camara.far = 30000.0   # el fondo llega a decenas de km
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
	var env := cielo.environment
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.ssao_enabled = true


## Provisional (N0): un llano grande y unos cerros lejanos de prueba para leer la luz y la niebla. El relieve real de
## Vilcashuaman llega en el N1.
func _crear_arena() -> void:
	var suelo := StaticBody3D.new()
	var malla := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(6000, 6000)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.31, 0.22)
	mat.roughness = 0.95
	plano.material = mat
	malla.mesh = plano
	suelo.add_child(malla)
	var col := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(6000, 1, 6000)
	col.shape = caja
	col.position.y = -0.5
	suelo.add_child(col)
	add_child(suelo)
	var piedra := StandardMaterial3D.new()
	piedra.albedo_color = Color(0.45, 0.42, 0.38)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1532
	for i in 18:
		var cerro := MeshInstance3D.new()
		var cono := CylinderMesh.new()
		cono.top_radius = 0.0
		cono.bottom_radius = rng.randf_range(500, 1400)
		cono.height = rng.randf_range(300, 1100)
		cono.radial_segments = 7
		cono.material = piedra
		cerro.mesh = cono
		var ang := TAU * i / 18.0 + rng.randf_range(-0.1, 0.1)
		var dist := rng.randf_range(2500, 9000)
		cerro.position = Vector3(cos(ang) * dist, cono.height * 0.5 - 60.0, sin(ang) * dist)
		add_child(cerro)


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
