class_name KitInca
extends RefCounted
## Kit modular inca: arma la geometria de un trozo del pueblo (muros con vanos trapezoidales, hastiales, techos de ichu,
## colcas, plataformas, escaleras, utileria) y la junta en una malla por material + una sola forma de colision.
##
## Cada pieza recibe una Transform3D `t` (su marco local) y medidas en metros. Las caras se ordenan solas segun su normal,
## asi ninguna pieza depende del sentido en que se escriban sus vertices. Las UV van en metros: x a lo largo de la pieza,
## y hacia arriba (o pendiente abajo en los techos); los shaders de MaterialesInca dibujan la piedra y la paja con ellas.
##
## Convenio de los muros: el marco local tiene +X a lo largo del muro, +Y arriba y +Z hacia fuera (la cara exterior).
## `muro_entre(a, b)` pone el exterior a la derecha de quien camina de a a b (visto desde arriba).

const EPS := 0.001

var _mallas := {}                           # material -> SurfaceTool
var _colision := PackedVector3Array()       # triangulos sueltos (ConcavePolygonShape3D)
var _triangulos := 0


# --- Caras ----------------------------------------------------------------------------------------

## Cara plana convexa (puntos locales a `t`, en orden alrededor del borde) con normal `n` local. Se triangula en
## abanico y se ordena para que Godot la vea de frente desde el lado de `n` (sentido horario visto de frente).
func cara(mat: String, t: Transform3D, pts: Array, uvs: Array, n: Vector3, colision := true) -> void:
	if pts.size() < 3:
		return
	var w: Array[Vector3] = []
	for p: Vector3 in pts:
		w.append(t * p)
	var nw := (t.basis * n).normalized()
	# Producto cruzado de Godot: la cara de frente tiene (b - a) x (c - a) opuesto a la normal.
	var invertir := false
	for k in range(1, w.size() - 1):
		var c := (w[k] - w[0]).cross(w[k + 1] - w[0])
		if c.length_squared() > 1e-10:
			invertir = c.dot(nw) > 0.0
			break
	var st := _sup(mat)
	for k in range(1, w.size() - 1):
		var orden := [0, k + 1, k] if invertir else [0, k, k + 1]
		for i: int in orden:
			st.set_normal(nw)
			st.set_uv(uvs[i])
			st.add_vertex(w[i])
			if colision:
				_colision.append(w[i])
		_triangulos += 1


func _sup(mat: String) -> SurfaceTool:
	if not _mallas.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_mallas[mat] = st
	return _mallas[mat]


## Triangulo con normales por vertice (superficies curvas: ceramica). Mismo convenio de orden que `cara`.
func triangulo_suave(mat: String, t: Transform3D, p: Array, n: Array, uv: Array) -> void:
	var w := [t * (p[0] as Vector3), t * (p[1] as Vector3), t * (p[2] as Vector3)]
	var nm: Vector3 = (n[0] + n[1] + n[2]) as Vector3
	var orden := [0, 2, 1] if (w[1] - w[0]).cross(w[2] - w[0]).dot(t.basis * nm) > 0.0 else [0, 1, 2]
	var st := _sup(mat)
	for i: int in orden:
		st.set_normal((t.basis * (n[i] as Vector3)).normalized())
		st.set_uv(uv[i])
		st.add_vertex(w[i])
	_triangulos += 1


## Poligono convexo solo de colision (rampas invisibles de las escaleras, tapas).
func colision_cara(t: Transform3D, pts: Array) -> void:
	for k in range(1, pts.size() - 1):
		for i in [0, k, k + 1]:
			_colision.append(t * (pts[i] as Vector3))


# --- Solidos simples ------------------------------------------------------------------------------

