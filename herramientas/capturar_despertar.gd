extends SceneTree
## Tira de cuadros del despertar del oro (brazos normales -> oro) en el banco, en una sola imagen de 4 x 2:
##   godot.console.exe --path . --fixed-fps 20 --script res://herramientas/capturar_despertar.gd
## --fixed-fps hace que cada cuadro avance lo mismo aunque la maquina dibuje lento (asi la tira sale a tiempo).
## Deja capturas/despertar_oro.png (sin HUD; cuadros cada DESPERTAR_SEG / 7 s, del primero al ultimo).


func _initialize() -> void:
	change_scene_to_file("res://escenas/banco.tscn")
	_correr.call_deferred()


func _correr() -> void:
	for i in 20:
		await process_frame
	var banco := current_scene
	var manos: Manos = banco.manos
	banco._hud.visible = false
	manos.venas_base = 0.0
	for i in 20:
		await process_frame
	manos.despertar_oro()
	var cuadros: Array[Image] = []
	var n := 8
	for k in n:
		await RenderingServer.frame_post_draw
		var img := root.get_viewport().get_texture().get_image()
		img.resize(img.get_width() / 2, img.get_height() / 2)
		cuadros.append(img)
		if k < n - 1:
			await create_timer(Manos.DESPERTAR_SEG / float(n - 1)).timeout
	var w := cuadros[0].get_width()
	var h := cuadros[0].get_height()
	var hoja := Image.create(w * 4, h * 2, false, cuadros[0].get_format())
	for k in n:
		hoja.blit_rect(cuadros[k], Rect2i(0, 0, w, h), Vector2i((k % 4) * w, (k / 4) * h))
	var carpeta := ProjectSettings.globalize_path("res://capturas")
	DirAccess.make_dir_recursive_absolute(carpeta)
	hoja.save_png(carpeta + "/despertar_oro.png")
	print("capturas/despertar_oro.png")
	quit()
