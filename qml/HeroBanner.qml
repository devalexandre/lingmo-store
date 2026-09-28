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

// The rotating banner at the top of the home page
Item {
    id: control

    property var heroes: []
    property int current: 0
    readonly property var hero: heroes.length > 0 ? heroes[Math.min(current, heroes.length - 1)] : null

    implicitHeight: 232
    visible: heroes.length > 0

    Timer {
        interval: 8000
        repeat: true
        running: control.heroes.length > 1 && control.visible && !hover.hovered
        onTriggered: control.current = (control.current + 1) % control.heroes.length
    }

    HoverHandler {
        id: hover
    }

    Rectangle {
        id: banner
        anchors.fill: parent
        radius: LingmoUI.Theme.hugeRadius + 4
        clip: true
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: control.hero && control.hero.colors ? control.hero.colors[0] : LingmoUI.Theme.highlightColor
                Behavior on color { ColorAnimation { duration: 450 } }
            }
            GradientStop {
                position: 1.0
                color: control.hero && control.hero.colors ? control.hero.colors[1] : Qt.darker(LingmoUI.Theme.highlightColor, 1.3)
                Behavior on color { ColorAnimation { duration: 450 } }
            }
        }

        // Soft decorative circles
        Rectangle {
            width: banner.height * 1.4
            height: width
            radius: width / 2
            x: banner.width - width * 0.62
            y: -height * 0.35
            color: Qt.rgba(1, 1, 1, 0.07)
        }
        Rectangle {
            width: banner.height * 0.9
            height: width
            radius: width / 2
            x: banner.width - width * 1.35
            y: banner.height - height * 0.45
            color: Qt.rgba(1, 1, 1, 0.05)
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (control.hero) rootWindow.openApp(control.hero.key)
        }

        RowLayout {
            id: content
            anchors.fill: parent
            anchors.leftMargin: LingmoUI.Units.largeSpacing * 3
            anchors.rightMargin: LingmoUI.Units.largeSpacing * 4
            spacing: LingmoUI.Units.largeSpacing * 2

            opacity: 1
            Behavior on opacity { NumberAnimation { duration: 180 } }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: LingmoUI.Units.smallSpacing * 1.5

                Label {
                    text: control.hero ? control.hero.name : ""
                    color: Qt.rgba(1, 1, 1, 0.75)
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.2
                    font.pointSize: LingmoUI.Theme.fontSize * 0.9
                }
                Label {
                    text: control.hero ? control.hero.title : ""
                    color: "white"
                    font.bold: true
                    font.pointSize: LingmoUI.Theme.fontSize * 2.1
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
                Label {
                    text: control.hero ? control.hero.text : ""
                    color: Qt.rgba(1, 1, 1, 0.88)
                    font.pointSize: LingmoUI.Theme.fontSize * 1.05
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    Layout.maximumWidth: 520
                }
                ActionButton {
                    light: true
                    text: control.hero && control.hero.installed ? qsTr("Open") : qsTr("See App")
                    Layout.topMargin: LingmoUI.Units.smallSpacing
                    onClicked: rootWindow.openApp(control.hero.key)
                }
            }

            AppIcon {
                size: 144
                source: control.hero ? control.hero.iconUrl : ""
                iconName: control.hero ? control.hero.iconName : ""
                Layout.alignment: Qt.AlignVCenter
                visible: control.width > 620
            }
        }

        // Page dots
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: LingmoUI.Units.largeSpacing
            spacing: 6
            visible: control.heroes.length > 1

            Repeater {
                model: control.heroes.length
                Rectangle {
                    width: index === control.current ? 18 : 7
                    height: 7
                    radius: 3.5
                    color: index === control.current ? "white" : Qt.rgba(1, 1, 1, 0.45)
                    Behavior on width { NumberAnimation { duration: 180 } }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: control.current = index
                    }
                }
            }
        }
    }
}
