extends SceneTree
## Capturas fijas de la fosa comun y del cañon (de dia, para ver la forma): desde el borde, de cerca, cenital, desde la
## calzada, el abismo desde el filo y la fosa junto al cañon. Deja capturas/fosa_<vista>.png. Necesita ventana.
##   godot.console.exe --path . --script res://herramientas/vistas_fosa.gd
func _initialize() -> void:
	change_scene_to_file("res://escenas/nivel1.tscn")
	_c.call_deferred()
func _poner(n: Node, pos: Vector3, mira: Vector3) -> void:
	var d := mira - pos
	n.jugador.reiniciar()
	n.jugador.global_position = pos - Vector3(0, 1.6, 0)
	n.jugador.rotation.y = atan2(-d.x, -d.z)
	n.jugador.cabeza.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
func _c() -> void:
	for i in 20:
		await process_frame
	var n := current_scene
	var c: Sky3D = n.cielo
	var f: Fosa = n.fosa
	var t: Terreno = n.terreno
	c.game_time_enabled = false
	n._hud.visible = false
	n.manos.visible = false
	n.jugador.set_physics_process(false)
	var m: Dictionary = f.miradores[0]
	var d := f.despertar
	var h := func(x: float, z: float) -> float: return t.altura(x, z)
	# Al filo, junto a la fosa: mirando al otro lado y hacia abajo.
	var mejor := Vector2.ZERO
	for q in Canon.borde_norte():
		if q.distance_to(Vector2(215, 175)) < mejor.distance_to(Vector2(215, 175)):
			mejor = q
	var info := Canon.cerca_del_eje(mejor)
	var norte: Vector2 = info[2]
	var pie := mejor + norte * 1.5
	var abismo_pos := Vector3(pie.x, t.altura(pie.x, pie.y) + 1.6, pie.y)
	var lejos := mejor - norte * 260.0
	var abismo_mira := Vector3(lejos.x, abismo_pos.y - 230.0, lejos.y)
	var vistas := [
		["borde", m.pos, m.mira],
		["cerca", d + Vector3(1.0, 1.4, 1.2), d + Vector3(-0.8, -0.3, -0.5)],
		["cenital", d + Vector3(0.3, 6.0, 0.4), d + Vector3(0.0, 0.0, 0.0)],
		["camino", Vector3(398, h.call(398, 236) + 1.6, 236), Vector3(330, h.call(398, 236) - 120, 420)],
		["abismo", abismo_pos, abismo_mira],
		["fosa_y_canon", Vector3(175, h.call(175, 120) + 6.0, 120), Vector3(205, 0, 260)],
	]
	for v in vistas:
		c.current_time = 15.5
		_poner(n, v[1], v[2])
		await create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		n._captura("fosa_" + v[0])
	quit()
