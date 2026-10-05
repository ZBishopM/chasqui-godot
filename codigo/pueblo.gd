class_name Pueblo
extends Node3D
## Zona 1 del Nivel 1: el pueblo (llaqta) junto a la plaza de Vilcashuaman, hecho con KitInca.
##
## Traza en cuadricula como Ollantaytambo: manzanas de dos kanchas (cercos con casas alrededor de un patio) separadas
## por callejones de 4 m, alrededor de una plaza de 92 x 56 m con dos kallankas (galpones largos de silleria) que le
## abren sus puertas. La meseta no es llana (~10 m de desnivel en 160 m): cada kancha se asienta en su propia plataforma
## de pirca a la altura de su punto mas alto, asi el pueblo baja en terrazas y los callejones quedan entre muros.
## Al este, andenes con colcas suben la ladera (camino al templo, zona 2); al oeste, casas redondas en las afueras.
##
## Para el parkour (N4 lo completa): techos de ichu a 40 grados (se camina por ellos), muros de 2,3 m con coronacion
## transitable, pilas de fardos y escaleras para subir, callejones que se saltan de techo a techo.
## Escondites: colcas (se entra agachado), casas oscuras, fardos, y un sotano bajo una casa del oeste (trampilla detras
## de unos fardos, salida a gatas por el muro de la plataforma).
##
## Coordenadas del pueblo ("locales"): x este, z sur, giradas ROT grados alrededor de la plaza; la y es la del mundo.

const ROT := -9.0                     # grados: giro de la cuadricula respecto al norte
const KANCHA := Vector2(22.0, 26.0)   # m de un cerco
const PASO := Vector2(48.0, 30.0)     # manzana (2 kanchas = 44 m) + callejon de 4 m
const PLAZA := Rect2(-46.0, -28.0, 92.0, 56.0)
const G := 0.6                        # grueso de muro
const CERCO := 2.3                    # alto de los cercos
const ALERO := 2.5                    # alto de los muros de las casas
const FONDO_WASI := 5.4               # fondo exterior de una casa
const SEMILLA := 1532

## [columna, fila, tipo]: manzana en x = col * 48 + 2, z = fila * 30 + 2.
const MANZANAS := [
	[-2, -3, ""], [-1, -3, ""], [0, -3, ""],
	[-3, -2, ""], [-2, -2, ""], [-1, -2, "kallanka"], [0, -2, "kallanka"],
	[-3, -1, ""], [-2, -1, ""],
	[-3, 0, "sotano"], [-2, 0, ""],
	[-3, 1, ""], [-2, 1, ""], [-1, 1, ""],
	[-2, 2, ""], [-1, 2, ""],
]
const ANDENES := Rect2(52.0, -58.0, 42.0, 60.0)   # 6 terrazas de 7 m hacia el este, en tramos de 15 m
const CASAS_REDONDAS := [Vector2(-168, -30), Vector2(-176, -8), Vector2(-164, 14), Vector2(-181, 30), Vector2(-160, 48)]

var terreno: Terreno
## Puntos de vista para el recorrido (nivel1, F3): {nombre, pos (ojos, mundo), mira (mundo)}.
var miradores: Array[Dictionary] = []

