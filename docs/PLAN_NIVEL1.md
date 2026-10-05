# Primer nivel: Vilcashuamán (prólogo, Acto I), por hitos con capturas

Copia en el repo del plan aprobado. El original estaba en `C:\Users\obisp\.claude\plans\verify-what-s-missing-first-hashed-lovelace.md`. Así cualquier sesión, local o en la nube, sabe por dónde va el trabajo.

## Contexto

El banco de manos y poderes ya está hecho; ahora toca el escenario. Se pidió un mundo inmenso, basado en lugares reales del Perú de la época, con:

- parkour por tejados y caminos largos y laberínticos;
- atajos, pisos y lugares secretos, incluidas cuevas;
- amanecer, atardecer y noche;
- plantas, flores y relieve, con el suelo vivo por el viento;
- un fondo que invite a explorar aunque no se pueda llegar.

El camino es lineal, pero lleno de atajos.

El primer nivel tiene 3 zonas:

1. El conjunto de casas.
2. El camino al templo, con el pozo donde el Chasqui despertará después.
3. El Templo inca del Sol, con vista al horizonte.

Después: lluvia y animación de brazos normales → brazos con oro.

### Decisiones

- Templo inca del Sol, no iglesia colonial.
- Lugar real: Vilcashuamán (Ayacucho).
- Los españoles llegan después, al portar `core/`. Portar core es pasar a GDScript la lógica de juego de la versión web (`chasqui-code/src/core/`): GameManager, Camaquen, Journey, Dialogue, Interaction, Combat, PlayerHealth, Objectives, ManaSystem, DayNightCycle y LightSampler. Sus 460 tests sirven de especificación, y la IA de los españoles sale de ahí.

### Forma de trabajo

Cada hito termina en PARADA, con capturas y números. No se sigue hasta el «sigue» del usuario, y se hace commit al aprobar cada hito.

## Investigación

- **Terreno:** se descarta Terrain3D (MIT). Su 1.0.2 se da por buena hasta Godot 4.6, y en 4.7 hay cuelgues al tocar regiones (issues #1041 y #1043). En su lugar va un terreno propio (`codigo/terreno.gd`).
- **Relieve real:** Copernicus GLO-30 (30 m, licencia libre Copernicus). El nivel jugable va hecho a mano encima, a escala 1:1.
- **Cielo:** Sky3D (MIT): sol, luna con fases, estrellas, nubes y niebla según la hora.
- **Hierba con viento:** ichu procedural en la GPU, que se aparta al paso del jugador.
- **Parkour:** dos rayos a la altura de la cabeza (el de abajo choca y el de arriba no = cornisa). De ahí salen agarrarse, subir y saltar a otra cornisa. Referencias: teitasan/climbing_physics_prototype y Godot-Thief-Controller.
- **Paralaje:** sale de la geometría real a distintas distancias, más niebla de distancia.
- **Investigación del pueblo (N3):** kanchas con muros de pirca, hastiales de piedra, vanos trapezoidales y techos de ichu; trazado en cuadrícula como Ollantaytambo; kallankas que se abren a la plaza; colcas en hilera en las laderas. El pueblo va en la meseta junto a la plaza y el templo en la altura sureste, mirando al amanecer del Inti Raymi; los une un camino entre quebradas.

## Hitos

| Hito | Qué | Estado |
|---|---|---|
| N0 | Escena del nivel. Sky3D con un día de 20 min y teclas para la hora. | Hecho (`38c39c3`) |
| N1 | Relieve real, fondo en capas con niebla. | Hecho (`6e79cdd`). Pendiente: relieve más accidentado (pedido para después). |
| N2 | Vida en el suelo: ichu con viento, flores, arbustos, árboles y piedras. | Hecho (`41c5827`) |
| N3 | Zona 1, el pueblo: kit modular inca, kanchas, kallankas, colcas, plazas, escondrijos, pozos, tejados por donde correr, sótano secreto. | **Hecho en la rama `claude/modest-brahmagupta-bjqbe0`; PARADA pendiente** (probar en local) |
| N4 | Parkour: agarrarse a cornisas, subir a pulso, saltar entre tejados, trepar. PARADA: tiras de cuadros y alturas medidas. | — |
| N5 | Zona 2, el Qhapaq Ñan al templo: camino largo y laberíntico entre andenes y quebradas, el pozo, atajos y una cueva. | — |
| N6 | Zona 3, el Templo del Sol: plataformas escalonadas, ushnu y portada de doble jamba, con vista al amanecer. | — |
| N7 | Cierre: regresión, rendimiento, README y memoria. | — |

Después: lluvia; brazos normales → oro; portar `core/` (españoles).

## Verificación

- `validate_script` antes de cualquier ejecución headless.
- Capturas y tiras de cuadros con `game_eval`. Para el pueblo: `herramientas/recorrido_pueblo.gd`.
- FPS medido en cada zona (meta: ≥ 60 en la RTX 4070 SUPER).
- `game_get_errors` limpio.
- Licencias apuntadas en `CREDITOS.md` antes de bajar nada. N3 no baja assets nuevos.

## Notas de N3 para quien siga

- **Dónde está:** `codigo/pueblo.gd` dice dónde va cada cosa; `codigo/kit_inca.gd` dice cómo se arma cada pieza.
- **Coordenadas:** las del pueblo son locales (+x este, +z sur), giradas `Pueblo.ROT` (−9°) alrededor de la plaza, con la y del mundo.
- **Plataformas:** cada kancha va en su propia plataforma, a la altura del punto más alto de su suelo + 0,25 m. Las escaleras exteriores salvan el desnivel; su colisión es una rampa de 37°.
- **Vegetación:** `Terreno.poner_obras()` recibe la máscara de obra. Hay que llamarlo antes de crear `Vegetacion`, y así lo hace `nivel1.gd`.
- **Probado en la nube** con Godot 4.7.2 (nixpkgs). La importación y el nivel en headless corren sin errores; el recorrido se renderizó con Vulkan por software (lavapipe), así que esos FPS no cuentan. Falta medir FPS en la RTX 4070 SUPER y jugarlo.
- **Para N4:** los techos están a 40° (se puede caminar por ellos; el `floor_max_angle` es de 45°). Los muros del cerco miden 2,3 m y los fardos dan escalones de 0,55 m. Las sarunas de los andenes miden 0,45 m de vuelo, cada 0,55 m de alto.
