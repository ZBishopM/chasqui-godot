class_name CampoVenas
extends RefCounted
## Red de venas bajo la piel, horneada en los vertices de la piel densa (lo usa hornear_piel.gd). Las venas son curvas sobre
## la superficie: en el antebrazo, en coordenadas cilindricas (a lo largo del hueso, angulo alrededor); en el dorso de la
## mano, en el plano de la mano (hacia los dedos, de lado). Cada vertice guarda su distancia a la vena mas cercana y el
## shader de PielVenas empuja la piel por la normal con un perfil de bulto.
##
## Lo que se guarda por vertice:
##   COLOR.r  distancia al eje de la vena / (3 * semiancho)   (0 = encima de la vena, 1 = lejos)
##   COLOR.g  crecimiento: 0 en los nudillos, CORTE en la muneca, 1 en el codo (la vena se hincha desde la mano)
##   COLOR.b  nudo: 0..1, cuanto abulta ese tramo (venas irregulares, con varices; 0 en las puntas, que se hunden)
##   COLOR.a  1 = brazo izquierdo (el del poder), 0 = derecho
##   UV2.x    semiancho del bulto en ese tramo (unidades de malla)
##   TANGENT  direccion en la piel que se aleja del eje de la vena (para inclinar la normal en el shader)

const CORTE := 0.3
const ANCHO_BRAZO := 0.004   # m: semiancho de una vena principal del antebrazo (el bulto de piel llega al doble)
const ANCHO_MANO := 0.003    # m: idem en el dorso de la mano
const MUESTRAS := 48
const DEDOS := ["f_index.01", "f_middle.01", "f_ring.01", "f_pinky.01"]

enum { BRAZO, MANO }


## a: arrays de una superficie (se le anaden COLOR, TEX_UV2 y TANGENT). cabeza: nombre de hueso -> posicion en el espacio de
## la malla (bind pose). lado: por vertice, 0 = fuera de la zona, 1 = brazo izquierdo, 2 = derecho. u: metros por unidad.
## Devuelve cuantos vertices quedaron sobre alguna vena (r < 1) por lado.
static func hornear(a: Array, cabeza: Dictionary, lado: PackedByteArray, u: float, semilla: int) -> Dictionary:
	var P: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var N: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var nv := P.size()
	var col := PackedColorArray()
	col.resize(nv)
	col.fill(Color(1, 1, 0, 0))
	var uv2 := PackedVector2Array()
	uv2.resize(nv)
	var tan := PackedFloat32Array()
	tan.resize(nv * 4)
	for i in nv:
		var t0 := _perp(N[i])
		tan[i * 4] = t0.x
		tan[i * 4 + 1] = t0.y
		tan[i * 4 + 2] = t0.z
		tan[i * 4 + 3] = 1.0
	var cuenta := {}
	for s in [1, 2]:
		var suf := ".L" if s == 1 else ".R"
		var m := _marco(cabeza, suf, s == 1, P, lado, s)
		var rng := RandomNumberGenerator.new()
		rng.seed = semilla + s * 101
		var curvas := _curvas_brazo(m, rng, u) + _curvas_mano(m, rng, u)
		var sobre := 0
		for i in nv:
			if lado[i] != s:
				continue
			var r := _evaluar(P[i], N[i], m, curvas)
			col[i] = Color(r.r, r.g, r.b, 1.0 if s == 1 else 0.0)
			uv2[i] = Vector2(r.ancho, 0.0)
			var g: Vector3 = r.dir
			tan[i * 4] = g.x
			tan[i * 4 + 1] = g.y
			tan[i * 4 + 2] = g.z
			if r.r < 1.0:
				sobre += 1
		cuenta[suf] = sobre
	a[Mesh.ARRAY_COLOR] = col
	a[Mesh.ARRAY_TEX_UV2] = uv2
	a[Mesh.ARRAY_TANGENT] = tan
	return cuenta


