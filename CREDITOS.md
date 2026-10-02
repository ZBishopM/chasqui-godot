# Créditos y licencias de los assets

La fuente única de candidatos es `codigo/catalogo.gd`; este archivo lista lo que ya está dentro del repo.
Al añadir un pack: copiar aquí autor, licencia y URL (confirmando la licencia en la página al descargar).

| Id | Qué | Autor | Licencia | Fuente | Ruta |
|---|---|---|---|---|---|
| H1 | Manos propias (metaballs, Blender → glTF) | Chasqui | propia | `chasqui-code/public/models` | `assets/manos/propia/` |
| H3 | PSX First Person Arms (rig, 18 animaciones; con y sin guantes) | Drillimpact | CC0 | https://drillimpact.itch.io/psx-first-person-arms-free | `assets/manos/psx_arms/` |
| H4 | FPS arms (rigged only) | para | CC0 | https://opengameart.org/content/fps-arms-rigged-only | `assets/manos/oga_fps_arms/` |
| P2 | KayKit Adventurers 2.0 (personajes + animaciones `Rig_Medium`) | Kay Lousberg | CC0 | https://kaylousberg.itch.io/kaykit-adventurers | `assets/personajes/kaykit/` |
| P3 | Universal Base Characters (Standard: Superhero hombre y mujer) | Quaternius | CC0 (`License.txt`) | https://quaternius.itch.io/universal-base-characters | `assets/personajes/ubc/` |
| P3m | Universal Animation Library (Standard: 43 animaciones + maniquí) | Quaternius | CC0 (`License.txt`) | https://quaternius.itch.io/universal-animation-library | `assets/personajes/ual/` |
| P4 | Kenney Blocky Characters | Kenney | CC0 | https://kenney.nl/assets/blocky-characters | `assets/personajes/kenney/` |
| V2 | Magic Projectiles VFX (12 proyectiles) | Binbun | CC0 (según su página) | https://binbun3d.itch.io/magic-projectiles-vfx | `assets/BinbunVFX/magic_projectiles/` |
| V3 | Elemental Magic FX, versión gratis (fuego: proyectil, área, casting) | Binbun | CC0 (`license.txt` del pack) | https://binbun3d.itch.io/elemental-magic-fx | `assets/BinbunVFX_Vol2/` |
| V4 | Loot VFX (ofrendas / oro sagrado) | Binbun | CC0 (según su página) | https://binbun3d.itch.io/loot-vfx | `assets/BinbunVFX/loot_effects/` |
| P1, V1 | Humanoide procedural, VFX propios | Chasqui | propia | — | `codigo/personajes.gd`, `codigo/vfx_propios.gd` |

Notas:
- Binbun pide, sin obligar, mencionar «Binbun3D» o «bun3d.com».
- Los packs de Binbun conservan su estructura (`res://assets/BinbunVFX...`): sus escenas llevan esas rutas escritas.
  A las escenas de Elemental Magic FX se les quitaron los UID obsoletos de los `ext_resource` (Godot los resolvía por ruta con un aviso por carga).
- Las texturas del pack Quaternius pesan ~25 MB; si el repo molesta, se pueden bajar de resolución sin tocar el modelo.

Pendiente de descargar: **WRAD ARMS** (https://wriks.itch.io/wrad-arms). El archivo `WRAD_TEXTURES.zip` que apareció en las descargas es otro pack del mismo autor (texturas fotográficas, 732 MB) y no se importó.
