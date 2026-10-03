extends SceneTree
## Hornea el relieve de Vilcashuaman para el juego a partir del recorte de recortar_dem.gd:
##   assets/relieve/vilcas_lejos.res — todo el recorte (~39 km) a 30 m: el fondo.
##   assets/relieve/vilcas_cerca.res — 1,2 km alrededor del pueblo a 2 m: lo jugable, con detalle fino.
##   godot.console.exe --headless --path . --script res://herramientas/hornear_relieve.gd
## Ambos son Image FORMAT_RF (float32): el importador de texturas los pasaria a media precision y a 3500 m eso son
## metros de error. Alturas relativas al centro (y = 0 en la plaza). Ejes: +X este, -Z norte (como el sol de Sky3D).

const FUENTE := "res://assets/relieve/fuente/vilcashuaman"
const LEJOS := "res://assets/relieve/vilcas_lejos.res"
const CERCA := "res://assets/relieve/vilcas_cerca.res"
const CERCA_LADO := 1200.0   # m
const CERCA_PASO := 2.0      # m
const DETALLE_M := 1.4       # m de relieve fino (lomas, surcos) que el modelo de 30 m no tiene
const BORDE_M := 80.0        # el detalle se apaga en este margen para coser con el relieve de 30 m


func _initialize() -> void:
	var dem := Image.load_from_file(ProjectSettings.globalize_path(FUENTE + ".exr"))
	dem.convert(Image.FORMAT_RF)   # el EXR se carga como RGBF (tres canales)
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(FUENTE + ".json")))
	var n := dem.get_width()
	var datos := dem.get_data().to_float32_array()
	var centro: Array = meta.centro_px
	var h0: float = meta.altura_centro_m
	var mx: float = meta.m_por_px_x
	var mz: float = meta.m_por_px_z

	# Lejos: el recorte entero, relativo a la plaza.
	var lejos := PackedFloat32Array()
	lejos.resize(n * n)
	for i in n * n:
		lejos[i] = datos[i] - h0
	var img_l := Image.create_from_data(n, n, false, Image.FORMAT_RF, lejos.to_byte_array())
	img_l.set_meta("m_por_px", Vector2(mx, mz))
	img_l.set_meta("centro_px", Vector2(centro[0], centro[1]))
	print("lejos: %d px, %.1f x %.1f m por px -> %s" % [n, mx, mz, error_string(ResourceSaver.save(img_l, LEJOS, ResourceSaver.FLAG_COMPRESS))])

	# Cerca: bicubica sobre el modelo de 30 m + ruido fractal que se apaga en el borde.
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
			var borde := minf(minf(x + mitad, mitad - x), minf(z + mitad, mitad - z))
			var peso := smoothstep(0.0, BORDE_M, borde)
			cerca[j * m + i] = _bicubica(datos, n, u, v) - h0 + ruido.get_noise_2d(x, z) * DETALLE_M * peso
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