## Marco de un brazo: codo E, muneca W, eje del antebrazo, dorso de la mano y radio de la piel a lo largo del antebrazo.
static func _marco(cabeza: Dictionary, suf: String, izq: bool, P: PackedVector3Array, lado: PackedByteArray, s: int) -> Dictionary:
	var E: Vector3 = cabeza["forearm" + suf]
	var W: Vector3 = cabeza["hand" + suf]
	var fb: Array[Vector3] = []
	for n: String in DEDOS:
		fb.append(cabeza[n + suf])
	var centro := (fb[0] + fb[1] + fb[2] + fb[3]) * 0.25
	var d := (centro - W).normalized()
	var l := (fb[0] - fb[3]).normalized()   # del menique al indice
	var n_palma := d.cross(l).normalized() * (1.0 if izq else -1.0)   # la misma regla que EjesMano.normal_palma
	var dorso := -n_palma
	var ax := (W - E).normalized()
	var ux := (dorso - ax * dorso.dot(ax)).normalized()   # angulo 0 = lado del dorso
	var vx := ax.cross(ux)
	var l2 := (l - d * l.dot(d)).normalized()
	var m := {
		E = E, W = W, largo = (W - E).length(), ax = ax, ux = ux, vx = vx,
		d = d, l = l2, dorso = dorso, x_nudillos = (centro - W).dot(d), medio_ancho = (fb[0] - fb[3]).dot(l2) * 0.5,
		y_centro = ((fb[0] + fb[3]) * 0.5 - W).dot(l2), hc = W.lerp(centro, 0.5),
	}
	# Radio medio de la piel en 10 tramos del antebrazo (para pasar del dorso de la mano al angulo del antebrazo).
	var suma := PackedFloat32Array()
	suma.resize(10)
	var n := PackedInt32Array()
	n.resize(10)
	for i in P.size():
		if lado[i] != s:
			continue
		var c := _cil(P[i], m)
		if c.x >= 0.0 and c.x < 1.0:
			var k := int(c.x * 10.0)
			suma[k] += c.z
			n[k] += 1
	var radio := PackedFloat32Array()
	for k in 10:
		radio.append(suma[k] / maxi(n[k], 1))
	m.radio = radio
	m.r_muneca = radio[9]
	m.signo_l = signf(l2.dot(vx))   # en el dorso, avanzar hacia el indice = sumar o restar angulo
	return m


## Coordenadas cilindricas en el antebrazo: (s 0 codo..1 muneca, angulo, radio).
static func _cil(p: Vector3, m: Dictionary) -> Vector3:
	var rel: Vector3 = p - m.E
	var s: float = rel.dot(m.ax) / m.largo
	var radial: Vector3 = rel - (m.ax as Vector3) * rel.dot(m.ax)
	return Vector3(s, atan2(radial.dot(m.vx), radial.dot(m.ux)), radial.length())


## Curva: dominio, parametro (t0..t1), muestras de la coordenada transversal (f), semiancho (w, unidades de malla) y nudo (k).
static func _curva(dom: int, t0: float, t1: float, f: Callable, ancho: float, rng: RandomNumberGenerator, afina_ini: bool, afina_fin: bool) -> Dictionary:
	var fs := PackedFloat32Array()
	var ws := PackedFloat32Array()
	var ks := PackedFloat32Array()
	var nudos: Array[Vector2] = []   # (posicion 0..1, fuerza): varices
	for j in rng.randi_range(1, 3):
		nudos.append(Vector2(rng.randf_range(0.1, 0.9), rng.randf_range(0.3, 0.6)))
	var fase := rng.randf() * TAU
	for j in MUESTRAS:
		var q := float(j) / (MUESTRAS - 1)
		var t := lerpf(t0, t1, q)
		fs.append(f.call(t))
		var nudo := 0.6 + 0.15 * sin(q * 9.0 + fase) + 0.06 * sin(q * 17.0 + fase * 1.7)
		var w := ancho * (0.85 + 0.2 * sin(q * 7.0 + fase * 0.6))
		for nd in nudos:
			var g := exp(-pow((q - nd.x) / 0.05, 2.0))
			nudo += nd.y * g
			w *= 1.0 + 0.35 * g
		# Las puntas se hunden en la carne: se estrechan y bajan (salvo donde la vena sigue en el otro dominio).
		var punta := 1.0
		if afina_ini:
			punta = minf(punta, smoothstep(0.0, 0.12, q))
		if afina_fin:
			punta = minf(punta, smoothstep(1.0, 0.88, q))
		ws.append(w * lerpf(0.6, 1.0, punta))
		ks.append(clampf(nudo, 0.0, 1.0) * punta)
	var w_max := 0.0
	for w in ws:
		w_max = maxf(w_max, w)
	return {dom = dom, t0 = t0, t1 = t1, f = fs, w = ws, k = ks, w_max = w_max}


