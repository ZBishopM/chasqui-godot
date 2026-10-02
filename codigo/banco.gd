extends Node3D
## Banco de combinaciones de Chasqui: arena greybox + jugador en primera persona.
## Teclas: 1 manos · 2 personaje · 3 VFX · 4 estilo (Mayus = anterior) · F G R T V C poderes
##         Tab vitrina · K guardar combinacion · F1 ocultar HUD · Esc libera el mouse

const ARCHIVO := "res://combinacion.json"
const PODERES := {KEY_F: "halcon", KEY_G: "sapo", KEY_R: "amaru", KEY_T: "condor", KEY_V: "puma", KEY_C: "colibri"}
const CATEGORIAS := ["manos", "personajes", "vfx", "estilo"]

const SHADER_PANTALLA := """
shader_type canvas_item;
uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_linear;
uniform float flash = 0.0;
uniform float gris = 0.0;
void fragment() {
	vec4 c = texture(pantalla, SCREEN_UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 g = mix(c.rgb, vec3(l) * vec3(0.85, 0.95, 1.1), gris);
	g = mix(g, vec3(1.0), flash);
	float v = smoothstep(0.95, 0.3, distance(SCREEN_UV, vec2(0.5)));
	g *= mix(1.0, v, gris * 0.6);
	COLOR = vec4(g, 1.0);
}
"""

var jugador: CharacterBody3D
var manos: Manos
var sel := {"manos": 0, "personajes": 0, "vfx": 0, "estilo": 0}
var _dummies: Array[Node3D] = []
var _vitrina: Node3D
var _en_vitrina := false
var _rareza := 0
var _hud: Label
var _mat_pantalla: ShaderMaterial


func _ready() -> void:
	_registrar_input()
	_crear_entorno()
	_crear_arena()
	jugador = CharacterBody3D.new()
	jugador.set_script(preload("res://codigo/jugador.gd"))
	jugador.position = Vector3(0, 0.05, 2)
	add_child(jugador)

	manos = Manos.new()
	jugador.camara.add_child(manos)
	_crear_hud()
	_cargar()
	_aplicar_todo()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("liberar_mouse"):
		var capturado := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if capturado else Input.MOUSE_MODE_CAPTURED
		return
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	var k := ev as InputEventKey
	if PODERES.has(k.keycode):
		_poder(PODERES[k.keycode])
	elif k.keycode >= KEY_1 and k.keycode <= KEY_4:
		_cambiar(CATEGORIAS[k.keycode - KEY_1], -1 if k.shift_pressed else 1)
	elif k.keycode == KEY_TAB:
		_alternar_vitrina()
	elif k.keycode == KEY_K:
		_guardar()
	elif k.keycode == KEY_O:
		_ofrenda()
	elif k.keycode == KEY_F1:
		_hud.visible = not _hud.visible


# --- Seleccion -----------------------------------------------------------------------------------

func _lista(cat: String) -> Array:
	return Catalogo.CATEGORIAS[cat]


func _actual(cat: String) -> Dictionary:
	return _lista(cat)[sel[cat]]


func _cambiar(cat: String, paso: int) -> void:
	var n := _lista(cat).size()
	sel[cat] = (sel[cat] + paso + n) % n
	_aplicar(cat)
	_actualizar_hud()


func _aplicar_todo() -> void:
	for cat in CATEGORIAS:
		_aplicar(cat)
	_actualizar_hud()


func _aplicar(cat: String) -> void:
	match cat:
		"manos":
			manos.montar(_actual("manos"))
			jugador.camara.fov = float(_actual("manos").get("fov", 90.0))   # cada rig se ve bien con su FOV
			Estilo.aplicar(manos, _actual("estilo").id == "toon", _actual("manos").get("tinta", true))
		"personajes":
			_montar_dummies()
			_montar_vitrina()
		"estilo":
			var toon: bool = _actual("estilo").id == "toon"
			Estilo.aplicar(manos, toon, _actual("manos").get("tinta", true))
			for d in _dummies:
				Estilo.aplicar(d, toon)
			Estilo.aplicar(_vitrina, toon)


