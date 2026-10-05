class_name Lluvia
extends Node3D
## Lluvia (despues del Nivel 1, en el plan): gotas GPU que siguen a la camara y caen con el viento; chocan con un campo de
## alturas que tambien sigue a la camara (no llueve bajo techo ni en la cueva) y al chocar salpican. Con la lluvia el
## cielo se cubre, el sol pierde fuerza, la bruma se espesa y todo se moja poco a poco (`humedad`, uniforme global que
## leen el terreno, la piedra, la paja y el ichu: mas oscuros, mas brillantes, charcos en el suelo llano); al parar se
## seca mas despacio. `objetivo` 0..1 (L en el nivel lo alterna); `intensidad` lo persigue en ~6 s.

const SUBIDA := 6.0        # s para llegar a la intensidad pedida
const MOJARSE := 25.0      # s para empaparse con lluvia fuerte
const SECARSE := 90.0      # s para secarse del todo
const GOTAS := 9000
const ALTO := 14.0         # m sobre la camara donde nacen las gotas
const CAMPO := 44.0        # m de lado del chaparron alrededor de la camara

var camara: Camera3D
var cielo: Sky3D
var objetivo := 0.0
var intensidad := 0.0
var humedad := 0.0
var _gotas: GPUParticles3D
var _salpicas: GPUParticles3D
var _campo: GPUParticlesCollisionHeightField3D
var _seco := {}      # valores del cielo sin lluvia


func _ready() -> void:
	_campo = GPUParticlesCollisionHeightField3D.new()
	_campo.size = Vector3(CAMPO + 8.0, 120.0, CAMPO + 8.0)
	_campo.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_512
	_campo.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_ALWAYS
	_campo.follow_camera_enabled = true
	add_child(_campo)

	_salpicas = GPUParticles3D.new()
	_salpicas.amount = 3000
	_salpicas.lifetime = 0.35
	_salpicas.emitting = false
	var ps := ParticleProcessMaterial.new()
	ps.direction = Vector3.UP
	ps.spread = 70.0
	ps.initial_velocity_min = 0.8
	ps.initial_velocity_max = 2.0
	ps.gravity = Vector3(0, -9.8, 0)
	ps.scale_min = 0.6
	ps.scale_max = 1.2
	_salpicas.process_material = ps
	_salpicas.draw_pass_1 = _malla_gota(Vector2(0.03, 0.03), 0.45)
	add_child(_salpicas)

	_gotas = GPUParticles3D.new()
	_gotas.amount = GOTAS
	_gotas.lifetime = 1.3
	_gotas.local_coords = false
	_gotas.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	_gotas.visibility_aabb = AABB(Vector3(-CAMPO, -40.0, -CAMPO), Vector3(CAMPO * 2.0, 80.0, CAMPO * 2.0))
	_gotas.emitting = false
	var pg := ParticleProcessMaterial.new()
	pg.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pg.emission_box_extents = Vector3(CAMPO * 0.5, 1.0, CAMPO * 0.5)
	pg.direction = Vector3.DOWN
	pg.spread = 3.0
	pg.initial_velocity_min = 11.0
	pg.initial_velocity_max = 14.0
	pg.gravity = Vector3(1.6, -9.8, -1.2)   # el viento del valle (relieve.gdshaderinc: viento_dir = (0,8, -0,6))
	pg.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	pg.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION
	pg.sub_emitter_amount_at_collision = 1
	_gotas.process_material = pg
	_gotas.draw_pass_1 = _malla_gota(Vector2(0.012, 0.55), 0.32)
	add_child(_gotas)
	_gotas.sub_emitter = _gotas.get_path_to(_salpicas)

	if cielo != null:
		_seco = {
			"cumulus": cielo.sky.cumulus_coverage, "cirrus": cielo.sky.cirrus_coverage, "absorcion": cielo.sky.cumulus_absorption,
			"sol": cielo.sun_energy, "sombra": cielo.sun_shadow_opacity, "niebla": cielo.sky.fog_density, "viento": cielo.wind_speed,
		}
	RenderingServer.global_shader_parameter_set("humedad", 0.0)


func _malla_gota(tam: Vector2, alfa: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = tam
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.78, 0.82, 0.9, alfa)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	return q


## Pone la lluvia de golpe (para capturas y pruebas): intensidad y humedad ya en `v`.
func poner(v: float) -> void:
	objetivo = v
	intensidad = v
	humedad = v


func alternar() -> void:
	objetivo = 0.0 if objetivo > 0.0 else 1.0


func _process(dt: float) -> void:
	intensidad = move_toward(intensidad, objetivo, dt / SUBIDA)
	humedad = move_toward(humedad, intensidad, dt / (MOJARSE if intensidad > humedad else SECARSE))
	RenderingServer.global_shader_parameter_set("humedad", humedad)
	if camara != null:
		var p := camara.global_position
		_gotas.global_position = p + Vector3(0, ALTO, 0)
	_gotas.amount_ratio = maxf(intensidad, 0.001)
	_gotas.emitting = intensidad > 0.01
	if cielo == null or _seco.is_empty():
		return
	var k := smoothstep(0.0, 1.0, intensidad)
	cielo.sky.cumulus_coverage = lerpf(_seco.cumulus, 0.97, k)
	cielo.sky.cirrus_coverage = lerpf(_seco.cirrus, 0.9, k)
	cielo.sky.cumulus_absorption = lerpf(_seco.absorcion, 6.0, k)
	cielo.sun_energy = lerpf(_seco.sol, 0.25, k)
	cielo.sun_shadow_opacity = lerpf(_seco.sombra, 0.35, k)
	cielo.sky.fog_density = lerpf(_seco.niebla, _seco.niebla * 8.0, k)
	cielo.wind_speed = lerpf(_seco.viento, 8.0, k)
