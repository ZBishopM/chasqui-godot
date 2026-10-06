class_name Fosa
extends Node3D
## La fosa comun escondida (zona 2): en el filo norte del cañon (Canon), a 15 m del vacio, al sur del pueblo y del pozo,
## a ~100 m de la calzada y tapada desde ella por las lomas y unas rocas. Da miedo acercarse: un sendero de cabras baja
## del camino y sigue el filo del barranco. La cavaron los traidores, que creen a los oraculos (vendran dioses del mar)
## y atacaron la iglesia donde el Chasqui llevaba un mensaje de unidad contra ellos. Ahi, de noche y bajo la tormenta,
## despierta el Chasqui entre los muertos amortajados; su sangre le da las venas de oro.
##
## Un hoyo de ~10 m y 5,2 m de hondo con paredes de tierra removida, montones de la tierra sacada alrededor, barro y
## charcos, piedras para trepar por el lado del camino y una pala olvidada. Lleno: tres capas de cuerpos envueltos en
## mantas tejidas atadas con sogas (MaterialesInca "mortaja", cada una de otro tinte), echados en poses distintas; bajo
## los de abajo, charcos de sangre (Decal). La sangre baja con `secar_sangre()` durante la cinematica.

const CENTRO := Vector2(191.0, 160.0)   # mundo: en el filo del cañon, oculto desde la calzada (linea de vista)
const RADIO := 2.9                      # m: radio del fondo
const BORDE := 4.8                      # m: donde la pared sale al suelo (paredes de ~70 grados)
const HONDO := 5.2                      # m bajo el punto mas bajo del borde
## Sendero de cabras: de la calzada al filo del cañon y por el filo hasta la fosa (mundo, xz).
const SENDERO := [Vector2(250, 80), Vector2(246, 112), Vector2(236, 140), Vector2(220, 158), Vector2(205, 163)]
const CAMINO := Vector2(250.0, 80.0)    # donde el sendero deja la calzada
const CAPA_CUERPOS := 1 << 1
const ROCAS := ["res://assets/plantas/namaqualand_boulder_02/namaqualand_boulder_02.gltf", "res://assets/plantas/namaqualand_boulder_05/namaqualand_boulder_05.gltf"]

var terreno: Terreno
var miradores: Array[Dictionary] = []
## Donde yace el Chasqui al despertar (en el fondo, entre los cuerpos).
var despertar: Vector3
## Los cuerpos (MeshInstance3D con la mortaja; su sangre es el parametro de instancia "sangre") y de donde sale la sangre.
var cuerpos: Array[MeshInstance3D] = []
var fuentes: Array[Vector3] = []

var _piso := 0.0
var _charcos: Array[Decal] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_rng.seed = 1532
	# El fondo, HONDO por debajo del punto mas bajo del borde (antes de abrir el hueco, que deja el suelo en NaN).
	var bajo := INF
	for i in 24:
		var a := TAU * i / 24.0
		bajo = minf(bajo, terreno.altura(CENTRO.x + cos(a) * BORDE, CENTRO.y + sin(a) * BORDE))
	_piso = bajo - HONDO
	despertar = Vector3(CENTRO.x, _piso, CENTRO.y)
	var kit := KitInca.new()
	_hoyo(kit)
	_escalones(kit)
	_pala(kit)
	kit.construir(self, "fosa")
	_cuerpos()
	_charcos_de_sangre()
	_ocultar()
	_sendero()
	terreno.abrir_hueco(CENTRO.x, CENTRO.y, BORDE + 0.3, BORDE - 0.3)
	var hacia_camino := (CAMINO - CENTRO).normalized()
	var borde_camino := CENTRO + hacia_camino * (BORDE + 1.0)
	var hb := terreno.altura(borde_camino.x, borde_camino.y)
	miradores.append({"nombre": "fosa", "pos": Vector3(borde_camino.x, hb + 2.1, borde_camino.y), "mira": despertar + Vector3(-0.5, 0.3, 0.5), "hora": 10.5})
	print("fosa: fondo a %.1f m, %d cuerpos, %d ms" % [_piso, cuerpos.size(), Time.get_ticks_msec() - t0])


