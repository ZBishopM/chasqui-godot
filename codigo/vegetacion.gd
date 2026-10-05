class_name Vegetacion
extends Node3D
## Lo que crece y rueda sobre el Terreno de la zona jugable:
##  - Ichu (la paja de la puna): matas procedurales que la tarjeta grafica coloca en dos rejillas (hasta 55 m) que siguen
##    al jugador; cada mata lee la altura del suelo en el shader (relieve.gdshaderinc) y crece solo donde el terreno pinta
##    hierba (cobertura_ichu). Se mecen con rafagas que cruzan el campo y se apartan al paso del jugador.
##  - Rocas, matorrales y flores (escaneos de Poly Haven, CC0, coleccion Namaqualand: un valle seco como los de Ayacucho),
##    repartidos con reglas de pendiente y manchas, en MultiMesh por trozos de 150 m que se dejan de dibujar de lejos.
## Nada crece en el suelo de obra del pueblo (Terreno.obra).

## Dos anillos de ichu que siguen al jugador: cerca matas densas de 22 hojas; mas lejos, matas de 9 hojas mas separadas
## (con 22 hojas en todo el campo eran 5,3 millones de triangulos). Se funden entre 18 y 25 m.
## [hojas, m entre matas, m donde empieza (fundido de entrada), m donde acaba (fundido de salida)]
const ICHU_ANILLOS := [[22, 0.55, 0.0, 25.0], [9, 0.8, 25.0, 55.0]]
const ICHU_ALTO := Vector2(0.3, 0.8)   # m de alto de las hojas (min, max)
const TROZO := 150.0            # m de lado de cada trozo de reparto

## modelo -> [variantes (nodos del glTF), cantidad en la zona jugable, escala min, max, alcance de dibujo m, regla]
## reglas: "llano" (donde crece ichu, en manchas), "ladera" (pendientes y bordes), "arbol" (grupitos en suelo poco
## inclinado), "cualquiera"
const REPARTO := {
	"flower_gazania": [["flower_gazania_c_LOD0", "flower_gazania_d_LOD0", "flower_gazania_f_LOD0", "flower_gazania_h_LOD0"], 2600, 0.8, 1.3, 110.0, "llano"],
	"flower_ursinia": [["flower_ursinia_a_LOD0", "flower_ursinia_b_LOD0", "flower_ursinia_c_LOD0"], 1800, 0.9, 1.4, 90.0, "llano"],
	"flower_heliophila": [["flower_heliophila_small", "flower_heliophila_medium"], 500, 0.8, 1.2, 90.0, "llano"],
	"wild_rooibos_bush": [["wild_rooibos_bush_a", "wild_rooibos_bush_b", "wild_rooibos_bush_c", "wild_rooibos_bush_d"], 2200, 1.0, 2.2, 260.0, "cualquiera"],
	"namaqualand_stones_01": [["namaqualand_stones_01_b", "namaqualand_stones_01_d", "namaqualand_stones_01_e"], 2500, 1.5, 4.0, 70.0, "cualquiera"],
	# Pesados (200-360 mil triangulos cada uno): pocos, y Godot les genera niveles de detalle al importar.
	"searsia_burchellii": [["searsia_burchellii_small_LOD0", "searsia_burchellii_medium_LOD0", "searsia_burchellii_large_LOD0"], 30, 0.9, 1.3, 1100.0, "arbol"],
	"didelta_spinosa": [["didelta_spinosa_small_LOD0", "didelta_spinosa_medium_LOD0", "didelta_spinosa_large_LOD0"], 60, 0.8, 1.2, 450.0, "cualquiera"],
	"namaqualand_boulder_02": [["boulder_02"], 140, 0.8, 2.6, 900.0, "ladera"],
	"namaqualand_boulder_05": [["namaqualand_boulder_05"], 220, 0.6, 2.2, 700.0, "ladera"],
}

