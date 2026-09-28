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

// A non-scrolling grid of app cards, for short lists inside a scrolling page
GridLayout {
    id: grid

    property var apps: []
    property int minimumCardWidth: 290
    signal appClicked(string key)

    columns: Math.max(1, Math.floor((width + columnSpacing) / (minimumCardWidth + columnSpacing)))
    columnSpacing: LingmoUI.Units.largeSpacing
    rowSpacing: LingmoUI.Units.largeSpacing

    Repeater {
        model: grid.apps

        AppCard {
            app: modelData
            Layout.fillWidth: true
            Layout.preferredWidth: grid.minimumCardWidth
            onClicked: grid.appClicked(modelData.key)
        }
    }
}
