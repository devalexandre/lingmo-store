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
import LingmoUI.CompatibleModule 3.0 as LingmoUI

Flickable {
    id: page

    readonly property string pageName: "installed"
    readonly property var apps: { rootWindow.rev; return catalog.installedApps() }
    readonly property int margin: LingmoUI.Units.largeSpacing * 2

    // One row per app and source (an app can be installed from both)
    readonly property var natives: { rootWindow.rev; return catalog.nativeGames() }
    readonly property var rows: {
        const list = []
        for (const game of natives) {
            if (game.source === "archlingmo" && game.installed)
                list.push({ app: { key: game.key, name: game.name, summary: game.console + " · " + game.project,
                                   iconUrl: "", iconName: "applications-games", size: "" },
                            source: "archlingmo", pkg: game.pkg })
        }
        for (const app of apps) {
            if (app.installedArch)
                list.push({ app: app, source: "arch" })
            if (app.installedFlathub)
                list.push({ app: app, source: "flathub" })
        }
        return list
    }

    contentWidth: width
    contentHeight: column.implicitHeight + margin * 2
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}

    LingmoUI.WheelHandler {
        target: page
    }

    ColumnLayout {
        id: column
        x: page.margin
        y: LingmoUI.Units.smallSpacing
        width: page.width - page.margin * 2
        spacing: LingmoUI.Units.largeSpacing

        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true

            Label {
                text: qsTr("Installed")
                font.pointSize: LingmoUI.Theme.fontSize * 1.6
                font.bold: true
                color: LingmoUI.Theme.textColor
            }
            Label {
                text: catalog.ready ? qsTr("%n app(s) on this computer", "", page.rows.length) : qsTr("Loading…")
                color: LingmoUI.Theme.disabledTextColor
            }
        }

        // Updates live in their own app
        Card {
            Layout.fillWidth: true

            RowLayout {
                Layout.fillWidth: true
                spacing: LingmoUI.Units.largeSpacing

                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: 10
                    color: "#FF9F0A"
                    Image {
                        anchors.centerIn: parent
                        source: "qrc:/icons/updates.svg"
                        width: 20
                        height: 20
                        sourceSize: Qt.size(40, 40)
                    }
                }
                Label {
                    text: qsTr("Updates for all your apps and the system are installed by the Updates app.")
                    color: LingmoUI.Theme.textColor
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
                ActionButton {
                    text: qsTr("Open Updates")
                    onClicked: store.openUpdater()
                }
            }
        }

        Rectangle {
            visible: page.rows.length > 0
            Layout.fillWidth: true
            implicitHeight: list.implicitHeight + LingmoUI.Units.smallSpacing * 2
            radius: LingmoUI.Theme.bigRadius
            color: LingmoUI.Theme.secondBackgroundColor

            ColumnLayout {
                id: list
                anchors.fill: parent
                anchors.margins: LingmoUI.Units.smallSpacing
                spacing: 0

                Repeater {
                    model: page.rows

                    delegate: Rectangle {
                        id: row
                        Layout.fillWidth: true
                        implicitHeight: 64
                        radius: LingmoUI.Theme.mediumRadius
                        color: rowMouse.containsMouse ? LingmoUI.Theme.alternateBackgroundColor : "transparent"

                        readonly property var app: modelData.app
                        readonly property bool busy: installer.busy && installer.currentKey === app.key
                                                     && (installer.currentSource === modelData.source
                                                         || modelData.source === "archlingmo")

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (modelData.source !== "archlingmo") rootWindow.openApp(row.app.key)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: LingmoUI.Units.largeSpacing
                            anchors.rightMargin: LingmoUI.Units.largeSpacing
                            spacing: LingmoUI.Units.largeSpacing

                            AppIcon {
                                size: 40
                                source: row.app.iconUrl || ""
                                iconName: row.app.iconName || ""
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Label {
                                    text: row.app.name
                                    font.bold: true
                                    color: LingmoUI.Theme.textColor
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Label {
                                    text: row.busy ? installer.statusText : row.app.summary
                                    color: LingmoUI.Theme.disabledTextColor
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Label {
                                visible: modelData.source === "arch" && (row.app.size || "") !== ""
                                text: row.app.size || ""
                                color: LingmoUI.Theme.disabledTextColor
                            }

                            Badge {
                                text: modelData.source === "flathub" ? "Flathub" : modelData.source === "archlingmo" ? "ArchLingmo" : "Arch"
                                tint: modelData.source === "flathub" ? "#4A86CF" : "#1793D1"
                            }

                            ProgressBar {
                                visible: row.busy
                                Layout.preferredWidth: 120
                                indeterminate: installer.progress < 0
                                value: Math.max(0, installer.progress)
                            }

                            ActionButton {
                                visible: !row.busy
                                text: qsTr("Open")
                                onClicked: modelData.source === "archlingmo" ? store.launchPackage(modelData.pkg)
                                                                             : store.launch(row.app.key, modelData.source)
                            }

                            ActionButton {
                                visible: !row.busy && !(modelData.source === "arch" && row.app.protected)
                                text: qsTr("Remove")
                                destructive: true
                                enabled: !installer.busy
                                onClicked: modelData.source === "archlingmo" ? rootWindow.askRemovePackage(modelData.pkg, row.app.name)
                                                                             : rootWindow.askRemove(row.app.key, modelData.source, row.app.name)
                            }
                        }
                    }
                }
            }
        }

        // Nothing yet
        ColumnLayout {
            visible: catalog.ready && page.rows.length === 0
            Layout.fillWidth: true
            Layout.topMargin: 60
            spacing: LingmoUI.Units.largeSpacing

            Label {
                text: qsTr("No apps installed from the store yet")
                font.pointSize: LingmoUI.Theme.fontSize * 1.2
                font.bold: true
                color: LingmoUI.Theme.textColor
                Layout.alignment: Qt.AlignHCenter
            }
            ActionButton {
                primary: true
                text: qsTr("Discover apps")
                Layout.alignment: Qt.AlignHCenter
                onClicked: rootWindow.showHome()
            }
        }
    }
}
