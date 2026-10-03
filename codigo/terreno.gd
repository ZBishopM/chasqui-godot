class_name Terreno
extends Node3D
## Relieve real de Vilcashuaman (Copernicus GLO-30, ver herramientas/hornear_relieve.gd), en tres anillos centrados en
## la plaza: la zona jugable a 2 m (1,2 km), el valle a 30 m (~12 km) y el fondo a 90 m (~39 km). Las mallas son
## rejillas planas: el shader las levanta con las alturas, asi el fondo no pesa en memoria. Entre anillos, la malla
## de dentro lleva un faldon hacia abajo que tapa las rendijas. Colision real solo en la zona jugable.
## Ejes: +X este, -Z norte; y = 0 en la plaza.

const LEJOS := "res://assets/relieve/vilcas_lejos.res"
const CERCA := "res://assets/relieve/vilcas_cerca.res"
const ANILLOS := [   # [lado m, paso m, hueco m, faldon]
	[1200.0, 2.0, 0.0, true],
	[11880.0, 30.0, 1200.0, true],
	[38880.0, 90.0, 11880.0, false],
]
const FALDON_M := 30.0

const SHADER := """
shader_type spatial;
render_mode cull_disabled;   // los faldones se ven por las dos caras

uniform sampler2D alt_lejos : filter_linear, repeat_disable;
uniform sampler2D alt_cerca : filter_linear, repeat_disable;
uniform vec2 m_por_px;     // metros por pixel del relieve lejano
uniform vec2 centro_px;    // pixel de la plaza en el relieve lejano
uniform vec2 tam_lejos;
uniform float lado_cerca;
uniform float paso_cerca;
uniform float faldon = 30.0;
uniform vec3 color_ichu : source_color = vec3(0.58, 0.49, 0.31);
uniform vec3 color_verde : source_color = vec3(0.33, 0.38, 0.22);
uniform vec3 color_tierra : source_color = vec3(0.46, 0.37, 0.27);
uniform vec3 color_roca : source_color = vec3(0.43, 0.40, 0.36);

varying vec3 v_pos;
varying vec3 v_normal;

float h_lejos(vec2 xz) {
	return texture(alt_lejos, (centro_px + xz / m_por_px + 0.5) / tam_lejos).r;
}

float h_cerca(vec2 xz) {
	float n = lado_cerca / paso_cerca + 1.0;
	return texture(alt_cerca, ((xz + lado_cerca * 0.5) / paso_cerca + 0.5) / n).r;
}

float altura(vec2 xz) {
	return max(abs(xz.x), abs(xz.y)) <= lado_cerca * 0.5 ? h_cerca(xz) : h_lejos(xz);
}

vec3 normal_en(vec2 xz) {
	float e = max(abs(xz.x), abs(xz.y)) <= lado_cerca * 0.5 - paso_cerca ? paso_cerca : m_por_px.x;
	float hx = altura(xz - vec2(e, 0.0)) - altura(xz + vec2(e, 0.0));
	float hz = altura(xz - vec2(0.0, e)) - altura(xz + vec2(0.0, e));
	return normalize(vec3(hx, 2.0 * e, hz));
}

// Hash sin seno (Dave Hoskins, "hash without sine"): con coordenadas de miles de celdas el de fract(sin) se rompe.
float azar(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(azar(i), azar(i + vec2(1, 0)), f.x), mix(azar(i + vec2(0, 1)), azar(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return ruido(p) * 0.5 + ruido(p * 2.1 + 3.7) * 0.3 + ruido(p * 4.3 + 9.1) * 0.2; }

void vertex() {
	vec2 xz = VERTEX.xz;
	VERTEX.y = altura(xz) - faldon * UV2.x;
	v_normal = normal_en(xz);
	NORMAL = v_normal;
	v_pos = VERTEX;
}

void fragment() {
	vec3 n = v_normal;
	float pend = 1.0 - n.y;                                 // 0 llano, ~0.3 a 45 grados
	float alt = v_pos.y;                                    // relativa a la plaza (3482 m)
	vec2 p = v_pos.xz;
	// variacion a varias escalas (sin mod: envolver el dominio deja una costura en x = 0 y z = 0)
	float v1 = fbm(p / 37.0);
	float v2 = fbm(p / 6.0);
	float v3 = fbm(p / 400.0);
	// los fondos de valle (mas de 500 m bajo la plaza) son mas verdes que la puna
	vec3 hierba = mix(color_ichu, color_verde, (1.0 - smoothstep(-1200.0, -500.0, alt)) * 0.8 + v3 * 0.35);
	hierba *= 0.85 + 0.3 * v1;
	vec3 suelo = mix(hierba, color_tierra * (0.9 + 0.2 * v2), smoothstep(0.55, 0.8, v1 + v2 * 0.3) * 0.6);
	vec3 roca = color_roca * (0.75 + 0.45 * v2);
	float roca_w = smoothstep(0.18, 0.32, pend + (v1 - 0.5) * 0.12);
	ALBEDO = mix(suelo, roca, roca_w);
	ROUGHNESS = 0.95;
}
"""

var lejos: Image
var cerca: Image
var _m_por_px: Vector2
var _centro_px: Vector2
var _paso_cerca: float
var _lado_cerca: float


