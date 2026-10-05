class_name Hogar
extends Node3D
## El hogar del Chasqui, en el borde oeste del pueblo (zona 1): una kancha pequena sobre su terraza, mirando a la puesta
## de sol del solsticio. La casa (wasi) abre su puerta trapezoidal al ONO (acimut 294 grados): por la tarde el sol entra
## por ella y dibuja un haz en la penumbra de dentro (niebla volumetrica solo dentro de la casa). Desde el umbral, sobre
## el murete del patio, el sol se pone en el abra entre los cerros (ver ABRAS en herramientas/hornear_relieve.gd).
##
## Dentro, lo de una casa andina: suelo de tierra con mantas tejidas, cama de ichu, fogon de tres piedras con ollas y
## una luz que titila, hornacinas con queros, maiz y hierbas colgados de las vigas, el quipu del chasqui junto a la puerta
## y un batan. Fuera: arriates con flores, un arbusto, aribalos, un banco de piedra frente a la vista y fardos para
## subir al techo.
##
## Marco local del hogar (`_marco`): +z hacia la puesta (el frente de la casa y el murete), centro de la kancha en el
## origen, y = la del mundo.

const SITIO := Vector2(-212.0, -28.0)   # m, mundo: centro de la kancha (suelo poco inclinado al oeste de las casas redondas)
const ACIMUT_PUESTA := 294.0            # grados: el sol se pone ahi el 21 de junio
const MITAD := 8.0                      # m: la kancha es de 16 x 16
const G := 0.6
const CERCO := 2.3                      # m: alto del cerco a los lados y detras (como en el pueblo)
const CASA := Vector3(7.4, 2.5, 5.6)    # largo, alero, fondo
const PORTADA_Z := 3.1                  # z local de la portada del cerco (lado -x, hacia el pueblo)
const CASA_Z := -4.5                    # centro de la casa en z local (al fondo del patio)
const CAPA_SOMBRA_FUEGO := 1 << 10     # capa de render de las piezas que dan sombra a la luz del fogon
const RADIO_NIEBLA := 40.0              # m: mas cerca se enciende la niebla volumetrica (los rayos)

## Luz aditiva del haz: mas fuerte en el centro del vano, se desvanece hacia los bordes, a lo largo y donde toca las
## superficies (asi no se ve el corte con el suelo y los muros); motas de polvo que flotan.
const SHADER_HAZ := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 color : source_color = vec3(1.0, 0.7, 0.45);
uniform float fuerza = 1.0;
uniform sampler2D profundidad : hint_depth_texture, filter_linear;

float ruido(vec3 p) { return fract(sin(dot(floor(p), vec3(12.99, 78.23, 37.71))) * 43758.55); }

