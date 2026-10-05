class_name Templo
extends Node3D
## Zona 3 del Nivel 1: el Templo del Sol de Vilcashuaman, en la explanada alta del sureste, mirando al amanecer del Inti
## Raymi. El 21 de junio el sol sale a ~65,8 grados de acimut (ENE) en esta latitud: todo el recinto se orienta a esa linea.
##
## - Plataforma ceremonial de 68 x 64 m (donde llega el Qhapaq Ñan por el oeste).
## - Plaza circular hundida, como en Caral: tres gradas de 0,8 m bajan a un piso redondo de 18 m.
## - Templo del Sol: tres terrazas de piedra poligonal con escalinata hacia el este, y arriba el Inti Wasi, con portada de
##   doble jamba hacia la escalinata y una puerta al este que da al borde, frente al horizonte por donde sale el sol.
## - Ushnu: piramide de tres cuerpos con escalinata, portada de doble jamba arriba y el "sillon del Inca".
## Marco local: -z mira al amanecer (ENE), +x al SSE, la y es la del mundo.

const ACIMUT_AMANECER := 65.8                  # grados desde el norte, 21 de junio a -13,65 de latitud
const CENTRO := Vector2(546.0, 250.0)          # mundo
const PLATAFORMA := Rect2(-34.0, -30.0, 68.0, 64.0)
const CIRCULO := Vector2(0.0, 16.0)            # centro de la plaza hundida (local)
const GRADAS := [9.0, 10.2, 11.4, 12.6]        # radios: piso, grada 1, grada 2, borde
const GRADA_ALTO := 0.8
const TEMPLO_Z := -15.0
const TERRAZAS := [Vector3(30, 28, 3.5), Vector3(22, 16, 3.5), Vector3(14, 8, 2.6)]   # ancho x, fondo z, alto
const USHNU := Vector2(22.0, 8.0)
const USHNU_CUERPOS := [15.0, 10.6, 6.2]
const USHNU_ALTO := 1.6

var terreno: Terreno
var miradores: Array[Dictionary] = []
var entrada := Vector3.ZERO      # pie de la escalinata de la plataforma (mundo), adonde llega el camino
var _base: Transform3D
var _tapa := 0.0
var _huellas: Array = []


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	# Basis(UP, a) lleva +z local a (sin a, 0, cos a): +z al revés del amanecer.
	var az := deg_to_rad(ACIMUT_AMANECER)
	var hacia_sol := Vector3(sin(az), 0.0, -cos(az))
	_base = Transform3D(Basis(Vector3.UP, atan2(-hacia_sol.x, -hacia_sol.z)), Vector3(CENTRO.x, 0.0, CENTRO.y))
	var kit := KitInca.new()
	_plataforma(kit)
	_plaza_hundida(kit)
	_templo(kit)
	_ushnu(kit)
	var tris := kit.triangulos()
	kit.construir(self, "templo")
	var giro := atan2(-hacia_sol.x, -hacia_sol.z)
	for hu: Array in _huellas:
		var r: Rect2 = hu[0]
		var c := _base * Vector3(r.get_center().x, 0.0, r.get_center().y)
		hu[0] = Vector2(c.x, c.z)
		hu.insert(1, r.size * 0.5)
		hu.insert(2, giro)
	terreno.pintar_obras(_huellas)
	print("templo: tapa a %.1f m, cima del templo a %.1f m, %d triangulos, %d ms" % [_tapa, _tapa + 9.6, tris, Time.get_ticks_msec() - t0])


func _l(x: float, y: float, z: float) -> Vector3:
	return _base * Vector3(x, y, z)


## Altura minima y maxima del suelo bajo un rectangulo local.
func _rango(r: Rect2) -> Vector2:
	var lo := INF
	var hi := -INF
	var nx := maxi(1, ceili(r.size.x / 2.0))
	var nz := maxi(1, ceili(r.size.y / 2.0))
	for j in nz + 1:
		for i in nx + 1:
			var p := _l(r.position.x + r.size.x * i / nx, 0.0, r.position.y + r.size.y * j / nz)
			var h := terreno.altura(p.x, p.z)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return Vector2(lo, hi)


# --- Plataforma y plaza hundida -------------------------------------------------------------------

