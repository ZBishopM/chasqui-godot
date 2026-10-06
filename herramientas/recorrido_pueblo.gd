extends SceneTree
## Recorrido del pueblo sin el MCP: abre el nivel 1, espera a que cargue, pasa por los miradores (Nivel1.capturar_recorrido)
## y deja capturas/pueblo_<n>_<mirador>.png con FPS, primitivas y llamadas de dibujo de cada uno. Necesita ventana (no
## --headless, que no dibuja).
##   godot.console.exe --path . --script res://herramientas/recorrido_pueblo.gd
##   godot.console.exe --path . --script res://herramientas/recorrido_pueblo.gd -- 17.5   (a otra hora)
##   godot.console.exe --path . --script res://herramientas/recorrido_pueblo.gd -- 10.5 casa,patio   (solo esos)
##   godot.console.exe --path . --script res://herramientas/recorrido_pueblo.gd -- 15 patio,vista lluvia   (lloviendo)


func _initialize() -> void:
	change_scene_to_file("res://escenas/nivel1.tscn")
	_correr.call_deferred()


func _correr() -> void:
	for i in 20:
		await process_frame
	var hora := 10.5
	var solo := PackedStringArray()
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		hora = float(args[0])
	if args.size() > 1:
		solo = args[1].split(",")
	var nivel := current_scene
	if args.size() > 2 and args[2] == "lluvia":
		nivel.lluvia.poner(1.0)
		for i in 30:
			await process_frame
	print(await nivel.capturar_recorrido(hora, solo))
	quit()
