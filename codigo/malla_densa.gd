class_name MallaDensa
extends RefCounted
## Densifica una malla con esqueleto para que la piel tenga vertices donde deformarse (las venas que abultan): parte por la
## mitad cada arista mas larga que `largo_max` hasta que no quede ninguna, solo en la zona pedida (antebrazo y mano).
## Un triangulo con 1, 2 o 3 aristas partidas se divide en 2, 3 o 4 (sin vertices colgando: la marca es por arista).
## Los puntos nuevos se curvan con teselacion Phong (el punto medio se acerca a los planos tangentes de sus extremos): la
## silueta se redondea sin encoger. Conserva UV, huesos y pesos (mezclados) y el material; descarta tangentes y blend shapes.


## `largo_max` en unidades de la malla; `zona`: indices de bind (hueso dominante de un extremo) donde se parte; vacia = toda.
static func subdividir(malla: Mesh, largo_max: float, zona: Array = [], phong := 0.75, max_pasadas := 12) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in malla.get_surface_count():
		var a := malla.surface_get_arrays(s)
		var limpio := []
		limpio.resize(Mesh.ARRAY_MAX)
		for t in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS, Mesh.ARRAY_INDEX]:
			limpio[t] = a[t]
		if limpio[Mesh.ARRAY_INDEX] == null:
			var ind := PackedInt32Array()
			for i in (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
				ind.append(i)
			limpio[Mesh.ARRAY_INDEX] = ind
		limpio[Mesh.ARRAY_NORMAL] = soldar_normales(limpio[Mesh.ARRAY_VERTEX], limpio[Mesh.ARRAY_NORMAL])
		for n in max_pasadas:
			var antes := (limpio[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
			limpio = _pasada(limpio, largo_max, zona, phong)
			if (limpio[Mesh.ARRAY_INDEX] as PackedInt32Array).size() == antes:
				break
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, limpio, [], {}, malla.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		out.surface_set_material(s, malla.surface_get_material(s))
	return out


## Promedia la normal de los vertices que comparten posicion (duplicados en las costuras de UV). Sin esto, el punto medio
## de una arista de costura saldria distinto a cada lado y al empujar la piel por la normal se abririan grietas.
static func soldar_normales(P: PackedVector3Array, N: PackedVector3Array) -> PackedVector3Array:
	var suma := {}
	for i in P.size():
		var c := _celda(P[i])
		suma[c] = suma.get(c, Vector3.ZERO) + N[i]
	var out := PackedVector3Array()
	out.resize(P.size())
	for i in P.size():
		var s: Vector3 = suma[_celda(P[i])]
		out[i] = s.normalized() if s.length() > 0.3 else N[i]   # caras opuestas en el mismo punto (lamina fina): no se promedian
	return out


static func _celda(p: Vector3) -> Vector3i:
	return Vector3i((p * 1e5).round())


static func _pasada(a: Array, largo_max: float, zona: Array, phong: float) -> Array:
	var P: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var N: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var UV: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var B: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var W: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var I: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var nv := P.size()
	var k := B.size() / nv   # huesos por vertice (4 u 8)
	var en_zona := PackedByteArray()
	en_zona.resize(nv)
	for i in nv:
		en_zona[i] = 1 if zona.is_empty() or zona.has(hueso_dominante(B, W, k, i)) else 0
	var P2 := P.duplicate()
	var N2 := N.duplicate()
	var UV2 := UV.duplicate()
	var B2 := B.duplicate()
	var W2 := W.duplicate()
	# 1) Marcar aristas largas y crear su punto medio (una vez por arista: los dos triangulos que la comparten lo reusan).
	# Cuenta todo triangulo que toque la zona, no solo las aristas con un extremo dentro: si no, una arista larga del borde
	# (los dos extremos fuera) haria nacer en su vecino, en cada pasada, otra arista igual de larga dentro de la zona.
	var medio := {}   # arista (i menor * nv + j mayor) -> indice del punto medio
	for t in range(0, I.size(), 3):
		if en_zona[I[t]] == 0 and en_zona[I[t + 1]] == 0 and en_zona[I[t + 2]] == 0:
			continue
		for e in 3:
			var i := I[t + e]
			var j := I[t + (e + 1) % 3]
			var clave := mini(i, j) * nv + maxi(i, j)
			if medio.has(clave) or P[i].distance_to(P[j]) <= largo_max:
				continue
			medio[clave] = P2.size()
			var q := (P[i] + P[j]) * 0.5
			var pi := q - N[i] * (q - P[i]).dot(N[i])
			var pj := q - N[j] * (q - P[j]).dot(N[j])
			# En pliegues o bordes (normales que divergen) Phong empuja el punto fuera de la piel y cada pasada crea otra
			# arista larga: ahi se usa el punto medio recto, y en el resto el empuje se limita a una fraccion de la arista.
			var curva := ((pi + pj) * 0.5 - q) * phong
			if N[i].dot(N[j]) < 0.5:
				curva = Vector3.ZERO
			curva = curva.limit_length(0.12 * P[i].distance_to(P[j]))
			P2.append(q + curva)
			N2.append((N[i] + N[j]).normalized())
			UV2.append((UV[i] + UV[j]) * 0.5)
			_mezclar_pesos(B, W, k, i, j, B2, W2)
	# 2) Partir cada triangulo segun cuantas de sus aristas se marcaron (se conserva el sentido de giro).
	var I2 := PackedInt32Array()
	for t in range(0, I.size(), 3):
		var v := [I[t], I[t + 1], I[t + 2]]
		var m := [-1, -1, -1]   # m[e] = punto medio de la arista v[e] -> v[e+1]
		var marcadas := 0
		for e in 3:
			var i: int = v[e]
			var j: int = v[(e + 1) % 3]
			m[e] = medio.get(mini(i, j) * nv + maxi(i, j), -1)
			if m[e] >= 0:
				marcadas += 1
		match marcadas:
			0:
				I2.append_array(v)
			3:
				I2.append_array([v[0], m[0], m[2], m[0], v[1], m[1], m[2], m[1], v[2], m[1], m[2], m[0]])
			1:
				var e := m.find(m.filter(func(x: int) -> bool: return x >= 0)[0])
				I2.append_array([v[e], m[e], v[(e + 2) % 3], m[e], v[(e + 1) % 3], v[(e + 2) % 3]])
			2:
				# Arista sin partir: a -> b; c el tercer vertice; m1 en b->c, m2 en c->a. Esquina (m1, c, m2) + el cuadrilatero
				# (a, b, m1, m2) cortado por su diagonal mas corta.
				var u := m.find(-1)
				var ia: int = v[u]
				var ib: int = v[(u + 1) % 3]
				var ic: int = v[(u + 2) % 3]
				var m1: int = m[(u + 1) % 3]
				var m2: int = m[(u + 2) % 3]
				I2.append_array([m1, ic, m2])
				if P2[ia].distance_squared_to(P2[m1]) < P2[ib].distance_squared_to(P2[m2]):
					I2.append_array([ia, ib, m1, ia, m1, m2])
				else:
					I2.append_array([ia, ib, m2, ib, m1, m2])
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = P2
	out[Mesh.ARRAY_NORMAL] = N2
	out[Mesh.ARRAY_TEX_UV] = UV2
	out[Mesh.ARRAY_BONES] = B2
	out[Mesh.ARRAY_WEIGHTS] = W2
	out[Mesh.ARRAY_INDEX] = I2
	return out


## Pesos del punto medio = la media de los dos extremos; se quedan los `k` huesos de mas peso y se renormaliza.
static func _mezclar_pesos(B: PackedInt32Array, W: PackedFloat32Array, k: int, i: int, j: int, B2: PackedInt32Array, W2: PackedFloat32Array) -> void:
	var pesos := {}
	for o in k:
		pesos[B[i * k + o]] = pesos.get(B[i * k + o], 0.0) + W[i * k + o] * 0.5
		pesos[B[j * k + o]] = pesos.get(B[j * k + o], 0.0) + W[j * k + o] * 0.5
	var lista := pesos.keys()
	lista.sort_custom(func(x: int, y: int) -> bool: return pesos[x] > pesos[y])
	var total := 0.0
	for o in mini(k, lista.size()):
		total += pesos[lista[o]]
	for o in k:
		if o < lista.size():
			B2.append(lista[o])
			W2.append(pesos[lista[o]] / maxf(total, 1e-6))
		else:
			B2.append(0)
			W2.append(0.0)


## Arista mas larga (en unidades de la malla) de los triangulos cuyos 3 vertices cuelgan sobre todo de `huesos` (indices de bind).
static func arista_max(malla: Mesh, huesos: Array) -> float:
	var mx := 0.0
	for s in malla.get_surface_count():
		var a := malla.surface_get_arrays(s)
		var P: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var B: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var W: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var I: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var k := B.size() / P.size()
		for t in range(0, I.size(), 3):
			var dentro := true
			for e in 3:
				if not huesos.has(hueso_dominante(B, W, k, I[t + e])):
					dentro = false
			if dentro:
				for e in 3:
					mx = maxf(mx, P[I[t + e]].distance_to(P[I[t + (e + 1) % 3]]))
	return mx


static func hueso_dominante(B: PackedInt32Array, W: PackedFloat32Array, k: int, v: int) -> int:
	var mejor := 0
	for o in k:
		if W[v * k + o] > W[v * k + mejor]:
			mejor = o
	return B[v * k + mejor]
