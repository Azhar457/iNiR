pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects as GE
import qs
import qs.modules.background.widgets
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

AbstractBackgroundWidget {
    id: root

    configEntryName: "customImage"
    defaultConfig: ({
        enable: false,
        locked: false,
        placementStrategy: "free",
        path: "",
        shape: "Cookie4Sided",
        fitMode: "cover",
        size: 220,
        dim: 0,
        widgetScale: 100,
        widgetOpacity: 100,
        x: 120,
        y: 320
    })
    resizableAxes: ({ uniform: "size" })

    readonly property string imagePath: String(root._readConfigKey("path") ?? "")
    readonly property string shapeName: String(root._readConfigKey("shape") ?? "Cookie4Sided")
    readonly property string fitMode: String(root._readConfigKey("fitMode") ?? "cover")
    readonly property real logicalSize: Math.max(80, Number(root._readConfigKey("size") ?? 220))
    readonly property real renderedSize: Math.round(root.logicalSize * root.scaleFactor)
    readonly property url imageSource: root.imagePath.length > 0
        ? (root.imagePath.startsWith("file:") ? root.imagePath : "file://" + root.imagePath)
        : ""
    readonly property int shapeEnum: root.shapeForName(root.shapeName)

    property bool dropHover: false

    implicitWidth: root.renderedSize
    implicitHeight: root.renderedSize

    function shapeForName(name: string): int {
        switch (name) {
        case "Circle": return MaterialShape.Shape.Circle;
        case "Square": return MaterialShape.Shape.Square;
        case "Slanted": return MaterialShape.Shape.Slanted;
        case "Arch": return MaterialShape.Shape.Arch;
        case "Fan": return MaterialShape.Shape.Fan;
        case "Arrow": return MaterialShape.Shape.Arrow;
        case "SemiCircle": return MaterialShape.Shape.SemiCircle;
        case "Oval": return MaterialShape.Shape.Oval;
        case "Pill": return MaterialShape.Shape.Pill;
        case "Triangle": return MaterialShape.Shape.Triangle;
        case "Diamond": return MaterialShape.Shape.Diamond;
        case "ClamShell": return MaterialShape.Shape.ClamShell;
        case "Pentagon": return MaterialShape.Shape.Pentagon;
        case "Gem": return MaterialShape.Shape.Gem;
        case "Sunny": return MaterialShape.Shape.Sunny;
        case "VerySunny": return MaterialShape.Shape.VerySunny;
        case "Cookie6Sided": return MaterialShape.Shape.Cookie6Sided;
        case "Cookie7Sided": return MaterialShape.Shape.Cookie7Sided;
        case "Cookie9Sided": return MaterialShape.Shape.Cookie9Sided;
        case "Cookie12Sided": return MaterialShape.Shape.Cookie12Sided;
        case "Ghostish": return MaterialShape.Shape.Ghostish;
        case "Clover4Leaf": return MaterialShape.Shape.Clover4Leaf;
        case "Clover8Leaf": return MaterialShape.Shape.Clover8Leaf;
        case "Burst": return MaterialShape.Shape.Burst;
        case "SoftBurst": return MaterialShape.Shape.SoftBurst;
        case "Boom": return MaterialShape.Shape.Boom;
        case "SoftBoom": return MaterialShape.Shape.SoftBoom;
        case "Flower": return MaterialShape.Shape.Flower;
        case "Puffy": return MaterialShape.Shape.Puffy;
        case "PuffyDiamond": return MaterialShape.Shape.PuffyDiamond;
        case "PixelCircle": return MaterialShape.Shape.PixelCircle;
        case "PixelTriangle": return MaterialShape.Shape.PixelTriangle;
        case "Bun": return MaterialShape.Shape.Bun;
        case "Heart": return MaterialShape.Shape.Heart;
        case "Cookie4Sided":
        default: return MaterialShape.Shape.Cookie4Sided;
        }
    }

    function pathFromDropUrl(value: var): string {
        const raw = String(value ?? "");
        try {
            return FileUtils.trimFileProtocol(decodeURIComponent(raw));
        } catch (error) {
            return FileUtils.trimFileProtocol(raw);
        }
    }

    function setImagePath(path: string): void {
        if (!path || !Images.isValidImageByName(path))
            return
        Config.setNestedValue(root._configPath + ".path", path)
    }

    MaterialShape {
        id: shadowShape
        anchors.fill: parent
        shape: root.shapeEnum
        color: Appearance.colors.colPrimaryContainer
        visible: false
    }

    StyledDropShadow {
        target: shadowShape
        visible: root.imagePath.length > 0
    }

    Item {
        id: maskedContent
        anchors.fill: parent
        layer.enabled: true
        layer.effect: GE.OpacityMask {
            maskSource: MaterialShape {
                width: maskedContent.width
                height: maskedContent.height
                shape: root.shapeEnum
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Appearance.colors.colPrimaryContainer
        }

        StyledImage {
            id: image
            anchors.fill: parent
            source: root.imageSource
            fillMode: root.fitMode === "contain" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
            cache: false
            asynchronous: true
            sourceSize.width: Math.max(1, Math.round(width * 2))
            sourceSize.height: Math.max(1, Math.round(height * 2))
        }

        MaterialSymbol {
            anchors.centerIn: parent
            visible: root.imagePath.length === 0 || image.status === Image.Error
            text: image.status === Image.Error ? "broken_image" : (root.dropHover ? "download" : "add_photo_alternate")
            fill: root.dropHover ? 1 : 0
            iconSize: Math.max(28, Math.round(root.renderedSize * 0.24))
            color: Appearance.colors.colOnPrimaryContainer
        }

        MaterialShape {
            anchors.fill: parent
            visible: root.dropHover
            shape: root.shapeEnum
            color: ColorUtils.applyAlpha(root.widgetAccentVisible, 0.22)
        }
    }

    DropArea {
        anchors.fill: parent
        enabled: !GlobalStates.widgetEditMode
        keys: ["text/uri-list"]

        onEntered: drag => {
            drag.accept(Qt.CopyAction);
            root.dropHover = true;
        }
        onExited: root.dropHover = false
        onDropped: drop => {
            root.dropHover = false;
            if (!drop.hasUrls || drop.urls.length === 0) {
                drop.accepted = false;
                return;
            }

            const path = root.pathFromDropUrl(drop.urls[0]);
            if (!path || !Images.isValidImageByName(path)) {
                drop.accepted = false;
                return;
            }

            root.setImagePath(path);
            drop.accept(Qt.CopyAction);
        }
    }
}