## Caja de `tam` centrada en `centro` (local a `t`). `mat_arriba` para la tapa superior; `abajo` dibuja la base.
func caja(mat: String, t: Transform3D, centro: Vector3, tam: Vector3, mat_arriba := "", abajo := false, colision := true) -> void:
	var h := tam * 0.5
	var c := centro
	var arr := mat if mat_arriba == "" else mat_arriba
	# arriba / abajo
	cara(arr, t, [c + Vector3(-h.x, h.y, -h.z), c + Vector3(h.x, h.y, -h.z), c + Vector3(h.x, h.y, h.z), c + Vector3(-h.x, h.y, h.z)],
		[Vector2(c.x - h.x, c.z - h.z), Vector2(c.x + h.x, c.z - h.z), Vector2(c.x + h.x, c.z + h.z), Vector2(c.x - h.x, c.z + h.z)], Vector3.UP, colision)
	if abajo:
		cara(mat, t, [c + Vector3(-h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, h.z), c + Vector3(-h.x, -h.y, h.z)],
			[Vector2(c.x - h.x, c.z - h.z), Vector2(c.x + h.x, c.z - h.z), Vector2(c.x + h.x, c.z + h.z), Vector2(c.x - h.x, c.z + h.z)], Vector3.DOWN, colision)
	var y0 := c.y - h.y
	var y1 := c.y + h.y
	# +z / -z
	for s in [1.0, -1.0]:
		var z: float = c.z + h.z * s
		cara(mat, t, [Vector3(c.x - h.x, y0, z), Vector3(c.x + h.x, y0, z), Vector3(c.x + h.x, y1, z), Vector3(c.x - h.x, y1, z)],
			[Vector2(c.x - h.x, y0), Vector2(c.x + h.x, y0), Vector2(c.x + h.x, y1), Vector2(c.x - h.x, y1)], Vector3(0, 0, s), colision)
	# +x / -x
	for s in [1.0, -1.0]:
		var x: float = c.x + h.x * s
		cara(mat, t, [Vector3(x, y0, c.z - h.z), Vector3(x, y0, c.z + h.z), Vector3(x, y1, c.z + h.z), Vector3(x, y1, c.z - h.z)],
			[Vector2(c.z - h.z, y0), Vector2(c.z + h.z, y0), Vector2(c.z + h.z, y1), Vector2(c.z - h.z, y1)], Vector3(s, 0, 0), colision)


