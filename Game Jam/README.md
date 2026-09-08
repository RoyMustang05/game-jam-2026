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
