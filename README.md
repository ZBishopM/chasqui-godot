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
| `Mayús` (mantener, hacia delante) · `Ctrl` (mantener) | esprintar · agacharse |
| `1` manos · `2` personaje · `3` VFX · `4` estilo | siguiente candidato (con **Mayús**: el anterior) |
| `F` Halcón · `G` Sapo · `R` Amaru · `T` Cóndor · `V` Puma · `C` Colibrí | poderes (Mayús+`C`: ralentiza en vez de detener) |
| `O` | ofrenda: efecto de recogida (Loot VFX de Binbun) en el suelo, de común a mítico |
| `Tab` | vitrina: todos los personajes en fila |
| `K` | guarda `combinacion.json` + una captura en `capturas/` |
| `F1` · `Esc` | oculta el HUD · libera el mouse |
| `F2` | banco ↔ Nivel 1 (Vilcashuamán) |
| `RePág` / `AvPág` · `Inicio` · `Fin` | (nivel) una hora más / menos · salta al amanecer · pausa el reloj |
| `F3` (Mayús: atrás) | (nivel) siguiente mirador: pueblo, camino, pozo, cueva, templo, amanecer… |
| `L` | (nivel) lluvia: empieza o para (tarda unos segundos; el suelo se moja y se seca despacio) |
| `B` | brazos normales; otra vez: el despertar del oro (de brazos normales a brazos que contienen el oro) |
| `W` / `Espacio` · `A`/`D` · `S`/`Ctrl` | (colgado de una cornisa) subir a pulso · desplazarse · soltarse (`S` + `Espacio`: salto atrás) |

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

## Moverse: andar, esprintar, agacharse

- **Andar** (5 m/s): las manos se balancean en un ocho, un rebote por pisada (`BOB`, `PASO_LARGO` en `manos.gd`).
- **Esprintar** (Mayús, 8 m/s): las manos bajan, se cierran en puño y bombean al ritmo del paso (`CapasManos`: `BOMBEO_GRADOS`, `CODO_GRADOS`). El puño no es procedural: se copia del puño hecho a mano de los gestos (`PUNO_CLIP`: izquierda de Halcón, derecha de Cóndor). H4 gira además el antebrazo `giro_puno` (catálogo) para que el puño quede como el de H3.
- **Agacharse** (Ctrl): cámara de 1,6 a 1,0 m, 2,5 m/s, sin esprint ni salto; al soltar solo se levanta si cabe. Los bordes de la pantalla se oscurecen (`agachado` en `SHADER_PANTALLA`).
- **FOV:** el jugador es su único dueño: el del rig de manos + la patada del Halcón (+16°, nunca se acumula) + 15° al esprintar. Las manos se dibujan siempre con el FOV del rig (`fov_manos` de `PielVenas`), así que al abrirse el mundo los antebrazos no se estiran.
- **Tics de reposo** (`CapasManos`, primera versión, pendiente de pulir): quieto y sin poder, de vez en cuando una mano tamborilea, se estira o aprieta.

`CapasManos` es un `SkeletonModifier3D`: corre después del `AnimationPlayer` y suma todo esto encima de los clips, sin tocarlos.

## Parkour (N4)

`Jugador` busca cornisas en el aire mirando a un muro: un rayo al pecho encuentra la cara y otro desde arriba encuentra el borde.

- **Bordes bajos:** si el borde queda por debajo del pecho, sube de una vez.
- **Bordes altos:** si queda más arriba, se cuelga y las manos suben a agarrarlo (`Jugador.colgado` → `Manos`).
- **Colgado:** A/D se desplaza por la cornisa (1,4 m/s, se para donde acaba el borde); W o Espacio sube a pulso (agachado si arriba no cabe de pie); Ctrl o S se suelta; S + Espacio salta hacia atrás.
- **Saltos:** tiempo de coyote y salto anticipado de 0,12 s.

Medido con `herramientas/probar_parkour.gd` (headless):

| Muro | Resultado |
|---|---|
| 0,8 m | se salta por encima |
| 1,2 m | se sube de un salto |
| 1,5–2,3 m (cercos) | sube sin colgarse |
| 2,5–3,5 m | se cuelga y sube a pulso |
| 3,8 m o más | no llega |

