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
# Venas de oro bajo la piel (PielVenas): al usar un poder se hinchan y encienden desde la mano hacia el codo con el esfuerzo
# del gesto y luego vuelven a su tamaño de reposo; el brazo sin poder solo acompana.
var venas_base := 0.5   # lo fija el juego: 0 sin poderes, 0.5 con poderes, sube hacia 1 con el Caos (el Monstruo)
var mana := 1.0         # 0..1; lo fija el juego. Con el mana vacio el oro se apaga.
var _piel: ShaderMaterial
var _crec := 0.0
var _crec_v := 0.0
# Salto: las manos se quedan atras al despegar y flotan en el aire (ligereza); al aterrizar se hunden con el cuerpo y suben
# despacio, sin rebote, como al caer en tierra o pasto (peso). Un resorte sobre la altura de las manos; `cuerpo` lo asigna
# quien monta las manos.
const SALTO_AIRE := -0.006       # m de desplazamiento por m/s de velocidad vertical en el aire (subiendo bajan, cayendo suben)
const SALTO_TOPE := 0.035        # m: lo maximo que flotan o se quedan atras en el aire
const SALTO_IMPACTO := 0.3       # m/s que recibe el resorte por cada m/s de caida al tocar el suelo
# El aterrizaje pesa segun la caida: de poca altura es corto y ligero; desde SALTO_CAIDA_MAX (la de un salto normal en
# plano) es el mas pesado, y caer de mas alto no lo pasa.
const SALTO_CAIDA_MAX := 5.0     # m/s
const SALTO_SUELO_HZ := 1.6      # aterrizaje pesado: mas bajo = se hunden y suben mas despacio
const SALTO_SUELO_AMORT := 0.8   # aterrizaje pesado: < 1 rebota (0,35 era un rebote seco), ~1 ni rebota
const SALTO_LIGERO_HZ := 4.0     # aterrizaje de poca altura
const SALTO_LIGERO_AMORT := 0.7
const SALTO_CABECEO := 0.9       # rad por m: al hundirse, las munecas se inclinan hacia abajo
var cuerpo: CharacterBody3D
var _salto_y := 0.0
var _salto_v := 0.0
var _en_suelo := true
var _vy := 0.0
var _peso_caida := 1.0   # 0..1: cuanto pesa el ultimo aterrizaje


func montar(e: Dictionary) -> void:
	for h in get_children():
		remove_child(h)
		h.queue_free()
	_anim = null
	_sk = null
	_gestos_anim = {}
	_clip_activo = ""
	_piel = null
	_crec = 0.0
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
	if e.has("piel"):
		# Piel densa horneada con la red de venas (herramientas/hornear_piel.gd) y su shader, con la textura que ya tenia.
		for m: MeshInstance3D in raiz.find_children("*", "MeshInstance3D", true, false):
			if m.skin != null:
				var antes := (m.material_override if m.material_override != null else m.mesh.surface_get_material(0)) as StandardMaterial3D
				var densa: Mesh = load(e.piel)
				m.set_meta("malla_original", m.mesh)
				m.mesh = densa
				_piel = PielVenas.material(antes.albedo_texture, float(densa.get_meta("m_por_u", 1.0)))
				m.material_override = _piel
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
		raiz.position += (e.get("manos_en", Vector3(0, -0.28, -0.42)) as Vector3) - en_manos


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


## En el aire: resorte blando (las manos flotan, ligeras). En el suelo: al tocarlo, el resorte recibe un golpe hacia abajo
## proporcional a la velocidad de caida (con tope) y se vuelve mas lento cuanto mas fuerte fue la caida: de poca altura se
## hunden poco y vuelven rapido; tras un salto normal se hunden con peso y suben despacio, sin rebotar.
func _salto(dt: float) -> void:
	if cuerpo == null:
		return
	var en_suelo := cuerpo.is_on_floor()
	var vy := cuerpo.velocity.y
	if en_suelo and not _en_suelo:
		var caida := clampf(-_vy, 0.0, SALTO_CAIDA_MAX)
		_peso_caida = caida / SALTO_CAIDA_MAX
		_salto_v -= caida * SALTO_IMPACTO
	_en_suelo = en_suelo
	_vy = vy
	var objetivo := 0.0 if en_suelo else clampf(vy * SALTO_AIRE, -SALTO_TOPE, SALTO_TOPE)
	var frec := lerpf(SALTO_LIGERO_HZ, SALTO_SUELO_HZ, _peso_caida) if en_suelo else 2.2       # Hz
	var amort := lerpf(SALTO_LIGERO_AMORT, SALTO_SUELO_AMORT, _peso_caida) if en_suelo else 0.8
	var w := TAU * frec
	# Subpasos fijos: con un frame largo (un tiron, una captura) el resorte explicito explotaria.
	var resto := minf(dt, 0.1)
	while resto > 0.0:
		var h := minf(resto, 1.0 / 240.0)
		_salto_v += (-w * w * (_salto_y - objetivo) - 2.0 * amort * w * _salto_v) * h
		_salto_y += _salto_v * h
		resto -= h


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
	_salto(dt)
	position = Vector3(_sway.x + resp.x, _sway.y + resp.y + _salto_y, 0.0)
	rotation.x = _salto_y * SALTO_CABECEO

	if _piel != null:
		var p := progreso()
		var meta := clampf(AnimProc.curva_esfuerzo(p), 0.0, 1.0) if p >= 0.0 else 0.0
		var sv := AnimProc.resorte(_crec, _crec_v, meta, 0.12, dt)
		_crec = maxf(sv[0], 0.0)
		_crec_v = sv[1]
		_piel.set_shader_parameter("venas_base", venas_base)
		_piel.set_shader_parameter("crecimiento", _crec)
		_piel.set_shader_parameter("crecimiento_otro", _crec * 0.3)
		_piel.set_shader_parameter("brillo", AnimProc.brillo_venas(_tiempo, p, mana))
		_piel.set_shader_parameter("brillo_otro", AnimProc.brillo_venas(_tiempo, -1.0, mana))