void fragment() {
	float ancho = smoothstep(0.0, 0.25, UV.x) * smoothstep(1.0, 0.75, UV.x);
	float alto = smoothstep(0.0, 0.15, UV2.x) * smoothstep(1.0, 0.8, UV2.x);
	float largo = mix(1.0, 0.25, UV.y);
	// Suave donde corta otra superficie: distancia (en vista) entre el haz y lo que hay detras.
	float z = textureLod(profundidad, SCREEN_UV, 0.0).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z, 1.0);
	float fondo = -v.z / v.w;
	float suave = clamp((fondo - (-VERTEX.z)) / 0.4, 0.0, 1.0);
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float motas = step(0.996, ruido(w * 110.0 + vec3(0.0, TIME * 1.5, TIME * 0.6))) * 2.0;
	// Las laminas vistas de canto se apagan (si no, se ve la raya).
	float frente = abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = color * fuerza * 0.042 * ancho * alto * largo * suave * smoothstep(0.1, 0.5, frente) * (1.0 + motas);
}
"""

var terreno: Terreno
## El sol de Sky3D (lo pone nivel1.gd): el haz que entra por la puerta sigue su direccion, su color y su fuerza.
var sol: DirectionalLight3D
## {nombre, pos, mira, hora}: se suman a los del pueblo.
var miradores: Array[Dictionary] = []
## Centro del hogar en el mundo (a la altura del piso).
var centro: Vector3

var _marco: Transform3D
var _casa: Transform3D
var _tapa := 0.0
var _fuego: OmniLight3D
var _ruido := FastNoiseLite.new()
var _t := 0.0
var _haz: MeshInstance3D
var _haz_mat: ShaderMaterial
var _haz_dir := Vector3.ZERO   # direccion local (marco de la casa) con que se armo el haz


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var v := Vector3(sin(deg_to_rad(ACIMUT_PUESTA)), 0.0, -cos(deg_to_rad(ACIMUT_PUESTA)))
	_marco = Transform3D(Basis(Vector3.UP, atan2(v.x, v.z)), Vector3(SITIO.x, 0.0, SITIO.y))
	# La terraza a la altura del punto mas alto del suelo bajo la kancha: el frente (hacia el valle) queda alto.
	var lo := INF
	var hi := -INF
	for j in 9:
		for i in 9:
			var p := _marco * Vector3(-MITAD + i * 2.0, 0.0, -MITAD + j * 2.0)
			var h := terreno.altura(p.x, p.z)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	_tapa = hi + 0.2
	_casa = _marco * Transform3D(Basis(), Vector3(0.0, _tapa, CASA_Z))
	centro = _marco * Vector3(0.0, _tapa, 0.0)
	var kit := KitInca.new()
	kit.plataforma(_marco, Rect2(-MITAD, -MITAD, MITAD * 2.0, MITAD * 2.0), lo - 0.6, _tapa)
	_cerco(kit)
	kit.wasi(_casa, CASA.x, CASA.z, CASA.y, [0.0], "pirca", G, true, 1.15)
	_vigas(kit)
	_dentro(kit)
	_patio(kit)
	var tris := kit.triangulos()
	kit.construir(self, "hogar")
	# Solo las piezas del hogar dan sombra a la luz del fogon (sin esto, su mapa cubico vuelve a dibujar el terreno y el
	# ichu de alrededor: el doble de primitivas).
	for mi in find_children("*", "MeshInstance3D", false, false):
		(mi as MeshInstance3D).layers |= CAPA_SOMBRA_FUEGO
	_plantas()
	_luces()
	terreno.pintar_obras([[SITIO, Vector2(MITAD, MITAD), atan2(v.x, v.z), 1.0, 4.0]])
	_miradores(v)
	print("hogar: %d triangulos, terraza a %.1f m (suelo de %.1f a %.1f), %d ms" % [tris, _tapa, lo, hi, Time.get_ticks_msec() - t0])


func _process(dt: float) -> void:
	# El fogon titila: dos ruidos lentos y uno rapido.
	_t += dt
	_fuego.light_energy = 1.7 + 0.45 * _ruido.get_noise_1d(_t * 40.0) + 0.2 * _ruido.get_noise_1d(_t * 160.0 + 50.0)
	_actualizar_haz()


## Haz de sol por la puerta: laminas de luz aditiva desde el vano hacia dentro, en la direccion del sol. Brilla cuando
## el sol entra de verdad (alineado con la puerta y sobre el horizonte) y se apaga de noche, con lluvia o de manana.
func _actualizar_haz() -> void:
	if sol == null:
		_haz.visible = false
		return
	var hacia_sol := (_casa.basis.inverse() * sol.global_transform.basis.z).normalized()
	var alineado := smoothstep(0.55, 0.9, hacia_sol.z)          # el sol por delante de la puerta
	var alto := smoothstep(0.02, 0.08, hacia_sol.y) * (1.0 - smoothstep(0.55, 0.8, hacia_sol.y))
	var fuerza := alineado * alto * clampf(sol.light_energy, 0.0, 1.5) * (sol.shadow_opacity if sol.shadow_enabled else 1.0)
	_haz.visible = fuerza > 0.01
	if not _haz.visible:
		return
	_haz_mat.set_shader_parameter("fuerza", fuerza)
	_haz_mat.set_shader_parameter("color", sol.light_color)
	var d := -hacia_sol   # hacia donde va la luz
	if d.distance_to(_haz_dir) > 0.01:
		_haz_dir = d
		_haz.mesh = _malla_haz(d)


## Laminas de luz desde el vano de la puerta (por la cara de dentro del muro) a lo largo de `d` (local a la casa): seis
## verticales y cuatro horizontales que, sumadas, se leen como un volumen. Cada punto del vano baja hasta el suelo (o
## 6 m). UV.x = posicion a lo ancho del vano, UV.y = de la puerta (0) al final (1), UV2.x = posicion a lo alto.
func _malla_haz(d: Vector3) -> ArrayMesh:
	var z := CASA.z * 0.5 - G
	var esc := 1.15
	var esquinas := [Vector3(-0.5 * esc, 0.02, z), Vector3(0.5 * esc, 0.02, z), Vector3(0.4 * esc, 2.0 * esc, z), Vector3(-0.4 * esc, 2.0 * esc, z)]
	var punto := func(u: float, h: float) -> Vector3:
		var abajo: Vector3 = (esquinas[0] as Vector3).lerp(esquinas[1], u)
		var arriba: Vector3 = (esquinas[3] as Vector3).lerp(esquinas[2], u)
		return abajo.lerp(arriba, h)
	var final := func(p: Vector3) -> Vector3:
		var largo := 6.0
		if d.y < -0.01:
			largo = minf(largo, p.y / -d.y)
		return p + d * maxf(largo, 0.3)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tira := func(params: Array) -> void:   # [[u, h], ...] a lo largo de la lamina
		for k in params.size() - 1:
			var a: Array = params[k]
			var b: Array = params[k + 1]
			var pa: Vector3 = punto.call(a[0], a[1])
			var pb: Vector3 = punto.call(b[0], b[1])
			var q := [[pa, a, 0.0], [pb, b, 0.0], [final.call(pb), b, 1.0], [final.call(pa), a, 1.0]]
			for idx in [0, 1, 2, 0, 2, 3]:
				var v: Array = q[idx]
				st.set_uv(Vector2(v[1][0], v[2]))
				st.set_uv2(Vector2(v[1][1], 0.0))
				st.add_vertex(v[0])
	for i in 6:
		var u := (i + 0.5) / 6.0
		tira.call([[u, 0.0], [u, 0.25], [u, 0.5], [u, 0.75], [u, 1.0]])
	for j in 4:
		var h := (j + 0.5) / 4.0
		tira.call([[0.0, h], [0.25, h], [0.5, h], [0.75, h], [1.0, h]])
	st.generate_normals()
	return st.commit()


## Cerco: murete bajo al frente (la vista), muros de 2,3 m a los lados y detras, con la portada del lado del pueblo.
func _cerco(kit: KitInca) -> void:
	var t := _marco * Transform3D(Basis(), Vector3(0.0, _tapa, 0.0))
	var e := MITAD - G * 0.5
	kit.muro_entre("pirca", t, Vector3(-MITAD, 0, e), Vector3(MITAD, 0, e), 0.85, 0.5, [], 0.1)
	kit.muro_entre("pirca", t, Vector3(MITAD, 0, -e), Vector3(-MITAD, 0, -e), CERCO, G)
	# Lado -x (hacia el noreste, el pueblo): portada trapezoidal cerca del frente.
	kit.muro_entre("pirca", t, Vector3(-e, 0, -e + G * 0.5), Vector3(-e, 0, e - 0.25), CERCO, G, [KitInca.puerta(PORTADA_Z + e - G * 0.5, 1.05)], 0.2, false)
	kit.muro_entre("pirca", t, Vector3(e, 0, e - 0.25), Vector3(e, 0, -e + G * 0.5), CERCO, G, [], 0.2, false)
	# Escalera de piedra del camino a la portada (sube hacia +x local). El pie depende de lo que mida: dos pasadas.
	var h := _suelo(-MITAD - 1.5, PORTADA_Z)
	var fin := 0.0
	for i in 2:
		fin = ceili(maxf(_tapa - h, 0.0) / 0.26) * 0.34
		h = _suelo(-MITAD - fin, PORTADA_Z)
	if _tapa - h > 0.2:
		kit.escalera("pirca", _marco * Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-MITAD - fin, h, PORTADA_Z)), 1.4, _tapa - h)


## Altura del suelo en un punto local del hogar.
func _suelo(x: float, z: float) -> float:
	var p := _marco * Vector3(x, 0.0, z)
	return terreno.altura(p.x, p.z)


## Por dentro del techo: tirantes de lado a lado, la cumbrera y los cabios bajo la paja.
func _vigas(kit: KitInca) -> void:
	var mz := CASA.z * 0.5
	var cumbre := CASA.y + mz * tan(deg_to_rad(40.0))
	for x in [-2.4, -0.8, 0.8, 2.4]:
		kit.caja("madera", _casa, Vector3(x, CASA.y - 0.08, 0.0), Vector3(0.14, 0.14, CASA.z - 0.3), "", true, false)
	kit.caja("madera", _casa, Vector3(0.0, cumbre - 0.1, 0.0), Vector3(CASA.x - 0.2, 0.16, 0.16), "", true, false)
	var largo := (mz + 0.1) / cos(deg_to_rad(40.0))
	var x := -CASA.x * 0.5 + 0.7
	while x < CASA.x * 0.5 - 0.5:
		for s in [1.0, -1.0]:
			var c := Vector3(x, (cumbre + CASA.y) * 0.5 - 0.11, s * (mz + 0.1) * 0.5)
			kit.caja("madera", _casa * Transform3D(Basis(Vector3.RIGHT, s * deg_to_rad(40.0)), c), Vector3.ZERO, Vector3(0.07, 0.07, largo), "", true, false)
		x += 0.75


## Lo de dentro de la casa (marco `_casa`: piso en y = 0, frente con la puerta en +z, por dentro x de -3,1 a 3,1 y z de
## -2,2 a 2,2).
func _dentro(kit: KitInca) -> void:
	var t := _casa
	# Mantas en el suelo, una encima de otra, frente a la cama.
	kit.caja("manta", t, Vector3(-0.9, 0.01, -0.5), Vector3(1.5, 0.02, 1.1), "", false, false)
	kit.caja("manta", t * Transform3D(Basis(Vector3.UP, 0.25), Vector3(-0.2, 0.025, 0.4)), Vector3.ZERO, Vector3(1.2, 0.02, 0.9), "", false, false)
	# Cama: tarima de ichu con mantas y una pila de mantas dobladas.
	kit.caja("ichu", t, Vector3(-2.15, 0.17, -1.45), Vector3(1.8, 0.34, 1.35))
	kit.caja("manta", t, Vector3(-2.1, 0.365, -1.4), Vector3(1.75, 0.05, 1.25), "", false, false)
	kit.caja("manta", t, Vector3(-2.75, 0.45, -1.45), Vector3(0.5, 0.12, 1.0), "", false, false)
	kit.caja("manta", t * Transform3D(Basis(Vector3.UP, -0.3), Vector3(-1.6, 0.4, -1.1)), Vector3.ZERO, Vector3(0.7, 0.03, 0.6), "", false, false)
	# Fogon: tres piedras alrededor de las brasas, una olla encima y otra al lado.
	var f := Vector3(2.15, 0.0, -1.3)
	for i in 3:
		var a := TAU * i / 3.0 + 0.4
		kit.caja("pirca", t * Transform3D(Basis(Vector3.UP, a), f + Vector3(cos(a), 0, sin(a)) * 0.28), Vector3(0, 0.11, 0), Vector3(0.22, 0.22, 0.2))
	kit.caja("brasa", t, f + Vector3(0, 0.03, 0), Vector3(0.36, 0.06, 0.36), "", false, false)
	var olla := [Vector2(0.0, 0.0), Vector2(0.12, 0.02), Vector2(0.2, 0.1), Vector2(0.21, 0.2), Vector2(0.15, 0.3), Vector2(0.16, 0.33)]
	kit.torno("ceramica", t * Transform3D(Basis(), f + Vector3(0, 0.2, 0)), olla)
	kit.torno("ceramica", t * Transform3D(Basis.from_scale(Vector3.ONE * 1.3), f + Vector3(-0.15, 0, 0.6)), olla)
	kit.batan(t * Transform3D(Basis(Vector3.UP, 0.2), Vector3(1.75, 0, 1.45)))
	kit.aribalo(t * Transform3D(Basis(), Vector3(-1.3, 0.04, 1.75)))
	# Hornacinas del muro de atras (x = 2,3, 0 y -2,3; base a 1 m): queros, un aribalo chico y una ollita.
	var quero := [Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.065, 0.17), Vector2(0.06, 0.17)]
	kit.torno("ceramica", t * Transform3D(Basis(), Vector3(2.2, 1.0, -2.36)), quero, 10)
	kit.torno("madera", t * Transform3D(Basis(), Vector3(2.42, 1.0, -2.36)), quero, 10)
	kit.aribalo(t * Transform3D(Basis(), Vector3(0.0, 1.04, -2.36)), 0.32)
	kit.torno("ceramica", t * Transform3D(Basis.from_scale(Vector3.ONE * 0.6), Vector3(-2.3, 1.0, -2.36)), olla)
	# Maiz y hierbas colgados de los tirantes.
	for c: Vector3 in [Vector3(-0.8, 0, -1.2), Vector3(-0.8, 0, 0.9), Vector3(0.8, 0, -0.4), Vector3(2.4, 0, 0.5)]:
		_racimo(kit, t * Transform3D(Basis(), c + Vector3(0, CASA.y - 0.15, 0)), int(c.z * 10.0 + c.x * 3.0))
	for c: Vector3 in [Vector3(-2.4, 0, 0.2), Vector3(0.8, 0, 1.4), Vector3(-0.8, 0, 0.1)]:
		_hierbas(kit, t * Transform3D(Basis(), c + Vector3(0, CASA.y - 0.15, 0)))
	_quipu(kit, t * Transform3D(Basis(), Vector3(-1.85, 1.85, 2.2)))


## Mazorcas atadas que cuelgan de un tirante (desde `t`, hacia abajo).
func _racimo(kit: KitInca, t: Transform3D, semilla: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	kit.caja("algodon", t, Vector3(0, -0.15, 0), Vector3(0.02, 0.3, 0.02), "", true, false)
	for i in 7:
		var a := TAU * i / 7.0 + rng.randf() * 0.4
		var b := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.25 + rng.randf() * 0.2)
		kit.caja("maiz", t * Transform3D(b, Vector3(0, -0.3, 0)), Vector3(0, -0.12, 0), Vector3(0.07, 0.2, 0.07), "", true, false)


## Atado de hierbas secas colgado boca abajo.
func _hierbas(kit: KitInca, t: Transform3D) -> void:
	kit.caja("algodon", t, Vector3(0, -0.1, 0), Vector3(0.02, 0.2, 0.02), "", true, false)
	kit.torno("hierba", t * Transform3D(Basis(), Vector3(0, -0.6, 0)), [Vector2(0.0, 0.0), Vector2(0.11, 0.06), Vector2(0.06, 0.32), Vector2(0.025, 0.42)], 8)


## El quipu del chasqui colgado en el muro del frente: cuerda principal y cuerdas colgantes con nudos.
func _quipu(kit: KitInca, t: Transform3D) -> void:
	kit.caja("algodon", t, Vector3.ZERO, Vector3(0.9, 0.025, 0.025), "", true, false)
	var colores := ["algodon", "lana", "maiz", "algodon", "manta"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 16:
		var x := -0.42 + i * 0.056
		var largo := rng.randf_range(0.3, 0.6)
		var mat: String = colores[i % colores.size()]
		kit.caja(mat, t, Vector3(x, -largo * 0.5, 0), Vector3(0.012, largo, 0.012), "", true, false)
		for k in rng.randi_range(1, 4):
			kit.caja(mat, t, Vector3(x, -0.08 - k * 0.09 - rng.randf() * 0.04, 0), Vector3(0.026, 0.026, 0.026), "", true, false)


## Patio: arriates, banco frente a la vista, aribalos y fardos junto a la puerta (por ellos se sube al techo), lena y
## una chaquitaclla.
func _patio(kit: KitInca) -> void:
	var t := _marco * Transform3D(Basis(), Vector3(0.0, _tapa, 0.0))
	kit.caja("pirca", t, Vector3(6.85, 0.2, 2.2), Vector3(1.0, 0.4, 6.0), "tierra")
	kit.caja("pirca", t, Vector3(-4.0, 0.2, 6.85), Vector3(5.6, 0.4, 0.95), "tierra")
	kit.caja("pirca", t, Vector3(2.6, 0.22, 7.05), Vector3(3.2, 0.44, 0.6))
	kit.aribalo(t * Transform3D(Basis(), Vector3(-2.2, 0.03, -1.15)))
	kit.aribalo(t * Transform3D(Basis(Vector3.UP, 1.0), Vector3(-2.75, 0.03, -0.9)), 0.6)
	# Fardos contra la fachada, junto a la puerta: escalon, pila y de ahi al alero (se camina por el techo).
	# (fuera del alero, que vuela hasta z = -1,1: debajo no se cabe de pie sobre la pila).
	kit.fardo(t * Transform3D(Basis(Vector3.UP, 0.08), Vector3(2.9, 0, -0.45)))
	kit.fardo(t * Transform3D(Basis(Vector3.UP, -0.05), Vector3(2.85, 0.55, -0.45)))
	kit.fardo(t * Transform3D(Basis(Vector3.UP, 0.15), Vector3(2.95, 0, 0.45)))
	# Lena apilada en el rincon del fondo.
	for i in 9:
		var fila := i / 3
		kit.caja("madera", t * Transform3D(Basis(Vector3.UP, 0.04 * (i % 3) - 0.04), Vector3(5.6, 0.09 + fila * 0.17, -6.9 + (i % 3) * 0.18 + fila * 0.05)), Vector3.ZERO, Vector3(1.4 - fila * 0.15, 0.16, 0.16), "", true, fila == 0)
	# Chaquitaclla (el arado de pie) apoyada junto a la puerta.
	kit.caja("madera", t * Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(-1.2, 0.85, -1.25)), Vector3.ZERO, Vector3(0.06, 1.7, 0.06), "", true, false)
	kit.caja("madera", t * Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(-1.2, 0.35, -1.12)), Vector3.ZERO, Vector3(0.05, 0.05, 0.3), "", true, false)


## Flores en los arriates y un arbusto en la esquina (los escaneos de Poly Haven que usa Vegetacion).
func _plantas() -> void:
	var t := _marco * Transform3D(Basis(), Vector3(0.0, _tapa, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var puestos := []
	for i in 9:
		puestos.append([Vector3(6.85 + rng.randf_range(-0.25, 0.25), 0.4, -0.5 + i * 0.65), ["flower_gazania", "flower_ursinia", "flower_heliophila"][i % 3]])
	for i in 8:
		puestos.append([Vector3(-6.4 + i * 0.68, 0.4, 6.85 + rng.randf_range(-0.2, 0.2)), ["flower_ursinia", "flower_gazania"][i % 2]])
	puestos.append([Vector3(6.4, 0.0, 6.6), "wild_rooibos_bush"])
	puestos.append([Vector3(-6.6, 0.0, -6.2), "wild_rooibos_bush"])
	var mallas := {}
	for p: Array in puestos:
		var modelo: String = p[1]
		if not mallas.has(modelo):
			var escena: Node3D = (load("res://assets/plantas/%s/%s.gltf" % [modelo, modelo]) as PackedScene).instantiate()
			var lista := []
			for mi: Node in escena.find_children("*", "MeshInstance3D", true, false):
				var m := (mi as MeshInstance3D).mesh
				if not mi.name.contains("LOD") or mi.name.ends_with("LOD0"):
					lista.append(m)
			escena.free()
			mallas[modelo] = lista
		var opciones: Array = mallas[modelo]
		var malla: Mesh = opciones[rng.randi() % opciones.size()]
		var caja := malla.get_aabb()
		var mi := MeshInstance3D.new()
		mi.mesh = malla
		var esc := rng.randf_range(0.9, 1.25) * (1.4 if modelo == "wild_rooibos_bush" else 1.0)
		mi.transform = t * Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * esc), p[0]) \
			* Transform3D(Basis(), -Vector3(caja.get_center().x, caja.position.y, caja.get_center().z))
		mi.visibility_range_end = 150.0
		add_child(mi)


## El fogon (luz calida que titila) y la niebla de dentro de la casa, donde se ven los rayos que entran por la puerta.
func _luces() -> void:
	_ruido.frequency = 0.05
	_fuego = OmniLight3D.new()
	_fuego.light_color = Color(1.0, 0.55, 0.25)
	_fuego.omni_range = 7.0
	_fuego.shadow_enabled = true
	_fuego.shadow_caster_mask = CAPA_SOMBRA_FUEGO
	_fuego.light_volumetric_fog_energy = 0.4
	_fuego.distance_fade_enabled = true
	_fuego.distance_fade_begin = 80.0
	_fuego.distance_fade_length = 20.0
	_fuego.transform = _casa * Transform3D(Basis(), Vector3(2.15, 0.45, -1.3))
	add_child(_fuego)
	var niebla := FogVolume.new()
	niebla.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	niebla.size = Vector3(CASA.x - 1.1, CASA.y + 1.6, CASA.z - 1.1)
	niebla.transform = _casa * Transform3D(Basis(), Vector3(0, (CASA.y + 1.6) * 0.5, 0))
	var mat := FogMaterial.new()
	mat.density = 0.08   # mas espesa enturbia todo el cuarto (solo la alumbra el fogon)
	mat.albedo = Color(1.0, 0.93, 0.82)
	mat.edge_fade = 0.15
	niebla.material = mat
	add_child(niebla)
	var sh := Shader.new()
	sh.code = SHADER_HAZ
	_haz_mat = ShaderMaterial.new()
	_haz_mat.shader = sh
	_haz = MeshInstance3D.new()
	_haz.name = "haz_de_sol"
	_haz.transform = _casa
	_haz.material_override = _haz_mat
	_haz.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_haz.visible = false
	add_child(_haz)


func _miradores(v: Vector3) -> void:
	var umbral := _casa * Vector3(0.0, 1.6, CASA.z * 0.5 + 0.35)
	var sol := v + Vector3(0, tan(deg_to_rad(3.5)), 0)
	miradores.append({"nombre": "hogar", "pos": _casa * Vector3(-0.9, 1.55, -1.0), "mira": _casa * Vector3(0.25, 0.7, 2.8), "hora": 16.0})
	# A las 16:00 el sol (acimut 302, 20 grados) entra por la puerta y alumbra el suelo hasta el fondo; mas tarde va mas
	# recto pero rasante (a las 16:45, 10 grados: poca luz en el suelo).
	miradores.append({"nombre": "rayo", "pos": _casa * Vector3(-2.4, 1.5, 1.3), "mira": _casa * Vector3(0.3, 0.9, -2.2), "hora": 16.0})
	miradores.append({"nombre": "umbral", "pos": umbral, "mira": umbral + sol * 100.0, "hora": 17.1})
	miradores.append({"nombre": "patio_hogar", "pos": _marco * Vector3(-5.2, _tapa + 1.6, 4.6), "mira": _casa * Vector3(0.6, 1.3, 1.0), "hora": 16.5})
