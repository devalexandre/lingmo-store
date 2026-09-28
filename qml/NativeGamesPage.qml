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
                    font.pointSize: LingmoUI.Theme.fontSize * 1.6
                    font.bold: true
                    color: LingmoUI.Theme.textColor
                }
                Label {
                    text: qsTr("Classic games rebuilt as native Linux programs by fan projects")
                    color: LingmoUI.Theme.disabledTextColor
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }
        }

        // Bring your own game
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: info.implicitHeight + LingmoUI.Units.largeSpacing * 2.5
            radius: LingmoUI.Theme.bigRadius
            color: Qt.rgba(LingmoUI.Theme.orangeColor.r, LingmoUI.Theme.orangeColor.g, LingmoUI.Theme.orangeColor.b,
                           LingmoUI.Theme.darkMode ? 0.16 : 0.1)

            RowLayout {
                id: info
                anchors.fill: parent
                anchors.margins: LingmoUI.Units.largeSpacing * 1.25
                spacing: LingmoUI.Units.largeSpacing

                LingmoUI.IconItem {
                    source: "dialog-information"
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignTop
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Label {
                        text: qsTr("The programs are free. The games are yours.")
                        font.bold: true
                        color: LingmoUI.Theme.textColor
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }
                    Label {
                        text: qsTr("Most of these need the data of a game you own, such as a copy of your own cartridge. The store never includes or downloads game data.")
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
