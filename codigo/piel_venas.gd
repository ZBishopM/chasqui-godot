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
## Se tocan en vivo: altura (m), grosor (1 = Caos bajo; ~1,5 = Caos alto), luz, luz_reposo, latido, color_oro (el oro
## sucio de la vena), color_pepita, pepitas y pepitas_escala (las pepitas de oro en bruto), infeccion, coagulos y
## color_coagulo (la vena negra y los coagulos rojos).

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
// Oro en bruto: la vena es oro sucio (ocre, apagado) con pepitas de oro mas puro que destellan. Antes era un amarillo
// limpio que en el pico se lavaba casi a blanco.
uniform vec3 color_oro : source_color = vec3(0.62, 0.40, 0.11);
uniform vec3 color_pepita : source_color = vec3(1.0, 0.80, 0.38);
uniform float pepitas = 1.0;           // cuanto brillan las pepitas (0 = sin pepitas)
uniform float pepitas_escala = 260.0;  // pepitas por unidad de UV (mas = mas pequenas)
// Infeccion dentro del oro, como lava viva: costras negras con el borde al rojo que flotan sobre el oro encendido y
// coagulos rojos que se forman y se deshacen. Con el oro en reposo no se ven.
uniform float infeccion = 1.0;         // 0 = oro limpio
uniform vec3 color_coagulo : source_color = vec3(0.62, 0.05, 0.03);
uniform float coagulos = 1.0;          // 0 = sin coagulos
uniform float luz = 1.15;              // energia del oro encendido
uniform float luz_reposo = 0.08;       // fraccion de luz que conserva el oro en reposo
uniform float latido = 0.12;           // cuanto late la vena (altura) con el pulso
uniform float rugosidad = 0.62;
// FOV propio de las manos (viewmodel FOV), en grados verticales; 0 = el de la camara. Asi el FOV del mundo puede abrirse
// (esprint, patada del Halcon) sin que los antebrazos, tan cerca de la camara, se estiren hacia los bordes.
uniform float fov_manos = 0.0;
// Sangre en las venas (cinematica del despertar en la fosa): antes del oro las venas se llenan de la sangre de los
// muertos, oscuras e hinchadas. El frente del poder (crecimiento) la vuelve oro desde los nudillos.
uniform float sangre = 0.0;
uniform vec3 color_sangre : source_color = vec3(0.30, 0.025, 0.03);

varying float v_campo;   // distancia al eje / alcance del bulto (1 = fin del bulto)
varying float v_r;       // distancia al eje de la vena / (3 * semiancho): 1 = lejos de toda vena
varying float v_h;       // m: altura en este tramo
varying float v_ancho;   // m: hasta donde llega el bulto
varying float v_tam;     // tamaño 0..1 en este punto (reposo -> 1 por detras del frente)
varying float v_encendido;
varying float v_frente;
varying float v_g;       // coordenada de crecimiento (0 nudillos .. 1 codo)
varying vec3 v_aleja;    // direccion en la piel que se aleja de la vena (vista)
varying float v_sangre;  // sangre que queda en este punto (por delante del frente de oro)

// Bulto de piel sobre una vena: lomo redondo y falda larga y suave (la piel no se dobla en angulo). x: 0 eje, 1 fin.
float perfil(float x) {
	float t = clamp(1.0 - x * x, 0.0, 1.0);
	return t * t * t;
}

