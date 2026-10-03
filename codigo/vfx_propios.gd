class_name VfxPropios
extends RefCounted
## V1: efectos propios de los 6 poderes del GDD §10, con GPUParticles3D + shaders. Sin texturas externas.
## ctx = {banco, mundo, camara, jugador, fwd, origen, destino, suelo, dummies}
##   origen = mano izquierda · destino = pecho del objetivo · suelo = sus pies.
## Todo lo que nace aqui entra al grupo "vfx" para que el Colibri pueda congelarlo.

const SHADER_XRAY := """
shader_type spatial;
render_mode unshaded, depth_test_disabled, blend_add, cull_back;
uniform vec4 color : source_color = vec4(1.0, 0.65, 0.1, 1.0);
uniform float pulso = 1.0;
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = color.rgb * (0.35 + f) * pulso;
	ALPHA = 0.55 + f * 0.45;
}
"""

const ANCHO_ANILLO := 0.16   # m, constante sin importar el radio
const SHADER_ANILLO := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 color : source_color = vec4(1.0);
uniform float radio = 0.2;
uniform float ancho = 0.12;
uniform float alfa = 1.0;
varying vec3 pos_local;
void vertex() { pos_local = VERTEX; }
void fragment() {
	float d = abs(length(pos_local.xz) - radio);
	float a = 1.0 - smoothstep(ancho * 0.25, ancho * 0.5, d);
	ALBEDO = color.rgb * 2.0;
	ALPHA = a * alfa;
}
"""

static var _sprite: GradientTexture2D
static var _xray: Shader
static var _sh_anillo: Shader


## Solo la mecanica (sin visual propio): la usan los packs, que ponen su propio visual encima.
static func mecanica(poder: String, ctx: Dictionary) -> void:
	match poder:
		"halcon": _halcon_mecanica(ctx)
		"sapo": _sapo_mecanica(ctx)
		"amaru":
			ctx.mundo.create_tween().tween_interval(0.45).finished.connect(func() -> void: _reaccion(ctx.mundo, ctx.dummies, ctx.destino))
		"condor":
			ctx.mundo.create_tween().tween_interval(0.2).finished.connect(func() -> void: _reaccion(ctx.mundo, ctx.dummies, ctx.destino))
		"puma": _puma(ctx)
		"colibri": _colibri(ctx)


static func lanzar(poder: String, ctx: Dictionary) -> void:
	match poder:
		"halcon": _halcon(ctx)
		"sapo": _sapo(ctx)
		"amaru": _amaru(ctx)
		"condor": _condor(ctx)
		"puma": _puma(ctx)
		"colibri": _colibri(ctx)


# --- Halcon: despegue + picado, estela de viento y patada de FOV -------------------------------

## Lo que cambia el juego: despegue vertical, picado hacia delante y patada de FOV. Lo comparten VFX propios y packs.
static func _halcon_mecanica(ctx: Dictionary) -> void:
	var jug: CharacterBody3D = ctx.jugador
	var fwd: Vector3 = ctx.fwd
	jug.velocity.y = 6.0                                   # fase 1: despegue vertical
	jug.impulso = Vector3(fwd.x, 0, fwd.z).normalized() * 18.0   # fase 2: picado hacia delante
	# La patada es un sumando del FOV que el jugador compone con el de reposo y el del esprint; va a valores fijos (16 y 0)
	# para que con F seguido no se acumule (antes partia del FOV actual y llego a 176 grados).
	var tw := _tween_unico(ctx.mundo, ctx.jugador, "patada_fov")
	tw.tween_property(ctx.jugador, "patada_fov", 16.0, 0.12)
	tw.tween_property(ctx.jugador, "patada_fov", 0.0, 0.5).set_trans(Tween.TRANS_SINE)


## Tween que corta al anterior con la misma `clave` sobre `n`: repetir un poder no apila dos tweens peleando por lo mismo.
static func _tween_unico(mundo: Node, n: Node, clave: String) -> Tween:
	if n.has_meta(clave):
		(n.get_meta(clave) as Tween).kill()
	var tw := mundo.create_tween()
	n.set_meta(clave, tw)
	return tw


static func _halcon(ctx: Dictionary) -> void:
	var fwd: Vector3 = ctx.fwd
	_halcon_mecanica(ctx)
	# Lineas de velocidad: palitos finos alineados con -fwd que nacen en un anillo delante de la camara.
	var pm := _proc(-fwd, 0.0, 22.0, 30.0, Vector3.ZERO, Color(0.9, 0.97, 1.0, 0.9), Color(0.9, 0.97, 1.0, 0.0), 0.7, 1.4, 0.0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = fwd
	pm.emission_ring_radius = 3.0
	pm.emission_ring_inner_radius = 1.2
	pm.emission_ring_height = 4.0
	pm.particle_flag_align_y = true
	var palito := BoxMesh.new()
	palito.size = Vector3(0.012, 1.1, 0.012)
	var mp := StandardMaterial3D.new()
	mp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mp.vertex_color_use_as_albedo = true
	mp.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	palito.material = mp
	_particulas(ctx.mundo, ctx.camara.global_position + fwd * 4.0, 90, 0.4, pm, palito, true, 0.7)


# --- Sapo: golpe de suelo, micro-huayco, enemigos atrapados hasta las rodillas ------------------

static func _sapo(ctx: Dictionary) -> void:
	var suelo: Vector3 = ctx.suelo
	_particulas(ctx.mundo, suelo + Vector3.UP * 0.1, 90, 0.9,
		_proc(Vector3.UP, 55.0, 3.0, 7.0, Vector3(0, -9.8, 0), Color(0.45, 0.28, 0.12, 1.0), Color(0.3, 0.18, 0.08, 0.0), 0.8, 1.6, 0.0),
		_quad(0.25, false))
	_anillo(ctx.mundo, suelo + Vector3.UP * 0.05, Color(0.6, 0.4, 0.2), 4.5, 0.6)
	var charco := _disco(ctx.mundo, suelo + Vector3.UP * 0.01, 2.6, Color(0.28, 0.17, 0.08))
	var tw: Tween = ctx.mundo.create_tween()
	tw.tween_interval(3.0)
	tw.tween_callback(charco.queue_free)
	_sapo_mecanica(ctx)


## Lo que cambia el juego: quienes estan cerca del golpe quedan atrapados hasta las rodillas unos segundos.
static func _sapo_mecanica(ctx: Dictionary) -> void:
	for d: Node3D in ctx.dummies:
		if d.global_position.distance_to(ctx.suelo) < 4.0:
			var base: float = d.get_meta("y_de_pie", d.position.y)   # no la actual: si ya estaba hundido, se hundia mas
			d.set_meta("y_de_pie", base)
			var t2 := _tween_unico(ctx.mundo, d, "atrapado")
			t2.tween_property(d, "position:y", base - 0.45, 0.2)
			t2.tween_interval(2.6)
			t2.tween_property(d, "position:y", base, 0.4)


# --- Amaru: serpiente de fuego a distancia, explosion y llamas residuales -----------------------

static func _amaru(ctx: Dictionary) -> void:
	var cabeza := Node3D.new()
	ctx.mundo.add_child(cabeza)
	cabeza.global_position = ctx.origen
	cabeza.add_to_group("vfx")
	var fuego := _particulas(cabeza, cabeza.global_position, 70, 0.5,
		_proc(Vector3.UP, 25.0, 0.2, 0.8, Vector3(0, 2.0, 0), Color(2.0, 1.1, 0.3, 0.9), Color(1.2, 0.2, 0.02, 0.0), 0.6, 1.3, 0.0),
		_quad(0.35), false, 0.0)
	fuego.position = Vector3.ZERO
	var luz := _luz(cabeza, Color(1.0, 0.55, 0.15), 1.2, 4.0)
	luz.position = Vector3.ZERO
	var tw: Tween = ctx.mundo.create_tween()
	tw.tween_property(cabeza, "global_position", ctx.destino, 0.45).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		_particulas(ctx.mundo, ctx.destino, 140, 0.8,
			_proc(Vector3.UP, 180.0, 2.0, 6.0, Vector3(0, 1.0, 0), Color(2.2, 1.2, 0.3, 1.0), Color(1.0, 0.15, 0.0, 0.0), 0.8, 1.8, 0.0),
			_quad(0.5))
		var flash := _luz(ctx.mundo, Color(1.0, 0.6, 0.2), 6.0, 8.0)
		flash.global_position = ctx.destino
		var t3: Tween = ctx.mundo.create_tween()
		t3.tween_property(flash, "light_energy", 0.0, 0.35)
		t3.tween_callback(flash.queue_free)
		fuego.emitting = false
		cabeza.queue_free()
		_particulas(ctx.mundo, ctx.suelo, 50, 1.6,
			_proc(Vector3.UP, 20.0, 0.3, 1.2, Vector3(0, 2.0, 0), Color(2.0, 1.0, 0.25, 0.9), Color(1.0, 0.1, 0.0, 0.0), 0.7, 1.5, 0.0),
			_quad(0.5), false, 0.0, 1.8)
		_reaccion(ctx.mundo, ctx.dummies, ctx.destino))


# --- Condor: rayo desde el cielo, fulminante y ruidoso ------------------------------------------

static func _condor(ctx: Dictionary) -> void:
	var fin: Vector3 = ctx.destino
	var inicio := fin + Vector3(0, 18, 0)
	var rayo := Node3D.new()
	ctx.mundo.add_child(rayo)
	rayo.add_to_group("vfx")
	_bolt(rayo, inicio, fin, 0.07, 1.0)
	for i in 2:
		var mitad := inicio.lerp(fin, randf_range(0.35, 0.6))
		_bolt(rayo, mitad, mitad + Vector3(randf_range(-4, 4), -randf_range(3, 6), randf_range(-4, 4)), 0.035, 0.8)
	var luz := _luz(ctx.mundo, Color(0.7, 0.85, 1.0), 14.0, 14.0)
	luz.global_position = fin + Vector3.UP * 1.0
	_particulas(ctx.mundo, fin, 60, 0.5,
		_proc(Vector3.UP, 90.0, 3.0, 9.0, Vector3(0, -6.0, 0), Color(3.0, 4.0, 6.0, 1.0), Color(0.8, 1.5, 4.0, 0.0), 0.6, 1.4, 0.0),
		_quad(0.18))
	ctx.banco.flash(0.55, 0.25)
	var tw: Tween = ctx.mundo.create_tween()
	tw.tween_property(luz, "light_energy", 0.0, 0.3)
	tw.tween_callback(luz.queue_free)
	tw.tween_callback(rayo.queue_free)
	_reaccion(ctx.mundo, ctx.dummies, fin)


static func _bolt(padre: Node3D, a: Vector3, b: Vector3, grosor: float, energia: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.85, 0.93, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.8, 1.0)
	mat.emission_energy_multiplier = 6.0 * energia
	var n := 12
	var anterior := a
	for i in range(1, n + 1):
		var t := float(i) / n
		var p := a.lerp(b, t)
		if i < n:
			var tam := sin(PI * t) * 0.9
			p += Vector3(randf_range(-tam, tam), 0, randf_range(-tam, tam))
		var largo := anterior.distance_to(p)
		var seg := MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = Vector3(grosor, grosor, largo)
		seg.mesh = caja
		seg.material_override = mat
		padre.add_child(seg)
		seg.global_position = (anterior + p) * 0.5
		var dir := (p - anterior).normalized()
		seg.look_at(p, Vector3.RIGHT if absf(dir.y) > 0.9 else Vector3.UP)
		anterior = p


# --- Puma: siluetas a traves de muros (5 s) y ondas de sonido -----------------------------------

static func _puma(ctx: Dictionary) -> void:
	if _xray == null:
		_xray = Shader.new()
		_xray.code = SHADER_XRAY
	var mat := ShaderMaterial.new()
	mat.shader = _xray
	for d: Node3D in ctx.dummies:
		_overlay(d, mat)
	var tw: Tween = ctx.mundo.create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("pulso", 0.7 + 0.3 * sin(v * 18.0)), 0.0, 5.0, 5.0)
	tw.tween_callback(func() -> void:
		for d: Node3D in ctx.dummies:
			if is_instance_valid(d):
				_overlay(d, null))
	for i in 5:
		var t2: Tween = ctx.mundo.create_tween()
		t2.tween_interval(i * 0.9)
		t2.tween_callback(func() -> void: _anillo(ctx.mundo, ctx.jugador.global_position + Vector3.UP * 0.1, Color(1.0, 0.65, 0.15), 16.0, 1.4))


static func _overlay(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_overlay = mat
	for c in n.get_children():
		_overlay(c, mat)


# --- Colibri: detencion total del tiempo (5 s) o ralentizacion (Mayus, ruta del Monstruo) -------

static func _colibri(ctx: Dictionary) -> void:
	var ralentiza := Input.is_key_pressed(KEY_SHIFT)
	var escala := 0.2 if ralentiza else 0.0
	_tiempo(ctx, escala)
	ctx.banco.gris(1.0, 0.25)
	_anillo(ctx.mundo, ctx.jugador.global_position + Vector3.UP * 0.1, Color(0.6, 0.8, 1.0), 10.0, 0.7)
	ctx.banco.manos.sostener_venas(5.0)   # las marcas arden mientras el tiempo esta detenido
	var tw: Tween = ctx.mundo.create_tween()
	tw.tween_interval(5.0)
	tw.tween_callback(func() -> void:
		_tiempo(ctx, 1.0)
		ctx.banco.gris(0.0, 0.5))


static func _tiempo(ctx: Dictionary, escala: float) -> void:
	for d: Node3D in ctx.dummies:
		var ap: AnimationPlayer = d.get_meta("anim", null)
		if ap != null:
			ap.speed_scale = escala
	for p in ctx.mundo.get_tree().get_nodes_in_group("vfx"):
		if p is GPUParticles3D or "speed_scale" in p:   # los efectos de Binbun tambien traen speed_scale
			p.speed_scale = escala


# --- Utilidades ---------------------------------------------------------------------------------

static func _reaccion(mundo: Node, dummies: Array, punto: Vector3) -> void:
	for d: Node3D in dummies:
		if d.global_position.distance_to(punto) < 3.0:
			var tw: Tween = mundo.create_tween()
			tw.tween_property(d, "rotation_degrees:x", -14.0, 0.08)
			tw.tween_property(d, "rotation_degrees:x", 0.0, 0.3)


static func _sprite_suave() -> GradientTexture2D:
	if _sprite == null:
		var g := Gradient.new()
		g.set_color(0, Color.WHITE)
		g.set_color(1, Color(1, 1, 1, 0))
		_sprite = GradientTexture2D.new()
		_sprite.gradient = g
		_sprite.fill = GradientTexture2D.FILL_RADIAL
		_sprite.fill_from = Vector2(0.5, 0.5)
		_sprite.fill_to = Vector2(1.0, 0.5)
		_sprite.width = 64
		_sprite.height = 64
	return _sprite


static func _quad(tam: float, aditivo: bool = true) -> QuadMesh:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _sprite_suave()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if aditivo else BaseMaterial3D.BLEND_MODE_MIX
	var q := QuadMesh.new()
	q.size = Vector2(tam, tam)
	q.material = m
	return q


static func _proc(dir: Vector3, spread: float, vmin: float, vmax: float, grav: Vector3,
		c0: Color, c1: Color, smin: float, smax: float, damping: float) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = spread
	pm.initial_velocity_min = vmin
	pm.initial_velocity_max = vmax
	pm.gravity = grav
	pm.scale_min = smin
	pm.scale_max = smax
	pm.damping_min = damping
	pm.damping_max = damping
	var g := Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, c1)
	var rampa := GradientTexture1D.new()
	rampa.gradient = g
	pm.color_ramp = rampa
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.15
	return pm


## one_shot=true: rafaga que se libera sola. false: continuo hasta `duracion` s (0 = hasta que lo apaguen).
static func _particulas(padre: Node, pos: Vector3, cantidad: int, vida: float, pm: ParticleProcessMaterial,
		malla: Mesh, una_vez: bool = true, explosividad: float = 1.0, duracion: float = 0.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = cantidad
	p.lifetime = vida
	p.one_shot = una_vez
	p.explosiveness = explosividad
	p.process_material = pm
	p.draw_pass_1 = malla
	p.add_to_group("vfx")
	padre.add_child(p)
	p.global_position = pos
	p.emitting = true
	var vive := vida + 0.5 if una_vez else duracion
	if vive > 0.0:
		padre.get_tree().create_timer(vive).timeout.connect(p.queue_free)
	return p


static func _luz(padre: Node, color: Color, energia: float, rango: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energia
	l.omni_range = rango
	padre.add_child(l)
	return l


## Anillo de ANCHO FIJO que se expande por el suelo. Un toro escalado engordaba con el radio (1,3 m de grosor a 16 m);
## aqui el plano no se escala: el shader dibuja la franja a `ancho` metros de la distancia `radio`.
static func _anillo(mundo: Node, pos: Vector3, color: Color, radio_final: float, seg: float, ancho: float = ANCHO_ANILLO) -> void:
	if _sh_anillo == null:
		_sh_anillo = Shader.new()
		_sh_anillo.code = SHADER_ANILLO
	var m := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2.ONE * (radio_final * 2.0 + ancho * 2.0)
	m.mesh = plano
	var mat := ShaderMaterial.new()
	mat.shader = _sh_anillo
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("ancho", ancho)
	mat.set_shader_parameter("radio", 0.2)
	mat.set_shader_parameter("alfa", 1.0)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mundo.add_child(m)
	m.add_to_group("vfx")
	m.global_position = pos
	var tw: Tween = mundo.create_tween().set_parallel(true)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("radio", v), 0.2, radio_final, seg)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("alfa", v), 1.0, 0.0, seg)
	tw.chain().tween_callback(m.queue_free)


static func _disco(mundo: Node, pos: Vector3, radio: float, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radio
	c.bottom_radius = radio
	c.height = 0.02
	m.mesh = c
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	m.material_override = mat
	mundo.add_child(m)
	m.global_position = pos
	return m
