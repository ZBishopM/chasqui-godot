class_name Manos
extends Node3D
## Manos en primera persona: monta el candidato elegido y anima la izquierda con los gestos de poder.
## Capas: respiracion + sway de mirada (resorte) sobre este nodo; gesto de poder sobre el pivote izquierdo.

# Encaje calibrado en la version web (M19): caida 0 grados, yaw +-16, pos +-0.18/-0.20/-0.35, escala 1.55.
const POS_IZQ := Vector3(-0.18, -0.20, -0.35)
const POS_DER := Vector3(0.18, -0.20, -0.35)
const ESCALA := 1.55
const YAW := 16.0
# El pivote del gesto queda detras y debajo de la mano (hombro/codo fuera de cuadro): el brazo oscila, no gira sobre la muneca.
const ANCLA_BRAZO := Vector3(0, -0.12, 0.2)
const FALANGES := ["Indice", "Medio", "Anular", "Menique", "Pulgar"]
const PESO_FALANGE := [1.0, 0.8, 0.5]

signal gesto_terminado

var _rng := RandomNumberGenerator.new()
var _pivote_izq: Node3D
var _muneca: Node3D
var _dedos: Array = []          # Array de Array[Node3D]: cada dedo = [falange1, falange2, ...]
var _reposo: Dictionary = {}    # Node3D -> Transform3D del reposo
var _variante: Dictionary = {}
var _progreso := -1.0           # -1 = sin gesto
var _tiempo := 0.0
var _mirada := Vector2.ZERO
var _sway := Vector2.ZERO
var _sway_v := Vector2.ZERO
var _anim: AnimationPlayer
# Tipo skel_brazos: huesos de la mano izquierda y reposo por hueso.
var _sk: Skeleton3D
var _huesos_izq: Array[int] = []
var _dedos_huesos: Array = []
var _reposo_hueso: Dictionary = {}
var _tiene_skel_gesto := false


func _ready() -> void:
	_rng.randomize()


func montar(e: Dictionary) -> void:
	for h in get_children():
		remove_child(h)
		h.queue_free()
	_reposo.clear()
	_dedos.clear()
	_pivote_izq = null
	_muneca = null
	_anim = null
	_sk = null
	_huesos_izq = []
	_dedos_huesos = []
	_reposo_hueso.clear()
	_tiene_skel_gesto = false
	_progreso = -1.0
	match e.tipo:
		"propia":
			_montar_propia(e)
		"skel_brazos":
			_montar_skel(e)


func _montar_propia(e: Dictionary) -> void:
	for lado in 2:
		var izq := lado == 0
		var pivote := Node3D.new()
		pivote.position = (POS_IZQ if izq else POS_DER) + ANCLA_BRAZO
		add_child(pivote)
		# Los glb vienen espejados respecto al giro de 180 grados que los pone mirando a -Z: cada pivote usa el archivo del otro lado.
		var mano: Node3D = (load(e.rutas[1 - lado]) as PackedScene).instantiate()
		mano.position = -ANCLA_BRAZO
		mano.scale = Vector3.ONE * ESCALA
		mano.rotation_degrees = Vector3(0, 180.0 + (YAW if izq else -YAW), 0)
		pivote.add_child(mano)
		var rig: Node3D = mano.get_node("ManoRig/Muneca")
		var dedos: Array = []
		for dedo: String in FALANGES:
			var cadena: Array = []
			var n: Node3D = rig.get_node_or_null(dedo + "_1")
			while n != null:
				cadena.append(n)
				n = n.get_node_or_null(dedo + "_" + str(cadena.size() + 1))
			dedos.append(cadena)
		if not izq:
			# Mano derecha: puno cerrado empunando el Champi (los pulgares cierran menos).
			for i in dedos.size():
				for j in dedos[i].size():
					dedos[i][j].rotation.x += (1.15 if i < 4 else 0.5) * PESO_FALANGE[mini(j, 2)] + 0.2
		else:
			_pivote_izq = pivote
			_muneca = rig
			_dedos = dedos
			_guardar_reposo(pivote)
			_guardar_reposo(rig)
			for cadena: Array in dedos:
				for n: Node3D in cadena:
					_guardar_reposo(n)