## Prisma: el poligono convexo `poli` (en el plano local z-y: Vector2(z, y)) extruido a lo largo de x, de x0 a x1.
## Las UV de los costados van (x, distancia recorrida por el borde desde el primer punto): en un techo, si el primer
## punto es la cumbrera, la y de la UV baja por la pendiente.
func prisma(mat: String, t: Transform3D, poli: PackedVector2Array, x0: float, x1: float, tapas := true, colision := true) -> void:
	var n := poli.size()
	var area := 0.0
	for i in n:
		var a := poli[i]
		var b := poli[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	var s := 0.0
	for i in n:
		var a := poli[i]
		var b := poli[(i + 1) % n]
		var e := b - a
		var largo := e.length()
		if largo < EPS:
			continue
		# Normal hacia fuera en el plano (z, y): depende del sentido del poligono.
		var n2 := Vector2(e.y, -e.x) if area > 0.0 else Vector2(-e.y, e.x)
		n2 = n2.normalized()
		cara(mat, t, [Vector3(x0, a.y, a.x), Vector3(x1, a.y, a.x), Vector3(x1, b.y, b.x), Vector3(x0, b.y, b.x)],
			[Vector2(x0, s), Vector2(x1, s), Vector2(x1, s + largo), Vector2(x0, s + largo)], Vector3(0.0, n2.y, n2.x), colision)
		s += largo
	if tapas:
		for lado in [[x0, -1.0], [x1, 1.0]]:
			var pts := []
			var uvs := []
			for p in poli:
				pts.append(Vector3(lado[0], p.y, p.x))
				uvs.append(Vector2(p.x, p.y))
			cara(mat, t, pts, uvs, Vector3(lado[1], 0, 0), colision)


# --- Muros ----------------------------------------------------------------------------------------

## Vano trapezoidal (puerta, ventana u hornacina) para `muro`. `c` = centro a lo largo del muro; `ancho` abajo y
## `ancho_arriba`; de y0 a y1. `fondo` 0 atraviesa el muro; > 0 es una hornacina de ese fondo en la cara `cara`
## (+1 exterior, -1 interior).
static func vano(c: float, ancho: float, ancho_arriba: float, y0: float, y1: float, fondo := 0.0, cara_ := -1) -> Dictionary:
	return {"c": c, "ab": ancho, "ar": ancho_arriba, "y0": y0, "y1": y1, "fondo": fondo, "cara": cara_}


## Puerta inca: 1 m abajo, 0,8 arriba, 2 m de alto.
static func puerta(c: float, escala := 1.0) -> Dictionary:
	return vano(c, 1.0 * escala, 0.8 * escala, 0.0, 2.0 * escala)


## Muro de `largo` x `alto` en el marco `t` (ver convenio arriba), `grueso` en la base. `talud`: fraccion de grueso que
## pierde arriba (los muros incas se inclinan hacia dentro). `extremos` dibuja las cabezas del muro (no hace falta si
## topa con otro).
func muro(mat: String, t: Transform3D, largo: float, alto: float, grueso: float, vanos: Array = [], talud := 0.2, extremos := true) -> void:
	var g0 := grueso * 0.5
	var g1 := grueso * (1.0 - talud) * 0.5
	var zc := func(y: float) -> float: return lerpf(g0, g1, y / alto)
	var k := (g0 - g1) / alto
	for s: float in [1.0, -1.0]:
		# Vanos que rompen esta cara: los pasantes y las hornacinas de este lado.
		var rompen: Array = []
		for v: Dictionary in vanos:
			if v.fondo <= 0.0 or int(v.cara) == int(s):
				rompen.append(v)
		var cortes := [0.0, alto]
		for v: Dictionary in rompen:
			cortes.append(clampf(v.y0, 0.0, alto))
			cortes.append(clampf(v.y1, 0.0, alto))
		cortes.sort()
		var n := Vector3(0.0, k, s).normalized()   # la cara se inclina hacia dentro: mira algo hacia arriba
		for i in cortes.size() - 1:
			var ya: float = cortes[i]
			var yb: float = cortes[i + 1]
			if yb - ya < EPS:
				continue
			var activos: Array = []
			for v: Dictionary in rompen:
				if v.y0 <= ya + EPS and v.y1 >= yb - EPS:
					activos.append(v)
			activos.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.c < b.c)
			# Tramos macizos entre vanos: [u izq abajo, u der abajo, u der arriba, u izq arriba]
			var izq_a := 0.0
			var izq_b := 0.0
			for v: Dictionary in activos:
				var l := _borde_vano(v, ya, -1.0)
				var lb := _borde_vano(v, yb, -1.0)
				_tramo(mat, t, s, n, izq_a, l, lb, izq_b, ya, yb, zc, largo)
				izq_a = _borde_vano(v, ya, 1.0)
				izq_b = _borde_vano(v, yb, 1.0)
			_tramo(mat, t, s, n, izq_a, largo, largo, izq_b, ya, yb, zc, largo)
	# Mochetas, dinteles y alfeizares de los vanos; fondo de las hornacinas.
	for v: Dictionary in vanos:
		# z_fuera: la cara por donde entra el vano (en una hornacina, la suya); zb: la otra cara o el fondo.
		var z_fuera := 1.0 if v.fondo <= 0.0 else float(v.cara)
		var y0: float = v.y0
		var y1: float = v.y1
		var za0: float = z_fuera * zc.call(y0)
		var za1: float = z_fuera * zc.call(y1)
		var zb0: float
		var zb1: float
		if v.fondo > 0.0:
			zb0 = z_fuera * (zc.call(y0) - v.fondo)
			zb1 = z_fuera * (zc.call(y1) - v.fondo)
		else:
			zb0 = -zc.call(y0)
			zb1 = -zc.call(y1)
		var l0 := _borde_vano(v, y0, -1.0)
		var l1 := _borde_vano(v, y1, -1.0)
		var r0 := _borde_vano(v, y0, 1.0)
		var r1 := _borde_vano(v, y1, 1.0)
		# Jamba izquierda: mira hacia el centro del vano (+u) y algo hacia abajo (el vano se cierra arriba).
		var nl := Vector3(y1 - y0, -(l1 - l0), 0.0).normalized()
		cara(mat, t, [Vector3(l0, y0, za0), Vector3(l1, y1, za1), Vector3(l1, y1, zb1), Vector3(l0, y0, zb0)],
			[Vector2(za0, y0), Vector2(za1, y1), Vector2(zb1, y1), Vector2(zb0, y0)], nl)
		var nr := Vector3(-(y1 - y0), (r1 - r0), 0.0).normalized()
		cara(mat, t, [Vector3(r0, y0, za0), Vector3(r1, y1, za1), Vector3(r1, y1, zb1), Vector3(r0, y0, zb0)],
			[Vector2(za0, y0), Vector2(za1, y1), Vector2(zb1, y1), Vector2(zb0, y0)], nr)
		if y1 < alto - EPS:
			cara(mat, t, [Vector3(l1, y1, za1), Vector3(r1, y1, za1), Vector3(r1, y1, zb1), Vector3(l1, y1, zb1)],
				[Vector2(l1, za1), Vector2(r1, za1), Vector2(r1, zb1), Vector2(l1, zb1)], Vector3.DOWN)
		if y0 > EPS:
			cara(mat, t, [Vector3(l0, y0, za0), Vector3(r0, y0, za0), Vector3(r0, y0, zb0), Vector3(l0, y0, zb0)],
				[Vector2(l0, za0), Vector2(r0, za0), Vector2(r0, zb0), Vector2(l0, zb0)], Vector3.UP)
		if v.fondo > 0.0:
			cara(mat, t, [Vector3(l0, y0, zb0), Vector3(r0, y0, zb0), Vector3(r1, y1, zb1), Vector3(l1, y1, zb1)],
				[Vector2(l0, y0), Vector2(r0, y0), Vector2(r1, y1), Vector2(l1, y1)], Vector3(0.0, 0.0, z_fuera))
	# Coronacion y cabezas.
	cara(mat, t, [Vector3(0, alto, -g1), Vector3(largo, alto, -g1), Vector3(largo, alto, g1), Vector3(0, alto, g1)],
		[Vector2(0, -g1), Vector2(largo, -g1), Vector2(largo, g1), Vector2(0, g1)], Vector3.UP)
	if extremos:
		for e in [[0.0, -1.0], [largo, 1.0]]:
			var x: float = e[0]
			cara(mat, t, [Vector3(x, 0, -g0), Vector3(x, 0, g0), Vector3(x, alto, g1), Vector3(x, alto, -g1)],
				[Vector2(-g0, 0), Vector2(g0, 0), Vector2(g1, alto), Vector2(-g1, alto)], Vector3(e[1], 0, 0))


