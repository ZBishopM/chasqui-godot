class_name MaterialesInca
extends RefCounted
## Materiales del kit inca (KitInca). Sin texturas nuevas: la piedra y el ichu se dibujan en el shader a partir de las UV
## en metros que pone el kit (u a lo largo de la pieza, v hacia arriba o pendiente abajo), y la roca y la tierra de
## Poly Haven que ya usa el terreno dan el grano fino.
##   pirca     piedra de campo asentada con barro (casas comunes, cercos, andenes)
##   silleria  bloques labrados en hiladas, juntas finas (kallanka, casas de los curacas)
##   poligonal piedras encajadas de muchos lados (templo); losa, la del camino, mas oscura
##   ichu      techo de paja en hileras
##   tierra    suelo apisonado (plataformas, patios)
##   roca      paredes de las cuevas (oscurecidas por el color de vertice)
##   madera, ceramica, agua

const SHADER_PIEDRA := """
shader_type spatial;

uniform sampler2D tex_roca : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform int modo = 0;              // 0 pirca, 1 silleria en hiladas, 2 poligonal (para el templo)
uniform float tam = 0.27;          // m: tamano medio de una piedra
uniform vec3 color_piedra : source_color = vec3(0.60, 0.54, 0.46);
uniform vec3 color_piedra2 : source_color = vec3(0.56, 0.47, 0.38);
uniform vec3 color_barro : source_color = vec3(0.52, 0.42, 0.31);
uniform float profundidad = 0.035; // m que se hunde la junta respecto a la cara de la piedra
global uniform float humedad;      // lluvia: la piedra mojada oscurece y brilla; la junta de barro tarda en secar

float azar(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 azar2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

// Celdas de Voronoi: x = distancia aproximada al borde de la celda (F2 - F1), y = numero de la piedra (0..1).
vec2 voronoi(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 id = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 r = g + 0.15 + 0.7 * azar2(i + g) - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = i + g;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec2(sqrt(d2) - sqrt(d1), azar(id));
}

void fragment() {
	vec2 uv = UV;
	float piedra;   // 1 piedra, 0 junta
	float alto;     // relieve 0..1 (la cara de la piedra abomba)
	float id;
	if (modo == 1) {
		// Hiladas de altura algo variable; bloques de largo distinto en cada hilada, desfasados.
		float hh = 0.42;
		float fila = floor(uv.y / hh);
		float largo = 0.55 + 0.6 * azar(vec2(fila, 3.1));
		float bx = (uv.x + azar(vec2(fila, 7.7)) * largo) / largo;
		float col = floor(bx);
		float fx = fract(bx) * largo;
		float fy = fract(uv.y / hh) * hh;
		float e = min(min(fx, largo - fx), min(fy, hh - fy));
		piedra = smoothstep(0.004, 0.012, e);
		alto = smoothstep(0.0, 0.08, e);
		id = azar(vec2(col, fila));
	} else {
		float escala = modo == 2 ? tam * 2.4 : tam;
		// En la pirca las piedras se asientan echadas: mas anchas que altas.
		vec2 p = uv / escala * (modo == 2 ? vec2(0.9, 1.0) : vec2(0.72, 1.18));
		vec2 v = voronoi(p);
		if (modo == 2) {
			piedra = smoothstep(0.004, 0.02, v.x);
			alto = smoothstep(0.0, 0.3, v.x);
		} else {
			piedra = smoothstep(0.03, 0.09, v.x);
			alto = piedra * (0.55 + 0.45 * smoothstep(0.08, 0.45, v.x));
		}
		id = v.y;
	}
	// Grano de roca: la luminancia de la foto de roca relativa a su media, asi solo aporta detalle (no tine).
	vec3 roca = texture(tex_roca, uv / 1.7 + id * 3.1).rgb;
	vec3 media = textureLod(tex_roca, vec2(0.5), 12.0).rgb;
	float grano = dot(roca, vec3(0.3, 0.5, 0.2)) / max(dot(media, vec3(0.3, 0.5, 0.2)), 0.02);
	vec3 c_piedra = mix(color_piedra, color_piedra2, azar(vec2(id, 1.7))) * (0.78 + 0.4 * id);
	c_piedra *= mix(1.0, grano, 0.55);
	vec3 c_junta = color_barro * (0.85 + 0.25 * grano);
	// Lejos el dibujo de las piedras se funde con su color medio (sin parpadeo).
	float dist = length(VERTEX);
	float lejos = smoothstep(25.0, 70.0, dist);
	vec3 medio = mix(color_barro, mix(color_piedra, color_piedra2, 0.5), modo == 0 ? 0.75 : 0.95);
	ALBEDO = mix(mix(c_junta, c_piedra, piedra), medio, lejos);
	ROUGHNESS = mix(0.95, 0.85, piedra);
	ALBEDO *= mix(1.0, mix(0.55, 0.72, piedra), humedad);
	ROUGHNESS = mix(ROUGHNESS, mix(0.6, 0.28, piedra), humedad);
	AO = mix(0.75, 1.0, piedra);
	AO_LIGHT_AFFECT = 0.2;
	// Relieve sin tangentes: gradiente de la altura en pantalla (bump mapping de Mikkelsen).
	float h = alto * profundidad * (1.0 - lejos);
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad);
}
"""

