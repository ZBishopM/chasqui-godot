class_name Camino
extends Node3D
## Zona 2 del Nivel 1: el Qhapaq Ñan del pueblo al Templo del Sol (~840 m, ~85 m de subida), con el pozo y la cueva.
##
## - Calzada de 3,6 m de losas que sigue una curva por PUNTOS (trazado de coste minimo sobre el relieve real, con curvas
##   de herradura anadidas): sube por la ladera con escalinatas donde la pendiente pasa del 18 %, muros de contencion
##   donde va en terraplen y parapetos donde la caida pasa de 1,5 m.
## - Atajos: donde dos tramos del camino pasan cerca a distinta altura, una escalera de terrazas (de <= 2,4 m: se trepan
##   con el parkour) los une.
## - Tambo (posada del camino) y, junto a el, la plazuela del pozo: un pozo de 15 m (aqui despertara el Chasqui) que da a
##   una camara y a una cueva de ~150 m que sale a la ladera entre el pueblo y el camino.
## - Corrales de pirca a los lados del camino: escondites.
## Todo en coordenadas del mundo (+X este, -Z norte); la y es la del terreno.

const ANCHO := 3.6
const PASO := 2.0                 # m entre secciones de la calzada
const ESCALERA := 0.18            # pendiente a partir de la cual se dibujan peldanos
const CONTRAHUELLA := 0.2         # m por peldano
const PARAPETO := Vector2(1.5, 0.55)   # caida a partir de la que hay parapeto; alto del parapeto
## Puntos de paso (mundo): sale de la plaza por el callejon del este, rodea los andenes por el norte, sube en herraduras,
## pasa por el tambo y el pozo, y llega a la explanada del templo.
const PUNTOS := [
	Vector2(53.1, -22.0), Vector2(58.1, -53.6), Vector2(73.7, -56.2), Vector2(109.1, -49.5),
	Vector2(150, -65), Vector2(205, -95), Vector2(245, -68), Vector2(212, -40), Vector2(238, -2), Vector2(238, 45),
	Vector2(252, 82), Vector2(282, 104), Vector2(312, 126), Vector2(350, 158), Vector2(374, 182), Vector2(356, 208),
	Vector2(398, 236), Vector2(425, 288), Vector2(465, 305), Vector2(498, 280), Vector2(512, 266),
]
const POZO := Vector2(268.0, 112.0)
const POZO_HONDO := 15.0
const TAMBO := Vector2(301.0, 95.0)
## La cueva: del fondo del pozo a la boca en la ladera (mundo, xz).
const CUEVA := [Vector2(276, 118), Vector2(268, 112), Vector2(250, 104), Vector2(232, 90), Vector2(214, 72), Vector2(196, 60), Vector2(176, 46), Vector2(158, 33), Vector2(147, 25), Vector2(138, 18)]
const CORRALES := [Vector2(196, -64), Vector2(262, 22), Vector2(336, 128), Vector2(392, 206)]
const ROCAS := ["res://assets/plantas/namaqualand_boulder_02/namaqualand_boulder_02.gltf", "res://assets/plantas/namaqualand_boulder_05/namaqualand_boulder_05.gltf"]

var terreno: Terreno
## Donde acaba la calzada (pie de la escalinata del templo); si no se da, el ultimo de PUNTOS.
var destino := Vector2.INF
var miradores: Array[Dictionary] = []
## Donde despierta el Chasqui (fondo del pozo), para mas adelante.
var despertar: Marker3D

var _pts := PackedVector2Array()      # centro de la calzada cada PASO m
var _ys := PackedFloat32Array()       # altura de la losa
var _lados := PackedVector2Array()    # derecha de la marcha
var _dist := PackedFloat32Array()     # m recorridos
var _huellas: Array = []
var _rng := RandomNumberGenerator.new()
var _info := {}


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_rng.seed = 1533
	_trazar()
	var kit := KitInca.new()
	_calzada(kit)
	_atajos(kit)
	_tambo(kit)
	_pozo(kit)
	_corrales(kit)
	var tris := kit.triangulos()
	kit.construir(self, "camino")
	_cueva()
	terreno.pintar_obras(_huellas)
	print("camino: %.0f m de calzada, %.0f m de escalinata, %d atajos, cueva de %.0f m, %d triangulos, %d ms" % [
		_dist[_dist.size() - 1], _info.get("escalinata", 0.0), _info.get("atajos", 0), _info.get("cueva", 0.0), tris + int(_info.get("tris_cueva", 0)), Time.get_ticks_msec() - t0])


func _h(x: float, z: float) -> float:
	return terreno.altura(x, z)


static func _giro(dir: Vector2) -> float:
	# Basis(UP, giro) lleva +x local a (cos, 0, -sin): que apunte a dir.
	return atan2(-dir.y, dir.x)


func _mirador(nombre: String, pos: Vector3, mira: Vector3) -> void:
	miradores.append({"nombre": nombre, "pos": pos, "mira": mira})


