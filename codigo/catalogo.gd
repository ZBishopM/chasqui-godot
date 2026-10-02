class_name Catalogo
extends RefCounted
## UNICA fuente de candidatos de la demo. Anadir un pack = anadir una entrada aqui (+ su adaptador si es de un tipo nuevo).
## `tipo` decide el adaptador: manos.gd (manos) · personajes.gd (personajes) · vfx_propios.gd / vfx_packs.gd (poderes).

const MANOS := [
	{id="H1", nombre="Propia (metaballs)", tipo="propia", licencia="propia", autor="Chasqui",
		url="", rutas=["res://assets/manos/propia/mano-izq.glb", "res://assets/manos/propia/mano-der.glb"]},
	{id="H4", nombre="OpenGameArt fps arms (rig con dedos)", tipo="skel_brazos", licencia="CC0", autor="para",
		url="https://opengameart.org/content/fps-arms-rigged-only", rutas=["res://assets/manos/oga_fps_arms/arms_anim.fbx"],
		textura="res://assets/manos/oga_fps_arms/new_diff.png", escala=0.1, yaw=180.0, tinta=false},
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
]

const VFX := [
	{id="V1", nombre="Propio (particulas + shaders)", tipo="propio", licencia="propia", autor="Chasqui", url=""},
]

const ESTILOS := [
	{id="pbr", nombre="PBR (luz normal)"},
	{id="toon", nombre="Toon (cel + tinta, M11)"},
]

const CATEGORIAS := {"manos": MANOS, "personajes": PERSONAJES, "vfx": VFX, "estilo": ESTILOS}
