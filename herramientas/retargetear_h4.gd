extends SceneTree
## Copia a H4 (OpenGameArt fps arms) la pose de reposo y los gestos de H3 (escenas/manos_h3.tscn), cuadro a cuadro, y guarda
## la escena editable escenas/manos_h4.tscn (pisa la que genera generar_h4.gd; vuelve a esa ejecutando aquel script).
##   godot.console.exe --headless --path . --script res://herramientas/retargetear_h4.gd
##
## Los dos rigs nombran y orientan distinto sus huesos, asi que no se copian rotaciones sino DIRECCIONES en el mundo: cada
## hueso de H4 gira lo minimo para apuntar adonde apunta el suyo en H3 (brazo, antebrazo, palma, falanges); la mano copia
## ademas hacia donde mira la palma. En H4 la mano no cuelga del antebrazo (cuelga de `hand.L.control`, un control de IK
## que Godot no resuelve): por eso aqui se la pega a la muneca en cada cuadro, y por eso sus gestos de antes se veian raros.
## Imprime `manos_en` para el catalogo: donde quedan las munecas de H3 respecto al ojo, para encuadrar H4 igual.

const H3 := "res://escenas/manos_h3.tscn"
const FBX := "res://assets/manos/oga_fps_arms/arms_anim.fbx"
const ESCENA := "res://escenas/manos_h4.tscn"
const FPS := 30.0
const CLIPS := ["reposo", "halcon", "sapo", "amaru", "condor", "puma", "colibri"]
const DEDOS := ["f_index", "f_middle", "f_ring", "f_pinky"]
const PALMA_H3 := {"f_index": "palm.01", "f_middle": "palm.02", "f_ring": "palm.03", "f_pinky": "palm.04"}
const PALMA_H4 := {"f_index": "palm_index", "f_middle": "palm_middle", "f_ring": "palm_ring", "f_pinky": "palm_pinky"}
## Grados que el antebrazo y la mano giran sobre el eje del antebrazo (pronacion) para que se vea mas el dorso de la mano.
## Se suma a todos los clips, asi los gestos salen del mismo reposo. 0 = igual que H3.
const GIRO_DORSO := 20.0

var sk3: Skeleton3D
var sk4: Skeleton3D


func _initialize() -> void:
	var e3: Dictionary = Catalogo.MANOS.filter(func(e: Dictionary) -> bool: return e.id == "H3")[0]
	var e4: Dictionary = Catalogo.MANOS.filter(func(e: Dictionary) -> bool: return e.id == "H4")[0]
	var r3: Node3D = (load(H3) as PackedScene).instantiate()
	r3.scale = Vector3.ONE * float(e3.escala)
	r3.rotation_degrees.y = float(e3.yaw)
	root.add_child(r3)
	var r4: Node3D = (load(FBX) as PackedScene).instantiate()
	r4.scale = Vector3.ONE * float(e4.escala)
	r4.rotation_degrees.y = float(e4.yaw)
	root.add_child(r4)
	await process_frame
	var ap3 := r3.get_node("Gestos") as AnimationPlayer
	for otro in r3.find_children("*", "AnimationPlayer", true, false):
		if otro != ap3:
			(otro as AnimationPlayer).active = false
	var ap4 := r4.find_child("AnimationPlayer", true, false) as AnimationPlayer
	ap4.active = false
	sk3 = r3.find_child("Skeleton3D", true, false) as Skeleton3D
	sk4 = r4.find_child("Skeleton3D", true, false) as Skeleton3D
	_comprobar()

	var lib := AnimationLibrary.new()
	for clip: String in CLIPS:
		lib.add_animation(clip, _clip(r4, ap3, clip))
		print("%s: %.2f s" % [clip, ap3.get_animation(clip).length])

	# Encuadre: donde quedan las munecas de H3 respecto a su ojo (hueso `camera` + desplazo), en el reposo.
	ap3.play("reposo")
	ap3.seek(0.0, true)
	ap3.advance(0.0)
	sk3.force_update_all_bone_transforms()
	var medio := (_p3("hand.L") + _p3("hand.R")) * 0.5
	print("manos_en para H4 = ", medio - _p3("camera") + (e3.desplazo as Vector3))

	var muestra := ap4.get_animation_list()[0]
	var originales := AnimationLibrary.new()
	originales.add_animation(muestra.replace("|", "_"), GestosLib.copiar_clip(ap4, muestra, true))
	var e := GestosLib.guardar_escena(ESCENA, FBX, r4.name, lib, originales)
	print("escena guardada: ", ESCENA, " (codigo ", e, ")")
	quit(0 if e == OK else 1)