# --- Trazado --------------------------------------------------------------------------------------

## Curva de Catmull-Rom por PUNTOS, muestreada cada PASO m, y altura de la losa: lo mas alto del suelo a lo ancho
## (asi nunca queda enterrada; donde la ladera cae, el camino va en terraplen con muro).
func _trazar() -> void:
	var puntos := PUNTOS.duplicate()
	if destino.is_finite():
		puntos[-1] = destino
	var p := [puntos[0]]
	p.append_array(puntos)
	p.append(puntos[-1])
	for k in range(1, p.size() - 2):
		var a: Vector2 = p[k - 1]
		var b: Vector2 = p[k]
		var c: Vector2 = p[k + 1]
		var d: Vector2 = p[k + 2]
		var n := maxi(1, int(b.distance_to(c) / PASO))
		for s in n:
			var t := float(s) / n
			_pts.append(0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t + (-a + 3.0 * b - 3.0 * c + d) * t * t * t))
	_pts.append(puntos[-1])
	var crudas := PackedFloat32Array()
	var recorrido := 0.0
	for i in _pts.size():
		var a := _pts[maxi(i - 1, 0)]
		var b := _pts[mini(i + 1, _pts.size() - 1)]
		var tg := (b - a).normalized()
		var lado := Vector2(-tg.y, tg.x)   # derecha de la marcha (con -Z al norte)
		_lados.append(lado)
		var hmax := -INF
		for o: float in [-ANCHO * 0.5, -ANCHO * 0.25, 0.0, ANCHO * 0.25, ANCHO * 0.5]:
			hmax = maxf(hmax, _h(_pts[i].x + lado.x * o, _pts[i].y + lado.y * o))
		crudas.append(hmax + 0.12)
		if i > 0:
			recorrido += _pts[i].distance_to(_pts[i - 1])
		_dist.append(recorrido)
	# Suaviza sin enterrar: el promedio de 5, pero nunca por debajo de la cruda.
	for i in crudas.size():
		var s := 0.0
		var n := 0
		for k in range(maxi(i - 2, 0), mini(i + 3, crudas.size())):
			s += crudas[k]
			n += 1
		_ys.append(maxf(crudas[i], s / n))


func _p3(i: int, o := 0.0, dy := 0.0) -> Vector3:
	var p := _pts[i] + _lados[i] * o
	return Vector3(p.x, _ys[i] + dy, p.y)


# --- Calzada --------------------------------------------------------------------------------------

func _calzada(kit: KitInca) -> void:
	var t := Transform3D.IDENTITY
	var hw := ANCHO * 0.5
	var escalinata := 0.0
	for i in _pts.size() - 1:
		var j := i + 1
		var largo := _pts[i].distance_to(_pts[j])
		if largo < 0.05:
			continue
		var dy := _ys[j] - _ys[i]
		var s0 := _dist[i]
		var s1 := _dist[j]
		if absf(dy) / largo <= ESCALERA:
			kit.cara("losa", t, [_p3(i, -hw), _p3(i, hw), _p3(j, hw), _p3(j, -hw)],
				[Vector2(s0, -hw), Vector2(s0, hw), Vector2(s1, hw), Vector2(s1, -hw)], _normal_losa(i, j))
		else:
			escalinata += largo
			_peldanos(kit, i, j)
		# Muros a los dos lados: bajan de la losa hasta bajo el suelo; con mucha caida, parapeto.
		for lado: float in [-1.0, 1.0]:
			var e0 := _p3(i, lado * hw)
			var e1 := _p3(j, lado * hw)
			var f0 := _h(e0.x, e0.z)
			var f1 := _h(e1.x, e1.z)
			var b0 := minf(f0, e0.y - 0.3) - 0.5
			var b1 := minf(f1, e1.y - 0.3) - 0.5
			var n := Vector3(_lados[i].x, 0.0, _lados[i].y) * lado
			var caida := maxf(e0.y - f0, e1.y - f1)
			var tope := PARAPETO.y if caida > PARAPETO.x else 0.0
			kit.cara("pirca", t, [Vector3(e0.x, b0, e0.z), Vector3(e1.x, b1, e1.z), Vector3(e1.x, e1.y + tope, e1.z), Vector3(e0.x, e0.y + tope, e0.z)],
				[Vector2(s0, b0), Vector2(s1, b1), Vector2(s1, e1.y + tope), Vector2(s0, e0.y + tope)], n)
			if tope > 0.0:
				# Parapeto: coronacion y cara de dentro (0,35 m de grueso).
				var g := -n * 0.35
				var a0 := e0 + Vector3.UP * tope
				var a1 := e1 + Vector3.UP * tope
				kit.cara("pirca", t, [a0, a1, a1 + g, a0 + g], [Vector2(s0, 0), Vector2(s1, 0), Vector2(s1, 0.35), Vector2(s0, 0.35)], Vector3.UP)
				kit.cara("pirca", t, [e0 + g, e1 + g, a1 + g, a0 + g], [Vector2(s0, e0.y), Vector2(s1, e1.y), Vector2(s1, a1.y), Vector2(s0, a0.y)], -n)
		var c := (_pts[i] + _pts[j]) * 0.5
		_huellas.append([c, Vector2(largo * 0.5 + 0.3, hw + 0.4), _giro(_pts[j] - _pts[i]), 1.0, 1.8])
	_info["escalinata"] = escalinata
	_mirador("camino_inicio", _p3(10, 0.0, 1.6), _p3(40, 0.0, 1.0))
	# La escalinata mas larga, vista desde abajo.
	var mejor := 0
	var racha := 0
	var inicio := 0
	for i in _pts.size() - 1:
		if absf(_ys[i + 1] - _ys[i]) / maxf(_pts[i].distance_to(_pts[i + 1]), 0.05) > ESCALERA:
			racha += 1
			if racha > mejor:
				mejor = racha
				inicio = i - racha + 1
		else:
			racha = 0
	var pie := maxi(inicio - 3, 0)
	_mirador("escalinata", _p3(pie, 0.0, 1.6), _p3(mini(inicio + mejor, _pts.size() - 1), 0.0, 1.0))
	_mirador("camino_alto", _p3(_pts.size() - 40, 0.0, 1.6), _p3(_pts.size() - 80, 0.0, -6.0))