const SHADER_ICHU := """
shader_type spatial;
render_mode cull_disabled;

#include "res://codigo/relieve.gdshaderinc"

uniform vec2 centro;            // jugador (xz): la rejilla le sigue
uniform vec3 jugador;           // para apartar las hojas
uniform int lado = 160;
uniform float paso = 0.75;
uniform vec2 alto = vec2(0.35, 0.75);
uniform float alcance = 55.0;   // m: mas alla las matas se encogen hasta desaparecer
uniform float inicio = 0.0;     // m: mas aca tambien (es el otro anillo)
uniform vec3 color_base : source_color = vec3(0.45, 0.39, 0.24);
uniform vec3 color_punta : source_color = vec3(0.82, 0.73, 0.50);
global uniform float humedad;   // lluvia: la paja mojada se oscurece

varying float v_alto;
varying float v_tono;

void vertex() {
	int id = INSTANCE_ID;
	vec2 celda = floor(centro / paso) + vec2(float(id % lado), float(id / lado)) - float(lado) * 0.5;
	float h1 = azar(celda);
	float h2 = azar(celda + 17.31);
	float h3 = azar(celda + 41.7);
	// Desorden: cada mata se sale de su celda hasta casi una celda entera, y las matas se agrupan en macollas (manchas de
	// ruido que deciden si hay mata y de que tamano), como crece el ichu de verdad.
	vec2 pos = (celda + 0.5 + (vec2(h1, h2) - 0.5) * 1.6) * paso;
	vec3 n = normal_en(pos);
	float d = distance(pos, centro);
	float macolla = smoothstep(0.3, 0.7, fbm(pos / 3.5 + 13.0));
	float tam = cobertura_ichu(pos, n) * (1.0 - smoothstep(alcance * 0.7, alcance, d)) * (0.35 + 0.65 * macolla);
	tam *= inicio > 0.0 ? smoothstep(inicio * 0.7, inicio, d) : 1.0;
	tam *= step(0.25 + 0.35 * azar(celda + 3.3), tam);   // matas sueltas y claros
	float alt = mix(alto.x, alto.y, h3 * 0.6 + macolla * 0.4) * tam;
	// La mata: hojas abiertas en abanico (la malla ya lo trae); se gira y escala por mata.
	float ang = h1 * 6.2831;
	mat2 giro = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang)));
	vec3 v = VERTEX;
	v.xz = giro * v.xz * (0.6 + 0.8 * tam);
	v.y *= alt;
	// Viento: rafagas que cruzan el campo (ruido que avanza con el viento) + temblor de cada hoja.
	float t = UV.y * UV.y;                       // 0 en la base, 1 en la punta
	float rafaga = fbm(pos / 14.0 - viento_dir * TIME * 1.6);
	vec2 empuje = viento_dir * viento_fuerza * (0.15 + 0.55 * rafaga);
	empuje += vec2(sin(TIME * 6.3 + h2 * 40.0), cos(TIME * 5.1 + h1 * 30.0)) * 0.035;
	// El jugador aparta las hojas a menos de 0,9 m.
	vec2 lejos_j = pos + v.xz - jugador.xz;
	float cerca_j = 1.0 - smoothstep(0.3, 0.9, length(lejos_j));
	empuje += normalize(lejos_j + 0.0001) * cerca_j * 0.8;
	v.xz += empuje * t * alt;
	v.y -= length(empuje) * t * alt * 0.35;      // al doblarse, la punta baja
	VERTEX = vec3(pos.x, altura(pos), pos.y) + v;
	// Normal casi vertical: hojas finas a contraluz, sin caras negras.
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.65));
	v_alto = UV.y;
	v_tono = h2;
}

void fragment() {
	vec3 c = mix(color_base, color_punta, smoothstep(0.0, 0.9, v_alto));
	c *= 0.8 + 0.4 * v_tono;
	c *= mix(1.0, 0.72, humedad);
	ALBEDO = c;
	ROUGHNESS = 0.9;
	BACKLIGHT = c * 0.5;                         // la paja deja pasar la luz
	AO = mix(0.55, 1.0, smoothstep(0.0, 0.5, v_alto));   // sombra suave dentro de la mata, sin base negra
	AO_LIGHT_AFFECT = 0.6;
}
"""

var terreno: Terreno
var jugador: Node3D
var _ichu: Array[ShaderMaterial] = []


func _ready() -> void:
	_crear_ichu()
	_repartir()


func _process(_dt: float) -> void:
	if jugador != null:
		var p := jugador.global_position
		for m in _ichu:
			m.set_shader_parameter("centro", Vector2(p.x, p.z))
			m.set_shader_parameter("jugador", p)


