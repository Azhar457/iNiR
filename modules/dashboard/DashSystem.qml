import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * System monitor card: CPU, memory (and GPU when reported) usage bars.
 * ResourceUsage polling only runs while the card is visible (transient panel
 * pattern: ensureRunning gated on visible, auto-stops afterwards).
 */
DashCard {
    id: root
    title: Translation.tr("System")
    icon: "monitor_heart"

    // keepAlive while shown so values keep updating past the 15s auto-stop;
    // always released on hide/destroy. _holding guards against double counts.
    property bool _holding: false
    function _syncPolling() {
        if (visible && !_holding) { _holding = true; ResourceUsage.keepAlive() }
        else if (!visible && _holding) { _holding = false; ResourceUsage.releaseKeepAlive() }
    }
    onVisibleChanged: _syncPolling()
    Component.onCompleted: _syncPolling()
    Component.onDestruction: if (_holding) { _holding = false; ResourceUsage.releaseKeepAlive() }

    component UsageRow: ColumnLayout {
        id: usageRow
        property string label: ""
        property real value: 0
        Layout.fillWidth: true
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: usageRow.label
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.colSubtext
            }
            StyledText {
                text: `${Math.round(usageRow.value * 100)}%`
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.family: Appearance.font.family.numbers
                color: root.colText
            }
        }
        StyledProgressBar {
            Layout.fillWidth: true
            value: usageRow.value
        }
    }

    UsageRow {
        label: Translation.tr("CPU")
        value: ResourceUsage.cpuUsage
    }
    UsageRow {
        label: Translation.tr("Memory")
        value: ResourceUsage.memoryUsedPercentage
    }
    UsageRow {
        visible: ResourceUsage.gpuUsage > 0
        label: Translation.tr("GPU")
        value: ResourceUsage.gpuUsage
    }
}
