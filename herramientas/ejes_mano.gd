class_name EjesMano
extends RefCounted
## Ejes de rotacion con SENTIDO, calculados de la geometria del rig en su postura de reposo, para posar una mano sin conocer
## como orientó sus huesos quien la modelo. Cada grado de libertad se define por el movimiento que produce ("el dedo se
## dobla hacia la palma", "el brazo sube"), no por un eje X/Y/Z: el rig de OpenGameArt y el de WRAD tienen ejes distintos.
##
## Convencion: todo se razona en el espacio de la VISTA (arriba = +Y, adelante = -Z, derecha = +X) y se baja al eje local del
## hueso. Una rotacion de +theta sobre el eje devuelto mueve la direccion del hueso hacia el destino; la pose resultante es
## reposo * R(eje_local, theta), que es como Skeleton3D compone la rotacion de pose.

const PESO_FALANGE := [1.0, 0.9, 0.7]
## Cuanto se separa cada dedo al abrir la mano (+ hacia el lado del indice, - hacia el del menique).
const ABRIR_DEDO := [1.0, 0.3, -0.5, -1.0]
## Desfase de cada dedo en la "ola" (0 = el indice empieza primero).
const OLA_DEDO := [0.2, 0.5, 0.8, 1.0]

var sk: Skeleton3D
var vista: Basis
var h: Dictionary
var izq: bool


## `h`: nombres de huesos: brazo, antebrazo, muneca, palma_medio, palma_indice, palma_menique, dedos (patrones con %d),
## pulgar (patron con %d) y punta (patron con %s para el hueso de la tercera falange).
func _init(esqueleto: Skeleton3D, yaw_grados: float, huesos: Dictionary, es_izquierda: bool = true) -> void:
	sk = esqueleto
	vista = Basis(Vector3.UP, deg_to_rad(yaw_grados))
	h = huesos
	izq = es_izquierda


func i(nombre: String) -> int:
	return sk.find_bone(nombre)


func pos(hueso: int) -> Vector3:
	return vista * sk.get_bone_global_pose(hueso).origin


func base(hueso: int) -> Basis:
	return vista * sk.get_bone_global_pose(hueso).basis.orthonormalized()


## Eje (en el espacio local del hueso) que lleva la direccion `dir` hacia `destino` con un giro positivo.
func hacia(hueso: int, dir: Vector3, destino: Vector3) -> Vector3:
	var e := dir.normalized().cross(destino.normalized())
	if e.length() < 0.001:
		return Vector3.ZERO
	return (base(hueso).inverse() * e.normalized()).normalized()


func eje_largo(hueso: int, dir: Vector3) -> Vector3:
	return (base(hueso).inverse() * dir.normalized()).normalized()


# --- geometria de la mano --------------------------------------------------------------------

func normal_palma() -> Vector3:
	var d := (pos(i(h.palma_medio)) - pos(i(h.muneca))).normalized()
	var l := lado()
	var n := d.cross(l).normalized()
	return n if izq else -n   # mano izquierda: n = d x l; derecha: l x d


## Del menique hacia el indice.
func lado() -> Vector3:
	return (pos(i(h.palma_indice)) - pos(i(h.palma_menique))).normalized()


func adentro() -> Vector3:
	return Vector3.RIGHT if izq else Vector3.LEFT


func _seg(patron: String, falange: int) -> Array[int]:
	# [hueso, siguiente] de una falange; la tercera apunta a su punta.
	var a := i(patron % falange)
	var b := i(patron % (falange + 1)) if falange < 3 else i(h.punta % (patron % 3))
	return [a, b]


## Direccion de una falange: hacia la siguiente o, si la punta no tiene hueso (H3 no trae `_end`), su eje Y local, que en
## los rigs de Blender va a lo largo del hueso.
func _dir_seg(s: Array[int]) -> Vector3:
	return pos(s[1]) - pos(s[0]) if s[1] >= 0 else base(s[0]) * Vector3.UP


# --- grados de libertad ----------------------------------------------------------------------

