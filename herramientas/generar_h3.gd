extends SceneTree
## Genera los gestos de H3 (PSX First Person Arms) y la escena editable escenas/manos_h3.tscn.
##   godot.console.exe --headless --path . --script res://herramientas/generar_h3.gd
## Cada clip del pack empieza y termina en su propia postura (mano abajo, pistola, guardia...), a 76-93 grados del `relax`
## que se usa de idle: por eso el cambio era brusco. Aqui se toma el APICE de cada clip y se fabrica un gesto nuevo que
## sale del `relax` y vuelve a el. Vuelve a ejecutarlo si cambias GESTOS; al hacerlo se pisan las ediciones a mano de esos clips.

const GLB := "res://assets/manos/psx_arms/arms_rig.glb"
const ESCENA := "res://escenas/manos_h3.tscn"
const IDLE := "relax"
const ESCALA_DUR := 1.3   # los giros son de ~100 grados: con la duracion de la version web la recuperacion iba demasiado rapida
## poder -> clip de origen del que se toma el apice; [clip, segundo] fija el instante a mano (los clips "idle" casi no se
## mueven, su pose util es la de la postura entera, no un apice).
const GESTOS := {
	"halcon": "grab_L", "sapo": "push_L", "amaru": "finger_gun_fire",
	"condor": "guard_draw", "puma": "jab_L", "colibri": ["finger_gun_idle", 0.0],
}


func _initialize() -> void:
	var raiz: Node = (load(GLB) as PackedScene).instantiate()
	root.add_child(raiz)
	await process_frame
	var ap := raiz.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk := raiz.find_child("Skeleton3D", true, false) as Skeleton3D
	var huesos := GestosLib.huesos_utiles(sk)
	var reposo := GestosLib.muestrear(ap, sk, IDLE, 0.0, huesos)

	var lib := AnimationLibrary.new()
	lib.add_animation("reposo", GestosLib.copiar_clip(ap, IDLE, true))
	for poder: String in GESTOS:
		var origen = GESTOS[poder]
		var clip: String = origen[0] if origen is Array else origen
		var t: float = origen[1] if origen is Array else GestosLib.tiempo_pico(ap, sk, clip, huesos)
		var pico := GestosLib.muestrear(ap, sk, clip, t, huesos)
		var dur: float = AnimProc.REPERTORIO[poder][0].duracion * ESCALA_DUR
		lib.add_animation(poder, GestosLib.clip_pose_a_pose(raiz, sk, huesos, reposo, pico, dur))
		print("%s <- %s @ %.2f s (dur %.2f s, %d huesos)" % [poder, clip, t, dur, huesos.size()])

	var originales := AnimationLibrary.new()
	for nombre in ap.get_animation_list():
		originales.add_animation(nombre, GestosLib.copiar_clip(ap, nombre, nombre in ["relax", "rest", "finger_gun_idle", "guard_idle", "knife_idle"]))

	var e := GestosLib.guardar_escena(ESCENA, GLB, "arms_rig", lib, originales)
	print("escena guardada: ", ESCENA, " (codigo ", e, ")")
	quit(0 if e == OK else 1)
