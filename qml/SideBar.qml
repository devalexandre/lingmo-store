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

// Navigation on the left, in the style of Lingmo Settings
Item {
    id: control

    implicitWidth: 244

    property alias model: listModel
    property string currentName: "home"
    signal activated(string name)

    function select(name) {
        for (let i = 0; i < listModel.count; ++i) {
            if (listModel.get(i).name === name) {
                listView.currentIndex = i
                control.currentName = name
                return
            }
        }
        listView.currentIndex = -1
        control.currentName = name
    }

    // Categories and their tile colors, also used by the home page
    function categoryInfo(name) {
        for (let i = 0; i < listModel.count; ++i) {
            if (listModel.get(i).name === name)
                return listModel.get(i)
        }
        return null
    }

    Rectangle {
        anchors.fill: parent
        color: LingmoUI.Theme.darkMode ? Qt.rgba(0.11, 0.11, 0.15, 0.55) : "#EDEEF2"
        Behavior on color { ColorAnimation { duration: 250 } }
    }

    ListModel {
        id: listModel

        ListElement { title: qsTr("Home"); name: "home"; iconSource: "home.svg"; iconColor: "#0A84FF"; section: "" }
        ListElement { title: qsTr("Games"); name: "games"; iconSource: "games.svg"; iconColor: "#BF5AF2"; section: "" }
        ListElement { title: qsTr("Native games"); name: "native"; iconSource: "native.svg"; iconColor: "#E0457B"; section: "" }
        ListElement { title: qsTr("Productivity"); name: "office"; iconSource: "office.svg"; iconColor: "#FF9500"; section: qsTr("Categories") }
        ListElement { title: qsTr("Internet"); name: "internet"; iconSource: "internet.svg"; iconColor: "#32ADE6"; section: qsTr("Categories") }
        ListElement { title: qsTr("Graphics & Photo"); name: "graphics"; iconSource: "graphics.svg"; iconColor: "#FF375F"; section: qsTr("Categories") }
        ListElement { title: qsTr("Audio & Video"); name: "multimedia"; iconSource: "multimedia.svg"; iconColor: "#FF6B3A"; section: qsTr("Categories") }
        ListElement { title: qsTr("Development"); name: "development"; iconSource: "development.svg"; iconColor: "#5E5CE6"; section: qsTr("Categories") }
        ListElement { title: qsTr("Education"); name: "education"; iconSource: "education.svg"; iconColor: "#30B0C7"; section: qsTr("Categories") }
        ListElement { title: qsTr("Utilities"); name: "utilities"; iconSource: "utilities.svg"; iconColor: "#8E8E93"; section: qsTr("Categories") }
        ListElement { title: qsTr("Installed"); name: "installed"; iconSource: "installed.svg"; iconColor: "#34C759"; section: qsTr("Your computer") }
        ListElement { title: qsTr("Updates"); name: "updates"; iconSource: "updates.svg"; iconColor: "#FF9F0A"; section: qsTr("Your computer") }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Room for the window buttons
        Item {
            Layout.preferredHeight: rootWindow.header.height
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: LingmoUI.Units.largeSpacing + LingmoUI.Units.smallSpacing
            Layout.rightMargin: LingmoUI.Units.largeSpacing
            Layout.bottomMargin: LingmoUI.Units.largeSpacing
            spacing: LingmoUI.Units.smallSpacing * 1.5

            LingmoUI.IconItem {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                source: "system-software-install"
            }

            Label {
                text: rootWindow.title
                color: rootWindow.active ? LingmoUI.Theme.textColor : LingmoUI.Theme.disabledTextColor
                font.pointSize: 13
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        ListView {
            id: listView
            Layout.fillHeight: true
            Layout.fillWidth: true
            clip: true
            model: listModel
            currentIndex: 0
            spacing: 2
            leftMargin: LingmoUI.Units.largeSpacing
            rightMargin: LingmoUI.Units.largeSpacing
            bottomMargin: LingmoUI.Units.largeSpacing
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            highlightFollowsCurrentItem: true
            highlightMoveDuration: 0
            highlightResizeDuration: 0
            highlight: Rectangle {
                radius: LingmoUI.Theme.mediumRadius
                color: LingmoUI.Theme.highlightColor
            }

            section.property: "section"
            section.delegate: Item {
                width: ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin
                height: section === "" ? 0 : LingmoUI.Units.fontMetrics.height + LingmoUI.Units.largeSpacing + LingmoUI.Units.smallSpacing
                visible: section !== ""

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: LingmoUI.Units.smallSpacing
                    anchors.topMargin: LingmoUI.Units.largeSpacing
                    color: LingmoUI.Theme.disabledTextColor
                    font.pointSize: LingmoUI.Theme.fontSize * 0.92
                    text: section
                }
            }

            LingmoUI.WheelHandler {
                target: listView
            }

            delegate: Item {
                id: item
                width: ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin
                height: LingmoUI.Units.fontMetrics.height + LingmoUI.Units.largeSpacing * 1.5

                readonly property bool isCurrent: listView.currentIndex === index

                Rectangle {
                    anchors.fill: parent
                    radius: LingmoUI.Theme.mediumRadius
                    color: mouseArea.containsMouse && !item.isCurrent
                           ? Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g, LingmoUI.Theme.textColor.b, 0.1)
                           : "transparent"
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (model.name !== "updates") {
                            listView.currentIndex = index
                            control.currentName = model.name
                        }
                        control.activated(model.name)
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: LingmoUI.Units.smallSpacing * 1.5
                    anchors.rightMargin: LingmoUI.Units.smallSpacing * 1.5
                    spacing: LingmoUI.Units.smallSpacing * 1.5

                    Rectangle {
                        id: tile
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        radius: 7
                        readonly property color tileColor: LingmoUI.Theme.darkMode ? Qt.lighter(model.iconColor, 1.12) : model.iconColor
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.lighter(tile.tileColor, 1.15) }
                            GradientStop { position: 1.0; color: tile.tileColor }
                        }
                        border.width: 1
                        border.color: item.isCurrent ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.06)

                        Image {
                            anchors.centerIn: parent
                            width: 15
                            height: 15
                            source: "qrc:/icons/" + model.iconSource
                            sourceSize: Qt.size(30, 30)
                        }
                    }

                    Label {
                        text: model.title
                        color: item.isCurrent ? LingmoUI.Theme.highlightedTextColor : LingmoUI.Theme.textColor
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Label {
                        visible: model.name === "updates"
                        text: "↗"
                        color: item.isCurrent ? LingmoUI.Theme.highlightedTextColor : LingmoUI.Theme.disabledTextColor
                    }
                }
            }
        }

        // What's being installed right now, from any page
        Rectangle {
            id: activity
            Layout.fillWidth: true
            Layout.margins: LingmoUI.Units.largeSpacing
            Layout.preferredHeight: visible ? activityLayout.implicitHeight + LingmoUI.Units.largeSpacing * 2 : 0
            visible: installer.busy
            radius: LingmoUI.Theme.mediumRadius
            color: LingmoUI.Theme.secondBackgroundColor

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (installer.currentAction === "gaming")
                        rootWindow.showGames()
                    else if (installer.currentKey !== "")
                        rootWindow.openApp(installer.currentKey)
                }
            }

            ColumnLayout {
                id: activityLayout
                anchors.fill: parent
                anchors.margins: LingmoUI.Units.largeSpacing
                spacing: LingmoUI.Units.smallSpacing

                Label {
                    Layout.fillWidth: true
                    text: installer.currentAction === "remove" ? qsTr("Removing %1").arg(installer.currentName)
                        : installer.currentAction === "gaming" ? qsTr("Preparing for games")
                        : qsTr("Installing %1").arg(installer.currentName)
                    font.bold: true
                    elide: Text.ElideRight
                    color: LingmoUI.Theme.textColor
                }
                ProgressBar {
                    Layout.fillWidth: true
                    indeterminate: installer.progress < 0
                    value: Math.max(0, installer.progress)
                }
                Label {
                    Layout.fillWidth: true
                    text: installer.statusText
                    elide: Text.ElideRight
                    color: LingmoUI.Theme.disabledTextColor
                    font.pointSize: LingmoUI.Theme.fontSize * 0.9
                }
            }
        }
    }
}