func _normal_losa(i: int, j: int) -> Vector3:
	var n := (_p3(i, 1.0) - _p3(i, -1.0)).cross(_p3(j) - _p3(i))
	return -n.normalized() if n.y < 0.0 else n.normalized()


## Peldanos entre las secciones i y j (de la mas baja a la mas alta); la colision es la rampa lisa.
func _peldanos(kit: KitInca, i: int, j: int) -> void:
	var hw := ANCHO * 0.5
	var lo := i if _ys[i] <= _ys[j] else j
	var hi := j if lo == i else i
	var dy := _ys[hi] - _ys[lo]
	var m := maxi(1, ceili(dy / CONTRAHUELLA))
	var t := Transform3D.IDENTITY
	var sl := _dist[lo]
	var sh := _dist[hi]
	for k in m:
		var f0 := float(k) / m
		var f1 := float(k + 1) / m
		var y0 := _ys[lo] + dy * f0
		var y1 := _ys[lo] + dy * f1
		var l0 := _p3(lo, -hw).lerp(_p3(hi, -hw), f0)
		var r0 := _p3(lo, hw).lerp(_p3(hi, hw), f0)
		var l1 := _p3(lo, -hw).lerp(_p3(hi, -hw), f1)
		var r1 := _p3(lo, hw).lerp(_p3(hi, hw), f1)
		l0.y = y1
		r0.y = y1
		l1.y = y1
		r1.y = y1
		var sa := lerpf(sl, sh, f0)
		var sb := lerpf(sl, sh, f1)
		kit.cara("losa", t, [l0, r0, r1, l1], [Vector2(sa, -hw), Vector2(sa, hw), Vector2(sb, hw), Vector2(sb, -hw)], Vector3.UP, false)
		# Contrahuella: de y0 a y1 en el arranque del peldano, mirando hacia abajo de la escalera.
		var baja := Vector3(l0.x, y0, l0.z)
		var bajr := Vector3(r0.x, y0, r0.z)
		var hacia := (_p3(lo) - _p3(hi))
		hacia.y = 0.0
		kit.cara("silleria", t, [baja, bajr, r0, l0], [Vector2(-hw, y0), Vector2(hw, y0), Vector2(hw, y1), Vector2(-hw, y1)], hacia.normalized(), false)
	kit.colision_cara(t, [_p3(lo, -hw), _p3(lo, hw), _p3(hi, hw), _p3(hi, -hw)])


# --- Atajos ---------------------------------------------------------------------------------------

## Atajos: pares de puntos del camino a <= 60 m en linea recta, 5-22 m de altura de diferencia y al menos 20 m de camino
## ahorrado (sobre todo en las herraduras). Se unen con terrazas de pirca de <= 2,4 m que se suben con el parkour
## (cornisa) en lugar de dar la vuelta. Se eligen los dos que mas ahorran, sin solaparse.
func _atajos(kit: KitInca) -> void:
	var candidatos: Array = []   # [ahorro, i, j]
	for i in range(0, _pts.size(), 2):
		for j in range(i + 10, _pts.size(), 2):
			var recta := _pts[i].distance_to(_pts[j])
			var dh := _ys[j] - _ys[i]
			var ahorro := _dist[j] - _dist[i] - recta
			if recta < 60.0 and dh > 5.0 and dh < 22.0 and dh / recta < 0.6 and ahorro > 20.0:
				candidatos.append([ahorro, i, j])
	candidatos.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var usados: Array[int] = []
	var n := 0
	for cand: Array in candidatos:
		if n >= 2:
			break
		var libre := true
		for u in usados:
			libre = libre and absi(u - int(cand[1])) > 40 and absi(u - int(cand[2])) > 40
		if not libre:
			continue
		_atajo(kit, cand[1], cand[2])
		usados.append(cand[1])
		usados.append(cand[2])
		n += 1
	_info["atajos"] = n


