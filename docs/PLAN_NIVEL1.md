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
| N1 | Relieve real, fondo en capas con niebla. | Hecho (`6e79cdd`). Relieve quebrado y abras al sol: `9722f36` |
| N2 | Vida en el suelo: ichu con viento, flores, arbustos, árboles y piedras. | Hecho (`41c5827`) |
| N3 | Zona 1, el pueblo: kit modular inca, kanchas, kallankas, colcas, plazas, escondrijos, pozos, tejados por donde correr, sótano secreto. | Hecho: `codigo/pueblo.gd`, `kit_inca.gd`, `materiales_inca.gd` |
| N4 | Parkour: agarrarse a cornisas, subir a pulso, saltar entre tejados, trepar. PARADA: alturas medidas. | Hecho: `herramientas/probar_parkour.gd` (bordes de 1,2 a 3,5 m, huecos de hasta 8 m) |
| N5 | Zona 2, el Qhapaq Ñan al templo: camino largo y laberíntico entre quebradas, el pozo, atajos y una cueva. | Hecho: `codigo/camino.gd` (~830 m, escalinatas, 2 atajos, tambo, pozo de 15 m, cueva de 160 m) |
| N6 | Zona 3, el Templo del Sol: plataformas escalonadas, ushnu y portada de doble jamba, con vista al amanecer. | Hecho: `codigo/templo.gd` (orientado a 65,8°), plaza circular de Caral, `codigo/cordillera.gd` (nevados lejanos) |
| N7 | Cierre: regresión, rendimiento, README y memoria. | Hecho en la nube (pruebas headless y capturas por software); **falta medir FPS en la GPU y jugarlo en local** |

Después del nivel:

| Qué | Estado |
|---|---|
| Lluvia | Hecha: `codigo/lluvia.gd` (tecla L) |
| Brazos normales → oro | Hecho: `Manos.despertar_oro()` (tecla B) |
| Relieve más accidentado (también en la zona jugable), con un abra donde se pone el sol | Hecho: `hornear_relieve.gd` (×1,4 cerca, ×2,6 lejos, riscos, `ABRAS`) |
| Horizonte, nubes y valle de las fotos de referencia | Hecho: cúmulos grandes de vientre gris, chacras en el valle, cordillera con brecha a la puesta |
| El hogar del Chasqui (morada cálida con el sol entrando por la puerta) | Hecho: `codigo/hogar.gd`, prueba `herramientas/probar_hogar.gd` |
| Nevados creíbles: nieve solo por encima de la cota real, alturas variadas, lo bajo pelado o con plantas | Hecho (`40d8616`): `codigo/biomas_andinos.gdshaderinc`, `cordillera.gd` con los macizos reales |
| Cañón de ~500 m con río junto al Qhapaq Ñan (se ve, no se cae) | Hecho (`e8ba8db`): `codigo/canon.gd`, tallado en `hornear_relieve.gd` |
| Fosa común escondida en el filo del cañón, llena de amortajados | Hecho (`e8ba8db`, escalera `ecbd9d0`): `codigo/fosa.gd`, 144 ragdolls horneados (`hornear_fosa.gd`) |
| Tormenta con rayos (más seguidos en la cinemática, realistas después) | Hecho (`091592e`): `codigo/tormenta.gd` (F5) |
| Cinemática del despertar en la fosa: sangre de los muertos → venas de oro | Hecha y aprobada (`ecbd9d0`, `48acee9`): `codigo/cinematica_despertar.gd` (F4), `sangre.gd`, `Manos.guion()`; detalles abiertos en las notas de abajo |
| Diálogo con Inti en el sueño | Pendiente: gancho `CinematicaDespertar._sueno_inti` (14–18 s) |
| Portar `core/` (españoles, combate, diálogos…) | Pendiente: falta el repo `chasqui-code` |

## Verificación

- `validate_script` antes de cualquier ejecución headless.
- Capturas y tiras de cuadros con `game_eval`. Para el pueblo: `herramientas/recorrido_pueblo.gd`.
- FPS medido en cada zona (meta: ≥ 60 en la RTX 4070 SUPER).
- `game_get_errors` limpio.
- Licencias apuntadas en `CREDITOS.md` antes de bajar nada. N3 a N7 no bajan assets nuevos (la cueva reutiliza las rocas de Poly Haven).

## Notas de N3 para quien siga

