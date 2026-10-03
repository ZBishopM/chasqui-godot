class_name Jugador
extends CharacterBody3D
## Chasqui en primera persona: capsula + cabeza + camara (M9 de la version web). Anda, esprinta (Mayus), salta y se agacha
## (Ctrl mantenido). Es el unico dueno del FOV de la camara: fov_base (el del rig de manos) + patada_fov (Halcon) + apertura
## al esprintar.

const VELOCIDAD := 5.0
const ESPRINT := 8.0          # m/s con Mayus, solo hacia delante
const ESPRINT_FOV := 15.0     # grados que se abre el FOV al esprintar
const AGACHADO_VEL := 2.5     # m/s agachado
const ALTURA := Vector2(1.8, 1.2)   # m de la capsula de pie / agachado
const OJOS := Vector2(1.6, 1.0)     # m de la camara de pie / agachado
const SALTO := 5.0
const SENSIBILIDAD := 0.0025
const FOV := 90.0

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
	# Agacharse con Ctrl mantenido; al soltar solo se levanta si cabe (si hay techo encima sigue agachado).
	if Input.is_action_pressed("agacharse") != agachado:
		if not agachado:
			agachado = true
			_poner_altura(ALTURA.y)
		elif not test_move(global_transform, Vector3.UP * (ALTURA.x - ALTURA.y)):
			agachado = false
			_poner_altura(ALTURA.x)

	if not is_on_floor():
		velocity += get_gravity() * delta
	elif Input.is_action_just_pressed("saltar") and not agachado:
		velocity.y = SALTO

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


func _process(dt: float) -> void:
	var s := AnimProc.resorte(esprint, _esprint_v, 1.0 if _esprintando else 0.0, 0.12, dt)
	esprint = clampf(s[0], 0.0, 1.0)
	_esprint_v = s[1]
	camara.fov = fov_base + patada_fov + ESPRINT_FOV * esprint
	var a := AnimProc.resorte(agacharse, _agacharse_v, 1.0 if agachado else 0.0, 0.08, dt)
	agacharse = clampf(a[0], 0.0, 1.0)
	_agacharse_v = a[1]
	cabeza.position.y = lerpf(OJOS.x, OJOS.y, agacharse)


## Capsula de `alto` m con los pies en el origen del jugador.
func _poner_altura(alto: float) -> void:
	_capsula.height = alto
	_col.position.y = alto * 0.5
