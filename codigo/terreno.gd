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

#include "res://codigo/relieve.gdshaderinc"

uniform float faldon = 30.0;
// Texturas de suelo (Poly Haven, CC0): hierba seca, tierra con piedras y roca. Se ven de cerca; lejos se funden con
// colores medios para que no se note la repeticion.
uniform sampler2D tex_hierba : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nor_hierba : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_tierra : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nor_tierra : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_roca : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nor_roca : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float escala_suelo = 3.0;   // m que cubre cada repeticion de la textura de suelo
uniform float escala_roca = 7.0;
uniform vec3 color_ichu : source_color = vec3(0.58, 0.49, 0.31);
uniform vec3 color_verde : source_color = vec3(0.33, 0.38, 0.22);
uniform vec3 color_tierra : source_color = vec3(0.46, 0.37, 0.27);
uniform vec3 color_roca : source_color = vec3(0.43, 0.40, 0.36);
uniform float sombra_nubes = 0.35;  // cuanto oscurecen las sombras de las nubes que corren con el viento

varying vec3 v_pos;
varying vec3 v_normal;

// Textura proyectada desde arriba, con dos escalas mezcladas para romper la repeticion.
vec3 cenital(sampler2D t, vec2 xz, float escala) {
	return mix(texture(t, xz / escala).rgb, texture(t, xz / (escala * 3.7) + 0.31).rgb, 0.35);
}

