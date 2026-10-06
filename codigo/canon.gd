class_name Canon
extends Node3D
## El cañon: corre de este a oeste por el sur de la meseta, pegado al Qhapaq Ñan entre el pozo y el templo (su borde
## norte va a 40-60 m de la calzada) y a ~85 m del pueblo, y baja al oeste hasta el valle grande. ~500 m de hondo y
## ~340 m de borde a borde: arriba paredes de roca casi verticales con repisas, abajo pedregal, y un rio en el fondo.
## Un peligro a la vista desde el camino; por ahora no se puede caer (barrera invisible en el borde norte, disimulada
## con peñascos). En su borde, escondida, esta la fosa comun.
##
## La forma (`tallar`) la aplica herramientas/hornear_relieve.gd al relieve horneado (cerca y lejos); este nodo pone en
## el nivel el rio, la barrera y los peñascos.

## Eje del cañon (mundo, xz), de este a oeste, por puntos de control (se suaviza con Catmull-Rom). Sale de un borde norte
## trazado a >= 52 m (en perpendicular) de la calzada, desplazado SEMIANCHO hacia el sur.
const EJE := [
	Vector2(2873, 948), Vector2(1571, 737), Vector2(865, 596), Vector2(585, 531), Vector2(543, 525), Vector2(474, 532),
	Vector2(370, 523), Vector2(246, 454), Vector2(196, 372), Vector2(164, 341), Vector2(55, 345), Vector2(-92, 350),
	Vector2(-233, 359), Vector2(-469, 387), Vector2(-853, 473), Vector2(-1333, 636), Vector2(-1937, 938),
	Vector2(-2846, 1241),
]
const SEMIANCHO := 170.0         # m del eje al borde
const FONDO_SEMIANCHO := 16.0    # m: el lecho del rio
## Altura del fondo (relativa a la plaza) a lo largo del eje: baja hacia el oeste, donde desemboca en el valle grande.
const FONDO := [[2900.0, -380.0], [500.0, -480.0], [-500.0, -560.0], [-2000.0, -900.0], [-2900.0, -1000.0]]
const RIO_ANCHO := 20.0

static var _ruido: FastNoiseLite


static func _ruido_borde() -> FastNoiseLite:
	if _ruido == null:
		_ruido = FastNoiseLite.new()
		_ruido.seed = 4242
		_ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_ruido.fractal_octaves = 3
		_ruido.frequency = 1.0 / 160.0
	return _ruido


static var _suave := PackedVector2Array()
static var _celdas := {}
const CELDA := 100.0


## El eje suavizado (cada ~10 m) y una rejilla de celdas de 100 m con los tramos que pasan a menos de 260 m: asi
## `cerca_del_eje` mira pocos tramos (el horneado lo llama millones de veces).
static func _preparar() -> void:
	if not _suave.is_empty():
		return
	for i in EJE.size() - 1:
		var p0: Vector2 = EJE[maxi(i - 1, 0)]
		var p1: Vector2 = EJE[i]
		var p2: Vector2 = EJE[i + 1]
		var p3: Vector2 = EJE[mini(i + 2, EJE.size() - 1)]
		var n := maxi(1, int(p1.distance_to(p2) / 10.0))
		for k in n:
			var t := float(k) / n
			_suave.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	_suave.append(EJE[EJE.size() - 1])
	var alcance := SEMIANCHO + 90.0
	for i in _suave.size() - 1:
		var a := _suave[i]
		var b := _suave[i + 1]
		var lo := Vector2i(floori((minf(a.x, b.x) - alcance) / CELDA), floori((minf(a.y, b.y) - alcance) / CELDA))
		var hi := Vector2i(floori((maxf(a.x, b.x) + alcance) / CELDA), floori((maxf(a.y, b.y) + alcance) / CELDA))
		for cx in range(lo.x, hi.x + 1):
			for cz in range(lo.y, hi.y + 1):
				var c := Vector2i(cx, cz)
				# Los arrays empaquetados se copian al sacarlos del diccionario: se vuelve a guardar.
				var lista: PackedInt32Array = _celdas.get(c, PackedInt32Array())
				lista.append(i)
				_celdas[c] = lista


static func eje_suave() -> PackedVector2Array:
	_preparar()
	return _suave