## El clip `clip` de H3 copiado a H4 cuadro a cuadro.
func _clip(r4: Node3D, ap3: AnimationPlayer, clip: String) -> Animation:
	var huesos := GestosLib.huesos_utiles(sk4)
	var manos := [sk4.find_bone("hand.L"), sk4.find_bone("hand.R")]
	var base := str(r4.get_path_to(sk4))
	var a3 := ap3.get_animation(clip)
	var largo := a3.length
	var a := Animation.new()
	a.length = largo
	a.loop_mode = a3.loop_mode
	var rot := {}
	for i in huesos:
		rot[i] = a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(rot[i], NodePath("%s:%s" % [base, sk4.get_bone_name(i)]))
	var pos := {}
	for i: int in manos:
		pos[i] = a.add_track(Animation.TYPE_POSITION_3D)
		a.track_set_path(pos[i], NodePath("%s:%s" % [base, sk4.get_bone_name(i)]))
	for k in maxi(2, ceili(largo * FPS) + 1):
		var t := minf(k / FPS, largo)
		ap3.play(clip)
		ap3.seek(t, true)
		ap3.advance(0.0)
		sk3.force_update_all_bone_transforms()
		var d := _fuente_h3()
		sk4.reset_bone_poses()
		sk4.force_update_all_bone_transforms()
		for s in [".L", ".R"]:
			_copiar_lado(s, d)
		for i in huesos:
			a.rotation_track_insert_key(rot[i], t, sk4.get_bone_pose_rotation(i))
		for i: int in manos:
			a.position_track_insert_key(pos[i], t, sk4.get_bone_pose_position(i))
	return a


## La pose actual de H3 con los nombres de H4. Los huesos punta de H3 no tienen hijo: su `_end` se pone sobre su eje Y.
func _fuente_h3() -> Dictionary:
	var d := {}
	for s in [".L", ".R"]:
		for n in ["upper_arm", "forearm", "hand"]:
			d[n + s] = _p3(n + s)
		d["forearm" + s + "_end"] = _p3("hand" + s)
		for dedo: String in DEDOS:
			d[PALMA_H4[dedo] + s] = _p3(PALMA_H3[dedo] + s)
		for dedo: String in DEDOS + ["thumb"]:
			for f in ["01", "02", "03"]:
				d["%s.%s%s" % [dedo, f, s]] = _p3("%s.%s%s" % [dedo, f, s])
			var punta := "%s.03%s" % [dedo, s]
			d[punta + "_end"] = _p3(punta) + _eje_y3(punta) * 0.01
	return d


## Un brazo de H4 copia la pose fuente `d`: direcciones del brazo y el antebrazo, mano (palma + muneca) y cada falange.
## Antes, la mano de la fuente gira GIRO_DORSO sobre el eje del antebrazo (el izquierdo y el derecho en espejo), y el
## antebrazo de H4 gira lo mismo para que la muneca no se retuerza.
func _copiar_lado(s: String, d: Dictionary) -> void:
	var codo: Vector3 = d["forearm" + s]
	var eje: Vector3 = (d["forearm" + s + "_end"] - codo).normalized()
	var giro := Quaternion(eje, deg_to_rad(GIRO_DORSO) * (1.0 if s == ".L" else -1.0))
	var g := {}
	for n: String in d:
		g[n] = codo + giro * (d[n] - codo) if s in n and not n.begins_with("upper_arm") else d[n]
	d = g
	_alinear("upper_arm" + s, "forearm" + s, d["forearm" + s] - d["upper_arm" + s])
	_alinear("forearm" + s, "forearm" + s + "_end", d["forearm" + s + "_end"] - d["forearm" + s])
	_rotar_mundo(sk4.find_bone("forearm" + s), giro)
	_mano(s, d)
	for dedo: String in DEDOS:
		_alinear(PALMA_H4[dedo] + s, dedo + ".01" + s, d[dedo + ".01" + s] - d[PALMA_H4[dedo] + s])
		_cadena(dedo, s, d)
	_cadena("thumb", s, d)


