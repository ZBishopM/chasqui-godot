extends SceneTree
## Hornea los cuerpos de la fosa comun (Fosa): deja caer N bultos amortajados (ragdolls de Fosa.SEGMENTOS unidos por
## articulaciones de giro limitado, rigidos como un cuerpo envuelto) en el hoyo vacio, de a uno y en orientaciones al
## azar, como si los hubieran tirado; espera a que se asienten y guarda la transformacion de cada segmento respecto al
## fondo de la fosa en Fosa.CUERPOS_HORNEADOS. Determinista (semilla fija, paso fijo).
##   godot.console.exe --headless --path . --fixed-fps 60 --script res://herramientas/hornear_fosa.gd -- 144

const CADA := 7              # cuadros de fisica entre un cuerpo y el siguiente
const ASENTARSE := 420       # cuadros despues del ultimo

var _fosa: Fosa
var _cuerpos: Array = []     # por cuerpo, sus RigidBody3D (cabeza a pies)


func _initialize() -> void:
	_correr.call_deferred()


func _correr() -> void:
	var n := 144
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		n = int(args[0])
	var terreno := Terreno.new()
	root.add_child(terreno)
	_fosa = Fosa.new()
	_fosa.terreno = terreno
	_fosa.sin_cuerpos = true
	root.add_child(_fosa)
	for i in 5:
		await physics_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 1532
	var fondo := Vector3(Fosa.CENTRO.x, _fosa._piso, Fosa.CENTRO.y)
	for k in n:
		# Tirados desde el borde: echados, con el rumbo, el giro y la inclinacion al azar, sobre cualquier parte del hoyo.
		var r := sqrt(rng.randf()) * (Fosa.RADIO - 0.7)
		var a := rng.randf() * TAU
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, deg_to_rad(90.0 + rng.randf_range(-25.0, 25.0))) * Basis(Vector3.UP, rng.randf() * TAU)
		var pos := fondo + Vector3(cos(a) * r, Fosa.HONDO + 0.5, sin(a) * r)   # desde el borde
		var t := Transform3D(b, pos - b * Vector3(0, 0.85, 0))
		_cuerpos.append(_ragdoll(t, Vector3(rng.randf_range(-1.0, 1.0), -1.5, rng.randf_range(-1.0, 1.0)), rng))
		for i in CADA:
			await physics_frame
	for i in ASENTARSE:
		await physics_frame
	# Guardar: por cuerpo, por segmento, [x.x x.y x.z  y.x y.y y.z  z.x z.y z.z  o.x o.y o.z] respecto al fondo.
	var base_inv := Transform3D(Basis(), fondo).affine_inverse()
	var datos := []
	var fuera := 0
	var alto := 0.0
	for rb_lista: Array in _cuerpos:
		var segs := []
		for rb: RigidBody3D in rb_lista:
			var t: Transform3D = base_inv * rb.global_transform
			alto = maxf(alto, t.origin.y)
			if Vector2(t.origin.x, t.origin.z).length() > Fosa.BORDE:
				fuera += 1
			var v := []
			for c in [t.basis.x, t.basis.y, t.basis.z, t.origin]:
				v.append_array([snappedf(c.x, 0.0001), snappedf(c.y, 0.0001), snappedf(c.z, 0.0001)])
			segs.append(v)
		datos.append(segs)
	var f := FileAccess.open(Fosa.CUERPOS_HORNEADOS, FileAccess.WRITE)
	f.store_string(JSON.stringify(datos))
	f.close()
	print("hornear_fosa: %d cuerpos, monton hasta %.2f m sobre el fondo, %d segmentos fuera del hoyo -> %s" % [n, alto, fuera, Fosa.CUERPOS_HORNEADOS])
	quit()


## Un bulto: segmentos rigidos (capsulas) en el marco del cuerpo de pie, puestos con `t`, unidos con ConeTwistJoint3D.
func _ragdoll(t: Transform3D, vel: Vector3, rng: RandomNumberGenerator) -> Array:
	var de_pie := Fosa.segmentos_de_pie()
	var rbs: Array[RigidBody3D] = []
	for i in Fosa.SEGMENTOS.size():
		var sg: Array = Fosa.SEGMENTOS[i]
		var rb := RigidBody3D.new()
		rb.mass = sg[3]
		rb.linear_damp = 0.4
		rb.angular_damp = 1.5
		var forma := CapsuleShape3D.new()
		forma.radius = sg[1]
		forma.height = maxf(sg[2], sg[1] * 2.0)
		var col := CollisionShape3D.new()
		col.shape = forma
		rb.add_child(col)
		var mat := PhysicsMaterial.new()
		mat.friction = 0.9   # tela mojada sobre barro
		mat.bounce = 0.0
		rb.physics_material_override = mat
		rb.transform = t * Transform3D(Basis(), de_pie[i][0])
		root.add_child(rb)
		rb.linear_velocity = vel
		rb.angular_velocity = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.8
		rbs.append(rb)
	for i in rbs.size():
		for j in rbs.size():
			if i != j:
				rbs[i].add_collision_exception_with(rbs[j])
	# Articulaciones: cuello, cintura, cadera, rodillas, tobillos (la manta las endurece).
	var giros := [35.0, 22.0, 45.0, 55.0, 20.0]
	var y := 1.65
	for i in rbs.size() - 1:
		y -= float(Fosa.SEGMENTOS[i][2])
		var j := ConeTwistJoint3D.new()
		# El eje x de la articulacion va a lo largo del cuerpo (hacia la cabeza).
		j.transform = t * Transform3D(Basis(Vector3.UP, Vector3(-1, 0, 0), Vector3(0, 0, 1)), Vector3(0, y, 0))
		j.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(giros[i]))
		j.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(12.0))
		root.add_child(j)
		j.node_a = rbs[i].get_path()
		j.node_b = rbs[i + 1].get_path()
	return rbs
