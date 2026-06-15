pragma Singleton
import QtQuick
import qs.modules.common

// Exact InnerTune design constants — literal translation of
// app/src/main/java/com/zionhuang/music/constants/Dimensions.kt.
// Font sizes scale with the user's fontSizeScale; geometry is fixed per InnerTune spec.
QtObject {
    readonly property int navigationBarHeight: 80
    readonly property int miniPlayerHeight: 64
    readonly property int queuePeekHeight: 64
    readonly property int appBarHeight: 64

    readonly property int listItemHeight: 64
    readonly property int suggestionItemHeight: 56
    readonly property int searchFilterHeight: 48
    readonly property int listThumbnailSize: 48
    readonly property int gridThumbnailHeight: 128
    readonly property int smallGridThumbnailHeight: 92

    readonly property int albumThumbnailSize: 144

    readonly property int thumbnailCornerRadius: 6

    readonly property int playerHorizontalPadding: 32

    // Scrim alpha over an active (playing) thumbnail — InnerTune ActiveBoxAlpha (0.4f).
    readonly property real activeBoxAlpha: 0.4

    // Material3 type sizes used by Items.kt (sp → scaled px).
    readonly property int titleTextSize: Math.round(14 * Appearance.fontSizeScale)
    readonly property int subtitleTextSize: Math.round(12 * Appearance.fontSizeScale)
}
