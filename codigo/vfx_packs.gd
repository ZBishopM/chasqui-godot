class_name VfxPacks
extends RefCounted
## Adaptadores de los packs de Binbun (CC0, https://binbun3d.itch.io). La mecanica de cada poder (empuje, hundimiento,
## tiempo detenido, siluetas) viene de VfxPropios.mecanica(); aqui solo se pone el visual del pack.
## Convencion del pack: cada efecto apunta hacia +X local; se gira para que +X mire hacia donde viaja.

const MP := "res://assets/BinbunVFX/magic_projectiles/effects/"
const EL := "res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/"
const LOOT := "res://assets/BinbunVFX/loot_effects/effects/"
const RAREZAS := ["common", "uncommon", "rare", "epic", "legendary", "mythic"]

## Magic Projectiles: el color de cada uno (amarillo, cian, violeta, rojo) decide el poder.
const V2 := {
	"halcon": "mprojectile_basic/mprojectile_basic_vfx_01.tscn",
	"sapo": "mprojectile_wave/mprojectile_wave_vfx_01.tscn",
	"amaru": "mprojectile_wave/mprojectile_wave_vfx_04.tscn",
	"condor": "mprojectile_basic/mprojectile_basic_vfx_02.tscn",
	"puma": "mprojectile_basic/mprojectile_basic_vfx_03.tscn",
	"colibri": "mprojectile_wave/mprojectile_wave_vfx_03.tscn",
}


static func lanzar(tipo: String, poder: String, ctx: Dictionary) -> void:
	VfxPropios.mecanica(poder, ctx)
	match tipo:
		"binbun_proyectiles":
			_v2(poder, ctx)
		"binbun_elemental":
			_v3(poder, ctx)


# --- Magic Projectiles ---------------------------------------------------------------------------

static func _v2(poder: String, ctx: Dictionary) -> void:
	var ruta: String = MP + V2[poder]
	var cam: Camera3D = ctx.camara
	var fwd: Vector3 = ctx.fwd
	match poder:
		"halcon":
			_proyectil(ctx, ruta, cam.global_position + fwd * 1.5, cam.global_position + fwd * 14.0, 0.35)
		"sapo":
			_proyectil(ctx, ruta, ctx.origen, ctx.suelo + Vector3.UP * 0.3, 0.5)
		"condor":
			_proyectil(ctx, ruta, ctx.destino + Vector3(0, 14, 0), ctx.destino, 0.2)
		"colibri":
			_proyectil(ctx, ruta, ctx.origen, ctx.origen + fwd * 2.0, 1.0)
		_:
			_proyectil(ctx, ruta, ctx.origen, ctx.destino, 0.45)


## Proyectil de un solo disparo: viaja de `desde` a `hasta` en `seg` y se apaga solo (su animacion "oneshot" dura ~1 s).
static func _proyectil(ctx: Dictionary, ruta: String, desde: Vector3, hasta: Vector3, seg: float) -> void:
	var n: Node3D = (load(ruta) as PackedScene).instantiate()
	# autoplay es una variable plana; en cambio one_shot solo se asigna en el editor, asi que se dispara "oneshot" a mano.
	n.set("autoplay", false)
	ctx.mundo.add_child(n)
	n.add_to_group("vfx")
	n.global_transform = Transform3D(_mirar_x(hasta - desde), desde)
	var ap := n.get_node("AnimationPlayer") as AnimationPlayer
	if n.has_method("_reset_particles"):
		n.call("_reset_particles")
	ap.play("oneshot")
	var tw := n.create_tween()
	tw.tween_property(n, "global_position", hasta, seg)
	tw.tween_interval(maxf(0.0, 1.0 - seg))
	tw.tween_callback(n.queue_free)


# --- Elemental Magic FX (version gratis: solo fuego) ---------------------------------------------