## Brazos con Skeleton3D de un solo mesh (H4). Se escala, se gira para mirar a -Z y se coloca por el punto medio de las manos.
## La animacion de muestra se congela en su primer cuadro: ese es el reposo sobre el que se suman los gestos (hueso izquierdo).
func _montar_skel(e: Dictionary) -> void:
	var raiz: Node3D = (load(e.rutas[0]) as PackedScene).instantiate()
	raiz.scale = Vector3.ONE * float(e.get("escala", 0.1))
	raiz.rotation_degrees.y = float(e.get("yaw", 180.0))
	add_child(raiz)
	if e.has("textura"):
		var piel := StandardMaterial3D.new()
		piel.albedo_texture = load(e.textura)
		_poner_material(raiz, piel)
	_anim = _buscar(raiz, "AnimationPlayer") as AnimationPlayer
	if _anim != null and _anim.get_animation_list().size() > 0:
		_anim.play(_anim.get_animation_list()[0])
		_anim.advance(0.0)
		_anim.active = false   # el reposo queda fijo; los gestos escriben sobre los huesos
	_sk = _buscar(raiz, "Skeleton3D") as Skeleton3D
	var izq := _sk.find_bone("hand.L")
	var der := _sk.find_bone("hand.R")
	var medio := (_sk.get_bone_global_pose(izq).origin + _sk.get_bone_global_pose(der).origin) * 0.5
	var en_manos := global_transform.affine_inverse() * (_sk.global_transform * medio)
	raiz.position += Vector3(0, -0.28, -0.42) - en_manos
	# Hueso izquierdo y sus dedos: el reposo se guarda para sumar deltas cada frame.
	_huesos_izq = [_sk.find_bone("upper_arm.L"), _sk.find_bone("hand.L")]
	for dedo in ["f_index", "f_middle", "f_ring", "f_pinky", "thumb"]:
		var cadena: Array[int] = []
		for n in ["01", "02", "03"]:
			var i := _sk.find_bone("%s.%s.L" % [dedo, n])
			if i >= 0:
				cadena.append(i)
		_dedos_huesos.append(cadena)
	for i in _sk.get_bone_count():
		_reposo_hueso[i] = _sk.get_bone_pose_rotation(i)
	_tiene_skel_gesto = true


