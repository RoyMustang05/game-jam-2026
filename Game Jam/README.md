# STILL//MOVING — The Last Flame

## Requisitos
- Godot **4.7.x** (probado en 4.7.2) y una GPU compatible con OpenGL 3.3 o superior.
- Windows, Linux o macOS. Este repositorio contiene todo el código, salas, audio y arte; no depende de rutas personales ni de archivos importados locales.
- Godot no se versiona dentro del repositorio. Cada integrante debe instalar la misma versión de Godot o usar una copia privada opcional en `.runtime/`.
- Conserva todos los archivos y carpetas del proyecto juntos; abre la carpeta que contiene `project.godot`, no sólo una escena suelta.

## Jugar

En Windows abre **Play.cmd**. Busca primero una copia opcional en `.runtime` y,
si no existe, usa `Godot.exe`/`godot.exe` desde `PATH`.

En Linux o macOS ejecuta `./play.sh` desde una terminal. También puedes importar
`project.godot` en Godot y pulsar F6/F5. La campaña tiene cuatro niveles y el
jefe final Pyrax.

## Controles
- A/D o flechas: moverse.
- Espacio, W o Arriba: saltar; otra pulsación hace doble salto.
- Mantener dirección hacia una pared + salto: salto de pared.
- Shift + dirección: dash temporal.
- Abajo + Shift en el aire: golpe descendente.
- X en el aire, sin direcciones: congelarse para planear.
- J: golpear el punto débil abierto de Pyrax.
- R: reiniciar desde el checkpoint. Esc: pausa.

Moverse hace avanzar el mundo; detenerse lo congela. Los peligros congelados siguen haciendo daño.

## Editar niveles

En Windows abre **Open Editor.cmd**; en Linux o macOS ejecuta `./open_editor.sh`.
Los cuatro niveles están en `rooms`.
Selecciona **Floors** para pintar tiles y arrastra enemigos u objetos desde `assets`.
**Ctrl+S** guarda, **F6** prueba el nivel, **F8** detiene y **F5** inicia la campaña.
Más detalles en **LEVEL-DESIGN.md**.

## Estructura del código

| Carpeta | Contenido |
|---|---|
| `scripts/game.gd` | Director: único reloj de simulación, carga de salas, muertes y finales |
| `scripts/actors/` | `player.gd` (Milo) y `dragon.gd` (Pyrax) |
| `scripts/world/` | Sistemas que avanzan con tiempo de mundo: `hazards`, `mechanisms`, `crushers`, `atmosphere`, más el arte de escenario (`levels`) y de objetos (`asset_art`) |
| `scripts/ui/` | Dibujo en tiempo real sin escalar: `menu_screen`, `hud`, `world_labels`, `level_geometry` y el helper `draw_text` |
| `scripts/systems/` | Servicios sin estado de juego: `input_bindings` (teclado) y `sound_bank` (audio sintetizado) |
| `scripts/editor/` | Capa de autoría: `room_definition` (raíz de cada sala) y `room_object` (assets arrastrables) |
| `rooms/`, `assets/` | Salas guardadas y escenas reutilizables; son la fuente de verdad en ejecución |
| `tests/`, `tools/` | Suites headless y generadores de campaña |

Regla clave: todo lo que vive bajo `world` avanza con el delta de mundo que
`game.gd` reparte; la interfaz siempre usa el delta real sin escalar.

## Pruebas

Con Godot 4.7.x en el PATH, desde esta carpeta:

```
godot --headless --script res://tests/core_tests.gd
godot --headless --script res://tests/mechanism_tests.gd
godot --headless --script res://tests/boss_tests.gd
godot --headless --script res://tests/authoring_tests.gd
godot --headless --script res://tests/route_tests.gd
```

Resultados de la última corrida en **TEST-REPORT.md**.

## Presentación y editor (septiembre 2026)

**Jugar** abre una introducción ilustrada de unos 13,5 segundos. **Enter / Espacio**
avanza cada momento; **Esc** la omite. El reloj y la simulación empiezan después.
Los reintentos, F6 y los cambios de nivel no reproducen la historia.

Las salidas de los tres primeros niveles abren automáticamente un portal de
2,35 segundos; el último conserva el final de campaña. Durante el viaje se
congelan los contadores y la simulación. Las teclas mantenidas durante la
secuencia deben soltarse antes de reutilizarlas.

Milo conserva su casco marfil, visor cian y cronómetro en todas las animaciones:

| Nivel / era | Vestuario |
| --- | --- |
| 01 / Prehistoria | Túnica de piel cosida, hombrera de pelo, bolsa de cuero |
| 02 / Antigüedad | Quitón de lino, paño carmesí, broche de bronce y correas |
| 03 / Industrial | Chaqueta de trabajo, arnés y gafas de cobre |
| 04 / Futuro colapsado | Traje de supervivencia, placas y circuitos luminosos |

**Editor de niveles** en el menú permite elegir una de las cuatro escenas y
abrirla en el mismo ejecutable de Godot instalado que está ejecutando el juego.
Se puede navegar con flechas/Tab y Enter, o con el ratón. En una exportación,
se explica cómo abrir el proyecto fuente en Godot. No genera ni migra niveles.

En Godot: elige `rooms/room_01.tscn` a `room_04.tscn`, selecciona **Floors** para
pintar o arrastra objetos desde **assets**. **Ctrl+S** guarda, **F6** juega esa
escena, **F8** detiene, **F5** juega la campaña. Vuelve a la ventana del juego y
pulsa **Volver al menú**; al iniciar otra partida se cargan las escenas guardadas.
Consulta [LEVEL-DESIGN.md](LEVEL-DESIGN.md) para los detalles de autoría.

Linux/macOS (Godot 4.7.x, renderer OpenGL Compatibility):

```bash
godot4 --path "/ruta/al/game-jam-2026/Game Jam"
```

Arte y procedencia: [assets/story/ARTWORK.md](assets/story/ARTWORK.md).
Prueba de integración: `godot --path . --script tests/presentation_tests.gd -- --capture`.
Las capturas de esta prueba se guardan en `/tmp/still-presentation`, fuera del repositorio.
