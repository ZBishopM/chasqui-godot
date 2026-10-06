class_name Tormenta
extends Node3D
## Noche de tormenta: Sky3D a la 1:30 con la luna tapada, la lluvia al maximo (Lluvia) y rayos.
##   "normal": como en la puna de verdad, cada 8-25 s; casi todos relampagos dentro de las nubes lejanas (el cielo
##              parpadea) y alguno ramificado a 2-6 km.
##   "cinematica": para el despertar en la fosa, cada 2-5 s y mas cerca (0,4-3 km), casi todos visibles.
## Cada rayo da 2-3 fogonazos en ~0,35 s con una luz direccional que sale de donde cae (sombras duras); los cercanos
## (rayo_ahora(true)) caen junto a la camara y suman el destello de pantalla. `rayo` avisa (las venas de oro
## reaccionan). Sin trueno: el proyecto todavia no tiene audio.

signal rayo(intensidad: float, posicion: Vector3)

const HORA := 1.5
const AMBIENTE := 1.3   # energia del ambiente nocturno (el color lo pone Sky3D: el tinte de la noche)
const MODOS := {
	# [espera minima, maxima (s), parte de relampagos en las nubes, distancia minima, maxima (m)]
	"normal": [8.0, 25.0, 0.7, 2000.0, 6000.0],
	"cinematica": [2.0, 5.0, 0.25, 400.0, 3000.0],
}

var cielo: Sky3D
var lluvia: Lluvia
## Quien tiene `flash(valor, seg)` (el banco/nivel): el destello de pantalla de los rayos cercanos.
var pantalla: Node
var camara: Camera3D
var terreno: Terreno

var activa := false
var modo := "normal"
var _espera := 0.0
var _luz: DirectionalLight3D
var _antes := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1532
	_luz = DirectionalLight3D.new()
	_luz.name = "relampago"
	_luz.light_color = Color(0.78, 0.86, 1.0)
	_luz.light_energy = 0.0
	_luz.shadow_enabled = true
	_luz.directional_shadow_max_distance = 220.0
	_luz.visible = false
	add_child(_luz)


## Empieza la tormenta: noche cerrada y lluvia de golpe (para la cinematica) o al ritmo de la lluvia.
func empezar(m := "normal", de_golpe := true) -> void:
	modo = m
	if not activa and cielo != null:
		_antes = {"hora": cielo.current_time, "reloj": cielo.game_time_enabled, "luna": cielo.moon_energy,
				"noche_cielo": cielo.night_sky_contribution, "amb": cielo.environment.ambient_light_energy}
	activa = true
	if cielo != null:
		cielo.game_time_enabled = false
		cielo.current_time = HORA
		cielo.moon_energy = 0.02   # la luna detras de las nubes
		# Ni la luna ni el cielo dan luz, pero el ojo se acostumbra: un ambiente azul gris muy bajo deja leer las formas
		# entre rayo y rayo.
		cielo.night_sky_contribution = 0.0   # Sky3D lo lleva ahi con su propio tween (al saltar a la noche)
		cielo.environment.ambient_light_sky_contribution = 0.0
		cielo.environment.ambient_light_energy = AMBIENTE
	if lluvia != null:
		if de_golpe:
			lluvia.poner(1.0)
		else:
			lluvia.objetivo = 1.0
	_espera = 1.0


## Pasa la tormenta: la lluvia amaina sola y el cielo vuelve a la hora que tenia.
func parar() -> void:
	if not activa:
		return
	activa = false
	if lluvia != null:
		lluvia.objetivo = 0.0
	if cielo != null and not _antes.is_empty():
		cielo.current_time = _antes.hora
		cielo.game_time_enabled = _antes.reloj
		cielo.moon_energy = _antes.luna
		cielo.night_sky_contribution = _antes.noche_cielo
		cielo.environment.ambient_light_energy = _antes.amb


func cambiar_modo(m: String) -> void:
	modo = m
	_espera = minf(_espera, float(MODOS[m][1]))


func _process(dt: float) -> void:
	if not activa:
		return
	_espera -= dt
	if _espera <= 0.0:
		var p: Array = MODOS[modo]
		_espera = _rng.randf_range(p[0], p[1])
		rayo_ahora(false)