## Antebrazo (parametro s: 1 muneca -> 0 codo; transversal: angulo). Siguen las del dorso de la mano, mas las del lado de la
## palma (las que mas se marcan tras el gimnasio) y ramas en Y que salen de ellas.
static func _curvas_brazo(m: Dictionary, rng: RandomNumberGenerator, u: float) -> Array:
	var out := []
	var w := ANCHO_BRAZO / u
	var r_w: float = m.r_muneca
	# Las 3 que vienen del dorso de la mano (mismas salidas que _curvas_mano) y derivan hacia los lados al subir.
	var salidas := [-0.55, 0.0, 0.6]
	var principales: Array[Dictionary] = []
	for y_rel: float in salidas:
		var y: float = m.y_centro + y_rel * m.medio_ancho
		var ang0: float = m.signo_l * y / r_w
		var deriva := rng.randf_range(0.5, 1.1) * signf(y_rel if y_rel != 0.0 else rng.randf() - 0.5)
		var fase := rng.randf() * TAU
		var fin := rng.randf_range(0.0, 0.25)
		var c := _curva(BRAZO, 1.04, fin, func(s: float) -> float: return ang0 + deriva * pow(1.0 - s, 1.3) + 0.10 * sin(s * 9.0 + fase) + 0.05 * sin(s * 21.0 + fase), w, rng, false, true)
		out.append(c)
		principales.append(c)
	# Lado de la palma del antebrazo (angulo ~PI): dos gruesas que suben casi paralelas y se juntan cerca del codo.
	for lado_p: float in [-1.0, 1.0]:
		var ang0 := PI + lado_p * rng.randf_range(0.3, 0.5)
		var fase := rng.randf() * TAU
		var c := _curva(BRAZO, 0.97, rng.randf_range(0.0, 0.1), func(s: float) -> float: return ang0 - lado_p * 0.25 * pow(1.0 - s, 2.0) + 0.12 * sin(s * 8.0 + fase) + 0.05 * sin(s * 19.0 + fase), w * 1.15, rng, true, true)
		out.append(c)
		principales.append(c)
	# Ramas en Y: nacen de una principal y se separan.
	for j in 3:
		var madre: Dictionary = principales[rng.randi() % principales.size()]
		var s0 := rng.randf_range(0.35, 0.75)
		var largo := rng.randf_range(0.25, 0.4)
		var ang_madre := _muestra(madre, s0, "f")
		var abre := rng.randf_range(0.5, 0.9) * (1.0 if rng.randf() < 0.5 else -1.0)
		var fase := rng.randf() * TAU
		out.append(_curva(BRAZO, s0, maxf(s0 - largo, 0.0), func(s: float) -> float: return ang_madre + abre * pow((s0 - s) / largo, 0.8) + 0.06 * sin(s * 17.0 + fase), w * 0.7, rng, false, true))
	return out


## Dorso de la mano (parametro x: de los nudillos a la muneca; transversal: y, de lado). Una vena entre cada par de nudillos
## baja hacia la muneca juntandose en 3 salidas, mas el arco venoso que las cruza.
static func _curvas_mano(m: Dictionary, rng: RandomNumberGenerator, u: float) -> Array:
	var out := []
	var w := ANCHO_MANO / u
	var xn: float = m.x_nudillos
	var yc: float = m.y_centro
	var ma: float = m.medio_ancho
	var arranques := [0.75, 0.25, -0.25, -0.75]   # entre nudillos, del indice al menique
	var destino := [0.6, 0.0, 0.0, -0.55]          # salidas en la muneca (las mismas que _curvas_brazo)
	for j in 4:
		var y0: float = yc + arranques[j] * ma * 1.1
		var y1: float = yc + destino[j] * ma
		var fase := rng.randf() * TAU
		var xi := xn * 0.92
		var f := func(x: float) -> float: return lerpf(y1, y0, smoothstep(0.0, 1.0, clampf(x / xi, 0.0, 1.0))) + 0.06 * ma * sin(x / xi * 7.0 + fase)
		out.append(_curva(MANO, xi, -0.015 / u, f, w, rng, true, false))
	# Arco venoso: cruza el dorso a media mano (parametro y).
	var xa := xn * rng.randf_range(0.5, 0.62)
	var fase := rng.randf() * TAU
	var arco := _curva(MANO, yc - ma * 0.95, yc + ma * 0.95, func(y: float) -> float: return xa + 0.12 * xn * sin((y - yc) / ma * 1.4 + fase), w * 0.85, rng, true, true)
	arco.eje_y = true
	out.append(arco)
	return out


