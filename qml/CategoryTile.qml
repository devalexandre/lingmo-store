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

// A colored category tile on the home page
Rectangle {
    id: control

    property string name: ""
    property string title: ""
    property string iconSource: ""
    property color tint: LingmoUI.Theme.highlightColor

    implicitHeight: 72
    radius: LingmoUI.Theme.bigRadius
    // Lighter while hovered
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop {
            position: 0.0
            color: Qt.lighter(control.tint, mouse.containsMouse ? 1.28 : 1.15)
            Behavior on color { ColorAnimation { duration: LingmoUI.Units.shortDuration; easing.type: LingmoUI.Units.easing } }
        }
        GradientStop {
            position: 1.0
            color: mouse.containsMouse ? Qt.lighter(control.tint, 1.08) : control.tint
            Behavior on color { ColorAnimation { duration: LingmoUI.Units.shortDuration; easing.type: LingmoUI.Units.easing } }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: rootWindow.showCategory(control.name)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: LingmoUI.Units.largeSpacing * 1.5
        anchors.rightMargin: LingmoUI.Units.largeSpacing
        spacing: LingmoUI.Units.largeSpacing

        Image {
            source: control.iconSource
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            sourceSize: Qt.size(56, 56)
        }

        Label {
            text: control.title
            color: LingmoUI.Theme.highlightedTextColor
            font.bold: true
            font.pointSize: LingmoUI.Units.fontSubheading
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