## Punto mas cercano del eje: [distancia, x del eje en ese punto (para el fondo), normal hacia el norte del tramo]. Lejos
## del cañon (fuera de la rejilla), distancia INF.
static func cerca_del_eje(p: Vector2) -> Array:
	_preparar()
	var mejor := INF
	var x_eje := 0.0
	var norte := Vector2(0, -1)
	var c := Vector2i(floori(p.x / CELDA), floori(p.y / CELDA))
	if not _celdas.has(c):
		return [mejor, x_eje, norte]
	for i: int in _celdas[c]:
		var a := _suave[i]
		var b := _suave[i + 1]
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var d := p.distance_to(q)
		if d < mejor:
			mejor = d
			x_eje = q.x
			var t := (b - a).normalized()
			norte = Vector2(t.y, -t.x)
			if norte.y > 0.0:
				norte = -norte
	return [mejor, x_eje, norte]


## Altura del fondo (lecho del rio) donde el eje pasa por x.
static func fondo(x: float) -> float:
	for k in FONDO.size() - 1:
		var a: Array = FONDO[k]
		var b: Array = FONDO[k + 1]
		if x <= a[0] and x >= b[0]:
			return lerpf(a[1], b[1], (a[0] - x) / (a[0] - b[0]))
	return FONDO[0][1] if x > FONDO[0][0] else FONDO[-1][1]


## Semiancho del cañon en un punto: el borde no es recto (quebradas laterales, salientes).
static func semiancho(p: Vector2) -> float:
	var r := _ruido_borde()
	# Ondas grandes (salientes y entrantes) y quebraditas de ~40 m que muerden el borde.
	return SEMIANCHO + r.get_noise_2d(p.x, p.y) * 18.0 + r.get_noise_2d(p.x * 4.0 + 900.0, p.y * 4.0) * 8.0


## Altura tallada: h (relativa a la plaza) del relieve en (x, z) con el cañon. Nunca sube el suelo.
static func tallar(x: float, z: float, h: float) -> float:
	var p := Vector2(x, z)
	var info := cerca_del_eje(p)
	var d: float = info[0]
	var w := semiancho(p)
	if d >= w:
		return h
	var f := fondo(info[1])
	if h <= f:
		return h
	var u := clampf((d - FONDO_SEMIANCHO) / (w - FONDO_SEMIANCHO), 0.0, 1.0)
	# En V: arriba la pared cae casi a plomo (pendiente ~84 grados en el borde), abajo el pedregal baja mas tendido hasta
	# un lecho angosto. Repisas en la pared.
	var g := 0.55 * pow(u, 1.2) + 0.45 * pow(u, 5.0) + 0.03 * sin(u * PI * 5.0) * u * (1.0 - u) * 4.0
	return minf(h, f + (h - f) * clampf(g, 0.0, 1.0))


## Puntos del borde norte (mundo, xz) cada ~10 m dentro de la zona jugable (|x|, |z| < 596).
static func borde_norte() -> PackedVector2Array:
	_preparar()
	var out := PackedVector2Array()
	for i in _suave.size() - 1:
		var a := _suave[i]
		var t := (_suave[i + 1] - a).normalized()
		var norte := Vector2(t.y, -t.x)
		if norte.y > 0.0:
			norte = -norte
		var q := a + norte * semiancho(a + norte * SEMIANCHO)
		if absf(q.x) < 596.0 and absf(q.y) < 596.0:
			out.append(q)
	return out


# --- En el nivel ------------------------------------------------------------------------------------

const SHADER_RIO := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 hondo : source_color = vec3(0.10, 0.16, 0.17);
uniform vec3 espuma : source_color = vec3(0.82, 0.86, 0.85);
global uniform float humedad;

