extends "res://codigo/banco.gd"
## Nivel 1 — Vilcashuamán (Ayacucho), prólogo Acto I: el pueblo, el camino al Templo del Sol con el pozo, y el templo.
## Hereda del banco las manos, los poderes, el HUD y el cambio de candidatos; cambia el entorno por un cielo con el sol y
## la luna donde estaban de verdad (Sky3D, latitud y fecha reales) y la arena por el escenario.
## Teclas extra: RePág / AvPág una hora mas / menos · Inicio salto al amanecer · Fin pausa el reloj · F2 vuelve al banco ·
## F3 (Mayus+F3) siguiente (anterior) mirador · L lluvia.

const LATITUD := -13.653     # grados: Vilcashuaman
const LONGITUD := -73.953
const UTC := -5.0
const FECHA := [1532, 6, 21]  # Inti Raymi, el solsticio de junio (invierno austral): el sol sale por el noreste
const HORA_INICIAL := 6.0
const MINUTOS_POR_DIA := 20.0  # un dia entero dura 20 min de juego
const AMANECER := 6.25         # hora a la que salta Inicio (el sol asoma hacia las 6:20)

var cielo: Sky3D
var terreno: Terreno
var pueblo: Pueblo
var hogar: Hogar
var fosa: Fosa
var canon: Canon
var camino: Camino
var templo: Templo
var vegetacion: Vegetacion
var lluvia: Lluvia
var miradores: Array[Dictionary] = []   # los de todas las zonas, en orden
var _hora: Label
var _mirador := -1


func _ready() -> void:
	super._ready()
	jugador.camara.far = 40000.0   # el fondo llega a ~20 km en cada direccion
	jugador.position.y = terreno.altura(jugador.position.x, jugador.position.z) + 0.3
	# El pueblo antes que la vegetacion: marca en el terreno donde no debe crecer nada.
	pueblo = Pueblo.new()
	pueblo.terreno = terreno
	add_child(pueblo)
	hogar = Hogar.new()   # la casa del Chasqui, al oeste del pueblo
	hogar.terreno = terreno
	hogar.sol = cielo.sun
	add_child(hogar)
	add_child(Cordillera.new())   # el fondo: nevados de 21 a 38 km
	# El templo antes que el camino: el camino acaba al pie de su escalinata.
	templo = Templo.new()
	templo.terreno = terreno
	add_child(templo)
	camino = Camino.new()
	camino.terreno = terreno
	camino.destino = Vector2(templo.entrada.x, templo.entrada.z)
	add_child(camino)
	canon = Canon.new()   # el cañon del sur (tallado en el relieve horneado): rio, barrera en el borde, peñascos
	canon.terreno = terreno
	add_child(canon)
	fosa = Fosa.new()   # la fosa comun escondida en el filo del cañon (antes de la vegetacion: pinta su suelo)
	fosa.terreno = terreno
	add_child(fosa)
	miradores.append_array(pueblo.miradores)
	miradores.append_array(hogar.miradores)
	miradores.append_array(camino.miradores)
	miradores.append_array(fosa.miradores)
	miradores.append_array(templo.miradores)
	_miradores_cordillera()
	vegetacion = Vegetacion.new()
	vegetacion.terreno = terreno
	vegetacion.jugador = jugador
	add_child(vegetacion)
	cielo.sun.directional_shadow_max_distance = 600.0   # las lomas cercanas tambien dan sombra
	lluvia = Lluvia.new()
	lluvia.camara = jugador.camara
	lluvia.cielo = cielo
	add_child(lluvia)
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
	cielo.sky.fog_sea_level = -4800.0   # bajo los valles mas hondos del relieve quebrado (~ -4000 m)
	cielo.sky.fog_density = 0.000032   # mas espesa blanqueaba la cordillera (a 20-38 km quedaba color crema)
	cielo.sky.fog_end = 30000.0
	cielo.sky.fog_falloff = 1.0
	# Nubes grandes y cercanas, de vientre gris (como las de la costa y los valles en la tarde): cumulos mas grandes
	# (cumulus_size bajo = menos repeticion), mas cubierto, mas gruesos y que absorben mas luz por debajo.
	cielo.sky.cumulus_size = 0.35
	cielo.sky.cumulus_coverage = 0.6
	cielo.sky.cumulus_thickness = 0.046
	cielo.sky.cumulus_absorption = 4.6
	cielo.sky.cumulus_intensity = 0.9
	cielo.sky.cumulus_noise_freq = 3.1   # bordes mas recortados
	cielo.sky.cirrus_coverage = 0.35
	var env := cielo.environment
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.ssao_enabled = true
	# Niebla volumetrica sin densidad propia: solo la ponen los FogVolume (el haz de sol que entra al hogar). Se
	# enciende cerca del hogar (_process), que es caro en todo el nivel.
	env.volumetric_fog_density = 0.0
	env.volumetric_fog_anisotropy = 0.6   # mirando hacia la puerta, el haz brilla mas (dispersion hacia delante)
	env.volumetric_fog_length = 20.0   # corta: celdas mas finas, el haz sale mas definido (solo hace falta dentro del hogar)
	env.volumetric_fog_detail_spread = 1.5
	env.volumetric_fog_temporal_reprojection_amount = 0.85


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
		KEY_L:
			lluvia.alternar()
		KEY_F3:
			var n := miradores.size()
			_mirador = (_mirador + (-1 if (ev as InputEventKey).shift_pressed else 1) + n) % n
			_ir_a_mirador(_mirador)