const SHADER_ICHU := """
shader_type spatial;

uniform vec3 color_nuevo : source_color = vec3(0.64, 0.53, 0.32);
uniform vec3 color_viejo : source_color = vec3(0.47, 0.44, 0.38);
uniform float hilera = 0.32;   // m de pendiente que cubre cada hilera de paja
global uniform float humedad;  // lluvia: la paja mojada se oscurece
uniform float profundidad = 0.03;

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

void fragment() {
	// UV: x a lo largo de la cumbrera, y pendiente abajo (m). Cada hilera tapa el arranque de la siguiente.
	float capa = floor(UV.y / hilera);
	float t = fract(UV.y / hilera);
	float borde = ruido(vec2(UV.x * 6.0, capa * 5.3)) * 0.25;   // el filo de cada hilera no es recto
	t = fract(UV.y / hilera + borde);
	// Hebras: ruido estirado pendiente abajo, desfasado en cada hilera; dos escalas para que no se vea una rejilla.
	float hebras = ruido(vec2(UV.x * 45.0 + capa * 17.0, UV.y * 2.2 + capa * 0.7));
	hebras = hebras * 0.55 + ruido(vec2(UV.x * 130.0 + capa * 5.0, UV.y * 5.0)) * 0.45;
	float sol = ruido(UV * vec2(0.35, 0.6) + 3.0);                  // manchas de paja vieja y nueva
	vec3 c = mix(color_viejo, color_nuevo, smoothstep(0.2, 0.85, sol));
	c *= 0.72 + 0.45 * hebras;
	c *= mix(0.72, 1.0, smoothstep(0.0, 0.35, t));                  // sombra bajo la hilera de encima
	float dist = length(VERTEX);
	float lejos = smoothstep(30.0, 90.0, dist);
	ALBEDO = mix(c, mix(color_viejo, color_nuevo, 0.5) * 0.85, lejos);
	ALBEDO *= mix(1.0, 0.62, humedad);
	ROUGHNESS = mix(1.0, 0.7, humedad);
	SPECULAR = 0.2;
	AO = mix(0.6, 1.0, smoothstep(0.0, 0.4, t));
	AO_LIGHT_AFFECT = 0.4;
	float h = (t * 0.5 + hebras * 0.5) * profundidad * (1.0 - lejos);
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad);
}
"""

## Tejido andino (mantas, la cama, la lliclla colgada): franjas a lo largo de UV.y (en metros) y, en las franjas anchas
## (pallay), rombos escalonados. Rojo de cochinilla, amarillo de chilca, negro y blanco de lana sin tenir.
const SHADER_MANTA := """
shader_type spatial;
render_mode cull_disabled;

uniform vec3 rojo : source_color = vec3(0.55, 0.07, 0.06);
uniform vec3 amarillo : source_color = vec3(0.78, 0.55, 0.12);
uniform vec3 negro : source_color = vec3(0.07, 0.05, 0.05);
uniform vec3 blanco : source_color = vec3(0.80, 0.74, 0.63);
uniform vec3 verde : source_color = vec3(0.12, 0.30, 0.20);
uniform float semilla = 0.0;

float hash(float n) { return fract(sin(n * 12.9898 + semilla * 4.13) * 43758.5453); }

void fragment() {
	// Repeticion de 0,9 m: franja ancha de pallay (0,32), listas finas a los lados y fondo rojo.
	float v = fract(UV.y / 0.9);
	vec3 c = rojo;
	if (v < 0.04 || (v > 0.47 && v < 0.51)) c = negro;
	else if (v < 0.08 || (v > 0.43 && v < 0.47)) c = amarillo;
	else if (v > 0.10 && v < 0.42) {
		// Pallay: rombos escalonados (distancia de Manhattan pixelada en celdas de 2 cm) de colores que alternan.
		float celda = floor(UV.x / 0.24);
		vec2 q = vec2(fract(UV.x / 0.24) - 0.5, (v - 0.26) / 0.32 * 1.33);
		q = floor(q * 12.0 + 0.5) / 12.0;
		float d = abs(q.x) + abs(q.y);
		float h = hash(celda + floor(UV.y / 0.9) * 7.0);
		vec3 centro = h < 0.5 ? amarillo : verde;
		c = negro;
		if (d < 0.42) c = blanco;
		if (d < 0.30) c = centro;
		if (d < 0.12) c = rojo;
	} else if (v > 0.55 && v < 0.58) c = blanco;
	else if (v > 0.62 && v < 0.64) c = amarillo;
	// Trama: hilos finos que dan textura y un poco de desgaste.
	float hilo = 0.85 + 0.15 * sin(UV.x * 900.0) * sin(UV.y * 700.0);
	ALBEDO = c * hilo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.15;
	SSS_STRENGTH = 0.2;
}
"""