## Altura del suelo en un punto alrededor de la fosa (a `r` m del centro, angulo `a`).
func _suelo(a: float, r: float) -> float:
	return terreno.altura(CENTRO.x + cos(a) * r, CENTRO.y + sin(a) * r)


## Paredes de tierra removida (del fondo al borde, con el radio irregular), el monton de la tierra sacada alrededor
## (tapa el borde del hueco del terreno) y el fondo de barro con charcos de agua.
func _hoyo(kit: KitInca) -> void:
	var n := 48
	var ruido := FastNoiseLite.new()
	ruido.seed = 7
	ruido.frequency = 0.9
	# Anillos de dentro a fuera: [radio, altura] por angulo. Las paredes caen ~60 grados.
	var anillos := []
	for i in n + 1:
		var a := TAU * i / n
		var w := ruido.get_noise_1d(i * 1.7) * 0.3
		var w2 := ruido.get_noise_1d(i * 3.1 + 40.0) * 0.22
		var w3 := ruido.get_noise_1d(i * 2.3 + 80.0) * 0.18
		var borde := _suelo(a, BORDE) + 0.35 + w3 * 0.6
		var fila := [
			Vector3(cos(a) * (RADIO + w * 0.5), _piso, sin(a) * (RADIO + w * 0.5)),
			Vector3(cos(a) * (RADIO + (BORDE - RADIO) * 0.22 + w + w2), lerpf(_piso, borde, 0.38 + w3 * 0.3), sin(a) * (RADIO + (BORDE - RADIO) * 0.22 + w + w2)),
			Vector3(cos(a) * (RADIO + (BORDE - RADIO) * 0.6 + w - w2), lerpf(_piso, borde, 0.8 + w2 * 0.2), sin(a) * (RADIO + (BORDE - RADIO) * 0.6 + w - w2)),
			Vector3(cos(a) * BORDE, borde, sin(a) * BORDE),
			Vector3(cos(a) * (BORDE + 0.9 + w2), _suelo(a, BORDE + 0.9) + 0.45 + w * 0.9 + w3, sin(a) * (BORDE + 0.9 + w2)),
			Vector3(cos(a) * (BORDE + 2.4), _suelo(a, BORDE + 2.4) - 0.1, sin(a) * (BORDE + 2.4)),
		]
		anillos.append(fila)
	var t := Transform3D(Basis(), Vector3(CENTRO.x, 0.0, CENTRO.y))
	# Paredes y monton en una malla de normales suaves (con caras planas se veia a facetas); la colision va aparte.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var filas: int = (anillos[0] as Array).size()
	for i in n + 1:
		for k in filas:
			st.set_uv(Vector2(i * 0.9, k * 0.8))
			st.add_vertex(t * (anillos[i][k] as Vector3))
	for i in n:
		for k in filas - 1:
			var a := i * filas + k
			var b := (i + 1) * filas + k
			# Orden para que las caras miren hacia dentro y arriba (sentido horario visto de frente).
			for idx in [a, a + 1, b, b, a + 1, b + 1]:
				st.add_index(idx)
			kit.colision_cara(t, [anillos[i][k], anillos[i + 1][k], anillos[i + 1][k + 1], anillos[i][k + 1]])
	st.generate_normals()
	var paredes := MeshInstance3D.new()
	paredes.name = "fosa_paredes"
	paredes.mesh = st.commit()
	paredes.material_override = MaterialesInca.todos()["tierra"]
	add_child(paredes)
	# Fondo de barro.
	var pts := []
	var uvs := []
	for i in n:
		var a := TAU * i / n
		var r := RADIO + ruido.get_noise_1d(i * 1.7) * 0.12 + 0.05
		pts.append(Vector3(cos(a) * r, _piso + 0.01, sin(a) * r))
		uvs.append(Vector2(cos(a), sin(a)) * r)
	kit.cara("barro", t, pts, uvs, Vector3.UP)
	# Charcos de agua de lluvia.
	for c: Vector2 in [Vector2(0.5, -0.5), Vector2(-0.9, -1.1), Vector2(0.9, 0.3)]:
		var cp := []
		var cu := []
		var rc := _rng.randf_range(0.16, 0.3)
		for i in 18:
			var a := TAU * i / 18.0
			var rr := rc * (0.8 + 0.2 * sin(a * 3.0 + c.x) + 0.08 * sin(a * 7.0))
			cp.append(Vector3(c.x + cos(a) * rr * 1.4, _piso + 0.02, c.y + sin(a) * rr))
			cu.append(Vector2(cos(a), sin(a)))
		kit.cara("agua", t, cp, cu, Vector3.UP, false)


