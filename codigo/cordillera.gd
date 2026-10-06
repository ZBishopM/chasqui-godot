class_name Cordillera
extends MeshInstance3D
## El fondo que invita a explorar: un anillo de cordillera de 21 a 38,5 km de la plaza, mas alla del relieve real
## (Terreno, que acaba a ~19 km). Las alturas se piensan en metros sobre el mar (msnm) y se pasan al mundo con la misma
## exageracion que el relieve lejano (x2,6), asi la nieve y los pisos ecologicos (biomas_andinos.gdshaderinc) siguen
## las cotas reales: la mayoria son cordones de puna y roca de 4000 a 4800 m, sin nieve, y solo los macizos que pasan
## de ~5000 m llevan nieve y glaciares. Los macizos estan en sus rumbos reales desde Vilcashuaman (mas cerca de lo que
## estan de verdad, para que se vean): el sol del Inti Raymi sale tras el hombro del Pumasillo (Vilcabamba).
## Malla polar (angulo x radio) levantada en la CPU; una sola pieza, sin sombras.

const R0 := 21000.0          # m: borde de dentro (bajo el horizonte del relieve real)
const R1 := 38500.0          # m: borde de fuera (cerca del far de la camara)
const ANGULOS := 1440
const RADIOS := 56
const EXAGERACION := 2.6     # la de herramientas/hornear_relieve.gd lejos
const PLAZA_MSNM := 3482.0
const ACIMUT_PUESTA := 293.0 # brecha: ahi se pone el sol del 21 de junio, en el abra del relieve (ABRAS de hornear_relieve)

## Macizos nevados reales: [nombre, acimut (grados), f (0 delante .. 1 al fondo del anillo), picos o volcan].
## picos: [[desvio en grados del acimut, msnm, radio de la base en m], ...]; volcan: ["volcan", msnm, radio m].
const MACIZOS := [
	["Vilcabamba", 72.0, 0.55, [[-2.0, 5991.0, 3300.0], [5.0, 6271.0, 3900.0], [-6.5, 5450.0, 2300.0], [1.6, 5620.0, 2400.0],
		[9.0, 5380.0, 2100.0], [-4.2, 5240.0, 1800.0], [11.5, 5050.0, 1900.0]]],   # Pumasillo 5991, Salkantay 6271
	["Ampay", 86.0, 0.35, [[0.0, 5235.0, 2700.0], [2.4, 4990.0, 1700.0], [-2.0, 4850.0, 1500.0]]],
	["Ccarhuarazo", 165.0, 0.4, ["volcan", 5112.0, 7500.0]],
	["Solimana", 149.0, 0.9, ["volcan", 6093.0, 9500.0]],
	["Rasuwillka", 350.0, 0.45, [[0.0, 4954.0, 2300.0], [-2.6, 4830.0, 1600.0], [2.1, 4880.0, 1800.0]]],
]