## La plataforma lleva un hueco cuadrado donde va la plaza hundida; entre el cuadrado y el circulo del borde, una losa
## en sectores.
func _plataforma(kit: KitInca) -> void:
	var rango := _rango(PLATAFORMA)
	# Alta lo bastante para que la plaza hundida (2,4 m) quede por encima del suelo en todas partes.
	var r_c := Rect2(CIRCULO - Vector2.ONE * GRADAS[3], Vector2.ONE * GRADAS[3] * 2.0)
	var bajo_circulo := _rango(r_c)
	_tapa = maxf(rango.y + 0.6, bajo_circulo.y + GRADA_ALTO * 3.0 + 0.4)
	kit.plataforma(_base, PLATAFORMA, rango.x - 0.6, _tapa, [r_c], {}, "poligonal")
	_huellas.append([PLATAFORMA, 1.0, 3.0])
	# Losa entre el cuadrado del hueco y el circulo del borde (sectores convexos).
	var n := 48
	var R: float = GRADAS[3]
	var t := _base * Transform3D(Basis(), Vector3(CIRCULO.x, _tapa, CIRCULO.y))
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector3(cos(a0), 0, sin(a0))
		var p1 := Vector3(cos(a1), 0, sin(a1))
		var q0 := _al_cuadrado(p0, R)
		var q1 := _al_cuadrado(p1, R)
		var pts := [p0 * R, p1 * R, q1, q0]
		# Si el sector cruza una esquina del cuadrado, la esquina entra en el poligono.
		var esquina := Vector3(signf(p0.x + p1.x) * R, 0, signf(p0.z + p1.z) * R)
		if absf(q0.x - q1.x) > 0.01 and absf(q0.z - q1.z) > 0.01:
			pts = [p0 * R, p1 * R, q1, esquina, q0]
		var uvs := []
		for p: Vector3 in pts:
			uvs.append(Vector2(p.x, p.z))
		kit.cara("poligonal", t, pts, uvs, Vector3.UP)
	var entrada_local := Vector3(0.0, 0.0, PLATAFORMA.end.y)
	_escalera(kit, entrada_local, Vector3(0, 0, 1), 8.0)
	_mirador("explanada", Vector3(-10.0, _tapa + 1.6, PLATAFORMA.end.y - 3.0), Vector3(0.0, _tapa + 6.0, TEMPLO_Z))


## Punto donde el rayo desde el centro en la direccion d corta el cuadrado de semilado R.
static func _al_cuadrado(d: Vector3, R: float) -> Vector3:
	var k := R / maxf(absf(d.x), absf(d.z))
	return d * k


func _plaza_hundida(kit: KitInca) -> void:
	var t := _base * Transform3D(Basis(), Vector3(CIRCULO.x, 0.0, CIRCULO.y))
	var piso := _tapa - GRADA_ALTO * 3.0
	# Piso redondo
	var pts := []
	var uvs := []
	for i in 40:
		var a := TAU * i / 40.0
		pts.append(Vector3(cos(a) * GRADAS[0], piso, sin(a) * GRADAS[0]))
		uvs.append(Vector2(cos(a), sin(a)) * GRADAS[0])
	kit.cara("tierra", t, pts, uvs, Vector3.UP)
	# Gradas: un muro redondo en cada radio y una corona de losas encima, hasta la tapa de la plataforma.
	for k in 3:
		var r: float = GRADAS[k]
		var y0 := piso + GRADA_ALTO * k
		kit.anillo("poligonal", t * Transform3D(Basis(), Vector3(0, piso - 0.3, 0)), r + 0.3, y0 - piso + GRADA_ALTO + 0.3, 0.6, 40, {}, 0.0)
		var r2: float = GRADAS[k + 1]
		for i in 40:
			var a0 := TAU * i / 40.0
			var a1 := TAU * (i + 1) / 40.0
			var y := y0 + GRADA_ALTO
			var c := [Vector3(cos(a0) * (r + 0.6), y, sin(a0) * (r + 0.6)), Vector3(cos(a1) * (r + 0.6), y, sin(a1) * (r + 0.6)),
				Vector3(cos(a1) * r2, y, sin(a1) * r2), Vector3(cos(a0) * r2, y, sin(a0) * r2)]
			kit.cara("poligonal", t, c, [Vector2(c[0].x, c[0].z), Vector2(c[1].x, c[1].z), Vector2(c[2].x, c[2].z), Vector2(c[3].x, c[3].z)], Vector3.UP)
	_mirador("plaza_circular", Vector3(CIRCULO.x + 9.5, _tapa + 1.6, CIRCULO.y + 9.5), Vector3(CIRCULO.x, piso, CIRCULO.y))