func _montar_dummies() -> void:
	for d in _dummies:
		d.queue_free()
	_dummies.clear()
	var posiciones := [Vector3(-3, 0, -6), Vector3(0, 0, -8), Vector3(3, 0, -6)]
	for p: Vector3 in posiciones:
		var d := Personajes.crear(_actual("personajes"))
		d.position = p
		d.visible = not _en_vitrina
		add_child(d)
		_dummies.append(d)
		Estilo.aplicar(d, _actual("estilo").id == "toon")


func _montar_vitrina() -> void:
	if _vitrina != null:
		_vitrina.queue_free()
	_vitrina = Node3D.new()
	_vitrina.visible = _en_vitrina
	add_child(_vitrina)
	var lista := Catalogo.PERSONAJES
	for i in lista.size():
		var c := Personajes.crear(lista[i])
		c.position = Vector3((i - (lista.size() - 1) / 2.0) * 1.3, 0, -2)
		_vitrina.add_child(c)
		var et := Label3D.new()
		et.text = "%s\n%s" % [lista[i].id, lista[i].nombre]
		et.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		et.font_size = 28
		et.pixel_size = 0.004
		et.outline_size = 8
		et.no_depth_test = true
		et.position = Vector3(c.position.x, 2.2, -2)
		_vitrina.add_child(et)
	Estilo.aplicar(_vitrina, _actual("estilo").id == "toon")


func _alternar_vitrina() -> void:
	_en_vitrina = not _en_vitrina
	_vitrina.visible = _en_vitrina
	for d in _dummies:
		d.visible = not _en_vitrina


# --- Poderes -------------------------------------------------------------------------------------

func _poder(poder: String) -> void:
	manos.lanzar_gesto(poder)
	await get_tree().create_timer(manos.duracion() * 0.5).timeout   # el efecto sale en el pico del gesto
	var tipo: String = _actual("vfx").tipo
	match tipo:
		"propio":
			VfxPropios.lanzar(poder, _ctx())
		"binbun_proyectiles", "binbun_elemental":
			VfxPacks.lanzar(tipo, poder, _ctx())


## Efecto de recogida de las ofrendas (Loot VFX de Binbun), de comun a mitico. Es el visual del Camaquen de oro sagrado.
func _ofrenda() -> void:
	VfxPacks.ofrenda(_ctx(), _rareza)
	_rareza = (_rareza + 1) % VfxPacks.RAREZAS.size()


func _ctx() -> Dictionary:
	var cam: Camera3D = jugador.camara
	var fwd: Vector3 = -cam.global_transform.basis.z
	var objetivo := _apuntar()
	return {
		banco = self, mundo = self, camara = cam, jugador = jugador, fwd = fwd,
		origen = cam.global_position + fwd * 0.6 - cam.global_transform.basis.x * 0.2 + Vector3.DOWN * 0.2,
		destino = objetivo + Vector3.UP * 1.1, suelo = objetivo, dummies = _dummies,
	}


## Pies del muneco mas cercano a la mira (cono ~25 grados) o, si no hay, el punto del suelo a ~12 m.
func _apuntar() -> Vector3:
	var cam: Camera3D = jugador.camara
	var fwd: Vector3 = -cam.global_transform.basis.z
	var mejor: Node3D = null
	var mejor_cos := 0.9
	for d in _dummies:
		var c: float = fwd.dot((d.global_position + Vector3.UP - cam.global_position).normalized())
		if d.visible and c > mejor_cos:
			mejor_cos = c
			mejor = d
	if mejor != null:
		return Vector3(mejor.global_position.x, 0, mejor.global_position.z)
	var p: Vector3 = cam.global_position + fwd * 12.0
	return Vector3(p.x, 0, p.z)


# --- Pantalla (flash del rayo, gris del Colibri) --------------------------------------------------

func flash(valor: float, seg: float) -> void:
	_mat_pantalla.set_shader_parameter("flash", valor)
	create_tween().tween_method(func(v: float) -> void: _mat_pantalla.set_shader_parameter("flash", v), valor, 0.0, seg)


