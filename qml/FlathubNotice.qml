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
import Lingmo.Store

// What's up with Flathub: off (offer to turn it on), downloading its catalog, failed
Card {
    id: control

    readonly property int st: flatpak.state
    visible: st === Flatpak.NoRemote || st === Flatpak.AddingRemote || st === Flatpak.Refreshing
             || st === Flatpak.Error || st === Flatpak.Unavailable

    RowLayout {
        spacing: LingmoUI.Units.largeSpacing * 1.5
        Layout.fillWidth: true

        Rectangle {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            radius: 12
            color: "#4A86CF"

            Label {
                anchors.centerIn: parent
                text: "F"
                color: "white"
                font.bold: true
                font.pointSize: 18
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Label {
                Layout.fillWidth: true
                font.bold: true
                color: LingmoUI.Theme.textColor
                wrapMode: Text.Wrap
                text: {
                    switch (control.st) {
                    case Flatpak.NoRemote: return qsTr("Get thousands more apps with Flathub")
                    case Flatpak.AddingRemote: return qsTr("Turning on Flathub…")
                    case Flatpak.Refreshing: return qsTr("Downloading the Flathub catalog…")
                    case Flatpak.Unavailable: return qsTr("Flathub is not available")
                    default: return qsTr("Could not download the Flathub catalog")
                    }
                }
            }
            Label {
                Layout.fillWidth: true
                color: control.st === Flatpak.Error ? LingmoUI.Theme.redColor : LingmoUI.Theme.disabledTextColor
                wrapMode: Text.Wrap
                text: {
                    switch (control.st) {
                    case Flatpak.NoRemote: return qsTr("Flathub is the biggest store of Linux apps: Spotify, Discord, Zoom and many more. Its apps run isolated from the system.")
                    case Flatpak.Refreshing: return qsTr("This happens only once and takes a minute. The apps from the Arch repositories are already here.")
                    case Flatpak.Unavailable: return qsTr("Install the flatpak package to get apps from Flathub.")
                    case Flatpak.Error: return flatpak.errorMessage
                    default: return ""
                    }
                }
                visible: text !== ""
            }
        }

        Spinner {
            visible: control.st === Flatpak.AddingRemote || control.st === Flatpak.Refreshing
            running: visible
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
        }

        ActionButton {
            visible: control.st === Flatpak.NoRemote
            primary: true
            text: qsTr("Turn On Flathub")
            onClicked: flatpak.addFlathub()
        }

        ActionButton {
            visible: control.st === Flatpak.Error
            text: qsTr("Try Again")
            onClicked: flatpak.refreshAppstream(true)
        }
    }
}