- **Dónde está:** `codigo/pueblo.gd` dice dónde va cada cosa; `codigo/kit_inca.gd` dice cómo se arma cada pieza.
- **Coordenadas:** las del pueblo son locales (+x este, +z sur), giradas `Pueblo.ROT` (−9°) alrededor de la plaza, con la y del mundo.
- **Plataformas:** cada kancha va en su propia plataforma, a la altura del punto más alto de su suelo + 0,25 m. Las escaleras exteriores salvan el desnivel; su colisión es una rampa de 37°.
- **Vegetación:** `Terreno.pintar_obras()` recibe las huellas de cada obra (pueblo, camino, templo). Hay que llamarlo antes de crear `Vegetacion`, y así lo hace `nivel1.gd`.
- **Probado en la nube** con Godot 4.7.2 (nixpkgs). La importación y el nivel en headless corren sin errores; el recorrido se renderizó con Vulkan por software (lavapipe), así que esos FPS no cuentan. Falta medir FPS en la RTX 4070 SUPER y jugarlo.
- **Para N4:** los techos están a 40° (se puede caminar por ellos; el `floor_max_angle` es de 45°). Los muros del cerco miden 2,3 m y los fardos dan escalones de 0,55 m. Las sarunas de los andenes miden 0,45 m de vuelo, cada 0,55 m de alto.

## Notas de N5 a N7 para quien siga

- **Orden en `nivel1.gd`:** terreno → pueblo → hogar → cordillera → templo → camino (acaba en `templo.entrada`) → vegetación → lluvia. El hogar pinta su suelo de obra, así que va antes de la vegetación.
- **Huecos del terreno:** `Terreno.abrir_hueco(x, z, radio, radio_colision)`. El dibujo se descarta en el shader (16 huecos como máximo). La colisión lleva NaN en el `HeightMapShape3D` y solo funciona bien con **Jolt** (el proyecto ya lo usa). La pieza de dentro debe tapar el borde: la losa del pozo, y el faldón de colisión y las rocas en la boca de la cueva.
- **El pozo del despertar:** `Camino.POZO`, de 15 m. El fondo es `Camino.despertar` (un `Marker3D`), y la salida es la cueva (`Camino.CUEVA`).
- **Atajos:** se eligen solos (`Camino._atajos`): pares de puntos del camino a ≤ 60 m en línea recta, con 5 a 22 m de desnivel y más de 20 m de camino ahorrado.
- **Templo:** marco local con −z hacia el amanecer del 21 de junio (`Templo.ACIMUT_AMANECER`). Los miradores `amanecer` y `atardecer` llevan su hora.
- **Pruebas:**
  - `herramientas/probar_parkour.gd` y `herramientas/probar_camino.gd`, en headless y con `--fixed-fps 60`.
  - `herramientas/recorrido_pueblo.gd`, con argumentos de hora, miradores y lluvia.
  - `herramientas/capturar_despertar.gd`.
- **Pendiente:**
  - Medir FPS en la GPU por zona.
  - Jugarlo en local.
  - Portar `core/` (españoles), que requiere el repo `chasqui-code`.

## Notas del relieve quebrado y el hogar para quien siga

- **Relieve:** `herramientas/hornear_relieve.gd` rehornea `assets/relieve/vilcas_cerca.res` y `vilcas_lejos.res`. Todo lo construido (pueblo, hogar, camino, templo) se asienta solo sobre `Terreno.altura()`. Si se cambia la exageración, hay que volver a correr `probar_camino.gd`, `probar_parkour.gd` y `probar_hogar.gd`.
- **Abras:** `ABRAS` = [centro, acimut, ancho en grados, desde m, hasta m, cuánto hunde]. Se comprueban con `herramientas/perfil_horizonte.gd`. La cordillera tiene su propia brecha (`Cordillera.ACIMUT_PUESTA`). No da sombra (`cast_shadow` apagado), pero sí tapa el disco del sol.
- **Sol del 21 de junio** (Sky3D, en el nivel):

  | Hora | Acimut | Elevación |
  |---|---|---|
  | 16:30 | 298,7° | 13,5° |
  | 16:45 | 297,5° | 10,3° |
  | 17:00 | 296,3° | 7,1° |
  | 17:15 | 295,3° | 3,8° |

  Desde el hogar, el horizonte en el abra está a unos 5°.
- **Hogar:**
  - **Marco:** `Hogar._marco` tiene +z hacia la puesta, y `_casa` es el marco de la casa (el piso en y = 0).
  - **Rayos:**
    - Lo que se ve es `Hogar._actualizar_haz`: diez láminas aditivas desde el vano, en la dirección del sol (`Hogar.sol`, que pone `nivel1.gd`).
    - La niebla volumétrica del `Environment` tiene densidad 0: solo la pone el `FogVolume` de la casa (0,08; más espesa enturbia el cuarto). `nivel1._process` la enciende a menos de `Hogar.RADIO_NIEBLA`.
  - **Luz del sol en el interior:** a las 16:45 (10°) la luz entra casi por el eje pero rasante, y en el suelo deja poco. Por eso los miradores de dentro van a las 16:00 (20°).
  - **Cerco:** sus muros miden 2,3 m. Un vano más alto que el muro deja geometría por encima del hueco, así que la portada (2,1 m) cabe dentro.
