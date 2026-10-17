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

// "Native games": classic games rebuilt as native programs by fan projects
Flickable {
    id: page

    readonly property string pageName: "native"
    readonly property int margin: LingmoUI.Units.largeSpacing * 2
    readonly property var games: { rootWindow.rev; return catalog.nativeGames() }

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
        spacing: LingmoUI.Units.largeSpacing * 1.5

        RowLayout {
            Layout.fillWidth: true
            spacing: LingmoUI.Units.largeSpacing

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 11
                // Same tile colour as "Native games" in the sidebar
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter("#E0457B", 1.15) }
                    GradientStop { position: 1.0; color: "#E0457B" }
                }
                Image {
                    anchors.centerIn: parent
                    source: "qrc:/icons/native.svg"
                    width: 22
                    height: 22
                    sourceSize: Qt.size(44, 44)
                }
            }

            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true

                Label {
                    text: qsTr("Native games")
                    font.pointSize: LingmoUI.Units.fontTitle
                    font.bold: true
                    color: LingmoUI.Theme.textColor
                }
                Label {
                    text: qsTr("Classic games rebuilt as native Linux programs by fan projects")
                    color: LingmoUI.Theme.secondaryTextColor
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }
        }

        // Bring your own game
        LingmoUI.Banner {
            Layout.fillWidth: true
            type: LingmoUI.Banner.Warning
            closable: false
            iconName: "dialog-information"
            title: qsTr("The programs are free. The games are yours.")
            text: qsTr("Most of these need the data of a game you own, such as a copy of your own cartridge. The store never includes or downloads game data.")

            LingmoUI.ActionButton {
                text: qsTr("How does it work?")
                onClicked: rootWindow.showOwnCopy({}, false)
            }
        }

        GridLayout {
            id: grid
            Layout.fillWidth: true
            columns: Math.max(1, Math.floor((width + columnSpacing) / (300 + columnSpacing)))
            columnSpacing: LingmoUI.Units.largeSpacing
            rowSpacing: LingmoUI.Units.largeSpacing

            Repeater {
                model: page.games

                NativeGameCard {
                    game: modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 300
                }
            }
        }
    }
}
