class_name Jugador
extends CharacterBody3D
## Chasqui en primera persona: capsula + cabeza + camara (M9 de la version web). Anda, esprinta (Mayus), salta y se agacha
## (Ctrl mantenido). Es el unico dueno del FOV de la camara: fov_base (el del rig de manos) + patada_fov (Halcon) + apertura
## al esprintar.
##
## Parkour (N4 del Nivel 1): en el aire, mirando a un muro, se agarra solo a la cornisa si su borde le queda entre
## AGARRE_ALTO.x y AGARRE_ALTO.y sobre los pies (un salto en plano alcanza bordes de hasta ~3,5 m); si el borde le queda
## por debajo del pecho (SIN_COLGARSE) sube de una vez, sin colgarse. Colgado: A/D se
## desplaza por la cornisa, W o Espacio sube a pulso (agachado si arriba no cabe de pie), Ctrl o S se suelta, y S +
## Espacio salta hacia atras, separandose del muro. Ademas: tiempo de coyote y salto anticipado, para saltar de techo en
## techo sin tener que clavar el borde.

const VELOCIDAD := 5.0
const ESPRINT := 8.0          # m/s con Mayus, solo hacia delante
const ESPRINT_FOV := 15.0     # grados que se abre el FOV al esprintar
const AGACHADO_VEL := 2.5     # m/s agachado
const ALTURA := Vector2(1.8, 1.2)   # m de la capsula de pie / agachado
const OJOS := Vector2(1.6, 1.0)     # m de la camara de pie / agachado
const SALTO := 5.0
const SENSIBILIDAD := 0.0025
const FOV := 90.0
# Parkour
const AGARRE_ALTO := Vector2(0.35, 2.25)  # m del borde sobre los pies para poder agarrarlo
const SIN_COLGARSE := 1.4                 # m: bordes mas bajos se suben de una vez, sin quedar colgado
const AGARRE_ALCANCE := 0.8               # m por delante del eje del cuerpo en que se busca el muro
const COLGADO_PIES := 1.85                # m bajo el borde quedan los pies colgado (los ojos, 0,25 m bajo el borde)
const SEPARACION := 0.4                   # m entre la cara del muro y el eje del cuerpo colgado
const LATERAL := 1.4                      # m/s por la cornisa
const SUBIR_SEG := Vector2(0.32, 0.22)    # s: subir el cuerpo al borde y luego avanzar sobre el
const SALTO_ATRAS := 4.5                  # m/s de separacion al saltar hacia atras desde la cornisa
const COYOTE := 0.12                      # s que aun se puede saltar tras salirse de un borde
const ANTICIPO := 0.12                    # s que vale pulsar saltar antes de tocar el suelo

enum Estado {NORMAL, COLGADO, SUBIENDO}

var cabeza: Node3D
var camara: Camera3D
var impulso := Vector3.ZERO  # empuje horizontal extra (Halcon); decae solo
var fov_base := FOV          # lo fija el banco segun el rig de manos
var patada_fov := 0.0        # grados extra que anima el Halcon (0 -> 16 -> 0)
var esprint := 0.0           # 0..1 suavizado: manos, FOV y cuerpo lo siguen
var agachado := false        # estado (fisico): capsula baja y paso lento
var agacharse := 0.0         # 0..1 suavizado: altura de la camara, vineta, cuerpo
var _esprint_v := 0.0
var _agacharse_v := 0.0
var _esprintando := false
var _col: CollisionShape3D
var _capsula: CapsuleShape3D
var estado := Estado.NORMAL
var colgado := 0.0               # 0..1 suavizado: las manos suben a agarrar el borde
var borde := Vector3.ZERO        # punto del borde agarrado (arriba del muro)
var normal_muro := Vector3.ZERO  # horizontal, hacia fuera del muro
var _cara := Vector3.ZERO        # punto de la cara del muro a la altura del pecho
var _sin_agarre := 0.0           # s en que no se agarra nada (tras soltarse o saltar)
var _colgado_v := 0.0
var _coyote := 0.0
var _anticipo := 0.0


func _ready() -> void:
	_col = CollisionShape3D.new()
	_capsula = CapsuleShape3D.new()
	_capsula.radius = 0.35
	_col.shape = _capsula
	add_child(_col)
	_poner_altura(ALTURA.x)

	cabeza = Node3D.new()
	cabeza.position.y = OJOS.x
	add_child(cabeza)

	camara = Camera3D.new()
	camara.fov = FOV
	camara.near = 0.02
	cabeza.add_child(camara)
	camara.make_current()


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-evento.relative.x * SENSIBILIDAD)
		cabeza.rotation.x = clampf(cabeza.rotation.x - evento.relative.y * SENSIBILIDAD, -1.5, 1.5)


