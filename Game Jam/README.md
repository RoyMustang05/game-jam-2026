# STILL//MOVING — The Last Flame

## Requisitos
- Windows de 64 bits y una tarjeta gráfica compatible con OpenGL 3.3.
- No necesitas instalar Godot, descargar assets ni tener conexión a Internet: el motor está incluido en `.runtime`.
- Conserva todos los archivos y carpetas del proyecto juntos.

## Jugar
Abre **Play.cmd** y pulsa **Enter**. La campaña tiene cuatro niveles y el jefe final Pyrax.

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
Abre **Open Editor.cmd**. Los cuatro niveles están en `rooms`.
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

Con Godot 4.7 en el PATH, desde esta carpeta:

```
godot --headless --script res://tests/core_tests.gd
godot --headless --script res://tests/mechanism_tests.gd
godot --headless --script res://tests/boss_tests.gd
godot --headless --script res://tests/authoring_tests.gd
godot --headless --script res://tests/route_tests.gd
```

Resultados de la última corrida en **TEST-REPORT.md**.