## Miradores hacia los nevados (Cordillera.MACIZOS): desde lo alto del templo hacia Vilcabamba (ENE), con luz de tarde
## en sus caras oeste, y hacia los volcanes del sur (Ccarhuarazo, Solimana) desde lo alto del pueblo.
func _miradores_cordillera() -> void:
	var cima := Vector3.ZERO
	for m: Dictionary in templo.miradores:
		if m.nombre == "amanecer":
			cima = m.pos
	var hacia := func(acimut: float, elev: float) -> Vector3:
		var a := deg_to_rad(acimut)
		return cima + Vector3(sin(a), tan(deg_to_rad(elev)), -cos(a)) * 1000.0
	miradores.append({"nombre": "nevados", "pos": cima, "mira": hacia.call(73.0, 6.0), "hora": 15.0})
	# Los volcanes del sur, desde el mirador alto del pueblo ("vista"), que no tiene muros delante.
	for m: Dictionary in pueblo.miradores:
		if m.nombre == "vista":
			var a := deg_to_rad(160.0)
			miradores.append({"nombre": "volcanes", "pos": m.pos, "mira": (m.pos as Vector3) + Vector3(sin(a), tan(deg_to_rad(3.0)), -cos(a)) * 1000.0, "hora": 11.0})


## Lleva al jugador al mirador i del pueblo, mirando hacia donde dice.
func _ir_a_mirador(i: int) -> void:
	var m: Dictionary = miradores[i]
	var pos: Vector3 = m.pos
	var dir: Vector3 = (m.mira as Vector3) - pos
	jugador.reiniciar()
	jugador.global_position = pos - Vector3(0, Jugador.OJOS.x, 0)
	jugador.rotation.y = atan2(-dir.x, -dir.z)
	jugador.cabeza.rotation.x = atan2(dir.y, Vector2(dir.x, dir.z).length())
	print("mirador %d/%d: %s" % [i + 1, miradores.size(), m.nombre])


## Recorrido del pueblo para la PARADA de N3 (lo usa el MCP via game_eval): pasa por cada mirador (o solo por los de
## `solo`), guarda capturas/pueblo_<n>_<nombre>.png y mide FPS, primitivas y llamadas de dibujo en cada uno. Sin HUD.
func capturar_recorrido(hora := 10.5, solo: PackedStringArray = []) -> String:
	var hora_antes := cielo.current_time
	var reloj := cielo.game_time_enabled
	cielo.game_time_enabled = false
	cielo.current_time = hora
	_hud.visible = false
	jugador.set_physics_process(false)
	var lineas: PackedStringArray = []
	for i in miradores.size():
		if not solo.is_empty() and not solo.has(miradores[i].nombre):
			continue
		_ir_a_mirador(i)
		cielo.current_time = float(miradores[i].get("hora", hora))
		await get_tree().create_timer(1.2).timeout   # que se asienten las sombras y el FPS
		await RenderingServer.frame_post_draw
		var ruta := _captura("nivel1_%02d_%s" % [i + 1, miradores[i].nombre])
		lineas.append("%-14s %4d FPS  %7d primitivas  %4d dibujos  %s" % [
			miradores[i].nombre, Engine.get_frames_per_second(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), ruta])
	jugador.set_physics_process(true)
	_hud.visible = true
	cielo.current_time = hora_antes
	cielo.game_time_enabled = reloj
	return "\n".join(lineas)


func _process(dt: float) -> void:
	super._process(dt)
	if hogar != null:
		cielo.environment.volumetric_fog_enabled = jugador.global_position.distance_to(hogar.centro) < Hogar.RADIO_NIEBLA
	if _hora != null:
		var h := cielo.current_time
		_hora.text = "%02d:%02d  21 jun 1532, Vilcashuaman%s   ·   RePag/AvPag hora · Inicio amanecer · Fin pausa · L lluvia · F2 banco · F3 miradores" % [
			int(h), int(fmod(h, 1.0) * 60.0), "" if cielo.game_time_enabled else " (pausa)"]
		_hora.visible = _hud.visible
