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

Flickable {
    id: page

    readonly property string pageName: "home"
    readonly property int margin: LingmoUI.Units.largeSpacing * 2
    readonly property var heroes: { rootWindow.rev; return catalog.heroes() }
    readonly property var featured: { rootWindow.rev; return catalog.featured() }
    readonly property var collections: { rootWindow.rev; return catalog.collections() }

    contentWidth: width
    contentHeight: column.implicitHeight + margin * 2
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}

    LingmoUI.WheelHandler {
        target: page
    }

    ColumnLayout {
        id: column
        x: page.margin
        y: LingmoUI.Units.smallSpacing
        width: page.width - page.margin * 2
        spacing: LingmoUI.Units.largeSpacing * 1.5

        // First start: the catalog is still being read
        LingmoUI.Card {
            visible: !catalog.ready
            Layout.fillWidth: true
            Layout.preferredHeight: 200

            LingmoUI.EmptyState {
                anchors.centerIn: parent
                busy: true
                text: qsTr("Loading the app catalog…")
            }
        }

        HeroBanner {
            heroes: page.heroes
            Layout.fillWidth: true
        }

        FlathubNotice {
            Layout.fillWidth: true
        }

        // Featured collections (the Craft suite): banner plus its apps
        Repeater {
            model: page.collections

            CollectionBanner {
                collection: modelData
                Layout.fillWidth: true
            }
        }

        SectionHeader {
            visible: page.featured.length > 0
            text: qsTr("Popular apps")
            subtitle: qsTr("Hand-picked favorites to get you started")
        }

        AppGrid {
            apps: page.featured
            Layout.fillWidth: true
            onAppClicked: (key) => rootWindow.openApp(key)
        }

        SectionHeader {
            text: qsTr("Categories")
        }

        GridLayout {
            id: tiles
            Layout.fillWidth: true
            columns: width > 640 ? 3 : 2
            columnSpacing: LingmoUI.Units.largeSpacing
            rowSpacing: LingmoUI.Units.largeSpacing

            Repeater {
                model: ["office", "internet", "graphics", "multimedia", "engineering", "games", "native", "development", "education", "utilities"]

                CategoryTile {
                    readonly property var info: sideBar.categoryInfo(modelData)
                    name: modelData
                    title: info ? info.title : ""
                    iconSource: info ? info.iconSource : ""
                    tint: info ? info.iconColor : LingmoUI.Theme.greyColor
                    Layout.fillWidth: true
                }
            }
        }

        // Games teaser
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: LingmoUI.Units.largeSpacing
            implicitHeight: teaser.implicitHeight + LingmoUI.Units.largeSpacing * 4
            radius: LingmoUI.Theme.hugeRadius + 4
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#3a1c71" }
                GradientStop { position: 0.6; color: "#6a3093" }
                GradientStop { position: 1.0; color: "#a044ff" }
            }

            RowLayout {
                id: teaser
                anchors.fill: parent
                anchors.margins: LingmoUI.Units.largeSpacing * 2
                spacing: LingmoUI.Units.largeSpacing * 2

                Image {
                    source: "qrc:/icons/games.svg"
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 56
                    sourceSize: Qt.size(112, 112)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Label {
                        text: qsTr("Play on Linux")
                        color: LingmoUI.Theme.highlightedTextColor
                        font.bold: true
                        font.pointSize: LingmoUI.Units.fontHeading
                    }
                    Label {
                        text: qsTr("Get Steam and the right drivers in one click, and check whether your game works.")
                        color: Qt.rgba(1, 1, 1, 0.85)
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }
                LingmoUI.ActionButton {
                    light: true
                    text: qsTr("Go to Games")
                    onClicked: rootWindow.showGames()
                }
            }
        }
    }
}
