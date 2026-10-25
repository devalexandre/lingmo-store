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
LingmoUI.Card {
    id: control

    property var app: ({})

    readonly property var rating: { reviews.revision; return reviews.rating(app.key || "") }

    implicitHeight: 104
    radius: LingmoUI.Theme.bigRadius
    clickable: true
    liftOnHover: true

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
                    font.pointSize: LingmoUI.Units.fontBody
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
                    color: LingmoUI.Theme.secondaryTextColor
                    font.pointSize: LingmoUI.Units.fontCaption
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            Label {
                text: control.app.summary || ""
                color: LingmoUI.Theme.secondaryTextColor
                font.pointSize: LingmoUI.Units.fontCaption
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Row {
                spacing: 4
                Layout.topMargin: 2

                LingmoUI.Badge {
                    visible: !!control.app.installed
                    text: qsTr("Installed")
                    tone: LingmoUI.Theme.successColor
                }
                LingmoUI.Badge {
                    visible: !!control.app.experimental
                    text: qsTr("Experimental")
                    tone: LingmoUI.Theme.warningColor
                }
                LingmoUI.Badge {
                    visible: !!control.app.hasFlathub
                    text: "Flathub"
                    subtle: true
                }
                LingmoUI.Badge {
                    visible: !!control.app.hasArch
                    text: "Arch"
                    subtle: true
                }
            }
        }
    }
}
