pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.modules.common

Singleton {
    id: root

    readonly property string activeFamily: Config.options?.panelFamily ?? "ii"

    readonly property var _descriptors: [
        {
            id: "featureSidebar",
            families: ["ii"],
            kind: "edge",
            labelKey: "Feature sidebar",
            icon: "left_panel_open",
            layoutScope: "global",
            slots: ["left", "right"],
            editableProperties: ["sizeMode", "height", "thickness"],
            collisionPolicy: "swap-sidebar",
            resetScopes: ["surface", "family"]
        },
        {
            id: "systemSidebar",
            families: ["ii"],
            kind: "edge",
            labelKey: "System sidebar",
            icon: "right_panel_open",
            layoutScope: "global",
            slots: ["left", "right"],
            editableProperties: ["sizeMode", "height", "thickness"],
            collisionPolicy: "swap-sidebar",
            resetScopes: ["surface", "family"]
        },
        {
            id: "iiBar",
            families: ["ii"],
            kind: "edge",
            labelKey: "Bar",
            icon: "toolbar",
            layoutScope: "enabledOutputs",
            slots: ["top", "right", "bottom", "left"],
            editableProperties: [],
            collisionPolicy: "swap-edge",
            resetScopes: ["surface", "family"]
        },
        {
            id: "iiDock",
            families: ["ii"],
            kind: "edge",
            labelKey: "Dock",
            icon: "dock_to_bottom",
            layoutScope: "enabledOutputs",
            slots: ["top", "right", "bottom", "left"],
            editableProperties: ["thickness"],
            collisionPolicy: "swap-edge",
            resetScopes: ["surface", "family"]
        },
        {
            id: "waffleBar",
            families: ["waffle"],
            kind: "edge",
            labelKey: "Taskbar",
            icon: "desktop_windows",
            layoutScope: "enabledOutputs",
            slots: ["top", "bottom"],
            editableProperties: [],
            collisionPolicy: "validated",
            resetScopes: ["surface", "family"]
        }
    ]

    function _clone(value: var): var {
        return JSON.parse(JSON.stringify(value))
    }

    function _failure(code: string, message: string): var {
        return {
            ok: false,
            code: code,
            message: message,
            effectiveSlot: "",
            scope: "",
            requiresRebuild: false
        }
    }

    function _sidebarRoleKey(surfaceId: string): string {
        if (surfaceId === "featureSidebar")
            return "feature"
        if (surfaceId === "systemSidebar")
            return "system"
        return ""
    }

    function _validSidebarSlot(value: var, fallback: string): string {
        const slot = String(value ?? "")
        return slot === "left" || slot === "right" ? slot : fallback
    }

    function sidebarAssignments(): var {
        const configuredFeature = root._validSidebarSlot(
            Config.options?.sidebar?.shellLayout?.feature?.slot, "left")
        const configuredSystem = root._validSidebarSlot(
            Config.options?.sidebar?.shellLayout?.system?.slot, "right")
        if (configuredFeature !== configuredSystem) {
            return {
                featureSidebar: configuredFeature,
                systemSidebar: configuredSystem,
                sanitized: false
            }
        }
        return {
            featureSidebar: configuredFeature,
            systemSidebar: configuredFeature === "left" ? "right" : "left",
            sanitized: true
        }
    }

    function sidebarRoleForSlot(slot: string): string {
        const assignments = root.sidebarAssignments()
        if (assignments.featureSidebar === slot)
            return "featureSidebar"
        if (assignments.systemSidebar === slot)
            return "systemSidebar"
        return ""
    }

    // Physical-side sidebar helpers for spatial triggers (bar corner buttons):
    // a left-corner control always addresses whatever role currently occupies
    // the left slot, while feature-specific triggers keep semantic open state.
    function sidebarOpenAtSlot(slot: string): bool {
        const role = root.sidebarRoleForSlot(slot)
        if (role === "featureSidebar")
            return GlobalStates.sidebarLeftOpen
        if (role === "systemSidebar")
            return GlobalStates.sidebarRightOpen
        return false
    }

    function setSidebarOpenAtSlot(slot: string, open: bool): void {
        const role = root.sidebarRoleForSlot(slot)
        if (role === "featureSidebar")
            GlobalStates.sidebarLeftOpen = open
        else if (role === "systemSidebar")
            GlobalStates.sidebarRightOpen = open
    }

    function toggleSidebarAtSlot(slot: string): void {
        root.setSidebarOpenAtSlot(slot, !root.sidebarOpenAtSlot(slot))
    }

    function _sidebarSizeState(surfaceId: string): var {
        const roleKey = root._sidebarRoleKey(surfaceId)
        if (roleKey.length === 0)
            return ({})
        const role = Config.options?.sidebar?.shellLayout?.[roleKey]
        const configuredMode = String(role?.sizeMode ?? "full")
        const sizeMode = ["full", "fit", "custom"].includes(configuredMode)
            ? configuredMode : "full"
        const customHeight = Math.max(320, Math.min(2160,
            Number(role?.customHeight ?? 720)))
        const width = Math.max(320, Math.min(900,
            Number(role?.width ?? 460)))
        return {
            sizeMode: sizeMode,
            customHeight: Math.round(customHeight),
            width: Math.round(width),
            legacyFitEnabled: surfaceId === "featureSidebar"
                ? (Config.options?.sidebar?.collapseWidgetsTab ?? false)
                : (Config.options?.sidebar?.collapseEmptyNotifications ?? false)
        }
    }

    function descriptor(surfaceId: string): var {
        const found = root._descriptors.find(item => item.id === surfaceId)
        return found ? root._clone(found) : null
    }

    function surfacesForFamily(family: string): var {
        const targetFamily = family.length > 0 ? family : root.activeFamily
        return root._descriptors
            .filter(item => item.families.includes(targetFamily))
            .map(item => root._clone(item))
    }

    function currentState(surfaceId: string, outputName: string): var {
        const desc = root.descriptor(surfaceId)
        if (!desc)
            return root._failure("unknown-surface", "Unknown shell surface")

        switch (surfaceId) {
        case "featureSidebar":
        case "systemSidebar": {
            const assignments = root.sidebarAssignments()
            const sizeState = root._sidebarSizeState(surfaceId)
            return {
                ok: true,
                id: surfaceId,
                slot: assignments[surfaceId],
                scope: desc.layoutScope,
                outputName: outputName,
                sizeMode: sizeState.sizeMode,
                customHeight: sizeState.customHeight,
                width: sizeState.width,
                legacyFitEnabled: sizeState.legacyFitEnabled,
                sanitizedAssignment: assignments.sanitized,
                source: "sidebar.shellLayout"
            }
        }
        case "iiBar": {
            const vertical = Config.options?.bar?.vertical ?? false
            const alternateEdge = Config.options?.bar?.bottom ?? false
            return {
                ok: true,
                id: surfaceId,
                slot: vertical ? (alternateEdge ? "right" : "left")
                    : (alternateEdge ? "bottom" : "top"),
                scope: desc.layoutScope,
                outputName: outputName,
                enabledOutputs: Config.options?.bar?.screenList ?? [],
                source: "bar.vertical+bar.bottom"
            }
        }
        case "iiDock":
            return {
                ok: true,
                id: surfaceId,
                slot: Config.options?.dock?.position ?? "bottom",
                enabled: Config.options?.dock?.enable ?? true,
                thickness: Math.round(Config.options?.dock?.height ?? 60),
                scope: desc.layoutScope,
                outputName: outputName,
                enabledOutputs: Config.options?.dock?.screenList ?? [],
                source: "dock.position"
            }
        case "waffleBar":
            return {
                ok: true,
                id: surfaceId,
                slot: (Config.options?.waffles?.bar?.bottom ?? true) ? "bottom" : "top",
                scope: desc.layoutScope,
                outputName: outputName,
                enabledOutputs: Config.options?.waffles?.bar?.screenList ?? [],
                source: "waffles.bar.bottom"
            }
        default:
            return root._failure("unsupported-surface", "Surface state adapter is unavailable")
        }
    }

    function legalSlots(surfaceId: string, outputName: string): var {
        const desc = root.descriptor(surfaceId)
        if (!desc)
            return []
        return root._clone(desc.slots)
    }

    function _occupiedFoundationSurface(surfaceId: string, slot: string,
            outputName: string): string {
        if (root.activeFamily !== "ii")
            return ""
        if (surfaceId === "iiBar") {
            const dock = root.currentState("iiDock", outputName)
            if (dock.ok && dock.enabled && dock.slot === slot)
                return "iiDock"
        }
        if (surfaceId === "iiDock") {
            const bar = root.currentState("iiBar", outputName)
            if (bar.ok && bar.slot === slot)
                return "iiBar"
        }
        return ""
    }

    function validatePlacement(surfaceId: string, slot: string, outputName: string): var {
        const desc = root.descriptor(surfaceId)
        if (!desc)
            return root._failure("unknown-surface", "Unknown shell surface")
        if (!desc.families.includes(root.activeFamily))
            return root._failure("inactive-family", "Surface is unavailable in the active family")
        if (!desc.slots.includes(slot))
            return root._failure("invalid-slot", "Surface does not support that slot")

        const current = root.currentState(surfaceId, outputName)
        if (surfaceId === "featureSidebar" || surfaceId === "systemSidebar") {
            const otherId = surfaceId === "featureSidebar"
                ? "systemSidebar" : "featureSidebar"
            const other = root.currentState(otherId, outputName)
            return {
                ok: true,
                code: "",
                message: "",
                effectiveSlot: slot,
                scope: desc.layoutScope,
                outputName: outputName,
                occupiedBy: other.ok && other.slot === slot ? otherId : "",
                swapWith: other.ok && other.slot === slot ? otherId : "",
                changed: !(current.ok && current.slot === slot),
                requiresRebuild: true
            }
        }

        // Bar and dock exchange edges like the sidebars do: dropping one on
        // the other's edge is an atomic swap, never a silent overlap.
        const occupiedBy = current.ok && current.slot === slot
            ? "" : root._occupiedFoundationSurface(surfaceId, slot, outputName)
        return {
            ok: true,
            code: "",
            message: "",
            effectiveSlot: slot,
            scope: desc.layoutScope,
            outputName: outputName,
            occupiedBy: occupiedBy,
            swapWith: occupiedBy,
            changed: !(current.ok && current.slot === slot),
            requiresRebuild: surfaceId === "iiBar" || surfaceId === "iiDock" || surfaceId === "waffleBar"
        }
    }

    function _barKeyUpdates(slot: string): var {
        return {
            "bar.vertical": slot === "left" || slot === "right",
            "bar.bottom": slot === "bottom" || slot === "right"
        }
    }

    function moveSurface(surfaceId: string, slot: string, outputName: string): var {
        const validation = root.validatePlacement(surfaceId, slot, outputName)
        if (!validation.ok)
            return validation
        if (!validation.changed)
            return validation

        switch (surfaceId) {
        case "featureSidebar":
        case "systemSidebar": {
            const targetRole = root._sidebarRoleKey(surfaceId)
            const otherRole = targetRole === "feature" ? "system" : "feature"
            const oppositeSlot = slot === "left" ? "right" : "left"
            const updates = {}
            updates["sidebar.shellLayout." + targetRole + ".slot"] = slot
            updates["sidebar.shellLayout." + otherRole + ".slot"] = oppositeSlot
            Config.setNestedValues(updates)
            break
        }
        case "iiBar": {
            const updates = root._barKeyUpdates(slot)
            if ((validation.swapWith ?? "") === "iiDock") {
                const barState = root.currentState("iiBar", outputName)
                updates["dock.position"] = barState.ok ? barState.slot : "bottom"
            }
            Config.setNestedValues(updates)
            break
        }
        case "iiDock": {
            if ((validation.swapWith ?? "") === "iiBar") {
                const dockState = root.currentState("iiDock", outputName)
                const updates = root._barKeyUpdates(
                    dockState.ok ? dockState.slot : "top")
                updates["dock.position"] = slot
                Config.setNestedValues(updates)
            } else {
                Config.setNestedValue("dock.position", slot)
            }
            break
        }
        case "waffleBar":
            Config.setNestedValue("waffles.bar.bottom", slot === "bottom")
            break
        default:
            return root._failure("mutation-not-ready",
                "Placement mutation is not available for this surface yet")
        }

        Config.flushWrites()
        const result = root._clone(validation)
        result.changed = true
        result.persisted = true
        return result
    }

    function setProperty(surfaceId: string, key: string, value: var, outputName: string): var {
        const desc = root.descriptor(surfaceId)
        if (!desc)
            return root._failure("unknown-surface", "Unknown shell surface")
        if (!desc.editableProperties.includes(key))
            return root._failure("unsupported-property", "Surface does not expose that property")

        if (surfaceId === "iiDock" && key === "thickness") {
            const numeric = Number(value)
            if (!Number.isFinite(numeric))
                return root._failure("invalid-value", "Invalid dock size")
            const clamped = Math.round(Math.max(40, Math.min(200, numeric)))
            Config.setNestedValue("dock.height", clamped)
            Config.flushWrites()
            return {
                ok: true,
                code: "",
                message: "",
                property: key,
                effectiveValue: clamped,
                scope: desc.layoutScope,
                outputName: outputName,
                persisted: true,
                requiresRebuild: false
            }
        }

        const roleKey = root._sidebarRoleKey(surfaceId)
        if (roleKey.length === 0)
            return root._failure("mutation-not-ready",
                "Property mutation is not available for this surface yet")

        let path = ""
        let effectiveValue = value
        if (key === "sizeMode") {
            const mode = String(value ?? "")
            if (!["full", "fit", "custom"].includes(mode))
                return root._failure("invalid-value", "Invalid sidebar size mode")
            path = "sidebar.shellLayout." + roleKey + ".sizeMode"
            effectiveValue = mode
        } else if (key === "height") {
            const numeric = Number(value)
            if (!Number.isFinite(numeric))
                return root._failure("invalid-value", "Invalid sidebar height")
            path = "sidebar.shellLayout." + roleKey + ".customHeight"
            effectiveValue = Math.round(Math.max(320, Math.min(2160, numeric)))
        } else if (key === "thickness") {
            const numeric = Number(value)
            if (!Number.isFinite(numeric))
                return root._failure("invalid-value", "Invalid sidebar width")
            path = "sidebar.shellLayout." + roleKey + ".width"
            effectiveValue = Math.round(Math.max(320, Math.min(900, numeric)))
        }

        if (path.length === 0)
            return root._failure("unsupported-property", "Unsupported sidebar property")
        Config.setNestedValue(path, effectiveValue)
        Config.flushWrites()
        return {
            ok: true,
            code: "",
            message: "",
            property: key,
            effectiveValue: effectiveValue,
            scope: desc.layoutScope,
            outputName: outputName,
            persisted: true,
            requiresRebuild: false
        }
    }

    function resetSurface(surfaceId: string, outputName: string): var {
        if (!root.descriptor(surfaceId))
            return root._failure("unknown-surface", "Unknown shell surface")
        switch (surfaceId) {
        case "featureSidebar":
        case "systemSidebar": {
            const roleKey = root._sidebarRoleKey(surfaceId)
            const defaultSlot = surfaceId === "featureSidebar" ? "left" : "right"
            const placement = root.moveSurface(surfaceId, defaultSlot, outputName)
            if (!placement.ok)
                return placement
            const updates = {}
            updates["sidebar.shellLayout." + roleKey + ".sizeMode"] = "full"
            updates["sidebar.shellLayout." + roleKey + ".customHeight"] = 720
            updates["sidebar.shellLayout." + roleKey + ".width"] = 460
            Config.setNestedValues(updates)
            Config.flushWrites()
            const result = root._clone(placement)
            result.reset = true
            return result
        }
        case "iiBar":
            return root.moveSurface(surfaceId, "top", outputName)
        case "iiDock": {
            const placement = root.moveSurface(surfaceId, "bottom", outputName)
            if (!placement.ok)
                return placement
            Config.setNestedValue("dock.height", 60)
            Config.flushWrites()
            const result = root._clone(placement)
            result.reset = true
            return result
        }
        case "waffleBar":
            return root.moveSurface(surfaceId, "bottom", outputName)
        default:
            return root._failure("reset-not-ready",
                "Reset is not available for this surface yet")
        }
    }

    function diagnosticState(outputName: string): var {
        const descriptors = root.surfacesForFamily(root.activeFamily)
        return {
            family: root.activeFamily,
            outputName: outputName,
            surfaces: descriptors.map(desc => ({
                descriptor: desc,
                current: root.currentState(desc.id, outputName),
                legalSlots: root.legalSlots(desc.id, outputName)
            }))
        }
    }
}
