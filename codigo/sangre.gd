class_name HiloSangre
extends MeshInstance3D
## Un hilo de sangre que repta (cinematica del despertar en la fosa): un tubo fino a lo largo de un recorrido, del que el
## shader solo dibuja el tramo entre `avance - largo` y `avance` (fracciones del recorrido). Avanzando `avance` de 0 a
## 1 + largo el hilo sale del cuerpo, cruza el monton ondulando como una culebra, sube por el aire hasta la muneca y entra
## en ella hasta desaparecer.

const SHADER := """
shader_type spatial;

uniform float avance = 0.0;
uniform float largo = 0.3;
uniform vec3 color_sangre : source_color = vec3(0.26, 0.012, 0.016);
varying float v_s;

void vertex() {
	v_s = UV.x;
	// Fino en la punta y en la cola (el radio de cada anillo va en UV2.x); por dentro corren abultamientos hacia la mano.
	float k = smoothstep(avance, avance - 0.025, v_s) * smoothstep(avance - largo, avance - largo + 0.12, v_s);
	VERTEX -= NORMAL * UV2.x * (1.0 - k);
	VERTEX += NORMAL * UV2.x * 0.3 * sin(v_s * 140.0 - TIME * 16.0) * k;
}

void fragment() {
	if (v_s > avance || v_s < avance - largo) {
		discard;
	}
	// Sangre fresca: muy oscura y brillante (los rayos la hacen relucir), con un rescoldo rojo que corre hacia la mano y
	// la deja leer de noche entre fogonazos (no es sangre cualquiera: la llama Inti).
	ALBEDO = color_sangre;
	ROUGHNESS = 0.12;
	SPECULAR = 0.7;
	EMISSION = vec3(0.5, 0.025, 0.02) * (0.2 + 0.08 * sin(v_s * 60.0 - TIME * 9.0));
}
"""
const LADOS := 7
const PASO := 0.03   # m entre anillos

static var _shader: Shader

var largo_m := 1.2   # m de hilo visible
var recorrido := 0.0  # m del recorrido entero
var fin := Vector3.ZERO   # donde entra (la muneca)
var _mat: ShaderMaterial


## Arma el tubo por los puntos `puntos` (se suavizan) con radio `radio` m.
func armar(puntos: PackedVector3Array, radio := 0.012) -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var curva := Curve3D.new()
	curva.bake_interval = PASO
	for i in puntos.size():
		# Catmull-Rom como Bezier: tangentes de los vecinos.
		var antes := puntos[maxi(i - 1, 0)]
		var despues := puntos[mini(i + 1, puntos.size() - 1)]
		var t := (despues - antes) / 6.0
		curva.add_point(puntos[i], -t, t)
	var pts := curva.get_baked_points()
	fin = puntos[puntos.size() - 1]
	recorrido = curva.get_baked_length()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal := Vector3.UP
	var largo_acum := 0.0
	for i in pts.size():
		var tg := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		if i > 0:
			largo_acum += pts[i].distance_to(pts[i - 1])
		# Marco que se transporta a lo largo del hilo (no gira de golpe donde sube por el aire).
		normal = (normal - tg * normal.dot(tg)).normalized()
		if normal.length() < 0.5:
			normal = tg.cross(Vector3.RIGHT).normalized()
		var binormal := tg.cross(normal)
		var s := largo_acum / maxf(recorrido, 0.001)
		var r := radio * (0.85 + 0.3 * sin(largo_acum * 23.0))
		for k in LADOS + 1:
			var a := TAU * k / LADOS
			var n := normal * cos(a) + binormal * sin(a)
			st.set_normal(n)
			st.set_uv(Vector2(s, float(k) / LADOS))
			st.set_uv2(Vector2(r, 0.0))
			st.add_vertex(pts[i] + n * r)
	for i in pts.size() - 1:
		for k in LADOS:
			var a := i * (LADOS + 1) + k
			var b := a + LADOS + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(a + 1)
			st.add_index(a + 1)
			st.add_index(b)
			st.add_index(b + 1)
	mesh = st.commit()
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_mat.set_shader_parameter("largo", largo_m / maxf(recorrido, 0.001))
	_mat.set_shader_parameter("avance", 0.0)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## 0..1: de nada (aun en el cuerpo) a todo dentro de la mano.
func poner_avance(p: float) -> void:
	var l := largo_m / maxf(recorrido, 0.001)
	_mat.set_shader_parameter("avance", p * (1.0 + l))


## El recorrido de un hilo: desde `desde` (un cuerpo) por encima del monton, ondulando, hasta debajo de `mano`, y de ahi
## sube por el aire hasta la muneca. Sigue la superficie con rayos hacia abajo (todo lo que choca menos `excluir`).
static func recorrido_por(espacio: PhysicsDirectSpaceState3D, desde: Vector3, mano: Vector3, excluir: Array[RID], semilla: int) -> PackedVector3Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var bajo_mano := Vector3(mano.x, mano.y, mano.z)
	var plano := Vector2(bajo_mano.x - desde.x, bajo_mano.z - desde.z)
	var lado := Vector3(-plano.y, 0.0, plano.x).normalized()
	var n := maxi(ceili(plano.length() / 0.12), 4)
	var fase := rng.randf() * TAU
	var ondas := rng.randf_range(1.5, 3.0)
	var r := PackedVector3Array()
	for i in n + 1:
		var t := float(i) / n
		var p := desde.lerp(bajo_mano, t) + lado * (0.14 * sin(t * TAU * ondas + fase) * sin(PI * t))
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, mano.y + 0.2, p.z), Vector3(p.x, mano.y - 4.0, p.z))
		q.exclude = excluir
		var golpe := espacio.intersect_ray(q)
		if golpe.is_empty():
			continue
		var suelo: Vector3 = golpe.position
		if t > 0.85 and suelo.y > mano.y - 0.35:
			break   # ya bajo la mano
		r.append(suelo + Vector3.UP * 0.012)
	# Del suelo a la muneca: se levanta en vertical y se curva hacia la mano.
	var pie := r[r.size() - 1] if r.size() > 0 else mano + Vector3.DOWN * 0.6
	var alto := mano.y - pie.y
	r.append(pie + Vector3.UP * alto * 0.3 + (mano - pie) * Vector3(0.15, 0.0, 0.15))
	r.append(pie.lerp(mano, 0.65) + Vector3.UP * alto * 0.05)
	r.append(mano + Vector3.DOWN * 0.05)
	r.append(mano)
	return r
