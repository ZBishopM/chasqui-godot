extends "res://herramientas/probar_camino.gd"
## Prueba de la fosa comun sin ventana: abre el nivel 1 y corre la cinematica del despertar.
##   godot.console.exe --headless --path . --fixed-fps 60 --script res://herramientas/probar_fosa.gd
## 1. La cinematica entera (F4): ¿termina?, ¿los hilos llegan a las munecas?, ¿queda el estado final (venas de oro en
##    reposo, guion suelto, control de vuelta, de pie sobre el monton, tormenta normal)?
## 2. Otra vez, saltandola a los 20 s: ¿el mismo estado final?
## 3. Desde el monton sale de la fosa andando por los escalones (y saltando si se atasca) hasta el sendero.


func _correr() -> void:
	for i in 10:
		await process_frame
	nivel = current_scene
	j = nivel.jugador
	var lineas: PackedStringArray = []
	lineas.append(await _cinematica(-1.0))
	lineas.append(await _cinematica(20.0))
	lineas.append(await _salir())
	print("\n".join(lineas))
	quit()


## Corre la cinematica (saltandola en `saltar_en` s si es > 0) y describe como queda.
func _cinematica(saltar_en: float) -> String:
	var c: CinematicaDespertar = nivel.despertar_en_fosa()
	var fin := [false]
	c.terminada.connect(func() -> void: fin[0] = true)
	var s := 0.0
	var hilos := ""
	while not fin[0] and s < 45.0:
		await process_frame
		s += 1.0 / 60.0
		if saltar_en > 0.0 and s >= saltar_en and not fin[0]:
			c.saltar()
		if hilos == "" and c != null and is_instance_valid(c) and c.t >= 27.0:
			var lejos := 0.0
			for h: HiloSangre in c._hilos:
				var lado := ".L" if c._hilos.find(h) % 2 == 0 else ".R"
				lejos = maxf(lejos, h.fin.distance_to(nivel.manos.punto_mano(lado)))
			hilos = "%d hilos (de %.1f a %.1f m), entran a %.2f m de la muneca como mucho; mortajas con sangre %.2f" % [
				c._hilos.size(), _min_rec(c._hilos), _max_rec(c._hilos), lejos, float(nivel.fosa.cuerpos[0].get_instance_shader_parameter("sangre"))]
	# Que caiga y se asiente sobre el monton.
	for i in 60:
		await physics_frame
	var m: Manos = nivel.manos
	var piso: float = nivel.fosa.despertar.y
	return "%s: %s en %.1f s · %s · venas_base %.2f · guion %s · fisica %s · ojos %.2f m · %s, pies %.2f m sobre lo alto del monton · tormenta %s, %s" % [
		"CINEMATICA" if saltar_en < 0.0 else "SALTADA a %.0f s" % saltar_en, "termina" if fin[0] else "NO termina", s,
		hilos if hilos != "" else "(sin medir hilos)", m.venas_base, "suelto" if not m.en_guion() else "PEGADO",
		"si" if j.is_physics_processing() else "NO", j.cabeza.position.y, "en el suelo" if j.is_on_floor() else "EN EL AIRE",
		j.global_position.y - piso, nivel.tormenta.modo, "activa" if nivel.tormenta.activa else "parada"]


func _min_rec(hs: Array[HiloSangre]) -> float:
	var r := INF
	for h in hs:
		r = minf(r, h.recorrido)
	return r


func _max_rec(hs: Array[HiloSangre]) -> float:
	var r := 0.0
	for h in hs:
		r = maxf(r, h.recorrido)
	return r


## Del monton por la escalera de piedras (saltando de una a otra), borde arriba y al sendero.
func _salir() -> String:
	var f: Fosa = nivel.fosa
	var piedras := 0
	var t := 0.0
	for e: Vector3 in f.escalones:
		if e.y < j.global_position.y - 0.3:
			continue   # bajo el monton, o ya por debajo
		var ok := false
		var s := 0.0
		Input.action_press("adelante")
		while s < 6.0:
			await physics_frame
			s += 1.0 / 60.0
			var p := j.global_position
			var d := Vector2(e.x - p.x, e.z - p.z)
			if d.length() < 0.45 and p.y > e.y - 0.1:
				ok = true
				break
			if j.estado == Jugador.Estado.NORMAL:
				j.rotation.y = atan2(-d.x, -d.y)
			if j.is_on_floor() and d.length() < 1.4 and e.y > p.y + 0.15:
				Input.action_press("saltar")
				await physics_frame
				await physics_frame
				Input.action_release("saltar")
		_soltar_todo()
		t += s
		if not ok:
			break
		piedras += 1
	var dir := (Fosa.CAMINO - Fosa.CENTRO).normalized()
	var r: Array = await _seguir(PackedVector2Array([Fosa.CENTRO + dir * (Fosa.BORDE + 2.5), Fosa.SENDERO[3]]), func(p: Vector3, _k: int) -> float: return p.y, 30.0, 0.9)
	var p := j.global_position
	var fuera := Vector2(p.x - Fosa.CENTRO.x, p.z - Fosa.CENTRO.y).length()
	return "SALIR: sube %d piedras (de %d) en %.0f s; %s en %.0f s mas · %d atascos %s · a %.1f m del centro, pies %.2f m sobre el terreno" % [
		piedras, f.escalones.size(), t, "sale" if r[0] else "NO sale", r[1], (r[2] as PackedStringArray).size(), " ".join(r[2]), fuera, p.y - nivel.terreno.altura(p.x, p.z)]
