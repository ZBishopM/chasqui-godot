class_name Manos
extends Node3D
## Manos en primera persona: monta el candidato elegido (brazos con Skeleton3D) y reproduce los clips de gesto de cada poder.
## Capas: respiracion + sway de mirada (resorte) sobre este nodo; el gesto lo pone el AnimationPlayer `Gestos` de la escena.

const MEZCLA_ENTRADA := 0.15   # s: del reposo al gesto
const MEZCLA_SALIDA := 0.4     # s: del gesto al reposo (mas lenta: es lo que se notaba brusco)
## Huesos (convencion de Blender "Rigify" de H3 y H4): munecas para colocar el rig si no trae hueso de camara.
const HUESOS := {muneca = "hand.L", muneca_der = "hand.R", ojo = "camera"}

var _tiempo := 0.0
var _mirada := Vector2.ZERO
var _sway := Vector2.ZERO
var _sway_v := Vector2.ZERO
var _anim: AnimationPlayer
var _sk: Skeleton3D
# Cada poder reproduce un clip y luego vuelve al reposo.
var _gestos_anim: Dictionary = {}
var _anim_reposo := ""
var _dur_anim := 0.6
var _clip_activo := ""
# Venas de oro (una por brazo; la 0 es la del poder, la mano izquierda).
const CRECIMIENTO_REPOSO := 0.18
var mana := 1.0   # 0..1; lo fija el juego. Con el mana vacio el oro se apaga.
var _venas: Array[VenasOro] = []
var _crec := CRECIMIENTO_REPOSO
var _crec_v := 0.0


func montar(e: Dictionary) -> void:
	for h in get_children():
		remove_child(h)
		h.queue_free()
	_anim = null
	_sk = null
	_gestos_anim = {}
	_clip_activo = ""
	_venas.clear()
	_crec = CRECIMIENTO_REPOSO
	_crec_v = 0.0
	_montar_skel(e)


## Brazos con Skeleton3D de un solo mesh. Se escala, se gira para mirar a -Z y se coloca por el hueso de camara (o las manos).
func _montar_skel(e: Dictionary) -> void:
	var raiz: Node3D = (load(e.get("escena", e.rutas[0])) as PackedScene).instantiate()
	raiz.scale = Vector3.ONE * float(e.get("escala", 0.1))
	raiz.rotation_degrees.y = float(e.get("yaw", 180.0))
	add_child(raiz)
	if e.has("textura"):
		var piel := StandardMaterial3D.new()
		piel.albedo_texture = load(e.textura)
		_poner_material(raiz, piel)
	# Escena editable (`Gestos` = AnimationPlayer con los clips del catalogo): se usa ella sola; el AnimationPlayer del
	# modelo importado se apaga para que dos reproductores no se pisen los huesos.
	_anim = raiz.get_node_or_null("Gestos") as AnimationPlayer
	if _anim != null:
		for otro in _buscar_todos(raiz, "AnimationPlayer"):
			if otro != _anim:
				(otro as AnimationPlayer).active = false
	else:
		_anim = _buscar(raiz, "AnimationPlayer") as AnimationPlayer
	_gestos_anim = e.get("gestos_anim", {})
	if _anim != null and _anim.get_animation_list().size() > 0:
		var reposo: String = e.get("anim_reposo", "")
		_anim_reposo = reposo if reposo != "" and _anim.has_animation(reposo) else _anim.get_animation_list()[0]
		_anim.get_animation(_anim_reposo).loop_mode = Animation.LOOP_LINEAR
		_anim.playback_default_blend_time = MEZCLA_ENTRADA
		_anim.play(_anim_reposo)
		_anim.advance(0.0)
	_sk = _buscar(raiz, "Skeleton3D") as Skeleton3D
	var cam_i := _sk.find_bone(HUESOS.ojo)
	if cam_i >= 0:
		# El rig trae un hueso de camara/cabeza: el ojo del jugador va ahi (mas el desplazo del catalogo).
		var ojo := global_transform.affine_inverse() * (_sk.global_transform * _sk.get_bone_global_pose(cam_i).origin)
		raiz.position += (e.get("desplazo", Vector3.ZERO) as Vector3) - ojo
	else:
		var medio := (_sk.get_bone_global_pose(_sk.find_bone(HUESOS.muneca)).origin + _sk.get_bone_global_pose(_sk.find_bone(HUESOS.muneca_der)).origin) * 0.5
		var en_manos := global_transform.affine_inverse() * (_sk.global_transform * medio)
		raiz.position += Vector3(0, -0.28, -0.42) - en_manos
	_montar_venas(e)