var _base: Transform3D
var _rng := RandomNumberGenerator.new()
var _huellas: Array = []    # [rect local, valor, margen m]
var _cuenta := {"kanchas": 0, "casas": 0, "colcas": 0, "triangulos": 0}


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_base = Transform3D(Basis(Vector3.UP, deg_to_rad(ROT)), Vector3.ZERO)
	_rng.seed = SEMILLA
	for i in MANZANAS.size():
		var m: Array = MANZANAS[i]
		var rect := Rect2(m[0] * PASO.x + 2.0, m[1] * PASO.y + 2.0, KANCHA.x * 2.0, KANCHA.y)
		var kit := KitInca.new()
		if m[2] == "kallanka":
			_kallanka(kit, rect)
		else:
			# Dos kanchas gemelas: la del este empieza sobre el muro que comparten.
			var a := Rect2(rect.position, KANCHA)
			var b := Rect2(rect.position + Vector2(KANCHA.x - G, 0.0), Vector2(KANCHA.x + G, KANCHA.y))
			var tapa_a := _kancha(kit, a, "e", m[2] == "sotano")
			var tapa_b := _kancha(kit, b, "o", false)
			# El muro compartido arranca de la plataforma mas alta (la otra le hace de muro de contencion).
			var x := a.end.x - G * 0.5
			kit.muro_entre("pirca", _base, Vector3(x, maxf(tapa_a, tapa_b), a.position.y + G), Vector3(x, maxf(tapa_a, tapa_b), a.end.y - G), CERCO, G)
		_cuenta["triangulos"] += kit.triangulos()
		kit.construir(self, "manzana_%d" % i)
	var kit_p := KitInca.new()
	_plaza(kit_p)
	_andenes(kit_p)
	_afueras(kit_p)
	_cuenta["triangulos"] += kit_p.triangulos()
	kit_p.construir(self, "plaza_andenes")
	_marcar_obras()
	_miradores_generales()
	print("pueblo: %d kanchas, %d casas, %d colcas, %d triangulos, %d ms" % [
		_cuenta.kanchas, _cuenta.casas, _cuenta.colcas, _cuenta.triangulos, Time.get_ticks_msec() - t0])


# --- Utilidades de terreno ------------------------------------------------------------------------

## Punto local del pueblo (x, z) en el mundo.
func _mundo(x: float, z: float, y := 0.0) -> Vector3:
	return _base * Vector3(x, y, z)


func _altura(x: float, z: float) -> float:
	var p := _mundo(x, z)
	return terreno.altura(p.x, p.z)


## Altura minima y maxima del suelo bajo un rectangulo local (muestras cada 2 m).
func _rango(r: Rect2) -> Vector2:
	var lo := INF
	var hi := -INF
	var nx := maxi(1, ceili(r.size.x / 2.0))
	var nz := maxi(1, ceili(r.size.y / 2.0))
	for j in nz + 1:
		for i in nx + 1:
			var h := _altura(r.position.x + r.size.x * i / nx, r.position.y + r.size.y * j / nz)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return Vector2(lo, hi)


func _mirador(nombre: String, pos_local: Vector3, mira_local: Vector3) -> void:
	miradores.append({"nombre": nombre, "pos": _base * pos_local, "mira": _base * mira_local})


# --- Kancha ---------------------------------------------------------------------------------------

## Lado de una kancha de semiancho hw y semifondo hd (local a su centro): normal hacia fuera, extremos de la linea media
## del muro (con el exterior a la derecha de a -> b), punto medio del borde exterior, direccion, largo y `centro` (la u
## del punto medio del borde, medida desde a). Si la kancha comparte su lado este, los lados norte y sur se paran antes
## del muro compartido: esa esquina la pone la gemela (asi no hay dos muros en el mismo sitio).
func _lado(k: String, hw: float, hd: float, compartido := "") -> Dictionary:
	var ld: Dictionary
	var corte := G if compartido == "e" else 0.0
	match k:
		"s":
			ld = {"n": Vector3(0, 0, 1), "a": Vector3(-hw, 0, hd - G * 0.5), "b": Vector3(hw - corte, 0, hd - G * 0.5), "borde": Vector3(0, 0, hd)}
		"n":
			ld = {"n": Vector3(0, 0, -1), "a": Vector3(hw - corte, 0, -(hd - G * 0.5)), "b": Vector3(-hw, 0, -(hd - G * 0.5)), "borde": Vector3(0, 0, -hd)}
		"e":
			ld = {"n": Vector3(1, 0, 0), "a": Vector3(hw - G * 0.5, 0, hd - G), "b": Vector3(hw - G * 0.5, 0, -(hd - G)), "borde": Vector3(hw, 0, 0)}
		_:
			ld = {"n": Vector3(-1, 0, 0), "a": Vector3(-(hw - G * 0.5), 0, -(hd - G)), "b": Vector3(-(hw - G * 0.5), 0, hd - G), "borde": Vector3(-hw, 0, 0)}
	var a: Vector3 = ld.a
	var b: Vector3 = ld.b
	ld["largo"] = a.distance_to(b)
	ld["dir"] = (b - a) / a.distance_to(b)
	ld["centro"] = ((ld.borde as Vector3) - a).dot((b - a) / a.distance_to(b))
	return ld


