class_name CinematicaDespertar
extends Node
## El despertar en la fosa comun (Parte 2 del plan): el Chasqui abre los ojos de noche, en lo alto del monton de
## amortajados, bajo la tormenta; se incorpora y los rayos le muestran los cuerpos; sueña con Inti (por ahora solo una luz
## calida: el dialogo se hara despues, en `_sueno_inti`); al volver levanta las manos y la sangre de los muertos repta
## hasta ellas y entra; las venas se hinchan de sangre, aprieta los punos y un frente de oro las enciende desde los
## nudillos con un rayo encima. Quedan las venas de oro de reposo y se levanta con el control de vuelta.
##
## Todo sale del reloj `t` (s) en `_poner(t)`: la camara, las manos y la pantalla son funciones de t, y los sucesos
## (rayos, hilos, pico) se disparan al cruzar su instante. Saltar (Esc o Intro) lleva t al final.
##
##   0-6     negro -> los parpados se abren (borroso), boca arriba mirando la tormenta; un rayo cruza el cielo
##   6-14    se incorpora a medias y mira alrededor: los fogonazos le muestran los cuerpos; brazos normales
##   14-18   sueño de Inti: una luz calida que lo llena todo (gancho del dialogo)
##   18-30   levanta las manos con las palmas arriba; hilos de sangre; las mortajas se secan; venas rojas; puno
##   30-34   frente de oro de los nudillos al codo; en el pico (32,3) un rayo cercano, destello y patada de FOV
##   34-38   las venas quedan en reposo (0,5); baja las manos, se levanta y recupera el control

signal terminada

const DURACION := 38.0
const PICO := 32.3
const SUENO := Vector2(14.0, 18.0)
const OJOS_ECHADO := 0.28   # m sobre el monton: la cabeza apoyada
const OJOS_SENTADO := 0.85
const HILOS := 8
const HUESO_HILO := "f_middle.01"   # los hilos entran por los nudillos (en cuadro; la muneca queda abajo)

const SHADER_VELO := """
shader_type canvas_item;
uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float abierto = 0.0;      // parpados: 0 cerrados .. 1 abiertos
uniform float borroso = 0.0;      // 0..1
uniform float inti = 0.0;         // 0..1: la luz del sueño
uniform float aspecto = 1.778;
void fragment() {
	vec3 c = textureLod(pantalla, SCREEN_UV, borroso * 4.5).rgb;
	// Parpados: una rendija que se abre, mas alta en el medio, con el borde blando y oscuro.
	vec2 p = UV - 0.5;
	float rendija = 0.62 * abierto * (1.0 - 0.45 * pow(abs(p.x) * 2.0, 2.0));
	float vista = smoothstep(rendija, rendija - 0.12 - 0.1 * (1.0 - abierto), abs(p.y));
	c *= vista;
	// Inti: un sol difuso y blanco dorado sobre un fondo calido, que respira.
	vec2 q = vec2(p.x * aspecto, p.y);
	float d = length(q - vec2(0.0, -0.06));
	float respira = 0.92 + 0.08 * sin(TIME * 1.3);
	vec3 calido = mix(vec3(0.95, 0.62, 0.28), vec3(1.0, 0.95, 0.82), exp(-d * d * 7.0) * respira);
	calido += vec3(1.0, 0.9, 0.7) * exp(-d * d * 60.0) * 0.6;
	c = mix(c, calido, inti);
	COLOR = vec4(c, 1.0);
}
"""

var nivel: Node   # el nivel 1: jugador, manos, fosa, tormenta, _hud, _hora
var t := 0.0
var _jugador: Jugador
var _manos: Manos
var _fosa: Fosa
var _tormenta: Tormenta
var _velo: ShaderMaterial
var _capa: CanvasLayer
var _yaw0 := 0.0
var _hilos: Array[HiloSangre] = []
var _hilo_t: Array[Vector2] = []   # por hilo: instante de salida y duracion
var _hecho := {}                   # sucesos ya disparados
var _sombra: Node3D
var _hud_antes := true
var _terminada := false


