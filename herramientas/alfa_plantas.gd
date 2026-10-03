extends SceneTree
## Arregla las plantas de Poly Haven cuyo glTF a 1K pide transparencia (BLEND) pero trae el color en JPG, sin alfa: las
## hojas salian como tarjetas negras. Junta el color con su mapa de alfa (bajado aparte de Poly Haven a _descargas/) en un
## PNG y cambia el glTF para usarlo, en modo recorte (MASK): mas barato que BLEND y sin errores de orden en el follaje.
##   godot.console.exe --headless --path . --script res://herramientas/alfa_plantas.gd   (y luego --import)

const PLANTAS := ["wild_rooibos_bush", "flower_ursinia", "flower_heliophila", "searsia_burchellii"]
const CORTE := 0.45


func _initialize() -> void:
	for m: String in PLANTAS:
		var dir := ProjectSettings.globalize_path("res://assets/plantas/%s/" % m)
		if FileAccess.file_exists(dir + "textures/%s_diff_alfa_1k.png" % m):
			print(m, ": ya hecho")
			continue
		var color := Image.load_from_file(dir + "textures/%s_diff_1k.jpg" % m)
		var alfa := Image.load_from_file(ProjectSettings.globalize_path("res://_descargas/%s_alpha_1k.png" % m))
		color.convert(Image.FORMAT_RGBA8)
		alfa.convert(Image.FORMAT_L8)
		if alfa.get_size() != color.get_size():
			alfa.resize(color.get_width(), color.get_height())
		for y in color.get_height():
			for x in color.get_width():
				var c := color.get_pixel(x, y)
				c.a = alfa.get_pixel(x, y).r
				color.set_pixel(x, y, c)
		var png := "textures/%s_diff_alfa_1k.png" % m
		color.save_png(dir + png)
		var ruta_gltf := dir + "%s.gltf" % m
		var g: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ruta_gltf))
		for img: Dictionary in g.images:
			if str(img.uri).ends_with("_diff_1k.jpg"):
				img.uri = png
				img["mimeType"] = "image/png"
		for mat: Dictionary in g.materials:
			if mat.get("alphaMode", "") == "BLEND":
				mat.alphaMode = "MASK"
				mat["alphaCutoff"] = CORTE
		var f := FileAccess.open(ruta_gltf, FileAccess.WRITE)
		f.store_string(JSON.stringify(g, "  ", false, true))   # precision completa: no tocar transformaciones
		f.close()
		print(m, ": ", png)
	quit()
