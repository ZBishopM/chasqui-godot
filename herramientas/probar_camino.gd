extends SceneTree
## Prueba de la zona 2 sin ventana: abre el nivel 1 y maneja al Jugador.
##   godot.console.exe --headless --path . --fixed-fps 60 --script res://herramientas/probar_camino.gd
## 1. Recorre la calzada entera del pueblo al templo andando (gira hacia el siguiente punto, salta si se atasca) y mide:
##    si llega, cuanto tarda, donde se atasco y si alguna vez quedo por debajo de la losa (se colo por un hueco).
## 2. Sube el templo: escalinatas de las tres terrazas, cruza el Inti Wasi hasta el borde este; y sube el ushnu.
## 3. Se tira al pozo: ¿cae a la camara?; luego sigue la cueva hasta la boca: ¿sale a la ladera?

const TECLAS := ["adelante", "atras", "izquierda", "derecha", "saltar", "esprintar", "agacharse"]

var nivel: Node
var j: Jugador


func _initialize() -> void:
	change_scene_to_file("res://escenas/nivel1.tscn")
	_correr.call_deferred()


func _correr() -> void:
	for i in 10:
		await process_frame
	nivel = current_scene
	j = nivel.jugador
	var lineas: PackedStringArray = []
	lineas.append(await _calzada())
	lineas.append(await _templo())
	lineas.append(await _pozo_y_cueva())
	print("\n".join(lineas))
	quit()


func _soltar_todo() -> void:
	for a: String in TECLAS:
		Input.action_release(a)


## Sigue la lista de puntos (mundo, xz) andando; cada punto vale a `radio` m. Devuelve [llego, segundos, atascos, minimo bajo el suelo esperado].
func _seguir(puntos: PackedVector2Array, esperado: Callable, limite_s: float, radio := 2.5) -> Array:
	var k := 0
	var t := 0.0
	var atascos: PackedStringArray = []
	var ultimo := j.global_position
	var quieto := 0.0
	var peor := 0.0
	Input.action_press("adelante")
	while k < puntos.size() and t < limite_s:
		await physics_frame
		t += 1.0 / 60.0
		var p := j.global_position
		var meta := puntos[k]
		if Vector2(p.x, p.z).distance_to(meta) < radio:
			k += 1
			continue
		var d := Vector2(meta.x - p.x, meta.y - p.z)
		j.rotation.y = atan2(-d.x, -d.y)
		var e: float = esperado.call(p, k)
		peor = minf(peor, p.y - e)
		if p.distance_to(ultimo) > 0.6:
			ultimo = p
			quieto = 0.0
		else:
			quieto += 1.0 / 60.0
			if quieto > 0.8:
				atascos.append("(%.0f, %.0f, %.0f)" % [p.x, p.y, p.z])
				Input.action_press("saltar")
				await physics_frame
				await physics_frame
				Input.action_release("saltar")
				quieto = 0.0
				if atascos.size() > 25:
					break
	_soltar_todo()
	return [k >= puntos.size(), t, atascos, peor]


func _calzada() -> String:
	var c: Camino = nivel.camino
	var pts := PackedVector2Array()
	for i in range(0, c._pts.size(), 2):
		pts.append(c._pts[i])
	var p0 := c._p3(0, 0.0, 0.3)
	j.reiniciar()
	j.global_position = p0
	for i in 10:
		await physics_frame
	var esperado := func(p: Vector3, k: int) -> float:
		return c._ys[mini(k * 2, c._ys.size() - 1)] - 1.5
	var r: Array = await _seguir(pts, esperado, 400.0)
	return "CALZADA: %s en %.0f s (%.0f m) · %d atascos %s · lo mas bajo respecto a la losa: %.1f m" % [
		"llega al templo" if r[0] else "NO llega", r[1], c._dist[c._dist.size() - 1], (r[2] as PackedStringArray).size(),
		" ".join(r[2] as PackedStringArray).substr(0, 300), r[3]]


