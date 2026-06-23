import qs.modules.common
import QtQuick
import QtQuick.Controls

/**
 * Does not include visual layout, but includes the easily neglected colors.
 */
TextInput {
    color: Appearance.zzzEverywhere ? Appearance.zzz.ink : Appearance.colors.colOnLayer1
    renderType: Text.NativeRendering
    selectedTextColor: Appearance.colors.colOnSecondaryContainer
    selectionColor: Appearance.zzzEverywhere ? Appearance.zzz.signal : Appearance.colors.colSecondaryContainer
    font {
        family: Appearance.font.family.main
        pixelSize: Appearance?.font.pixelSize.small ?? 15
        hintingPreference: Font.PreferFullHinting
        variableAxes: Appearance.font.variableAxes.main
    }
}