func _atajo(kit: KitInca, i: int, j: int) -> void:
	var a := _pts[i] + _lados[i] * (ANCHO * 0.5) * signf(_lados[i].dot(_pts[j] - _pts[i]))
	var b := _pts[j] + _lados[j] * (ANCHO * 0.5) * signf(_lados[j].dot(_pts[i] - _pts[j]))
	var dir := (b - a).normalized()
	var largo := a.distance_to(b)
	var dh := _ys[j] - _ys[i]
	var pasos := maxi(2, ceili(dh / 2.4))
	var giro := _giro(dir)
	var ancho := 3.0
	var fondo := largo / pasos
	for k in pasos:
		# Terraza k: de a + dir*fondo*k a a + dir*fondo*(k+1), tapa subiendo hasta la del camino de arriba.
		var c := a + dir * fondo * (k + 0.5)
		var tapa := _ys[i] + dh * float(k + 1) / pasos
		var r := Rect2(-fondo * 0.5, -ancho * 0.5, fondo, ancho)
		var bajo := INF
		for f: float in [-0.5, 0.0, 0.5]:
			for g: float in [-0.5, 0.5]:
				var q := c + dir * fondo * f + Vector2(-dir.y, dir.x) * ancho * g
				bajo = minf(bajo, _h(q.x, q.y))
		tapa = maxf(tapa, _h(c.x, c.y) + 0.2)
		var t := Transform3D(Basis(Vector3.UP, giro), Vector3(c.x, 0.0, c.y))
		kit.plataforma(t, r, bajo - 0.6, tapa)
		_huellas.append([c, Vector2(fondo * 0.5, ancho * 0.5), giro, 1.0, 1.5])
	if not miradores.any(func(m: Dictionary) -> bool: return m.nombre == "atajo"):
		var p := a - dir * 6.0
		_mirador("atajo", Vector3(p.x, _h(p.x, p.y) + 1.6 + 0.3, p.y), Vector3(b.x, _ys[j], b.y))


# --- Tambo y pozo ---------------------------------------------------------------------------------

## Tambo: una kancha de posta junto al camino, con dos casas, fardos y aribalos, y portada hacia la calzada.
func _tambo(kit: KitInca) -> void:
	var i := _cercano(TAMBO)
	var dir := (_pts[mini(i + 1, _pts.size() - 1)] - _pts[maxi(i - 1, 0)]).normalized()
	var giro := _giro(dir)
	var b := Basis(Vector3.UP, giro)
	var r := Rect2(-10.0, -8.0, 20.0, 16.0)
	var rango := _rango(TAMBO, b, r)
	var tapa := rango.y + 0.25
	kit.plataforma(Transform3D(b, Vector3(TAMBO.x, 0.0, TAMBO.y)), r, rango.x - 0.6, tapa)
	_huellas.append([TAMBO, r.size * 0.5, giro, 1.0, 2.0])
	var t := Transform3D(b, Vector3(TAMBO.x, tapa, TAMBO.y))
	# Hacia que lado (z local) queda el camino: alli la portada.
	var hacia := b.inverse() * Vector3(_pts[i].x - TAMBO.x, 0.0, _pts[i].y - TAMBO.y)
	var s := signf(hacia.z)
	var g := 0.6
	var cerco := 2.3
	var zc := s * (8.0 - g * 0.5)
	# Frente (con portada) y fondo, y los costados entre ellos.
	var vp := [KitInca.vano(10.0, 1.4, 1.15, 0.0, 2.05)]
	if s > 0.0:
		kit.muro_entre("pirca", t, Vector3(-10, 0, zc), Vector3(10, 0, zc), cerco, g, vp)
	else:
		kit.muro_entre("pirca", t, Vector3(10, 0, zc), Vector3(-10, 0, zc), cerco, g, vp)
	# Costados: del frente hasta las casas del fondo (que cierran el resto con sus muros).
	for x: float in [-10.0 + g * 0.5, 10.0 - g * 0.5]:
		var a := Vector3(x, 0, -s * (8.0 - 5.4))
		var c := Vector3(x, 0, s * (8.0 - g))
		if (x > 0.0) == (s > 0.0):
			kit.muro_entre("pirca", t, c, a, cerco, g)
		else:
			kit.muro_entre("pirca", t, a, c, cerco, g)
	# Dos casas al fondo, de lado a lado, con el frente al patio.
	var giro_casa := Basis() if s > 0.0 else Basis(Vector3.UP, PI)
	var z_casa := -s * (8.0 - 2.7)
	kit.wasi(t * Transform3D(giro_casa, Vector3(-5.0, 0, z_casa)), 10.0, 5.4, 2.5, [0.0])
	kit.wasi(t * Transform3D(giro_casa, Vector3(5.0, 0, z_casa)), 10.0, 5.4, 2.5, [1.5])
	for k in 4:
		kit.aribalo(t * Transform3D(Basis(Vector3.UP, k * 1.3), Vector3(-7.0 + k * 0.7, 0, z_casa + s * 3.2)), 0.7)
	var tf := t * Transform3D(Basis(), Vector3(8.2, 0, s * 4.0))
	for alto in 2:
		kit.fardo(tf * Transform3D(Basis(), Vector3(0, alto * 0.55, 0)))
	_escalera_a(kit, t, Vector3(0.0, 0.0, s * 8.0), Vector3(0, 0, s), tapa)
	_mirador("tambo", t * Vector3(0, 1.6, s * 14.0), t * Vector3(0, 1.5, 0))


