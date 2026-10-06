extends SceneTree
## Perfil del horizonte desde un punto: para cada acimut, el angulo de elevacion del cerro mas alto (y a que distancia),
## leyendo el relieve horneado (vilcas_lejos.res). Sirve para comprobar que la puesta de sol del 21 de junio (~294 grados)
## cae en un hueco entre montanas y la salida (~66 grados) sobre el horizonte del templo.
##   godot.console.exe --headless --path . --script res://herramientas/perfil_horizonte.gd -- x z desde hasta paso
##   (por defecto: el borde oeste del pueblo, de 250 a 340 grados cada 5)

const LEJOS := "res://assets/relieve/vilcas_lejos.res"
const CERCA := "res://assets/relieve/vilcas_cerca.res"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var x := -150.0 if args.size() < 1 else float(args[0])
	var z := 40.0 if args.size() < 2 else float(args[1])
	var desde := 250.0 if args.size() < 3 else float(args[2])
	var hasta := 340.0 if args.size() < 4 else float(args[3])
	var paso := 5.0 if args.size() < 5 else float(args[4])
	var lejos: Image = load(LEJOS)
	var cerca: Image = load(CERCA)
	var m_px: Vector2 = lejos.get_meta("m_por_px")
	var c_px: Vector2 = lejos.get_meta("centro_px")
	var altura := func(px: float, pz: float) -> float:
		var i := int(round(c_px.x + px / m_px.x))
		var j := int(round(c_px.y + pz / m_px.y))
		if i < 0 or j < 0 or i >= lejos.get_width() or j >= lejos.get_height():
			return NAN
		return lejos.get_pixel(i, j).r
	var ojo: float = altura.call(x, z) + 1.6
	var mitad := (cerca.get_width() - 1) * float(cerca.get_meta("paso_m")) * 0.5
	if absf(x) < mitad and absf(z) < mitad:
		var paso_c: float = cerca.get_meta("paso_m")
		ojo = cerca.get_pixel(int((x + mitad) / paso_c), int((z + mitad) / paso_c)).r + 1.6
	print("desde (%.0f, %.0f), ojos a %.1f m sobre la plaza" % [x, z, ojo])
	var az := desde
	while az <= hasta + 0.01:
		var a := deg_to_rad(az)
		var mejor := -90.0
		var dist := 0.0
		var r := 300.0
		while r < 19000.0:
			var h: float = altura.call(x + sin(a) * r, z - cos(a) * r)
			if is_nan(h):
				break
			var e := rad_to_deg(atan2(h - ojo, r))
			if e > mejor:
				mejor = e
				dist = r
			r += 120.0
		print("%5.1f: %5.2f grados (cerro a %4.1f km) %s" % [az, mejor, dist / 1000.0, "#".repeat(maxi(0, int(mejor * 3.0)))])
		az += paso
	quit()