## Piedras salientes del lado del camino para trepar (escalones de ~0,55 m) desde el fondo hasta el borde.
func _escalones(kit: KitInca) -> void:
	var dir := (CAMINO - CENTRO).normalized()
	var a := atan2(dir.y, dir.x)
	var b := Basis(Vector3.UP, -a)
	var n := ceili((HONDO + 0.35) / 0.55)
	for k in n:
		var r := RADIO - 0.25 + k * (BORDE - RADIO + 0.1) / n
		var c := CENTRO + dir * r
		var alto := 0.55 * (k + 1)
		kit.caja("pirca", Transform3D(b, Vector3(c.x, _piso, c.y)), Vector3(0, alto * 0.5, 0), Vector3(0.5, alto, 0.9))


## La pala de los traidores, clavada en el monton de tierra.
func _pala(kit: KitInca) -> void:
	var a := 2.3
	var p := Vector2(CENTRO.x + cos(a) * (BORDE + 0.9), CENTRO.y + sin(a) * (BORDE + 0.9))
	var y := terreno.altura(p.x, p.y) + 0.3
	var t := Transform3D(Basis(Vector3.UP, 0.6) * Basis(Vector3.RIGHT, 0.35), Vector3(p.x, y, p.y))
	kit.caja("madera", t, Vector3(0, 0.6, 0), Vector3(0.05, 1.3, 0.05), "", true, false)
	kit.caja("madera", t, Vector3(0, -0.1, 0), Vector3(0.24, 0.32, 0.03), "", true, false)


# --- Cuerpos amortajados ------------------------------------------------------------------------------

## Cada cuerpo es un bulto envuelto con torpeza en una manta y atado con sogas. Su forma sale de un ragdoll de seis
## segmentos (cabeza, torso, pelvis, muslos, piernas, pies: las piernas van juntas dentro de la manta) que
## herramientas/hornear_fosa.gd deja caer en el hoyo con la fisica hasta que se asientan, apilados como los tiraron;
## lo horneado (CUERPOS_HORNEADOS) guarda la transformacion de cada segmento respecto al fondo de la fosa.
## [nombre, radio, largo a lo largo del cuerpo, masa]: de la cabeza a los pies (1,65 m).
const SEGMENTOS := [
	["cabeza", 0.11, 0.22, 5.0], ["torso", 0.2, 0.42, 25.0], ["pelvis", 0.18, 0.22, 14.0],
	["muslos", 0.16, 0.36, 16.0], ["piernas", 0.12, 0.33, 8.0], ["pies", 0.09, 0.1, 2.0],
]
const CUERPOS_HORNEADOS := "res://assets/fosa/cuerpos_fosa.json"
## Perfil del bulto a lo largo del cuerpo (0 cabeza .. 1 pies): [s, medio ancho, medio grueso].
const PERFIL := [
	[0.0, 0.0, 0.0], [0.02, 0.085, 0.09], [0.06, 0.125, 0.13], [0.11, 0.12, 0.12], [0.14, 0.09, 0.09],
	[0.17, 0.17, 0.13], [0.21, 0.235, 0.16], [0.32, 0.22, 0.17], [0.42, 0.19, 0.15], [0.52, 0.21, 0.16],
	[0.66, 0.17, 0.14], [0.77, 0.125, 0.11], [0.8, 0.13, 0.115], [0.91, 0.095, 0.09], [0.955, 0.1, 0.13],
	[0.985, 0.07, 0.09], [1.0, 0.0, 0.0],
]
const SOGAS := [0.14, 0.3, 0.55, 0.78, 0.93]