## Giro (alrededor de Y) que lleva el +z local a `v` (horizontal).
static func _giro_hacia(v: Vector3) -> Basis:
	return Basis(Vector3.UP, atan2(v.x, v.z))


## Giro que lleva el +z local a -n: hacia dentro de la kancha.
static func _giro_adentro(n: Vector3) -> Basis:
	return _giro_hacia(-n)


## Una kancha en el rectangulo local `r` sobre su plataforma. `compartido`: lado que comparte con su gemela (ese muro
## lo pone la manzana). Cerco con portada hacia la plaza, 1-2 casas, patio con pozo/batan/aribalos, fardos para subir
## al muro y, a veces, escalera de piedra. Devuelve la altura de la plataforma.
func _kancha(kit: KitInca, r: Rect2, compartido: String, sotano: bool) -> float:
	_cuenta["kanchas"] += 1
	var hw := r.size.x * 0.5
	var hd := r.size.y * 0.5
	var c := r.get_center()
	var rango := _rango(r)
	var tapa := rango.y + 0.25
	var base := rango.x - 0.6
	# Portada: el lado libre que mejor mira a la plaza y menos escalera pide.
	var lados_libres: Array[String] = []
	for k: String in ["n", "s", "e", "o"]:
		if k != compartido:
			lados_libres.append(k)
	var portada := ""
	var mejor := -INF
	for k in lados_libres:
		var ld := _lado(k, hw, hd, compartido)
		var fuera: Vector3 = ld.borde + ld.n * 2.5
		var h_fuera := _altura(c.x + fuera.x, c.y + fuera.z)
		var hacia_plaza := (Vector3(-c.x, 0, -c.y)).normalized()
		var puntos: float = (ld.n as Vector3).dot(hacia_plaza) * 2.0 - (tapa - h_fuera)
		if sotano and k == "o":
			puntos = -INF   # el sotano va bajo la casa del oeste
		if puntos > mejor:
			mejor = puntos
			portada = k
	# Casas en los otros lados libres.
	var casas := {}   # lado -> largo
	for k in lados_libres:
		if k == portada:
			continue
		if sotano and k == "o" or _rng.randf() < 0.85 or casas.is_empty() and k == lados_libres[-1]:
			var largo_lado := 2.0 * (hw if k == "n" or k == "s" else hd - G)
			var maximo := largo_lado - 2.0 * (FONDO_WASI + 0.8)
			casas[k] = snappedf(_rng.randf_range(8.0, maxf(8.0, minf(maximo, 12.0))), 0.1)

	# Sotano: camara bajo la casa del oeste, con trampilla dentro de la casa y salida por el muro de la plataforma.
	var huecos := []
	var vanos_plat := {}
	var camara := {}
	if sotano:
		var cam := Rect2(-hw + G, -2.4, 3.6, 5.0)   # local a la kancha
		var trampilla := Rect2(-hw + G + 1.9, -1.6, 1.3, 1.3)
		var r_cam := _rango(Rect2(cam.position + c, cam.size))
		var piso := r_cam.y + 0.05
		tapa = maxf(tapa, piso + 0.35 + 1.85)   # de pie dentro, para poder saltar a los bloques
		camara = {"rect": cam, "trampilla": trampilla, "piso": piso}
		huecos.append(Rect2(trampilla.position + c, trampilla.size))
		var u := (c.y + cam.get_center().y) - (r.position.y + G)   # a lo largo del muro oeste de la plataforma
		vanos_plat["o"] = [KitInca.vano(u, 0.95, 0.8, piso - base, piso - base + 1.3)]
	kit.plataforma(_base, r, base, tapa, huecos, vanos_plat)
	_huellas.append([r, 1.0, 2.0])
	var tk := _base * Transform3D(Basis(), Vector3(c.x, tapa, c.y))

	# Casas
	var huecos_cerco := {}
	for k: String in casas:
		var ld := _lado(k, hw, hd, compartido)
		var largo: float = casas[k]
		var b := _giro_adentro(ld.n)
		var centro: Vector3 = ld.borde - ld.n * (FONDO_WASI * 0.5)
		var puertas := [0.0] if largo < 10.0 else [-largo * 0.25, largo * 0.25]
		if sotano and k == "o":
			puertas = [-largo * 0.2]
		var tw := tk * Transform3D(b, centro)
		var cumbre := kit.wasi(tw, largo, FONDO_WASI, ALERO, puertas)
		_cuenta["casas"] += 1
		var uc: float = ld.centro
		huecos_cerco[k] = [uc - largo * 0.5, uc + largo * 0.5]
		# Aribalos junto al frente, lejos de las puertas; a veces un batan.
		var frente: Vector3 = ld.borde - ld.n * (FONDO_WASI + 0.45)
		var dir: Vector3 = ld.dir
		for s in [-1.0, 1.0]:
			if _rng.randf() < 0.7:
				kit.aribalo(tk * Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), frente + dir * s * (largo * 0.5 - 1.1)), _rng.randf_range(0.6, 0.8))
		if _rng.randf() < 0.6:
			kit.batan(tk * Transform3D(b * Basis(Vector3.UP, _rng.randf_range(-0.4, 0.4)), frente - ld.n * 1.4 + dir * _rng.randf_range(-2.0, 2.0)))
		if _miradores_casa_pendiente:
			_miradores_casa_pendiente = false
			# Dentro de la primera casa, mirando a las hornacinas del fondo; y desde su cumbrera.
			var dentro := tw * Vector3(0, 1.6, 1.2)
			var fondo := tw * Vector3(0, 1.3, -FONDO_WASI * 0.5)
			miradores.append({"nombre": "casa", "pos": dentro, "mira": fondo})
			miradores.append({"nombre": "tejado", "pos": tw * Vector3(-largo * 0.5 + 0.5, cumbre + 0.7 + 1.6, 0), "mira": tw * Vector3(largo * 4.0, cumbre - 2.0, 0)})
		if sotano and k == "o":
			_sotano(kit, tk, camara, r, c)

	# Cerco: cada lado libre menos lo que ocupan las casas; la portada en el lado elegido.
	for k in lados_libres:
		var ld := _lado(k, hw, hd, compartido)
		var a: Vector3 = ld.a
		var largo_lado: float = ld.largo
		var dir: Vector3 = ld.dir
		var tramos := [[0.0, largo_lado]]
		if huecos_cerco.has(k):
			var h: Array = huecos_cerco[k]
			tramos = [[0.0, h[0]], [h[1], largo_lado]]
		for tr: Array in tramos:
			if tr[1] - tr[0] < 0.3:
				continue
			var vanos := []
			if k == portada:
				var u: float = ld.centro - tr[0]
				if u > 0.0 and u < tr[1] - tr[0]:
					vanos.append(KitInca.vano(u, 1.4, 1.15, 0.0, 2.05))
			kit.muro_entre("pirca", tk, a + dir * tr[0], a + dir * tr[1], CERCO, G, vanos)

	# Escalera de la portada, de la calle a la plataforma.
	var lp := _lado(portada, hw, hd, compartido)
	_escalera_exterior(kit, Vector2(c.x + lp.borde.x, c.y + lp.borde.z), lp.n, tapa, 2.0)

	# Pila de fardos junto al cerco de la portada, cerca de su arranque (sube al muro, y es escondite), y a veces una
	# escalera de piedra hacia el otro extremo.
	var largo_p: float = lp.largo
	var dir_p: Vector3 = lp.dir
	var n_p: Vector3 = lp.n
	var cara_dentro: Vector3 = (lp.a as Vector3) - n_p * (G * 0.5 + 0.02)   # cara de dentro del cerco, en a
	var tf := tk * Transform3D(_giro_adentro(n_p), cara_dentro + dir_p * 2.6)
	for col in 3:
		for alto in 3 - col:
			kit.fardo(tf * Transform3D(Basis(Vector3.UP, _rng.randf_range(-0.05, 0.05)), Vector3(0, alto * 0.55, 0.32 + col * 0.62)))
	if _rng.randf() < 0.4:
		var fin := ceili(CERCO / 0.26) * 0.34
		var pie := cara_dentro + dir_p * (largo_p - 3.0) - n_p * fin
		kit.escalera("pirca", tk * Transform3D(_giro_adentro(n_p), pie), 1.0, CERCO)
	# Patio: pozo a veces.
	if _rng.randf() < 0.3:
		var p := Vector3(_rng.randf_range(-2.0, 2.0), 0, _rng.randf_range(-2.0, 2.0))
		kit.pozo(tk * Transform3D(Basis(), p + Vector3(0, -0.2, 0)))
	if _miradores_kancha_pendiente:
		_miradores_kancha_pendiente = false
		miradores.append({"nombre": "patio", "pos": tk * (lp.borde - lp.n * 3.0 + Vector3(0, 1.6, 0)), "mira": tk * Vector3(0, 1.5, 0)})
	return tapa


