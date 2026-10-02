extends CharacterBody3D
## Chasqui en primera persona: capsula + cabeza + camara FOV 90 (M9 de la version web).

const VELOCIDAD := 5.0
const SALTO := 5.0
const SENSIBILIDAD := 0.0025
const FOV := 90.0

var cabeza: Node3D
var camara: Camera3D
var impulso := Vector3.ZERO  # empuje horizontal extra (Halcon); decae solo


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
	var dir := (transform.basis * Vector3(eje.x, 0.0, eje.y)).normalized()
	impulso = impulso.move_toward(Vector3.ZERO, 60.0 * delta)
	velocity.x = dir.x * VELOCIDAD + impulso.x
	velocity.z = dir.z * VELOCIDAD + impulso.z
	move_and_slide()
