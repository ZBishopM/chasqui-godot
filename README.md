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

Si prefieres cambiar *números* en vez de claves: edita `GESTOS` (de qué clip se toma la pose) en `herramientas/generar_h3.gd` y vuelve a ejecutar; H4 se regenera copiando a H3 (abajo). **Ojo: regenerar pisa las claves que hayas tocado a mano en esos clips.**

```
godot.console.exe --headless --path . --script res://herramientas/generar_h3.gd
godot.console.exe --headless --path . --script res://herramientas/retargetear_h4.gd
```

- **H3:** cada clip del pack empieza y termina en su propia postura (mano abajo, pistola, guardia…), a 76–93° del `relax` que se usa de reposo; por eso volver era brusco. Los gestos nuevos salen del `relax` hacia el ápice del clip original y vuelven con curva suave, más una mezcla de 0,15 s al entrar y 0,4 s al salir (`MEZCLA_ENTRADA/SALIDA` en `manos.gd`).
- **H4 copia a H3** (`herramientas/retargetear_h4.gd`): el reposo y los seis gestos, cuadro a cuadro. No copia rotaciones (los dos rigs orientan distinto sus huesos) sino direcciones en el mundo: cada hueso de H4 gira lo mínimo para apuntar adonde apunta el suyo en H3, y la mano copia además hacia dónde mira la palma. Encima, el antebrazo y la mano giran `GIRO_DORSO` (20°) sobre el eje del antebrazo para que se vea más el dorso. Encuadre: `manos_en` del catálogo = donde quedan las muñecas de H3 respecto al ojo (el script lo imprime).
- **Trampa de H4:** su mano no cuelga del antebrazo sino de `hand.L.control`, un control de IK que Godot no resuelve; por eso sus gestos de antes se veían raros. El retarget pega la mano a la muñeca en cada cuadro. Los gestos anteriores (poses por grados, `PICOS` en `generar_h4.gd`) vuelven ejecutando `generar_h4.gd`.

## Salto y aterrizaje

Capa de resorte sobre la altura de las manos (`Manos._salto`): al despegar se quedan atrás, en el aire flotan, y al tocar el suelo se hunden con un golpe proporcional a la caída y suben sin rebotar, como en tierra o pasto. El peso depende de la altura: una caída corta es ligera y rápida (0,15 m: −0,6 cm, quietas en 0,16 s) y desde `SALTO_CAIDA_MAX` (5 m/s, un salto normal en plano) es la más pesada (−4 cm, quietas en ~0,45 s); caer de más alto no la pasa. Se ajusta con las constantes `SALTO_*` de `codigo/manos.gd`.

La patada de FOV del Halcón (+16°) siempre vuelve al FOV de reposo del rig, aunque se pulse F seguido; el hundimiento del Sapo tampoco se acumula (`VfxPropios._tween_unico`).

## Venas de oro bajo la piel

Las venas son bultos de la propia piel, no mallas encima: abultan el antebrazo y el dorso de la mano y el oro se trasluce por ellas.

- **Piel densa:** `piel=` en el catálogo carga la malla de los brazos con el antebrazo, la muñeca y el dorso/palma partidos hasta aristas de 2,5 mm (`escenas/piel_h3.res`, `piel_h4.res`; `codigo/malla_densa.gd`). Así una vena tiene vértices de sobra a lo ancho.
- **La red de venas** (`herramientas/campo_venas.gd`) se hornea en esos vértices: curvas irregulares en el antebrazo (las que vienen del dorso, dos gruesas por la cara interna y ramas en Y) y en el dorso de la mano (una entre cada par de nudillos y el arco que las cruza), con varices y puntas que se hunden. Cada vértice guarda su distancia a la vena más cercana.
- **El shader** (`codigo/piel_venas.gd`, `PielVenas`) empuja la piel por la normal con un perfil de bulto, inclina la normal para que la luz dibuje el relieve y enciende el oro: núcleo dorado y halo rojizo, como luz que atraviesa la carne.
- **Estados** (los mueve `Manos`): en reposo las venas tienen el tamaño `Manos.venas_base` (lo fija el juego: 0 sin poderes, 0,5 con poderes, sube hacia 1 con el Caos) y el oro solo late. Al usar un poder, un frente sube de los nudillos al codo con la curva de esfuerzo del gesto: por detrás las venas se hinchan al 100 % y el oro se enciende (`AnimProc.brillo_venas`, con su espasmo); luego vuelven a `venas_base`. El brazo sin poder acompaña al 30 %. `Manos.mana` (0–1) apaga el oro con el maná vacío.
- **Se tocan en vivo** (parámetros del material): `altura` (m), `grosor` (1 = Caos bajo, ~1,5 = Caos alto), `luz`, `luz_reposo`, `latido`, `color_oro`.

Volver a hornear si cambia el modelo o el trazado (`SEMILLA` en `hornear_piel.gd` da otra red igual de verosímil):

```
godot.console.exe --headless --path . --script res://herramientas/hornear_piel.gd
```

## Pruebas automáticas

`codigo/banco.gd` expone, para el MCP de Godot (`game_eval`):

- `probar(poder, instantes)` y `probar_todo()`: lanzan los poderes y guardan capturas en `capturas/`.
- `capturar_picos()`: congela cada gesto de las manos en su pico y guarda `manos_<id>_<poder>.png`.
- `medir_suavidad()`: velocidad angular máxima del hueso más rápido durante cada gesto (°/s). Un salto de 90° en un frame da más de 10 000; un gesto fluido queda bajo ~700. Estado actual: H3 260–510 °/s, H4 410–730 °/s.

Humo sin ventana: `godot.console.exe --headless --path . --quit-after 120` (**N son frames**, ~60/s; nunca `godot.exe`, traga la salida).
