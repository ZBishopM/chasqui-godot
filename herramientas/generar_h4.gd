extends SceneTree
## Genera los gestos de H4 (OpenGameArt fps arms) y la escena editable escenas/manos_h4.tscn.
##   godot.console.exe --headless --path . --script res://herramientas/generar_h4.gd
## A diferencia de H3, este rig no trae clips de gesto. Las poses pico se definen por MOVIMIENTO ("el dedo se dobla hacia la
## palma", "el brazo sube") y EjesMano las baja a los ejes locales de cada hueso, calculados de la geometria del rig.
## Los angulos de PICOS son los de AnimProc.REPERTORIO (la version web) pasados a grados. Cambia un numero y vuelve a
## ejecutar, o abre la escena en el editor y retoca las claves a mano (el script pisa esas ediciones al volver a correr).

const FBX := "res://assets/manos/oga_fps_arms/arms_anim.fbx"
const ESCENA := "res://escenas/manos_h4.tscn"
const YAW := 180.0   # el mismo que `yaw` del catalogo: el rig mira a +Z y se gira para mirar a -Z

const HUESOS := {
	"brazo": "upper_arm.L", "antebrazo": "forearm.L", "muneca": "hand.L",
	"palma_medio": "palm_middle.L", "palma_indice": "palm_index.L", "palma_menique": "palm_pinky.L",
	"dedos": ["f_index.0%d.L", "f_middle.0%d.L", "f_ring.0%d.L", "f_pinky.0%d.L"],
	"pulgar": "thumb.0%d.L", "punta": "%s_end",
}

## Pose pico de cada poder: grado de libertad -> grados (ver EjesMano.rotaciones para el sentido de cada uno).
const PICOS := {
	# Halcon "garra alta": brazo en alto, muneca atras, dedos en garra
	"halcon": {"brazo_elevar": 34, "antebrazo_elevar": 20, "muneca_flex": -17, "dedos_flex": 40, "pulgar_flex": 25},
	# Sapo "palmada baja": el brazo baja y empuja, mano abierta
	"sapo": {"brazo_elevar": -8, "antebrazo_elevar": -22, "muneca_flex": -8, "dedos_abrir": 10},
	# Amaru "ondular": la muñeca ondula y los dedos se enroscan en ola
	"amaru": {"brazo_barrer": -14, "muneca_flex": 17, "dedos_ola": 30},
	# Condor "alas": brazo abierto y alto, dedos muy separados
	"condor": {"brazo_elevar": 25, "brazo_barrer": -28, "muneca_flex": -11, "dedos_abrir": 16, "dedos_flex": -6},
	# Puma "acecho": garra tensa hacia delante
	"puma": {"brazo_adelante": 11, "muneca_flex": 14, "dedos_flex": 34, "dedos_abrir": 6},
	# Colibri "aleteo": casi quieta, solo tiembla
	"colibri": {"muneca_flex": 9, "dedos_flex": 14},
}
## poder -> grados de temblor (el espasmo del GDD §10); 0 = sin temblor
const TEMBLOR := {"halcon": 4.0, "sapo": 3.0, "amaru": 3.0, "condor": 2.0, "puma": 4.0, "colibri": 7.0}


func _initialize() -> void:
	var raiz: Node = (load(FBX) as PackedScene).instantiate()
	root.add_child(raiz)
	await process_frame
	var ap := raiz.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk := raiz.find_child("Skeleton3D", true, false) as Skeleton3D
	var huesos := GestosLib.huesos_utiles(sk)
	var muestra := ap.get_animation_list()[0]
	var reposo := GestosLib.muestrear(ap, sk, muestra, 0.0, huesos)   # el primer cuadro del clip de muestra es el reposo
	var ejes := EjesMano.new(sk, YAW, HUESOS, true)
	var temblor := ejes.ejes_temblor()

	var lib := AnimationLibrary.new()
	lib.add_animation("reposo", GestosLib.clip_estatico(raiz, sk, huesos, reposo))
	var semilla := 0.0
	for poder: String in PICOS:
		var pico := ejes.pose(reposo, PICOS[poder])
		var dur: float = AnimProc.REPERTORIO[poder][0].duracion
		semilla += 0.3
		lib.add_animation(poder, GestosLib.clip_pose_a_pose(raiz, sk, huesos, reposo, pico, dur, "esfuerzo", temblor, TEMBLOR[poder], semilla))
		print("%s: %d grados de libertad, %d huesos rotados, dur %.2f s" % [poder, (PICOS[poder] as Dictionary).size(), ejes.rotaciones(PICOS[poder]).size(), dur])

	var originales := AnimationLibrary.new()
	originales.add_animation(muestra.replace("|", "_"), GestosLib.copiar_clip(ap, muestra, true))
	var e := GestosLib.guardar_escena(ESCENA, FBX, raiz.name, lib, originales)
	print("escena guardada: ", ESCENA, " (codigo ", e, ")")
	quit(0 if e == OK else 1)