func _poner_material(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
	for c in n.get_children():
		_poner_material(c, mat)


func _buscar(n: Node, clase: String) -> Node:
	if n.is_class(clase):
		return n
	for c in n.get_children():
		var r := _buscar(c, clase)
		if r != null:
			return r
	return null


func _guardar_reposo(n: Node3D) -> void:
	_reposo[n] = n.transform


func lanzar_gesto(poder: String) -> void:
	if _pivote_izq == null and not _tiene_skel_gesto:
		return
	_variante = AnimProc.variante_al_azar(poder, _rng)
	_progreso = 0.0


func hay_gesto() -> bool:
	return _progreso >= 0.0


## 0..1 del gesto en curso (para sincronizar luz/VFX con el dolor de la mano).
func progreso() -> float:
	return _progreso


## Duracion (s) del gesto que acaba de lanzarse; 0.4 si estas manos no tienen gesto.
func duracion() -> float:
	return float(_variante.duracion) if (_pivote_izq != null or _tiene_skel_gesto) and not _variante.is_empty() else 0.4


func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mirada += ev.relative


func _process(dt: float) -> void:
	_tiempo += dt
	# Sway: al girar, las manos rezagan al lado opuesto y un resorte las devuelve (M12).
	var objetivo := Vector2(clampf(-_mirada.x * 0.0006, -0.04, 0.04), clampf(_mirada.y * 0.0006, -0.04, 0.04))
	_mirada = Vector2.ZERO
	for i in 2:
		var s := AnimProc.resorte(_sway[i], _sway_v[i], objetivo[i], 0.12, dt)
		_sway[i] = s[0]
		_sway_v[i] = s[1]
	var resp := AnimProc.respiracion(_tiempo, 0.004)
	position = Vector3(_sway.x + resp.x, _sway.y + resp.y, 0.0)

	if _progreso >= 0.0 and (_pivote_izq != null or _tiene_skel_gesto):
		_progreso += dt / float(_variante.duracion)
		if _progreso >= 1.0:
			_progreso = -1.0
			_restaurar()
			gesto_terminado.emit()
		else:
			_restaurar()
			_aplicar_gesto()


func _restaurar() -> void:
	for n: Node3D in _reposo:
		n.transform = _reposo[n]
	for i: int in _reposo_hueso:
		_sk.set_bone_pose_rotation(i, _reposo_hueso[i])


## Mismo gesto sobre huesos: brazo y muneca izquierdos + dedos. Los ejes locales de cada rig difieren; es una aproximacion de demo.
func _aplicar_gesto_skel() -> void:
	var v := _variante
	var r := AnimProc.curva_esfuerzo(_progreso)
	var dolor: float = AnimProc.espasmo(_progreso, v.seed) * float(v.espasmo)
	var tb := AnimProc.TB
	var brazo: Vector3 = (v.rot as Vector3) * r + Vector3(dolor * tb, dolor * tb * 0.6, dolor * tb * 1.2)
	_girar_hueso(_huesos_izq[0], brazo)
	_girar_hueso(_huesos_izq[1], Vector3(float(v.muneca) * r + dolor * tb, 0, 0))
	var n := _dedos_huesos.size()
	var ola_env := sin(PI * _progreso)
	for i in n:
		var cadena: Array = _dedos_huesos[i]
		for j in cadena.size():
			var w: float = PESO_FALANGE[mini(j, 2)]
			var ang := 0.0
			match v.dedos:
				"apreton":
					ang = (float(v.dedo_amt) * r + dolor * tb * 0.8) * w
				"abanico":
					ang = (-float(v.dedo_amt) * 0.4 * r + dolor * tb * 0.3) * w
				_:
					ang = (sin(_progreso * PI * 3.0 + i * 0.5) * float(v.dedo_amt) * ola_env + dolor * tb * 0.4) * w
			_girar_hueso(cadena[j], Vector3(ang, 0, 0))


func _girar_hueso(i: int, euler: Vector3) -> void:
	if i >= 0:
		_sk.set_bone_pose_rotation(i, _reposo_hueso[i] * Quaternion.from_euler(euler))


## Suma deltas sobre el reposo (port de aplicarGesto en GestoPoder.ts).
func _aplicar_gesto() -> void:
	if _tiene_skel_gesto:
		_aplicar_gesto_skel()
		return
	var v := _variante
	var r := AnimProc.curva_esfuerzo(_progreso)
	var dolor: float = AnimProc.espasmo(_progreso, v.seed) * float(v.espasmo)
	var tb := AnimProc.TB
	_pivote_izq.rotation += (v.rot as Vector3) * r + Vector3(dolor * tb, dolor * tb * 0.6, dolor * tb * 1.2)
	_pivote_izq.position += (v.pos as Vector3) * r + Vector3(dolor * 0.006, 0, 0)
	_muneca.rotation.x += float(v.muneca) * r + dolor * tb

	var n := _dedos.size()
	var ola_env := sin(PI * _progreso)
	for i in n:
		var cadena: Array = _dedos[i]
		for j in cadena.size():
			var d: Node3D = cadena[j]
			var w: float = PESO_FALANGE[mini(j, 2)]
			match v.dedos:
				"apreton":
					d.rotation.x += (float(v.dedo_amt) * r + dolor * tb * 0.8) * w
				"abanico":
					d.rotation.x += (-float(v.dedo_amt) * 0.4 * r + dolor * tb * 0.3) * w
					if j == 0:
						d.rotation.z += (i - (n - 1) / 2.0) * 0.12 * float(v.dedo_amt) * r
				_:
					var desfase := i * 0.5
					d.rotation.x += (sin(_progreso * PI * 3.0 + desfase) * float(v.dedo_amt) * ola_env + dolor * tb * 0.4) * w
