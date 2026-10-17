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

// A game of the "Native games" collection
LingmoUI.Card {
    id: control

    property var game: ({})
    readonly property bool flathub: game.source === "flathub"
    readonly property bool busy: installer.busy && installer.currentKey === game.key

    implicitHeight: 158
    radius: LingmoUI.Theme.bigRadius
    // Flathub games open their app page
    clickable: control.flathub
    liftOnHover: true
    onClicked: rootWindow.openApp(control.game.key)

    // Console tile colours (illustration, not theme)
    function consoleColor(name) {
        if (name.indexOf("64") >= 0) return "#D83A34"
        if (name.indexOf("Super Nintendo") >= 0) return "#6D5BD0"
        if (name.indexOf("Mega Drive") >= 0) return "#1E6FD9"
        return "#546E7A"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: LingmoUI.Units.largeSpacing * 1.25
        spacing: LingmoUI.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: LingmoUI.Units.largeSpacing

            Item {
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52

                AppIcon {
                    anchors.fill: parent
                    size: 52
                    visible: control.flathub
                    source: control.game.iconUrl || ""
                    iconName: control.game.iconName || ""
                }

                Rectangle {
                    id: consoleTile
                    anchors.fill: parent
                    visible: !control.flathub
                    radius: 13
                    readonly property color tint: control.consoleColor(control.game.console || "")
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.lighter(consoleTile.tint, 1.2) }
                        GradientStop { position: 1.0; color: consoleTile.tint }
                    }

                    Image {
                        anchors.centerIn: parent
                        source: "qrc:/icons/native.svg"
                        width: 28
                        height: 28
                        sourceSize: Qt.size(56, 56)
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Label {
                    text: control.game.name || ""
                    font.bold: true
                    font.pointSize: LingmoUI.Units.fontBody
                    color: LingmoUI.Theme.textColor
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Label {
                    text: (control.game.console || "") + "  ·  " + (control.game.project || "")
                    color: LingmoUI.Theme.secondaryTextColor
                    font.pointSize: LingmoUI.Units.fontCaption
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        Label {
            text: control.busy ? installer.statusText : (control.game.note || "")
            color: LingmoUI.Theme.secondaryTextColor
            font.pointSize: LingmoUI.Units.fontCaption
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Item { Layout.fillHeight: true }

        ProgressBar {
            visible: control.busy
            Layout.fillWidth: true
            indeterminate: installer.progress < 0
            value: Math.max(0, installer.progress)
        }

        RowLayout {
            visible: !control.busy
            Layout.fillWidth: true
            spacing: 4

            LingmoUI.Badge {
                visible: !!control.game.needsOwnCopy
                text: qsTr("Needs your copy")
                tone: LingmoUI.Theme.warningColor
                iconName: "dialog-information-symbolic"

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: rootWindow.showOwnCopy(control.game, false)
                }
            }
            LingmoUI.Badge {
                visible: control.flathub
                text: "Flathub"
                subtle: true
            }
            LingmoUI.Badge {
                visible: !control.flathub && control.game.available
                text: "ArchLingmo"
                subtle: true
            }
            LingmoUI.Badge {
                visible: !control.flathub && !control.game.available
                text: qsTr("Coming soon")
                subtle: true
            }

            Item { Layout.fillWidth: true }

            LingmoUI.ActionButton {
                visible: control.flathub
                implicitHeight: LingmoUI.Units.smallControlHeight
                text: control.game.installed ? qsTr("Open") : qsTr("See")
                onClicked: {
                    if (control.game.installed)
                        store.launch(control.game.key, "flathub")
                    else
                        rootWindow.openApp(control.game.key)
                }
            }
            LingmoUI.ActionButton {
                visible: !control.flathub && control.game.available
                implicitHeight: LingmoUI.Units.smallControlHeight
                primary: !control.game.installed
                enabled: control.game.installed || !installer.busy
                text: control.game.installed ? qsTr("Open") : qsTr("Install")
                onClicked: {
                    if (control.game.installed)
                        store.launchPackage(control.game.pkg)
                    else
                        rootWindow.installNative(control.game)
                }
            }
        }
    }
}