func gris(destino: float, seg: float) -> void:
	var desde: float = _mat_pantalla.get_shader_parameter("gris")
	create_tween().tween_method(func(v: float) -> void: _mat_pantalla.set_shader_parameter("gris", v), desde, destino, seg)


# --- HUD, guardado -------------------------------------------------------------------------------

func _crear_hud() -> void:
	var capa_fx := CanvasLayer.new()
	capa_fx.layer = 10
	add_child(capa_fx)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER_PANTALLA
	_mat_pantalla = ShaderMaterial.new()
	_mat_pantalla.shader = sh
	_mat_pantalla.set_shader_parameter("flash", 0.0)
	_mat_pantalla.set_shader_parameter("gris", 0.0)
	rect.material = _mat_pantalla
	capa_fx.add_child(rect)

	var capa := CanvasLayer.new()
	capa.layer = 11
	add_child(capa)
	_hud = Label.new()
	_hud.position = Vector2(14, 10)
	_hud.add_theme_font_size_override("font_size", 16)
	_hud.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hud.add_theme_constant_override("outline_size", 6)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(_hud)


func _actualizar_hud() -> void:
	var lineas: PackedStringArray = []
	for i in CATEGORIAS.size():
		var cat: String = CATEGORIAS[i]
		var e := _actual(cat)
		var lic: String = ("  ·  %s · %s" % [e.licencia, e.autor]) if e.has("licencia") else ""
		lineas.append("[%d] %-10s %s %s%s" % [i + 1, cat.capitalize(), e.get("id", ""), e.nombre, lic])
	lineas.append("")
	lineas.append("F Halcon · G Sapo · R Amaru · T Condor · V Puma · C Colibri (Mayus+C ralentiza)")
	lineas.append("O ofrenda (Loot VFX, rareza cicla) · Mayus+1..4 anterior · Tab vitrina · K guardar · F1 ocultar · Esc mouse")
	_hud.text = "\n".join(lineas)


func _guardar() -> void:
	var datos := {}
	for cat in CATEGORIAS:
		var e := _actual(cat)
		datos[cat] = {"id": e.get("id", ""), "nombre": e.nombre}
	datos["fecha"] = Time.get_datetime_string_from_system()
	var f := FileAccess.open(ARCHIVO, FileAccess.WRITE)
	f.store_string(JSON.stringify(datos, "\t"))
	f.close()
	_captura("combinacion_" + Time.get_datetime_string_from_system().replace(":", "-"))
	print("Combinacion guardada: ", datos)


## Guarda la vista actual en capturas/<nombre>.png (carpeta ignorada por git). Devuelve la ruta absoluta.
func _captura(nombre: String) -> String:
	var carpeta := ProjectSettings.globalize_path("res://capturas")
	DirAccess.make_dir_recursive_absolute(carpeta)
	var ruta := "%s/%s.png" % [carpeta, nombre]
	get_viewport().get_texture().get_image().save_png(ruta)
	return ruta


const PRUEBAS := {
	"halcon": [0.55, 0.8], "sapo": [0.7, 1.0, 1.8], "amaru": [0.8, 1.05, 1.6],
	"condor": [0.68, 0.8, 1.2], "puma": [1.0, 2.5], "colibri": [0.7, 2.0],
}


## Mide cuanto se mueve el hueso mas rapido de las manos durante cada gesto (entrada, pico y vuelta al reposo), en grados/s.
## Un salto de 90 grados en un solo frame da >10000; un gesto fluido queda por debajo de unos 700. Se usa desde el MCP.
func medir_suavidad() -> String:
	var sk: Skeleton3D = manos._sk
	if sk == null:
		return "estas manos no usan Skeleton3D"
	var huesos := GestosLib.huesos_utiles(sk)
	var out: PackedStringArray = ["manos=" + str(_actual("manos").id)]
	for poder in PRUEBAS:
		await get_tree().create_timer(0.8).timeout
		var previa := GestosLib.pose_actual(sk, huesos)
		var t_prev := Time.get_ticks_usec()
		manos.lanzar_gesto(poder)
		var vmax := 0.0
		var t_en := 0.0
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < int((manos.duracion() + 1.0) * 1000.0):
			await get_tree().process_frame
			var ahora := Time.get_ticks_usec()
			var dt := (ahora - t_prev) / 1e6
			t_prev = ahora
			var p := GestosLib.pose_actual(sk, huesos)
			var d := 0.0
			for i in huesos:
				d = maxf(d, (previa[i] as Quaternion).angle_to(p[i]))
			var v := rad_to_deg(d) / maxf(dt, 0.0001)
			if v > vmax:
				vmax = v
				t_en = (Time.get_ticks_msec() - t0) / 1000.0
			previa = p
		out.append("%s: dur=%.2f s  vel_max=%.0f °/s (t=%.2f s)" % [poder, manos.duracion(), vmax, t_en])
	return "\n".join(out)