const SHADER := """
shader_type spatial;
render_mode cull_disabled;

#include "res://codigo/biomas_andinos.gdshaderinc"

uniform vec3 color_lejania : source_color = vec3(0.42, 0.50, 0.62);   // el aire azula lo lejano

varying vec3 v_pos;
varying vec3 v_nor;
varying float v_conc;
varying float v_seco;

// Relieve fino (canaletas y costillas de unos cientos de metros): perturba la normal, asi las caras no se ven planas.
float detalle(vec2 p) {
	float c = 1.0 - abs(bio_ruido(p / 520.0) * 2.0 - 1.0);   // crestas
	return c * c * 70.0 + bio_fbm(p / 210.0) * 30.0;
}

void vertex() {
	v_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_nor = NORMAL;
	v_conc = COLOR.r;
	v_seco = COLOR.g;
}

void fragment() {
	vec2 p = v_pos.xz;
	float e = 60.0;
	vec2 g = vec2(detalle(p + vec2(e, 0.0)) - detalle(p - vec2(e, 0.0)), detalle(p + vec2(0.0, e)) - detalle(p - vec2(0.0, e))) / (2.0 * e);
	vec3 n = normalize(normalize(v_nor) - vec3(g.x, 0.0, g.y) * 1.4);
	float m = BIO_PLAZA_MSNM + v_pos.y / 2.6;
	vec4 s = bio_suelo(m, n, v_conc, bio_fbm(p / 2600.0), bio_ruido(p / 300.0), v_seco, 1.8);
	float d = length(p - CAMERA_POSITION_WORLD.xz);
	ALBEDO = mix(s.rgb, color_lejania * (0.6 + 0.4 * dot(s.rgb, vec3(0.33))), smoothstep(15000.0, 42000.0, d) * 0.3);
	ROUGHNESS = s.a;
	SPECULAR = 0.08 + 0.25 * step(s.a, 0.7);   // la roca y el pasto no brillan; la nieve y el hielo un poco
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
}
"""


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var crestas := FastNoiseLite.new()
	crestas.seed = 1532
	crestas.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	crestas.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	crestas.fractal_octaves = 4
	crestas.frequency = 1.0 / 9000.0
	crestas.domain_warp_enabled = true
	crestas.domain_warp_amplitude = 2600.0
	crestas.domain_warp_frequency = 1.0 / 14000.0
	var medias := FastNoiseLite.new()
	medias.seed = 77
	medias.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	medias.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	medias.fractal_octaves = 3
	medias.frequency = 1.0 / 2800.0
	var finas := FastNoiseLite.new()
	finas.seed = 5
	finas.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	finas.fractal_octaves = 2
	finas.frequency = 1.0 / 800.0
	var picos := FastNoiseLite.new()
	picos.seed = 99
	picos.frequency = 1.0 / 2500.0

	# Alturas en msnm sobre la rejilla polar.
	var msnm := PackedFloat32Array()
	msnm.resize((RADIOS + 1) * ANGULOS)
	var puntos := []   # por macizo: [Vector2 centro, msnm, radio, es_volcan, giro]
	for mz: Array in MACIZOS:
		var r_c := lerpf(R0, R1, mz[2])
		var lista: Array = mz[3]
		if lista.size() > 0 and lista[0] is String:
			var a := deg_to_rad(mz[1])
			puntos.append([Vector2(sin(a), -cos(a)) * r_c, lista[1], lista[2], true, 0.0])
		else:
			for k in lista.size():
				var pk: Array = lista[k]
				var a := deg_to_rad(mz[1] + pk[0])
				# Los picos se escalonan un poco hacia delante y hacia atras.
				var r_k := r_c + (fmod(k * 0.618, 1.0) - 0.5) * 3000.0
				puntos.append([Vector2(sin(a), -cos(a)) * r_k, pk[1], pk[2], false, k * 0.7 + 0.3])
	for j in RADIOS + 1:
		var f := float(j) / RADIOS
		var r := lerpf(R0, R1, f)
		for i in ANGULOS:
			var a := TAU * i / ANGULOS
			var p := Vector2(sin(a), -cos(a)) * r   # a = acimut desde el norte (-z), hacia el este (+x)
			# Cordones de fondo: crestas deformadas en tres escalas, de 4000 a ~4850 m; sube desde bajo el horizonte.
			var c := clampf(0.62 * (crestas.get_noise_2d(p.x, p.y) * 0.5 + 0.5) + 0.26 * (medias.get_noise_2d(p.x, p.y) * 0.5 + 0.5) + 0.12 * (finas.get_noise_2d(p.x, p.y) * 0.5 + 0.5), 0.0, 1.0)
			var cordon := 3950.0 + 900.0 * pow(c, 1.3) - 250.0 * smoothstep(0.8, 1.0, f)
			var h := lerpf(3000.0, cordon, smoothstep(0.0, 0.3, f))
			# Delante, algunos panes de azucar (conos empinados de roca y quenual, sin nieve).
			var pan := smoothstep(0.55, 0.85, picos.get_noise_2d(p.x, p.y) * 0.5 + 0.5) * (1.0 - smoothstep(0.1, 0.3, f)) * smoothstep(0.0, 0.08, f)
			h += pan * 650.0
			# Macizos: el cuerpo los levanta hacia ~4600 m (superpuna, bajo la nieve) y cada pico es una piramide de aristas (o un cono volcanico).
			for pt: Array in puntos:
				var d: Vector2 = p - (pt[0] as Vector2)
				var radio: float = pt[2]
				var dl := d.length()
				if dl > radio * 2.6:
					continue
				var cima: float = pt[1]
				if pt[3]:
					# Volcan: cono ancho de laderas concavas, la cima achatada con un crater poco hondo.
					var k := clampf(dl / radio, 0.0, 1.0)
					var cono := cima - (cima - 4300.0) * pow(k, 0.75) - 60.0 * (1.0 - smoothstep(0.0, 0.08, k))
					h = maxf(h, lerpf(h, cono, 1.0 - smoothstep(0.9, 1.0, k)))
				else:
					var giro: float = pt[4]
					var u := d.rotated(giro)
					# Distancia en rombo: cuatro caras con aristas en los ejes (piramide de cumbre alpina).
					var dr := (absf(u.x) + absf(u.y)) * 0.72 + maxf(absf(u.x), absf(u.y)) * 0.28
					var k := dr / radio
					var pico := cima - (cima - 4450.0) * pow(k, 0.85)
					pico += (finas.get_noise_2d(p.x * 2.0, p.y * 2.0)) * 90.0 * (1.0 - clampf(k, 0.0, 1.0))
					var cuerpo := lerpf(h, maxf(h, 4600.0 + (finas.get_noise_2d(p.x, p.y) * 120.0)), exp(-pow(dl / (radio * 1.9), 2.0)))
					h = maxf(cuerpo, pico if k < 1.6 else -INF)
			# Brecha hacia la puesta: sin ella los picos esconden el sol antes de que llegue al abra.
			var brecha := exp(-pow(angle_difference(a, deg_to_rad(ACIMUT_PUESTA)) / deg_to_rad(7.0), 2.0))
			h = lerpf(h, minf(h, 3700.0 + (h - 3700.0) * 0.15), brecha)
			msnm[j * ANGULOS + i] = h

	# Posiciones, concavidad (quebradas y circos: donde los vecinos estan mas altos) y vertiente seca (oeste).
	var pos := PackedVector3Array()
	var colores := PackedColorArray()
	pos.resize(msnm.size())
	colores.resize(msnm.size())
	for j in RADIOS + 1:
		var r := lerpf(R0, R1, float(j) / RADIOS)
		for i in ANGULOS:
			var a := TAU * i / ANGULOS
			var h := msnm[j * ANGULOS + i]
			pos[j * ANGULOS + i] = Vector3(sin(a) * r, (h - PLAZA_MSNM) * EXAGERACION, -cos(a) * r)
			var vecinos := msnm[j * ANGULOS + (i + 1) % ANGULOS] + msnm[j * ANGULOS + (i + ANGULOS - 1) % ANGULOS] \
				+ msnm[mini(j + 1, RADIOS) * ANGULOS + i] + msnm[maxi(j - 1, 0) * ANGULOS + i]
			var conc := clampf((vecinos * 0.25 - h) / 45.0, 0.0, 1.0)
			var seco := smoothstep(0.0, 0.6, cos(a - deg_to_rad(270.0)))
			colores[j * ANGULOS + i] = Color(conc, seco, 0.0)
	# Normales de la rejilla (diferencias centrales).
	var normales := PackedVector3Array()
	normales.resize(pos.size())
	for j in RADIOS + 1:
		for i in ANGULOS:
			var t := pos[j * ANGULOS + (i + 1) % ANGULOS] - pos[j * ANGULOS + (i + ANGULOS - 1) % ANGULOS]
			var rr := pos[mini(j + 1, RADIOS) * ANGULOS + i] - pos[maxi(j - 1, 0) * ANGULOS + i]
			var n := rr.cross(t).normalized()
			normales[j * ANGULOS + i] = n if n.y >= 0.0 else -n
	var indices := PackedInt32Array()
	indices.resize(RADIOS * ANGULOS * 6)
	var w := 0
	for j in RADIOS:
		for i in ANGULOS:
			var a := j * ANGULOS + i
			var b := j * ANGULOS + (i + 1) % ANGULOS
			var c := (j + 1) * ANGULOS + i
			var d := (j + 1) * ANGULOS + (i + 1) % ANGULOS
			indices[w] = a; indices[w + 1] = c; indices[w + 2] = b
			indices[w + 3] = b; indices[w + 4] = c; indices[w + 5] = d
			w += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = normales
	arr[Mesh.ARRAY_COLOR] = colores
	arr[Mesh.ARRAY_INDEX] = indices
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh = malla
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-R1, -4000.0, -R1), Vector3(R1 * 2.0, 12000.0, R1 * 2.0))
	print("cordillera: %d vertices, %d ms" % [pos.size(), Time.get_ticks_msec() - t0])
