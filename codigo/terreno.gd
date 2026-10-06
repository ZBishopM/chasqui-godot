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
#include "res://codigo/biomas_andinos.gdshaderinc"

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
uniform float sombra_nubes = 0.5;   // cuanto oscurecen las sombras de las nubes que corren con el viento
// Chacras en los fondos de valle (de lejos): parcelas de verdes y ocres con pircas oscuras en los bordes y algun arbol.
uniform vec3 chacra_verde : source_color = vec3(0.30, 0.42, 0.16);
uniform vec3 chacra_ocre : source_color = vec3(0.58, 0.50, 0.26);
uniform vec3 color_pirca : source_color = vec3(0.16, 0.14, 0.12);
// Huecos (boca del pozo, entrada de la cueva): (x, z, radio). Ahi el suelo no se dibuja; la pieza que va dentro tapa el borde.
uniform vec3 huecos[16];
uniform int n_huecos = 0;
global uniform float humedad;   // 0..1: la lluvia (Lluvia) moja el suelo

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
	for (int i = 0; i < n_huecos; i++) {
		if (distance(v_pos.xz, huecos[i].xy) < huecos[i].z) {
			discard;
		}
	}
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
	// Mas lejos, los pisos ecologicos por altitud real (biomas_andinos): valles verdes, quenuales en las quebradas,
	// puna pajiza y superpuna de pedregal en las cumbres (el relieve real no llega a la cota de nieve).
	float lejania = smoothstep(450.0, 1600.0, dist);
	if (lejania > 0.0) {
		float e = 90.0;
		float vecinos = (altura(p + vec2(e, 0.0)) + altura(p - vec2(e, 0.0)) + altura(p + vec2(0.0, e)) + altura(p - vec2(0.0, e))) * 0.25;
		float conc = clamp((vecinos - v_pos.y) / bio_exageracion(length(p)) / 18.0, 0.0, 1.0);
		vec4 piso = bio_suelo(bio_msnm(v_pos), n, conc, v3, bio_ruido(p / 90.0), 0.0, bio_exageracion(length(p)));
		lejos = mix(lejos, piso.rgb * (0.9 + 0.2 * v1), lejania);
	}
	// Chacras: en lo llano del fondo de los valles, parcelas giradas de 40-80 m, de verde a ocre, con la pirca del borde
	// (se ensancha con la distancia para no parpadear) y arboles sueltos junto a ella.
	float en_valle = (1.0 - smoothstep(-650.0, -420.0, alt)) * (1.0 - smoothstep(0.05, 0.12, pend)) * smoothstep(250.0, 600.0, dist);
	if (en_valle > 0.0) {
		vec2 q = mat2(vec2(0.82, 0.57), vec2(-0.57, 0.82)) * p / vec2(62.0, 44.0);
		vec2 celda = floor(q);
		vec2 f = fract(q);
		float tono = azar(celda);
		vec3 parcela = mix(chacra_verde, chacra_ocre, smoothstep(0.55, 0.9, tono)) * (0.8 + 0.35 * azar(celda + 7.1));
		float ancho_pirca = clamp(dist / 9000.0, 0.012, 0.06);
		float borde = min(min(f.x, 1.0 - f.x) * 62.0 / 44.0, min(f.y, 1.0 - f.y));
		float pirca = 1.0 - smoothstep(ancho_pirca, ancho_pirca * 2.0, borde);
		float arbol = step(0.78, azar(floor(p / 9.0))) * (1.0 - smoothstep(0.0, 0.12, borde));
		parcela = mix(parcela, color_pirca, max(pirca * 0.85, arbol * 0.7));
		lejos = mix(lejos, parcela, en_valle);
	}

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
	// Paredes del cañon (y riscos): roca a cualquier distancia, con estratos horizontales y surcos que bajan. La malla se
	// estira mucho en vertical y sin esto la pared era una cortina lisa.
	float pared = smoothstep(0.42, 0.7, pend);
	if (pared > 0.0) {
		vec3 rr = triplanar(tex_roca, v_pos, n, 26.0) * 0.55 + triplanar(tex_roca, v_pos, n, 8.0) * 0.45;
		rr *= color_roca / max(textureLod(tex_roca, vec2(0.5), 12.0).rgb, vec3(0.02));
		vec2 hor = normalize(vec2(-n.z, n.x) + vec2(0.0001));
		float a_lo_largo = dot(v_pos.xz, hor);
		// Estratos: bandas de distinto grosor y tono (ruido estirado en horizontal), no una onda regular.
		float banda = fbm(vec2(a_lo_largo / 260.0, v_pos.y / 5.5 + fbm(v_pos.xz / 90.0) * 3.0));
		float estrato = 0.78 + 0.32 * smoothstep(0.35, 0.75, banda) - 0.12 * smoothstep(0.6, 0.9, fbm(vec2(a_lo_largo / 30.0, v_pos.y / 2.0)));
		float surco = 0.8 + 0.4 * fbm(vec2(a_lo_largo / 6.0, v_pos.y / 110.0));
		vec3 tono = mix(vec3(0.82, 0.68, 0.55), vec3(0.58, 0.52, 0.47), smoothstep(0.3, 0.7, fbm(vec2(a_lo_largo / 150.0, v_pos.y / 40.0))));
		ALBEDO = mix(ALBEDO, rr * tono * estrato * surco, pared);
	}

	// Sombras de nubes que corren con el viento: el fondo tambien se mueve.
	float nube = smoothstep(0.5, 0.7, fbm((p - viento_dir * TIME * 9.0) / 1800.0 + 7.0));   // nubes grandes
	ALBEDO *= 1.0 - sombra_nubes * nube;

	// Lluvia: el suelo mojado es mas oscuro y brillante; en lo llano se forman charcos que reflejan el cielo.
	float charco = humedad * smoothstep(0.985, 0.996, n.y) * smoothstep(0.55, 0.72, fbm(p / 3.0 + 21.0)) * detalle;
	ALBEDO *= mix(1.0, 0.62, humedad) * (1.0 - 0.45 * charco);
	n_det = normalize(mix(n_det, n, charco));
	NORMAL = (VIEW_MATRIX * vec4(n_det, 0.0)).xyz;
	ROUGHNESS = mix(mix(0.95, 0.5, humedad), 0.04, charco);
	// Seco, el suelo apenas brilla: con el especular por defecto (0,5) las laderas lejanas, vistas al sesgo, reflejaban el
	// cielo y se veian palidas, casi blancas. Mojado y en los charcos si brilla.
	SPECULAR = mix(mix(0.1, 0.5, humedad), 0.5, charco);
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
var _forma: HeightMapShape3D
var _huecos := PackedVector3Array()       # (x, z, radio) que no se dibujan
var _huecos_col := PackedVector3Array()   # (x, z, radio) que no chocan
var _huecos_pendientes := false
const MAX_HUECOS := 16
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