# --- Templo del Sol -------------------------------------------------------------------------------

func _templo(kit: KitInca) -> void:
	var y := _tapa
	for k in TERRAZAS.size():
		var tz: Vector3 = TERRAZAS[k]
		var r := Rect2(-tz.x * 0.5, TEMPLO_Z - tz.y * 0.5, tz.x, tz.y)
		kit.plataforma(_base, r, y - 0.6, y + tz.z, [], {}, "poligonal")
		# Escalinata de 6 m por el oeste, del piso de abajo al borde de esta terraza.
		_escalera(kit, Vector3(0.0, y + tz.z - _tapa, TEMPLO_Z + tz.y * 0.5), Vector3(0, 0, 1), 6.0, y)
		y += tz.z
	var cima := y
	_inti_wasi(kit, cima)
	var borde_este := TEMPLO_Z - (TERRAZAS[2] as Vector3).y * 0.5
	_mirador("templo", Vector3(14.0, _tapa + 1.6, TEMPLO_Z + 26.0), Vector3(0.0, cima, TEMPLO_Z))
	miradores.append({"nombre": "amanecer", "pos": _l(0.0, cima + 1.6, borde_este + 0.8), "mira": _l(0.0, cima - 40.0, borde_este - 2000.0), "hora": 6.55})
	miradores.append({"nombre": "atardecer", "pos": _l(0.0, cima + 1.6, borde_este + 0.8), "mira": _l(0.0, cima + 20.0, borde_este + 2000.0), "hora": 17.3})


## Casa del Sol sobre la terraza de arriba: silleria, portada de doble jamba al oeste (hacia la escalinata) y puerta al
## este, al borde de la terraza, frente a la salida del sol.
func _inti_wasi(kit: KitInca, cima: float) -> void:
	var t := _base * Transform3D(Basis(), Vector3(0.0, cima, TEMPLO_Z))
	var largo := 10.0
	var fondo := 5.6
	var g := 0.8
	var mx := largo * 0.5
	var mz := fondo * 0.5
	var alero := 3.0
	# Oeste (+z): portada de doble jamba en el centro.
	_muro_doble_jamba(kit, t, Vector3(-mx, 0, mz - g * 0.5), Vector3(mx, 0, mz - g * 0.5), alero, g)
	# Este (-z): puerta al borde, y hornacinas.
	kit.muro_entre("silleria", t, Vector3(mx, 0, -mz + g * 0.5), Vector3(-mx, 0, -mz + g * 0.5), alero, g,
		[KitInca.puerta(mx, 1.1), KitInca.vano(1.5, 0.5, 0.38, 1.1, 1.75, 0.3, -1), KitInca.vano(largo - 1.5, 0.5, 0.38, 1.1, 1.75, 0.3, -1)])
	var tg := tan(deg_to_rad(40.0))
	var cumbre := alero + mz * tg
	for s in [1.0, -1.0]:
		var x: float = s * (mx - g * 0.5)
		kit.muro_entre("silleria", t, Vector3(x, 0, s * (mz - g)), Vector3(x, 0, -s * (mz - g)), alero, g,
			[KitInca.vano(mz - g, 0.5, 0.38, 1.1, 1.75, 0.3, -1)], 0.2, false)
		kit.hastial("silleria", KitInca.marco_muro(t, Vector3(x, 0, s * mz), Vector3(x, 0, -s * mz)), fondo, alero, cumbre - 0.1, g * 0.8)
	# Cumbrera a lo largo (x), entre los dos hastiales.
	kit.techo_dos_aguas(t, -mx - 0.4, mx + 0.4, fondo, alero, 40.0, 0.7, 0.4, "silleria", g)
	# Dentro: una piedra-altar junto a la puerta este, sin cerrar el paso.
	kit.caja("poligonal", t, Vector3(-2.8, 0.45, -mz + g + 0.6), Vector3(1.6, 0.9, 0.7))


## Muro de a a b con una portada de doble jamba en el centro: un vano grande poco profundo y, dentro, el vano de paso.
func _muro_doble_jamba(kit: KitInca, t: Transform3D, a: Vector3, b: Vector3, alto: float, g: float) -> void:
	var largo := a.distance_to(b)
	var c := largo * 0.5
	kit.muro_entre("silleria", t, a, b, alto, g, [KitInca.vano(c, 2.0, 1.6, 0.0, 2.7)])
	# Marco interior, retranqueado 0,25 m: tapa el vano grande menos la puerta.
	var dir := (b - a).normalized()
	var fuera := dir.cross(Vector3.UP)
	var ma := a + dir * (c - 1.0) - fuera * 0.125
	var mb := a + dir * (c + 1.0) - fuera * 0.125
	kit.muro_entre("silleria", t, ma, mb, 2.7, g - 0.25, [KitInca.vano(1.0, 1.25, 1.0, 0.0, 2.35)], 0.0, false)