func _ready() -> void:
	process_priority = 100   # despues del Jugador: la cabeza la pone la cinematica
	_jugador = nivel.jugador
	_manos = nivel.manos
	_fosa = nivel.fosa
	_tormenta = nivel.tormenta
	# El jugador, sin control, en lo alto del monton mirando hacia los escalones (y el camino).
	_jugador.set_physics_process(false)
	_jugador.set_process_unhandled_input(false)
	_jugador.reiniciar()
	_jugador.global_position = _fosa.despertar
	var hacia := Fosa.CAMINO - Fosa.CENTRO
	_yaw0 = atan2(-hacia.x, -hacia.y)
	for h in _jugador.get_children():
		if h is CuerpoSombra:
			_sombra = h
			_sombra.visible = false
	_hud_antes = nivel._hud.visible
	nivel._hud.visible = false
	_manos.brazos_normales()
	_manos.venas_base = 0.0
	_manos.guion({"venas_base": 0.0, "pose": 0.0, "palmas": 0.0, "temblor": 0.0, "apretar": 0.0, "crecimiento": 0.0, "brillo": 1.0, "sangre": 0.0})
	_fosa.secar_sangre(1.0)
	_tormenta.empezar("cinematica", true)
	_tormenta._espera = 6.0   # el primer rayo lo pone el guion
	_capa = CanvasLayer.new()
	_capa.layer = 50
	add_child(_capa)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER_VELO
	_velo = ShaderMaterial.new()
	_velo.shader = sh
	rect.material = _velo
	_capa.add_child(rect)
	_poner(0.0)


func _input(ev: InputEvent) -> void:
	if _terminada:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and (ev as InputEventKey).keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
		saltar()
	if ev is InputEventKey or ev is InputEventMouseButton or ev is InputEventMouseMotion:
		get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	if _terminada:
		return
	var antes := t
	t += dt
	if t >= DURACION:
		_sucesos(antes, t)
		_terminar()
		return
	_poner(t)   # antes de los sucesos: los hilos se trazan con la cabeza y las manos ya en su sitio
	_sucesos(antes, t)


## Lleva la cinematica al final de golpe (mismo estado que al terminar sola).
func saltar() -> void:
	if _terminada:
		return
	t = DURACION
	_terminar()


# --- Reloj ----------------------------------------------------------------------------------------

## Rampa suave de 0 (antes de a) a 1 (despues de b).
static func _r(x: float, a: float, b: float) -> float:
	return smoothstep(a, b, x)


