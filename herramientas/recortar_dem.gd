extends SceneTree
## Recorta del modelo de elevacion Copernicus GLO-30 (30 m, GeoTIFF de 1 x 1 grado) el cuadrado de terreno alrededor de
## Vilcashuaman y lo guarda como alturas en metros: assets/relieve/fuente/vilcashuaman.exr (+ .json con la
## georreferencia). La carpeta fuente/ no la importa Godot (.gdignore): el juego usa lo que hornea hornear_relieve.gd.
##   godot.console.exe --headless --path . --script res://herramientas/recortar_dem.gd
## Las piezas se bajan de https://copernicus-dem-30m.s3.amazonaws.com/ (sin cuenta) a _descargas/dem/:
##   Copernicus_DSM_COG_10_S14_00_W074_00_DEM.tif -> cop30_S14_W074.tif (y W075, la vecina del oeste).
## Lee solo lo que traen esas piezas: TIFF clasico little-endian, float32, bloques de 1024 px, Deflate + predictor 3
## (coma flotante). No hace falta GDAL.

const CENTRO := Vector2(-73.953, -13.653)   # lon, lat de Vilcashuaman (plaza)
const LADO_GRADOS := 0.36                   # ~39 km de lado
const PIEZAS := {"res://_descargas/dem/cop30_S14_W074.tif": -74.0, "res://_descargas/dem/cop30_S14_W075.tif": -75.0}
const SALIDA := "res://assets/relieve/fuente/vilcashuaman"
const M_POR_GRADO := 111320.0


func _initialize() -> void:
	var px := 1.0 / 3600.0
	var lon0 := CENTRO.x - LADO_GRADOS * 0.5
	var lat0 := CENTRO.y + LADO_GRADOS * 0.5   # borde norte
	var n := int(round(LADO_GRADOS * 3600.0))
	var alturas := PackedFloat32Array()
	alturas.resize(n * n)
	alturas.fill(NAN)
	for ruta: String in PIEZAS:
		_volcar(ProjectSettings.globalize_path(ruta), lon0, lat0, n, px, alturas)
	var faltan := 0
	var minimo := INF
	var maximo := -INF
	for h in alturas:
		if is_nan(h):
			faltan += 1
		else:
			minimo = minf(minimo, h)
			maximo = maxf(maximo, h)
	var c := alturas[(n / 2) * n + n / 2]
	print("recorte %d x %d px, alturas %.0f..%.0f m, centro %.1f m, sin dato %d" % [n, n, minimo, maximo, c, faltan])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA.get_base_dir()))
	FileAccess.open(ProjectSettings.globalize_path(SALIDA.get_base_dir().path_join(".gdignore")), FileAccess.WRITE).close()
	var img := Image.create_from_data(n, n, false, Image.FORMAT_RF, alturas.to_byte_array())
	var e := img.save_exr(ProjectSettings.globalize_path(SALIDA + ".exr"), true)
	var meta := {
		"fuente": "Copernicus GLO-30 DEM (DGED 2021/1), piezas S14 W074 y W075",
		"lon_oeste": lon0, "lat_norte": lat0, "grados_por_px": px, "lado_px": n,
		"m_por_px_x": px * M_POR_GRADO * cos(deg_to_rad(CENTRO.y)), "m_por_px_z": px * M_POR_GRADO,
		"centro_px": [(CENTRO.x - lon0) / px, (lat0 - CENTRO.y) / px], "altura_centro_m": c,
	}
	var f := FileAccess.open(ProjectSettings.globalize_path(SALIDA + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	print("guardado %s.exr (codigo %d) y .json" % [SALIDA, e])
	quit(0 if e == OK else 1)


## Copia en `alturas` (n x n, empezando en lon0/lat0) los pixeles de la pieza `ruta` que caen dentro del recorte.
func _volcar(ruta: String, lon0: float, lat0: float, n: int, px: float, alturas: PackedFloat32Array) -> void:
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		printerr("no se pudo abrir ", ruta)
		return
	var t := _etiquetas(f)
	var ancho: int = t[256][0]
	var tile: int = t[322][0]
	var offsets: Array = t[324]
	var cuentas: Array = t[325]
	var origen_lon: float = t[33922][3]
	var origen_lat: float = t[33922][4]
	if t[259][0] != 8 or t[317][0] != 3 or t[258][0] != 32:
		printerr("formato inesperado en ", ruta, ": compresion ", t[259], " predictor ", t[317])
		return
	var por_fila := int(ceil(ancho / float(tile)))
	# Columnas y filas de la pieza que caen dentro del recorte.
	var c0 := int(floor((lon0 - origen_lon) / px))
	var r0 := int(floor((origen_lat - lat0) / px))
	for tf in por_fila:
		for tc in por_fila:
			var x0 := tc * tile
			var y0 := tf * tile
			if x0 >= c0 + n or x0 + tile <= c0 or y0 >= r0 + n or y0 + tile <= r0:
				continue
			var datos := _bloque(f, offsets[tf * por_fila + tc], cuentas[tf * por_fila + tc], tile)
			for y in tile:
				var oy := y0 + y - r0
				if oy < 0 or oy >= n or y0 + y >= ancho:
					continue
				for x in tile:
					var ox := x0 + x - c0
					# los bloques del borde traen relleno mas alla del ancho de la pieza: no se copia
					if ox >= 0 and ox < n and x0 + x < ancho:
						alturas[oy * n + ox] = datos[y * tile + x]
			print("  bloque %d,%d de %s" % [tc, tf, ruta.get_file()])
	f.close()


## Descomprime un bloque y deshace el predictor 3: cada fila guarda primero todos los bytes mas significativos, luego los
## siguientes..., y cada byte va como diferencia con el anterior de la fila.
func _bloque(f: FileAccess, offset: int, cuenta: int, tile: int) -> PackedFloat32Array:
	f.seek(offset)
	var b := f.get_buffer(cuenta).decompress(tile * tile * 4, FileAccess.COMPRESSION_DEFLATE)
	var fila := tile * 4
	var salida := PackedByteArray()
	salida.resize(tile * tile * 4)
	for y in tile:
		var base := y * fila
		for i in range(1, fila):
			b[base + i] = (b[base + i] + b[base + i - 1]) & 0xFF
		for x in tile:
			var o := base + x * 4
			# bytes del flotante en orden big-endian repartidos en 4 planos -> little-endian
			salida[o] = b[base + 3 * tile + x]
			salida[o + 1] = b[base + 2 * tile + x]
			salida[o + 2] = b[base + tile + x]
			salida[o + 3] = b[base + x]
	return salida.to_float32_array()


## Etiquetas TIFF (clasico, little-endian) -> lista de valores. Lee los arrays aunque esten fuera de la entrada.
func _etiquetas(f: FileAccess) -> Dictionary:
	f.seek(4)
	f.seek(f.get_32())
	var n := f.get_16()
	var t := {}
	for i in n:
		var pos := f.get_position()
		var tag := f.get_16()
		var tipo := f.get_16()
		var cnt := f.get_32()
		var tam: int = {3: 2, 4: 4, 12: 8, 2: 1, 1: 1, 11: 4, 16: 8}.get(tipo, 1)
		var fin := pos + 12
		if tam * cnt > 4:
			f.seek(f.get_32())
		var vals := []
		for k in cnt:
			match tipo:
				3: vals.append(f.get_16())
				4: vals.append(f.get_32())
				12: vals.append(f.get_double())
				11: vals.append(f.get_float())
				16: vals.append(f.get_64())
				_: vals.append(f.get_8())
		t[tag] = vals
		f.seek(fin)
	return t