var _miradores_casa_pendiente := true
var _miradores_kancha_pendiente := true


## Camara secreta dentro de la plataforma, bajo la casa del oeste: piso de tierra, muros de pirca, dos bloques para
## volver a subir por la trampilla, y una salida a gatas (1,3 m) por el muro oeste de la plataforma con un bloque fuera.
func _sotano(kit: KitInca, tk: Transform3D, camara: Dictionary, r: Rect2, c: Vector2) -> void:
	var cam: Rect2 = camara.rect
	var tr: Rect2 = camara.trampilla
	var tapa := tk.origin.y
	var piso: float = camara.piso - tapa     # relativo a la tapa (negativo)
	var techo := -0.35
	var x0 := cam.position.x
	var x1 := cam.end.x
	var z0 := cam.position.y
	var z1 := cam.end.y
	kit.caja("pirca", tk, Vector3(cam.get_center().x, piso - 0.15, cam.get_center().y), Vector3(cam.size.x, 0.3, cam.size.y), "tierra")
	var alto := techo - piso + 0.3
	var y := piso - 0.3
	kit.muro_entre("pirca", tk, Vector3(x1, y, z1), Vector3(x1, y, z0), alto, 0.5, [], 0.0)
	kit.muro_entre("pirca", tk, Vector3(x1, y, z0), Vector3(x0, y, z0), alto, 0.5, [], 0.0)
	kit.muro_entre("pirca", tk, Vector3(x0, y, z1), Vector3(x1, y, z1), alto, 0.5, [], 0.0)
	# Bloques bajo la trampilla: uno justo debajo, a 1,1 m del borde (se sube de un salto), y otro de la mitad al lado.
	var ct := tr.get_center()
	var b1 := -piso - 1.1
	kit.caja("pirca", tk, Vector3(ct.x, piso + b1 * 0.5, ct.y - 0.2), Vector3(0.9, b1, 0.9), "", false)
	kit.caja("pirca", tk, Vector3(ct.x - 1.0, piso + b1 * 0.25, ct.y - 0.2), Vector3(0.9, b1 * 0.5, 0.9), "", false)
	# Dentro: tinajas y fardos.
	kit.aribalo(tk * Transform3D(Basis(), Vector3(x0 + 0.6, piso, z0 + 0.7)), 0.7)
	kit.aribalo(tk * Transform3D(Basis(Vector3.UP, 1.0), Vector3(x0 + 1.3, piso, z0 + 0.6)), 0.65)
	kit.fardo(tk * Transform3D(Basis(Vector3.UP, 0.3), Vector3(x1 - 0.9, piso, z1 - 0.8)))
	# Fardos que tapan la trampilla a la vista desde la puerta (a un lado, no encima).
	kit.fardo(tk * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(ct.x + 1.05, 0, ct.y)))
	kit.fardo(tk * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(ct.x + 1.05, 0.55, ct.y)))
	kit.fardo(tk * Transform3D(Basis(), Vector3(ct.x, 0, ct.y + 1.25)))
	# Salida: bloque(s) fuera del muro oeste de la plataforma, para entrar desde la calle.
	var sal := Vector2(c.x - r.size.x * 0.5, c.y + cam.get_center().y)
	var h_fuera := _altura(sal.x - 0.6, sal.y)
	var abs_piso: float = camara.piso
	if abs_piso - h_fuera > 0.15:
		kit.caja("pirca", _base, Vector3(sal.x - 0.5, (abs_piso + h_fuera - 0.5) * 0.5, sal.y), Vector3(1.0, abs_piso - h_fuera + 0.5, 1.2))
		if abs_piso - h_fuera > 1.0:
			var medio := (abs_piso + h_fuera) * 0.5
			kit.caja("pirca", _base, Vector3(sal.x - 1.5, (medio + h_fuera - 0.5) * 0.5, sal.y), Vector3(1.0, medio - h_fuera + 0.5, 1.2))
	miradores.append({"nombre": "sotano", "pos": tk * Vector3(ct.x - 0.4, piso + 1.6, z1 - 0.6), "mira": tk * Vector3(x0, piso + 0.5, cam.get_center().y)})
	miradores.append({"nombre": "salida_sotano", "pos": _base * Vector3(sal.x - 6.0, h_fuera + 1.6, sal.y + 2.0), "mira": _base * Vector3(sal.x, abs_piso + 0.6, sal.y)})


