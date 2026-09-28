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

// One of the two places an app can come from, as a selectable card
Rectangle {
    id: control

    property string title: ""
    property string text: ""
    property string version: ""
    property string note: ""
    property bool selected: false
    property bool recommended: false
    property bool installed: false
    signal clicked()

    implicitHeight: layout.implicitHeight + LingmoUI.Units.largeSpacing * 2.5
    radius: LingmoUI.Theme.bigRadius
    color: selected ? Qt.rgba(LingmoUI.Theme.highlightColor.r, LingmoUI.Theme.highlightColor.g,
                              LingmoUI.Theme.highlightColor.b, LingmoUI.Theme.darkMode ? 0.18 : 0.08)
                    : LingmoUI.Theme.secondBackgroundColor
    border.width: selected ? 2 : 1
    border.color: selected ? LingmoUI.Theme.highlightColor
                           : (LingmoUI.Theme.darkMode ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.08))

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: control.clicked()
    }

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: LingmoUI.Units.largeSpacing * 1.25
        spacing: LingmoUI.Units.largeSpacing

        // Radio mark
        Rectangle {
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 2
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            radius: 9
            color: "transparent"
            border.width: 2
            border.color: control.selected ? LingmoUI.Theme.highlightColor : LingmoUI.Theme.disabledTextColor

            Rectangle {
                anchors.centerIn: parent
                width: 8
                height: 8
                radius: 4
                visible: control.selected
                color: LingmoUI.Theme.highlightColor
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            RowLayout {
                spacing: LingmoUI.Units.smallSpacing
                Layout.fillWidth: true

                Label {
                    text: control.title
                    font.bold: true
                    color: LingmoUI.Theme.textColor
                }
                Badge {
                    visible: control.recommended
                    text: qsTr("Recommended")
                    tint: LingmoUI.Theme.highlightColor
                }
                Badge {
                    visible: control.installed
                    text: qsTr("Installed")
                    tint: LingmoUI.Theme.greenColor
                }
                Item { Layout.fillWidth: true }
            }
            Label {
                text: control.text
                color: LingmoUI.Theme.disabledTextColor
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            Label {
                visible: control.version !== ""
                text: qsTr("Version %1").arg(control.version)
                color: LingmoUI.Theme.disabledTextColor
                font.pointSize: LingmoUI.Theme.fontSize * 0.9
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Label {
                visible: control.note !== ""
                text: control.note
                color: LingmoUI.Theme.orangeColor
                font.pointSize: LingmoUI.Theme.fontSize * 0.9
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }
    }
}
