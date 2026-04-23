# Mac-Style Dock Fix for KDE Plasma 6.6

Este es un parche para el widget "Icons-Only Task Manager 2" (o Fancy Tasks) diseñado para solucionar los problemas de parpadeo (Z-Fighting) y visibilidad de los Tooltips al usar el efecto de Zoom Parabólico en Fedora 43 / KDE Plasma 6.6.

## ¿Qué se solucionó?
* **Bucle de Eventos (Jitter):** Se reemplazaron los múltiples `ToolTipArea` individuales que bloqueaban el sensor de zoom, causando un parpadeo infinito.
* **Master Tooltip:** Se implementó un único Tooltip maestro de tamaño `0x0` flotante con `z: 9999` que sigue matemáticamente la variable `hoveredIndex` del dock.

## ¿Que tiene de nuevo?
* Ahora al cambiar la alternativa de la barra mantiene el tamaño de los iconos.
* Ahora Muestra Lista de Miniaturas (Solo icono y texto) cuando se tiene mas de dos ventanas abiertas.

## Instalación
1. Descarga el archivo `mac-dock-fix-plasma6.plasmoid` de los Releases.
2. Instálalo vía terminal:
   `kpackagetool6 -t Plasma/Applet -i mac-dock-fix-plasma6.plasmoid`
3. Reinicia Plasma: `plasmashell --replace & disown`

*Créditos al autor original del widget. Este es un parche comunitario.*  *https://store.kde.org/p/2352806*

*mejorno402*

# mac-dock-plasma6-fix
Este es un parche para el widget "Icons-Only Task Manager 2" (o Fancy Tasks / macOS Dock)