## u del borde izquierdo (lado -1) o derecho (+1) del vano a la altura y.
func _borde_vano(v: Dictionary, y: float, lado: float) -> float:
	var f := clampf((y - v.y0) / maxf(v.y1 - v.y0, EPS), 0.0, 1.0)
	return v.c + lado * lerpf(v.ab, v.ar, f) * 0.5


## Un tramo macizo de una cara del muro: cuadrilatero entre u = ua..ub (abajo, y = ya) y u = uc..ud (arriba, y = yb).
func _tramo(mat: String, t: Transform3D, s: float, n: Vector3, ua: float, ub: float, uc: float, ud: float, ya: float, yb: float, zc: Callable, largo: float) -> void:
	if ub - ua < EPS and uc - ud < EPS:
		return
	var za: float = s * zc.call(ya)
	var zb: float = s * zc.call(yb)
	# UV: del lado de fuera u crece con x; del de dentro se espeja para que las dos caras no se vean calcadas.
	var u := func(x: float) -> float: return x if s > 0.0 else largo - x + 0.37
	cara(mat, t, [Vector3(ua, ya, za), Vector3(ub, ya, za), Vector3(uc, yb, zb), Vector3(ud, yb, zb)],
		[Vector2(u.call(ua), ya), Vector2(u.call(ub), ya), Vector2(u.call(uc), yb), Vector2(u.call(ud), yb)], n)


## Marco de un muro que va de `a` a `b` (puntos en la base, locales a `t`) con el exterior a la derecha.
static func marco_muro(t: Transform3D, a: Vector3, b: Vector3) -> Transform3D:
	var x := (b - a)
	x.y = 0.0
	x = x.normalized()
	var z := x.cross(Vector3.UP)
	return t * Transform3D(Basis(x, Vector3.UP, z), a)


func muro_entre(mat: String, t: Transform3D, a: Vector3, b: Vector3, alto: float, grueso: float, vanos: Array = [], talud := 0.2, extremos := true) -> void:
	var largo := Vector2(b.x - a.x, b.z - a.z).length()
	if largo < 0.05:
		return
	muro(mat, marco_muro(t, a, b), largo, alto, grueso, vanos, talud, extremos)


## Hastial: triangulo de piedra sobre la cabecera de una casa. En el marco de muro `t`: base de x = 0 a `largo` a la
## altura y0, pico en el centro a y1.
func hastial(mat: String, t: Transform3D, largo: float, y0: float, y1: float, grueso: float) -> void:
	var g := grueso * 0.5
	var mt := t * Transform3D(Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0)), Vector3.ZERO)
	# En mt el eje x atraviesa el muro y el plano (z, y) es su cara: la z de mt es la u del muro.
	prisma(mat, mt, PackedVector2Array([Vector2(0.0, y0), Vector2(largo, y0), Vector2(largo * 0.5, y1)]), -g, g)


# --- Techos ---------------------------------------------------------------------------------------

