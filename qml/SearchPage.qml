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

    readonly property string pageName: "search"
    property string query: ""
    readonly property var results: { rootWindow.rev; return catalog.search(query, 80) }

    ColumnLayout {
        anchors.fill: parent
        spacing: LingmoUI.Units.largeSpacing

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: LingmoUI.Units.largeSpacing * 2
            Layout.rightMargin: LingmoUI.Units.largeSpacing * 2
            Layout.topMargin: LingmoUI.Units.smallSpacing
            spacing: 0

            Label {
                text: qsTr("Results for “%1”").arg(page.query)
                font.pointSize: LingmoUI.Theme.fontSize * 1.6
                font.bold: true
                color: LingmoUI.Theme.textColor
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Label {
                visible: page.results.length > 0
                text: qsTr("%n app(s) found", "", page.results.length)
                color: LingmoUI.Theme.disabledTextColor
            }
        }

        AppGridView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: page.results.length > 0
            model: page.results
            onAppClicked: (key) => rootWindow.openApp(key)
        }

        // Nothing found
        ColumnLayout {
            visible: page.results.length === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: LingmoUI.Units.largeSpacing

            Item { Layout.fillHeight: true }

            Image {
                source: "qrc:/icons/search.svg"
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 64
                Layout.preferredHeight: 64
                sourceSize: Qt.size(128, 128)
                opacity: 0.5
            }
            Label {
                text: catalog.ready ? qsTr("No apps found") : qsTr("Loading the app catalog…")
                font.pointSize: LingmoUI.Theme.fontSize * 1.3
                font.bold: true
                color: LingmoUI.Theme.textColor
                Layout.alignment: Qt.AlignHCenter
            }
            Label {
                visible: catalog.ready
                text: qsTr("Check the spelling or try another word, like “music” or “photos”.")
                color: LingmoUI.Theme.disabledTextColor
                Layout.alignment: Qt.AlignHCenter
            }

            Item { Layout.fillHeight: true }
        }
    }
}