## Todo lo que es funcion del tiempo: cabeza, manos, sangre y pantalla.
func _poner(x: float) -> void:
	# Cabeza: echado -> sentado -> de pie.
	var alto := lerpf(OJOS_ECHADO, OJOS_SENTADO, _r(x, 6.0, 9.5))
	alto = lerpf(alto, Jugador.OJOS.x, _r(x, 34.8, 37.2))
	var respira := sin(x * 1.7) * 0.012 * (1.0 - _r(x, 34.0, 36.0))
	_jugador.cabeza.position.y = alto + respira
	# Cabeceo: el cielo (1,25 rad) -> los cuerpos de delante -> las manos -> al frente.
	var cab := 1.25 + sin(x * 0.9) * 0.03
	cab = lerpf(cab, -0.5, _r(x, 5.5, 9.5))
	cab = lerpf(cab, -0.3, _r(x, 10.0, 12.0))
	cab = lerpf(cab, -0.85, _r(x, 18.0, 20.0))
	cab = lerpf(cab, -0.72, _r(x, 30.0, 31.5))
	cab = lerpf(cab, -0.08, _r(x, 34.5, 37.5))
	_jugador.cabeza.rotation.x = cab
	# Giro: mira a un lado y al otro buscando entre los cuerpos (9,5-14) y vuelve al frente.
	var giro := 0.75 * _r(x, 9.5, 11.5) - 1.35 * _r(x, 11.8, 13.6) + 0.6 * _r(x, 17.5, 19.0)
	_jugador.rotation.y = _yaw0 + giro
	# Alabeo: la cabeza ladeada en el barro, que se endereza al incorporarse.
	_jugador.camara.rotation.z = lerpf(0.22, 0.0, _r(x, 5.0, 8.0)) + sin(x * 0.7) * 0.01
	# Manos: aparecen al incorporarse (aun sin venas); suben con las palmas arriba para recibir la sangre y, cuando ha
	# entrado, se dan la vuelta mientras se cierran: las venas (en el dorso y el antebrazo) quedan a la vista.
	_manos.visible = x >= 7.0
	var pose := _r(x, 18.2, 19.8) * (1.0 - _r(x, 34.5, 36.0))
	var palmas := _r(x, 18.6, 20.2) * (1.0 - _r(x, 26.5, 28.0))
	var temblor := _r(x, 22.0, 29.0) * (1.0 - 0.7 * _r(x, PICO, PICO + 1.2)) * (1.0 - _r(x, 34.5, 35.5))
	var apretar := _r(x, 27.5, 29.5) * (1.0 - _r(x, PICO, PICO + 0.15))
	var venas := 0.9 * _r(x, 22.0, 29.0)
	venas = lerpf(venas, 0.5, _r(x, 33.5, 35.5))
	var sangre := _r(x, 21.5, 24.0) * (0.0 if x >= PICO - 0.1 else 1.0)   # cuando el frente llega al codo ya todo es oro
	var crec := _r(x, 30.0, PICO - 0.1) * (1.0 - _r(x, PICO + 0.7, 35.0))
	var brillo := 1.0 + 2.2 * _r(x, 30.0, PICO) * (1.0 - _r(x, PICO + 0.3, 34.5)) + 0.6 * sin(x * 31.0) * _r(x, 30.5, PICO) * (1.0 - _r(x, PICO, PICO + 0.4))
	_manos.guion({"pose": pose, "palmas": palmas, "temblor": temblor, "apretar": apretar, "venas_base": venas, "sangre": sangre, "crecimiento": crec, "brillo": brillo})
	# La sangre de las mortajas se va con los hilos.
	_fosa.secar_sangre(lerpf(1.0, 0.12, _r(x, 20.0, 29.0)))
	for i in _hilos.size():
		var ht := _hilo_t[i]
		_hilos[i].poner_avance(clampf((x - ht.x) / ht.y, 0.0, 1.0))
	# Pantalla: parpados (se abren, parpadean, se abren del todo), borroso al despertar, la luz de Inti.
	# Pasado 1 la rendija sigue abriendose hasta salir de la pantalla (1,8): despierto no queda viñeta.
	var abierto := 0.45 * _r(x, 1.0, 2.2) * (1.0 - _r(x, 2.5, 2.8)) + _r(x, 3.0, 4.6) + 0.8 * _r(x, 4.6, 6.5)
	abierto *= 1.0 - 0.85 * (_r(x, 18.0, 18.12) - _r(x, 18.25, 18.5))   # un parpadeo al volver del sueño
	_velo.set_shader_parameter("abierto", clampf(abierto, 0.0, 1.8))
	_velo.set_shader_parameter("borroso", 1.0 - _r(x, 2.0, 6.5) + 0.6 * (_r(x, 17.0, 18.0) - _r(x, 18.0, 19.5)))
	_velo.set_shader_parameter("inti", _sueno_inti(x))
	var tam := get_viewport().get_visible_rect().size
	_velo.set_shader_parameter("aspecto", tam.x / maxf(tam.y, 1.0))


## Gancho del sueño con Inti (14-18 s): por ahora solo la luz calida que lo llena todo; aqui ira el dialogo. Devuelve
## cuanto tapa la luz (0..1).
func _sueno_inti(x: float) -> float:
	return _r(x, SUENO.x, SUENO.x + 1.2) * (1.0 - _r(x, SUENO.y - 1.2, SUENO.y))


