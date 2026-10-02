# Chasqui — Banco de combinaciones (Godot 4.7)

Demo técnica para elegir qué **manos**, **personaje**, **VFX de poderes** y **estilo** usa Chasqui. Todo se cambia en vivo.
El diseño del juego no cambia: ver `../GDD.md`. Esta carpeta es la migración a Godot de la versión web (`../chasqui-code`).

## Abrir

```
godot --path D:\2026-projects\chasqui\chasqui-godot          # ejecuta la demo
godot -e --path D:\2026-projects\chasqui\chasqui-godot       # abre el editor (F5 = jugar)
```

La primera vez, el editor importa los assets (unos segundos).

### Trabajar con el editor abierto

El editor y la demo que lanza Claude (por el MCP de Godot) **conviven**: son dos procesos. Con el editor abierto, Claude edita los archivos del disco y Godot los recarga al volver a la ventana. La ventana «Chasqui (DEBUG)» que abre Claude es un juego real: se puede jugar con el mouse y el teclado a la vez que él la maneja.

- F5 en el editor lanza **tu** juego; Claude no puede manejar esa ventana (solo la que lanza él).
- Cuando Claude cambia un `.gd` o el catálogo, relanza su ventana; la tuya hay que reiniciarla (F5 otra vez).
- Si Godot pregunta «archivos modificados en disco», elige «Recargar».
- Ejecutar el proyecto desde Claude añade temporalmente un autoload (`mcp_interaction_server.gd`) a `project.godot`; se quita al detener el juego.

## Controles

| Tecla | Hace |
|---|---|
| WASD · Espacio · mouse | moverse, saltar, mirar |
| `1` manos · `2` personaje · `3` VFX · `4` estilo | siguiente candidato (con **Mayús**: el anterior) |
| `F` Halcón · `G` Sapo · `R` Amaru · `T` Cóndor · `V` Puma · `C` Colibrí | poderes (Mayús+`C`: ralentiza en vez de detener) |
| `O` | ofrenda: efecto de recogida (Loot VFX de Binbun) en el suelo, de común a mítico |
| `Tab` | vitrina: todos los personajes en fila |
| `K` | guarda `combinacion.json` + una captura en `capturas/` |
| `F1` · `Esc` | oculta el HUD · libera el mouse |

El HUD muestra, por cada categoría, el candidato actual con su licencia y autor.

## Añadir un pack

1. Copiar los archivos a `assets/<categoría>/<pack>/` (con su `License.txt`).
2. Añadir una entrada en `codigo/catalogo.gd` (`tipo` decide el adaptador).
3. Anotar autor, licencia y URL en `CREDITOS.md`.
4. Si es un `tipo` nuevo: adaptador en `codigo/manos.gd`, `codigo/personajes.gd` o un `vfx_*.gd`.

Descargas a mano (itch.io y Sketchfab piden clic o cuenta): dejarlas en `_descargas/` (Godot no la importa, ni git la sube).
Tipos de adaptador que ya existen: manos `propia` y `skel_brazos` (esqueleto + gestos por huesos o por clips); personajes `procedural`, `kaykit`, `kenney`, `ubc` y `ual`; VFX `propio`, `binbun_proyectiles` y `binbun_elemental`.
Los VFX de packs solo ponen el visual: la mecánica de cada poder (empuje del Halcón, hundimiento del Sapo, tiempo del Colibrí, siluetas del Puma) sale de `VfxPropios.mecanica()`.

## Pruebas automáticas

`codigo/banco.gd` expone `probar(poder, instantes)` y `probar_todo()`: lanzan los poderes y guardan capturas en `capturas/`. Se usan desde el MCP de Godot (`game_eval`).

Humo sin ventana: `godot.console.exe --headless --path . --quit-after 120` (**N son frames**, ~60/s; nunca `godot.exe`, traga la salida).