func _ready() -> void:
	lejos = load(LEJOS)
	cerca = load(CERCA)
	_m_por_px = lejos.get_meta("m_por_px")
	_centro_px = lejos.get_meta("centro_px")
	_paso_cerca = cerca.get_meta("paso_m")
	_lado_cerca = (cerca.get_width() - 1) * _paso_cerca
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("alt_lejos", ImageTexture.create_from_image(lejos))
	mat.set_shader_parameter("alt_cerca", ImageTexture.create_from_image(cerca))
	mat.set_shader_parameter("m_por_px", _m_por_px)
	mat.set_shader_parameter("centro_px", _centro_px)
	mat.set_shader_parameter("tam_lejos", Vector2(lejos.get_width(), lejos.get_height()))
	mat.set_shader_parameter("lado_cerca", _lado_cerca)
	mat.set_shader_parameter("paso_cerca", _paso_cerca)
	mat.set_shader_parameter("faldon", FALDON_M)
	for a: Array in ANILLOS:
		var mi := MeshInstance3D.new()
		mi.mesh = _rejilla(a[0], a[1], a[2], a[3])
		mi.material_override = mat
		var mitad: float = a[0] * 0.5
		mi.custom_aabb = AABB(Vector3(-mitad, -2000.0, -mitad), Vector3(a[0], 3500.0, a[0]))
		add_child(mi)
	_colision()


## Altura del suelo (m, relativa a la plaza) en x, z: la misma que dibuja el shader.
func altura(x: float, z: float) -> float:
	var mitad := _lado_cerca * 0.5
	if absf(x) <= mitad and absf(z) <= mitad:
		return _bilineal(cerca, (x + mitad) / _paso_cerca, (z + mitad) / _paso_cerca)
	return _bilineal(lejos, _centro_px.x + x / _m_por_px.x, _centro_px.y + z / _m_por_px.y)


func _bilineal(img: Image, u: float, v: float) -> float:
	var x0 := clampi(int(floor(u)), 0, img.get_width() - 2)
	var y0 := clampi(int(floor(v)), 0, img.get_height() - 2)
	var fx := clampf(u - x0, 0.0, 1.0)
	var fy := clampf(v - y0, 0.0, 1.0)
	var a := lerpf(img.get_pixel(x0, y0).r, img.get_pixel(x0 + 1, y0).r, fx)
	var b := lerpf(img.get_pixel(x0, y0 + 1).r, img.get_pixel(x0 + 1, y0 + 1).r, fx)
	return lerpf(a, b, fy)


## Rejilla plana de `lado` m con celdas de `paso` m y un hueco central de `hueco` m (alineado a la rejilla). Con
## `faldon`, el borde exterior baja FALDON_M (UV2.x = 1) para tapar la rendija con el anillo de fuera.
func _rejilla(lado: float, paso: float, hueco: float, faldon: bool) -> ArrayMesh:
	var q := int(round(lado / paso))
	var mitad := lado * 0.5
	var h := hueco * 0.5
	var pos := PackedVector3Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	for j in q + 1:
		for i in q + 1:
			pos.append(Vector3(-mitad + i * paso, 0.0, -mitad + j * paso))
			uv2.append(Vector2.ZERO)
	for j in q:
		for i in q:
			var cx := -mitad + (i + 0.5) * paso
			var cz := -mitad + (j + 0.5) * paso
			if hueco > 0.0 and absf(cx) < h and absf(cz) < h:
				continue
			var a := j * (q + 1) + i
			idx.append_array([a, a + 1, a + q + 1, a + 1, a + q + 2, a + q + 1])
	if faldon:
		# Cinta vertical: cada vertice del borde se duplica abajo.
		var borde: Array[int] = []
		for i in q:
			borde.append(i)                          # norte, de oeste a este
		for j in q:
			borde.append(j * (q + 1) + q)            # este, de norte a sur
		for i in q:
			borde.append(q * (q + 1) + q - i)        # sur, de este a oeste
		for j in q:
			borde.append((q - j) * (q + 1))          # oeste, de sur a norte
		var base := pos.size()
		for k in borde.size():
			pos.append(pos[borde[k]])
			uv2.append(Vector2(1.0, 0.0))
		for k in borde.size():
			var s := (k + 1) % borde.size()
			var a: int = borde[k]
			var b: int = borde[s]
			idx.append_array([a, base + k, b, b, base + k, base + s])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Colision de la zona jugable (las alturas a 2 m) y cuatro muros invisibles en su borde.
func _colision() -> void:
	var cuerpo := StaticBody3D.new()
	add_child(cuerpo)
	var forma := HeightMapShape3D.new()
	forma.map_width = cerca.get_width()
	forma.map_depth = cerca.get_height()
	forma.map_data = cerca.get_data().to_float32_array()
	var col := CollisionShape3D.new()
	col.shape = forma
	col.scale = Vector3(_paso_cerca, 1.0, _paso_cerca)
	cuerpo.add_child(col)
	var mitad := _lado_cerca * 0.5
	for lado in 4:
		var muro := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = Vector3(_lado_cerca, 2000.0, 2.0) if lado < 2 else Vector3(2.0, 2000.0, _lado_cerca)
		muro.shape = caja
		muro.position = [Vector3(0, 0, -mitad + 4.0), Vector3(0, 0, mitad - 4.0), Vector3(-mitad + 4.0, 0, 0), Vector3(mitad - 4.0, 0, 0)][lado]
		cuerpo.add_child(muro)