## Techo de ichu a dos aguas sobre una casa de `ancho` (caras exteriores de los muros largos en z = +-ancho/2), con la
## cumbrera a lo largo de x, de x0 a x1. Los aleros arrancan a `alero` sobre esas caras y vuelan `vuelo`. Devuelve la
## altura de la cumbrera (cara de abajo). Tambien rellena con piedra el hueco entre la coronacion de los muros largos y
## la cara de abajo del techo.
func techo_dos_aguas(t: Transform3D, x0: float, x1: float, ancho: float, alero: float, pendiente_grados: float, vuelo: float, grueso: float, mat_muro := "pirca", grueso_muro := 0.6) -> float:
	var tg := tan(deg_to_rad(pendiente_grados))
	var cumbre := alero + ancho * 0.5 * tg
	var gv := grueso / cos(deg_to_rad(pendiente_grados))   # grueso medido en vertical
	for s in [1.0, -1.0]:
		var z_alero: float = s * (ancho * 0.5 + vuelo)
		var y_alero: float = alero - vuelo * tg
		# Primer punto: la cumbrera arriba, asi la UV baja por la pendiente.
		prisma("ichu", t, PackedVector2Array([Vector2(0.0, cumbre + gv), Vector2(z_alero, y_alero + gv), Vector2(z_alero, y_alero), Vector2(0.0, cumbre)]), x0, x1)
		# Cuna de piedra sobre el muro largo, hasta la cara de abajo del techo.
		var zf: float = s * ancho * 0.5
		var zd: float = s * (ancho * 0.5 - grueso_muro * 0.95)
		prisma(mat_muro, t, PackedVector2Array([Vector2(zf, alero), Vector2(zd, alero), Vector2(zd, alero + grueso_muro * 0.95 * tg)]), x0 + 0.35, x1 - 0.35)
	# Caballete: un rollo de paja sobre la cumbrera.
	prisma("ichu", t, PackedVector2Array([Vector2(-0.22, cumbre + gv - 0.05), Vector2(0.0, cumbre + gv + 0.16), Vector2(0.22, cumbre + gv - 0.05)]), x0 - 0.05, x1 + 0.05)
	return cumbre


## Techo conico de ichu (colcas, casas redondas): de `alero` (radio `radio` + `vuelo`) a la punta en `punta`.
func techo_conico(t: Transform3D, radio: float, alero: float, punta: float, vuelo: float, grueso: float, lados := 14) -> void:
	var r := radio + vuelo
	var pend := (punta - alero) / radio
	var y_alero := alero - vuelo * pend
	var cima := Vector3(0, punta + grueso, 0)
	for i in lados:
		var a0 := TAU * i / lados
		var a1 := TAU * (i + 1) / lados
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var p0 := d0 * r + Vector3(0, y_alero + grueso, 0)
		var p1 := d1 * r + Vector3(0, y_alero + grueso, 0)
		var dm := (d0 + d1).normalized()
		var n := (dm * (punta - y_alero) + Vector3.UP * r).normalized()
		var arco := r * TAU / lados
		var largo := Vector2(r, punta - y_alero).length()
		cara("ichu", t, [cima, p0, p1], [Vector2(arco * i + arco * 0.5, 0.0), Vector2(arco * i, largo), Vector2(arco * (i + 1), largo)], n)
		# Canto del alero
		cara("ichu", t, [p0, p1, p1 - Vector3(0, grueso, 0), p0 - Vector3(0, grueso, 0)],
			[Vector2(arco * i, 0.0), Vector2(arco * (i + 1), 0.0), Vector2(arco * (i + 1), grueso), Vector2(arco * i, grueso)], dm)
		# Cara de abajo
		var q0 := p0 - Vector3(0, grueso, 0)
		var q1 := p1 - Vector3(0, grueso, 0)
		cara("ichu", t, [Vector3(0, punta, 0), q0, q1], [Vector2(0, 0), Vector2(arco, largo), Vector2(0, largo)], -n)


# --- Piezas compuestas ----------------------------------------------------------------------------

## Muro circular (colca, casa redonda, brocal de pozo) de `lados` tramos rectos. `puerta` = vano centrado en el tramo 0
## (que mira a +x local) o un Dictionary vacio.
func anillo(mat: String, t: Transform3D, radio: float, alto: float, grueso: float, lados: int, puerta_: Dictionary = {}, talud := 0.15) -> void:
	# Cada tramo se alarga lo justo para que las caras de fuera se toquen en las esquinas.
	var extra := grueso * 0.5 * tan(PI / lados)
	for i in lados:
		var a0 := -PI / lados + TAU * i / lados
		var a1 := a0 + TAU / lados
		var p0 := Vector3(cos(a0), 0, sin(a0)) * radio
		var p1 := Vector3(cos(a1), 0, sin(a1)) * radio
		var dir := (p0 - p1).normalized()
		# Con el exterior a la derecha hay que recorrer el anillo en sentido horario visto desde arriba (de p1 a p0).
		var a := p1 - dir * extra
		var b := p0 + dir * extra
		var vanos := []
		if i == 0 and not puerta_.is_empty():
			var v := puerta_.duplicate()
			v.c = a.distance_to(b) * 0.5
			vanos.append(v)
		muro_entre(mat, t, a, b, alto, grueso, vanos, talud, false)


