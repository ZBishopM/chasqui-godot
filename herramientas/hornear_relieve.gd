extends SceneTree
## Hornea el relieve de Vilcashuaman para el juego a partir del recorte de recortar_dem.gd:
##   assets/relieve/vilcas_lejos.res — todo el recorte (~39 km) a 30 m: el fondo.
##   assets/relieve/vilcas_cerca.res — 1,2 km alrededor del pueblo a 2 m: lo jugable, con detalle fino.
##   godot.console.exe --headless --path . --script res://herramientas/hornear_relieve.gd
## Ambos son Image FORMAT_RF (float32): el importador de texturas los pasaria a media precision y a 3500 m eso son
## metros de error. Alturas relativas al centro (y = 0 en la plaza). Ejes: +X este, -Z norte (como el sol de Sky3D).
##
## Relieve quebrado (_quebrar): el modelo real es suave para un juego; se exagera en vertical respecto a la plaza, poco en
## la zona jugable (EXAGERACION_CERCA) y mucho desde unos km (EXAGERACION_LEJOS): los cerros se levantan de golpe sobre
## los valles, que se ahondan. Lejos se anaden riscos (ruido de crestas). Dos abras (ABRAS): hacia la puesta de sol del
## 21 de junio vista desde el borde oeste del pueblo (el hogar del Chasqui) y hacia la salida del sol vista desde el
## templo, los cerros se rebajan: el sol se pone y sale en un hueco entre montanas. En la zona jugable el detalle fino
## crece con la pendiente: laderas quebradas, llanos edificables.

const FUENTE := "res://assets/relieve/fuente/vilcashuaman"
const LEJOS := "res://assets/relieve/vilcas_lejos.res"
const CERCA := "res://assets/relieve/vilcas_cerca.res"
const CERCA_LADO := 1200.0   # m
const CERCA_PASO := 2.0      # m
const DETALLE_M := Vector2(1.0, 2.6)   # m de relieve fino (lomas, surcos, piedras) en lo llano / en las laderas
const BORDE_M := 80.0        # el detalle se apaga en este margen para coser con el relieve de 30 m
const EXAGERACION_CERCA := 1.4
const EXAGERACION_LEJOS := 2.6
const EXAGERACION_DESDE := Vector2(700.0, 6000.0)   # m de la plaza: de cerca a lejos
const RISCOS_M := 220.0                              # m de los riscos (ruido de crestas) lejos
const RISCOS_DESDE := Vector2(900.0, 5000.0)
## Abras: [origen (x, z), acimut (grados desde el norte), semiancho (grados), desde, hasta (m del origen), cuanto se
## rebajan los cerros en la linea (0..1)]. La puesta del 21 de junio es a 294,2 grados y la salida a 65,8; como el sol
## baja y sube en diagonal, se ve ponerse algo al sur de su acimut en el horizonte.
const ABRAS := [
	[Vector2(-150, 40), 292.5, 5.0, 4000.0, 15000.0, 0.42],
	[Vector2(546, 250), 65.8, 6.0, 350.0, 16000.0, 0.62],
]

var _riscos: FastNoiseLite


## Altura quebrada (relativa a la plaza) del punto x, z (m) con altura real h (relativa a la plaza).
func _quebrar(x: float, z: float, h: float) -> float:
	var r := Vector2(x, z).length()
	var f := lerpf(EXAGERACION_CERCA, EXAGERACION_LEJOS, smoothstep(EXAGERACION_DESDE.x, EXAGERACION_DESDE.y, r))
	var q := h * f
	var risco := _riscos.get_noise_2d(x, z) * 0.5 + 0.5
	q += RISCOS_M * risco * risco * smoothstep(RISCOS_DESDE.x, RISCOS_DESDE.y, r)
	if q > 0.0:
		for abra: Array in ABRAS:
			var o: Vector2 = abra[0]
			var d := Vector2(x - o.x, z - o.y)
			var ro := d.length()
			var desde: float = abra[3]
			var hasta: float = abra[4]
			if ro < desde * 0.5 or ro > hasta * 1.3:
				continue
			# Acimut desde el norte (-z) hacia el este (+x).
			var az := rad_to_deg(atan2(d.x, -d.y))
			var da := wrapf(az - float(abra[1]), -180.0, 180.0) / float(abra[2])
			var en := exp(-da * da) * smoothstep(desde * 0.5, desde, ro) * (1.0 - smoothstep(hasta, hasta * 1.3, ro))
			q *= 1.0 - float(abra[5]) * en
	return q