func _physics_process(delta: float) -> void:
	_sin_agarre = maxf(_sin_agarre - delta, 0.0)
	if estado == Estado.COLGADO:
		_colgado(delta)
		return
	if estado == Estado.SUBIENDO:
		return
	# Agacharse con Ctrl mantenido; al soltar solo se levanta si cabe (si hay techo encima sigue agachado).
	if Input.is_action_pressed("agacharse") != agachado:
		if not agachado:
			agachado = true
			_poner_altura(ALTURA.y)
		elif not test_move(global_transform, Vector3.UP * (ALTURA.x - ALTURA.y)):
			agachado = false
			_poner_altura(ALTURA.x)

	_coyote = COYOTE if is_on_floor() else _coyote - delta
	_anticipo = ANTICIPO if Input.is_action_just_pressed("saltar") else _anticipo - delta
	if not is_on_floor():
		velocity += get_gravity() * delta
	if _anticipo > 0.0 and _coyote > 0.0 and not agachado:
		velocity.y = SALTO
		_anticipo = 0.0
		_coyote = 0.0

	var eje := Input.get_vector("izquierda", "derecha", "adelante", "atras")
	# En el aire se conserva el esprint con que se salto.
	if is_on_floor():
		_esprintando = Input.is_action_pressed("esprintar") and eje.y < -0.3 and not agachado
	var dir := (transform.basis * Vector3(eje.x, 0.0, eje.y)).normalized()
	var rapidez := AGACHADO_VEL if agachado else (ESPRINT if _esprintando else VELOCIDAD)
	impulso = impulso.move_toward(Vector3.ZERO, 60.0 * delta)
	velocity.x = dir.x * rapidez + impulso.x
	velocity.z = dir.z * rapidez + impulso.z
	move_and_slide()
	if not is_on_floor() and not agachado and _sin_agarre <= 0.0 and velocity.y < 3.0:
		_buscar_cornisa()


# --- Parkour ---------------------------------------------------------------------------------------

