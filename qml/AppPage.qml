/*
 * Copyright (C) 2026 LingmoOS Team.
 *
 * Author:     devalexandre <alexandre@dev2learn.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import LingmoUI.CompatibleModule 3.0 as LingmoUI

Flickable {
    id: page

    readonly property string pageName: "app"
    property string appKey: ""
    readonly property var app: { rootWindow.rev; return catalog.app(appKey) }
    readonly property bool found: app.key !== undefined

    // "arch" or "flathub": what the user picked, else what the store recommends
    property string chosen: ""
    readonly property string source: chosen !== "" ? chosen : (app.recommended || "")
    readonly property var src: source === "arch" ? app.arch : (source === "flathub" ? app.flathub : undefined)
    readonly property bool archOffered: !!app.arch && (app.arch.available || app.arch.installed)
    readonly property bool bothSources: archOffered && !!app.flathub
    readonly property bool installed: !!src && src.installed
    readonly property bool busyHere: installer.busy && installer.currentKey === appKey
    readonly property bool busyElsewhere: installer.busy && !busyHere

    property string flathubSize: ""
    property string lastError: ""
    property bool showLog: false
    property bool descriptionExpanded: false
    readonly property int margin: LingmoUI.Units.largeSpacing * 2

    contentWidth: width
    contentHeight: column.implicitHeight + margin * 2
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}

    LingmoUI.WheelHandler {
        target: page
    }

    Connections {
        target: catalog
        function onSizeReady(key, text) {
            if (key === page.appKey)
                page.flathubSize = text
        }
    }

    Connections {
        target: installer
        function onFinished(key, source, action, ok, message) {
            if (key !== page.appKey)
                return
            page.lastError = ok ? "" : message
            if (ok)
                page.showLog = false
        }
    }

    Component.onCompleted: {
        if (app.flathub)
            catalog.fetchFlathubSize(appKey)
    }

    function licenseText() {
        const license = app.license || ""
        if (app.licenseFree)
            return qsTr("Free software (%1)").arg(license)
        if (license === "" || license.toLowerCase().indexOf("proprietary") >= 0)
            return qsTr("Proprietary")
        return license
    }

    function sizeText() {
        if (source === "arch" && app.arch && app.arch.installedSize)
            return qsTr("%1 installed, %2 to download").arg(app.arch.installedSize).arg(app.arch.downloadSize)
        if (source === "flathub")
            return flathubSize !== "" ? flathubSize : qsTr("Unknown")
        return qsTr("Unknown")
    }

    function sourceName(s) {
        return s === "arch" ? qsTr("Arch version") : "Flathub"
    }

    ColumnLayout {
        id: column
        x: page.margin
        y: LingmoUI.Units.smallSpacing
        width: page.width - page.margin * 2
        spacing: LingmoUI.Units.largeSpacing * 1.5

        // Unknown app
        ColumnLayout {
            visible: !page.found
            Layout.fillWidth: true
            Layout.topMargin: 80
            spacing: LingmoUI.Units.largeSpacing

            Spinner {
                visible: !catalog.ready
                running: visible
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
            }
            Label {
                text: catalog.ready ? qsTr("This app was not found") : qsTr("Loading the app catalog…")
                font.pointSize: LingmoUI.Theme.fontSize * 1.3
                font.bold: true
                color: LingmoUI.Theme.textColor
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // Header: icon, name, developer, action
        RowLayout {
            visible: page.found
            Layout.fillWidth: true
            spacing: LingmoUI.Units.largeSpacing * 2

            AppIcon {
                size: 112
                source: page.app.iconUrl || ""
                iconName: page.app.iconName || ""
                Layout.alignment: Qt.AlignTop
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: LingmoUI.Units.smallSpacing

                Label {
                    text: page.app.name || ""
                    font.pointSize: LingmoUI.Theme.fontSize * 2
                    font.bold: true
                    color: LingmoUI.Theme.textColor
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    spacing: LingmoUI.Units.smallSpacing
                    Layout.fillWidth: true

                    Label {
                        visible: text !== ""
                        text: page.app.developer || ""
                        color: LingmoUI.Theme.highlightColor
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Badge {
                        visible: page.source === "flathub" && !!page.app.flathub && page.app.flathub.verified
                        text: qsTr("Verified")
                        tint: "#1f9d55"
                        filled: true
                        icon: "qrc:/icons/shield.svg"
                    }
                    Item { Layout.fillWidth: true }
                }

                Label {
                    text: page.app.summary || ""
                    color: LingmoUI.Theme.disabledTextColor
                    font.pointSize: LingmoUI.Theme.fontSize * 1.1
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }

            // Actions
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 230
                spacing: LingmoUI.Units.smallSpacing

                // Working on this app
                ColumnLayout {
                    visible: page.busyHere
                    spacing: LingmoUI.Units.smallSpacing
                    Layout.fillWidth: true

                    Label {
                        text: installer.statusText
                        color: LingmoUI.Theme.textColor
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    ProgressBar {
                        Layout.fillWidth: true
                        indeterminate: installer.progress < 0
                        value: Math.max(0, installer.progress)
                    }
                    ActionButton {
                        visible: installer.canCancel
                        text: qsTr("Cancel")
                        Layout.alignment: Qt.AlignRight
                        onClicked: installer.cancel()
                    }
                }

                RowLayout {
                    visible: !page.busyHere && page.found
                    spacing: LingmoUI.Units.smallSpacing
                    Layout.alignment: Qt.AlignRight

                    ActionButton {
                        visible: page.installed && !(page.source === "arch" && page.app.arch && page.app.arch.protected)
                        text: qsTr("Remove")
                        destructive: true
                        enabled: !installer.busy
                        onClicked: rootWindow.askRemove(page.appKey, page.source, page.app.name)
                    }
                    ActionButton {
                        visible: page.installed
                        primary: true
                        text: qsTr("Open")
                        onClicked: store.launch(page.appKey, page.source)
                    }
                    ActionButton {
                        visible: !page.installed
                        primary: true
                        implicitWidth: 150
                        text: qsTr("Install")
                        enabled: !installer.busy && !!page.src
                                 && (page.source === "flathub" || page.src.available)
                        onClicked: {
                            page.lastError = ""
                            installer.install(page.appKey, page.source)
                        }
                    }
                }

                Label {
                    visible: page.busyElsewhere
                    text: qsTr("Waiting for %1 to finish…").arg(installer.currentName)
                    color: LingmoUI.Theme.disabledTextColor
                    font.pointSize: LingmoUI.Theme.fontSize * 0.9
                    horizontalAlignment: Text.AlignRight
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
                Label {
                    visible: !page.busyHere && page.found && page.source !== ""
                    text: page.bothSources ? qsTr("From: %1").arg(page.sourceName(page.source))
                                           : page.source === "flathub" ? qsTr("From Flathub") : qsTr("From the Arch repositories")
                    color: LingmoUI.Theme.disabledTextColor
                    font.pointSize: LingmoUI.Theme.fontSize * 0.9
                    Layout.alignment: Qt.AlignRight
                }
            }
        }

        // What went wrong
        Rectangle {
            visible: page.lastError !== "" && !page.busyHere
            Layout.fillWidth: true
            implicitHeight: errorLayout.implicitHeight + LingmoUI.Units.largeSpacing * 2
            radius: LingmoUI.Theme.bigRadius
            color: Qt.rgba(LingmoUI.Theme.redColor.r, LingmoUI.Theme.redColor.g, LingmoUI.Theme.redColor.b,
                           LingmoUI.Theme.darkMode ? 0.2 : 0.1)

            ColumnLayout {
                id: errorLayout
                anchors.fill: parent
                anchors.margins: LingmoUI.Units.largeSpacing
                spacing: LingmoUI.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    LingmoUI.IconItem {
                        source: "dialog-error"
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                    }
                    Label {
                        text: page.lastError
                        color: LingmoUI.Theme.textColor
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                    Label {
                        visible: installer.log !== ""
                        text: page.showLog ? qsTr("Hide details") : qsTr("Details")
                        color: LingmoUI.Theme.highlightColor
                        font.bold: true
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.showLog = !page.showLog
                        }
                    }
                }
                LogView {
                    visible: page.showLog
                    text: installer.log
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                }
            }
        }

        // Native games that need the user's own game data
        Rectangle {
            visible: page.found && !!page.app.nativeGame && page.app.nativeGame.needsOwnCopy
            Layout.fillWidth: true
            implicitHeight: ownCopy.implicitHeight + LingmoUI.Units.largeSpacing * 2
            radius: LingmoUI.Theme.bigRadius
            color: Qt.rgba(LingmoUI.Theme.orangeColor.r, LingmoUI.Theme.orangeColor.g, LingmoUI.Theme.orangeColor.b,
                           LingmoUI.Theme.darkMode ? 0.16 : 0.1)

            RowLayout {
                id: ownCopy
                anchors.fill: parent
                anchors.margins: LingmoUI.Units.largeSpacing
                spacing: LingmoUI.Units.largeSpacing

                LingmoUI.IconItem {
                    source: "dialog-information"
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Label {
                        text: qsTr("You need your own copy of the game")
                        font.bold: true
                        color: LingmoUI.Theme.textColor
                    }
                    Label {
                        text: page.app.nativeGame ? page.app.nativeGame.note : ""
                        color: LingmoUI.Theme.textColor
                        opacity: 0.8
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }
                ActionButton {
                    text: qsTr("How does it work?")
                    onClicked: rootWindow.showOwnCopy({}, false)
                }
            }
        }

        // Where to install from
        ColumnLayout {
            visible: page.found && page.bothSources
            Layout.fillWidth: true
            spacing: LingmoUI.Units.largeSpacing

            Label {
                text: qsTr("Choose where to install from")
                font.bold: true
                color: LingmoUI.Theme.textColor
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: LingmoUI.Units.largeSpacing

                SourceOption {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    title: qsTr("Arch version")
                    text: qsTr("Integrated with the system and kept up to date with it by Updates.")
                    version: page.app.arch ? page.app.arch.version : ""
                    note: page.app.archOutdated ? qsTr("Older than the Flathub version.") : ""
                    selected: page.source === "arch"
                    recommended: page.app.recommended === "arch"
                    installed: !!page.app.arch && page.app.arch.installed
                    enabled: !page.busyHere
                    onClicked: page.chosen = "arch"
                }
                SourceOption {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    title: "Flathub"
                    text: qsTr("Straight from the developer and isolated from the system; often newer.")
                    version: page.app.flathub ? page.app.flathub.version : ""
                    selected: page.source === "flathub"
                    recommended: page.app.recommended === "flathub"
                    installed: !!page.app.flathub && page.app.flathub.installed
                    enabled: !page.busyHere
                    onClicked: page.chosen = "flathub"
                }
            }
        }

        // Screenshots
        ListView {
            id: shots
            visible: page.found && count > 0
            Layout.fillWidth: true
            Layout.preferredHeight: 300
            orientation: ListView.Horizontal
            spacing: LingmoUI.Units.largeSpacing
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: page.app.screenshots || []
            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Item {
                height: shots.height - 12
                width: Math.round(height * 16 / 10)

                Rectangle {
                    id: frame
                    anchors.fill: parent
                    radius: LingmoUI.Theme.bigRadius
                    color: LingmoUI.Theme.darkMode ? "#252528" : "#E9EAEE"
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: frame.width
                            height: frame.height
                            radius: frame.radius
                        }
                    }

                    Image {
                        id: shot
                        anchors.fill: parent
                        source: modelData.thumbnail
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                        mipmap: true
                    }

                    Spinner {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        running: shot.status === Image.Loading
                        visible: running
                    }
                    Label {
                        anchors.centerIn: parent
                        visible: shot.status === Image.Error
                        text: qsTr("Picture unavailable")
                        color: LingmoUI.Theme.disabledTextColor
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        viewer.shots = page.app.screenshots
                        viewer.index = index
                        viewer.open()
                    }
                }
            }

            LingmoUI.WheelHandler {
                target: shots
            }
        }

        // Description
        Card {
            visible: page.found && (page.app.description || "") !== ""
            Layout.fillWidth: true

            Label {
                text: qsTr("About this app")
                font.bold: true
                font.pointSize: LingmoUI.Theme.fontSize * 1.15
                color: LingmoUI.Theme.textColor
            }

            Item {
                id: descriptionBox
                Layout.fillWidth: true
                readonly property bool isLong: description.implicitHeight > 240
                implicitHeight: isLong && !page.descriptionExpanded ? 240 : description.implicitHeight
                clip: true

                Label {
                    id: description
                    width: parent.width
                    text: page.app.description || ""
                    textFormat: Text.RichText
                    wrapMode: Text.Wrap
                    color: LingmoUI.Theme.textColor
                    lineHeight: 1.15
                    onLinkActivated: (link) => store.openUrl(link)
                }

                Rectangle {
                    visible: descriptionBox.isLong && !page.descriptionExpanded
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 60
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: LingmoUI.Theme.secondBackgroundColor }
                    }
                }
            }

            Label {
                visible: descriptionBox.isLong
                text: page.descriptionExpanded ? qsTr("Show less") : qsTr("Show more")
                color: LingmoUI.Theme.highlightColor
                font.bold: true
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.descriptionExpanded = !page.descriptionExpanded
                }
            }
        }

        // Details
        Card {
            visible: page.found
            Layout.fillWidth: true

            Label {
                text: qsTr("Details")
                font.bold: true
                font.pointSize: LingmoUI.Theme.fontSize * 1.15
                color: LingmoUI.Theme.textColor
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: LingmoUI.Units.largeSpacing * 2
                rowSpacing: LingmoUI.Units.smallSpacing * 1.5

                Repeater {
                    model: [
                        { label: qsTr("Version"), value: page.src ? (page.src.version || qsTr("Unknown")) : "" },
                        { label: qsTr("Developer"), value: page.app.developer || qsTr("Unknown") },
                        { label: qsTr("License"), value: page.licenseText() },
                        { label: qsTr("Size"), value: page.sizeText() },
                        { label: qsTr("Source"), value: page.source === "arch"
                                    ? qsTr("Arch Linux repositories (%1)").arg(page.app.arch ? page.app.arch.repo || "local" : "")
                                    : page.source === "flathub" ? (page.app.flathub.verified ? qsTr("Flathub, verified developer") : "Flathub") : "" },
                        { label: qsTr("Package"), value: page.source === "arch" ? (page.app.arch ? page.app.arch.pkgname : "")
                                                                                : (page.app.flathub ? page.app.flathub.flatpakId : "") },
                    ]

                    delegate: RowLayout {
                        Layout.fillWidth: true
                        Layout.columnSpan: 1
                        spacing: LingmoUI.Units.largeSpacing

                        Label {
                            text: modelData.label
                            color: LingmoUI.Theme.disabledTextColor
                            Layout.preferredWidth: 110
                        }
                        Label {
                            text: modelData.value
                            color: LingmoUI.Theme.textColor
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                    }
                }

                RowLayout {
                    visible: (page.app.homepage || "") !== ""
                    Layout.fillWidth: true
                    spacing: LingmoUI.Units.largeSpacing

                    Label {
                        text: qsTr("Website")
                        color: LingmoUI.Theme.disabledTextColor
                        Layout.preferredWidth: 110
                    }
                    Label {
                        text: (page.app.homepage || "").replace(/^https?:\/\//, "").replace(/\/$/, "")
                        color: LingmoUI.Theme.highlightColor
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: store.openUrl(page.app.homepage)
                        }
                    }
                }
            }
        }
    }

    ScreenshotViewer {
        id: viewer
    }
}