static func _v3(poder: String, ctx: Dictionary) -> void:
	var proy := EL + "projectile/vfx_fire_projectile_01.tscn"
	var area := EL + "area/vfx_fire_area_01.tscn"
	var lanza := EL + "cast/vfx_fire_cast_01.tscn"
	var cam: Camera3D = ctx.camara
	var fwd: Vector3 = ctx.fwd
	match poder:
		"amaru":
			_emisor(ctx, lanza, ctx.origen, fwd, 0.8)
			_emisor_viaja(ctx, proy, ctx.origen, ctx.destino, 0.45)
			ctx.mundo.get_tree().create_timer(0.45).timeout.connect(func() -> void: _emisor(ctx, area, ctx.suelo, Vector3.RIGHT, 1.6))
		"halcon":
			_emisor_viaja(ctx, proy, cam.global_position + fwd * 1.5, cam.global_position + fwd * 14.0, 0.35)
		"sapo":
			_emisor(ctx, area, ctx.suelo, Vector3.RIGHT, 1.6)
		"condor":
			_emisor_viaja(ctx, proy, ctx.destino + Vector3(0, 14, 0), ctx.destino, 0.2)
			ctx.mundo.get_tree().create_timer(0.2).timeout.connect(func() -> void: _emisor(ctx, area, ctx.suelo, Vector3.RIGHT, 1.0))
		"puma":
			_emisor(ctx, lanza, ctx.origen, fwd, 0.8)
			_emisor_viaja(ctx, proy, ctx.origen, ctx.destino, 0.45)
		"colibri":
			_emisor(ctx, lanza, ctx.origen, fwd, 0.8)


## Efecto fijo en un punto durante `dur` s. Los "cast" (VFXControllerBB) se tocan con play(); los emisores continuos
## (area, proyectil) arrancan solos y se cierran con emitting=false.
static func _emisor(ctx: Dictionary, ruta: String, pos: Vector3, dir: Vector3, dur: float) -> Node3D:
	var n: Node3D = (load(ruta) as PackedScene).instantiate()
	var es_cast := n.has_method("play")
	if es_cast:
		n.set("one_shot", true)
		n.set("autoplay", false)
	ctx.mundo.add_child(n)
	n.add_to_group("vfx")
	n.global_transform = Transform3D(_mirar_x(dir), pos)
	if es_cast:
		n.call("play")
		ctx.mundo.get_tree().create_timer(dur + 0.1).timeout.connect(n.queue_free)
	else:
		ctx.mundo.get_tree().create_timer(dur).timeout.connect(func() -> void: _cerrar(n))
	return n


static func _emisor_viaja(ctx: Dictionary, ruta: String, desde: Vector3, hasta: Vector3, seg: float) -> void:
	var n := _emisor(ctx, ruta, desde, hasta - desde, seg + 0.05)
	n.create_tween().tween_property(n, "global_position", hasta, seg)


static func _cerrar(n: Node3D) -> void:
	if is_instance_valid(n):
		n.set("emitting", false)
		n.get_tree().create_timer(0.6).timeout.connect(n.queue_free)


# --- Loot VFX: ofrendas y oro sagrado (Camaquen) ---------------------------------------------------

## Efecto de recogida sobre el suelo, delante del jugador. `rareza`: 0 comun ... 5 mitico.
static func ofrenda(ctx: Dictionary, rareza: int) -> void:
	var r: String = RAREZAS[rareza % RAREZAS.size()]
	var n: Node3D = (load(LOOT + "ground/ground_loot_vfx_%s.tscn" % r) as PackedScene).instantiate()
	ctx.mundo.add_child(n)
	n.add_to_group("vfx")
	n.global_position = ctx.suelo + Vector3.UP * 0.05
	ctx.mundo.get_tree().create_timer(4.0).timeout.connect(n.queue_free)


## Gira para que +X local mire hacia `dir` (los efectos del pack apuntan a +X).
static func _mirar_x(dir: Vector3) -> Basis:
	var d := dir.normalized()
	if d.length() < 0.5:
		return Basis.IDENTITY
	if d.dot(Vector3.RIGHT) < -0.999:
		return Basis(Vector3.UP, PI)
	return Basis(Quaternion(Vector3.RIGHT, d))
