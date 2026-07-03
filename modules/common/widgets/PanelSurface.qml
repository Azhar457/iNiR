pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.functions

// PanelSurface — the shared "panel skin" (el molde de fondo único).
//
// En vez de que cada panel/componente dibuje su propio fondo, borde y esquinas a mano
// (que es lo que hace que todo se vea distinto), lo envuelven en esto y la pinta sale
// consistente. Editar ESTE archivo = cambiar la pinta de todos los que lo usen.
//
// Sabe poner la cara correcta según el estilo activo del shell — la misma lógica que
// antes estaba copiada y divergente en cada panel:
//   zzz    → placa con esquina cortada (chamfer) + hairline (look consola/poster)
//   angel  → tarjeta de vidrio
//   inir   → capa plana con borde fino
//   aurora → sub-superficie translúcida
//   material/cards → rectángulo redondeado con el color de capa
//
// Uso:
//   PanelSurface { elevation: 1; /* tu contenido */ }
//   PanelSurface { island: true }            // pastilla (pill) que se redondea sola
//   PanelSurface { borderless: true }        // sin fondo (transparente)
Item {
    id: root

    default property alias content: contentHolder.data

    // Qué tan "elevado" se ve: 0 = fondo base, 1 = contenido (lo normal), 2+ = flotante.
    property int elevation: 1
    // Sin fondo (transparente) — para barras "borderless".
    property bool borderless: false
    // Pastilla: se redondea a la mitad de su alto (las "islas" de la barra).
    property bool island: false
    // Estilo tarjeta (config del usuario): esquinas más redondeadas + borde.
    property bool cardStyle: false
    // Override manual de esquinas; -1 = automático según estilo.
    property real radiusOverride: -1
    // En zzz: true = placa con esquina cortada; false = transparente (cuando el
    // contorno del shell ya lo dibuja otra cosa, p.ej. la barra unificada).
    property bool zzzChamfer: true
    // En zzz: dibuja el marco técnico (marcas de registro en las esquinas), como la
    // card tech-frame. Off por defecto; prendelo en superficies grandes/poster.
    property bool techFrame: false
    property string frameLabel: ""
    property string frameIndex: ""

    readonly property bool _zzz: Appearance.zzzEverywhere
    readonly property bool _angel: Appearance.angelEverywhere
    readonly property bool _inir: Appearance.inirEverywhere
    readonly property bool _aurora: Appearance.auroraEverywhere

    // ── Color de fondo (misma elección que hacían los paneles a mano) ──
    readonly property color _fill: root.borderless ? "transparent"
        : root._angel ? Appearance.angel.colGlassCard
        : root._inir ? (root.elevation <= 0 ? Appearance.inir.colLayer0 : Appearance.inir.colLayer1)
        : root._aurora ? Appearance.aurora.colSubSurface
        : (root.elevation <= 0 ? Appearance.colors.colLayer0
          : root.elevation === 1 ? Appearance.colors.colLayer1
          : root.elevation === 2 ? Appearance.colors.colLayer2
          : root.elevation === 3 ? Appearance.colors.colLayer3
          : Appearance.colors.colLayer4)

    // ── Esquinas ──
    readonly property real _radius: root.radiusOverride >= 0 ? root.radiusOverride
        : root.island ? Math.min(width, height) / 2
        : root._angel ? Appearance.angel.roundingSmall
        : root._inir ? Appearance.inir.roundingNormal
        : (root.cardStyle ? Appearance.rounding.normal : Appearance.rounding.small)

    // ── Borde ──
    readonly property int _borderWidth: root.borderless ? 0
        : root.island ? 1
        : root._angel ? Appearance.angel.cardBorderWidth
        : root._inir ? 1
        : (root.cardStyle ? 1 : 0)
    readonly property color _borderColor: root._angel ? Appearance.angel.colCardBorder
        : root._inir ? Appearance.inir.colBorder
        : Appearance.colors.colLayer0Border

    // ── Cara ZZZ: placa con esquina cortada + hairline ──
    ZzzPlate {
        anchors.fill: parent
        visible: root._zzz && root.zzzChamfer && !root.borderless
        fillColor: root._fill
        strokeColor: Appearance.zzz.hairline
        strokeWidth: Appearance.zzz.hairlineThick
        chamfer: Appearance.zzz.cutCorner
    }

    // ── Cara resto (y zzz transparente): rectángulo redondeado ──
    Rectangle {
        anchors.fill: parent
        visible: !(root._zzz && root.zzzChamfer && !root.borderless)
        color: root._zzz ? "transparent" : root._fill
        radius: root._zzz ? Appearance.zzz.cardRadius : root._radius
        border.width: root._zzz ? 0 : root._borderWidth
        border.color: root._borderColor
        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
        Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
        Behavior on border.width { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
        Behavior on border.color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
    }

    // Marco técnico poster (marcas de registro en esquinas) — solo zzz, opt-in.
    // Las marcas L de esquina son vocabulario "console" (modo square); en
    // modo round (anime soft) son marcas cuadradas que chocan con la esquina
    // redondeada y se leen feas, así que se suprimen. kept in square.
    ZzzTechFrame {
        anchors.fill: parent
        visible: root._zzz && root.techFrame
        showCornerMarks: !Appearance.zzz.round
        showLabels: root.frameLabel.length > 0 || root.frameIndex.length > 0
        label: root.frameLabel
        index: root.frameIndex
    }

    // Contenido encima de la cara.
    Item {
        id: contentHolder
        anchors.fill: parent
    }
}