Los huecos entre tejados se saltan esprintando hasta 8 m (aterriza a 0,3 m del borde). Constantes: `AGARRE_ALTO`, `SIN_COLGARSE`, `LATERAL`, `SUBIR_SEG`, `COYOTE`, `ANTICIPO` en `jugador.gd`.

```
godot.console.exe --headless --path . --script res://herramientas/probar_parkour.gd
```

## Sombra del jugador

Los brazos en primera persona no dan sombra. La da `CuerpoSombra`: el maniquí de Quaternius (UAL), invisible para la cámara (`SHADOWS_ONLY`), colgado del jugador. Anima reposo, trote, esprint, agachado y salto según el estado del jugador, y sus brazos apuntan adonde apuntan los brazos en primera persona (`BrazosSombra`). No copia los puños ni el bombeo del esprint.

## Tiempos de los poderes

- El **Halcón** sube al doble de velocidad hasta el pico (`ARRANQUE` en `manos.gd`): mano arriba a los 286 ms de la tecla y despegue a los 358 ms. El efecto de cada poder sale en el pico de su gesto (`Manos.retardo_pico()`).
- Las **marcas** (venas) tienen su propio reloj: suben con la mano y se apagan más despacio; la parte visible dura ~50 % más que el gesto (`VENAS_DURACION` = 1,75). El **Colibrí** las deja en el pico los 5 s del tiempo detenido (`Manos.sostener_venas`), y el gris de la pantalla respeta el oro encendido.
- La patada de FOV del Halcón y el hundimiento del Sapo no se acumulan al repetir el poder (`VfxPropios._tween_unico`).

## Venas de oro bajo la piel

Las venas son bultos de la propia piel, no mallas encima: abultan el antebrazo y el dorso de la mano y el oro se trasluce por ellas.

- **Piel densa:** `piel=` en el catálogo carga la malla de los brazos con el antebrazo, la muñeca y el dorso/palma partidos hasta aristas de 2,5 mm (`escenas/piel_h3.res`, `piel_h4.res`; `codigo/malla_densa.gd`). Así una vena tiene vértices de sobra a lo ancho.
- **La red de venas** (`herramientas/campo_venas.gd`) se hornea en esos vértices: curvas irregulares en el antebrazo (las que vienen del dorso, dos gruesas por la cara interna y ramas en Y) y en el dorso de la mano (una entre cada par de nudillos y el arco que las cruza), con varices y puntas que se hunden. Cada vértice guarda su distancia a la vena más cercana.
- **El shader** (`codigo/piel_venas.gd`, `PielVenas`) empuja la piel por la normal con un perfil de bulto, inclina la normal para que la luz dibuje el relieve y enciende el oro: núcleo dorado y halo rojizo, como luz que atraviesa la carne.
- **Oro en bruto e infectado:** la vena es oro sucio (ocre) con pepitas de oro más puro. Cuando arde, lleva dentro, como lava viva, costras negras que derivan con el borde al rojo y coágulos rojos que se forman y se deshacen; en reposo la infección no se ve.
- **Estados** (los mueve `Manos`): en reposo las venas tienen el tamaño `Manos.venas_base` (lo fija el juego: 0 sin poderes, 0,5 con poderes, sube hacia 1 con el Caos) y el oro solo late. Al usar un poder, un frente sube de los nudillos al codo con la curva de esfuerzo del gesto: por detrás las venas se hinchan al 100 % y el oro se enciende (`AnimProc.brillo_venas`, con su espasmo); luego vuelven a `venas_base`. El brazo sin poder acompaña al 30 %. `Manos.mana` (0–1) apaga el oro con el maná vacío.
- **Se tocan en vivo** (parámetros del material): `altura` (m), `grosor` (1 = Caos bajo, ~1,5 = Caos alto), `luz`, `luz_reposo`, `latido`, `color_oro`, `color_pepita`, `pepitas`, `pepitas_escala`, `infeccion`, `coagulos`, `color_coagulo`.

Volver a hornear si cambia el modelo o el trazado (`SEMILLA` en `hornear_piel.gd` da otra red igual de verosímil):

```
godot.console.exe --headless --path . --script res://herramientas/hornear_piel.gd
```

## Nivel 1: Vilcashuamán (prólogo, Acto I)

Plan por hitos en `docs/PLAN_NIVEL1.md` (cada hito termina en PARADA con capturas y números). `F2` abre el nivel.