## `venas` en el catalogo: codo, muneca, dedos_base (nombres del brazo IZQUIERDO; el derecho sale cambiando .L por .R) y radios.
func _montar_venas(e: Dictionary) -> void:
	var cfg: Dictionary = e.get("venas", {})
	if cfg.is_empty() or _sk == null:
		return
	for izq in [true, false]:
		var v := VenasOro.new()
		v.radio_brazo = float(cfg.get("radio_brazo", v.radio_brazo))
		v.radio_mano = float(cfg.get("radio_mano", v.radio_mano))
		v.grosor = float(cfg.get("grosor", v.grosor))
		v.engrosa = float(cfg.get("engrosa", v.engrosa))
		v.cantidad = int(cfg.get("cantidad", v.cantidad))
		v.semilla = 7 if izq else 11
		add_child(v)
		var dedos: Array[String] = []
		for n: String in cfg.dedos_base:
			dedos.append(n if izq else n.replace(".L", ".R"))
		var h := {
			"codo": cfg.codo if izq else (cfg.codo as String).replace(".L", ".R"),
			"muneca": cfg.muneca if izq else (cfg.muneca as String).replace(".L", ".R"),
			"dedos_base": dedos,
		}
		v.construir(_sk, h, izq)
		_venas.append(v)


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


func _buscar_todos(n: Node, clase: String) -> Array[Node]:
	var r: Array[Node] = []
	if n.is_class(clase):
		r.append(n)
	for c in n.get_children():
		r.append_array(_buscar_todos(c, clase))
	return r


func lanzar_gesto(poder: String) -> void:
	var clip: String = _gestos_anim.get(poder, "")
	if clip == "" or not _anim.has_animation(clip):
		return
	var a := _anim.get_animation(clip)
	a.loop_mode = Animation.LOOP_NONE
	_dur_anim = a.length
	_clip_activo = clip
	_anim.play(clip, MEZCLA_ENTRADA)
	if not _anim.animation_finished.is_connected(_volver_al_reposo):
		_anim.animation_finished.connect(_volver_al_reposo)


## 0..1 del gesto en curso (para sincronizar luz/VFX con el dolor de la mano); -1 si no hay gesto.
func progreso() -> float:
	if _clip_activo != "" and _anim != null and _anim.current_animation == _clip_activo:
		return clampf(_anim.current_animation_position / maxf(_anim.current_animation_length, 0.001), 0.0, 1.0)
	return -1.0


func _volver_al_reposo(clip: StringName) -> void:
	if clip != _anim_reposo:
		_clip_activo = ""
		_anim.play(_anim_reposo, MEZCLA_SALIDA)


## Duracion (s) del ultimo gesto lanzado.
func duracion() -> float:
	return _dur_anim


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

	if not _venas.is_empty():
		# El oro crece desde la mano con el esfuerzo del gesto y se enciende con su dolor; en reposo respira.
		var p := progreso()
		var meta_crec := CRECIMIENTO_REPOSO
		if p >= 0.0:
			meta_crec += (1.0 - CRECIMIENTO_REPOSO) * clampf(AnimProc.curva_esfuerzo(p), 0.0, 1.0)
		var sv := AnimProc.resorte(_crec, _crec_v, meta_crec, 0.12, dt)
		_crec = sv[0]
		_crec_v = sv[1]
		_venas[0].crecimiento = _crec
		_venas[0].brillo = AnimProc.brillo_venas(_tiempo, p, mana)
		if _venas.size() > 1:   # el brazo sin poder solo acompana de lejos
			_venas[1].crecimiento = CRECIMIENTO_REPOSO + (_crec - CRECIMIENTO_REPOSO) * 0.3
			_venas[1].brillo = AnimProc.brillo_venas(_tiempo, -1.0, mana)
