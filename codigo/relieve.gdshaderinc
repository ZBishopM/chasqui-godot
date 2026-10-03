// Relieve de Vilcashuaman compartido por el terreno, el ichu y lo que se apoye en el suelo (ver Terreno.configurar).
// Alturas relativas a la plaza; +X este, -Z norte.

uniform sampler2D alt_lejos : filter_linear, repeat_disable;
uniform sampler2D alt_cerca : filter_linear, repeat_disable;
uniform vec2 m_por_px;     // metros por pixel del relieve lejano
uniform vec2 centro_px;    // pixel de la plaza en el relieve lejano
uniform vec2 tam_lejos;
uniform float lado_cerca;
uniform float paso_cerca;
// Viento: direccion (en el suelo) y fuerza 0..1. Mueve el ichu y las sombras de las nubes.
uniform vec2 viento_dir = vec2(0.8, -0.6);
uniform float viento_fuerza = 0.6;

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

// Cuanto ichu crece aqui (0..1): nada en pendientes fuertes, manchas de tierra desnuda entre matas. El terreno usa el
// mismo valor para poner textura de hierba seca o de tierra, asi el ichu nace donde el suelo es de hierba.
float cobertura_ichu(vec2 xz, vec3 n) {
	float pend = 1.0 - n.y;
	float claros = smoothstep(0.35, 0.6, fbm(xz / 23.0 + 51.0));
	return (1.0 - smoothstep(0.12, 0.22, pend)) * claros;
}