## Casa inca rectangular (wasi) en su marco `t`: centro del piso en el origen, largo en x, fondo en z, el frente (con
## las puertas) hacia +z. `puertas` y `puertas_atras`: centros en x. Hornacinas trapezoidales por dentro en el muro de
## atras y en las cabeceras. La kallanka es una wasi grande de silleria. Devuelve la altura de la cumbrera.
func wasi(t: Transform3D, largo: float, fondo: float, alero := 2.5, puertas: Array = [0.0], mat := "pirca", grueso := 0.6, ventanas := true, escala_puerta := 1.0, puertas_atras: Array = []) -> float:
	var g := grueso
	var mx := largo * 0.5
	var mz := fondo * 0.5
	var zf := mz - g * 0.5
	# Frente: de -x a +x (exterior +z).
	var vf := []
	for c: float in puertas:
		vf.append(puerta(c + mx, escala_puerta))
	muro_entre(mat, t, Vector3(-mx, 0, zf), Vector3(mx, 0, zf), alero, g, vf)
	# Fondo: de +x a -x (exterior -z), asi la u del muro es mx - x. Hornacinas por dentro (cara -1) cada ~1,6 m.
	var vb := []
	for c: float in puertas_atras:
		vb.append(puerta(mx - c, escala_puerta))
	var n_horn := int((largo - 2.0 * g) / 1.6)
	for i in n_horn:
		var c := g + 0.8 + i * (largo - 2.0 * g - 1.6) / maxf(n_horn - 1, 1)
		var libre := true
		for p: float in puertas_atras:
			libre = libre and absf((mx - p) - c) > 0.6 + 0.6 * escala_puerta
		if libre:
			vb.append(vano(c, 0.5, 0.38, 1.0, 1.65, 0.3, -1))
	muro_entre(mat, t, Vector3(mx, 0, -zf), Vector3(-mx, 0, -zf), alero, g, vb)
	# Cabeceras entre los muros largos, con un hastial encima.
	var tg := tan(deg_to_rad(40.0))
	var cumbre := alero + mz * tg
	for s in [1.0, -1.0]:
		var x: float = s * (mx - g * 0.5)
		var a := Vector3(x, 0, s * (mz - g))
		var b := Vector3(x, 0, -s * (mz - g))
		var vc := [vano((mz - g), 0.45, 0.35, 1.0, 1.6, 0.3, -1)]
		if ventanas and s > 0.0:
			vc = [vano((mz - g), 0.45, 0.35, 1.1, 1.65)]   # ventana pasante en una cabecera
		muro_entre(mat, t, a, b, alero, g, vc, 0.2, false)
		var marco := marco_muro(t, Vector3(x, 0, s * mz), Vector3(x, 0, -s * mz))
		hastial(mat, marco, fondo, alero, cumbre - 0.1, g * 0.8)
	techo_dos_aguas(t, -mx - 0.35, mx + 0.35, fondo, alero, 40.0, 0.6, 0.32, mat, g)
	return cumbre


## Colca (deposito redondo) con techo conico y una puerta baja por la que se entra agachado (escondite).
func colca(t: Transform3D, radio := 2.0, alto := 2.6) -> void:
	anillo("pirca", t, radio, alto, 0.55, 12, vano(0.0, 0.85, 0.7, 0.0, 1.35))
	techo_conico(t, radio, alto, alto + radio * 0.95, 0.45, 0.3)


## Casa redonda de las afueras: muro bajo, puerta normal, techo conico alto.
func casa_redonda(t: Transform3D, radio := 2.6) -> void:
	anillo("pirca", t, radio, 1.9, 0.5, 12, puerta(0.0, 0.95))
	techo_conico(t, radio, 1.9, 1.9 + radio * 1.15, 0.5, 0.32)


## Pozo: brocal redondo de piedra con agua oscura abajo.
func pozo(t: Transform3D, radio := 0.85) -> void:
	anillo("pirca", t, radio, 0.75, 0.35, 12, {}, 0.0)
	var pts := []
	var uvs := []
	for i in 12:
		var a := TAU * i / 12.0
		pts.append(Vector3(cos(a), 0, sin(a)) * (radio - 0.15) + Vector3(0, 0.3, 0))
		uvs.append(Vector2(cos(a), sin(a)))
	cara("agua", t, pts, uvs, Vector3.UP, false)
	colision_cara(t, pts)