## Pinta suelo de obra (1 = obra: ahi no crece nada y el suelo es de tierra pisada) en una imagen de 1 m/px que cubre la
## zona jugable. Cada huella: [centro (Vector2, mundo), semilados (Vector2), giro (rad, como Basis(UP, giro)), valor 0..1,
## margen m (se desvanece hacia fuera)]. Se mezcla con lo ya pintado (maximo). Hay que llamarlo antes de crear lo que
## se apoya en el terreno (Vegetacion).
func pintar_obras(huellas: Array) -> void:
	var n := int(_lado_cerca) + 1
	if obras == null:
		obras = Image.create(n, n, false, Image.FORMAT_R8)
	var datos := obras.get_data()
	var mitad := _lado_cerca * 0.5
	for hu: Array in huellas:
		var c: Vector2 = hu[0]
		var medio: Vector2 = hu[1]
		var giro: float = hu[2]
		var valor: float = hu[3]
		var margen: float = hu[4]
		var ca := cos(giro)
		var sa := sin(giro)
		var radio := medio.length() + margen
		var i0 := clampi(int(c.x - radio + mitad), 0, n - 1)
		var i1 := clampi(int(c.x + radio + mitad) + 1, 0, n - 1)
		var j0 := clampi(int(c.y - radio + mitad), 0, n - 1)
		var j1 := clampi(int(c.y + radio + mitad) + 1, 0, n - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var dx := i - mitad - c.x
				var dz := j - mitad - c.y
				# Al marco de la huella: inversa de Basis(UP, giro) en el plano.
				var lx := dx * ca - dz * sa
				var lz := dx * sa + dz * ca
				var d := maxf(absf(lx) - medio.x, absf(lz) - medio.y)
				var v := valor if d <= 0.0 else valor * (1.0 - smoothstep(0.0, maxf(margen, 0.01), d))
				if v <= 0.0:
					continue
				var k := j * n + i
				datos[k] = maxi(datos[k], int(v * 255.0))
	obras.set_data(n, n, false, Image.FORMAT_R8, datos)
	_tex_obras = ImageTexture.create_from_image(obras)
	configurar(_mat)


## Abre un hueco redondo en el suelo (x, z, radio): no se dibuja y no choca. `radio_colision` (por defecto 1 m menos que
## el dibujo, porque la rejilla de colision es de 2 m) es lo que se abre en la colision: la pieza que va dentro (brocal,
## boca de cueva) debe tapar el borde. Los huecos se aplican juntos al final del frame.
func abrir_hueco(x: float, z: float, radio: float, radio_colision := -1.0) -> void:
	if _huecos.size() >= MAX_HUECOS:
		push_warning("Terreno: demasiados huecos")
		return
	_huecos.append(Vector3(x, z, radio))
	_huecos_col.append(Vector3(x, z, radio_colision if radio_colision > 0.0 else maxf(radio - 1.0, 0.4)))
	var lista := _huecos.duplicate()
	lista.resize(MAX_HUECOS)
	_mat.set_shader_parameter("huecos", lista)
	_mat.set_shader_parameter("n_huecos", _huecos.size())
	if not _huecos_pendientes:
		_huecos_pendientes = true
		_aplicar_huecos.call_deferred()


func _aplicar_huecos() -> void:
	_huecos_pendientes = false
	var datos := cerca.get_data().to_float32_array()
	var m := cerca.get_width()
	var mitad := _lado_cerca * 0.5
	for h in _huecos_col:
		var i0 := clampi(int((h.x - h.z + mitad) / _paso_cerca), 0, m - 1)
		var i1 := clampi(int((h.x + h.z + mitad) / _paso_cerca) + 1, 0, m - 1)
		var j0 := clampi(int((h.y - h.z + mitad) / _paso_cerca), 0, m - 1)
		var j1 := clampi(int((h.y + h.z + mitad) / _paso_cerca) + 1, 0, m - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				if Vector2(-mitad + i * _paso_cerca - h.x, -mitad + j * _paso_cerca - h.y).length() <= h.z:
					datos[j * m + i] = NAN
	_forma.map_data = datos


## Si (x, z) cae en un hueco.
func en_hueco(x: float, z: float) -> bool:
	for h in _huecos:
		if Vector2(x - h.x, z - h.y).length() < h.z:
			return true
	return false


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
	_forma = forma
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
