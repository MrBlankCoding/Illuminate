import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import illuminate.ui

pragma ComponentBehavior: Bound

Popup {
    id: root

    property bool showArrow: true
    property var focusRouter: null
    property real arrowOffset: 0
    readonly property int shadowPad: 18
    property bool previewing: false

    readonly property real seedHue: Theme.seed.hslHue < 0 ? 0 : Theme.seed.hslHue
    readonly property real seedVividness: Theme.seed.hslHue < 0 ? 0 : Theme.seed.hslSaturation

    function seedAt(hue, vividness) {
        return Qt.hsla(hue, Math.max(0, Math.min(1, vividness)), 0.5, 1)
    }

    // the wheel has a feel: a tick every twelfth of the way round, a firmer
    // one settling into the grey centre (only felt on a Force Touch trackpad)
    readonly property int hueDetents: 12
    readonly property real centreRadius: 0.08
    property int lastDetent: -1
    property bool inCentre: false
    property point pendingPointerPosition: Qt.point(0, 0)

    function feelAt(hue, vividness) {
        const centre = vividness < root.centreRadius
        if (centre !== root.inCentre) {
            root.inCentre = centre
            if (centre)
                WindowHelper.haptic("snap")
        }
        const detent = Math.floor(hue * root.hueDetents) % root.hueDetents
        if (!centre && root.lastDetent >= 0 && detent !== root.lastDetent)
            WindowHelper.haptic("tick")
        root.lastDetent = detent
    }

    function pickAt(x, y) {
        const dx = x - disc.radius
        const dy = disc.radius - y
        let hue = Math.atan2(dy, dx) / (Math.PI * 2)
        if (hue < 0)
            hue += 1
        const vividness = Math.sqrt(dx * dx + dy * dy) / disc.radius
        root.feelAt(hue, vividness)
        root.previewing = true
        Browser.previewThemeColor(root.seedAt(hue, vividness))
    }

    function queuePickAt(x, y) {
        root.pendingPointerPosition = Qt.point(x, y)
        if (!pointerPreviewTimer.running)
            pointerPreviewTimer.start()
    }

    function flushPendingPick() {
        pointerPreviewTimer.stop()
        root.pickAt(root.pendingPointerPosition.x, root.pendingPointerPosition.y)
    }

    function commitPreview() {
        if (!root.previewing)
            return
        root.previewing = false
        Browser.setThemeColor(Theme.seed)
    }

    onOpened: {
        if (root.focusRouter)
            root.focusRouter.claimUiFocus("themePicker")
    }

    Connections {
        target: root.focusRouter
        enabled: root.visible
        ignoreUnknownSignals: true
        function onFocusReturnedToWeb() {
            root.close()
        }
    }
    Timer {
        id: pointerPreviewTimer
        interval: 16
        repeat: false
        onTriggered: root.pickAt(root.pendingPointerPosition.x, root.pendingPointerPosition.y)
    }
    onClosed: {
        if (pointerPreviewTimer.running)
            root.flushPendingPick()
        root.commitPreview()
        if (root.focusRouter)
            root.focusRouter.releaseUiFocus("themePicker")
    }

    popupType: Qt.platform.os === "windows" ? Popup.Item : Popup.Window
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent
    padding: shadowPad
    implicitWidth: 292 + shadowPad * 2
    Component.onCompleted: PopupCloser.watch(root)

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150; easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: 180; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Theme.durationFast; easing.type: Easing.InQuad }
        NumberAnimation { property: "scale"; to: 0.98; duration: Theme.durationFast; easing.type: Easing.InQuad }
    }

    background: Item {
        RectangularShadow { anchors.fill: card; radius: card.radius; blur: 24; offset.y: 6; color: Theme.shadow }
        Rectangle {
            id: card
            anchors.fill: parent
            anchors.margins: root.shadowPad
            radius: Theme.radiusCommand
            color: Theme.cardBg
            border.width: 1
            border.color: Theme.cardBorder
        }
        Shape {
            visible: root.showArrow
            x: card.x - 12; y: card.y + (card.height - 29) / 2 + root.arrowOffset
            width: 14; height: 29
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: Theme.cardBg; strokeColor: "transparent"
                PathSvg { path: "M14 0 L12 0 L2.6 12.1 Q0 14.5 2.6 16.9 L12 29 L14 29 Z" }
            }
            ShapePath {
                fillColor: "transparent"; strokeColor: Theme.cardBorder; strokeWidth: 1
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M12 0 L2.6 12.1 Q0 14.5 2.6 16.9 L12 29" }
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: 0

        RowLayout {
            spacing: Theme.space2
            Layout.fillWidth: true
            Layout.leftMargin: Theme.space4
            Layout.rightMargin: Theme.space3
            Layout.topMargin: 14

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true
                Text {
                    text: qsTr("Theme")
                    color: Theme.text
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeL; weight: Font.DemiBold }
                }
                Text {
                    Layout.fillWidth: true
                    text: Browser.space ? Browser.space.name : qsTr("Current space")
                    color: Theme.textMuted
                    elide: Text.ElideRight
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeS }
                }
            }

                Button {
                    id: resetButton
                    leftPadding: Theme.space2
                    rightPadding: Theme.space2
                    Layout.alignment: Qt.AlignTop
                    implicitHeight: 24
                enabled: Theme.hasCustomSeed
                opacity: enabled ? 1 : 0.4
                text: qsTr("Reset")
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeS }
                onClicked: {
                    root.previewing = false
                    Browser.resetThemeColor()
                }
                background: Item {
                    Rectangle {
                        anchors.fill: parent
                    radius: Theme.radiusS
                    color: resetButton.pressed ? Theme.itemPressed : (resetButton.hovered ? Theme.itemHover : "transparent")
                    }
                }
                contentItem: Text {
                    text: resetButton.text
                    color: resetButton.hovered ? Theme.text : Theme.textMuted
                    font: resetButton.font
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                Accessible.name: qsTr("Reset to the default theme")
            }
        }

        // hue around the edge, vividness outward from a grey centre: exactly the
        // HSL disc at half lightness, since a gradient between neighbouring
        // primaries and a fade from grey both interpolate along HSL lines
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 228
            Layout.topMargin: Theme.space3

            Shape {
                id: disc
                readonly property real radius: width / 2
                width: 212; height: 212
                anchors.centerIn: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: ConicalGradient {
                        centerX: disc.radius; centerY: disc.radius; angle: 0
                        GradientStop { position: 0 / 6; color: "#ff0000" }
                        GradientStop { position: 1 / 6; color: "#ffff00" }
                        GradientStop { position: 2 / 6; color: "#00ff00" }
                        GradientStop { position: 3 / 6; color: "#00ffff" }
                        GradientStop { position: 4 / 6; color: "#0000ff" }
                        GradientStop { position: 5 / 6; color: "#ff00ff" }
                        GradientStop { position: 6 / 6; color: "#ff0000" }
                    }
                    PathAngleArc { centerX: disc.radius; centerY: disc.radius; radiusX: disc.radius; radiusY: disc.radius; sweepAngle: 360 }
                }
                ShapePath {
                    strokeColor: Theme.cardBorder; strokeWidth: 1
                    fillGradient: RadialGradient {
                        centerX: disc.radius; centerY: disc.radius; centerRadius: disc.radius
                        focalX: disc.radius; focalY: disc.radius
                        GradientStop { position: 0; color: "#808080" }
                        GradientStop { position: 1; color: "#00808080" }
                    }
                    PathAngleArc { centerX: disc.radius; centerY: disc.radius; radiusX: disc.radius; radiusY: disc.radius; sweepAngle: 360 }
                }
            }

            // rings at a third and two thirds of the way out, as a sense of scale
            Repeater {
                model: [1 / 3, 2 / 3]
                delegate: Rectangle {
                    width: disc.width * modelData; height: width
                    required property real modelData
                    anchors.centerIn: disc
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.alpha("#ffffff", 0.28)
                }
            }

            Rectangle {
                id: marker
                width: pointerHandler.active ? 26 : 22; height: width; radius: width / 2
                x: disc.x + disc.radius + Math.cos(root.seedHue * Math.PI * 2) * root.seedVividness * disc.radius - width / 2
                y: disc.y + disc.radius - Math.sin(root.seedHue * Math.PI * 2) * root.seedVividness * disc.radius - height / 2
                color: root.seedAt(root.seedHue, root.seedVividness)
                border.width: 3
                border.color: "#ffffff"
                Behavior on width { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic } }

                RectangularShadow {
                    anchors.fill: parent
                    z: -1
                    radius: parent.radius
                    blur: 8; offset.y: 1
                    color: Qt.alpha("#000000", 0.35)
                }
            }

            Item {
                id: dragArea
                objectName: "themePickerWheel"
                anchors.fill: disc
                activeFocusOnTab: true

                PointHandler {
                    id: pointerHandler
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    target: null
                    onActiveChanged: {
                        if (active) {
                            dragArea.forceActiveFocus()
                            root.pickAt(point.position.x, point.position.y)
                            return
                        }
                        if (pointerPreviewTimer.running)
                            root.flushPendingPick()
                        root.commitPreview()
                        root.lastDetent = -1
                        root.inCentre = false
                    }
                    onPointChanged: {
                        if (active)
                            root.queuePickAt(point.position.x, point.position.y)
                    }
                }

                Keys.onPressed: event => {
                    let hue = root.seedHue
                    let vividness = root.seedVividness
                    if (event.key === Qt.Key_Left)
                        hue = (hue + 0.99) % 1
                    else if (event.key === Qt.Key_Right)
                        hue = (hue + 0.01) % 1
                    else if (event.key === Qt.Key_Up)
                        vividness += 0.04
                    else if (event.key === Qt.Key_Down)
                        vividness -= 0.04
                    else
                        return
                    root.previewing = false
                    Browser.setThemeColor(root.seedAt(hue, vividness))
                    event.accepted = true
                }
                Accessible.role: Accessible.Slider
                Accessible.name: qsTr("Theme colour")
                Accessible.description: qsTr("Left and right change the hue; up and down change how vivid it is")

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -3
                    radius: width / 2
                    visible: dragArea.activeFocus
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.accent
                }
            }
        }

        // each preset previewed as its own sidebar colour with its accent inside
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.space3
            Layout.rightMargin: Theme.space3
            Layout.topMargin: Theme.space3
            spacing: 0

            Repeater {
                model: Theme.presets
                delegate: AbstractButton {
                    id: swatch
                    required property var modelData
                    readonly property var preview: Theme.paletteFor(modelData.seed, Theme.isDark)
                    readonly property bool selected: Theme.sameSeed(Theme.seed, modelData.seed)
                    Layout.fillWidth: true
                    implicitHeight: 30
                    hoverEnabled: true
                    onClicked: {
                        root.previewing = false
                        Browser.setThemeColor(modelData.seed)
                    }

                    ToolTip {
                        visible: swatch.hovered
                        delay: 500
                        text: swatch.modelData.name
                    }
                    Accessible.name: modelData.name
                    Accessible.checkable: true
                    Accessible.checked: selected

                    contentItem: Item {
                        Rectangle {
                            anchors.centerIn: parent
                            width: 24; height: 24; radius: 12
                            color: "transparent"
                            border.width: 2
                            border.color: swatch.selected ? Theme.text
                                        : (swatch.hovered || swatch.visualFocus ? Qt.alpha(Theme.text, 0.25) : "transparent")
                            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 16; height: 16; radius: 8
                            color: swatch.preview.sidebarBg
                            border.width: 1
                            border.color: Qt.alpha(Theme.text, 0.12)
                            Rectangle {
                                anchors.centerIn: parent
                                width: 8; height: 8; radius: 4
                                color: swatch.preview.accent
                            }
                        }
                    }
                    background: null
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.space4; Layout.rightMargin: Theme.space4; Layout.topMargin: Theme.space3
            Layout.preferredHeight: 1
            color: Theme.cardBorder
        }

        // light or dark, for every space
        Rectangle {
            id: modeSwitch
            Layout.fillWidth: true
            Layout.leftMargin: Theme.space4; Layout.rightMargin: Theme.space4
            Layout.topMargin: Theme.space3; Layout.bottomMargin: Theme.space4
            Layout.preferredHeight: 32
            radius: Theme.radiusItem + 1
            color: Theme.fieldBg

            readonly property var modes: [
                { value: "system", label: qsTr("Auto"),  icon: "qrc:/illuminate/ui/icons/monitor.svg" },
                { value: "light",  label: qsTr("Light"), icon: "qrc:/illuminate/ui/icons/sun.svg" },
                { value: "dark",   label: qsTr("Dark"),  icon: "qrc:/illuminate/ui/icons/moon.svg" }
            ]
            readonly property int selectedIndex: Math.max(0, modes.findIndex(m => m.value === Theme.mode))
            readonly property real segmentWidth: (width - 4) / modes.length

            Rectangle {
                x: 2 + modeSwitch.selectedIndex * modeSwitch.segmentWidth
                y: 2
                width: modeSwitch.segmentWidth
                height: modeSwitch.height - 4
                radius: Theme.radiusItem - 1
                color: Theme.isDark ? Theme.surfaceHigh : Theme.bg
                border.width: 1
                border.color: Theme.itemActiveBorder
                Behavior on x { NumberAnimation { duration: Theme.durationMid; easing.type: Easing.OutCubic } }
            }

            Row {
                anchors.fill: parent
                anchors.margins: 2

                Repeater {
                    model: modeSwitch.modes
                    delegate: AbstractButton {
                        id: segment
                        required property var modelData
                        required property int index
                        readonly property bool selected: index === modeSwitch.selectedIndex
                        width: modeSwitch.segmentWidth
                        height: parent.height
                        hoverEnabled: true
                        onClicked: Browser.themeMode = modelData.value
                        Accessible.name: qsTr("%1 appearance").arg(modelData.label)
                        Accessible.checkable: true
                        Accessible.checked: selected

                        contentItem: Item {
                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                LucideIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: segment.modelData.icon
                                    size: 14
                                    color: segment.selected || segment.hovered ? Theme.text : Theme.textMuted
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: segment.modelData.label
                                    color: segment.selected || segment.hovered ? Theme.text : Theme.textMuted
                                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeS; weight: segment.selected ? Font.Medium : Font.Normal }
                                }
                            }
                        }
                        background: null
                    }
                }
            }
        }
    }
}
