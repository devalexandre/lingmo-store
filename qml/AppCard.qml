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

// An app in a grid: icon, name, one-line summary and where it comes from
Rectangle {
    id: control

    property var app: ({})
    signal clicked()

    readonly property var rating: { reviews.revision; return reviews.rating(app.key || "") }

    implicitHeight: 104
    radius: LingmoUI.Theme.bigRadius
    color: mouse.containsMouse ? (LingmoUI.Theme.darkMode ? Qt.lighter(LingmoUI.Theme.secondBackgroundColor, 1.18)
                                                          : Qt.darker(LingmoUI.Theme.secondBackgroundColor, 1.02))
                               : LingmoUI.Theme.secondBackgroundColor
    border.width: 1
    border.color: mouse.containsMouse ? Qt.rgba(LingmoUI.Theme.highlightColor.r, LingmoUI.Theme.highlightColor.g,
                                                LingmoUI.Theme.highlightColor.b, 0.45)
                                      : (LingmoUI.Theme.darkMode ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(0, 0, 0, 0.05))

    Behavior on color { ColorAnimation { duration: 120 } }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: control.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: LingmoUI.Units.largeSpacing
        spacing: LingmoUI.Units.largeSpacing

        AppIcon {
            size: 60
            source: control.app.iconUrl || ""
            iconName: control.app.iconName || ""
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                spacing: LingmoUI.Units.smallSpacing

                Label {
                    text: control.app.name || ""
                    font.pointSize: LingmoUI.Theme.fontSize * 1.08
                    font.bold: true
                    color: LingmoUI.Theme.textColor
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                // Average stars and how many people rated it
                RatingStars {
                    visible: !!control.rating.count
                    size: 12
                    count: 1   // one star: the number says the rest
                    value: 1
                    Layout.alignment: Qt.AlignVCenter
                }
                Label {
                    visible: !!control.rating.count
                    text: control.rating.count
                          ? "%1 (%2)".arg(Number(control.rating.average).toLocaleString(Qt.locale(), 'f', 1))
                                     .arg(Number(control.rating.count).toLocaleString(Qt.locale(), 'f', 0))
                          : ""
                    color: LingmoUI.Theme.disabledTextColor
                    font.pointSize: LingmoUI.Theme.fontSize * 0.8
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            Label {
                text: control.app.summary || ""
                color: LingmoUI.Theme.disabledTextColor
                font.pointSize: LingmoUI.Theme.fontSize * 0.92
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Row {
                spacing: 4
                Layout.topMargin: 2

                Badge {
                    visible: !!control.app.installed
                    text: qsTr("Installed")
                    tint: LingmoUI.Theme.greenColor
                    icon: "qrc:/icons/check.svg"
                    filled: true
                }
                Badge {
                    visible: !!control.app.hasFlathub
                    text: "Flathub"
                    tint: "#4A86CF"
                }
                Badge {
                    visible: !!control.app.hasArch
                    text: "Arch"
                    tint: "#1793D1"
                    filled: false
                }
            }
        }
    }
}