## Recorre los 6 poderes con la combinacion actual y deja las capturas en capturas/ (para revisar sin jugar).
func probar_todo() -> void:
	for poder: String in PRUEBAS:
		await probar(poder, PRUEBAS[poder])
		await get_tree().create_timer(6.0).timeout


## Prueba automatica (la usa el MCP via game_eval): lanza un poder y captura en los instantes dados (s).
func probar(poder: String, instantes: Array) -> void:
	_poder(poder)
	var t0 := Time.get_ticks_msec()
	for s: float in instantes:
		var espera := s - (Time.get_ticks_msec() - t0) / 1000.0
		if espera > 0.0:
			await get_tree().create_timer(espera).timeout
		await RenderingServer.frame_post_draw
		_captura("%s_%s_%.2f" % [_actual("vfx").id, poder, s])


func _cargar() -> void:
	if not FileAccess.file_exists(ARCHIVO):
		return
	var datos = JSON.parse_string(FileAccess.get_file_as_string(ARCHIVO))
	if not datos is Dictionary:
		return
	for cat in CATEGORIAS:
		if datos.has(cat):
			var lista := _lista(cat)
			for i in lista.size():
				if lista[i].get("id", "") == datos[cat].get("id", ""):
					sel[cat] = i


# --- Escenario -----------------------------------------------------------------------------------

func _registrar_input() -> void:
	var teclas := {
		"adelante": KEY_W, "atras": KEY_S, "izquierda": KEY_A, "derecha": KEY_D,
		"saltar": KEY_SPACE, "liberar_mouse": KEY_ESCAPE,
	}
	for nombre: String in teclas:
		if not InputMap.has_action(nombre):
			InputMap.add_action(nombre)
		var ev := InputEventKey.new()
		ev.physical_keycode = teclas[nombre]
		InputMap.action_add_event(nombre, ev)


func _crear_entorno() -> void:
	var cielo := ProceduralSkyMaterial.new()
	cielo.sky_top_color = Color(0.35, 0.55, 0.85)
	cielo.sky_horizon_color = Color(0.8, 0.85, 0.9)
	cielo.ground_horizon_color = Color(0.8, 0.85, 0.9)
	var sky := Sky.new()
	sky.sky_material = cielo
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.ssao_enabled = true
	var mundo := WorldEnvironment.new()
	mundo.environment = env
	add_child(mundo)

	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, -30, 0)
	sol.shadow_enabled = true
	add_child(sol)


func _crear_arena() -> void:
	var suelo := StaticBody3D.new()
	var malla := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(60, 60)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.27, 0.22)
	plano.material = mat
	malla.mesh = plano
	suelo.add_child(malla)
	var col := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(60, 1, 60)
	col.shape = caja
	col.position.y = -0.5
	suelo.add_child(col)
	add_child(suelo)

	# Bloques de referencia: miden escala, dan sombra y sirven de muro para la Vision del Puma.
	for i in 5:
		var b := CSGBox3D.new()
		b.size = Vector3(1.5, 1.0 + i * 0.5, 1.5)
		b.position = Vector3(-10 + i * 5, b.size.y * 0.5, -14)
		b.use_collision = true
		add_child(b)
	var muro := CSGBox3D.new()
	muro.size = Vector3(3.2, 3, 0.5)
	muro.position = Vector3(3, 1.5, -4)
	muro.use_collision = true
	add_child(muro)
