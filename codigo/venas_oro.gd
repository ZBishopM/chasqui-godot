class_name VenasOro
extends Node3D
## Venas de oro bajo la piel (GDD §6, «el oro vive fusionado bajo la piel del Chasqui»): cintas finas pegadas a los huesos del
## dorso de la mano y del antebrazo. Nacen en los nudillos, cruzan la muñeca y trepan por el antebrazo; el shader las revela desde
## la mano segun `crecimiento` (0..1) y las enciende con `brillo` (ver AnimProc.brillo_venas).
##
## Se construye de la geometria del rig en reposo, asi que vale para cualquier brazo con huesos de codo, muñeca y dedos.
## Las dimensiones estan en METROS DEL MUNDO: se convierten a unidades locales con la escala del esqueleto.

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 color : source_color = vec4(1.0, 0.72, 0.16, 1.0);
uniform float crecimiento = 0.2;   // 0..1: hasta donde llegan las venas, medido desde los nudillos
uniform float brillo = 1.0;        // 1 = reposo; sube al canalizar
uniform float emision = 2.6;
void fragment() {
	float x = UV.x;
	float revelado = 1.0 - smoothstep(crecimiento - 0.07, crecimiento, x);
	float frente = exp(-pow((x - crecimiento) * 16.0, 2.0)) * 1.4;           // la punta que avanza brilla mas
	float perfil = 1.0 - smoothstep(0.35, 1.0, abs(UV.y * 2.0 - 1.0));        // la cinta es mas intensa en el centro
	float pulso = 0.88 + 0.12 * sin(TIME * 6.0 + x * 24.0);
	ALBEDO = color.rgb * emision * brillo * (1.0 + frente) * pulso;
	ALPHA = clamp(revelado * perfil, 0.0, 1.0);
}
"""

## 1 = fino y simetrico (ruta del Verdadero Chasqui, Caos bajo); 3 = grueso y brillante (ruta del Monstruo, Caos alto).
@export_range(0.5, 4.0, 0.1) var grosor := 1.0
@export_range(1, 16) var cantidad := 8
@export var radio_brazo := 0.026     # m: distancia del eje del antebrazo a la piel, junto a la muñeca
@export var radio_mano := 0.012      # m: lo mismo en el dorso de la mano
@export_range(0.0, 1.0, 0.05) var engrosa := 0.55   # cuanto crece el radio hacia el codo (0 = cilindro; 0.55 = antebrazo humano)
@export var color := Color(1.0, 0.72, 0.16)
@export var semilla := 7
## Donde acaba la parte de la mano y empieza la del antebrazo en el eje de crecimiento (0..1).
const CORTE := 0.3

var crecimiento := 0.2:
	set(v):
		crecimiento = v
		for m in _mats:
			m.set_shader_parameter("crecimiento", v)
var brillo := 1.0:
	set(v):
		brillo = v
		for m in _mats:
			m.set_shader_parameter("brillo", v)

var _mats: Array[ShaderMaterial] = []
var _adjuntos: Array[Node] = []
static var _shader: Shader


## h: codo (hueso del antebrazo), muneca, dedos_base (nombres de la 1.a falange de indice, medio, anular y menique).
## `yaw` solo sirve para saber hacia donde mira el modelo; la geometria se calcula en el espacio del esqueleto.
func construir(sk: Skeleton3D, h: Dictionary, es_izquierda: bool) -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var iE := sk.find_bone(h.codo)
	var iW := sk.find_bone(h.muneca)
	var fb: Array[Vector3] = []
	for n: String in h.dedos_base:
		fb.append(sk.get_bone_global_pose(sk.find_bone(n)).origin)
	var E := sk.get_bone_global_pose(iE).origin
	var W := sk.get_bone_global_pose(iW).origin
	var esc := maxf(sk.global_transform.basis.get_scale().x, 0.0001)   # m -> unidades del esqueleto: dividir por esto

	# Marco de la mano: d hacia los dedos, l del menique al indice, dorso = el lado opuesto a la palma.
	var centro := (fb[0] + fb[1] + fb[2] + fb[3]) * 0.25
	var d := (centro - W).normalized()
	var l := (fb[0] - fb[3]).normalized()
	var n_palma := d.cross(l).normalized()
	if not es_izquierda:
		n_palma = -n_palma
	var dorso := -n_palma
	# Marco del antebrazo: a del codo a la muñeca; u la direccion del dorso perpendicular al eje; v completa la base.
	var a := (W - E).normalized()
	var u := (dorso - a * dorso.dot(a)).normalized()
	var v := a.cross(u).normalized()
	var largo := (W - E).length()

	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var ancho := 0.0022 * grosor / esc        # m -> local
	var r_brazo := radio_brazo / esc
	var r_mano := radio_mano / esc

	# --- antebrazo: `cantidad` cintas que envuelven el brazo, cada una con su largo y su giro ---
	var cintas_brazo: Array = []
	for k in cantidad:
		var phi0 := TAU * (k + rng.randf_range(-0.25, 0.25)) / cantidad
		var giro := rng.randf_range(-1.6, 1.6)
		var longitud := rng.randf_range(0.5, 1.0)
		var pts: Array[Vector3] = []
		var nrm: Array[Vector3] = []
		var xs: Array[float] = []
		var pasos := 16
		for j in pasos + 1:
			var s := float(j) / pasos
			var phi := phi0 + giro * s + 0.22 * sin(s * 9.0 + k * 1.7)
			var radial := u * cos(phi) + v * sin(phi)
			var r := r_brazo * (1.0 + engrosa * s * longitud)
			pts.append(W - a * (s * longitud * largo) + radial * r)
			nrm.append(radial)
			xs.append(CORTE + (1.0 - CORTE) * s * longitud)
		cintas_brazo.append([pts, nrm, xs])
	_adjuntar(sk, iE, cintas_brazo, ancho)

	# --- mano: una vena desde la base de cada dedo hasta la muñeca, por el dorso Y por la palma (segun como se vea la mano) ---
	var cintas_mano: Array = []
	for cara in [dorso, -dorso]:
		for k in 4:
			var pts: Array[Vector3] = []
			var nrm: Array[Vector3] = []
			var xs: Array[float] = []
			var pasos := 8
			var desvio := rng.randf_range(-0.004, 0.004) / esc
			for j in pasos + 1:
				var s := float(j) / pasos
				pts.append(fb[k].lerp(W, s) + cara * r_mano + l * desvio * sin(s * PI))
				nrm.append(cara)
				xs.append(CORTE * s)
			cintas_mano.append([pts, nrm, xs])
	_adjuntar(sk, iW, cintas_mano, ancho * 0.8)


## Convierte las cintas (puntos en el espacio del esqueleto) al marco local del hueso y las monta en un BoneAttachment3D.
func _adjuntar(sk: Skeleton3D, hueso: int, cintas: Array, ancho: float) -> void:
	var att := BoneAttachment3D.new()
	att.name = "Venas_" + sk.get_bone_name(hueso)
	att.bone_idx = hueso
	sk.add_child(att)
	_adjuntos.append(att)
	var a_local := sk.get_bone_global_pose(hueso).affine_inverse()
	var malla := ArrayMesh.new()
	for c in cintas:
		var pts: Array = c[0]
		var nrm: Array = c[1]
		var xs: Array = c[2]
		var vert := PackedVector3Array()
		var uv := PackedVector2Array()
		var norm := PackedVector3Array()
		for j in pts.size():
			var p: Vector3 = pts[j]
			var tangente: Vector3 = (pts[mini(j + 1, pts.size() - 1)] - pts[maxi(j - 1, 0)]).normalized()
			var ancho_j := ancho * (1.0 - 0.55 * float(j) / maxf(pts.size() - 1.0, 1.0))
			var lado := tangente.cross(nrm[j]).normalized() * (ancho_j * 0.5)
			vert.append(a_local * (p + lado))
			vert.append(a_local * (p - lado))
			uv.append(Vector2(xs[j], 0.0))
			uv.append(Vector2(xs[j], 1.0))
			var nl := (a_local.basis * (nrm[j] as Vector3)).normalized()
			norm.append(nl)
			norm.append(nl)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vert
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_NORMAL] = norm
		malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("crecimiento", crecimiento)
	mat.set_shader_parameter("brillo", brillo)
	_mats.append(mat)
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	att.add_child(mi)


func _exit_tree() -> void:
	for n in _adjuntos:
		if is_instance_valid(n):
			n.queue_free()
