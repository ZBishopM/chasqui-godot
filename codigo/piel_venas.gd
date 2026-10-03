class_name PielVenas
extends RefCounted
## Piel de los brazos con las venas de oro por debajo (GDD §6, «el oro vive fusionado bajo la piel del Chasqui»). La red de
## venas viene horneada en los vertices de la piel densa (herramientas/campo_venas.gd); este shader empuja la piel por la
## normal con un perfil de bulto, le inclina la normal para que la luz dibuje el relieve y deja que el oro se trasluzca.
##
## Estados (los mueve Manos):
##   - reposo: las venas tienen el tamaño `venas_base` (lo fija el juego: 0 sin poderes, 0.5 con poderes, sube hacia 1 con
##     el Caos) y el oro apenas brilla, con el latido;
##   - al usar un poder, `crecimiento` avanza de los nudillos al codo: por detras del frente las venas se hinchan al 100 %
##     y el oro se enciende con `brillo` (la curva de esfuerzo y el espasmo del gesto); despues vuelven a `venas_base`.
##
## Se tocan en vivo: altura (m), grosor (1 = Caos bajo; ~1,5 = Caos alto), luz, luz_reposo, latido, color_oro.

const SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D textura : source_color, filter_linear_mipmap, repeat_enable;
uniform float unidad = 1.0;            // metros por unidad de malla (lo hornea hornear_piel.gd)
uniform float altura = 0.002;          // m: cuanto levanta la piel una vena hinchada, en su eje
uniform float grosor = 1.0;            // ancho de las venas
uniform float venas_base = 0.5;        // tamaño en reposo (0..1)
uniform float crecimiento = 0.0;       // 0..1 desde los nudillos: hasta donde llega el poder (brazo del poder)
uniform float crecimiento_otro = 0.0;  // lo mismo para el otro brazo
uniform float brillo = 1.0;            // AnimProc.brillo_venas del brazo del poder (~1 en reposo, ~2,6 en el pico)
uniform float brillo_otro = 1.0;
uniform vec3 color_oro : source_color = vec3(1.0, 0.66, 0.16);
uniform float luz = 1.6;               // energia del oro encendido
uniform float luz_reposo = 0.08;       // fraccion de luz que conserva el oro en reposo
uniform float latido = 0.12;           // cuanto late la vena (altura) con el pulso
uniform float rugosidad = 0.62;
// FOV propio de las manos (viewmodel FOV), en grados verticales; 0 = el de la camara. Asi el FOV del mundo puede abrirse
// (esprint, patada del Halcon) sin que los antebrazos, tan cerca de la camara, se estiren hacia los bordes.
uniform float fov_manos = 0.0;

varying float v_campo;   // distancia al eje / alcance del bulto (1 = fin del bulto)
varying float v_r;       // distancia al eje de la vena / (3 * semiancho): 1 = lejos de toda vena
varying float v_h;       // m: altura en este tramo
varying float v_ancho;   // m: hasta donde llega el bulto
varying float v_tam;     // tamaño 0..1 en este punto (reposo -> 1 por detras del frente)
varying float v_encendido;
varying float v_frente;
varying float v_g;       // coordenada de crecimiento (0 nudillos .. 1 codo)
varying vec3 v_aleja;    // direccion en la piel que se aleja de la vena (vista)

// Bulto de piel sobre una vena: lomo redondo y falda larga y suave (la piel no se dobla en angulo). x: 0 eje, 1 fin.
float perfil(float x) {
	float t = clamp(1.0 - x * x, 0.0, 1.0);
	return t * t * t;
}

// Pulso doble del corazon (lub-dub), 0..1.
float pulso(float t) {
	float f = fract(t * 1.15);
	return exp(-pow(f * 13.0, 2.0)) + 0.6 * exp(-pow((f - 0.2) * 13.0, 2.0));
}

void vertex() {
	bool del_poder = COLOR.a > 0.5;
	float crec = del_poder ? crecimiento : crecimiento_otro;
	float detras = 1.0 - smoothstep(crec - 0.08, crec, COLOR.g);   // 1 donde ya llego el poder
	v_tam = mix(venas_base, 1.0, detras * step(0.001, crec));
	v_encendido = detras * step(0.001, crec) * (del_poder ? brillo : brillo_otro);
	v_frente = exp(-pow((COLOR.g - crec) * 14.0, 2.0)) * step(0.001, crec);
	// Alto y ancho crecen con el tamaño; el ancho menos (por debajo de ~60 % la malla no tiene vertices para dibujarlo).
	float ancho = grosor * (0.6 + 0.4 * v_tam);
	float h = altura * 1.6 * COLOR.b * v_tam * (1.0 + latido * pulso(TIME));
	VERTEX += NORMAL * (h * perfil(COLOR.r * 1.5 / ancho) / unidad);
	v_campo = COLOR.r * 1.5 / ancho;
	v_r = COLOR.r;
	v_g = COLOR.g;
	v_h = h;
	v_ancho = 2.0 * UV2.x * unidad * ancho;
	v_aleja = normalize((MODELVIEW_MATRIX * vec4(TANGENT, 0.0)).xyz);
	// Solo en perspectiva (la camara): las sombras del sol se dibujan en ortografica y no se tocan.
	if (fov_manos > 0.0 && PROJECTION_MATRIX[3][3] < 0.5) {
		// Solo cambia la escala; el signo se conserva (Godot invierte la Y en la proyeccion).
		float f = 1.0 / tan(radians(fov_manos) * 0.5);
		float aspecto = abs(PROJECTION_MATRIX[1][1] / PROJECTION_MATRIX[0][0]);
		PROJECTION_MATRIX[1][1] = f * sign(PROJECTION_MATRIX[1][1]);
		PROJECTION_MATRIX[0][0] = f / aspecto * sign(PROJECTION_MATRIX[0][0]);
	}
}

void fragment() {
	vec3 piel = texture(textura, UV).rgb;
	float x = v_campo;
	float nucleo = x < 1.0 ? perfil(x) : 0.0;
	ALBEDO = mix(piel, piel * vec3(0.82, 0.8, 0.72), nucleo * 0.35 * v_tam);   // el oro apagado oscurece un poco la piel
	ROUGHNESS = rugosidad;
	if (x < 1.0 && v_ancho > 0.0) {
		// Pendiente del bulto (dh/dd): inclina la normal hacia fuera del eje, asi la luz rasante marca el relieve.
		float t = 1.0 - x * x;
		float pendiente = v_h * (-6.0 * x * t * t) / v_ancho;
		NORMAL = normalize(NORMAL - pendiente * v_aleja);
		ROUGHNESS = mix(rugosidad, rugosidad * 0.75, nucleo);   // la piel tensa sobre la vena brilla un poco mas
	}
	// El oro bajo la piel: nucleo dorado y un halo algo mas ancho y mas rojo (la luz que atraviesa la carne), que muere a
	// 3 semianchos del eje (v_r = 1).
	float halo = perfil(v_r);
	vec3 oro = color_oro * nucleo * nucleo + color_oro * vec3(1.0, 0.45, 0.25) * halo * 0.18;
	float flujo = 0.75 + 0.25 * sin(v_g * 70.0 - TIME * 10.0);   // pulsos de oro que corren hacia el codo
	float encendido = luz_reposo * (1.0 + 0.6 * pulso(TIME)) * v_tam + 0.6 * v_encendido * flujo + v_frente;
	EMISSION = oro * encendido * luz;
}
"""

static var _shader: Shader


static func material(textura: Texture2D, unidad: float) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("textura", textura)
	m.set_shader_parameter("unidad", unidad)
	return m