- **Pruebas con rayos:** el borde de la zona jugable tiene muros invisibles (a ±596 m, `Terreno`). Un rayo físico hacia el sol choca con ellos, así que no sirve para saber si algo da sombra. Para eso hay que hacer capturas.

## Notas de nevados, cañón, fosa y cinemática para quien siga

- **Altitud real:** `bio_msnm(p) = 3482 + y / bio_exageracion(r)`, donde la exageración va de ×1,4 a ×2,6 entre 700 y 6000 m de la plaza (la de `hornear_relieve.gd`). Si cambia la exageración del relieve, hay que cambiarla también en `biomas_andinos.gdshaderinc` y en `Cordillera.EXAGERACION`.
- **Fuentes de la nieve y los pisos:**
  - línea de nieve de 4700 m (este húmedo) a 5100 m (oeste seco) en el Perú central;
  - ELA tropical por encima de 5000 m, con lenguas hasta ~4600 m;
  - Polylepis de 3500 a 4800 m;
  - puna húmeda central.
  - Fuentes:
    - [Línea de nieve en los Andes peruanos (J. Glaciology)](https://www.cambridge.org/core/journals/journal-of-glaciology/article/observations-on-the-snow-line-in-the-peruvian-andes/612B481F59DB84DC31B416AE304C710E)
    - [ELA de glaciares tropicales (Frontiers)](https://www.frontiersin.org/journals/earth-science/articles/10.3389/feart.2022.838826/full)
    - [Puna húmeda de los Andes centrales](https://www.oneearth.org/ecoregions/central-andean-wet-puna/)
    - [Polylepis en el Perú](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12655902/)
    - [Ccarhuarazo](https://en.wikipedia.org/wiki/Ccarhuarazo_(Ayacucho))
    - [Pumasillo](https://en.wikipedia.org/wiki/Pumasillo)
- **Cañón:**
  - El eje (`Canon.EJE`) se trazó desde un borde norte a ≥ 52 m en perpendicular de la calzada.
  - `Canon.tallar` usa una rejilla de celdas de 100 m. Ojo en GDScript: los `Packed*Array` que se sacan de un `Dictionary` son copias, así que hay que volver a guardarlos.
  - Si se toca el cañón: rehornear el relieve y volver a correr `probar_camino`, `probar_hogar` y `probar_parkour`.
- **Fosa:**
  - **Sitio:** (191, 160), oculto desde la calzada (0 de 43 puntos del camino la ven).
  - **Si cambian el hoyo o los escalones:** rehornear el montón (`hornear_fosa.gd -- 144`, ~10 s, determinista) y comprobar que dice «0 segmentos fuera del hoyo».
  - **Capa de render:** los cuerpos van en la capa 2 (`Fosa.CAPA_CUERPOS`) para que los charcos (`Decal`, `cull_mask` 1) no los pinten.
- **Tormenta:**
  - `Sky3D` vuelve a poner su `ambient_light_sky_contribution` con un tween al cruzar a la noche. Por eso la tormenta baja `night_sky_contribution` en vez de tocar el `Environment` directamente.
  - Con `parar()` vuelven la hora, el reloj, la luna y el ambiente que había.
- **Cinemática:**
  - **Prioridad:** `process_priority` 100, para correr después del `Jugador`, que pone la altura de la cabeza cada cuadro.
  - **Orden en cada cuadro:** primero `_poner(t)` y luego los sucesos. Si no, los hilos se trazaban con la cabeza aún de pie y quedaban 0,75 m por encima de la mano.
  - **Los hilos no siguen a la mano:** su final queda fijo donde estaban los nudillos al salir (20,4 s). Funciona porque las manos están quietas hasta que se dan la vuelta (26,5 s), y para entonces ya han entrado todos.
  - **Tiras de cuadros:** `capturar_fosa.gd` solo dibuja los cuadros justo antes de cada captura (`RenderingServer.render_loop_enabled`). Con Vulkan por software, dibujarlos todos tardaba ~5 h; así, unos 40 min.
- **Abierto (aprobado así, para revisar):**
  - **Cuadro del pico (32,3 s):** el rayo cercano y el destello aún lo hacen parecer de día durante ~0,1 s. Se podría bajar más la luz del rayo en ese instante y dejar que brille solo el oro.
  - **Encuadre de las manos:** del puño en adelante (27–35 s) quedan en los bordes de la pantalla. Se podrían juntar hacia el centro con la pose del guion.
  - **Rayo de los 3,6 s:** apenas se ve; se ve el fogonazo, pero el trazo cae en el borde borroso de los párpados.
  - **Gotas al entrar:** los hilos no sueltan gotitas al entrar en la mano.
  - **Trueno:** no hay; el proyecto aún no tiene audio.
  - **FPS en la GPU:** sin medir. La fosa suma 144 mallas de ~1000 vértices y 864 cápsulas estáticas, y carga en ~1 s.
