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

// Screenshots in full size, over the window
Popup {
    id: control

    property var shots: []
    property int index: 0

    parent: Overlay.overlay
    x: 0
    y: 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    background: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.82)
        radius: rootWindow.windowRadius
    }

    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: LingmoUI.Units.shortDuration } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: LingmoUI.Units.veryShortDuration } }

    contentItem: Item {
        focus: true
        Keys.onLeftPressed: control.index = Math.max(0, control.index - 1)
        Keys.onRightPressed: control.index = Math.min(control.shots.length - 1, control.index + 1)

        MouseArea {
            anchors.fill: parent
            onClicked: control.close()
        }

        Image {
            id: image
            anchors.fill: parent
            anchors.margins: 64
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            source: control.shots.length > 0 ? control.shots[control.index].source : ""
            smooth: true
            mipmap: true
        }

        LingmoUI.Spinner {
            anchors.centerIn: parent
            running: image.status === Image.Loading
            size: 40
        }

        Label {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24
            anchors.horizontalCenter: parent.horizontalCenter
            text: control.shots.length > 0 ? (control.shots[control.index].caption || "") : ""
            color: "white"
            visible: text !== ""
        }

        Repeater {
            model: [
                { dx: -1, glyph: "‹" },
                { dx: 1, glyph: "›" },
            ]
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: modelData.dx < 0 ? 16 : parent.width - width - 16
                width: 40
                height: 40
                radius: 20
                color: Qt.rgba(1, 1, 1, arrowMouse.containsMouse ? 0.3 : 0.15)
                Behavior on color { ColorAnimation { duration: LingmoUI.Units.veryShortDuration } }
                visible: modelData.dx < 0 ? control.index > 0 : control.index < control.shots.length - 1

                Label {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -2
                    text: modelData.glyph
                    color: "white"
                    font.pointSize: LingmoUI.Units.fontTitle
                }
                MouseArea {
                    id: arrowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: control.index = Math.max(0, Math.min(control.shots.length - 1, control.index + modelData.dx))
                }
            }
        }

        Label {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 20
            text: "✕"
            color: "white"
            font.pointSize: LingmoUI.Units.fontHeading

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                onClicked: control.close()
            }
        }
    }
}
