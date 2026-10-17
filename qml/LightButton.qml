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
import LingmoUI.CompatibleModule 3.0 as LingmoUI

// LingmoUI.ActionButton drawn white with dark text, for the coloured
// banners (hero, games teaser). The shared button has no such variant.
LingmoUI.ActionButton {
    id: control

    font.weight: Font.DemiBold

    contentItem: Text {
        text: control.text
        font: control.font
        color: "#1d1d22"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        renderType: LingmoUI.Theme.renderType
    }

    background: Rectangle {
        implicitHeight: LingmoUI.Units.controlHeight
        implicitWidth: LingmoUI.Units.controlHeight * 2
        radius: LingmoUI.Theme.smallRadius
        color: control.down ? Qt.darker("white", 1.12) : control.hovered ? Qt.darker("white", 1.05) : "white"
        Behavior on color { ColorAnimation { duration: LingmoUI.Units.veryShortDuration } }
    }
}
