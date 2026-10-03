class_name Catalogo
extends RefCounted
## UNICA fuente de candidatos de la demo. Anadir un pack = anadir una entrada aqui (+ su adaptador si es de un tipo nuevo).
## `tipo` decide el adaptador: manos.gd (manos) · personajes.gd (personajes) · vfx_propios.gd / vfx_packs.gd (poderes).

const MANOS := [
	{id="H3", nombre="PSX First Person Arms (animadas)", licencia="CC0", autor="Drillimpact",
		url="https://drillimpact.itch.io/psx-first-person-arms-free", rutas=["res://assets/manos/psx_arms/arms_rig.glb"],
		escena="res://escenas/manos_h3.tscn", piel="res://escenas/piel_h3.res", escala=1.0, yaw=180.0, desplazo=Vector3(0, 0.12, -0.02), fov=70.0, tinta=false, anim_reposo="reposo",
		gestos_anim={halcon="halcon", sapo="sapo", amaru="amaru", condor="condor", puma="puma", colibri="colibri"}},
	{id="H4", nombre="OpenGameArt fps arms (rig con dedos)", licencia="CC0", autor="para",
		url="https://opengameart.org/content/fps-arms-rigged-only", rutas=["res://assets/manos/oga_fps_arms/arms_anim.fbx"],
		textura="res://assets/manos/oga_fps_arms/new_diff.png", escena="res://escenas/manos_h4.tscn", piel="res://escenas/piel_h4.res", escala=0.1, yaw=180.0, tinta=false,
		manos_en=Vector3(0, -0.099, -0.266), fov=70.0,   # gestos copiados de H3 (retargetear_h4.gd): mismo encuadre que H3
		giro_puno=25.0,   # al esprintar deshace el giro del dorso (GIRO_DORSO) y gira los punos como los de H3
		anim_reposo="reposo", gestos_anim={halcon="halcon", sapo="sapo", amaru="amaru", condor="condor", puma="puma", colibri="colibri"}},
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
