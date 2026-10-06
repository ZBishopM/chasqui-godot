extends SceneTree
## Tira de cuadros de la cinematica del despertar en la fosa (CinematicaDespertar), con ventana (Vulkan):
##   godot --path . --fixed-fps 60 --resolution 960x540 --script res://herramientas/capturar_fosa.gd
## Guarda capturas/fosa_cine_<seg>.png en los instantes de MOMENTOS (con --fixed-fps el reloj es el del juego). Entre
## captura y captura no se dibuja (con Vulkan por software cada cuadro tarda segundos): solo los ultimos cuadros antes de
## cada una, para que se asienten las sombras.

const MOMENTOS := [2.0, 3.65, 8.62, 11.0, 13.4, 16.0, 21.0, 23.5, 26.0, 28.5, 30.0, 31.2, 32.33, 33.2, 35.0, 37.8]


func _initialize() -> void:
	change_scene_to_file("res://escenas/nivel1.tscn")
	_correr.call_deferred()


func _correr() -> void:
	for i in 30:
		await process_frame
	var nivel := current_scene
	var c: CinematicaDespertar = nivel.despertar_en_fosa()
	var k := 0
	while k < MOMENTOS.size() and is_instance_valid(c):
		RenderingServer.render_loop_enabled = c.t >= MOMENTOS[k] - 0.06
		await process_frame
		if c.t >= MOMENTOS[k]:
			await RenderingServer.frame_post_draw
			print("captura ", nivel._captura("fosa_cine_%04.1f" % MOMENTOS[k]), " t=%.2f" % c.t)
			k += 1
	quit()