## Sigue al jugador desde donde lo dejo la calzada (al pie del templo).
func _templo() -> String:
	var t: Templo = nivel.templo
	var l := func(x: float, z: float) -> Vector2:
		var w: Vector3 = t._base * Vector3(x, 0.0, z)
		return Vector2(w.x, w.z)
	var cima: float = t._tapa + 9.6
	var ruta := PackedVector2Array([l.call(0.0, 30.0), l.call(-14.0, 20.0), l.call(-14.0, 5.0), l.call(0.0, 4.0), l.call(0.0, -1.5),
		l.call(0.0, -6.0), l.call(0.0, -8.0), l.call(0.0, -11.0), l.call(0.0, -15.0), l.call(0.0, -18.6)])
	var nada := func(p: Vector3, k: int) -> float:
		return -1000.0
	var r: Array = await _seguir(ruta, nada, 60.0)
	var arriba := j.global_position.y
	var linea := "TEMPLO: %s en %.0f s · %d atascos %s · pies a %.1f m (cima %.1f m)" % ["llega al borde este de la cima" if r[0] and absf(arriba - cima) < 0.3 else "NO llega arriba", r[1],
		(r[2] as PackedStringArray).size(), " ".join(r[2] as PackedStringArray).substr(0, 200), arriba, cima]
	# Ushnu: baja por el templo y sube por la escalinata oeste del ushnu.
	var u := Templo.USHNU
	j.reiniciar()
	var ruta2 := PackedVector2Array([l.call(0.0, -6.0), l.call(0.0, 0.0), l.call(u.x - 12.0, u.y), l.call(u.x - 1.0, u.y), l.call(u.x + 1.5, u.y)])
	var r2: Array = await _seguir(ruta2, nada, 60.0)
	var cima_u: float = t._tapa + Templo.USHNU_ALTO * 3.0
	return linea + "\nUSHNU: %s en %.0f s · %d atascos · pies a %.1f m (cima %.1f m)" % ["sube" if r2[0] and absf(j.global_position.y - cima_u) < 0.3 else "NO sube", r2[1], (r2[2] as PackedStringArray).size(), j.global_position.y, cima_u]


func _pozo_y_cueva() -> String:
	var c: Camino = nivel.camino
	j.reiniciar()
	j.global_position = Vector3(Camino.POZO.x, c._h(Camino.POZO.x, Camino.POZO.y) + 1.1, Camino.POZO.y)   # dentro del brocal, bajo el travesano
	var fondo: float = c._info["piso_pozo"]
	var t := 0.0
	while t < 6.0:
		await physics_frame
		t += 1.0 / 60.0
		if j.is_on_floor() and t > 0.5:
			break
	var en_camara := absf(j.global_position.y - fondo) < 0.6
	var linea := "POZO: cae %.1f m y queda a %.2f m del piso de la camara (%s)" % [
		c._h(Camino.POZO.x, Camino.POZO.y) + 1.1 - j.global_position.y, j.global_position.y - fondo, "en la camara" if en_camara else "NO"]
	var pts := PackedVector2Array()
	for p: Vector2 in Camino.CUEVA.slice(1):
		pts.append(p)
	var esperado := func(p: Vector3, k: int) -> float:
		return fondo - 3.5
	var r: Array = await _seguir(pts, esperado, 90.0)
	var p := j.global_position
	var fuera := absf(p.y - c._h(p.x, p.z)) < 0.6
	return linea + "\nCUEVA: %s en %.0f s · %d atascos %s · al final en (%.0f, %.1f, %.0f), %s" % [
		"llega a la boca" if r[0] else "NO llega", r[1], (r[2] as PackedStringArray).size(), " ".join(r[2] as PackedStringArray).substr(0, 200),
		p.x, p.y, p.z, "sobre el suelo de la ladera" if fuera else "NO esta fuera"]
