extends SceneTree
## Prueba del parkour (N4) sin ventana: arma una pista de muros y huecos, maneja al Jugador simulando teclas y mide.
##   godot.console.exe --headless --path . --script res://herramientas/probar_parkour.gd
## 1. Muros de distinta altura: corre hacia el muro, salta, ¿se agarra?, ¿sube a pulso? (y a que altura queda).
## 2. Huecos entre tejados a 2,5 m: esprinta y salta en el borde, ¿llega al otro lado?
## 3. Por la cornisa: colgado, se desplaza 1 s a la derecha.

const MUROS := [0.8, 1.2, 1.5, 2.0, 2.3, 2.5, 3.0, 3.3, 3.5, 3.8, 4.2]
const HUECOS := [2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
const TECLAS := {"adelante": KEY_W, "atras": KEY_S, "izquierda": KEY_A, "derecha": KEY_D, "saltar": KEY_SPACE, "esprintar": KEY_SHIFT, "agacharse": KEY_CTRL}

var mundo: Node3D


func _initialize() -> void:
	_correr.call_deferred()


func _correr() -> void:
	for nombre: String in TECLAS:
		if not InputMap.has_action(nombre):
			InputMap.add_action(nombre)
	mundo = Node3D.new()
	root.add_child(mundo)
	_caja(Vector3(0, -0.5, 0), Vector3(400, 1, 400))
	var lineas: PackedStringArray = ["MUROS (alto del muro: agarra / sube / pies arriba)"]
	for i in MUROS.size():
		lineas.append(await _muro(i, MUROS[i]))
	lineas.append("HUECOS entre plataformas de 2,5 m, esprintando (hueco: resultado)")
	for i in HUECOS.size():
		lineas.append(await _hueco(i, HUECOS[i]))
	lineas.append(await _cornisa())
	print("\n".join(lineas))
	quit()


func _caja(centro: Vector3, tam: Vector3) -> void:
	var c := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = tam
	col.shape = b
	c.add_child(col)
	c.position = centro
	mundo.add_child(c)


func _jugador(pos: Vector3) -> Jugador:
	var j := Jugador.new()
	j.position = pos
	mundo.add_child(j)
	for k in 8:
		await physics_frame
	return j


func _frames(n: int) -> void:
	for k in n:
		await physics_frame


func _pulsar(accion: String) -> void:
	Input.action_press(accion)
	await physics_frame
	await physics_frame
	Input.action_release(accion)


func _muro(i: int, alto: float) -> String:
	var x := 20.0 + i * 12.0
	_caja(Vector3(x, alto * 0.5, -4.0), Vector3(5.0, alto, 2.0))   # cara en z = -3
	var j: Jugador = await _jugador(Vector3(x, 0.05, -1.0))
	Input.action_press("adelante")
	await _pulsar("saltar")
	var agarra := false
	var directo := false
	var pico := 0.0
	for k in 90:
		await physics_frame
		pico = maxf(pico, j.global_position.y)
		if j.estado == Jugador.Estado.COLGADO:
			agarra = true
			break
		if j.estado == Jugador.Estado.SUBIENDO:
			directo = true
			break
		if j.is_on_floor() and j.global_position.y > alto - 0.1:
			break
	Input.action_release("adelante")
	var sube := false
	var arriba := 0.0
	if not agarra:
		await _frames(50)
		var encima := j.is_on_floor() and absf(j.global_position.y - alto) < 0.15
		j.queue_free()
		if directo:
			return "  %.1f m: sube sin colgarse: %s" % [alto, "arriba" if encima else "NO"]
		var r := "se sube de un salto" if encima else ("la salta por encima" if j.global_position.z < -5.0 else "no llega")
		return "  %.1f m: %s   (pies subieron a %.2f)" % [alto, r, pico]
	if agarra:
		await _frames(10)
		await _pulsar("saltar")
		await _frames(50)
		arriba = j.global_position.y
		sube = j.estado == Jugador.Estado.NORMAL and absf(arriba - alto) < 0.15
	j.queue_free()
	return "  %.1f m: %s / %s / %.2f m   (pies subieron a %.2f)" % [alto, "agarra" if agarra else "no", "sube" if sube else "no", arriba, pico]


func _hueco(i: int, hueco: float) -> String:
	var x := -20.0 - i * 12.0
	var alto := 2.5
	_caja(Vector3(x, alto * 0.5, 10.0), Vector3(4.0, alto, 20.0))                      # de z = 0 a 20
	_caja(Vector3(x, alto * 0.5, -hueco - 10.0), Vector3(4.0, alto, 20.0))              # de z = -hueco a -hueco-20
	var j: Jugador = await _jugador(Vector3(x, alto + 0.05, 14.0))
	Input.action_press("adelante")
	Input.action_press("esprintar")
	var salto := false
	for k in 240:
		await physics_frame
		if not salto and j.global_position.z < 0.35:
			Input.action_press("saltar")
			salto = true
		elif salto:
			Input.action_release("saltar")
		if salto and j.is_on_floor() and j.global_position.z < -0.5:
			break
		if j.global_position.y < 0.5 or j.estado == Jugador.Estado.COLGADO:
			break
	Input.action_release("adelante")
	Input.action_release("esprintar")
	var r := "cae"
	if j.estado == Jugador.Estado.COLGADO:
		r = "no llega, se agarra al borde"
	elif j.global_position.y > alto - 0.2 and j.global_position.z < -hueco:
		r = "llega (aterriza a %.1f m del borde)" % (-j.global_position.z - hueco)
	j.queue_free()
	return "  %.0f m: %s" % [hueco, r]


func _cornisa() -> String:
	var x := 0.0
	var alto := 3.0
	_caja(Vector3(x, alto * 0.5, -40.0), Vector3(12.0, alto, 2.0))   # cara en z = -39
	var j: Jugador = await _jugador(Vector3(x, 0.05, -37.6))
	Input.action_press("adelante")
	await _pulsar("saltar")
	for k in 90:
		await physics_frame
		if j.estado == Jugador.Estado.COLGADO:
			break
	Input.action_release("adelante")
	if j.estado != Jugador.Estado.COLGADO:
		return "CORNISA: no se agarro"
	await _frames(10)
	var x0 := j.global_position.x
	Input.action_press("derecha")
	await _frames(60)
	Input.action_release("derecha")
	var recorrido := j.global_position.x - x0
	# Hasta el final del muro (x = 6): no debe pasarse.
	Input.action_press("derecha")
	await _frames(400)
	Input.action_release("derecha")
	var fin := j.global_position.x
	await _pulsar("agacharse")
	await _frames(60)
	return "CORNISA: 1 s a la derecha = %.2f m · se para en x = %.2f (el muro acaba en 6,0) · al soltarse cae al suelo: %s" % [
		recorrido, fin, "si" if j.is_on_floor() and j.global_position.y < 0.2 else "no"]
