pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "notes"
    defaultConfig: ({
        placementStrategy: "free",
        contentWidth: 240, contentHeight: 160,
        text: "",
        fontSize: 14,
        fontFamily: "sans",
        textAlign: "left",
        widgetScale: 100, widgetOpacity: 100,
        showBackground: true, useBlur: false, showBorder: true,
        backgroundOpacity: 0.10, borderWidth: 1, borderOpacity: 0.12,
        cornerRadius: -1, colorMode: "auto", dim: 0,
        x: 80, y: 80
    })

    implicitWidth: Math.round((Config.getNestedValue("background.widgets.notes.contentWidth", 240)) * scaleFactor)
    implicitHeight: Math.round((Config.getNestedValue("background.widgets.notes.contentHeight", 160)) * scaleFactor)

    visibleWhenLocked: false
    needsColText: true
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })
    resizeMinWidth: 120
    resizeMinHeight: 80
    resizeMaxWidth: 800
    resizeMaxHeight: 600

    // Only draggable in edit mode — otherwise click = type
    draggable: GlobalStates.widgetEditMode && !GlobalStates.screenLocked && !root.locked

    readonly property string noteText: Config.getNestedValue("background.widgets.notes.text", "")
    readonly property int fontSize: Math.round((Config.getNestedValue("background.widgets.notes.fontSize", 14)) * scaleFactor)
    readonly property string fontFamily: Config.getNestedValue("background.widgets.notes.fontFamily", "sans")
    readonly property string textAlign: Config.getNestedValue("background.widgets.notes.textAlign", "left")

    readonly property real cardRadius: root.widgetCardRadius

    // ── Edit popover: font + alignment ─────────────────────────
    editPopoverContent: Component {
        ColumnLayout {
            spacing: 8

            RowLayout {
                spacing: 4
                Layout.alignment: Qt.AlignHCenter
                Repeater {
                    model: [
                        { label: Translation.tr("Sans"), value: "sans" },
                        { label: Translation.tr("Mono"), value: "mono" }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        leftmost: true; rightmost: true
                        buttonText: modelData.label
                        toggled: root.fontFamily === modelData.value
                        onClicked: Config.setNestedValue("background.widgets.notes.fontFamily", modelData.value)
                    }
                }
            }

            RowLayout {
                spacing: 6
                Layout.alignment: Qt.AlignHCenter

                StyledText {
                    text: Translation.tr("Text size")
                    color: Appearance.colors.colOnLayer2
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }

                StyledSpinBox {
                    from: 10
                    to: 48
                    stepSize: 1
                    value: Config.getNestedValue("background.widgets.notes.fontSize", 14)
                    onValueModified: Config.setNestedValue("background.widgets.notes.fontSize", value)
                }
            }

            RowLayout {
                spacing: 4
                Layout.alignment: Qt.AlignHCenter
                Repeater {
                    model: [
                        { icon: "format_align_left", value: "left" },
                        { icon: "format_align_center", value: "center" },
                        { icon: "format_align_right", value: "right" }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        toggled: root.textAlign === modelData.value
                        onClicked: Config.setNestedValue("background.widgets.notes.textAlign", modelData.value)
                    }
                }
            }
        }
    }

    // ── Card background ────────────────────────────────────────
    WidgetSurface {
        regionBrightness: root.regionBrightness
        anchors.fill: parent
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.cardRadius
        surfaceOpacity: root.backgroundOpacity
        surfaceBorderWidth: root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.widgetSurfaceInk
        colorMode: root.colorMode
        surfaceAccent: root.widgetAccent
        surfaceUseBlur: root.effectiveBlur
        screenX: root.x
        screenY: root.y
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
        visible: root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur
    }

    // ── Editor (TextEdit + Flickable, no built-in context menu) ────
    Flickable {
        id: editorFlick
        anchors.fill: parent
        anchors.margins: Math.round(12 * root.scaleFactor)
        clip: true
        contentWidth: width
        contentHeight: textEdit.contentHeight
        boundsBehavior: Flickable.StopAtBounds

        // When in edit mode, disable text interaction so widget can be dragged.
        // Out of edit mode, TextEdit handles all input.
        interactive: !GlobalStates.widgetEditMode

        TextEdit {
            id: textEdit
            width: editorFlick.width
            text: root.noteText
            wrapMode: TextEdit.Wrap
            color: root.widgetInk
            selectByMouse: true
            selectByKeyboard: true
            persistentSelection: false
            renderType: Text.NativeRendering

            // Disable input handling in edit mode so drag works
            enabled: !GlobalStates.widgetEditMode

            font.pixelSize: root.fontSize
            font.family: root.fontFamily === "mono" ? Appearance.font.family.monospace
                : Appearance.font.family.main

            horizontalAlignment: root.textAlign === "center" ? TextEdit.AlignHCenter
                : root.textAlign === "right" ? TextEdit.AlignRight
                : TextEdit.AlignLeft

            // Auto-scroll cursor into view
            onCursorRectangleChanged: {
                const r = cursorRectangle
                if (r.y < editorFlick.contentY) editorFlick.contentY = r.y
                else if (r.y + r.height > editorFlick.contentY + editorFlick.height)
                    editorFlick.contentY = r.y + r.height - editorFlick.height
            }

            // Suppress right-click context menu
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onPressed: (mouse) => mouse.accepted = true
            }

            // Persist text changes (debounced)
            onTextChanged: _saveDebounce.restart()

            Timer {
                id: _saveDebounce
                interval: 400
                repeat: false
                onTriggered: {
                    if (textEdit.text !== root.noteText)
                        Config.setNestedValue("background.widgets.notes.text", textEdit.text)
                }
            }
        }

        // Placeholder text when empty
        StyledText {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: 2
                rightMargin: 2
            }
            visible: textEdit.text.length === 0 && !textEdit.activeFocus
            text: Translation.tr("Write a note…")
            color: root.widgetInkSubtle
            font.pixelSize: root.fontSize
            font.family: textEdit.font.family
            horizontalAlignment: root.textAlign === "center" ? Text.AlignHCenter
                : root.textAlign === "right" ? Text.AlignRight : Text.AlignLeft
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
        }
    }
}
