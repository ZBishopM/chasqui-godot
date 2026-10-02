class_name Catalogo
extends RefCounted
## UNICA fuente de candidatos de la demo. Anadir un pack = anadir una entrada aqui (+ su adaptador si es de un tipo nuevo).
## `tipo` decide el adaptador: manos.gd (manos) · personajes.gd (personajes) · vfx_propios.gd / vfx_packs.gd (poderes).

const WRAD_HUESOS := {
	brazo = "bicep.l", muneca = "wrist.l", muneca_der = "wrist.r", ojo = "",
	dedos = ["finger_index%d.l", "finger_middle%d.l", "finger_ring%d.l", "finger_pinky%d.l", "finger_thumb%d.l"],
}

# Venas de oro (VenasOro): hueso del codo, de la muñeca y primera falange de cada dedo (brazo izquierdo; el derecho se deduce).
# Los radios (m) son hasta donde llega la piel desde el eje del hueso: se calibran con una captura por rig.
const VENAS_H4 := {codo="forearm.L", muneca="hand.L", dedos_base=["f_index.01.L", "f_middle.01.L", "f_ring.01.L", "f_pinky.01.L"], radio_brazo=0.056, radio_mano=0.016, engrosa=0.1, grosor=2.2}
const VENAS_H3 := {codo="forearm.L", muneca="hand.L", dedos_base=["f_index.01.L", "f_middle.01.L", "f_ring.01.L", "f_pinky.01.L"], radio_brazo=0.045, radio_mano=0.019, engrosa=0.35, grosor=1.4}

# WRAD viene con los brazos colgando. Pose de primera persona hallada por busqueda numerica (codigo en la sesion): brazo -60 y codo -90 grados sobre el eje X local de cada hueso (simetrica).
const WRAD_POSE := {"bicep.l": -60.0, "bicep.r": -60.0, "forearm.l": -90.0, "forearm.r": -90.0}

const MANOS := [
	{id="H1", nombre="Propia (metaballs)", tipo="propia", licencia="propia", autor="Chasqui",
		url="", rutas=["res://assets/manos/propia/mano-izq.glb", "res://assets/manos/propia/mano-der.glb"]},
	{id="H4", nombre="OpenGameArt fps arms (rig con dedos)", tipo="skel_brazos", licencia="CC0", autor="para",
		url="https://opengameart.org/content/fps-arms-rigged-only", rutas=["res://assets/manos/oga_fps_arms/arms_anim.fbx"],
		textura="res://assets/manos/oga_fps_arms/new_diff.png", escena="res://escenas/manos_h4.tscn", venas=VENAS_H4, escala=0.1, yaw=180.0, tinta=false,
		anim_reposo="reposo", gestos_anim={halcon="halcon", sapo="sapo", amaru="amaru", condor="condor", puma="puma", colibri="colibri"}},
	{id="H2", nombre="WRAD ARMS (clara)", tipo="skel_brazos", licencia="CC0", autor="wriks",
		url="https://wriks.itch.io/wrad-arms", rutas=["res://assets/manos/wrad_arms/arms.glb"],
		escala=0.06, yaw=180.0, tinta=false, huesos=WRAD_HUESOS, pose=WRAD_POSE, manos_en=Vector3(0, -0.12, -0.2)},
	{id="H2d", nombre="WRAD ARMS (oscura)", tipo="skel_brazos", licencia="CC0", autor="wriks",
		url="https://wriks.itch.io/wrad-arms", rutas=["res://assets/manos/wrad_arms/arms.glb"],
		textura="res://assets/manos/wrad_arms/arm_albedo_dark.png", escala=0.06, yaw=180.0, tinta=false, huesos=WRAD_HUESOS, pose=WRAD_POSE, manos_en=Vector3(0, -0.12, -0.2)},
	{id="H3", nombre="PSX First Person Arms (animadas)", tipo="skel_brazos", licencia="CC0", autor="Drillimpact",
		url="https://drillimpact.itch.io/psx-first-person-arms-free", rutas=["res://assets/manos/psx_arms/arms_rig.glb"],
		escena="res://escenas/manos_h3.tscn", venas=VENAS_H3, escala=1.0, yaw=180.0, desplazo=Vector3(0, 0.12, -0.02), fov=70.0, tinta=false, anim_reposo="reposo",
		gestos_anim={halcon="halcon", sapo="sapo", amaru="amaru", condor="condor", puma="puma", colibri="colibri"}},
	{id="H3g", nombre="PSX First Person Arms con guantes", tipo="skel_brazos", licencia="CC0", autor="Drillimpact",
		url="https://drillimpact.itch.io/psx-first-person-arms-free", rutas=["res://assets/manos/psx_arms/arms_rig.glb"],
		textura="res://assets/manos/psx_arms/arms_gloves_01.png", pixelado=true, escena="res://escenas/manos_h3.tscn", venas=VENAS_H3, escala=1.0, yaw=180.0, desplazo=Vector3(0, 0.12, -0.02), fov=70.0, tinta=false, anim_reposo="reposo",
		gestos_anim={halcon="halcon", sapo="sapo", amaru="amaru", condor="condor", puma="puma", colibri="colibri"}},
]

