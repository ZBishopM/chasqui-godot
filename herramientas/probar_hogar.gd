extends "res://herramientas/probar_camino.gd"
## Prueba del hogar del Chasqui sin ventana: abre el nivel 1 y maneja al Jugador.
##   godot.console.exe --headless --path . --fixed-fps 60 --script res://herramientas/probar_hogar.gd
## 1. Entra por la portada del cerco, cruza el patio y pasa la puerta de la casa: ¿llega al fondo, sobre el piso?
## 2. Sale, sube a los fardos de junto a la puerta y de ahi al alero y al techo: ¿hasta que altura llega sobre el piso?


func _correr() -> void:
	for i in 10:
		await process_frame
	nivel = current_scene
	j = nivel.jugador
	var h: Hogar = nivel.hogar
	var local := func(x: float, z: float) -> Vector2:
		var p: Vector3 = h._marco * Vector3(x, 0.0, z)
		return Vector2(p.x, p.z)
	var piso: float = h._tapa
	var fuera: Vector2 = local.call(-12.0, Hogar.PORTADA_Z)
	j.reiniciar()
	j.global_position = Vector3(fuera.x, nivel.terreno.altura(fuera.x, fuera.y) + 0.5, fuera.y)
	for i in 10:
		await physics_frame
	var entrar := PackedVector2Array([local.call(-10.0, Hogar.PORTADA_Z), local.call(-6.0, Hogar.PORTADA_Z), local.call(0.0, 4.0), local.call(0.0, 0.5), local.call(0.0, -2.5), local.call(-0.3, -4.0)])
	var r: Array = await _seguir(entrar, func(_p: Vector3, _k: int) -> float: return piso, 40.0, 0.8)
	var lineas: PackedStringArray = []
	lineas.append("CASA: %s en %.0f s · %d atascos %s · pies a %.2f m del piso, %.1f m bajo el piso como mucho" % [
		"entra" if r[0] else "NO entra", r[1], (r[2] as PackedStringArray).size(), " ".join(r[2]), j.global_position.y - piso, -float(r[3])])
	# Hasta lo alto de la pila de fardos (los atascos de por medio los salta _seguir).
	var pila := PackedVector2Array([local.call(0.0, -2.5), local.call(0.0, 1.0), local.call(2.9, 1.8), local.call(2.9, 0.45), local.call(2.9, -0.45)])
	var ok: Array = await _seguir(pila, func(_p: Vector3, _k: int) -> float: return piso, 30.0, 0.5)
	var en_pila := j.global_position.y - piso
	# Desde la pila, de cara a la casa: adelante y un salto al alero; luego sigue techo arriba.
	var alto := -INF
	var colgado := 0
	var hacia: Vector3 = h._marco * Vector3(2.9, 0.0, -4.0)
	Input.action_press("adelante")
	for i in 240:
		await physics_frame
		var p := j.global_position
		if j.estado == Jugador.Estado.NORMAL:
			j.rotation.y = atan2(-(hacia.x - p.x), -(hacia.z - p.z))
		if i == 30:
			Input.action_press("saltar")
		elif i == 33:
			Input.action_release("saltar")
		# Colgado del alero: soltar y volver a pulsar adelante sube a pulso (como haria quien juega).
		if j.estado == Jugador.Estado.COLGADO:
			colgado += 1
			if colgado == 5:
				Input.action_release("adelante")
			elif colgado == 8:
				Input.action_press("adelante")
		alto = maxf(alto, p.y - piso)
	_soltar_todo()
	lineas.append("TECHO: %s a la pila (pies a %.2f m) · lo mas alto %.2f m sobre el piso (alero a %.1f m, cumbrera a %.1f m) (%s) -> %s" % [
		"llega" if ok[0] else "NO llega", en_pila, alto, Hogar.CASA.y, Hogar.CASA.y + Hogar.CASA.z * 0.5 * tan(deg_to_rad(40.0)),
		"colgandose del alero" if colgado > 0 else "de un salto", "sube al techo" if alto > Hogar.CASA.y + 0.5 else "NO sube"])
	print("\n".join(lineas))
	quit()