## Sucesos con instante: se disparan una vez al cruzarlo (tambien si un cuadro largo se lo salta).
func _sucesos(a: float, b: float) -> void:
	var cruza := func(x: float) -> bool: return a < x and b >= x
	if cruza.call(3.6):
		# Un rayo cruza el cielo que mira: cae a 250 m, algo de lado, y su cima (>= 500 m) queda a 60-70 grados de
		# elevacion, dentro de lo que ve echado.
		var ojo := _jugador.camara.global_position
		var rumbo := _yaw0 + 0.5
		_tormenta.rayo_ahora(false, Vector3(ojo.x, ojo.y - 50.0, ojo.z) + Vector3(-sin(rumbo), 0.0, -cos(rumbo)) * 250.0)
	if cruza.call(8.6):
		_tormenta.rayo_ahora(true)
	if cruza.call(12.2):
		_tormenta.rayo_ahora(true)
	if cruza.call(20.4):
		_soltar_hilos()
	if cruza.call(25.5):
		_tormenta.rayo_ahora(false)
	if cruza.call(PICO):
		_manos.pico_despertar.emit()   # el nivel hace el destello
		var tw := create_tween()
		tw.tween_property(_jugador, "patada_fov", 8.0, 0.12)
		tw.tween_property(_jugador, "patada_fov", 0.0, 0.9).set_ease(Tween.EASE_OUT)
		_tormenta.rayo_ahora(true)
		_tormenta._espera = 3.0


## Los hilos: de los cuerpos mas cercanos que tiene delante (sus torsos, a +-60 grados de donde mira: se los ve llegar)
## a los nudillos de una y otra mano, saliendo escalonados; entran todos antes de que las manos se den la vuelta (26,5 s).
func _soltar_hilos() -> void:
	var yo := _fosa.despertar
	var delante := Vector2(-sin(_jugador.rotation.y), -cos(_jugador.rotation.y))
	var fuentes := _fosa.fuentes.duplicate()
	fuentes.sort_custom(func(p: Vector3, q: Vector3) -> bool:
		return Vector2(p.x - yo.x, p.z - yo.z).length() < Vector2(q.x - yo.x, q.z - yo.z).length())
	var elegidas: Array[Vector3] = []
	for pasada in 2:   # primero las de delante; si no alcanzan, las demas
		for f: Vector3 in fuentes:
			var v := Vector2(f.x - yo.x, f.z - yo.z)
			var de_frente := v.normalized().dot(delante) > cos(deg_to_rad(60.0))
			if v.length() > 1.3 and v.length() < 5.0 and (de_frente or pasada == 1) and not elegidas.has(f):
				elegidas.append(f)
			if elegidas.size() >= HILOS:
				break
	var espacio := _jugador.get_world_3d().direct_space_state
	var excluir: Array[RID] = [_jugador.get_rid()]
	for i in elegidas.size():
		var lado := ".L" if i % 2 == 0 else ".R"
		var mano := _manos.punto_mano(lado, HUESO_HILO)
		var hilo := HiloSangre.new()
		hilo.largo_m = 1.0 + 0.15 * (i % 3)
		hilo.armar(HiloSangre.recorrido_por(espacio, elegidas[i] + Vector3.UP * 0.6, mano, excluir, 77 + i), 0.019 + 0.004 * (i % 2))
		nivel.add_child(hilo)
		_hilos.append(hilo)
		_hilo_t.append(Vector2(20.4 + 0.3 * i, 3.6 + 0.3 * (i % 3)))


func _terminar() -> void:
	if _terminada:
		return
	_terminada = true
	_poner(DURACION)
	for h in _hilos:
		h.queue_free()
	_hilos.clear()
	_fosa.secar_sangre(0.12)
	_manos.visible = true
	_manos.soltar_guion()
	_manos.venas_base = 0.5
	_jugador.camara.rotation.z = 0.0
	_jugador.cabeza.position.y = Jugador.OJOS.x
	_jugador.patada_fov = 0.0
	_jugador.reiniciar()
	_jugador.set_physics_process(true)
	_jugador.set_process_unhandled_input(true)
	if _sombra != null:
		_sombra.visible = true
	nivel._hud.visible = _hud_antes
	_tormenta.cambiar_modo("normal")
	_capa.queue_free()
	terminada.emit()
	queue_free()