## spec: grado_de_libertad -> grados. Devuelve hueso -> [eje_local, grados] acumulables.
func rotaciones(spec: Dictionary) -> Dictionary:
	var r := {}
	var br := i(h.brazo)
	var ab := i(h.antebrazo)
	var mu := i(h.muneca)
	var dir_br := pos(ab) - pos(br)
	var dir_ab := pos(mu) - pos(ab)
	var dir_mu := pos(i(h.palma_medio)) - pos(mu)
	var n := normal_palma()
	var l := lado()
	for clave: String in spec:
		var g: float = spec[clave]
		match clave:
			"brazo_elevar":
				_sumar(r, br, hacia(br, dir_br, Vector3.UP), g)
			"brazo_barrer":
				_sumar(r, br, hacia(br, dir_br, adentro()), g)
			"brazo_adelante":
				_sumar(r, br, hacia(br, dir_br, Vector3.FORWARD), g)
			"antebrazo_elevar":
				_sumar(r, ab, hacia(ab, dir_ab, Vector3.UP), g)
			"antebrazo_barrer":
				_sumar(r, ab, hacia(ab, dir_ab, adentro()), g)
			"antebrazo_girar":
				_sumar(r, ab, eje_largo(ab, dir_ab), g)
			"muneca_flex":
				_sumar(r, mu, hacia(mu, dir_mu, n), g)
			"muneca_abrir":
				_sumar(r, mu, hacia(mu, dir_mu, l), g)
			"dedos_flex":
				_dedos(r, n, l, g, false, false)
			"dedos_abrir":
				_dedos(r, n, l, g, true, false)
			"dedos_ola":
				_dedos(r, n, l, g, false, true)
			"pulgar_flex":
				for f in range(1, 4):
					var s := _seg(h.pulgar, f)
					_sumar(r, s[0], hacia(s[0], _dir_seg(s), n), g * PESO_FALANGE[f - 1])
	return r


func _dedos(r: Dictionary, n: Vector3, l: Vector3, g: float, abrir: bool, ola: bool) -> void:
	for k in (h.dedos as Array).size():
		var patron: String = h.dedos[k]
		for f in range(1, 4):
			var s := _seg(patron, f)
			var dir := _dir_seg(s)
			if abrir:
				if f == 1:
					_sumar(r, s[0], hacia(s[0], dir, l), g * ABRIR_DEDO[k])
			else:
				var peso: float = PESO_FALANGE[f - 1] * (OLA_DEDO[k] if ola else 1.0)
				_sumar(r, s[0], hacia(s[0], dir, n), g * peso)


func _sumar(r: Dictionary, hueso: int, eje: Vector3, grados: float) -> void:
	if hueso < 0 or eje == Vector3.ZERO or absf(grados) < 0.001:
		return
	var q := Quaternion(eje, deg_to_rad(grados))
	var previo: Quaternion = r.get(hueso, Quaternion.IDENTITY)
	r[hueso] = q * previo   # ejes fijos en el marco de reposo: el ultimo giro se aplica despues


## Pose completa: el reposo con las rotaciones de `spec` aplicadas encima.
func pose(reposo: Dictionary, spec: Dictionary) -> Dictionary:
	var rot := rotaciones(spec)
	var p := reposo.duplicate()
	for hueso: int in rot:
		if p.has(hueso):
			p[hueso] = (reposo[hueso] as Quaternion) * (rot[hueso] as Quaternion)
	return p


## Ejes locales de los huesos que deben temblar (espasmo): los dedos doblandose y la muneca. Hueso -> eje local.
func ejes_temblor() -> Dictionary:
	var spec := {"dedos_flex": 1.0, "muneca_flex": 1.0}
	var rot := rotaciones(spec)
	var e := {}
	for hueso: int in rot:
		var q: Quaternion = rot[hueso]
		var s := sqrt(maxf(0.0, 1.0 - q.w * q.w))
		if s > 0.0001:
			e[hueso] = Vector3(q.x, q.y, q.z) / s
	return e
