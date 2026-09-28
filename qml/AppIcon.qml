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

// An app's icon: the catalog's picture, else the icon theme, else a generic one
Item {
    id: control

    property string source: ""
    property string iconName: ""
    property int size: 64

    implicitWidth: size
    implicitHeight: size

    Image {
        id: image
        anchors.fill: parent
        source: control.source
        sourceSize: Qt.size(control.size * 2, control.size * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
        visible: status === Image.Ready
    }

    LingmoUI.IconItem {
        anchors.fill: parent
        visible: image.status !== Image.Ready
        source: control.iconName !== "" && store.hasThemeIcon(control.iconName) ? control.iconName : "application-x-executable"
        opacity: image.status === Image.Loading ? 0.25 : 1
        smooth: true
    }
}
