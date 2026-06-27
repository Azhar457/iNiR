# Plan: una sola "piel de panel" para un look consistente (zzz y todos los estilos)

> Objetivo en criollo: que TODOS los paneles (barra, dock, costados, popups) compartan
> un mismo molde de fondo, para que se vean iguales y se puedan cambiar desde UN solo lugar.

## El problema (diagnóstico 2026-06-26)
- Cada panel dibuja su propio fondo/borde/esquinas a mano → se ven distintos entre sí.
- Los colores ya salen de un lugar central (`Appearance.qml`); el que diverge es la FORMA.
- Hay piezas del estilo zzz, pero cada panel decide si las usa → inconsistencia.

## La solución
Un componente compartido `modules/common/widgets/PanelSurface.qml` = la "piel de panel".
- Recibe el contenido adentro y pinta el fondo correcto según el estilo activo
  (zzz → placa con esquina cortada; angel → su fondo; aurora → vidrio; material → plano).
- Expone props simples (radius, elevación, acento) — sin que cada panel reinvente nada.
- Editar este archivo = cambiar la pinta de TODOS los paneles que lo usen.

## Cómo lo aplicamos (de a poco, verificable)
1. [hecho] Crear `PanelSurface.qml` + registrarlo en `widgets/qmldir`. Molde completo
   (zzz/angel/inir/aurora/material/island/borderless/cardStyle).
2. [hecho, falta confirmar a ojo] `BarGroup.qml` (fondo de los grupos de la barra) ahora
   usa `PanelSurface` en vez de su choclo a mano. Arranca limpio. Misma pinta esperada.
3. Si gusta, replicar al dock, costados, popups, uno por uno, confirmando cada uno.
4. Cada cambio de look se refleja también en una card de `design-system/` y se re-sincroniza
   con `/design-sync` (ver [[design-system-is-source]]).

## Hallazgo de tamaño (2026-06-26)
~180 archivos dibujan su fondo a mano. Dos tipos:
- SIMPLES (rectángulo color+esquina+borde): seguros para pasar al molde.
- CON BLUR/VIDRIO (dock, costados, barra vertical main bg): el fondo está entrelazado con
  la maquinaria de desenfoque del wallpaper (OpacityMask + blendedColors). NO swapear a
  ciegas — `PanelSurface` todavía no sabe hacer blur. Hacerlos con cuidado + confirmación.
- HECHO de arrastre: la barra vertical usa `Bar.BarGroup` para sus grupos → ya quedó con el
  molde compartido al arreglar BarGroup (resuelve "las laterales no coinciden con la barra").

## Próximos pasos seguros
- Crear un molde para TARJETAS internas (`ContentCard`, hermano de PanelSurface) y migrar
  las tarjetas/botones simples (el grueso de los 180).
- Enseñarle a `PanelSurface` el modo blur/vidrio para poder absorber los paneles grandes.

## Alcance: NO solo paneles — TODO lo que da apariencia
El dueño aclaró: además de los paneles, hay muchos componentes de Quickshell (botones,
chips, listas, popups, menús, tooltips, switches, sliders…) que le dan la pinta a cada cosa.
TODOS tienen que poder editarse en masa desde piezas compartidas, igual que `PanelSurface`.
- Fase A: paneles → `PanelSurface` (en curso).
- Fase B: superficies de contenido (tarjetas/secciones) → un molde compartido.
- Fase C: controles (botones/chips/switches/sliders) → que tomen forma/borde de un solo lugar.
- Auditar con grep dónde se pintan formas/bordes a mano y reemplazar por el molde.

## Regla de oro
Una pieza de forma/estilo nueva vive en `modules/common/widgets/` y se consume desde ahí.
Nunca volver a pintar fondos/bordes/esquinas a mano dentro de cada panel o componente.