## Escalera desde la calle hasta el borde de una plataforma: `borde` = punto medio del borde (local, xz), `n` hacia
## fuera, `tapa` = altura de arriba. Si el desnivel es pequeno no pone nada.
func _escalera_exterior(kit: KitInca, borde: Vector2, n: Vector3, tapa: float, ancho: float) -> void:
	var fuera := Vector2(n.x, n.z)
	var h := _altura(borde.x + fuera.x * 1.5, borde.y + fuera.y * 1.5)
	if tapa - h < 0.2:
		return
	# El pie depende de lo que mida la escalera: dos pasadas.
	var fin := 0.0
	for i in 2:
		fin = ceili((tapa - h) / 0.26) * 0.34
		h = _altura(borde.x + fuera.x * fin, borde.y + fuera.y * fin)
	var pie := borde + fuera * fin
	# La escalera sube hacia su -z local: hacia la plataforma.
	var t := _base * Transform3D(_giro_hacia(n), Vector3(pie.x, h, pie.y))
	kit.escalera("pirca", t, ancho, tapa - h)


# --- Kallanka -------------------------------------------------------------------------------------

## Manzana de kallanka: galpon de silleria de 40 x 10 m con seis puertas a la plaza sobre una terraza con escalinata;
## detras, un patio cercado con colcas al que se sale por dos puertas traseras.
func _kallanka(kit: KitInca, r: Rect2) -> void:
	var rango := _rango(r)
	var tapa := rango.y + 0.25
	kit.plataforma(_base, r, rango.x - 0.6, tapa, [], {}, "silleria")
	_huellas.append([r, 1.0, 2.0])
	var c := r.get_center()
	var largo := 40.0
	var fondo := 10.0
	var cz := r.end.y - 1.8 - fondo * 0.5
	var tk := _base * Transform3D(Basis(), Vector3(c.x, tapa, cz))
	var puertas := []
	for i in 6:
		puertas.append(-16.25 + i * 6.5)
	kit.wasi(tk, largo, fondo, 3.2, puertas, "silleria", 0.8, true, 1.25, [-9.75, 9.75])
	_cuenta["casas"] += 1
	_escalera_exterior(kit, Vector2(c.x, r.end.y), Vector3(0, 0, 1), tapa, 30.0)
	# Patio trasero: cerco al norte y a los lados hasta la espalda del galpon, con portada al norte.
	var tp := _base * Transform3D(Basis(), Vector3(0, tapa, 0))
	var x0 := r.position.x
	var x1 := r.end.x
	var z0 := r.position.y
	var z_esp := cz - fondo * 0.5
	kit.muro_entre("pirca", tp, Vector3(x1, 0, z0 + G * 0.5), Vector3(x0, 0, z0 + G * 0.5), CERCO, G, [KitInca.vano((x1 - x0) * 0.5, 1.4, 1.15, 0.0, 2.05)])
	kit.muro_entre("pirca", tp, Vector3(x1 - G * 0.5, 0, z_esp), Vector3(x1 - G * 0.5, 0, z0 + G), CERCO, G)
	kit.muro_entre("pirca", tp, Vector3(x0 + G * 0.5, 0, z0 + G), Vector3(x0 + G * 0.5, 0, z_esp), CERCO, G)
	_escalera_exterior(kit, Vector2(c.x, z0), Vector3(0, 0, -1), tapa, 2.0)
	var zc := (z0 + z_esp) * 0.5
	for i in 3:
		kit.colca(tp * Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(c.x - 12.0 + i * 12.0, 0, zc)))
		_cuenta["colcas"] += 1
	if miradores.is_empty() or not miradores.any(func(m: Dictionary) -> bool: return m.nombre == "kallanka"):
		miradores.append({"nombre": "kallanka", "pos": tk * Vector3(0, 1.6, 2.0), "mira": tk * Vector3(-15.0, 1.4, -3.0)})


