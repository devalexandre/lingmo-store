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
import Qt5Compat.GraphicalEffects
import LingmoUI.CompatibleModule 3.0 as LingmoUI

// Five stars filled up to `value` (0–5, fractions allowed). With `interactive`,
// hovering and clicking picks a value (picked()).
Row {
    id: control

    property real value: 0
    property int size: 14
    property bool interactive: false
    property int count: 5
    property int hoverValue: 0
    signal picked(int stars)

    readonly property real shown: hoverValue > 0 ? hoverValue : value

    spacing: Math.max(1, Math.round(size / 8))

    Repeater {
        model: control.count

        Item {
            width: control.size
            height: control.size
            readonly property real fill: Math.max(0, Math.min(1, control.shown - index))

            Image {
                id: shape
                anchors.fill: parent
                source: "qrc:/icons/star.svg"
                sourceSize: Qt.size(control.size * 2, control.size * 2)
                visible: false
            }
            ColorOverlay {
                anchors.fill: parent
                source: shape
                color: LingmoUI.Theme.disabledTextColor
                opacity: 0.35
            }
            Item {
                width: parent.width * parent.fill
                height: parent.height
                clip: true

                ColorOverlay {
                    width: control.size
                    height: control.size
                    source: shape
                    color: LingmoUI.Theme.orangeColor
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: control.interactive
                hoverEnabled: control.interactive
                cursorShape: control.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
                onEntered: control.hoverValue = index + 1
                onExited: control.hoverValue = 0
                onClicked: control.picked(index + 1)
            }
        }
    }
}
