pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.background.widgets

// Desktop headline ticker — rotates through the NewsService feed (the same
// location-aware Google News boards as the sidebar News tab). Click opens
// the article in the browser.
AbstractBackgroundWidget {
    id: root

    configEntryName: "newsTicker"
    defaultConfig: ({
        placementStrategy: "free", contentWidth: 320, contentHeight: 92,
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto", dim: 0,
        showBackground: true, showBorder: true, backgroundOpacity: 0.16,
        borderWidth: 1, borderOpacity: 0.2, cornerRadius: -1, useBlur: false,
        x: 100, y: 260
    })

    implicitWidth: Math.round(Config.getNestedValue("background.widgets.newsTicker.contentWidth", 320) * scaleFactor)
    implicitHeight: Math.round(Config.getNestedValue("background.widgets.newsTicker.contentHeight", 92) * scaleFactor)
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })
    resizeMinWidth: 220
    resizeMinHeight: 72
    needsColText: true
    property int headlineIndex: 0
    readonly property var article: (NewsService.articles.length > 0)
        ? NewsService.articles[root.headlineIndex % NewsService.articles.length] : null
    property var displayedArticle: null

    onArticleChanged: {
        if (!root.displayedArticle || !Appearance.animationsEnabled) {
            root.displayedArticle = root.article;
            headlineText.opacity = 1;
            return;
        }
        headlineText.opacity = 0;
        swapTimer.restart();
    }

    Component.onCompleted: {
        root.displayedArticle = root.article;
        NewsService.fetch(
            Config.options?.sidebar?.news?.mode ?? "local",
            Config.options?.sidebar?.news?.topic ?? "WORLD");
    }

    // Raw-ms rotation timer (never calcEffectiveDuration — not a visual Behavior).
    Timer {
        interval: 12000
        repeat: true
        running: root.visible && root.powerActive && NewsService.articles.length > 1
        onTriggered: root.headlineIndex = (root.headlineIndex + 1) % NewsService.articles.length
    }

    WidgetSurface {
        regionBrightness: root.regionBrightness
        anchors.fill: parent
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.widgetCardRadius
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

    MouseArea {
        anchors.fill: parent
        cursorShape: root.displayedArticle ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: !GlobalStates.widgetEditMode
        onClicked: if (root.displayedArticle) NewsService.openArticle(root.displayedArticle)
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Math.round(12 * root.scaleFactor)
        spacing: Math.round(10 * root.scaleFactor)

        MaterialSymbol {
            Layout.alignment: Qt.AlignTop
            text: "newspaper"
            iconSize: Math.round(26 * root.scaleFactor)
            color: root.widgetAccentVisible
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Math.round(2 * root.scaleFactor)

            // Fade between headlines (organic morphing — no hard swap).
            StyledText {
                id: headlineText
                Layout.fillWidth: true
                text: root.displayedArticle?.title ?? Translation.tr("No news")
                color: root.widgetInk
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.pixelSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor)
                font.weight: Font.DemiBold
                opacity: 1
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
                // Fade out the currently displayed headline, swap only after
                // the fade completes, then reveal the new article.
                Timer {
                    id: swapTimer
                    interval: Math.max(1, Appearance.animation.elementMoveFast.duration)
                    onTriggered: {
                        root.displayedArticle = root.article;
                        headlineText.opacity = 1;
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.displayedArticle
                    ? [root.displayedArticle.source, NewsService.formatTime(root.displayedArticle.timestamp)].filter(s => s && s.length > 0).join(" • ")
                    : ""
                color: root.widgetInkMuted
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
            }
        }
    }
}