# --- Plaza, andenes, afueras ----------------------------------------------------------------------

func _plaza(kit: KitInca) -> void:
	_huellas.append([PLAZA, 0.85, 4.0])
	var p := Vector2(-18.0, 9.0)
	kit.pozo(_base * Transform3D(Basis(), Vector3(p.x, _altura(p.x, p.y) - 0.2, p.y)), 1.1)


## Andenes al este de la plaza: terrazas de 7 m que suben la ladera en tramos de 15 m, con escaleras en el segundo tramo,
## piedras voladizas (sarunas) para saltar en el tercero y colcas en las tres de arriba.
func _andenes(kit: KitInca) -> void:
	var filas := int(ANDENES.size.x / 7.0)
	var tramos := int(ANDENES.size.y / 15.0)
	var tapas := []   # [fila][tramo]
	for i in filas:
		tapas.append([])
		for j in tramos:
			var r := Rect2(ANDENES.position.x + i * 7.0, ANDENES.position.y + j * 15.0, 7.0, 15.0)
			var rango := _rango(r)
			var tapa := rango.y + 0.15
			if i > 0:
				tapa = maxf(tapa, tapas[i - 1][j] + 0.6)   # siempre sube hacia el este
			tapas[i].append(tapa)
			kit.plataforma(_base, r, rango.x - 0.6, tapa)
			_huellas.append([r, 1.0, 1.5])
	var tp := _base * Transform3D(Basis(), Vector3.ZERO)
	for i in filas:
		for j in tramos:
			var tapa: float = tapas[i][j]
			var x_frente := ANDENES.position.x + i * 7.0
			var zc := ANDENES.position.y + (j + 0.5) * 15.0
			var abajo: float = tapas[i - 1][j] if i > 0 else _altura(x_frente - 1.0, zc)
			if j == 1:
				if i == 0:
					_escalera_exterior(kit, Vector2(x_frente, zc), Vector3(-1, 0, 0), tapa, 1.6)
				else:
					var fin := ceili((tapa - abajo) / 0.26) * 0.34
					kit.escalera("pirca", _base * Transform3D(_giro_hacia(Vector3(-1, 0, 0)), Vector3(x_frente - fin, abajo, zc)), 1.6, tapa - abajo)
			elif j == 2 and i > 0:
				# Sarunas: piedras que sobresalen del muro en diagonal, cada 0,55 m.
				var n := int((tapa - abajo) / 0.55)
				for k in n:
					kit.caja("pirca", tp, Vector3(x_frente - 0.22, abajo + (k + 1) * 0.55 - 0.09, zc - 2.0 + k * 0.95), Vector3(0.45, 0.18, 0.7))
			if i >= filas - 3:
				for s in [-1.0, 1.0]:
					kit.colca(_base * Transform3D(Basis(Vector3.UP, PI), Vector3(x_frente + 3.5, tapa, zc + s * 3.6)), 1.9, 2.5)
					_cuenta["colcas"] += 1
	var arriba: float = tapas[filas - 1][1]
	# Por encima de las colcas de arriba (en F3 el jugador cae sobre ellas): se ve el pueblo bajando hacia la plaza.
	_mirador("andenes", Vector3(ANDENES.end.x - 1.0, arriba + 6.5, ANDENES.position.y + 15.0), Vector3(-40.0, arriba - 14.0, -10.0))
	_mirador("sarunas", Vector3(ANDENES.position.x + 7.0 * 2 - 6.0, tapas[1][2] + 1.6, ANDENES.position.y + 2.5 * 15.0 + 4.0), Vector3(ANDENES.position.x + 7.0 * 2, tapas[2][2], ANDENES.position.y + 2.5 * 15.0 - 2.0))