float azar(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float ruido(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(azar(i), azar(i + vec2(1, 0)), f.x), mix(azar(i + vec2(0, 1)), azar(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	// UV.x: a lo largo del rio (m, hacia aguas abajo); UV.y: a lo ancho (0..1). El agua corre y rompe en espuma.
	vec2 q = vec2(UV.x * 0.08 - TIME * 0.9, UV.y * 3.0);
	float r = ruido(q) * 0.6 + ruido(q * 2.7 + 3.0) * 0.4;
	float orilla = 1.0 - smoothstep(0.0, 0.2, min(UV.y, 1.0 - UV.y));
	float blanco = smoothstep(0.55, 0.8, r + orilla * 0.4 + humedad * 0.15);
	ALBEDO = mix(hondo, espuma, blanco);
	ROUGHNESS = mix(0.08, 0.6, blanco);
	SPECULAR = 0.6;
}
"""

var terreno: Terreno


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_rio()
	_barrera()
	print("canon: rio, barrera de %d tramos, %d ms" % [_tramos, Time.get_ticks_msec() - t0])


## El rio en el fondo: una cinta que sigue el eje (a 1,5 m sobre el lecho).
func _rio() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var largo := 0.0
	var puntos := eje_suave()   # de este a oeste: aguas abajo (la UV crece hacia alla y el agua corre en ese sentido)
	for k in puntos.size() - 1:
		var a: Vector2 = puntos[k]
		var b: Vector2 = puntos[k + 1]
		var t := (b - a).normalized()
		var lado := Vector2(-t.y, t.x) * RIO_ANCHO * 0.5
		var ya := fondo(a.x) + 1.5
		var yb := fondo(b.x) + 1.5
		var la := largo
		largo += a.distance_to(b)
		var v := [Vector3(a.x - lado.x, ya, a.y - lado.y), Vector3(a.x + lado.x, ya, a.y + lado.y), Vector3(b.x + lado.x, yb, b.y + lado.y), Vector3(b.x - lado.x, yb, b.y - lado.y)]
		var uv := [Vector2(la, 0), Vector2(la, 1), Vector2(largo, 1), Vector2(largo, 0)]
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3.UP)
			st.set_uv(uv[idx])
			st.add_vertex(v[idx])
	var mi := MeshInstance3D.new()
	mi.name = "rio"
	mi.mesh = st.commit()
	var sh := Shader.new()
	sh.code = SHADER_RIO
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


var _tramos := 0


## Barrera invisible en el borde norte (no se puede caer, todavia) y peñascos que la disimulan.
func _barrera() -> void:
	var borde := borde_norte()
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "barrera_canon"
	add_child(cuerpo)
	for k in borde.size() - 1:
		var a := borde[k]
		var b := borde[k + 1]
		if a.distance_to(b) > 20.0:
			continue   # salto entre tramos del eje
		var ya := terreno.altura(a.x, a.y)
		var yb := terreno.altura(b.x, b.y)
		var forma := BoxShape3D.new()
		forma.size = Vector3(a.distance_to(b) + 0.6, 4.0, 0.6)
		var col := CollisionShape3D.new()
		col.shape = forma
		var c := (a + b) * 0.5
		col.transform = Transform3D(Basis(Vector3.UP, -atan2(b.y - a.y, b.x - a.x)), Vector3(c.x, maxf(ya, yb) + 1.0, c.y))
		cuerpo.add_child(col)
		_tramos += 1
	# Peñascos sueltos en el filo, cada ~20-35 m.
	var rocas: Array[Mesh] = []
	for ruta: String in ["res://assets/plantas/namaqualand_boulder_02/namaqualand_boulder_02.gltf", "res://assets/plantas/namaqualand_boulder_05/namaqualand_boulder_05.gltf"]:
		var e: Node3D = (load(ruta) as PackedScene).instantiate()
		for m: MeshInstance3D in e.find_children("*", "MeshInstance3D", true, false):
			rocas.append(m.mesh)
			break
		e.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var k := 0
	while k < borde.size():
		var p := borde[k]
		var info := cerca_del_eje(p)
		var hacia_eje: Vector2 = -(info[2] as Vector2)
		var q := p - hacia_eje * rng.randf_range(0.5, 2.5)
		var mi := MeshInstance3D.new()
		mi.mesh = rocas[rng.randi() % rocas.size()]
		var caja := mi.mesh.get_aabb()
		var esc := rng.randf_range(1.2, 3.2) / maxf(caja.size.x, 0.1)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * esc)
		mi.transform = Transform3D(b, Vector3(q.x, terreno.altura(q.x, q.y) - 0.4, q.y) - b * Vector3(caja.get_center().x, caja.position.y, caja.get_center().z))
		mi.visibility_range_end = 600.0
		add_child(mi)
		k += rng.randi_range(3, 6)
