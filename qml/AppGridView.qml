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

// A scrolling, virtualized grid of app cards (categories, search results)
GridView {
    id: view

    property int minimumCardWidth: 290
    property int margin: LingmoUI.Units.largeSpacing * 2
    signal appClicked(string key)

    readonly property int columns: Math.max(1, Math.floor((width - margin * 2) / minimumCardWidth))
    cellWidth: Math.floor((width - margin * 2) / columns)
    cellHeight: 104 + LingmoUI.Units.largeSpacing
    leftMargin: margin
    rightMargin: margin
    bottomMargin: margin
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    cacheBuffer: 600
    ScrollBar.vertical: ScrollBar {}

    delegate: Item {
        width: view.cellWidth
        height: view.cellHeight

        AppCard {
            anchors.fill: parent
            anchors.rightMargin: LingmoUI.Units.largeSpacing
            anchors.bottomMargin: LingmoUI.Units.largeSpacing
            app: modelData
            onClicked: view.appClicked(modelData.key)
        }
    }

    LingmoUI.WheelHandler {
        target: view
    }
}