## Casas redondas sueltas al oeste del pueblo, cada una con su zocalo y su piso.
func _afueras(kit: KitInca) -> void:
	for p: Vector2 in CASAS_REDONDAS:
		var radio := _rng.randf_range(2.4, 2.9)
		var rango := _rango(Rect2(p - Vector2(radio, radio), Vector2(radio, radio) * 2.0))
		var piso := rango.y + 0.05
		# La puerta (el +x local del anillo) mira mas o menos al pueblo: Basis(UP, a) lleva +x a (cos a, 0, -sin a).
		var giro := Basis(Vector3.UP, atan2(p.y, -p.x) + _rng.randf_range(-0.6, 0.6))
		var t := _base * Transform3D(giro, Vector3(p.x, piso, p.y))
		var zocalo := piso - rango.x + 0.3
		kit.anillo("pirca", _base * Transform3D(giro, Vector3(p.x, rango.x - 0.3, p.y)), radio, zocalo, 0.55, 12, {}, 0.0)
		var pts := []
		var uvs := []
		for i in 12:
			var a := TAU * i / 12.0
			pts.append(Vector3(cos(a), 0, sin(a)) * (radio - 0.2))
			uvs.append(Vector2(cos(a), sin(a)) * radio)
		kit.cara("tierra", t, pts, uvs, Vector3.UP)
		kit.casa_redonda(t, radio)
		kit.fardo(t * Transform3D(Basis(Vector3.UP, 0.4), Vector3(-radio - 1.2, 0, 0.8)))
		_huellas.append([Rect2(p - Vector2(radio, radio), Vector2(radio, radio) * 2.0), 1.0, 2.5])
		_cuenta["casas"] += 1
	var p0: Vector2 = CASAS_REDONDAS[1]
	_mirador("afueras", Vector3(p0.x + 14.0, _altura(p0.x + 14.0, p0.y + 6.0) + 1.6, p0.y + 6.0), Vector3(p0.x, _altura(p0.x, p0.y) + 1.5, p0.y))