## Escalera de piedra que sube `alto` m hacia -z local desde el origen (el pie, al centro). Se dibujan los peldanos;
## la colision es una rampa lisa (el jugador no sube escalones sin saltar). Devuelve lo que mide en planta.
func escalera(mat: String, t: Transform3D, ancho: float, alto: float, contrahuella := 0.26, huella := 0.34, base := -0.6) -> float:
	var n := maxi(1, ceili(alto / contrahuella))
	var ch := alto / n
	for i in n:
		var y1 := (i + 1) * ch
		# Cada peldano es un bloque desde la base (enterrada) hasta su huella.
		caja(mat, t, Vector3(0, (y1 + base) * 0.5, -(i + 0.5) * huella), Vector3(ancho, y1 - base, huella), "", false, false)
	var fin := n * huella
	var a := ancho * 0.5
	colision_cara(t, [Vector3(-a, 0, 0.05), Vector3(a, 0, 0.05), Vector3(a, alto, -fin), Vector3(-a, alto, -fin)])
	for s in [-1.0, 1.0]:
		colision_cara(t, [Vector3(s * a, base, 0.05), Vector3(s * a, alto, -fin), Vector3(s * a, base, -fin)])
	return fin


## Plataforma (terraza) de muros de contencion con tapa de tierra. `rect` en el plano local x-z, de y_base a y_tapa.
## `huecos`: rectangulos (Rect2 en x-z) donde la tapa se abre (trampillas). `vanos`: por lado ("n", "s", "e", "o") los
## vanos de su muro.
func plataforma(t: Transform3D, rect: Rect2, y_base: float, y_tapa: float, huecos: Array = [], vanos: Dictionary = {}, mat := "pirca") -> void:
	var g := 0.6
	var x0 := rect.position.x
	var z0 := rect.position.y
	var x1 := rect.end.x
	var z1 := rect.end.y
	var alto := y_tapa - y_base
	var tb := t * Transform3D(Basis(), Vector3(0, y_base, 0))
	# Muros con el exterior hacia fuera del rectangulo; la cara de fuera queda en el borde del rectangulo.
	muro_entre(mat, tb, Vector3(x0, 0, z1 - g * 0.5), Vector3(x1, 0, z1 - g * 0.5), alto, g, vanos.get("s", []), 0.1)
	muro_entre(mat, tb, Vector3(x1, 0, z0 + g * 0.5), Vector3(x0, 0, z0 + g * 0.5), alto, g, vanos.get("n", []), 0.1)
	muro_entre(mat, tb, Vector3(x1 - g * 0.5, 0, z1 - g), Vector3(x1 - g * 0.5, 0, z0 + g), alto, g, vanos.get("e", []), 0.1, false)
	muro_entre(mat, tb, Vector3(x0 + g * 0.5, 0, z0 + g), Vector3(x0 + g * 0.5, 0, z1 - g), alto, g, vanos.get("o", []), 0.1, false)
	# Tapa de tierra (0,35 m) entre las caras de dentro de los muros, partida alrededor de los huecos.
	var d := g * 0.95
	for r: Rect2 in _restar_rects(Rect2(x0 + d, z0 + d, rect.size.x - 2.0 * d, rect.size.y - 2.0 * d), huecos):
		var c := r.get_center()
		caja("pirca", t, Vector3(c.x, y_tapa - 0.175, c.y), Vector3(r.size.x, 0.35, r.size.y), "tierra", true)


## Resta rectangulos (sin solaparse entre ellos) de `r`: devuelve rectangulos que cubren el resto.
func _restar_rects(r: Rect2, huecos: Array) -> Array:
	var lista := [r]
	for h: Rect2 in huecos:
		var nueva := []
		for a: Rect2 in lista:
			if not a.intersects(h):
				nueva.append(a)
				continue
			var i := a.intersection(h)
			if i.position.y > a.position.y:
				nueva.append(Rect2(a.position.x, a.position.y, a.size.x, i.position.y - a.position.y))
			if i.end.y < a.end.y:
				nueva.append(Rect2(a.position.x, i.end.y, a.size.x, a.end.y - i.end.y))
			if i.position.x > a.position.x:
				nueva.append(Rect2(a.position.x, i.position.y, i.position.x - a.position.x, i.size.y))
			if i.end.x < a.end.x:
				nueva.append(Rect2(i.end.x, i.position.y, a.end.x - i.end.x, i.size.y))
		lista = nueva
	return lista