float azar(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Ruido de valor suave, 0..1.
float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(azar(i), azar(i + vec2(1.0, 0.0)), f.x), mix(azar(i + vec2(0.0, 1.0)), azar(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Tres octavas giradas entre si: las manchas salen organicas y no cuadradas (el ruido de valor solo deja ver su rejilla).
float manchas(vec2 p) {
	mat2 giro = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	float s = ruido(p) * 0.55;
	p = giro * p * 2.1 + 7.3;
	s += ruido(p) * 0.3;
	p = giro * p * 2.3 + 3.1;
	return s + ruido(p) * 0.15;
}

// Pulso doble del corazon (lub-dub), 0..1. Cuadrados a mano: pow() con base negativa no esta definido en GLSL y en
// algunas GPU da NaN (la malla desaparecia ~0,17 s en cada latido).
float pulso(float t) {
	float f = fract(t * 1.15);
	float a = f * 13.0;
	float b = (f - 0.2) * 13.0;
	return exp(-a * a) + 0.6 * exp(-b * b);
}

void vertex() {
	bool del_poder = COLOR.a > 0.5;
	float crec = del_poder ? crecimiento : crecimiento_otro;
	float detras = 1.0 - smoothstep(crec - 0.08, crec, COLOR.g);   // 1 donde ya llego el poder
	v_tam = mix(venas_base, 1.0, detras * step(0.001, crec));
	v_encendido = detras * step(0.001, crec) * (del_poder ? brillo : brillo_otro);
	float df = (COLOR.g - crec) * 14.0;   // sin pow(): la base es negativa detras del frente
	v_frente = exp(-df * df) * step(0.001, crec);
	v_sangre = sangre * (1.0 - detras * step(0.001, crec));
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
	// Pepitas: manchas de ruido de valor en las UV (pegadas a la piel, no resbalan al mover el brazo), solo en el nucleo,
	// de dos tamanos, que titilan un poco.
	float n = ruido(UV * pepitas_escala) * 0.7 + ruido(UV * pepitas_escala * 2.3 + 17.0) * 0.3;
	float pepita = smoothstep(0.66, 0.86, n) * smoothstep(0.25, 0.7, nucleo) * pepitas;
	pepita *= 0.85 + 0.15 * sin(TIME * 2.3 + n * 40.0);
	float flujo = 0.75 + 0.25 * sin(v_g * 70.0 - TIME * 10.0);   // pulsos de oro que corren hacia el codo
	float encendido = luz_reposo * (1.0 + 0.6 * pulso(TIME)) * v_tam + 0.6 * v_encendido * flujo + v_frente;
	float vivo = smoothstep(0.08, 0.6, encendido);   // 0 con el oro en reposo, 1 con el oro encendido
	// Infeccion, dentro del oro como lava viva: costras negras que flotan sobre el oro (derivan y se deforman despacio) con
	// el borde al rojo, y coagulos rojos que se forman y se deshacen. Solo existe donde arde el oro: en reposo no se ve.
	vec2 deriva = vec2(TIME * 0.11, -TIME * 0.06);
	float ni = manchas(UV * pepitas_escala * 0.3 + 91.0 + deriva + 0.6 * vec2(sin(TIME * 0.4), cos(TIME * 0.3)));
	float en_vena = smoothstep(0.1, 0.5, nucleo);
	float negro = smoothstep(0.55, 0.64, ni) * en_vena * infeccion;
	float borde = (smoothstep(0.49, 0.55, ni) - smoothstep(0.55, 0.62, ni)) * en_vena * infeccion;
	float nc = manchas(UV * pepitas_escala * 0.4 + 251.0 - deriva * 0.7);
	float vive = smoothstep(0.2, 0.8, 0.5 + 0.5 * sin(TIME * 0.35 + nc * 25.0));
	float coagulo = smoothstep(0.56, 0.66, nc) * en_vena * vive * coagulos * (1.0 - negro);
	pepita *= 1.0 - negro;
	vec3 oro = (color_oro * nucleo * nucleo + color_oro * vec3(1.0, 0.45, 0.25) * halo * 0.18) * (1.0 - negro * 0.95)
			+ color_pepita * (pepita * 1.6 + borde * 0.9) + color_coagulo * coagulo * 1.4;
	ALBEDO = mix(ALBEDO, ALBEDO * vec3(1.05, 0.92, 0.7), pepita * 0.6 * v_tam);   // la pepita tine la piel aun apagada
	// Con el oro encendido la costra y el coagulo tinen la piel de encima, al mismo nivel que el oro.
	ALBEDO = mix(ALBEDO, vec3(0.05, 0.03, 0.035), negro * 0.7 * vivo);
	ALBEDO = mix(ALBEDO, color_coagulo * 0.55, coagulo * 0.5 * vivo);
	// La sangre: la vena hinchada se ve granate bajo la piel (sin luz propia, apenas un rescoldo); donde paso el frente
	// ya es oro.
	ALBEDO = mix(ALBEDO, mix(ALBEDO, color_sangre, nucleo * 0.85 + halo * 0.2), v_sangre * smoothstep(0.05, 0.3, v_tam));
	ROUGHNESS = mix(ROUGHNESS, 0.35, v_sangre * nucleo);
	EMISSION = mix(oro * encendido * luz, color_sangre * nucleo * 0.25, v_sangre);
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
