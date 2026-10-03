class_name CapasManos
extends SkeletonModifier3D
## Capas procedurales encima de la animacion de las manos. Corre despues del AnimationPlayer (`Gestos`), asi que suma
## movimiento sin tocar los clips. Tics de reposo: de vez en cuando una mano tamborilea, se estira, aprieta, frota el
## pulgar o gira la muneca, para que las manos no parezcan congeladas.
## Los ejes de cada movimiento salen de EjesMano en la pose de reposo, asi que valen para cualquier rig (H3 y H4).

const TIC_ESPERA := Vector2(4.0, 9.0)   # s de reposo entre un tic y el siguiente (al azar en el rango)
const TIC_FUNDIDO := 0.15                # s en que un tic se apaga si empieza un gesto o el jugador se mueve
const TIC_AMPLITUD := 1.0                # escala de todos los angulos de los tics
const DURACION := {"tamborileo": 1.6, "estirar": 1.7, "apretar": 1.9, "pulgar": 1.6, "muneca": 1.5}
const LADOS := [".L", ".R"]
const GDL := ["dedos_flex", "dedos_abrir", "pulgar_flex", "muneca_flex", "muneca_abrir"]
const DEDOS := ["f_index", "f_middle", "f_ring", "f_pinky"]

var en_reposo := false   # lo fija Manos: sin gesto, quieto y en el suelo
var tic_actual := ""
var _ejes := {}          # lado -> gdl -> hueso -> Vector3 (eje local, largo = grados por grado del gdl)
var _dedo_de := {}       # hueso -> indice del dedo (0 indice .. 3 menique)
var _rng := RandomNumberGenerator.new()
var _espera := 0.0
var _lado := ".L"
var _t := 0.0
var _peso := 1.0


## Calcula los ejes con el esqueleto en su pose de reposo (llamar antes de anadir el modifier al esqueleto).
func preparar(sk: Skeleton3D, yaw_grados: float) -> void:
	_rng.randomize()
	_espera = _rng.randf_range(TIC_ESPERA.x, TIC_ESPERA.y)
	sk.force_update_all_bone_transforms()
	for s: String in LADOS:
		var nombres := {
			"brazo": "upper_arm" + s, "antebrazo": "forearm" + s, "muneca": "hand" + s,
			# los nudillos (y no los huesos de la palma) dan la direccion y el lado de la mano en los dos rigs
			"palma_medio": "f_middle.01" + s, "palma_indice": "f_index.01" + s, "palma_menique": "f_pinky.01" + s,
			"dedos": DEDOS.map(func(d: String) -> String: return d + ".0%d" + s),
			"pulgar": "thumb.0%d" + s, "punta": "%s_end",
		}
		var ejes := EjesMano.new(sk, yaw_grados, nombres, s == ".L")
		_ejes[s] = {}
		for gdl: String in GDL:
			var por_hueso := {}
			var rot := ejes.rotaciones({gdl: 1.0})
			for hueso: int in rot:
				var q: Quaternion = rot[hueso]
				var seno := sqrt(maxf(0.0, 1.0 - q.w * q.w))
				if seno > 1e-6:
					por_hueso[hueso] = Vector3(q.x, q.y, q.z) / seno * rad_to_deg(2.0 * acos(clampf(q.w, -1.0, 1.0)))
			_ejes[s][gdl] = por_hueso
		for k in DEDOS.size():
			for f in range(1, 4):
				_dedo_de[sk.find_bone("%s.0%d%s" % [DEDOS[k], f, s])] = k


## Lanza un tic ya (para probar). `nombre` = una clave de DURACION; `lado` = ".L" o ".R".
func tic(nombre: String, lado: String) -> void:
	tic_actual = nombre
	_lado = lado
	_t = 0.0
	_peso = 1.0


func _process_modification_with_delta(delta: float) -> void:
	if tic_actual == "":
		if en_reposo:
			_espera -= delta
			if _espera <= 0.0:
				tic(DURACION.keys()[_rng.randi() % DURACION.size()], LADOS[_rng.randi() % 2])
		else:
			_espera = _rng.randf_range(TIC_ESPERA.x, TIC_ESPERA.y)
		if tic_actual == "":
			return
	_t += delta
	if not en_reposo:
		_peso -= delta / TIC_FUNDIDO
	if _t >= float(DURACION[tic_actual]) or _peso <= 0.0:
		tic_actual = ""
		_espera = _rng.randf_range(TIC_ESPERA.x, TIC_ESPERA.y)
		return
	_aplicar(get_skeleton())


func _aplicar(sk: Skeleton3D) -> void:
	var p := _t / float(DURACION[tic_actual])
	var giros := {}   # hueso -> Quaternion
	for gdl: String in GDL:
		var por_hueso: Dictionary = _ejes[_lado][gdl]
		for hueso: int in por_hueso:
			var grados := _grados(gdl, _dedo_de.get(hueso, -1), p) * TIC_AMPLITUD * maxf(_peso, 0.0)
			if absf(grados) < 0.01:
				continue
			var v: Vector3 = por_hueso[hueso]
			var q := Quaternion(v.normalized(), deg_to_rad(grados * v.length()))
			giros[hueso] = (giros.get(hueso, Quaternion.IDENTITY) as Quaternion) * q
	for hueso: int in giros:
		sk.set_bone_pose_rotation(hueso, sk.get_bone_pose_rotation(hueso) * (giros[hueso] as Quaternion))


## Grados del grado de libertad `gdl` en el progreso `p` (0..1) del tic; `dedo` = 0 indice .. 3 menique (-1 si no es dedo).
func _grados(gdl: String, dedo: int, p: float) -> float:
	var e := smoothstep(0.0, 0.25, p) * (1.0 - smoothstep(0.65, 1.0, p))   # entra y sale suave
	var t := p * float(DURACION[tic_actual])
	match tic_actual:
		"tamborileo":   # dos pasadas del menique al indice, cada dedo un golpecito
			if gdl == "dedos_flex" and dedo >= 0:
				var g := 0.0
				for inicio in [0.1, 0.8]:
					var x := clampf((t - inicio - (3 - dedo) * 0.12) / 0.35, 0.0, 1.0)
					g += sin(PI * x) ** 2
				return 22.0 * g
		"estirar":      # abre y extiende los dedos, la muneca un poco atras
			return {"dedos_abrir": 12.0, "dedos_flex": -10.0, "pulgar_flex": -8.0, "muneca_flex": -7.0}.get(gdl, 0.0) * e
		"apretar":      # medio puno lento
			return {"dedos_flex": 32.0, "pulgar_flex": 10.0, "muneca_flex": 5.0}.get(gdl, 0.0) * e
		"pulgar":       # el pulgar frota el costado del indice
			if gdl == "pulgar_flex":
				return (8.0 + 8.0 * sin(TAU * 2.2 * t)) * e
			if gdl == "dedos_flex" and dedo == 0:
				return 10.0 * e
		"muneca":       # un circulo pequeno con la muneca
			if gdl == "muneca_flex":
				return 10.0 * sin(TAU * p) * e
			if gdl == "muneca_abrir":
				return 7.0 * (1.0 - cos(TAU * p)) * e
	return 0.0