## Sin cuerpos (para hornearlos: la herramienta los suelta sobre el hoyo vacio).
var sin_cuerpos := false


## Extremos (cabeza, pies) de cada segmento en el marco del cuerpo de pie: la cabeza arriba, el eje y del segmento
## apunta hacia la cabeza. Devuelve [centro, largo] por segmento.
static func segmentos_de_pie() -> Array:
	var out := []
	var y := 1.65
	for sg: Array in SEGMENTOS:
		var largo: float = sg[2]
		out.append([Vector3(0, y - largo * 0.5, 0), largo])
		y -= largo
	return out


func _medida(s: float) -> Vector2:
	for k in PERFIL.size() - 1:
		var a: Array = PERFIL[k]
		var b: Array = PERFIL[k + 1]
		if s <= b[0]:
			var f := (s - float(a[0])) / (float(b[0]) - float(a[0]))
			f = f * f * (3.0 - 2.0 * f)
			return Vector2(lerpf(a[1], b[1], f), lerpf(a[2], b[2], f))
	return Vector2.ZERO


## Malla de un bulto a partir de los segmentos asentados (Transform3D en el marco del fondo de la fosa): la columna pasa
## por los extremos de los segmentos y la seccion (eliptica, con pliegues y bultos de tela mal envuelta) sigue su giro.
## Las sogas son bandas algo mas anchas. COLOR.r = barro (por debajo), COLOR.g = donde se empapa de sangre.
func _bulto(segs: Array, semilla: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var fase := rng.randf() * TAU
	# Puntos de la columna (cabeza a pies) y la base de cada uno.
	var puntos: Array[Vector3] = []
	var bases: Array[Basis] = []
	var largos: Array[float] = []
	for k in segs.size():
		var t: Transform3D = segs[k]
		var largo: float = SEGMENTOS[k][2]
		var arriba := t.basis.y.normalized()
		if k == 0:
			puntos.append(t.origin + arriba * largo * 0.5)
			bases.append(t.basis.orthonormalized())
		puntos.append(t.origin)
		bases.append(t.basis.orthonormalized())
		puntos.append(t.origin - arriba * largo * 0.5)
		bases.append(t.basis.orthonormalized())
	var acum := [0.0]
	for i in range(1, puntos.size()):
		acum.append(float(acum[-1]) + puntos[i].distance_to(puntos[i - 1]))
	var total: float = acum[-1]
	var filas := 56
	var lados := 14
	# Bultos de tela: unos pocos abultamientos al azar a lo largo y alrededor.
	var bultos := []
	for i in 5:
		bultos.append(Vector3(rng.randf_range(0.15, 0.9), rng.randf() * TAU, rng.randf_range(0.03, 0.07)))
	var punto_en := func(s: float) -> Array:
		var d := s * total
		for i in range(1, puntos.size()):
			if d <= float(acum[i]) or i == puntos.size() - 1:
				var f := clampf((d - float(acum[i - 1])) / maxf(float(acum[i]) - float(acum[i - 1]), 0.0001), 0.0, 1.0)
				var q := Quaternion(bases[i - 1]).slerp(Quaternion(bases[i]), f)
				return [puntos[i - 1].lerp(puntos[i], f), Basis(q)]
		return [puntos[-1], bases[-1]]
	var tela := SurfaceTool.new()
	tela.begin(Mesh.PRIMITIVE_TRIANGLES)
	var soga := SurfaceTool.new()
	soga.begin(Mesh.PRIMITIVE_TRIANGLES)
	var anillo := func(st: SurfaceTool, s: float, escala: float, es_soga: bool) -> void:
		var pb: Array = punto_en.call(s)
		var c: Vector3 = pb[0]
		var b: Basis = pb[1]
		var m := _medida(s) * escala
		for i in lados + 1:
			var t := TAU * i / lados
			var pliegue := 1.0
			if not es_soga:
				pliegue += 0.08 * sin(t * 3.0 + s * 31.0 + fase) + 0.04 * sin(t * 7.0 - s * 57.0)
				for bu: Vector3 in bultos:   # (s, angulo, cuanto)
					var ds := (s - bu.x) / 0.07
					var dt := angle_difference(t, bu.y)
					pliegue += bu.z / maxf(m.x, 0.05) * exp(-ds * ds - dt * dt * 2.0)
			var v := c + b.x * cos(t) * m.x * pliegue + b.z * sin(t) * m.y * pliegue
			var nrm := (b.x * cos(t) / maxf(m.x, 0.01) + b.z * sin(t) / maxf(m.y, 0.01)).normalized()
			var abajo := clampf(-nrm.y, 0.0, 1.0)
			var sangre := exp(-pow((s - 0.36) / 0.22, 2.0)) * (0.55 + 0.45 * abajo) + rng.randf() * 0.15
			st.set_color(Color(abajo, sangre, 0.0))
			st.set_uv(Vector2(t / TAU * (m.x + m.y) * PI, s * total))
			st.add_vertex(v)
	for j in filas + 1:
		anillo.call(tela, float(j) / filas, 1.0, false)
	for i in filas:
		for k in lados:
			var a := i * (lados + 1) + k
			var b2 := a + lados + 1
			for idx in [a, b2, a + 1, a + 1, b2, b2 + 1]:
				tela.add_index(idx)
	tela.generate_normals()
	var n := 0
	for s0: float in SOGAS:
		var s1: float = s0 + rng.randf_range(-0.03, 0.03)
		for d: float in [-0.012, 0.012]:
			anillo.call(soga, s1 + d, 1.1 + rng.randf_range(0.0, 0.06), true)
		for k in lados:
			var a := n * 2 * (lados + 1) + k
			var b2 := a + lados + 1
			for idx in [a, b2, a + 1, a + 1, b2, b2 + 1]:
				soga.add_index(idx)
		n += 1
	soga.generate_normals()
	var mats := MaterialesInca.todos()
	var malla := tela.commit()
	malla.surface_set_material(0, mats["mortaja"])
	soga.commit(malla)
	malla.surface_set_material(1, mats["soga"])
	return malla


## Los cuerpos horneados: la malla de cada bulto, su colision (capsulas: se puede pisar el monton) y de donde sale la
## sangre. El Chasqui yace en lo alto del monton, cerca del centro.
func _cuerpos() -> void:
	if sin_cuerpos:
		return
	if not FileAccess.file_exists(CUERPOS_HORNEADOS):
		push_warning("Fosa: faltan los cuerpos horneados (herramientas/hornear_fosa.gd)")
		return
	var datos: Array = JSON.parse_string(FileAccess.get_file_as_string(CUERPOS_HORNEADOS))
	var base := Transform3D(Basis(), Vector3(CENTRO.x, _piso, CENTRO.y))
	var colision := StaticBody3D.new()
	colision.name = "cuerpos_colision"
	add_child(colision)
	var alto := -INF
	var rng := RandomNumberGenerator.new()
	rng.seed = 1532
	for k in datos.size():
		var segs := []
		for sv: Array in datos[k]:
			var t := Transform3D(Basis(Vector3(sv[0], sv[1], sv[2]), Vector3(sv[3], sv[4], sv[5]), Vector3(sv[6], sv[7], sv[8])), Vector3(sv[9], sv[10], sv[11]))
			segs.append(base * t)
		var mi := MeshInstance3D.new()
		mi.name = "cuerpo_%d" % k
		mi.mesh = _bulto(segs, 100 + k)
		mi.layers = CAPA_CUERPOS   # los charcos (Decal) no pintan los cuerpos
		mi.set_instance_shader_parameter("sangre", 1.0)
		mi.set_instance_shader_parameter("tinte", rng.randf())
		add_child(mi)
		cuerpos.append(mi)
		for i in segs.size():
			var t: Transform3D = segs[i]
			var forma := CapsuleShape3D.new()
			forma.radius = SEGMENTOS[i][1]
			forma.height = maxf(SEGMENTOS[i][2], SEGMENTOS[i][1] * 2.0)
			var col := CollisionShape3D.new()
			col.shape = forma
			col.transform = t
			colision.add_child(col)
			if Vector2(t.origin.x - CENTRO.x, t.origin.z - CENTRO.y).length() < 1.0:
				alto = maxf(alto, t.origin.y + float(SEGMENTOS[i][1]))
		fuentes.append((segs[1] as Transform3D).origin)
	despertar = Vector3(CENTRO.x, alto if alto > -INF else _piso, CENTRO.y)


## Charcos de sangre bajo los cuerpos: un Decal con una mancha hecha con ruido; `secar_sangre` los encoge.
func _charcos_de_sangre() -> void:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var ruido := FastNoiseLite.new()
	ruido.seed = 3
	ruido.frequency = 0.045
	for y in 128:
		for x in 128:
			var d := Vector2(x - 63.5, y - 63.5).length() / 63.5
			var a := clampf((1.0 - d) * 1.6 + ruido.get_noise_2d(x, y) * 0.9 - 0.35, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.22, 0.01, 0.01, smoothstep(0.0, 0.25, a)))
	var tex := ImageTexture.create_from_image(img)
	for k in mini(16, fuentes.size()):
		var dc := Decal.new()
		dc.texture_albedo = tex
		dc.size = Vector3(1.9, 1.0, 1.3)
		dc.modulate = Color(1, 1, 1, 0.95)
		dc.position = Vector3(fuentes[k].x, _piso + 0.3, fuentes[k].z)
		dc.rotation.y = _rng.randf() * TAU
		dc.upper_fade = 0.2
		dc.cull_mask = 1
		dc.lower_fade = 0.2
		add_child(dc)
		_charcos.append(dc)