## La mata de ichu: `hojas` hojas en abanico, cada una una tira de 3 tramos que se afina hacia la punta y se arquea.
## Con menos hojas, mas anchas, para que la mata lejana tape lo mismo.
func _malla_mata(hojas: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for h in hojas:
		var ang := TAU * h / hojas + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var lado := dir.cross(Vector3.UP)
		var abre := rng.randf_range(0.1, 0.5)        # cuanto se abre hacia fuera
		var largo := rng.randf_range(0.55, 1.0)
		var ancho := 0.018 * sqrt(22.0 / hojas)
		var base := dir * rng.randf_range(0.0, 0.09)
		var tramos := 3
		var prev_i: Vector3
		var prev_d: Vector3
		for k in tramos + 1:
			var t := float(k) / tramos
			var centro_h := base + dir * abre * t * t * largo + Vector3.UP * t * largo
			var a := ancho * (1.0 - t * 0.9)
			var vi := centro_h - lado * a
			var vd := centro_h + lado * a
			if k > 0:
				var t0 := float(k - 1) / tramos
				for tri in [[prev_i, t0], [vi, t], [prev_d, t0], [prev_d, t0], [vi, t], [vd, t]]:
					st.set_uv(Vector2(0.0, tri[1]))
					st.set_normal(-dir)
					st.add_vertex(tri[0])
			prev_i = vi
			prev_d = vd
	return st.commit()


func _crear_ichu() -> void:
	var sh := Shader.new()
	sh.code = SHADER_ICHU
	for a: Array in ICHU_ANILLOS:
		var lado := int(ceil(2.0 * a[3] / a[1]))
		var mat := ShaderMaterial.new()
		mat.shader = sh
		terreno.configurar(mat)
		mat.set_shader_parameter("lado", lado)
		mat.set_shader_parameter("paso", a[1])
		mat.set_shader_parameter("inicio", a[2])
		mat.set_shader_parameter("alcance", a[3])
		mat.set_shader_parameter("alto", ICHU_ALTO)
		_ichu.append(mat)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _malla_mata(a[0])
		mm.instance_count = lado * lado
		for i in mm.instance_count:   # nacen con transformacion cero (escala 0): identidad, y el shader las coloca
			mm.set_instance_transform(i, Transform3D.IDENTITY)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.custom_aabb = AABB(Vector3(-1e5, -1e4, -1e5), Vector3(2e5, 2e4, 2e5))   # siempre visible: se mueve en el shader
		add_child(mmi)


## Reparte los modelos de REPARTO por la zona jugable (determinista) en trozos de TROZO m.
func _repartir() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1532
	var manchas := FastNoiseLite.new()
	manchas.seed = 99
	manchas.frequency = 1.0 / 40.0
	var lado := 1200.0 - 40.0   # sin los muros del borde
	for modelo: String in REPARTO:
		var r: Array = REPARTO[modelo]
		var escena: Node3D = (load("res://assets/plantas/%s/%s.gltf" % [modelo, modelo]) as PackedScene).instantiate()
		var mallas: Array[Mesh] = []
		var ajustes: Array[Transform3D] = []
		for nombre: String in r[0]:
			var mi := escena.find_child(nombre, true, false) as MeshInstance3D
			mallas.append(mi.mesh)
			# El escaneo trae la pieza desplazada en el conjunto: se recentra en su base.
			var caja := mi.mesh.get_aabb()
			ajustes.append(Transform3D(Basis(), -Vector3(caja.get_center().x, caja.position.y, caja.get_center().z)))
		escena.free()
		# trozo -> variante -> transformaciones
		var por_trozo := {}
		var puestas := 0
		var intentos := 0
		while puestas < int(r[1]) and intentos < int(r[1]) * 30:
			intentos += 1
			var x := rng.randf_range(-lado * 0.5, lado * 0.5)
			var z := rng.randf_range(-lado * 0.5, lado * 0.5)
			if terreno.obra(x, z) > 0.05:   # nada dentro del pueblo
				continue
			var n := terreno.normal(x, z)
			var pend := 1.0 - n.y
			var mancha := manchas.get_noise_2d(x + modelo.length() * 97.0, z) * 0.5 + 0.5
			var vale := true
			match r[5]:
				"llano":
					vale = pend < 0.12 and rng.randf() < smoothstep(0.55, 0.8, mancha)
				"ladera":
					vale = pend > 0.08 and rng.randf() < smoothstep(0.08, 0.3, pend) + 0.15
				"arbol":   # arboles sueltos o en grupitos, en suelo poco inclinado
					vale = pend < 0.2 and rng.randf() < smoothstep(0.6, 0.85, mancha)
				_:
					vale = pend < 0.35 and rng.randf() < 0.3 + mancha * 0.7
			if not vale:
				continue
			var var_i := rng.randi() % mallas.size()
			var esc := rng.randf_range(r[2], r[3])
			var arriba := Vector3.UP.lerp(n, 0.6).normalized() if r[5] != "llano" else Vector3.UP
			var b := Basis(Quaternion(Vector3.UP, arriba)) * Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * esc)
			var y := terreno.altura(x, z) - (0.15 * esc if r[5] == "ladera" else 0.0)   # las rocas, un poco enterradas
			var t := Transform3D(b, Vector3(x, y, z)) * ajustes[var_i]
			var clave := Vector2i(int(floor((x + lado * 0.5) / TROZO)), int(floor((z + lado * 0.5) / TROZO)))
			if not por_trozo.has(clave):
				por_trozo[clave] = {}
			if not por_trozo[clave].has(var_i):
				por_trozo[clave][var_i] = []
			por_trozo[clave][var_i].append(t)
			puestas += 1
		for clave: Vector2i in por_trozo:
			# El alcance de dibujo se mide desde el origen del nodo: cada trozo va en su centro.
			var cx := -lado * 0.5 + (clave.x + 0.5) * TROZO
			var cz := -lado * 0.5 + (clave.y + 0.5) * TROZO
			var origen := Vector3(cx, terreno.altura(cx, cz), cz)
			for var_i: int in por_trozo[clave]:
				var lista: Array = por_trozo[clave][var_i]
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = mallas[var_i]
				mm.instance_count = lista.size()
				for k in lista.size():
					mm.set_instance_transform(k, (lista[k] as Transform3D).translated(-origen))
				var mmi := MultiMeshInstance3D.new()
				mmi.position = origen
				mmi.multimesh = mm
				mmi.visibility_range_end = r[4]
				mmi.visibility_range_end_margin = r[4] * 0.15
				mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				if r[5] == "llano":
					mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(mmi)
		print("vegetacion: %s %d/%d en %d trozos" % [modelo, puestas, int(r[1]), por_trozo.size()])
