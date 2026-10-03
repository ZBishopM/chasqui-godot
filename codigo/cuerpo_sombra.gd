class_name CuerpoSombra
extends Node3D
## Cuerpo entero del Chasqui que solo proyecta sombra (la camara no lo ve): asi la sombra en el suelo es la de una persona
## y no la de dos brazos flotando (los brazos en primera persona no dan sombra, ver Manos). Es el maniqui de Quaternius
## (UAL) con sus animaciones, elegidas por el estado del jugador. Va colgado del jugador, no de la camara: gira con el
## cuerpo y no cabecea con la mirada.

const MODELO := "res://assets/personajes/ual/UAL1_Standard.glb"
const MEZCLA := 0.2      # s de cruce entre animaciones
const ATRAS := 0.12      # m que se retrasa el cuerpo para que la cabeza quede detras de la camara
const CICLOS := ["Idle", "Walk", "Jog_Fwd", "Sprint", "Crouch_Idle", "Crouch_Fwd", "Jump"]

var jugador: Jugador
var manos: Manos         # sus brazos dan la pose de los brazos de la sombra
var modelo: Node3D
var _ap: AnimationPlayer
var _actual := ""


func _ready() -> void:
	modelo = (load(MODELO) as PackedScene).instantiate()
	modelo.rotation_degrees.y = 180.0   # el maniqui mira a +Z; el jugador, a -Z
	modelo.position.z = ATRAS
	add_child(modelo)
	for m: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_ap = modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip: String in CICLOS:
		if _ap.has_animation(clip):
			_ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_poner("Idle")
	var brazos := BrazosSombra.new()
	brazos.cuerpo = self
	(modelo.find_child("Skeleton3D", true, false) as Skeleton3D).add_child(brazos)


func _process(_dt: float) -> void:
	if jugador == null:
		return
	var local := jugador.global_transform.basis.inverse() * jugador.velocity
	var vel := Vector2(local.x, local.z).length()
	var clip := "Idle"
	if not jugador.is_on_floor():
		clip = "Jump"
	elif jugador.agachado:
		clip = "Crouch_Fwd" if vel > 0.3 else "Crouch_Idle"
	elif vel > 0.3:
		clip = "Sprint" if jugador.esprint > 0.5 else "Jog_Fwd"
	_poner(clip)
	# Las animaciones solo van hacia delante: andando hacia atras se reproducen al reves.
	_ap.speed_scale = -1.0 if local.z > 0.3 and clip != "Jump" else 1.0


func _poner(clip: String) -> void:
	if clip != _actual and _ap.has_animation(clip):
		_ap.play(clip, MEZCLA)
		_actual = clip


## Los brazos del maniqui apuntan adonde apuntan los brazos en primera persona (brazo, antebrazo y mano, en el mundo), asi
## la sombra hace lo que se ve: levanta la mano en un poder, la adelanta en reposo. Corre despues de la animacion del
## maniqui (piernas, torso y cabeza siguen siendo suyos). No copia los puños ni el bombeo del esprint (CapasManos): la
## pose que se lee de los brazos es la de su animacion.
class BrazosSombra extends SkeletonModifier3D:
	const LADOS := {".L": "_l", ".R": "_r"}
	var cuerpo: CuerpoSombra

	func _process_modification_with_delta(_dt: float) -> void:
		var fp: Skeleton3D = cuerpo.manos._sk if cuerpo.manos != null else null
		if fp == null:
			return
		var sk := get_skeleton()
		for s: String in LADOS:
			var z: String = LADOS[s]
			_alinear(sk, "upperarm" + z, "lowerarm" + z, _p(fp, "forearm" + s) - _p(fp, "upper_arm" + s))
			_alinear(sk, "lowerarm" + z, "hand" + z, _p(fp, "hand" + s) - _p(fp, "forearm" + s))
			_alinear(sk, "hand" + z, "middle_01" + z, _p(fp, "f_middle.01" + s) - _p(fp, "hand" + s))

	func _p(sk: Skeleton3D, nombre: String) -> Vector3:
		return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(nombre)).origin

	## Gira el hueso `nombre` lo minimo para que apunte a su `hijo` en la direccion `destino` (mundo).
	func _alinear(sk: Skeleton3D, nombre: String, hijo: String, destino: Vector3) -> void:
		var i := sk.find_bone(nombre)
		var j := sk.find_bone(hijo)
		if i < 0 or j < 0 or destino.length() < 1e-5:
			return
		var d := (sk.global_transform.basis.orthonormalized().inverse() * destino).normalized()
		var actual := (sk.get_bone_global_pose(j).origin - sk.get_bone_global_pose(i).origin).normalized()
		var nueva := Basis(Quaternion(actual, d)) * sk.get_bone_global_pose(i).basis
		var padre := sk.get_bone_parent(i)
		var local := (sk.get_bone_global_pose(padre).basis.inverse() * nueva) if padre >= 0 else nueva
		sk.set_bone_pose_rotation(i, local.get_rotation_quaternion())