## Escalera desde el suelo hasta el borde de una plataforma: `borde` local a `t` (y = 0 en la tapa), `n` hacia fuera.
func _escalera_a(kit: KitInca, t: Transform3D, borde: Vector3, n: Vector3, tapa: float) -> void:
	var nw := t.basis * n
	var bw := t * borde
	var h := _h(bw.x + nw.x * 1.5, bw.z + nw.z * 1.5)
	if tapa - h < 0.2:
		return
	var fin := 0.0
	for k in 2:
		fin = ceili((tapa - h) / 0.26) * 0.34
		h = _h(bw.x + nw.x * fin, bw.z + nw.z * fin)
	var pie := bw + nw * fin
	kit.escalera("pirca", Transform3D(Basis(Vector3.UP, atan2(nw.x, nw.z)), Vector3(pie.x, h, pie.z)), 2.0, tapa - h)


## Plazuela del pozo: losa de 10 x 10 m sobre el suelo con el brocal en el centro; el pozo baja 15 m por un fuste de
## pirca hasta la camara de la cueva. El terreno se abre en la boca.
func _pozo(kit: KitInca) -> void:
	var r := Rect2(-5.0, -5.0, 10.0, 10.0)
	var rango := _rango(POZO, Basis(), r)
	var tapa := rango.y + 0.15
	var t := Transform3D(Basis(), Vector3(POZO.x, 0.0, POZO.y))
	kit.plataforma(t, r, rango.x - 0.6, tapa, [Rect2(-1.05, -1.05, 2.1, 2.1)])   # el hueco cabe dentro del brocal
	_huellas.append([POZO, Vector2(5, 5), 0.0, 1.0, 3.0])
	var tt := Transform3D(Basis(), Vector3(POZO.x, tapa, POZO.y))
	kit.anillo("pirca", tt, 1.25, 0.85, 0.5, 12, {}, 0.0)                       # brocal
	var fondo := _h(POZO.x, POZO.y) - POZO_HONDO
	_info["piso_pozo"] = fondo
	var techo := fondo + 4.0                                                    # techo de la camara
	kit.anillo("pirca", Transform3D(Basis(), Vector3(POZO.x, techo - 0.6, POZO.y)), 1.25, tapa - techo + 0.6, 0.5, 12, {}, 0.0)
	# Travesano de madera con su soga, sobre el brocal.
	kit.caja("madera", tt, Vector3(0, 1.95, 0), Vector3(3.0, 0.14, 0.14))
	for s: float in [-1.0, 1.0]:
		kit.caja("madera", tt, Vector3(s * 1.35, 1.0, 0), Vector3(0.14, 2.0, 0.14))
	kit.caja("madera", tt, Vector3(0, 0.6, 0), Vector3(0.03, 2.7, 0.03), "", false, false)
	terreno.abrir_hueco(POZO.x, POZO.y, 1.6)
	_mirador("pozo", tt * Vector3(-4.0, 1.6, 3.5), tt * Vector3(0, 0.5, 0))


func _corrales(kit: KitInca) -> void:
	for p: Vector2 in CORRALES:
		var radio := _rng.randf_range(4.0, 6.0)
		var rango := _rango(p, Basis(), Rect2(-radio, -radio, radio * 2.0, radio * 2.0))
		var giro := Basis(Vector3.UP, _rng.randf() * TAU)
		var alto := rango.y - rango.x + 1.6
		kit.anillo("pirca", Transform3D(giro, Vector3(p.x, rango.x - 0.3, p.y)), radio, alto, 0.5, 16, KitInca.vano(0.0, 1.2, 1.0, 0.0, alto - 0.4), 0.1)
		_huellas.append([p, Vector2(radio, radio), 0.0, 0.7, 2.0])


func _cercano(p: Vector2) -> int:
	var mejor := 0
	for i in _pts.size():
		if _pts[i].distance_squared_to(p) < _pts[mejor].distance_squared_to(p):
			mejor = i
	return mejor