const ROCA := "res://assets/terreno/rock_face_03/rock_face_03_diff_1k.jpg"
const TIERRA := "res://assets/terreno/dry_ground_rocks/dry_ground_rocks_diff_1k.jpg"

static var _cache: Dictionary = {}


## Diccionario nombre -> Material, creado una sola vez.
static func todos() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var sh_piedra := Shader.new()
	sh_piedra.code = SHADER_PIEDRA
	var tex_roca: Texture2D = load(ROCA)
	var pirca := ShaderMaterial.new()
	pirca.shader = sh_piedra
	pirca.set_shader_parameter("tex_roca", tex_roca)
	pirca.set_shader_parameter("modo", 0)
	var silleria := ShaderMaterial.new()
	silleria.shader = sh_piedra
	silleria.set_shader_parameter("tex_roca", tex_roca)
	silleria.set_shader_parameter("modo", 1)
	silleria.set_shader_parameter("color_piedra", Color(0.60, 0.56, 0.50))
	silleria.set_shader_parameter("color_piedra2", Color(0.54, 0.50, 0.45))
	silleria.set_shader_parameter("color_barro", Color(0.38, 0.34, 0.29))
	silleria.set_shader_parameter("profundidad", 0.02)
	var poligonal := silleria.duplicate() as ShaderMaterial
	poligonal.set_shader_parameter("modo", 2)
	# Losas del Qhapaq Ñan: piedra poligonal mas oscura y gastada que la del templo.
	var losa := poligonal.duplicate() as ShaderMaterial
	losa.set_shader_parameter("color_piedra", Color(0.47, 0.43, 0.38))
	losa.set_shader_parameter("color_piedra2", Color(0.42, 0.37, 0.31))
	losa.set_shader_parameter("color_barro", Color(0.36, 0.29, 0.21))
	losa.set_shader_parameter("tam", 0.2)

	var sh_ichu := Shader.new()
	sh_ichu.code = SHADER_ICHU
	var ichu := ShaderMaterial.new()
	ichu.shader = sh_ichu

	var tierra := StandardMaterial3D.new()
	tierra.albedo_texture = load(TIERRA)
	tierra.albedo_color = Color(0.92, 0.84, 0.74)
	tierra.uv1_triplanar = true
	tierra.uv1_world_triplanar = true
	tierra.uv1_scale = Vector3.ONE / 3.0
	tierra.roughness = 1.0

	var madera := StandardMaterial3D.new()
	madera.albedo_color = Color(0.33, 0.23, 0.15)
	madera.roughness = 0.85
	var ceramica := StandardMaterial3D.new()
	ceramica.albedo_color = Color(0.56, 0.27, 0.16)
	ceramica.roughness = 0.6
	var agua := StandardMaterial3D.new()
	agua.albedo_color = Color(0.02, 0.03, 0.03)
	agua.roughness = 0.05
	agua.metallic_specular = 0.7

	# Roca de las cuevas: la foto de roca proyectada, oscurecida por el color de vertice (luz que llega de las bocas).
	var roca := StandardMaterial3D.new()
	roca.albedo_texture = tex_roca
	roca.albedo_color = Color(0.78, 0.7, 0.62)
	roca.uv1_triplanar = true
	roca.uv1_world_triplanar = true
	roca.uv1_scale = Vector3.ONE / 2.5
	roca.vertex_color_use_as_albedo = true
	roca.roughness = 0.95

	var sh_manta := Shader.new()
	sh_manta.code = SHADER_MANTA
	var manta := ShaderMaterial.new()
	manta.shader = sh_manta
	var plano := func(color: Color, rugoso := 0.9) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rugoso
		return m
	var maiz: StandardMaterial3D = plano.call(Color(0.80, 0.52, 0.14), 0.7)
	var hierba: StandardMaterial3D = plano.call(Color(0.33, 0.36, 0.17))
	hierba.cull_mode = BaseMaterial3D.CULL_DISABLED
	var algodon: StandardMaterial3D = plano.call(Color(0.78, 0.72, 0.60))
	var lana: StandardMaterial3D = plano.call(Color(0.50, 0.09, 0.07))
	# Brasas del fogon: brillan solas (el glow las hace resplandecer).
	var brasa: StandardMaterial3D = plano.call(Color(0.1, 0.03, 0.01))
	brasa.emission_enabled = true
	brasa.emission = Color(1.0, 0.38, 0.08)
	brasa.emission_energy_multiplier = 3.0

	_cache = {
		"pirca": pirca, "silleria": silleria, "poligonal": poligonal, "ichu": ichu,
		"tierra": tierra, "madera": madera, "ceramica": ceramica, "agua": agua, "roca": roca, "losa": losa,
		"manta": manta, "maiz": maiz, "hierba": hierba, "algodon": algodon, "lana": lana, "brasa": brasa,
	}
	return _cache
