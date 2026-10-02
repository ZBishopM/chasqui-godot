class_name Estilo
extends RefCounted
## Toon (M11 de la version web): luz en bandas planas + contorno de tinta por casco invertido.
## Los materiales con emision (oro, venas, marca de Inti) se dejan intactos y sin tinta (M16): las fuentes de luz no llevan contorno.

const SHADER_TOON := """
shader_type spatial;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 color : source_color = vec4(1.0);
uniform bool usa_tex = false;
uniform int bandas = 3;
void fragment() {
	vec4 c = color;
	if (usa_tex) { c *= texture(tex, UV); }
	ALBEDO = c.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float b = floor(nl * float(bandas) + 0.5) / float(bandas);
	DIFFUSE_LIGHT += LIGHT_COLOR * b / PI;
}
"""

const SHADER_TINTA := """
shader_type spatial;
render_mode cull_front, unshaded;
uniform float grosor = 0.25;
void vertex() {
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 vn = normalize(mat3(MODELVIEW_MATRIX) * NORMAL);
	vp.xyz += vn * grosor * (-vp.z) * 0.02;
	POSITION = PROJECTION_MATRIX * vp;
}
void fragment() { ALBEDO = vec3(0.02, 0.02, 0.04); }
"""

static var _toon: Shader
static var _tinta: Shader
static var _mat_tinta: ShaderMaterial


## `tinta=false` para mallas abiertas (brazos con los extremos sin tapa): el casco invertido dejaria ver el interior en negro.
static func aplicar(raiz: Node, toon: bool, tinta: bool = true) -> void:
	if _toon == null:
		_toon = Shader.new()
		_toon.code = SHADER_TOON
		_tinta = Shader.new()
		_tinta.code = SHADER_TINTA
		_mat_tinta = ShaderMaterial.new()
		_mat_tinta.shader = _tinta
	_recorrer(raiz, toon, tinta)


static func _recorrer(n: Node, toon: bool, tinta: bool) -> void:
	if n is MeshInstance3D:
		_malla(n, toon, tinta)
	for c in n.get_children():
		_recorrer(c, toon, tinta)


static func _malla(m: MeshInstance3D, toon: bool, tinta: bool) -> void:
	if m.mesh == null:
		return
	if not toon:
		if m.has_meta("orig_surf"):
			var guardado: Array = m.get_meta("orig_surf")
			for i in guardado.size():
				m.set_surface_override_material(i, guardado[i])
			m.material_override = m.get_meta("orig_ov")
			m.remove_meta("orig_surf")
			m.remove_meta("orig_ov")
		return
	if m.has_meta("orig_surf"):
		return
	var orig := []
	for i in m.mesh.get_surface_count():
		orig.append(m.get_surface_override_material(i))
	m.set_meta("orig_surf", orig)
	m.set_meta("orig_ov", m.material_override)
	if m.material_override != null:
		m.material_override = _a_toon(m.material_override, tinta)
		return
	for i in m.mesh.get_surface_count():
		m.set_surface_override_material(i, _a_toon(m.get_active_material(i), tinta))


static func _a_toon(src: Material, tinta: bool) -> Material:
	var std := src as StandardMaterial3D
	if std == null or std.emission_enabled:
		return src
	var mat := ShaderMaterial.new()
	mat.shader = _toon
	mat.set_shader_parameter("color", std.albedo_color)
	mat.set_shader_parameter("usa_tex", std.albedo_texture != null)
	if std.albedo_texture != null:
		mat.set_shader_parameter("tex", std.albedo_texture)
	if tinta:
		mat.next_pass = _mat_tinta
	return mat