# --- Utileria -------------------------------------------------------------------------------------

## Superficie de revolucion: `perfil` = puntos (radio, y) de abajo arriba.
func torno(mat: String, t: Transform3D, perfil: Array, lados := 14) -> void:
	for j in perfil.size() - 1:
		var a: Vector2 = perfil[j]
		var b: Vector2 = perfil[j + 1]
		var e := b - a
		var n2 := Vector2(e.y, -e.x).normalized()   # hacia fuera
		for i in lados:
			var a0 := TAU * i / lados
			var a1 := TAU * (i + 1) / lados
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var p := [d0 * a.x + Vector3.UP * a.y, d1 * a.x + Vector3.UP * a.y, d1 * b.x + Vector3.UP * b.y, d0 * b.x + Vector3.UP * b.y]
			var n := [d0 * n2.x + Vector3.UP * n2.y, d1 * n2.x + Vector3.UP * n2.y, d1 * n2.x + Vector3.UP * n2.y, d0 * n2.x + Vector3.UP * n2.y]
			var uv := [Vector2(float(i) / lados, a.y), Vector2(float(i + 1) / lados, a.y), Vector2(float(i + 1) / lados, b.y), Vector2(float(i) / lados, b.y)]
			triangulo_suave(mat, t, [p[0], p[1], p[2]], [n[0], n[1], n[2]], [uv[0], uv[1], uv[2]])
			triangulo_suave(mat, t, [p[0], p[2], p[3]], [n[0], n[2], n[3]], [uv[0], uv[2], uv[3]])


## Aribalo (la tinaja inca de base en punta y cuello largo), apoyado un poco hundido.
func aribalo(t: Transform3D, alto := 0.75) -> void:
	var k := alto / 0.75
	var perfil := []
	for p: Vector2 in [Vector2(0.0, -0.06), Vector2(0.09, 0.02), Vector2(0.19, 0.14), Vector2(0.25, 0.28), Vector2(0.25, 0.38),
			Vector2(0.2, 0.5), Vector2(0.1, 0.57), Vector2(0.065, 0.62), Vector2(0.065, 0.69), Vector2(0.12, 0.75), Vector2(0.09, 0.75)]:
		perfil.append(p * k)
	torno("ceramica", t, perfil)
	colision_cara(t, [Vector3(-0.2, 0, -0.2) * k, Vector3(0.2, 0, -0.2) * k, Vector3(0.2, 0.5, -0.2) * k, Vector3(-0.2, 0.5, -0.2) * k])


## Fardo de ichu atado: un bloque de paja. Apilados sirven de escalon y de escondite.
func fardo(t: Transform3D, tam := Vector3(1.1, 0.55, 0.6)) -> void:
	caja("ichu", t, Vector3(0, tam.y * 0.5, 0), tam)


## Batan: losa de moler con su chungo (la piedra que la acompana).
func batan(t: Transform3D) -> void:
	caja("pirca", t, Vector3(0, 0.08, 0), Vector3(0.9, 0.16, 0.6))
	caja("pirca", t, Vector3(0.1, 0.22, 0.05), Vector3(0.32, 0.12, 0.2), "", false, false)


# --- Montaje --------------------------------------------------------------------------------------

## Crea las MeshInstance3D (una por material) y el cuerpo estatico con toda la colision, como hijos de `padre`.
## Las coordenadas de las piezas ya son las de `padre`.
func construir(padre: Node3D, nombre: String) -> void:
	var mats := MaterialesInca.todos()
	for mat: String in _mallas:
		var malla := (_mallas[mat] as SurfaceTool).commit()
		if malla.get_surface_count() == 0:
			continue
		malla.surface_set_material(0, mats[mat])
		var mi := MeshInstance3D.new()
		mi.name = "%s_%s" % [nombre, mat]
		mi.mesh = malla
		padre.add_child(mi)
	if not _colision.is_empty():
		var cuerpo := StaticBody3D.new()
		cuerpo.name = nombre + "_colision"
		var forma := ConcavePolygonShape3D.new()
		forma.backface_collision = true
		forma.set_faces(_colision)
		var col := CollisionShape3D.new()
		col.shape = forma
		cuerpo.add_child(col)
		padre.add_child(cuerpo)
	_mallas.clear()
	_colision = PackedVector3Array()


## Triangulos dibujados desde que se creo el kit (para medir).
func triangulos() -> int:
	return _triangulos
