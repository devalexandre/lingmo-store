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

Item {
    id: page

    readonly property string pageName: "category"
    property string category: ""
    property string title: ""
    property color tint: LingmoUI.Theme.highlightColor
    readonly property var apps: { rootWindow.rev; return catalog.category(category) }

    ColumnLayout {
        anchors.fill: parent
        spacing: LingmoUI.Units.largeSpacing

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: LingmoUI.Units.largeSpacing * 2
            Layout.rightMargin: LingmoUI.Units.largeSpacing * 2
            Layout.topMargin: LingmoUI.Units.smallSpacing
            spacing: LingmoUI.Units.largeSpacing

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 11
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(page.tint, 1.15) }
                    GradientStop { position: 1.0; color: page.tint }
                }
                Image {
                    anchors.centerIn: parent
                    readonly property var info: sideBar.categoryInfo(page.category)
                    source: info ? "qrc:/icons/" + info.iconSource : ""
                    width: 22
                    height: 22
                    sourceSize: Qt.size(44, 44)
                }
            }

            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true

                Label {
                    text: page.title
                    font.pointSize: LingmoUI.Theme.fontSize * 1.6
                    font.bold: true
                    color: LingmoUI.Theme.textColor
                }
                Label {
                    text: catalog.ready ? qsTr("%n app(s)", "", page.apps.length) : qsTr("Loading…")
                    color: LingmoUI.Theme.disabledTextColor
                }
            }
        }

        AppGridView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: page.apps
            onAppClicked: (key) => rootWindow.openApp(key)
        }
    }
}