- **N0, cielo** (`codigo/nivel1.gd`, `addons/sky_3d`): Sky3D con la latitud, la longitud y la fecha reales (21 de junio de 1532, Inti Raymi). Un día = 20 min.
- **N1, relieve** (`codigo/terreno.gd`, `herramientas/recortar_dem.gd`, `hornear_relieve.gd`): Copernicus GLO-30 alrededor de la plaza, en tres anillos (1,2 km a 2 m jugables, 12 km, 39 km).
- **N2, suelo vivo** (`codigo/vegetacion.gd`): ichu procedural con viento, y flores, matorrales, árboles y rocas de Poly Haven.
- **N3, el pueblo** (`codigo/pueblo.gd`, `codigo/kit_inca.gd`, `codigo/materiales_inca.gd`):
  - **Traza:** cuadrícula como Ollantaytambo, girada 9°. Manzanas de dos kanchas (cercos con casas alrededor de un patio) y callejones de 4 m alrededor de una plaza de 92 × 56 m. Al norte de la plaza, dos kallankas de sillería con seis puertas.
  - **Bordes:** al este, andenes con colcas que suben la ladera hacia el templo; al oeste, casas redondas.
  - **Plataformas:** la meseta tiene unos 10 m de desnivel, así que cada kancha va en su propia plataforma de pirca y el pueblo baja en terrazas.
  - **Kit:** muros con talud y vanos trapezoidales (puertas, ventanas, hornacinas), hastiales, techos de ichu a dos aguas y cónicos, colcas, pozos, escaleras (la colisión es una rampa), plataformas con trampillas, aríbalos, fardos y batanes. Todo se genera al cargar (~0,2 s): una malla por material y una sola colisión por manzana.
  - **Materiales sin texturas nuevas:** la piedra (pirca, sillería, poligonal) y la paja se dibujan en el shader a partir de UV en metros, y la roca de Poly Haven pone el grano.
  - **Parkour (N4 lo completa):** techos a 40° por los que se camina, coronaciones de muro de 2,3 m, pilas de fardos para subir, sarunas (piedras voladizas) en los andenes, y callejones que se saltan de techo a techo.
  - **Escondites:** colcas en las que se entra agachado, casas oscuras, fardos, y un sótano bajo una casa del oeste. Al sótano se entra por una trampilla tapada por fardos, y se sale a gatas por el muro de la plataforma.
  - **Suelo de obra:** `Pueblo` pinta una máscara (`Terreno.poner_obras`). Ahí no crece ichu, no se reparten plantas y el terreno pinta tierra pisada.

- **N5, el Qhapaq Ñan** (`codigo/camino.gd`): la zona 2, unos 830 m desde la plaza (por el callejón del este y el norte de los andenes) hasta la explanada del templo, con ~85 m de subida.
  - **Calzada:** 3,6 m de losas sobre un trazado de coste mínimo calculado en el relieve real, con curvas de herradura añadidas.
  - **Escalinatas** donde la pendiente pasa del 18 % (177 m en total). Su colisión es una rampa.
  - **Muros y parapetos:** muro de contención donde va en terraplén, parapeto donde la caída pasa de 1,5 m.
  - **Atajos:** donde el camino da la vuelta, terrazas de ≤ 2,4 m que se trepan con el parkour (el mejor ahorra 84 m).
  - **Tambo** (posada) y, junto a él, la plazuela del **pozo**: 15 m de caída hasta una cámara, que es donde despertará el Chasqui (`Camino.despertar`, un `Marker3D`).
  - **Cueva:** 160 m de túnel, oscuro lejos de las bocas, que sale en trinchera a la ladera entre el pueblo y el camino, con rocas en la boca.
  - **Corrales** de pirca para esconderse.
  - **Huecos en el terreno:** `Terreno.abrir_hueco()` no dibuja el suelo y lo quita de la colisión (NaN en el `HeightMapShape3D`).
- **Física:** el proyecto usa **Jolt** (`project.godot`). Godot Physics daba normales NaN junto a los huecos del terreno; con Jolt las pruebas de parkour dan lo mismo.
- **N6, el Templo del Sol** (`codigo/templo.gd`): todo el recinto mira a la salida del sol del 21 de junio (acimut 65,8°, ENE).
  - **Plataforma ceremonial** de 68 × 64 m, adonde llega la calzada.
  - **Plaza circular hundida** como la de Caral: tres gradas de 0,8 m.
  - **Templo de tres terrazas** de piedra poligonal con escalinata. Arriba está el **Inti Wasi**, con portada de doble jamba al oeste y puerta al este, al borde, frente al horizonte.
  - **Ushnu** con escalinata, portada de doble jamba y el sillón del Inca.
  - **Miradores:** `amanecer` (6:33) y `atardecer` (17:18) se capturan a su hora.
