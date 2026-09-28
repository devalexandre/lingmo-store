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
import LingmoUI.CompatibleModule 3.0 as LingmoUI

// Small colored pill: "Flathub", "Arch", "Installed"…
Rectangle {
    id: control

    property alias text: label.text
    property color tint: LingmoUI.Theme.highlightColor
    property bool filled: false
    property string icon: ""

    implicitWidth: row.implicitWidth + 14
    implicitHeight: 20
    radius: height / 2
    color: filled ? tint : Qt.rgba(tint.r, tint.g, tint.b, LingmoUI.Theme.darkMode ? 0.22 : 0.13)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 3

        Image {
            visible: control.icon !== ""
            source: control.icon
            width: 11
            height: 11
            sourceSize: Qt.size(22, 22)
            anchors.verticalCenter: parent.verticalCenter
        }

        Label {
            id: label
            font.pointSize: LingmoUI.Theme.fontSize * 0.78
            font.bold: true
            color: control.filled ? "white" : (LingmoUI.Theme.darkMode ? Qt.lighter(control.tint, 1.35) : Qt.darker(control.tint, 1.15))
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