## Un rayo ya. `cerca`: cae a 20-60 m de la camara (o en `donde`), con destello de pantalla.
func rayo_ahora(cerca := false, donde := Vector3.INF) -> void:
	var p: Array = MODOS[modo]
	var ojo := camara.global_position if camara != null else Vector3.ZERO
	var a := _rng.randf() * TAU
	var nube := not cerca and _rng.randf() < float(p[2])
	var dist := _rng.randf_range(20.0, 60.0) if cerca else _rng.randf_range(p[3], p[4])
	var pie := donde if donde != Vector3.INF else ojo + Vector3(cos(a), 0.0, sin(a)) * dist
	if donde == Vector3.INF:
		pie.y = terreno.altura(pie.x, pie.z) if terreno != null and absf(pie.x) < 590.0 and absf(pie.z) < 590.0 else ojo.y - 200.0
	var intensidad := 1.0 if cerca else (0.35 if nube else clampf(1.4 - dist / 5000.0, 0.4, 1.0))
	if nube:
		# Dentro de las nubes: no se ve el rayo, solo se ilumina el cielo desde arriba y a un lado.
		pie = ojo + Vector3(cos(a) * dist, 900.0, sin(a) * dist)
	else:
		_dibujar(pie, dist, cerca)
	_fogonazo(pie + Vector3(0, 600.0 if not nube else 0.0, 0), intensidad, cerca)
	if pantalla != null:
		pantalla.flash(0.2 if cerca else (0.06 if nube else 0.15 * intensidad), 0.35 if cerca else 0.25)
	rayo.emit(intensidad, pie)


## El rayo visible: un tronco desde las nubes hasta `pie` y unas ramas, que parpadea y se apaga.
func _dibujar(pie: Vector3, dist: float, cerca: bool) -> void:
	var nodo := Node3D.new()
	add_child(nodo)
	var alto := 260.0 if cerca else clampf(dist * 0.35, 500.0, 1500.0)
	var grosor := 0.25 if cerca else clampf(dist * 0.0012, 0.8, 5.0)
	var cima := pie + Vector3(_rng.randf_range(-0.15, 0.15) * alto, alto, _rng.randf_range(-0.15, 0.15) * alto)
	VfxPropios._bolt(nodo, cima, pie, grosor, 1.6, alto * 0.06, 28)
	for i in _rng.randi_range(2, 4):
		var desde := cima.lerp(pie, _rng.randf_range(0.15, 0.6))
		var hasta := desde + Vector3(_rng.randf_range(-0.3, 0.3) * alto, -_rng.randf_range(0.15, 0.35) * alto, _rng.randf_range(-0.3, 0.3) * alto)
		VfxPropios._bolt(nodo, desde, hasta, grosor * 0.5, 1.0, alto * 0.04, 12)
	var tw := create_tween()
	tw.tween_interval(0.07)
	tw.tween_callback(func() -> void: nodo.visible = false)
	tw.tween_interval(0.05)
	tw.tween_callback(func() -> void: nodo.visible = true)
	tw.tween_interval(0.12)
	tw.tween_callback(nodo.queue_free)


## La luz del rayo: 2-3 parpadeos desde `desde` hacia la camara.
## Los cercanos alumbran menos de lo que su intensidad diria: con toda la luz la fosa parecia de dia; asi el fogonazo
## es un golpe azul frio con sombras duras.
func _fogonazo(desde: Vector3, intensidad: float, cerca := false) -> void:
	var ojo := camara.global_position if camara != null else Vector3.ZERO
	var dir := (ojo - desde).normalized()
	if absf(dir.y) > 0.99:
		dir = Vector3(0.1, dir.y, 0.0).normalized()
	_luz.basis = Basis.looking_at(dir, Vector3.UP)
	_luz.visible = true
	var e := 3.2 * intensidad * (0.6 if cerca else 1.0)
	var amb := 0.5 if cerca else 0.9
	var tw := create_tween()
	for paso: Array in [[e, 0.03], [e * 0.15, 0.05], [e * 0.8, 0.04], [0.0, 0.08], [e * 0.45, 0.04], [0.0, 0.12]]:
		tw.tween_property(_luz, "light_energy", float(paso[0]), float(paso[1]))
	tw.tween_callback(func() -> void: _luz.visible = false)
	# El cielo entero se ilumina un instante: sube el ambiente (las caras en sombra tambien se ven).
	if cielo != null:
		var env := cielo.environment
		var ta := create_tween()
		ta.tween_property(env, "ambient_light_energy", AMBIENTE + amb * intensidad, 0.03)
		ta.tween_property(env, "ambient_light_energy", AMBIENTE + amb * 0.2 * intensidad, 0.08)
		ta.tween_property(env, "ambient_light_energy", AMBIENTE + amb * 0.65 * intensidad, 0.04)
		ta.tween_property(env, "ambient_light_energy", AMBIENTE, 0.25)