- **El fondo** (`codigo/cordillera.gd`): un anillo de cordillera de 21 a 38 km, más allá del relieve real.
  - Delante, picos en pan de azúcar como el Huayna Picchu; detrás, nevados más altos hacia el ENE, por donde sale el sol.
  - Es geometría a distancias reales, así que da paralaje, y la niebla de Sky3D la azula.
- **Lluvia** (`codigo/lluvia.gd`, tecla `L`):
  - **Gotas:** partículas GPU que siguen a la cámara con el viento del valle. Chocan con un campo de alturas que también la sigue (no llueve bajo techo ni en la cueva) y salpican.
  - **Cielo:** se cubre, el sol pierde fuerza y la bruma se espesa.
  - **Superficies mojadas:** la variable global `humedad` (`[shader_globals]` en `project.godot`) moja poco a poco el terreno, la piedra, la paja y el ichu, que se ven más oscuros y brillantes. En lo llano se forman charcos.
- **Despertar del oro** (`Manos.despertar_oro()`, tecla `B`), de brazos normales a brazos que contienen el oro, en 5,5 s:
  - Las manos suben frente a la cara.
  - Tiemblan con el espasmo de los gestos y se cierran en puño (`CapasManos.apretar`).
  - Las venas crecen desde cero y un frente las enciende de los nudillos al codo, en los dos brazos.
  - Pico: destello, patada de FOV y las manos se abren.
  - Queda el oro de reposo latiendo (`venas_base` 0,5).

Recorrido con capturas y números, sin el MCP (necesita ventana):

```
godot.console.exe --path . --script res://herramientas/recorrido_pueblo.gd          # 10:30
godot.console.exe --path . --script res://herramientas/recorrido_pueblo.gd -- 17.5  # a otra hora
godot.console.exe --path . --script res://herramientas/recorrido_pueblo.gd -- 15 patio,vista,pozo lluvia   # solo esos, lloviendo
godot.console.exe --path . --fixed-fps 20 --script res://herramientas/capturar_despertar.gd               # tira del despertar del oro
godot.console.exe --headless --path . --fixed-fps 60 --script res://herramientas/probar_camino.gd        # recorre camino, templo, pozo y cueva
```

`probar_camino.gd` hace todo el recorrido manejando al jugador. Último resultado:

| Prueba | Resultado |
|---|---|
| Calzada | llega al templo en 168 s (826 m) |
| Templo | sube las tres terrazas, cruza el Inti Wasi y llega al borde este |
| Ushnu | sube a la cima |
| Pozo | cae 16 m y queda en la cámara |
| Cueva | sale a la ladera en 33 s |

Con el MCP: `game_eval` → `await capturar_recorrido()` en la escena del nivel. Deja `capturas/nivel1_<n>_<mirador>.png` e imprime FPS, primitivas y llamadas de dibujo por mirador.

## Pruebas automáticas

`codigo/banco.gd` expone, para el MCP de Godot (`game_eval`):

- `probar(poder, instantes)` y `probar_todo()`: lanzan los poderes y guardan capturas en `capturas/`.
- `capturar_picos()`: congela cada gesto de las manos en su pico y guarda `manos_<id>_<poder>.png`.
- `medir_suavidad()`: velocidad angular máxima del hueso más rápido durante cada gesto (°/s). Un salto de 90° en un frame da más de 10 000; un gesto fluido queda bajo ~700. Estado actual: H3 260–560 °/s y H4 290–590 °/s, salvo el Halcón (arranque al doble): 769 °/s en H3 y 1007 °/s en H4.
- `capturar_secuencia(nombre, n, intervalo, lado)`: tira de cuadros en un PNG, para ver movimiento en una imagen.
- `capturar_brazo(nombre, giro, alambre, distancia)`: primer plano del antebrazo desde fuera del cuerpo.

Humo sin ventana: `godot.console.exe --headless --path . --quit-after 120` (**N son frames**, ~60/s; nunca `godot.exe`, traga la salida).