func _rayo(desde: Vector3, hasta: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(desde, hasta, collision_mask, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q)


## Busca una cornisa delante (hacia donde mira el cuerpo): un muro casi vertical a la altura del pecho o de la cabeza y,
## encima, un borde horizontal dentro del alcance de los brazos.
func _buscar_cornisa() -> void:
	var adelante := -global_transform.basis.z
	adelante.y = 0.0
	adelante = adelante.normalized()
	var pies := global_position
	for alto: float in [0.5, 1.0, 1.45, 1.9]:
		var desde := pies + Vector3.UP * alto
		var r := _rayo(desde, desde + adelante * AGARRE_ALCANCE)
		if r.is_empty():
			continue
		var n: Vector3 = r.normal
		if absf(n.y) > 0.35:
			continue
		n.y = 0.0
		n = n.normalized()
		if adelante.dot(-n) < 0.5:
			continue
		# El borde: rayo hacia abajo un poco dentro del muro, desde por encima del alcance. Si arriba tambien hay muro el
		# rayo nace dentro de la pieza y no da nada: no hay cornisa.
		var dentro: Vector3 = (r.position as Vector3) - n * 0.22
		var r2 := _rayo(Vector3(dentro.x, pies.y + AGARRE_ALTO.y + 0.3, dentro.z), Vector3(dentro.x, pies.y + AGARRE_ALTO.x, dentro.z))
		if r2.is_empty() or (r2.normal as Vector3).y < 0.7:
			continue
		var p: Vector3 = r2.position
		var h := p.y - pies.y
		if h < AGARRE_ALTO.x or h > AGARRE_ALTO.y:
			continue
		if h < SIN_COLGARSE:
			# Borde a la altura del pecho o mas bajo: se apoya y sube de una vez.
			borde = p
			normal_muro = n
			velocity = Vector3.ZERO
			_subir()
		else:
			_agarrar(p, n, r.position)
		return


func _agarrar(punto: Vector3, n: Vector3, cara: Vector3) -> void:
	estado = Estado.COLGADO
	borde = punto
	normal_muro = n
	_cara = cara
	velocity = Vector3.ZERO
	impulso = Vector3.ZERO
	rotation.y = atan2(n.x, n.z)   # de cara al muro
	var meta := Vector3(cara.x, punto.y - COLGADO_PIES, cara.z) + n * SEPARACION
	create_tween().tween_property(self, "global_position", meta, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _soltar(vel: Vector3) -> void:
	estado = Estado.NORMAL
	velocity = vel
	_sin_agarre = 0.35
	_coyote = 0.0


func _colgado(delta: float) -> void:
	var eje := Input.get_vector("izquierda", "derecha", "adelante", "atras")
	if Input.is_action_just_pressed("saltar"):
		if eje.y > 0.3:
			_soltar(normal_muro * SALTO_ATRAS + Vector3.UP * SALTO)   # salto hacia atras
		else:
			_subir()
		return
	if Input.is_action_just_pressed("adelante"):
		_subir()
		return
	if Input.is_action_just_pressed("agacharse") or Input.is_action_just_pressed("atras"):
		_soltar(normal_muro * 0.6)
		return
	if absf(eje.x) < 0.2:
		return
	# Por la cornisa: solo si el borde sigue, hay muro delante y el cuerpo no choca con nada.
	var derecha := (-normal_muro).cross(Vector3.UP)
	var paso := derecha * signf(eje.x) * LATERAL * delta
	var nuevo := borde + paso
	var r := _rayo(nuevo + Vector3.UP * 0.35, nuevo + Vector3.DOWN * 0.35)
	if r.is_empty() or (r.normal as Vector3).y < 0.7:
		return
	var pecho := global_position + paso + Vector3.UP * 1.45
	if _rayo(pecho, pecho - normal_muro * (SEPARACION + 0.3)).is_empty():
		return
	if test_move(global_transform, paso):
		return
	borde = Vector3(nuevo.x, (r.position as Vector3).y, nuevo.z)   # el mismo palmo dentro del muro
	global_position += paso
	global_position.y = borde.y - COLGADO_PIES


## Sube a pulso: el cuerpo sube hasta el borde y avanza sobre el. Si arriba no cabe de pie, sube agachado; si tampoco,
## se queda colgado.
func _subir() -> void:
	var destino := borde - normal_muro * 0.5 + Vector3.UP * 0.03
	if _choca_en(destino, ALTURA.x):
		if _choca_en(destino, ALTURA.y):
			return
		agachado = true
		_poner_altura(ALTURA.y)
	estado = Estado.SUBIENDO
	var arriba := Vector3(global_position.x, borde.y + 0.05, global_position.z)
	var tw := create_tween()
	tw.tween_property(self, "global_position", arriba, SUBIR_SEG.x).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "global_position", destino, SUBIR_SEG.y).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void:
		estado = Estado.NORMAL
		velocity = Vector3.ZERO
		_sin_agarre = 0.3)


## Vuelve al estado normal (al teletransportarlo: miradores, pruebas), de pie y sin velocidad.
func reiniciar() -> void:
	estado = Estado.NORMAL
	velocity = Vector3.ZERO
	impulso = Vector3.ZERO
	_sin_agarre = 0.3


## Si la capsula de `alto` m con los pies en `pies` choca con algo.
func _choca_en(pies: Vector3, alto: float) -> bool:
	var forma := CapsuleShape3D.new()
	forma.radius = _capsula.radius
	forma.height = alto
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	q.transform = Transform3D(Basis(), pies + Vector3.UP * (alto * 0.5 + 0.02))
	q.collision_mask = collision_mask
	q.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _process(dt: float) -> void:
	var s := AnimProc.resorte(esprint, _esprint_v, 1.0 if _esprintando else 0.0, 0.12, dt)
	esprint = clampf(s[0], 0.0, 1.0)
	_esprint_v = s[1]
	camara.fov = fov_base + patada_fov + ESPRINT_FOV * esprint
	var a := AnimProc.resorte(agacharse, _agacharse_v, 1.0 if agachado else 0.0, 0.08, dt)
	agacharse = clampf(a[0], 0.0, 1.0)
	_agacharse_v = a[1]
	cabeza.position.y = lerpf(OJOS.x, OJOS.y, agacharse)
	var c := AnimProc.resorte(colgado, _colgado_v, 1.0 if estado == Estado.COLGADO else (0.6 if estado == Estado.SUBIENDO else 0.0), 0.08, dt)
	colgado = clampf(c[0], 0.0, 1.0)
	_colgado_v = c[1]


## Capsula de `alto` m con los pies en el origen del jugador.
func _poner_altura(alto: float) -> void:
	_capsula.height = alto
	_col.position.y = alto * 0.5