// Roca en tres proyecciones (triplanar): en las paredes no se estira.
vec3 triplanar(sampler2D t, vec3 p, vec3 n, float escala) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(t, p.zy / escala).rgb * w.x + texture(t, p.xz / escala).rgb * w.y + texture(t, p.xy / escala).rgb * w.z;
}

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
	float dist = length(v_pos - CAMERA_POSITION_WORLD);
	float v1 = fbm(p / 37.0);
	float v3 = fbm(p / 400.0);
	float roca_w = smoothstep(0.18, 0.32, pend + (v1 - 0.5) * 0.12);
	float ichu = cobertura_ichu(p, n);

	// Lejos: colores medios. Los fondos de valle (mas de 500 m bajo la plaza) son mas verdes que la puna.
	vec3 hierba_lejos = mix(color_ichu, color_verde, (1.0 - smoothstep(-1200.0, -500.0, alt)) * 0.8 + v3 * 0.35);
	vec3 suelo_lejos = mix(color_tierra, hierba_lejos, ichu * 0.8 + 0.2) * (0.85 + 0.3 * v1);
	vec3 lejos = mix(suelo_lejos, color_roca * (0.8 + 0.4 * v1), roca_w);

	// Cerca: texturas.
	vec3 cerca = lejos;
	vec3 n_det = n;
	float detalle = 1.0 - smoothstep(60.0, 260.0, dist);
	if (detalle > 0.0) {
		// Cada textura se reescala para que su color medio (su mip mas pequeno) sea el color de lejos: cerca se ve el
		// detalle de la foto, y al alejarse no hay salto de color.
		vec3 hierba = cenital(tex_hierba, p, escala_suelo);
		hierba *= hierba_lejos / max(textureLod(tex_hierba, vec2(0.5), 12.0).rgb, vec3(0.02));
		vec3 tierra = cenital(tex_tierra, p, escala_suelo * 1.3);
		tierra *= color_tierra / max(textureLod(tex_tierra, vec2(0.5), 12.0).rgb, vec3(0.02));
		vec3 roca = triplanar(tex_roca, v_pos, n, escala_roca);
		roca *= color_roca / max(textureLod(tex_roca, vec2(0.5), 12.0).rgb, vec3(0.02));
		vec3 suelo = mix(tierra, hierba, smoothstep(0.2, 0.6, ichu));
		cerca = mix(suelo, roca, roca_w) * (0.85 + 0.3 * v1);
		// Relieve fino de la textura: perturba la normal del suelo (aproximacion "whiteout" desde arriba).
		vec2 nh = texture(nor_hierba, p / escala_suelo).xy * 2.0 - 1.0;
		vec2 nt = texture(nor_tierra, p / (escala_suelo * 1.3)).xy * 2.0 - 1.0;
		vec2 nr = texture(nor_roca, p / escala_roca).xy * 2.0 - 1.0;
		vec2 nd = mix(mix(nt, nh, smoothstep(0.2, 0.6, ichu)), nr, roca_w) * detalle;
		n_det = normalize(vec3(n.x + nd.x, n.y, n.z - nd.y));
	}
	ALBEDO = mix(lejos, cerca, detalle);

	// Sombras de nubes que corren con el viento: el fondo tambien se mueve.
	float nube = smoothstep(0.52, 0.72, fbm((p - viento_dir * TIME * 9.0) / 1100.0 + 7.0));
	ALBEDO *= 1.0 - sombra_nubes * nube;

	NORMAL = (VIEW_MATRIX * vec4(n_det, 0.0)).xyz;
	ROUGHNESS = 0.95;
}
"""

const TEXTURAS := {
	"tex_hierba": "res://assets/terreno/withered_grass/withered_grass_diff_1k.jpg",
	"nor_hierba": "res://assets/terreno/withered_grass/withered_grass_nor_gl_1k.jpg",
	"tex_tierra": "res://assets/terreno/dry_ground_rocks/dry_ground_rocks_diff_1k.jpg",
	"nor_tierra": "res://assets/terreno/dry_ground_rocks/dry_ground_rocks_nor_gl_1k.jpg",
	"tex_roca": "res://assets/terreno/rock_face_03/rock_face_03_diff_1k.jpg",
	"nor_roca": "res://assets/terreno/rock_face_03/rock_face_03_nor_gl_1k.jpg",
}

var lejos: Image
var cerca: Image
var obras: Image                 # suelo de obra (pueblo), ver poner_obras
var _tex_lejos: ImageTexture
var _tex_cerca: ImageTexture
var _tex_obras: ImageTexture
var _mat: ShaderMaterial
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
	_tex_lejos = ImageTexture.create_from_image(lejos)
	_tex_cerca = ImageTexture.create_from_image(cerca)
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_mat = mat
	configurar(mat)
	mat.set_shader_parameter("faldon", FALDON_M)
	for t: String in TEXTURAS:
		mat.set_shader_parameter(t, load(TEXTURAS[t]))
	for a: Array in ANILLOS:
		var mi := MeshInstance3D.new()
		mi.mesh = _rejilla(a[0], a[1], a[2], a[3])
		mi.material_override = mat
		var mitad: float = a[0] * 0.5
		mi.custom_aabb = AABB(Vector3(-mitad, -2000.0, -mitad), Vector3(a[0], 3500.0, a[0]))
		add_child(mi)
	_colision()


## Pone en `mat` los uniformes del relieve (codigo/relieve.gdshaderinc): cualquier shader que lo incluya sabe la altura
## del suelo en cada punto (el ichu se apoya asi en el terreno sin pasar por la CPU).
func configurar(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("alt_lejos", _tex_lejos)
	mat.set_shader_parameter("alt_cerca", _tex_cerca)
	mat.set_shader_parameter("m_por_px", _m_por_px)
	mat.set_shader_parameter("centro_px", _centro_px)
	mat.set_shader_parameter("tam_lejos", Vector2(lejos.get_width(), lejos.get_height()))
	mat.set_shader_parameter("lado_cerca", _lado_cerca)
	mat.set_shader_parameter("paso_cerca", _paso_cerca)
	if _tex_obras != null:
		mat.set_shader_parameter("obras", _tex_obras)
		mat.set_shader_parameter("paso_obras", _lado_cerca / (obras.get_width() - 1))


## Marca el suelo de obra (Image FORMAT_R8 que cubre la zona jugable, 1 = obra): ahi no crece nada y el suelo es de
## tierra. Hay que llamarlo antes de crear lo que se apoya en el terreno (Vegetacion).
func poner_obras(img: Image) -> void:
	obras = img
	_tex_obras = ImageTexture.create_from_image(img)
	configurar(_mat)


## Cuanto suelo de obra hay en x, z (0..1).
func obra(x: float, z: float) -> float:
	if obras == null:
		return 0.0
	var paso := _lado_cerca / (obras.get_width() - 1)
	var i := int(round((x + _lado_cerca * 0.5) / paso))
	var j := int(round((z + _lado_cerca * 0.5) / paso))
	if i < 0 or j < 0 or i >= obras.get_width() or j >= obras.get_height():
		return 0.0
	return obras.get_pixel(i, j).r


## Normal del suelo en x, z (la misma cuenta que el shader).
func normal(x: float, z: float) -> Vector3:
	var e := _paso_cerca if absf(x) < _lado_cerca * 0.5 - _paso_cerca and absf(z) < _lado_cerca * 0.5 - _paso_cerca else _m_por_px.x
	return Vector3(altura(x - e, z) - altura(x + e, z), 2.0 * e, altura(x, z - e) - altura(x, z + e)).normalized()


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
