extends SceneTree
## Hornea la piel densa de las manos (`piel` en el catalogo, p. ej. escenas/piel_h3.res): la malla del rig subdividida con
## MallaDensa, para que las venas tengan vertices donde abultar. Volver a ejecutar solo si cambia LARGO_MAX o el modelo:
##   godot.console.exe --headless --path . --script res://herramientas/hornear_piel.gd
## Imprime vertices, triangulos y la arista mas larga del antebrazo y la mano en mm antes y despues.

const LARGO_MAX := 0.004   # m: ninguna arista del antebrazo o la mano queda mas larga
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
		var err := ResourceSaver.save(densa, e.piel)
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