func _initialize() -> void:
	_riscos = FastNoiseLite.new()
	_riscos.seed = 1471
	_riscos.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_riscos.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_riscos.fractal_octaves = 5
	_riscos.frequency = 1.0 / 1400.0
	var dem := Image.load_from_file(ProjectSettings.globalize_path(FUENTE + ".exr"))
	dem.convert(Image.FORMAT_RF)   # el EXR se carga como RGBF (tres canales)
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(FUENTE + ".json")))
	var n := dem.get_width()
	var datos := dem.get_data().to_float32_array()
	var centro: Array = meta.centro_px
	var h0: float = meta.altura_centro_m
	var mx: float = meta.m_por_px_x
	var mz: float = meta.m_por_px_z

	# Lejos: el recorte entero, relativo a la plaza y quebrado.
	var lejos := PackedFloat32Array()
	lejos.resize(n * n)
	for j in n:
		var z := (j - float(centro[1])) * mz
		for i in n:
			lejos[j * n + i] = _quebrar((i - float(centro[0])) * mx, z, datos[j * n + i] - h0)
	var img_l := Image.create_from_data(n, n, false, Image.FORMAT_RF, lejos.to_byte_array())
	img_l.set_meta("m_por_px", Vector2(mx, mz))
	img_l.set_meta("centro_px", Vector2(centro[0], centro[1]))
	print("lejos: %d px, %.1f x %.1f m por px -> %s" % [n, mx, mz, error_string(ResourceSaver.save(img_l, LEJOS, ResourceSaver.FLAG_COMPRESS))])

	# Cerca: bicubica sobre el modelo de 30 m, quebrada como el fondo, + ruido fractal (mas en las laderas) que se apaga en
	# el borde.
	var ruido := FastNoiseLite.new()
	ruido.seed = 1532
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.frequency = 1.0 / 45.0
	ruido.fractal_type = FastNoiseLite.FRACTAL_FBM
	ruido.fractal_octaves = 4
	ruido.fractal_gain = 0.45
	var m := int(CERCA_LADO / CERCA_PASO) + 1
	var cerca := PackedFloat32Array()
	cerca.resize(m * m)
	var mitad := CERCA_LADO * 0.5
	for j in m:
		var z := -mitad + j * CERCA_PASO
		for i in m:
			var x := -mitad + i * CERCA_PASO
			var u := float(centro[0]) + x / mx
			var v := float(centro[1]) + z / mz
			cerca[j * m + i] = _quebrar(x, z, _bicubica(datos, n, u, v) - h0)
	var base := cerca.duplicate()
	for j in m:
		var z := -mitad + j * CERCA_PASO
		for i in m:
			var x := -mitad + i * CERCA_PASO
			var borde := minf(minf(x + mitad, mitad - x), minf(z + mitad, mitad - z))
			var peso := smoothstep(0.0, BORDE_M, borde)
			# Pendiente de la base (diferencias centrales a 2 pasos): el detalle es mayor en las laderas.
			var dx := base[j * m + mini(i + 2, m - 1)] - base[j * m + maxi(i - 2, 0)]
			var dz := base[mini(j + 2, m - 1) * m + i] - base[maxi(j - 2, 0) * m + i]
			var pend := Vector2(dx, dz).length() / (4.0 * CERCA_PASO)
			var amp := lerpf(DETALLE_M.x, DETALLE_M.y, smoothstep(0.08, 0.35, pend))
			cerca[j * m + i] = base[j * m + i] + ruido.get_noise_2d(x, z) * amp * peso
	var img_c := Image.create_from_data(m, m, false, Image.FORMAT_RF, cerca.to_byte_array())
	img_c.set_meta("paso_m", CERCA_PASO)
	print("cerca: %d px a %.0f m (%.0f m de lado), altura en el centro %.2f m -> %s" % [
		m, CERCA_PASO, CERCA_LADO, cerca[(m / 2) * m + m / 2], error_string(ResourceSaver.save(img_c, CERCA, ResourceSaver.FLAG_COMPRESS))])
	quit()


## Interpolacion bicubica (Catmull-Rom) del modelo en coordenadas de pixel fraccionarias.
func _bicubica(d: PackedFloat32Array, n: int, u: float, v: float) -> float:
	var x0 := int(floor(u))
	var y0 := int(floor(v))
	var fx := u - x0
	var fy := v - y0
	var filas := PackedFloat32Array([0, 0, 0, 0])
	for k in 4:
		var y := clampi(y0 - 1 + k, 0, n - 1)
		var p := PackedFloat32Array()
		for l in 4:
			p.append(d[y * n + clampi(x0 - 1 + l, 0, n - 1)])
		filas[k] = _cr(p[0], p[1], p[2], p[3], fx)
	return _cr(filas[0], filas[1], filas[2], filas[3], fy)


func _cr(a: float, b: float, c: float, d: float, t: float) -> float:
	return b + 0.5 * t * (c - a + t * (2.0 * a - 5.0 * b + 4.0 * c - d + t * (3.0 * (b - c) + d - a)))
