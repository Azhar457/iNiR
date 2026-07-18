pragma ComponentBehavior: Bound

import QtQuick

import qs.modules.common

Item {
    id: root

    required property var pages
    required property int requestedIndex
    property bool loadEnabled: true

    readonly property int currentIndex: _currentIndex
    readonly property Item currentItem: _currentSlot < 0 ? null : _loader(_currentSlot).item
    readonly property bool loading: _pendingSlot >= 0
        || (_currentSlot >= 0 && _loader(_currentSlot).status === Loader.Loading)

    property int _currentIndex: -1
    property int _currentSlot: -1
    property int _pendingIndex: -1
    property int _pendingSlot: -1
    property int _slot0Index: -1
    property int _slot1Index: -1
    property int _direction: 1
    property bool _transitionRunning: false

    clip: _transitionRunning

    function _loader(slot) {
        return slot === 0 ? pageSlot0 : pageSlot1
    }

    function _sourceFor(index) {
        if (index < 0 || index >= pages.length)
            return ""
        return pages[index]?.component ?? ""
    }

    function _setSlotIndex(slot, index) {
        if (slot === 0)
            _slot0Index = index
        else
            _slot1Index = index
    }

    function _prepareSlot(slot, index, asynchronous, opacity, x) {
        const loader = _loader(slot)
        loader.asynchronous = asynchronous
        loader.opacity = opacity
        loader.x = x
        _setSlotIndex(slot, index)
    }

    function _reset() {
        switchAnimation.stop()
        _transitionRunning = false
        _currentIndex = -1
        _currentSlot = -1
        _pendingIndex = -1
        _pendingSlot = -1
        _setSlotIndex(0, -1)
        _setSlotIndex(1, -1)
    }

    function _requestPage() {
        if (!loadEnabled || requestedIndex < 0 || requestedIndex >= pages.length)
            return

        if (_transitionRunning)
            switchAnimation.complete()

        if (_currentSlot < 0) {
            _currentSlot = 0
            _currentIndex = requestedIndex
            _prepareSlot(0, requestedIndex, false, 1, 0)
            return
        }

        if (_pendingSlot >= 0 || requestedIndex === _currentIndex)
            return

        _direction = requestedIndex >= _currentIndex ? 1 : -1
        _pendingIndex = requestedIndex
        _pendingSlot = _currentSlot === 0 ? 1 : 0
        _prepareSlot(
            _pendingSlot,
            _pendingIndex,
            true,
            0,
            _direction * Appearance.sizes.spacingMedium * 2
        )
    }

    function _discardPending() {
        const slot = _pendingSlot
        _pendingIndex = -1
        _pendingSlot = -1
        if (slot >= 0)
            _setSlotIndex(slot, -1)
    }

    function _handleStatus(slot, status) {
        if (slot !== _pendingSlot)
            return

        if (status === Loader.Error) {
            console.warn("SettingsPageHost: failed to load page", _pendingIndex)
            _discardPending()
            return
        }

        if (status !== Loader.Ready)
            return

        if (_pendingIndex !== requestedIndex) {
            _discardPending()
            Qt.callLater(root._requestPage)
            return
        }

        if (!Appearance.animationsEnabled || Appearance.animation.elementMoveFast.duration <= 0) {
            _finishSwap()
            return
        }

        const currentLoader = _loader(_currentSlot)
        const pendingLoader = _loader(_pendingSlot)
        currentFade.target = currentLoader
        pendingFade.target = pendingLoader
        pendingSlide.target = pendingLoader
        _transitionRunning = true
        switchAnimation.start()
    }

    function _finishSwap() {
        if (_pendingSlot < 0)
            return

        const oldSlot = _currentSlot
        const nextSlot = _pendingSlot
        const nextIndex = _pendingIndex
        const oldLoader = _loader(oldSlot)
        const nextLoader = _loader(nextSlot)

        oldLoader.opacity = 0
        nextLoader.opacity = 1
        nextLoader.x = 0

        _currentSlot = nextSlot
        _currentIndex = nextIndex
        _pendingSlot = -1
        _pendingIndex = -1
        _transitionRunning = false
        _setSlotIndex(oldSlot, -1)

        if (requestedIndex !== _currentIndex)
            Qt.callLater(root._requestPage)
    }

    onRequestedIndexChanged: Qt.callLater(root._requestPage)
    onLoadEnabledChanged: {
        if (loadEnabled)
            Qt.callLater(root._requestPage)
        else
            _reset()
    }
    Component.onCompleted: Qt.callLater(root._requestPage)

    Loader {
        id: pageSlot0

        anchors.fill: parent
        active: root._slot0Index >= 0
        source: active ? root._sourceFor(root._slot0Index) : ""
        visible: active
        enabled: root._currentSlot === 0 && root._pendingSlot < 0 && !root._transitionRunning
        z: root._pendingSlot === 0 ? 1 : 0
        layer.enabled: root._transitionRunning && active

        onStatusChanged: root._handleStatus(0, status)
    }

    Loader {
        id: pageSlot1

        anchors.fill: parent
        active: root._slot1Index >= 0
        source: active ? root._sourceFor(root._slot1Index) : ""
        visible: active
        enabled: root._currentSlot === 1 && root._pendingSlot < 0 && !root._transitionRunning
        z: root._pendingSlot === 1 ? 1 : 0
        layer.enabled: root._transitionRunning && active

        onStatusChanged: root._handleStatus(1, status)
    }

    ParallelAnimation {
        id: switchAnimation

        NumberAnimation {
            id: currentFade
            property: "opacity"
            to: 0
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
        NumberAnimation {
            id: pendingFade
            property: "opacity"
            to: 1
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
        NumberAnimation {
            id: pendingSlide
            property: "x"
            to: 0
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }

        onFinished: root._finishSwap()
    }
}
