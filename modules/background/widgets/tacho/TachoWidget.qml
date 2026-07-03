pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.background.widgets

// CPU tachometer — a racing rev counter for system load. 270° dial with tick
// marks, a redline band on the last fifth, and a needle driven by CPU usage.
AbstractBackgroundWidget {
    id: root

    configEntryName: "tacho"
    defaultConfig: ({
        placementStrategy: "free", gaugeSize: 180,
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto", dim: 0,
        showBackground: true, showBorder: true, backgroundOpacity: 0.16,
        borderWidth: 1, borderOpacity: 0.2, cornerRadius: -1, useBlur: false,
        x: 120, y: 120
    })

    readonly property int gaugeSize: Math.round(Config.getNestedValue("background.widgets.tacho.gaugeSize", 180) * scaleFactor)
    implicitWidth: gaugeSize
    implicitHeight: gaugeSize
    resizableAxes: ({ uniform: "gaugeSize" })
    resizeMinWidth: 110
    resizeMinHeight: 110
    needsColText: true

    // Dial geometry: 270° sweep starting at 135° (bottom-left), redline on the
    // last 20% — the classic rev-counter read.
    readonly property real _startAngle: 135
    readonly property real _sweep: 270
    readonly property real _redlineFrom: 0.8
    readonly property real cpuValue: ResourceUsage.cpuUsage

    // ResourceUsage auto-stops without a keep-alive; a persistent desktop
    // widget must hold one or the needle freezes at the last poll (P0 rule).
    Component.onCompleted: ResourceUsage.keepAlive()
    Component.onDestruction: ResourceUsage.releaseKeepAlive()

    WidgetSurface {
        regionBrightness: root.regionBrightness
        anchors.fill: parent
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : width / 2
        surfaceOpacity: root.backgroundOpacity
        surfaceBorderWidth: root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.widgetSurfaceInk
        surfaceAccent: root.widgetAccent
        surfaceUseBlur: root.useBlur
        screenX: root.x
        screenY: root.y
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
        visible: root.backgroundOpacity > 0 || root.borderWidth > 0
    }

    // Static dial: track arc, tick marks, redline band, numerals.
    Canvas {
        id: dial
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const cx = width / 2, cy = height / 2;
            const R = Math.min(cx, cy) - Math.round(10 * root.scaleFactor);
            const a0 = root._startAngle * Math.PI / 180;
            const rad = f => a0 + f * root._sweep * Math.PI / 180;
            const track = root.widgetInkSubtle;
            const redline = root.widgetSignal;
            // Track arc
            ctx.lineWidth = Math.max(2, R * 0.055);
            ctx.lineCap = "round";
            ctx.strokeStyle = Qt.rgba(track.r, track.g, track.b, 0.45);
            ctx.beginPath();
            ctx.arc(cx, cy, R, rad(0), rad(root._redlineFrom));
            ctx.stroke();
            // Redline band
            ctx.strokeStyle = Qt.rgba(redline.r, redline.g, redline.b, 0.85);
            ctx.beginPath();
            ctx.arc(cx, cy, R, rad(root._redlineFrom), rad(1));
            ctx.stroke();
            // Ticks + numerals 0..10
            const ink = root.widgetInk;
            ctx.fillStyle = Qt.rgba(ink.r, ink.g, ink.b, 0.85);
            ctx.font = "600 " + Math.max(8, Math.round(R * 0.17)) + "px " + Appearance.font.family.numbers;
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            for (let i = 0; i <= 10; ++i) {
                const f = i / 10;
                const a = rad(f);
                const major = i % 2 === 0;
                const inner = R - (major ? R * 0.14 : R * 0.08);
                const hot = f >= root._redlineFrom;
                ctx.strokeStyle = hot ? Qt.rgba(redline.r, redline.g, redline.b, 0.9)
                                      : Qt.rgba(ink.r, ink.g, ink.b, major ? 0.8 : 0.4);
                ctx.lineWidth = major ? Math.max(2, R * 0.03) : 1;
                ctx.beginPath();
                ctx.moveTo(cx + Math.cos(a) * inner, cy + Math.sin(a) * inner);
                ctx.lineTo(cx + Math.cos(a) * (R - R * 0.03), cy + Math.sin(a) * (R - R * 0.03));
                ctx.stroke();
                if (major) {
                    const tr = R - R * 0.28;
                    ctx.fillText(String(i), cx + Math.cos(a) * tr, cy + Math.sin(a) * tr);
                }
            }
        }
        onWidthChanged: if (available) requestPaint()
        onHeightChanged: if (available) requestPaint()
        Connections {
            target: root
            function onWidgetInkChanged() { if (dial.available) dial.requestPaint() }
            function onWidgetSignalChanged() { if (dial.available) dial.requestPaint() }
        }
    }

    // Needle — a rotated bar, animated with the spatial preset so it sweeps
    // like a real gauge instead of teleporting between polls.
    Item {
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        rotation: root._startAngle + 90 + root.cpuValue * root._sweep
        Behavior on rotation {
            enabled: Appearance.animationsEnabled && root.animationsActive
            NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(14 * root.scaleFactor)
            width: Math.max(2, Math.round(root.gaugeSize * 0.018))
            height: parent.height / 2 - Math.round(20 * root.scaleFactor)
            radius: width / 2
            antialiasing: true
            color: root.cpuValue >= root._redlineFrom ? root.widgetSignal : root.widgetAccent
        }
    }

    // Hub + digital readout
    Rectangle {
        anchors.centerIn: parent
        width: Math.round(root.gaugeSize * 0.06)
        height: width
        radius: width / 2
        color: root.widgetAccent
    }
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.gaugeSize * 0.12)
        spacing: 0
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(root.cpuValue * 100) + "%"
            color: root.widgetInk
            font {
                family: Appearance.font.family.numbers
                pixelSize: Math.max(10, Math.round(root.gaugeSize * 0.13))
                weight: Font.Bold
            }
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "CPU"
            color: root.widgetInkMuted
            font.pixelSize: Math.max(7, Math.round(root.gaugeSize * 0.07))
            font.letterSpacing: 2
        }
    }
}