## Un vector unitario en el plano de la piel (la tangente nunca puede ser nula: el shader la normaliza).
static func _perp(n: Vector3) -> Vector3:
	return n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()


static func _muestra(c: Dictionary, t: float, campo: String) -> float:
	var arr: PackedFloat32Array = c[campo]
	var q := clampf((t - float(c.t0)) / (float(c.t1) - float(c.t0)), 0.0, 1.0) * (arr.size() - 1)
	var i := mini(int(q), arr.size() - 2)
	return lerpf(arr[i], arr[i + 1], q - i)


## Vena mas cercana a un vertice (en distancia relativa a su ancho). Devuelve r, g, b, ancho y la direccion que se aleja de ella.
static func _evaluar(p: Vector3, n: Vector3, m: Dictionary, curvas: Array) -> Dictionary:
	var cil := _cil(p, m)
	var rel_w: Vector3 = p - m.W
	var x: float = rel_w.dot(m.d)
	var y: float = rel_w.dot(m.l)
	var en_dorso: bool = (p - m.hc).dot(m.dorso) > 0.0
	# Crecimiento por posicion: dorso/palma de la mano 0..CORTE (nudillos -> muneca), antebrazo CORTE..1 (muneca -> codo).
	var g := CORTE + (1.0 - CORTE) * clampf(1.0 - cil.x, 0.0, 1.0)
	if cil.x >= 1.0:
		g = CORTE * clampf(1.0 - x / float(m.x_nudillos), 0.0, 1.0)
	var mejor := {r = 1.0, g = g, b = 0.0, ancho = 0.0, dir = _perp(n)}
	var mejor_rel := 1.0
	var radio: PackedFloat32Array = m.radio
	var r_local := maxf(cil.z, radio[clampi(int(cil.x * 10.0), 0, 9)] * 0.5)
	for c: Dictionary in curvas:
		var t_min := minf(c.t0, c.t1)
		var t_max := maxf(c.t0, c.t1)
		var tp: float
		var tq: float
		var escala_p: float
		var escala_q: float
		if c.dom == BRAZO:
			tp = cil.x
			tq = cil.y
			escala_p = m.largo
			escala_q = r_local
		else:
			if not en_dorso:
				continue
			var eje_y: bool = c.get("eje_y", false)
			tp = y if eje_y else x
			tq = x if eje_y else y
			escala_p = 1.0
			escala_q = 1.0
		var holgura: float = 3.0 * float(c.w_max) / escala_p   # mas alla de la punta, el bulto se cierra como una capsula
		if tp < t_min - holgura or tp > t_max + holgura:
			continue
		var tc := clampf(tp, t_min, t_max)
		var fc := _muestra(c, tc, "f")
		var dq := tq - fc
		if c.dom == BRAZO:
			dq = wrapf(dq, -PI, PI)
		var dp := (tp - tc) * escala_p
		dq *= escala_q
		# Pendiente de la curva: la distancia perpendicular es menor que la diferencia transversal.
		var h := (float(c.t1) - float(c.t0)) / (MUESTRAS - 1)
		var pend := (_muestra(c, tc + h, "f") - _muestra(c, tc - h, "f")) / (2.0 * h) * escala_q / escala_p
		var dist := sqrt(dp * dp + dq * dq / (1.0 + pend * pend))
		var w := _muestra(c, tc, "w")
		var rel := dist / (3.0 * w)
		if rel < mejor_rel:
			mejor_rel = rel
			var dir: Vector3
			if c.dom == BRAZO:
				var e_ang: Vector3 = -(m.ux as Vector3) * sin(cil.y) + (m.vx as Vector3) * cos(cil.y)
				dir = (m.ax as Vector3) * dp + e_ang * dq
			else:
				var eje_y: bool = c.get("eje_y", false)
				var dir_p: Vector3 = m.l if eje_y else m.d
				var dir_q: Vector3 = m.d if eje_y else m.l
				dir = dir_p * dp + dir_q * dq
			dir = dir - n * dir.dot(n)
			if dir.length() > 1e-9:
				dir = dir.normalized()
			else:
				dir = mejor.dir
			mejor = {r = rel, g = g, b = _muestra(c, tc, "k"), ancho = w, dir = dir}
	return mejor
