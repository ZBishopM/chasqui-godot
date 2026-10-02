class_name GestosLib
extends RefCounted
## Fabrica clips de gesto "pose a pose" (reposo -> pico -> reposo) como recursos `Animation` editables en el editor de Godot.
## La forma temporal es la `curva_esfuerzo` de la version web (anticipacion, pico tardio, aguante, rebote), y cada hueso
## se interpola por cuaternion: pose(p) = reposo * (reposo^-1 * pico)^w(p), con w fuera de [0,1] en la anticipacion y el rebote.

const MUESTRAS := 28


## Huesos que deforman la malla (se dejan fuera los de control IK, la camara y las puntas).
static func huesos_utiles(sk: Skeleton3D) -> Array[int]:
	var r: Array[int] = []
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		if n == "root" or n == "camera" or n.ends_with("_end") or "IK" in n or "control" in n or n.begins_with("arm_target"):
			continue
		r.append(i)
	return r


static func pose_actual(sk: Skeleton3D, huesos: Array[int]) -> Dictionary:
	var d := {}
	for i in huesos:
		d[i] = sk.get_bone_pose_rotation(i)
	return d


## Pose de todos los huesos en el instante `t` de un clip del propio AnimationPlayer.
static func muestrear(ap: AnimationPlayer, sk: Skeleton3D, clip: String, t: float, huesos: Array[int]) -> Dictionary:
	ap.active = true
	ap.play(clip)
	ap.seek(t, true)
	ap.advance(0.0)
	return pose_actual(sk, huesos)


## Suma de angulos (grados) entre dos poses: cuanto se parecen.
static func distancia(a: Dictionary, b: Dictionary) -> float:
	var s := 0.0
	for i: int in a:
		s += rad_to_deg((a[i] as Quaternion).angle_to(b[i]))
	return s


## Instante del clip con la pose mas lejana a la de su propio comienzo: el apice del gesto.
static func tiempo_pico(ap: AnimationPlayer, sk: Skeleton3D, clip: String, huesos: Array[int], pasos: int = 40) -> float:
	var largo := ap.get_animation(clip).length
	var inicio := muestrear(ap, sk, clip, 0.0, huesos)
	var mejor_t := 0.0
	var mejor := -1.0
	for k in range(1, pasos + 1):
		var t := largo * k / pasos
		var d := distancia(inicio, muestrear(ap, sk, clip, t, huesos))
		if d > mejor:
			mejor = d
			mejor_t = t
	return mejor_t


## Peso reposo->pico (0 = reposo, 1 = pico) en el progreso p del gesto.
##  - "esfuerzo": la curva del dolor de la version web (pico tardio, aguante, recuperacion con rebote). Va bien con giros
##    chicos; con giros de ~100 grados el rebote se mueve a >1000 grados/s y se siente seco.
##  - "suave": sube con ease-in-out, aguanta y baja con ease-in-out, sin rebote (pico de velocidad ~1,5 x giro / tiempo).
static func peso(p: float, forma: String) -> float:
	if forma == "esfuerzo":
		return AnimProc.curva_esfuerzo(p)
	if p < 0.12:
		return -0.05 * smoothstep(0.0, 0.12, p)
	if p < 0.45:
		var s := (p - 0.12) / 0.33
		return -0.05 + 1.05 * (s * s * (3.0 - 2.0 * s))
	if p < 0.6:
		return 1.0
	var r := (p - 0.6) / 0.4
	return 1.0 - r * r * (3.0 - 2.0 * r)


## Animation de `dur` segundos: reposo -> pico -> reposo con la forma elegida. Las rutas de pista son relativas a `raiz`
## (la raiz del modelo, que es donde apunta root_node del AnimationPlayer).
static func clip_pose_a_pose(raiz: Node, sk: Skeleton3D, huesos: Array[int], reposo: Dictionary, pico: Dictionary, dur: float, forma: String = "suave") -> Animation:
	var a := Animation.new()
	a.length = dur
	var base := str(raiz.get_path_to(sk))
	var pistas := {}
	for i in huesos:
		var pista := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(pista, NodePath("%s:%s" % [base, sk.get_bone_name(i)]))
		a.track_set_interpolation_type(pista, Animation.INTERPOLATION_LINEAR)
		pistas[i] = pista
	for k in range(MUESTRAS + 1):
		var p := float(k) / MUESTRAS
		var w := peso(p, forma) if k < MUESTRAS else 0.0
		for i in huesos:
			var q0: Quaternion = reposo[i]
			var delta: Quaternion = (q0.inverse() * (pico[i] as Quaternion)).normalized()
			if delta.w < 0.0:
				delta = -delta   # camino corto
			var q := q0
			var s := sqrt(maxf(0.0, 1.0 - delta.w * delta.w))
			if s > 0.0001:   # si no, el hueso no se mueve y el eje no esta definido
				var eje := Vector3(delta.x, delta.y, delta.z) / s
				q = q0 * Quaternion(eje, 2.0 * acos(clampf(delta.w, -1.0, 1.0)) * w)
			a.rotation_track_insert_key(pistas[i], p * dur, q)
	return a


## Copia el clip `nombre` de un AnimationPlayer como Animation independiente (el original, dentro del GLB, es de solo lectura).
static func copiar_clip(ap: AnimationPlayer, nombre: String, repetir: bool) -> Animation:
	var a := ap.get_animation(nombre).duplicate() as Animation
	a.loop_mode = Animation.LOOP_LINEAR if repetir else Animation.LOOP_NONE
	return a


## Guarda una escena envoltorio `Node3D > modelo + AnimationPlayer "Gestos"` para abrirla en el editor y editar los clips.
static func guardar_escena(ruta_escena: String, ruta_modelo: String, nombre_modelo: String, lib: AnimationLibrary, lib_orig: AnimationLibrary) -> int:
	var raiz := Node3D.new()
	raiz.name = "Manos"
	var modelo := (load(ruta_modelo) as PackedScene).instantiate()
	modelo.name = nombre_modelo
	raiz.add_child(modelo)
	modelo.owner = raiz
	var ap := AnimationPlayer.new()
	ap.name = "Gestos"
	raiz.add_child(ap)
	ap.owner = raiz
	ap.root_node = NodePath("../" + nombre_modelo)
	ap.add_animation_library("", lib)
	if lib_orig != null:
		ap.add_animation_library("originales", lib_orig)
	var ps := PackedScene.new()
	var e := ps.pack(raiz)
	if e != OK:
		return e
	var r := ResourceSaver.save(ps, ruta_escena)
	raiz.free()
	return r