## Cuanta sangre queda (1 toda .. 0 absorbida): encoge los charcos y seca las mortajas.
func secar_sangre(cuanta: float) -> void:
	for dc in _charcos:
		dc.modulate.a = 0.95 * cuanta
		dc.scale = Vector3.ONE * lerpf(0.35, 1.0, cuanta)
	for mi in cuerpos:
		mi.set_instance_shader_parameter("sangre", cuanta)


# --- Escondite ------------------------------------------------------------------------------------

## Rocas, matorral y dos queñuas entre la fosa y el camino: desde la calzada no se ve.
func _ocultar() -> void:
	var dir := (CAMINO - CENTRO).normalized()
	var lado := Vector2(-dir.y, dir.x)
	var rocas: Array[Mesh] = []
	for ruta: String in ROCAS:
		var e: Node3D = (load(ruta) as PackedScene).instantiate()
		for m: MeshInstance3D in e.find_children("*", "MeshInstance3D", true, false):
			rocas.append(m.mesh)
			break
		e.free()
	for k in 6:
		var p := CENTRO + dir * _rng.randf_range(BORDE + 3.0, BORDE + 6.5) + lado * _rng.randf_range(-6.0, 6.0)
		# El paso del sendero queda libre.
		if absf((p - CENTRO).dot(lado)) < 1.5:
			p += lado * 2.5
		_instancia(rocas[k % rocas.size()], p, _rng.randf_range(2.2, 3.6), -0.5)
	# Piedras que asoman de las paredes y sueltas en el fondo.
	var piedras := _malla_planta("namaqualand_stones_01")
	for k in 14:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(RADIO + 0.2, BORDE - 0.2) if k < 9 else _rng.randf_range(0.8, RADIO - 0.3)
		var c := CENTRO + Vector2(cos(a), sin(a)) * r
		var mi := MeshInstance3D.new()
		mi.mesh = rocas[k % rocas.size()] if k < 9 else piedras
		var caja := mi.mesh.get_aabb()
		var esc := _rng.randf_range(0.35, 0.8) / maxf(caja.size.x, 0.1) if k < 9 else _rng.randf_range(0.8, 1.3)
		var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * esc)
		var f := clampf((r - RADIO) / (BORDE - RADIO), 0.0, 1.0)
		var y := lerpf(_piso, _suelo(a, BORDE) + 0.3, f) - 0.12
		mi.transform = Transform3D(b, Vector3(c.x, y, c.y) - b * Vector3(caja.get_center().x, caja.position.y, caja.get_center().z))
		add_child(mi)
	var arbusto := _malla_planta("wild_rooibos_bush")
	for k in 7:
		var p := CENTRO + dir * _rng.randf_range(BORDE + 2.0, BORDE + 8.0) + lado * _rng.randf_range(-8.0, 8.0)
		if absf((p - CENTRO).dot(lado)) < 1.2:
			continue
		_instancia(arbusto, p, _rng.randf_range(1.4, 2.2), 0.0, true)
	var arbol := _malla_planta("searsia_burchellii")
	for s in [-1.0, 1.0]:
		_instancia(arbol, CENTRO + dir * (BORDE + 4.5) + lado * s * 5.5, 1.15, 0.0, true)