func _miradores_generales() -> void:
	var h0 := _altura(0, 12)
	miradores.push_front({"nombre": "plaza", "pos": _mundo(0, 12, h0 + 1.6), "mira": _mundo(0, -40, h0 + 4.0)})
	var hc := _altura(-48, 45)
	_mirador("callejon", Vector3(-48, hc + 1.6, 45), Vector3(-48, hc + 1.0, -80))
	var hv := _altura(70, 75)
	_mirador("vista", Vector3(70, hv + 45.0, 75), Vector3(-50, 0, -20))


# --- Suelo de obra --------------------------------------------------------------------------------

## Pinta en una imagen de 1 m/px de la zona jugable donde hay obra (plataformas, casas, plaza, calles) y se la pasa al
## terreno: ahi no crece ichu ni se reparten plantas, y el suelo es de tierra pisada.
func _marcar_obras() -> void:
	var lado := 1200.0
	var n := int(lado) + 1
	var img := Image.create(n, n, false, Image.FORMAT_R8)
	var datos := PackedByteArray()
	datos.resize(n * n)
	datos.fill(0)
	# Todo el pueblo, calles incluidas: poco ichu, suelo pisado.
	var todo := Rect2(-150.0, -96.0, 250.0, 190.0).merge(Rect2(-190.0, -45.0, 60.0, 100.0))
	_huellas.push_front([todo, 0.8, 10.0])
	var inv := _base.basis.inverse()
	for hu: Array in _huellas:
		var r: Rect2 = hu[0]
		var valor: float = hu[1]
		var margen: float = hu[2]
		var centro := r.get_center()
		var medio := r.size * 0.5
		var cw := _mundo(centro.x, centro.y)
		var radio := medio.length() + margen
		var i0 := clampi(int(cw.x - radio + lado * 0.5), 0, n - 1)
		var i1 := clampi(int(cw.x + radio + lado * 0.5) + 1, 0, n - 1)
		var j0 := clampi(int(cw.z - radio + lado * 0.5), 0, n - 1)
		var j1 := clampi(int(cw.z + radio + lado * 0.5) + 1, 0, n - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var l := inv * Vector3(i - lado * 0.5 - cw.x, 0.0, j - lado * 0.5 - cw.z)
				var d := maxf(absf(l.x) - medio.x, absf(l.z) - medio.y)
				var v := valor * (1.0 - smoothstep(0.0, margen, d))
				if v <= 0.0:
					continue
				var k := j * n + i
				datos[k] = maxi(datos[k], int(v * 255.0))
	img.set_data(n, n, false, Image.FORMAT_R8, datos)
	terreno.poner_obras(img)