const PERSONAJES := [
	{id="P1", nombre="Humanoide procedural", tipo="procedural", licencia="propia", autor="Chasqui", url=""},
	{id="P2a", nombre="KayKit Knight", tipo="kaykit", licencia="CC0", autor="Kay Lousberg",
		url="https://kaylousberg.itch.io/kaykit-adventurers", rutas=["res://assets/personajes/kaykit/Knight.glb"]},
	{id="P2b", nombre="KayKit Rogue (encapuchado)", tipo="kaykit", licencia="CC0", autor="Kay Lousberg",
		url="https://kaylousberg.itch.io/kaykit-adventurers", rutas=["res://assets/personajes/kaykit/Rogue_Hooded.glb"]},
	{id="P2c", nombre="KayKit Barbarian", tipo="kaykit", licencia="CC0", autor="Kay Lousberg",
		url="https://kaylousberg.itch.io/kaykit-adventurers", rutas=["res://assets/personajes/kaykit/Barbarian.glb"]},
	{id="P4a", nombre="Kenney Blocky A", tipo="kenney", licencia="CC0", autor="Kenney",
		url="https://kenney.nl/assets/blocky-characters", rutas=["res://assets/personajes/kenney/character-a.glb"]},
	{id="P4b", nombre="Kenney Blocky K", tipo="kenney", licencia="CC0", autor="Kenney",
		url="https://kenney.nl/assets/blocky-characters", rutas=["res://assets/personajes/kenney/character-k.glb"]},
	{id="P3a", nombre="Quaternius Superhero (hombre)", tipo="ubc", licencia="CC0", autor="Quaternius",
		url="https://quaternius.itch.io/universal-base-characters", rutas=["res://assets/personajes/ubc/Superhero_Male_FullBody.gltf"]},
	{id="P3b", nombre="Quaternius Superhero (mujer)", tipo="ubc", licencia="CC0", autor="Quaternius",
		url="https://quaternius.itch.io/universal-base-characters", rutas=["res://assets/personajes/ubc/Superhero_Female_FullBody.gltf"]},
	{id="P3m", nombre="Quaternius Maniqui (UAL)", tipo="ual", licencia="CC0", autor="Quaternius",
		url="https://quaternius.itch.io/universal-animation-library", rutas=["res://assets/personajes/ual/UAL1_Standard.glb"]},
]

const VFX := [
	{id="V1", nombre="Propio (particulas + shaders)", tipo="propio", licencia="propia", autor="Chasqui", url=""},
	{id="V2", nombre="Binbun Magic Projectiles (12 proyectiles)", tipo="binbun_proyectiles", licencia="CC0", autor="Binbun",
		url="https://binbun3d.itch.io/magic-projectiles-vfx"},
	{id="V3", nombre="Binbun Elemental Magic FX (gratis: fuego)", tipo="binbun_elemental", licencia="CC0", autor="Binbun",
		url="https://binbun3d.itch.io/elemental-magic-fx"},
]

const ESTILOS := [
	{id="pbr", nombre="PBR (luz normal)"},
	{id="toon", nombre="Toon (cel + tinta, M11)"},
]

const CATEGORIAS := {"manos": MANOS, "personajes": PERSONAJES, "vfx": VFX, "estilo": ESTILOS}
