extends SceneTree
## Hornea la piel densa de las manos (`piel` en el catalogo, p. ej. escenas/piel_h3.res): la malla del rig subdividida con
## MallaDensa, para que las venas tengan vertices donde abultar, y la red de venas (CampoVenas) en sus vertices.
## Volver a ejecutar si cambia el modelo, LARGO_MAX, SEMILLA o el trazado de las venas en campo_venas.gd:
##   godot.console.exe --headless --path . --script res://herramientas/hornear_piel.gd
## Imprime vertices, triangulos y la arista mas larga del antebrazo y la mano en mm antes y despues.

const LARGO_MAX := 0.0025   # m: ninguna arista del antebrazo o la mano queda mas larga (>= 4 vertices a lo ancho de una vena)
const SEMILLA := 7         # cambia el trazado de las venas (otra red igual de verosimil)
const ZONA := ["forearm", "hand", "palm"]   # prefijos de hueso: antebrazo, muneca y dorso/palma (los dedos ya son densos)


func _initialize() -> void:
	var fallos := 0
	for e: Dictionary in Catalogo.MANOS:
		if not e.has("piel"):
			continue
		var raiz: Node3D = (load(e.escena) as PackedScene).instantiate()
		raiz.scale = Vector3.ONE * float(e.escala)
		root.add_child(raiz)
		await process_frame
		var sk := raiz.find_child("Skeleton3D", true, false) as Skeleton3D
		var mallas := raiz.find_children("*", "MeshInstance3D", true, false).filter(func(m: MeshInstance3D) -> bool: return m.skin != null)
		if mallas.size() != 1:
			printerr("%s: se esperaba 1 malla con skin y hay %d" % [e.id, mallas.size()])
			fallos += 1
			continue
		var mi: MeshInstance3D = mallas[0]
		var binds := {}   # nombre de hueso -> indice de bind
		for b in mi.skin.get_bind_count():
			var nombre := mi.skin.get_bind_name(b)
			binds[nombre if nombre != "" else sk.get_bone_name(mi.skin.get_bind_bone(b))] = b
		var nombres := binds.keys().filter(func(n: String) -> bool: return ZONA.any(func(p: String) -> bool: return n.begins_with(p)))
		var zona := nombres.map(func(n: String) -> int: return binds[n])
		print("%s: zona = %s" % [e.id, ", ".join(nombres)])
		# Metros por unidad de malla: distancia codo-muneca en el mundo / la misma en el espacio de la malla (bind pose).
		var en_malla: float = mi.skin.get_bind_pose(binds["forearm.L"]).affine_inverse().origin.distance_to(mi.skin.get_bind_pose(binds["hand.L"]).affine_inverse().origin)
		var en_mundo := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("forearm.L")).origin).distance_to(sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand.L")).origin)
		var m_por_u := en_mundo / en_malla
		var t0 := Time.get_ticks_msec()
		var densa := MallaDensa.subdividir(mi.mesh, LARGO_MAX / m_por_u, zona)
		var seg := (Time.get_ticks_msec() - t0) / 1000.0
		print("%s: antebrazo %.3f m (%.4f m/u), %d sup, %d blend shapes, %d huesos/vertice" % [e.id, en_mundo, m_por_u, mi.mesh.get_surface_count(), mi.mesh.get_blend_shape_count(), _k(mi.mesh)])
		print("  antes:   %s, arista max antebrazo+mano %.1f mm" % [_cuenta(mi.mesh), MallaDensa.arista_max(mi.mesh, zona) * m_por_u * 1000.0])
		print("  despues: %s, arista max antebrazo+mano %.1f mm (%.1f s)" % [_cuenta(densa), MallaDensa.arista_max(densa, zona) * m_por_u * 1000.0, seg])
		# Venas (CampoVenas): cabeza de cada hueso en el espacio de la malla y de que brazo es cada vertice de la zona.
		var cabeza := {}
		var nombre_de := {}
		for n: String in binds:
			cabeza[n] = mi.skin.get_bind_pose(binds[n]).affine_inverse().origin
			nombre_de[binds[n]] = n
		var a := densa.surface_get_arrays(0)
		var B: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var W: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var nv := (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var k := B.size() / nv
		var lado := PackedByteArray()
		lado.resize(nv)
		for i in nv:
			var hueso: String = nombre_de.get(MallaDensa.hueso_dominante(B, W, k, i), "")
			if nombres.has(hueso):
				lado[i] = 1 if hueso.ends_with(".L") else 2
		t0 = Time.get_ticks_msec()
		var cuenta := CampoVenas.hornear(a, cabeza, lado, m_por_u, SEMILLA)
		print("  venas: vertices sobre una vena %s (%.1f s)" % [cuenta, (Time.get_ticks_msec() - t0) / 1000.0])
		var final := ArrayMesh.new()
		final.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, densa.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		final.surface_set_material(0, densa.surface_get_material(0))
		final.set_meta("m_por_u", m_por_u)   # PielVenas pasa los metros del shader a unidades de la malla con esto
		var err := ResourceSaver.save(final, e.piel)
		print("  guardada: %s (codigo %d)" % [e.piel, err])
		if err != OK:
			fallos += 1
		raiz.queue_free()
	quit(fallos)


func _cuenta(m: Mesh) -> String:
	var v := 0
	var t := 0
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		v += (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		t += (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return "%d vertices, %d triangulos" % [v, t]


func _k(m: Mesh) -> int:
	var a := m.surface_get_arrays(0)
	return (a[Mesh.ARRAY_BONES] as PackedInt32Array).size() / (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
