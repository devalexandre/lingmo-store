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

// Title of a section of a page, with an optional link on the right
RowLayout {
    id: control

    property alias text: title.text
    property alias subtitle: sub.text
    property string actionText: ""
    signal actionClicked()

    spacing: LingmoUI.Units.largeSpacing
    Layout.fillWidth: true
    Layout.topMargin: LingmoUI.Units.largeSpacing

    ColumnLayout {
        spacing: 1
        Layout.fillWidth: true

        Label {
            id: title
            font.pointSize: LingmoUI.Units.fontHeading
            font.bold: true
            color: LingmoUI.Theme.textColor
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        Label {
            id: sub
            visible: text !== ""
            color: LingmoUI.Theme.secondaryTextColor
            Layout.fillWidth: true
            wrapMode: Text.Wrap
        }
    }

    Label {
        visible: control.actionText !== ""
        text: control.actionText
        color: LingmoUI.Theme.highlightColor
        font.bold: true
        Layout.alignment: Qt.AlignBottom

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: control.actionClicked()
        }
    }
}
