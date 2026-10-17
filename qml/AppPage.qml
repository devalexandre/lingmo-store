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
    readonly property var rating: { reviews.revision; return reviews.rating(appKey) }
    readonly property var perms: { permissions.revision; return app.flathub ? permissions.forApp(app.flathub.flatpakId) : ({}) }
    readonly property string versionText: src ? (src.version || "") : ""
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
        loadExtras()
    }
    onFoundChanged: loadExtras()

    // Reviews and the sandbox permissions arrive later; the page never waits for them
    function loadExtras() {
        if (!found)
            return
        reviews.fetch(appKey)
        if (app.flathub)
            permissions.fetch(app.flathub.flatpakId, app.flathub.ref || "", !!app.flathub.installed)
    }

    function safetyText() {
        if (source === "arch") {
            const repo = app.arch ? (app.arch.repo || "") : ""
            return ["core", "extra", "multilib"].indexOf(repo) >= 0 ? qsTr("No sandbox · official repository")
                                                                     : qsTr("No sandbox")
        }
        if (source !== "flathub" || perms.state !== "ready")
            return ""
        return perms.level === "high" ? qsTr("Wide access, see below")
             : perms.level === "medium" ? qsTr("Isolated, some access")
             : qsTr("Isolated from the system")
    }
    function safetyColor() {
        if (source === "arch")
            return LingmoUI.Theme.secondaryTextColor
        return perms.level === "high" ? LingmoUI.Theme.errorColor
             : perms.level === "medium" ? LingmoUI.Theme.warningColor : LingmoUI.Theme.successColor
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
        LingmoUI.EmptyState {
            visible: !page.found
            Layout.fillWidth: true
            Layout.topMargin: 80
            busy: !catalog.ready
            iconName: "system-software-install"
            title: catalog.ready ? qsTr("This app was not found") : qsTr("Loading the app catalog…")
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
                    font.pointSize: LingmoUI.Units.fontTitle
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
                    LingmoUI.Badge {
                        visible: page.source === "flathub" && !!page.app.flathub && page.app.flathub.verified
                        text: qsTr("Verified")
                        tone: LingmoUI.Theme.successColor
                    }
                    Item { Layout.fillWidth: true }
                }

                Label {
                    text: page.app.summary || ""
                    color: LingmoUI.Theme.secondaryTextColor
                    font.pointSize: LingmoUI.Units.fontBody
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    visible: !!page.rating.count
                    spacing: LingmoUI.Units.smallSpacing

                    RatingStars {
                        size: 16
                        value: page.rating.average || 0
                    }
                    Label {
                        text: page.rating.count ? Number(page.rating.average).toLocaleString(Qt.locale(), 'f', 1) : ""
                        font.bold: true
                        color: LingmoUI.Theme.textColor
                    }
                    Label {
                        text: qsTr("%n rating(s)", "", page.rating.count || 0)
                        color: LingmoUI.Theme.secondaryTextColor
                    }
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
                    LingmoUI.ActionButton {
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

                    LingmoUI.ActionButton {
                        visible: page.installed && !(page.source === "arch" && page.app.arch && page.app.arch.protected)
                        text: qsTr("Remove")
                        destructive: true
                        subtle: true
                        enabled: !installer.busy
                        onClicked: rootWindow.askRemove(page.appKey, page.source, page.app.name)
                    }
                    LingmoUI.ActionButton {
                        visible: page.installed
                        primary: true
                        text: qsTr("Open")
                        onClicked: store.launch(page.appKey, page.source)
                    }
                    LingmoUI.ActionButton {
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
                    color: LingmoUI.Theme.secondaryTextColor
                    font.pointSize: LingmoUI.Units.fontCaption
                    horizontalAlignment: Text.AlignRight
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
                Label {
                    visible: !page.busyHere && page.found && page.source !== ""
                    text: page.bothSources ? qsTr("From: %1").arg(page.sourceName(page.source))
                                           : page.source === "flathub" ? qsTr("From Flathub") : qsTr("From the Arch repositories")
                    color: LingmoUI.Theme.secondaryTextColor
                    font.pointSize: LingmoUI.Units.fontCaption
                    Layout.alignment: Qt.AlignRight
                }
                // How isolated it is, next to the button that installs it
                RowLayout {
                    visible: !page.busyHere && page.found && page.safetyText() !== ""
                    Layout.alignment: Qt.AlignRight
                    spacing: 4

                    LingmoUI.IconItem {
                        source: "qrc:/icons/shield.svg"
                        color: page.safetyColor()
                        Layout.preferredWidth: 14
                        Layout.preferredHeight: 14
                    }
                    Label {
                        text: page.safetyText()
                        color: page.safetyColor()
                        font.pointSize: LingmoUI.Units.fontCaption
                        font.bold: page.source === "flathub" && page.perms.level === "high"
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignRight
                        Layout.maximumWidth: 200
                    }
                }
            }
        }

        // What went wrong
        ColumnLayout {
            visible: page.lastError !== "" && !page.busyHere
            Layout.fillWidth: true
            spacing: LingmoUI.Units.smallSpacing

            LingmoUI.Banner {
                Layout.fillWidth: true
                type: LingmoUI.Banner.Error
                closable: false
                text: page.lastError

                LingmoUI.ActionButton {
                    visible: installer.log !== ""
                    text: page.showLog ? qsTr("Hide details") : qsTr("Details")
                    onClicked: page.showLog = !page.showLog
                }
            }
            LogView {
                visible: page.showLog
                text: installer.log
                Layout.fillWidth: true
                Layout.preferredHeight: 200
            }
        }

        // Native games that need the user's own game data
        LingmoUI.Banner {
            visible: page.found && !!page.app.nativeGame && page.app.nativeGame.needsOwnCopy
            Layout.fillWidth: true
            type: LingmoUI.Banner.Warning
            closable: false
            iconName: "dialog-information"
            title: qsTr("You need your own copy of the game")
            text: page.app.nativeGame ? page.app.nativeGame.note : ""

            LingmoUI.ActionButton {
                text: qsTr("How does it work?")
                onClicked: rootWindow.showOwnCopy({}, false)
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
                font.pointSize: LingmoUI.Units.fontSubheading
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

        // Before installing: what it can reach
        PermissionsCard {
            visible: page.found && (page.source === "flathub" || page.source === "arch")
            Layout.fillWidth: true
            source: page.source
            app: page.app
            info: page.perms
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
                    color: LingmoUI.Theme.secondBackgroundColor
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

                    LingmoUI.Spinner {
                        anchors.centerIn: parent
                        size: 28
                        running: shot.status === Image.Loading
                    }
                    Label {
                        anchors.centerIn: parent
                        visible: shot.status === Image.Error
                        text: qsTr("Picture unavailable")
                        color: LingmoUI.Theme.secondaryTextColor
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
        LingmoUI.Card {
            id: card1
            visible: page.found && (page.app.description || "") !== ""
            Layout.fillWidth: true
            implicitHeight: card1Content.implicitHeight + padding * 2

            ColumnLayout {
                id: card1Content
                anchors.fill: parent
                anchors.margins: card1.padding
                spacing: LingmoUI.Units.largeSpacing

                Label {
                    text: qsTr("About this app")
                    font.bold: true
                    font.pointSize: LingmoUI.Units.fontSubheading
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
        }

        ReviewsCard {
            visible: page.found
            Layout.fillWidth: true
            appKey: page.appKey
            appName: page.app.name || ""
            installed: page.installed
            onWriteReview: reviewDialog.openFor(page.appKey, page.app.name || "", page.versionText)
        }

        // Details
        LingmoUI.Card {
            id: card2
            visible: page.found
            Layout.fillWidth: true
            implicitHeight: card2Content.implicitHeight + padding * 2

            ColumnLayout {
                id: card2Content
                anchors.fill: parent
                anchors.margins: card2.padding
                spacing: LingmoUI.Units.largeSpacing

                Label {
                    text: qsTr("Details")
                    font.bold: true
                    font.pointSize: LingmoUI.Units.fontSubheading
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
                                color: LingmoUI.Theme.secondaryTextColor
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
                            color: LingmoUI.Theme.secondaryTextColor
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
    }

    ScreenshotViewer {
        id: viewer
    }

    ReviewDialog {
        id: reviewDialog
    }
}
