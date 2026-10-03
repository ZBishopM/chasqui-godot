class_name Jugador
extends CharacterBody3D
## Chasqui en primera persona: capsula + cabeza + camara (M9 de la version web). Anda, esprinta (Mayus) y salta.
## Es el unico dueno del FOV de la camara: fov_base (el del rig de manos) + patada_fov (Halcon) + apertura al esprintar.

const VELOCIDAD := 5.0
const ESPRINT := 8.0          # m/s con Mayus, solo hacia delante
const ESPRINT_FOV := 15.0     # grados que se abre el FOV al esprintar
const SALTO := 5.0
const SENSIBILIDAD := 0.0025
const FOV := 90.0

var cabeza: Node3D
var camara: Camera3D
var impulso := Vector3.ZERO  # empuje horizontal extra (Halcon); decae solo
var fov_base := FOV          # lo fija el banco segun el rig de manos
var patada_fov := 0.0        # grados extra que anima el Halcon (0 -> 16 -> 0)
var esprint := 0.0           # 0..1 suavizado: manos, FOV y cuerpo lo siguen
var _esprint_v := 0.0
var _esprintando := false


func _ready() -> void:
	var col := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.height = 1.8
	capsula.radius = 0.35
	col.shape = capsula
	col.position.y = 0.9
	add_child(col)

	cabeza = Node3D.new()
	cabeza.position.y = 1.6
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
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif Input.is_action_just_pressed("saltar"):
		velocity.y = SALTO

	var eje := Input.get_vector("izquierda", "derecha", "adelante", "atras")
	# En el aire se conserva el esprint con que se salto.
	if is_on_floor():
		_esprintando = Input.is_action_pressed("esprintar") and eje.y < -0.3
	var dir := (transform.basis * Vector3(eje.x, 0.0, eje.y)).normalized()
	var rapidez := ESPRINT if _esprintando else VELOCIDAD
	impulso = impulso.move_toward(Vector3.ZERO, 60.0 * delta)
	velocity.x = dir.x * rapidez + impulso.x
	velocity.z = dir.z * rapidez + impulso.z
	move_and_slide()


func _process(dt: float) -> void:
	var s := AnimProc.resorte(esprint, _esprint_v, 1.0 if _esprintando else 0.0, 0.12, dt)
	esprint = clampf(s[0], 0.0, 1.0)
	_esprint_v = s[1]
	camara.fov = fov_base + patada_fov + ESPRINT_FOV * esprint
