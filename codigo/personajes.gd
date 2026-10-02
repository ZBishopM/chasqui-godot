class_name Personajes
extends RefCounted
## Fabrica de personajes segun la entrada del catalogo. Origen en los pies, ~1.8 m, mirando a +Z.
## Cada personaje devuelto lleva meta "anim" (AnimationPlayer o null) para poder pausarlo (Colibri) o reaccionar.

const KAYKIT_ANIMS := [
	"res://assets/personajes/kaykit/animaciones/Rig_Medium_General.glb",
	"res://assets/personajes/kaykit/animaciones/Rig_Medium_MovementBasic.glb",
]


static func crear(e: Dictionary) -> Node3D:
	var n: Node3D
	match e.tipo:
		"kaykit":
			n = _kaykit(e)
		"kenney":
			n = _kenney(e)
		"ubc":
			n = _ubc(e)
		"ual":
			n = _ual(e)
		_:
			n = _procedural()
	n.set_meta("entrada", e)
	return n


static func _kaykit(e: Dictionary) -> Node3D:
	var n: Node3D = (load(e.rutas[0]) as PackedScene).instantiate()
	var ap := AnimationPlayer.new()
	n.add_child(ap)
	ap.root_node = NodePath("..")
	var lib := AnimationLibrary.new()
	for ruta: String in KAYKIT_ANIMS:
		var src: Node = (load(ruta) as PackedScene).instantiate()
		var sap := src.find_child("AnimationPlayer", true, false) as AnimationPlayer
		for nombre in sap.get_animation_list():
			var a := sap.get_animation(nombre).duplicate() as Animation
			a.loop_mode = Animation.LOOP_LINEAR if nombre.begins_with("Idle") or nombre.begins_with("Walk") or nombre.begins_with("Run") else Animation.LOOP_NONE
			lib.add_animation(nombre, a)
		src.free()
	ap.add_animation_library("", lib)
	ap.play("Idle_A")
	n.set_meta("anim", ap)
	return n


const UAL := "res://assets/personajes/ual/UAL1_Standard.glb"


## Personaje Quaternius (sin animaciones propias): toma las 43 de la Universal Animation Library, que comparte esqueleto.
static func _ubc(e: Dictionary) -> Node3D:
	var n: Node3D = (load(e.rutas[0]) as PackedScene).instantiate()
	var ap := AnimationPlayer.new()
	n.add_child(ap)
	ap.root_node = NodePath("..")
	var src: Node = (load(UAL) as PackedScene).instantiate()
	var sap := src.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var lib := AnimationLibrary.new()
	for nombre in sap.get_animation_list():
		var a := sap.get_animation(nombre).duplicate() as Animation
		a.loop_mode = Animation.LOOP_LINEAR if nombre in ["Idle", "Walk", "Jog_Fwd", "Sprint", "Idle_Talking", "Idle_Torch"] else Animation.LOOP_NONE
		lib.add_animation(nombre, a)
	src.free()
	ap.add_animation_library("", lib)
	ap.play("Idle")
	n.set_meta("anim", ap)
	return n


static func _ual(e: Dictionary) -> Node3D:
	var n: Node3D = (load(e.rutas[0]) as PackedScene).instantiate()
	var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	ap.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
	ap.play("Idle")
	n.set_meta("anim", ap)
	return n


static func _kenney(e: Dictionary) -> Node3D:
	var n: Node3D = (load(e.rutas[0]) as PackedScene).instantiate()
	var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null:
		ap.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
		ap.play("idle")
	n.set_meta("anim", ap)
	return n


## Port simplificado de Humanoide.ts: cabeza, torso con tunica, brazos y piernas con pivote, vincha y macana.
static func _procedural() -> Node3D:
	var raiz := Node3D.new()
	var piel := _mat(Color(0.72, 0.5, 0.36))
	var tunica := _mat(Color(0.65, 0.18, 0.12))
	var oscuro := _mat(Color(0.2, 0.14, 0.1))

	var torso := _malla(BoxMesh.new(), tunica, Vector3(0, 1.2, 0))
	(torso.mesh as BoxMesh).size = Vector3(0.5, 0.6, 0.28)
	raiz.add_child(torso)
	var falda := _malla(CylinderMesh.new(), tunica, Vector3(0, 0.78, 0))
	(falda.mesh as CylinderMesh).top_radius = 0.24
	(falda.mesh as CylinderMesh).bottom_radius = 0.3
	(falda.mesh as CylinderMesh).height = 0.45
	raiz.add_child(falda)
	var cabeza := _malla(SphereMesh.new(), piel, Vector3(0, 1.72, 0))
	(cabeza.mesh as SphereMesh).radius = 0.14
	(cabeza.mesh as SphereMesh).height = 0.28
	raiz.add_child(cabeza)
	var vincha := _malla(CylinderMesh.new(), oscuro, Vector3(0, 1.78, 0))
	(vincha.mesh as CylinderMesh).top_radius = 0.145
	(vincha.mesh as CylinderMesh).bottom_radius = 0.145
	(vincha.mesh as CylinderMesh).height = 0.04
	raiz.add_child(vincha)

	for lado in [-1.0, 1.0]:
		raiz.add_child(_miembro(Vector3(0.32 * lado, 1.45, 0), 0.55, 0.06, piel))
		raiz.add_child(_miembro(Vector3(0.12 * lado, 0.55, 0), 0.55, 0.075, piel))
	var macana := _malla(CylinderMesh.new(), oscuro, Vector3(0.38, 1.0, 0.25))
	(macana.mesh as CylinderMesh).top_radius = 0.05
	(macana.mesh as CylinderMesh).bottom_radius = 0.03
	(macana.mesh as CylinderMesh).height = 0.7
	raiz.add_child(macana)
	raiz.set_meta("anim", null)
	return raiz


static func _miembro(pivote: Vector3, largo: float, radio: float, mat: Material) -> Node3D:
	var p := Node3D.new()
	p.position = pivote
	var m := _malla(CapsuleMesh.new(), mat, Vector3(0, -largo * 0.5, 0))
	(m.mesh as CapsuleMesh).radius = radio
	(m.mesh as CapsuleMesh).height = largo
	p.add_child(m)
	return p


static func _malla(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	return m


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m