func _malla_planta(modelo: String) -> Mesh:
	var e: Node3D = (load("res://assets/plantas/%s/%s.gltf" % [modelo, modelo]) as PackedScene).instantiate()
	var malla: Mesh = null
	for m: MeshInstance3D in e.find_children("*", "MeshInstance3D", true, false):
		if not m.name.contains("LOD") or m.name.ends_with("LOD0"):
			malla = m.mesh
			break
	e.free()
	return malla


func _instancia(malla: Mesh, p: Vector2, tam: float, hundir: float, escala_propia := false) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	var caja := malla.get_aabb()
	var esc := tam if escala_propia else tam / maxf(caja.size.x, 0.1)
	var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * esc)
	var y := terreno.altura(p.x, p.y) + hundir
	mi.transform = Transform3D(b, Vector3(p.x, y, p.y) - b * Vector3(caja.get_center().x, caja.position.y, caja.get_center().z))
	mi.visibility_range_end = 400.0
	add_child(mi)


## Sendero de cabras de la calzada al filo del cañon y por el filo hasta la fosa: tierra pisada sin ichu. Y el suelo
## alrededor de la fosa, removido y sin plantas.
func _sendero() -> void:
	var huellas := [[CENTRO, Vector2(BORDE + 2.6, BORDE + 2.6), 0.0, 1.0, 1.5]]
	for i in SENDERO.size() - 1:
		var a: Vector2 = SENDERO[i]
		var b: Vector2 = SENDERO[i + 1]
		var dir := (b - a).normalized()
		var largo := a.distance_to(b)
		var k := 0.0
		while k < largo:
			var c := a + dir * k + Vector2(-dir.y, dir.x) * sin(k * 0.21 + i) * 0.6
			huellas.append([c, Vector2(0.35, 1.4), atan2(dir.x, dir.y), 0.75, 0.5])
			k += 2.0
	terreno.pintar_obras(huellas)
