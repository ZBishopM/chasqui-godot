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
4. Si es un `tipo` nuevo: adaptador en `codigo/personajes.gd` o un `vfx_*.gd`.

Descargas a mano (itch.io y Sketchfab piden clic o cuenta): dejarlas en `_descargas/` (Godot no la importa, ni git la sube).
Manos: brazos con `Skeleton3D` y una escena con el `AnimationPlayer` `Gestos` (ver abajo). Tipos de adaptador que ya existen: personajes `procedural`, `kaykit`, `kenney`, `ubc` y `ual`; VFX `propio`, `binbun_proyectiles` y `binbun_elemental`.
Los VFX de packs solo ponen el visual: la mecánica de cada poder (empuje del Halcón, hundimiento del Sapo, tiempo del Colibrí, siluetas del Puma) sale de `VfxPropios.mecanica()`.

## Gestos de las manos (H3 y H4): editables en el editor de Godot

Los gestos de los seis poderes son **clips `Animation` normales** guardados en una escena: `escenas/manos_h3.tscn` (PSX) y `escenas/manos_h4.tscn` (OpenGameArt). Cada una tiene un `AnimationPlayer` llamado `Gestos` con el clip `reposo`, uno por poder (`halcon`, `sapo`, `amaru`, `condor`, `puma`, `colibri`) y, en la librería `originales`, los clips que traía el pack.

Para retocar un gesto: abre la escena → selecciona `Gestos` → elige el clip en el panel de animación → mueve el hueso en el Inspector (`Skeleton3D` › Bones) y pulsa la llave para insertar la clave. La demo carga la escena tal cual; no hace falta regenerar nada.

Si prefieres cambiar *números* en vez de claves: edita `PICOS` (grados por movimiento) en `herramientas/generar_h4.gd`, o `GESTOS` (de qué clip se toma la pose) en `generar_h3.gd`, y vuelve a ejecutar. **Ojo: regenerar pisa las claves que hayas tocado a mano en esos clips.**

```
godot.console.exe --headless --path . --script res://herramientas/generar_h3.gd
godot.console.exe --headless --path . --script res://herramientas/generar_h4.gd
```

- **H3:** cada clip del pack empieza y termina en su propia postura (mano abajo, pistola, guardia…), a 76–93° del `relax` que se usa de reposo; por eso volver era brusco. Los gestos nuevos salen del `relax` hacia el ápice del clip original y vuelven con curva suave, más una mezcla de 0,15 s al entrar y 0,4 s al salir (`MEZCLA_ENTRADA/SALIDA` en `manos.gd`).
- **H4:** el rig no trae clips de gesto. `herramientas/ejes_mano.gd` calcula, de la geometría del rig, el eje con sentido de cada movimiento («el dedo se dobla hacia la palma», «el brazo sube»), así que las poses no dependen de cómo orientó sus huesos quien lo modeló.

## Piel densa (para las venas)

`piel=` en el catálogo carga una versión densa de la malla de los brazos (`escenas/piel_h3.res`, `piel_h4.res`): el antebrazo, la muñeca y el dorso/palma tienen aristas de 4 mm como máximo, para que las venas puedan abultar la piel. La hornea `herramientas/hornear_piel.gd` con `codigo/malla_densa.gd` (solo parte las aristas largas de esa zona; el resto queda como estaba). Hay que volver a hornear si cambia el modelo:

```
godot.console.exe --headless --path . --script res://herramientas/hornear_piel.gd
```

## Pruebas automáticas

`codigo/banco.gd` expone, para el MCP de Godot (`game_eval`):

- `probar(poder, instantes)` y `probar_todo()`: lanzan los poderes y guardan capturas en `capturas/`.
- `capturar_picos()`: congela cada gesto de las manos en su pico y guarda `manos_<id>_<poder>.png`.
- `medir_suavidad()`: velocidad angular máxima del hueso más rápido durante cada gesto (°/s). Un salto de 90° en un frame da más de 10 000; un gesto fluido queda bajo ~700. Estado actual: H3 260–510 °/s, H4 410–730 °/s.

Humo sin ventana: `godot.console.exe --headless --path . --quit-after 120` (**N son frames**, ~60/s; nunca `godot.exe`, traga la salida).