func _cadena(dedo: String, s: String, d: Dictionary) -> void:
	for f in ["01", "02", "03"]:
		var n := "%s.%s%s" % [dedo, f, s]
		var hijo := "%s.03%s_end" % [dedo, s] if f == "03" else "%s.0%d%s" % [dedo, int(f) + 1, s]
		_alinear(n, hijo, d[hijo] - d[n])


## La mano: gira para que su marco (hacia los dedos, normal de la palma) sea el de la fuente y se coloca en la muneca de H4.
func _mano(s: String, d: Dictionary) -> void:
	var m3 := _marco(d["hand" + s], d["f_middle.01" + s], d["f_index.01" + s], d["f_pinky.01" + s])
	var m4 := _marco(_p4("hand" + s), _p4("f_middle.01" + s), _p4("f_index.01" + s), _p4("f_pinky.01" + s))
	var i := sk4.find_bone("hand" + s)
	_rotar_mundo(i, Quaternion(m3 * m4.inverse()))
	var g := sk4.get_bone_global_pose(i)
	g.origin = sk4.get_bone_global_pose(sk4.find_bone("forearm" + s + "_end")).origin
	var p := sk4.get_bone_parent(i)
	var local := (sk4.get_bone_global_pose(p).affine_inverse() * g) if p >= 0 else g
	sk4.set_bone_pose_position(i, local.origin)
	sk4.force_update_all_bone_transforms()


func _marco(muneca: Vector3, medio: Vector3, indice: Vector3, menique: Vector3) -> Basis:
	var y := (medio - muneca).normalized()
	var z := y.cross(indice - menique).normalized()
	return Basis(y.cross(z), y, z)


## Gira el hueso `nombre` de H4 lo minimo para que su direccion (hacia `hijo`) sea `destino` (mundo).
func _alinear(nombre: String, hijo: String, destino: Vector3) -> void:
	var i := sk4.find_bone(nombre)
	var j := sk4.find_bone(hijo)
	if i < 0 or j < 0:
		printerr("falta hueso en H4: ", nombre if i < 0 else hijo)
		return
	var actual := _p4(hijo) - _p4(nombre)
	if actual.length() < 1e-6 or destino.length() < 1e-6:
		return
	_rotar_mundo(i, Quaternion(actual.normalized(), destino.normalized()))


func _rotar_mundo(i: int, q_mundo: Quaternion) -> void:
	var b := sk4.global_transform.basis.orthonormalized()
	var q_sk := Basis(b.inverse() * Basis(q_mundo) * b)
	var nueva := q_sk * sk4.get_bone_global_pose(i).basis
	var p := sk4.get_bone_parent(i)
	var local := (sk4.get_bone_global_pose(p).basis.inverse() * nueva) if p >= 0 else nueva
	sk4.set_bone_pose_rotation(i, local.get_rotation_quaternion())
	sk4.force_update_all_bone_transforms()


func _p3(n: String) -> Vector3:
	return sk3.global_transform * sk3.get_bone_global_pose(sk3.find_bone(n)).origin


func _p4(n: String) -> Vector3:
	return sk4.global_transform * sk4.get_bone_global_pose(sk4.find_bone(n)).origin


## Direccion de un hueso hoja de H3 (sin hueso hijo): su eje Y local, que en los rigs de Blender va a lo largo del hueso.
func _eje_y3(n: String) -> Vector3:
	var i := sk3.find_bone(n)
	return (sk3.global_transform.basis * sk3.get_bone_global_pose(i).basis * Vector3.UP).normalized()


## Comprueba los supuestos: el eje Y va a lo largo del hueso en H3, y en H4 la mano en reposo esta en la muneca.
func _comprobar() -> void:
	var d := (_p3("f_index.03.L") - _p3("f_index.02.L")).normalized()
	print("H3: eje Y de f_index.02.L vs direccion al hijo: cos = %.3f" % _eje_y3("f_index.02.L").dot(d))
	print("H4: mano.L a muneca en reposo: %.4f m" % _p4("hand.L").distance_to(_p4("forearm.L_end")))
