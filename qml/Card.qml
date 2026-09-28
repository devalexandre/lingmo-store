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
import QtQuick.Layouts
import LingmoUI.CompatibleModule 3.0 as LingmoUI

// A rounded panel, like Lingmo Settings' RoundedItem
Rectangle {
    id: control

    default property alias content: _layout.data
    property alias spacing: _layout.spacing
    property real padding: LingmoUI.Units.largeSpacing * 1.5

    color: LingmoUI.Theme.secondBackgroundColor
    radius: LingmoUI.Theme.bigRadius
    implicitHeight: _layout.implicitHeight + padding * 2
    border.width: LingmoUI.Theme.darkMode ? 0 : 1
    border.color: Qt.rgba(0, 0, 0, 0.05)

    Behavior on color { ColorAnimation { duration: 200 } }

    ColumnLayout {
        id: _layout
        anchors.fill: parent
        anchors.margins: control.padding
        spacing: LingmoUI.Units.largeSpacing
    }
}
