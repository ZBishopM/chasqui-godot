class_name Cordillera
extends MeshInstance3D
## El fondo que invita a explorar: un anillo de cordillera de 22 a 38 km de la plaza, mas alla del relieve real
## (Terreno, que acaba a ~19 km). Por delante, picos en pan de azucar como el Huayna Picchu; detras, nevados de 5000 a
## 6000 m sobre el mar con nieve y glaciares. Al ser geometria real a distintas distancias, al moverse da paralaje; la
## niebla de Sky3D la azula con la distancia. El sol del Inti Raymi sale por detras de los nevados del ENE.
## Malla polar (angulo x radio) levantada en la CPU con ruido de crestas; es una sola pieza de pocos miles de vertices.

const R0 := 21000.0          # m: borde de dentro (bajo el horizonte del relieve real)
const R1 := 38500.0          # m: borde de fuera (cerca del far de la camara)
const ANGULOS := 360
const RADIOS := 28
const ACIMUT_SOL := 65.8     # los nevados mas altos, detras de la salida del sol

const SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 color_roca : source_color = vec3(0.42, 0.38, 0.34);
uniform vec3 color_puna : source_color = vec3(0.55, 0.48, 0.33);
uniform vec3 color_nieve : source_color = vec3(0.93, 0.95, 1.0);
uniform float cota_nieve = 2150.0;   // m sobre la plaza (3482 m): la nieve empieza hacia los 5600 m (solo las cumbres)
varying vec3 v_pos;
varying vec3 v_nor;

float azar(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	v_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_nor = NORMAL;
}

void fragment() {
	float pend = 1.0 - v_nor.y;
	float vetas = azar(floor(v_pos.xz / 180.0)) * 300.0;
	float nieve = smoothstep(cota_nieve - 250.0 + vetas, cota_nieve + 250.0 + vetas, v_pos.y) * (1.0 - smoothstep(0.45, 0.7, pend));
	vec3 base = mix(color_puna, color_roca, smoothstep(0.15, 0.4, pend) + smoothstep(600.0, 1400.0, v_pos.y) * 0.6);
	ALBEDO = mix(base, color_nieve, nieve);
	ROUGHNESS = mix(0.95, 0.5, nieve);
}
"""


func _ready() -> void:
	var ruido := FastNoiseLite.new()
	ruido.seed = 1532
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ruido.fractal_octaves = 5
	ruido.frequency = 1.0 / 9000.0
	var picos := FastNoiseLite.new()
	picos.seed = 99
	picos.frequency = 1.0 / 2500.0
	var alturas := PackedFloat32Array()
	var pos := PackedVector3Array()
	for j in RADIOS + 1:
		var f := float(j) / RADIOS
		var r := lerpf(R0, R1, f)
		for i in ANGULOS:
			var a := TAU * i / ANGULOS
			var dir := Vector2(sin(a), -cos(a))   # a = acimut desde el norte (-z), hacia el este (+x)
			var p := dir * r
			# Envolvente: sube desde debajo del horizonte, cumbres a media distancia, baja algo al fondo.
			var env := smoothstep(0.0, 0.35, f) * (1.0 - 0.35 * smoothstep(0.75, 1.0, f))
			# Crestas desiguales: la mayoria se queda en puna y roca; solo algunas pasan la cota de nieve.
			var cresta := pow(ruido.get_noise_2d(p.x, p.y) * 0.5 + 0.5, 1.7)
			var alto := -900.0 + env * (900.0 + 900.0 + 2900.0 * cresta)
			# Mas altos detras del amanecer (ENE) y hacia el norte.
			var hacia_sol := cos(a - deg_to_rad(ACIMUT_SOL))
			alto += env * 700.0 * maxf(hacia_sol, 0.0)
			# Delante, algunos panes de azucar (Huayna Picchu): conos empinados donde el ruido de picos es alto.
			var pan := smoothstep(0.55, 0.85, picos.get_noise_2d(p.x, p.y) * 0.5 + 0.5) * (1.0 - smoothstep(0.1, 0.3, f)) * smoothstep(0.0, 0.08, f)
			alto += pan * 1300.0
			alturas.append(alto)
			pos.append(Vector3(p.x, alto, p.y))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in RADIOS + 1:
		for i in ANGULOS:
			st.add_vertex(pos[j * ANGULOS + i])
	for j in RADIOS:
		for i in ANGULOS:
			var a := j * ANGULOS + i
			var b := j * ANGULOS + (i + 1) % ANGULOS
			var c := (j + 1) * ANGULOS + i
			var d := (j + 1) * ANGULOS + (i + 1) % ANGULOS
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	st.generate_normals()
	mesh = st.commit()
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-R1, -2000.0, -R1), Vector3(R1 * 2.0, 8000.0, R1 * 2.0))
