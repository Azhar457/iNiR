import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

ContentPage {
    settingsPageIndex: 24
    settingsPageName: Translation.tr("AI")

    Component.onCompleted: Ai.ensureInitialized()

    // ── Setup status ─────────────────────────────────────────────
    SettingsCardSection {
        expanded: true
        icon: "rocket_launch"
        title: Translation.tr("Get started")

        SettingsGroup {
            component StatusRow: RowLayout {
                id: statusRow
                property string statusIcon: ""
                property bool ok: false
                property string label: ""
                property string detail: ""
                Layout.fillWidth: true
                spacing: 10

                MaterialSymbol {
                    text: statusRow.statusIcon
                    iconSize: 20
                    color: statusRow.ok ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        Layout.fillWidth: true
                        text: statusRow.label
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: statusRow.detail.length > 0
                        text: statusRow.detail
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                        wrapMode: Text.WordWrap
                    }
                }
                MaterialSymbol {
                    text: statusRow.ok ? "check_circle" : "radio_button_unchecked"
                    iconSize: 18
                    color: statusRow.ok ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                }
            }

            StatusRow {
                statusIcon: "smart_toy"
                ok: (Ai.getModel() ?? null) !== null
                label: (Ai.getModel() ?? null) !== null
                    ? Translation.tr("Active model: %1").arg(Ai.getModel().name)
                    : Translation.tr("No model selected")
                detail: Translation.tr("Pick one from the model selector in the chat sidebar, or add a provider below")
            }

            StatusRow {
                statusIcon: "key"
                ok: Ai.currentModelHasApiKey
                label: Ai.currentModelHasApiKey
                    ? Translation.tr("API key ready for the active model")
                    : Translation.tr("The active model needs an API key")
                detail: Ai.currentModelHasApiKey ? "" : Translation.tr("Type /key YOUR_KEY in the chat, or re-add the provider below with its key")
            }

            StatusRow {
                readonly property bool localFound: Ai.modelList.some(m => (Ai.models[m]?.endpoint ?? "").includes("localhost"))
                statusIcon: "computer"
                ok: localFound
                label: localFound
                    ? Translation.tr("Local models detected (Ollama)")
                    : Translation.tr("No local models")
                detail: localFound ? "" : Translation.tr("Install Ollama and pull a model to chat without any account or key")
            }

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                text: Translation.tr("Two ways to use the assistant: run models locally with Ollama (private, free, no key), or connect an online provider below — several have free tiers.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }
        }
    }

    // ── Providers ────────────────────────────────────────────────
    SettingsCardSection {
        expanded: true
        icon: "cloud"
        title: Translation.tr("Providers & models")

        SettingsGroup {
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                Layout.bottomMargin: 4

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("AI Providers")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }

                RippleButton {
                    implicitWidth: addProviderBtnRow.implicitWidth + 16
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.small
                    colBackground: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.88)
                    colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.80)
                    onClicked: {
                        providerForm.editingIndex = -1
                        providerForm.titleText = Translation.tr("Add AI Provider")
                        providerForm.saveLabelText = Translation.tr("Add")
                        providerNameInput.text = ""
                        providerEndpointInput.text = ""
                        providerForm.selectedFormat = "openai"
                        providerForm._manualOverride = false
                        providerModelInput.text = ""
                        providerApiKeyInput.text = ""
                        providerForm.expanded = true
                    }

                    contentItem: RowLayout {
                        id: addProviderBtnRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialSymbol {
                            text: "add"
                            iconSize: 16
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: Translation.tr("Add Provider")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: Appearance.colors.colPrimary
                        }
                    }
                }
            }

            // ── Quick-add provider presets ──────────────────────────────────
            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                text: Translation.tr("Quick add — popular providers (free tiers available)")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }

            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                spacing: 6

                Repeater {
                    model: AiProviderPresets.presets

                    delegate: RippleButton {
                        id: presetChip
                        required property var modelData
                        readonly property var preset: presetChip.modelData
                        readonly property bool alreadyAdded:
                            (Config.options?.ai?.extraModels ?? []).some(m =>
                                (m?.endpoint ?? "") === preset.endpoint)

                        implicitWidth: presetChipRow.implicitWidth + 20
                        implicitHeight: 32
                        buttonRadius: Appearance.rounding.full
                        colBackground: preset.local
                            ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.88)
                            : Appearance.colors.colLayer2
                        colBackgroundHover: preset.local
                            ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.80)
                            : Appearance.colors.colLayer2Hover

                        onClicked: {
                            // Pre-fill the existing Add Provider form so the user
                            // only needs to paste a key (or just hit Add for local).
                            providerForm.editingIndex = -1
                            providerForm.titleText = Translation.tr("Add %1").arg(preset.name)
                            providerForm.saveLabelText = Translation.tr("Add")
                            providerNameInput.text = preset.name
                            providerEndpointInput.text = preset.endpoint
                            providerModelInput.text = preset.model
                            providerForm.selectedFormat = preset.api_format ?? "openai"
                            providerForm._manualOverride = true
                            providerApiKeyInput.text = ""
                            providerForm.expanded = true
                        }

                        contentItem: RowLayout {
                            id: presetChipRow
                            anchors.centerIn: parent
                            spacing: 6
                            CustomIcon {
                                width: Appearance.font.pixelSize.large
                                height: Appearance.font.pixelSize.large
                                source: presetChip.preset.icon
                                colorize: true
                                color: presetChip.preset.local ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer2
                            }
                            StyledText {
                                text: presetChip.preset.name
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: presetChip.preset.local ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer2
                            }
                            MaterialSymbol {
                                visible: presetChip.alreadyAdded
                                text: "check_circle"
                                iconSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colPrimary
                            }
                        }

                        StyledToolTip {
                            text: presetChip.preset.description
                                + (presetChip.preset.requiresKey
                                    ? "\n\n" + Translation.tr("Get a key: ") + presetChip.preset.keyGetLink
                                    : "")
                        }
                    }
                }
            }

            Repeater {
                model: Config.options?.ai?.extraModels ?? []

                delegate: Item {
                    id: providerItem
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: providerRow.implicitHeight + 12

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.small
                        color: providerMA.containsMouse ? Appearance.colors.colLayer1Hover : "transparent"
                        Behavior on color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

                        RowLayout {
                            id: providerRow
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10

                            MaterialSymbol {
                                readonly property var formatIcons: ({
                                    "openai": "smart_toy",
                                    "gemini": "auto_awesome",
                                    "mistral": "smart_toy",
                                    "anthropic": "psychology",
                                    "openai-response": "bolt"
                                })
                                text: formatIcons[providerItem.modelData?.api_format] ?? "smart_toy"
                                iconSize: 20
                                color: Appearance.colors.colTertiary
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                StyledText {
                                    Layout.fillWidth: true
                                    text: providerItem.modelData?.name ?? providerItem.modelData?.model ?? Translation.tr("Unnamed")
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colOnLayer1
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: providerItem.modelData?.model ?? ""
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colSubtext
                                    elide: Text.ElideMiddle
                                }
                            }

                            Rectangle {
                                width: fmtLabel.implicitWidth + 12
                                height: 22
                                radius: Appearance.rounding.full
                                color: ColorUtils.transparentize(Appearance.colors.colTertiary, 0.88)

                                readonly property var formatLabels: ({
                                    "openai": "OpenAI",
                                    "gemini": "Gemini",
                                    "mistral": "Mistral",
                                    "anthropic": "Anthropic",
                                    "openai-response": "Responses"
                                })

                                StyledText {
                                    id: fmtLabel
                                    anchors.centerIn: parent
                                    text: parent.formatLabels[providerItem.modelData?.api_format] ?? providerItem.modelData?.api_format ?? "OpenAI"
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    font.weight: Font.Medium
                                    color: Appearance.colors.colTertiary
                                }
                            }

                            RippleButton {
                                implicitWidth: 28
                                implicitHeight: 28
                                buttonRadius: 14
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: {
                                    const m = providerItem.modelData
                                    providerForm.editingIndex = providerItem.index
                                    providerForm.titleText = Translation.tr("Edit AI Provider")
                                    providerForm.saveLabelText = Translation.tr("Save")
                                    providerNameInput.text = m?.name ?? ""
                                    providerEndpointInput.text = m?.endpoint ?? ""
                                    providerForm.selectedFormat = m?.api_format ?? "openai"
                                    providerForm._manualOverride = true
                                    providerModelInput.text = m?.model ?? ""
                                    providerApiKeyInput.text = ""
                                    providerForm.expanded = true
                                }

                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "edit"
                                    iconSize: 14
                                    color: Appearance.colors.colSubtext
                                }

                                StyledToolTip { text: Translation.tr("Edit") }
                            }

                            RippleButton {
                                implicitWidth: 28
                                implicitHeight: 28
                                buttonRadius: 14
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: {
                                    let models = [...(Config.options?.ai?.extraModels ?? [])]
                                    models.splice(providerItem.index, 1)
                                    Config.setNestedValue("ai.extraModels", models)
                                }

                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "close"
                                    iconSize: 14
                                    color: Appearance.colors.colSubtext
                                }

                                StyledToolTip { text: Translation.tr("Remove") }
                            }
                        }

                        MouseArea {
                            id: providerMA
                            anchors.fill: parent
                            z: -1
                            hoverEnabled: true
                        }
                    }
                }
            }

            ColumnLayout {
                visible: (Config.options?.ai?.extraModels ?? []).length === 0
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                spacing: 4

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "neurology"
                    iconSize: 28
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("No providers yet")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("Add an AI provider to use the chat sidebar. Local models via Ollama and free OpenRouter models are loaded automatically.")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                }
            }

            Rectangle {
                id: providerForm
                Layout.fillWidth: true
                Layout.topMargin: 4

                property bool expanded: false
                property int editingIndex: -1
                property string titleText: Translation.tr("Add AI Provider")
                property string saveLabelText: Translation.tr("Add")
                property string selectedFormat: "openai"
                property bool _manualOverride: false

                implicitHeight: expanded ? aiAddFormCol.implicitHeight + 24 : 0
                visible: expanded
                clip: true
                radius: Appearance.rounding.small
                color: Appearance.colors.colSurfaceContainerLow
                border.width: 1
                border.color: Appearance.colors.colLayer0Border

                Behavior on implicitHeight {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }

                ColumnLayout {
                    id: aiAddFormCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    StyledText {
                        text: providerForm.titleText
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer1
                    }

                    ColumnLayout {
                        spacing: 4
                        Layout.fillWidth: true

                        StyledText {
                            text: Translation.tr("Provider name")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }

                        MaterialTextField {
                            id: providerNameInput
                            Layout.fillWidth: true
                            placeholderText: Translation.tr("e.g. My Claude Proxy")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSurface
                            placeholderTextColor: Appearance.colors.colSubtext
                            background: Rectangle {
                                color: Appearance.colors.colLayer1
                                radius: Appearance.rounding.small
                                border.width: providerNameInput.activeFocus ? 2 : 1
                                border.color: providerNameInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 4
                        Layout.fillWidth: true

                        StyledText {
                            text: Translation.tr("API endpoint URL")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }

                        MaterialTextField {
                            id: providerEndpointInput
                            Layout.fillWidth: true
                            placeholderText: "https://api.openai.com/v1/chat/completions"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSurface
                            placeholderTextColor: Appearance.colors.colSubtext
                            background: Rectangle {
                                color: Appearance.colors.colLayer1
                                radius: Appearance.rounding.small
                                border.width: providerEndpointInput.activeFocus ? 2 : 1
                                border.color: providerEndpointInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                            }

                            onTextChanged: {
                                if (providerForm._manualOverride) return
                                const url = text.toLowerCase()
                                if (url.includes("generativelanguage.googleapis.com")) {
                                    providerForm.selectedFormat = "gemini"
                                } else if (url.includes("api.anthropic.com") || url.includes("/v1/messages")) {
                                    providerForm.selectedFormat = "anthropic"
                                } else if (url.includes("api.openai.com") || url.includes("/v1/chat/completions")) {
                                    providerForm.selectedFormat = "openai"
                                }
                            }
                        }
                    }

                    ContentSubsection {
                        title: Translation.tr("API format")

                        ConfigSelectionArray {
                            enableSettingsSearch: false
                            options: [
                                { displayName: "OpenAI", icon: "smart_toy", value: "openai" },
                                { displayName: "Gemini", icon: "auto_awesome", value: "gemini" },
                                { displayName: "Anthropic", icon: "psychology", value: "anthropic" },
                                { displayName: Translation.tr("Responses API"), icon: "bolt", value: "openai-response" }
                            ]
                            currentValue: providerForm.selectedFormat
                            onSelected: (newValue) => {
                                providerForm.selectedFormat = newValue
                                providerForm._manualOverride = true
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: providerForm.selectedFormat === "openai"
                            text: Translation.tr("Compatible with OpenAI, Mistral, Ollama, OpenRouter, vLLM, and any OpenAI-compatible endpoint.")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colSubtext
                            wrapMode: Text.WordWrap
                        }
                    }

                    ColumnLayout {
                        spacing: 4
                        Layout.fillWidth: true

                        StyledText {
                            text: Translation.tr("Model code")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }

                        MaterialTextField {
                            id: providerModelInput
                            Layout.fillWidth: true
                            placeholderText: "gpt-4.1"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSurface
                            placeholderTextColor: Appearance.colors.colSubtext
                            background: Rectangle {
                                color: Appearance.colors.colLayer1
                                radius: Appearance.rounding.small
                                border.width: providerModelInput.activeFocus ? 2 : 1
                                border.color: providerModelInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 4
                        Layout.fillWidth: true

                        StyledText {
                            text: Translation.tr("API key (optional)")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }

                        MaterialTextField {
                            id: providerApiKeyInput
                            Layout.fillWidth: true
                            placeholderText: "sk-..."
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSurface
                            placeholderTextColor: Appearance.colors.colSubtext
                            echoMode: TextInput.Password
                            background: Rectangle {
                                color: Appearance.colors.colLayer1
                                radius: Appearance.rounding.small
                                border.width: providerApiKeyInput.activeFocus ? 2 : 1
                                border.color: providerApiKeyInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Item { Layout.fillWidth: true }

                        RippleButton {
                            implicitWidth: cancelProviderLabel.implicitWidth + 24
                            implicitHeight: 32
                            buttonRadius: Appearance.rounding.small
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colLayer1Hover
                            onClicked: {
                                providerForm.expanded = false
                                providerForm.editingIndex = -1
                                providerNameInput.text = ""
                                providerEndpointInput.text = ""
                                providerForm.selectedFormat = "openai"
                                providerForm._manualOverride = false
                                providerModelInput.text = ""
                                providerApiKeyInput.text = ""
                            }

                            contentItem: StyledText {
                                id: cancelProviderLabel
                                anchors.centerIn: parent
                                text: Translation.tr("Cancel")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer1
                            }
                        }

                        RippleButton {
                            implicitWidth: saveProviderLabel.implicitWidth + 24
                            implicitHeight: 32
                            buttonRadius: Appearance.rounding.small
                            colBackground: Appearance.colors.colPrimary
                            colBackgroundHover: Appearance.colors.colPrimaryHover
                            enabled: providerEndpointInput.text.trim() !== "" && providerModelInput.text.trim() !== ""
                            opacity: enabled ? 1 : 0.5
                            onClicked: {
                                const modelCode = providerModelInput.text.trim()
                                const apiKey = providerApiKeyInput.text.trim()
                                const keyId = modelCode.toLowerCase().replace(/[:\/ ]/g, "-")

                                const entry = {
                                    name: providerNameInput.text.trim() || modelCode,
                                    endpoint: providerEndpointInput.text.trim(),
                                    model: modelCode,
                                    api_format: providerForm.selectedFormat,
                                    requires_key: apiKey.length > 0,
                                    key_id: keyId,
                                }

                                let models = [...(Config.options?.ai?.extraModels ?? [])]
                                if (providerForm.editingIndex >= 0) {
                                    const orig = models[providerForm.editingIndex]
                                    if (orig) {
                                        for (let k in orig) {
                                            if (!(k in entry) && k !== "index") entry[k] = orig[k]
                                        }
                                    }
                                    models[providerForm.editingIndex] = entry
                                } else {
                                    models.push(entry)
                                }
                                Config.setNestedValue("ai.extraModels", models)

                                if (apiKey.length > 0) {
                                    KeyringStorage.setNestedField(["apiKeys", keyId], apiKey)
                                }

                                providerForm.expanded = false
                                providerForm.editingIndex = -1
                                providerNameInput.text = ""
                                providerEndpointInput.text = ""
                                providerForm.selectedFormat = "openai"
                                providerForm._manualOverride = false
                                providerModelInput.text = ""
                                providerApiKeyInput.text = ""
                            }

                            contentItem: StyledText {
                                id: saveProviderLabel
                                anchors.centerIn: parent
                                text: providerForm.saveLabelText
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnPrimary
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Assistant behavior ───────────────────────────────────────
    SettingsCardSection {
        expanded: false
        icon: "psychology"
        title: Translation.tr("Assistant behavior")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("System prompt")
                tooltip: Translation.tr("Custom instructions the assistant always receives")

                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("System prompt")
                    text: Config.options?.ai?.systemPrompt ?? ""
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Qt.callLater(() => {
                            Config.setNestedValue("ai.systemPrompt", text)
                        });
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Default tool mode")
                tooltip: Translation.tr("What the assistant can do. Search is only available on Gemini models; Functions lets it read/edit the shell config and run approved commands")

                ConfigSelectionArray {
                    enableSettingsSearch: false
                    currentValue: Config.options?.ai?.tool ?? "search"
                    onSelected: newValue => {
                        Config.setNestedValue("ai.tool", newValue);
                    }
                    options: [
                        { displayName: Translation.tr("Functions"), icon: "service_toolbox", value: "functions" },
                        { displayName: Translation.tr("Search"), icon: "search", value: "search" },
                        { displayName: Translation.tr("None"), icon: "block", value: "none" }
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Temperature")
                tooltip: Translation.tr("Higher = more creative, lower = more predictable. Default 0.5")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    MaterialSymbol {
                        text: "device_thermostat"
                        iconSize: 20
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledSlider {
                        id: temperatureSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 1
                        stepSize: 0.05
                        value: Persistent.states?.ai?.temperature ?? 0.5
                        configuration: StyledSlider.Configuration.S
                        tooltipContent: value.toFixed(2)
                        onMoved: {
                            if (Persistent.states?.ai) Persistent.states.ai.temperature = Math.round(value * 100) / 100;
                        }
                    }
                    StyledText {
                        Layout.preferredWidth: 36
                        horizontalAlignment: Text.AlignRight
                        text: temperatureSlider.value.toFixed(2)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }
            }
        }
    }

    // ── Privacy ──────────────────────────────────────────────────
    SettingsCardSection {
        expanded: false
        icon: "policy"
        title: Translation.tr("Privacy & policy")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Allow AI features")
                tooltip: Translation.tr("Local only restricts the assistant to models running on this machine (Ollama)")

                ConfigSelectionArray {
                    enableSettingsSearch: false
                    currentValue: Config.options?.policies?.ai ?? 0
                    onSelected: newValue => {
                        Config.setNestedValue("policies.ai", newValue);
                    }
                    options: [
                        { displayName: Translation.tr("No"), icon: "close", value: 0 },
                        { displayName: Translation.tr("Yes"), icon: "check", value: 1 },
                        { displayName: Translation.tr("Local only"), icon: "sync_saved_locally", value: 2 }
                    ]
                }
            }
        }
    }

    // ── Voice input ──────────────────────────────────────────────
    SettingsCardSection {
        expanded: false
        icon: "mic"
        title: Translation.tr("Voice input")

        SettingsGroup {
            ConfigSpinBox {
                id: voiceDurationSpin
                // Without the guard the spin box writes its own default over the
                // user's value while the page is still being created.
                property bool _ready: false
                Component.onCompleted: _ready = true

                icon: "timer"
                text: Translation.tr("Max recording length (seconds)")
                value: Config.options?.voiceSearch?.duration ?? 5
                from: 3
                to: 60
                stepSize: 1
                onValueChanged: {
                    if (voiceDurationSpin._ready)
                        Config.setNestedValue("voiceSearch.duration", value)
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                text: Translation.tr("The mic button in the chat and the voice search use Gemini for transcription — a free Gemini API key must be set (add the Gemini provider above with a key, or type /key in the chat with a Gemini model selected).")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }
        }
    }
}