# --- Ushnu ----------------------------------------------------------------------------------------

## Piramide de tres cuerpos. La escalinata sube por el lado oeste (hacia la plaza hundida, -x local) con la misma pendiente
## que sus rampas de colision: arranca fuera para pasar siempre por encima de las esquinas de los cuerpos.
func _ushnu(kit: KitInca) -> void:
	var y := _tapa
	for k in USHNU_CUERPOS.size():
		var l: float = USHNU_CUERPOS[k]
		kit.plataforma(_base, Rect2(USHNU.x - l * 0.5, USHNU.y - l * 0.5, l, l), y - 0.6, y + USHNU_ALTO, [], {}, "poligonal")
		y += USHNU_ALTO
	var alto := USHNU_ALTO * USHNU_CUERPOS.size()
	var n := ceili(alto / 0.26)
	var fin := n * 0.34
	var cima_borde := USHNU.x - (USHNU_CUERPOS[-1] as float) * 0.5
	var pie := Vector3(cima_borde - fin - 0.1, _tapa, USHNU.y)
	kit.escalera("poligonal", _base * Transform3D(Basis(Vector3.UP, -PI * 0.5), pie), 2.4, alto)
	_huellas.append([Rect2(USHNU.x - 9.0, USHNU.y - 8.0, 18.0, 16.0), 1.0, 1.0])
	# Arriba: portada de doble jamba suelta al llegar de la escalinata y el sillon del Inca (asiento doble).
	var t := _base * Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(cima_borde + 0.7, y, USHNU.y))
	_muro_doble_jamba(kit, t, Vector3(-2.2, 0, 0), Vector3(2.2, 0, 0), 3.0, 0.8)
	var ts := _base * Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(USHNU.x + 1.2, y, USHNU.y))
	for s in [-0.45, 0.45]:
		kit.caja("poligonal", ts, Vector3(s, 0.25, 0), Vector3(0.75, 0.5, 0.7))
		kit.caja("poligonal", ts, Vector3(s, 0.65, 0.3), Vector3(0.75, 1.3, 0.12))
	_mirador("ushnu", _l(USHNU.x - 16.0, _tapa + 1.6, USHNU.y + 6.0), _l(USHNU.x, y, USHNU.y))
	_mirador("desde_ushnu", _l(USHNU.x + 2.2, y + 1.6, USHNU.y), _l(-10.0, _tapa, CIRCULO.y))


# --- Utilidades -----------------------------------------------------------------------------------

func _mirador(nombre: String, pos_local: Vector3, mira_local: Vector3) -> void:
	miradores.append({"nombre": nombre, "pos": _base * pos_local, "mira": _base * mira_local})


## Escalera desde abajo hasta un borde (local). `borde.y` relativo a la tapa de la plataforma; `n` hacia fuera. Si se da
## `piso` (y del mundo), el pie esta a esa altura (sobre otra terraza); si no, en el suelo.
func _escalera(kit: KitInca, borde: Vector3, n: Vector3, ancho: float, piso := NAN) -> void:
	var arriba := _tapa + borde.y
	var pie_y := piso
	var fin := 0.0
	if is_nan(piso):
		var p := _l(borde.x + n.x * 2.0, 0.0, borde.z + n.z * 2.0)
		pie_y = terreno.altura(p.x, p.z)
		for k in 2:
			fin = ceili((arriba - pie_y) / 0.26) * 0.34
			p = _l(borde.x + n.x * fin, 0.0, borde.z + n.z * fin)
			pie_y = terreno.altura(p.x, p.z)
		entrada = _l(borde.x + n.x * fin, pie_y, borde.z + n.z * fin)
	if arriba - pie_y < 0.2:
		return
	fin = ceili((arriba - pie_y) / 0.26) * 0.34
	var pie := Vector3(borde.x + n.x * fin, pie_y, borde.z + n.z * fin)
	kit.escalera("poligonal", _base * Transform3D(Basis(Vector3.UP, atan2(n.x, n.z)), pie), ancho, arriba - pie_y)