## Altura minima y maxima del suelo bajo el rectangulo `r` (local) centrado en `c` y girado `b`.
func _rango(c: Vector2, b: Basis, r: Rect2) -> Vector2:
	var lo := INF
	var hi := -INF
	var nx := maxi(1, ceili(r.size.x / 2.0))
	var nz := maxi(1, ceili(r.size.y / 2.0))
	for j in nz + 1:
		for i in nx + 1:
			var l := b * Vector3(r.position.x + r.size.x * i / nx, 0.0, r.position.y + r.size.y * j / nz)
			var h := _h(c.x + l.x, c.y + l.z)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return Vector2(lo, hi)


# --- Cueva ----------------------------------------------------------------------------------------

## Tunel de roca del fondo del pozo a la ladera: anillos irregulares a lo largo de CUEVA (el primero, ancho, es la camara
## bajo el pozo), piso plano, oscuro lejos de las bocas (color de vertice). Donde el suelo de la ladera queda por debajo
## del techo, el tunel se abre en trinchera: el terreno se agujerea encima y la roca de los lados hace de pared.
func _cueva() -> void:
	var piso0: float = _info["piso_pozo"]
	var ruido := FastNoiseLite.new()
	ruido.seed = 7
	ruido.frequency = 0.35
	# Eje del tunel cada 1,2 m.
	var eje := PackedVector2Array()
	for k in CUEVA.size() - 1:
		var a: Vector2 = CUEVA[k]
		var b: Vector2 = CUEVA[k + 1]
		var n := maxi(1, int(a.distance_to(b) / 1.2))
		for s in n:
			eje.append(a.lerp(b, float(s) / n))
	eje.append(CUEVA[-1])
	var total := 0.0
	var largos := PackedFloat32Array([0.0])
	for k in range(1, eje.size()):
		total += eje[k].distance_to(eje[k - 1])
		largos.append(total)
	# Hasta donde llega: se corta cuando el piso queda por encima del suelo de fuera.
	var anillos: Array = []   # [centro Vector3, lado Vector3, rx, ry, piso, abierto (bool), m recorridos]
	var boca := -1
	var s_pozo := (CUEVA[0] as Vector2).distance_to(POZO)
	for k in eje.size():
		var piso := piso0 - 2.2 * largos[k] / total
		var hs := _h(eje[k].x, eje[k].y)
		if hs < piso + 0.15:
			break
		var tg := (eje[mini(k + 1, eje.size() - 1)] - eje[maxi(k - 1, 0)]).normalized()
		var camara := clampf(1.3 - absf(largos[k] - s_pozo) / 6.0, 0.0, 1.0)   # camara ancha bajo el pozo
		var rx := lerpf(1.9, 3.4, camara)
		var ry := lerpf(1.7, 2.6, camara)
		var abierto := hs < piso + ry * 2.0 + 0.8
		if abierto and boca < 0:
			boca = k
		anillos.append([Vector3(eje[k].x, piso + ry * 0.75, eje[k].y), Vector3(-tg.y, 0.0, tg.x), rx, ry, piso, abierto, largos[k]])
	_info["cueva"] = anillos[-1][6]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col := PackedVector3Array()
	var lados := 18
	var red: Array = []   # por anillo: [vertices, normales, abiertos]
	var fin: float = anillos[-1][6]
	for a: Array in anillos:
		var c: Vector3 = a[0]
		var lado: Vector3 = a[1]
		var vs := PackedVector3Array()
		var ns := PackedVector3Array()
		var fuera := []
		for q in lados:
			var f := TAU * q / lados
			var rx: float = a[2]
			var ry: float = a[3]
			var off := lado * cos(f) * rx + Vector3.UP * sin(f) * ry
			var p := c + off * (1.0 + 0.22 * ruido.get_noise_3d(c.x + off.x, c.y + off.y, c.z + off.z))
			var piso: float = a[4]
			var es_piso := p.y < piso
			if es_piso:
				p.y = piso + 0.04 * ruido.get_noise_2d(p.x * 3.0, p.z * 3.0)
			vs.append(p)
			ns.append(Vector3.UP if es_piso else (c - p).normalized())
			# Abierto: bajo el pozo (techo de la camara) o, en la trinchera de la boca, lo que asoma sobre el suelo.
			var bajo_pozo := Vector2(p.x - POZO.x, p.z - POZO.y).length() < 1.2 and sin(f) > 0.2
			var asoma: bool = a[5] and p.y > _h(p.x, p.z) - 0.1
			fuera.append(bajo_pozo or asoma)
		red.append([vs, ns, fuera])
	# Trinchera de la boca: el terreno se abre encima (un hueco cada dos anillos; caben 16 en total).
	for k in range(0, anillos.size(), 2):
		if anillos[k][5]:
			var c: Vector3 = anillos[k][0]
			terreno.abrir_hueco(c.x, c.z, 1.7, 2.6)   # la colision, mas ancha: la cubren el tunel y su faldon
	# Luz: oscuro lejos de las bocas (la del pozo al principio y la de la ladera al final).
	var luz := func(s: float) -> float:
		return clampf(maxf(1.0 - absf(s - s_pozo) / 14.0, 1.0 - (fin - s) / 22.0), 0.17, 1.0)
	for k in red.size() - 1:
		var A: Array = red[k]
		var B: Array = red[k + 1]
		var la: float = luz.call(anillos[k][6])
		var lb: float = luz.call(anillos[k + 1][6])
		for q in lados:
			var q2 := (q + 1) % lados
			if A[2][q] or A[2][q2] or B[2][q] or B[2][q2]:
				continue
			var v := [A[0][q], A[0][q2], B[0][q2], B[0][q]]
			var n := [A[1][q], A[1][q2], B[1][q2], B[1][q]]
			var l := [la, la, lb, lb]
			var u := [Vector2(float(q) / lados * 8.0, anillos[k][6] * 0.5), Vector2(float(q + 1) / lados * 8.0, anillos[k][6] * 0.5),
				Vector2(float(q + 1) / lados * 8.0, anillos[k + 1][6] * 0.5), Vector2(float(q) / lados * 8.0, anillos[k + 1][6] * 0.5)]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				# Caras hacia dentro: Godot ve de frente lo que gira en sentido horario; se ordena con la normal.
				var p0: Vector3 = v[tri[0]]
				var p1: Vector3 = v[tri[1]]
				var p2: Vector3 = v[tri[2]]
				var nm: Vector3 = (n[tri[0]] + n[tri[1]] + n[tri[2]])
				var orden: Array = [tri[0], tri[2], tri[1]] if (p1 - p0).cross(p2 - p0).dot(nm) > 0.0 else tri
				for o: int in orden:
					var g: float = l[o]
					st.set_color(Color(g, g, g))
					st.set_normal(n[o])
					st.set_uv(u[o])
					st.add_vertex(v[o])
					col.append(v[o])
	# Fondo de la camara (detras del pozo): tapa del primer anillo, mirando hacia el tunel.
	var c_fondo: Vector3 = anillos[0][0]
	var r0: Array = red[0]
	var hacia_tunel := (anillos[1][0] as Vector3) - c_fondo
	for q in lados:
		var q2 := (q + 1) % lados
		var tri := [c_fondo, r0[0][q], r0[0][q2]]
		var orden: Array = [0, 2, 1] if ((tri[1] as Vector3) - c_fondo).cross((tri[2] as Vector3) - c_fondo).dot(hacia_tunel) > 0.0 else [0, 1, 2]
		for o: int in orden:
			st.set_color(Color(0.5, 0.5, 0.5))
			st.set_normal(hacia_tunel.normalized())
			st.set_uv(Vector2((tri[o] as Vector3).x, (tri[o] as Vector3).y))
			st.add_vertex(tri[o])
			col.append(tri[o])
	# Faldon de colision alrededor de la trinchera: el terreno se agujerea algo mas de lo que se ve.
	for k in anillos.size() - 1:
		if not (anillos[k][5] and anillos[k + 1][5]):
			continue
		for s: float in [-1.0, 1.0]:
			var pa: Vector3 = anillos[k][0] + anillos[k][1] * s * anillos[k][2]
			var pb: Vector3 = anillos[k + 1][0] + anillos[k + 1][1] * s * anillos[k + 1][2]
			var qa: Vector3 = anillos[k][0] + anillos[k][1] * s * 4.5
			var qb: Vector3 = anillos[k + 1][0] + anillos[k + 1][1] * s * 4.5
			pa.y = _h(pa.x, pa.z)
			pb.y = _h(pb.x, pb.z)
			qa.y = _h(qa.x, qa.z)
			qb.y = _h(qb.x, qb.z)
			col.append_array(PackedVector3Array([pa, pb, qb, pa, qb, qa]))
	# Delante de la boca: el agujero de la colision pasa del final del tunel; un faldon que sigue el suelo lo cierra.
	var ce: Vector3 = anillos[-1][0]
	var de := ce - (anillos[maxi(anillos.size() - 3, 0)][0] as Vector3)
	de.y = 0.0
	de = de.normalized()
	var la := Vector3(-de.z, 0.0, de.x)
	for f in 4:
		for g in 4:
			var q := []
			for e: Vector2 in [Vector2(f, g), Vector2(f + 1, g), Vector2(f + 1, g + 1), Vector2(f, g + 1)]:
				var w := ce + de * (e.x * 1.8 - 1.5) + la * (e.y * 2.4 - 4.8)
				w.y = _h(w.x, w.z)
				q.append(w)
			col.append_array(PackedVector3Array([q[0], q[1], q[2], q[0], q[2], q[3]]))
	# Techo de la camara alrededor del pozo: al quitar el techo bajo el fuste queda un hueco mas ancho que el; un anillo
	# de roca plano, a la altura del pie del fuste, lo cierra (mirando hacia abajo).
	var y_techo: float = _info["piso_pozo"] + 3.4
	for q in 24:
		var a0 := TAU * q / 24.0
		var a1 := TAU * (q + 1) / 24.0
		var anillo_v := [Vector3(cos(a0) * 1.0, 0, sin(a0) * 1.0), Vector3(cos(a1) * 1.0, 0, sin(a1) * 1.0), Vector3(cos(a1) * 3.2, 0, sin(a1) * 3.2), Vector3(cos(a0) * 3.2, 0, sin(a0) * 3.2)]
		var vv := []
		for p: Vector3 in anillo_v:
			vv.append(Vector3(POZO.x, y_techo, POZO.y) + p)
		var orden: Array = [0, 1, 2, 0, 2, 3] if ((vv[1] as Vector3) - vv[0]).cross((vv[2] as Vector3) - vv[0]).y > 0.0 else [0, 2, 1, 0, 3, 2]
		for o: int in orden:
			st.set_color(Color(0.55, 0.55, 0.55))
			st.set_normal(Vector3.DOWN)
			st.set_uv(Vector2((vv[o] as Vector3).x, (vv[o] as Vector3).z))
			st.add_vertex(vv[o])
	var malla := st.commit()
	malla.surface_set_material(0, MaterialesInca.todos()["roca"])
	var mi := MeshInstance3D.new()
	mi.name = "cueva"
	mi.mesh = malla
	add_child(mi)
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "cueva_colision"
	var forma := ConcavePolygonShape3D.new()
	forma.backface_collision = true
	forma.set_faces(col)
	var cs := CollisionShape3D.new()
	cs.shape = forma
	cuerpo.add_child(cs)
	add_child(cuerpo)
	_info["tris_cueva"] = col.size() / 3
	# Camara: donde despertara el Chasqui (bajo el pozo), con una luz tenue que baja por el.
	var k_pozo := 0
	for k in anillos.size():
		if absf((anillos[k][6] as float) - s_pozo) < absf((anillos[k_pozo][6] as float) - s_pozo):
			k_pozo = k
	var piso_pozo: float = anillos[k_pozo][4]
	despertar = Marker3D.new()
	despertar.name = "despertar_chasqui"
	despertar.position = Vector3(POZO.x, piso_pozo, POZO.y)
	add_child(despertar)
	var luz_pozo := OmniLight3D.new()
	luz_pozo.position = Vector3(POZO.x, piso0 + 3.5, POZO.y)
	luz_pozo.light_color = Color(1.0, 0.92, 0.8)
	luz_pozo.light_energy = 0.6
	luz_pozo.omni_range = 9.0
	add_child(luz_pozo)
	# Boca: rocas grandes alrededor, que enmarcan la trinchera y tapan los bordes del agujero.
	var kb := maxi(boca, 0)
	_rocas_boca(anillos, kb)
	var cb: Vector3 = anillos[kb][0]
	var cf: Vector3 = anillos[-1][0]
	var fuera_dir := (cf - cb)
	fuera_dir.y = 0.0
	fuera_dir = fuera_dir.normalized()
	var ojo := cf + fuera_dir * 10.0
	ojo.y = _h(ojo.x, ojo.z) + 1.6
	_mirador("boca_cueva", ojo, cb)
	var med: Array = anillos[anillos.size() / 2]
	_mirador("cueva", (med[0] as Vector3) + Vector3(0, -0.2, 0) + (cf - (med[0] as Vector3)).normalized() * -2.0, cf)
	_mirador("fondo_pozo", Vector3(POZO.x + 1.6, piso_pozo + 1.6, POZO.y + 0.8), Vector3(POZO.x, piso_pozo + 9.0, POZO.y))
	_huellas.append([Vector2(cb.x, cb.z), Vector2(6, 6), 0.0, 1.0, 3.0])


func _rocas_boca(anillos: Array, kb: int) -> void:
	var escenas: Array[Node3D] = []
	for ruta: String in ROCAS:
		escenas.append((load(ruta) as PackedScene).instantiate())
	var mallas: Array[Mesh] = []
	for e in escenas:
		for m: MeshInstance3D in e.find_children("*", "MeshInstance3D", true, false):
			mallas.append(m.mesh)
			break
		e.free()
	for k in range(kb, anillos.size(), 2):
		var a: Array = anillos[k]
		for s: float in [-1.0, 1.0]:
			var p: Vector3 = (a[0] as Vector3) + (a[1] as Vector3) * s * ((a[2] as float) + 1.2)
			p.y = _h(p.x, p.z) - 0.4
			var mi := MeshInstance3D.new()
			mi.mesh = mallas[_rng.randi() % mallas.size()]
			var caja := mi.mesh.get_aabb()
			var esc := _rng.randf_range(1.4, 2.4) * 1.6 / maxf(caja.size.x, 0.1)
			var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * esc)
			mi.transform = Transform3D(b, p - b * Vector3(caja.get_center().x, caja.position.y, caja.get_center().z))
			add_child(mi)
