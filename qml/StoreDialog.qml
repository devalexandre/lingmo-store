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

// A small modal question in the store's style
Popup {
    id: control

    property string title: ""
    property string text: ""
    property string iconName: "dialog-question"
    property string acceptText: qsTr("OK")
    property string rejectText: qsTr("Cancel")
    property bool destructive: false
    property bool showReject: true
    signal accepted()
    signal rejected()

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(460, parent ? parent.width - 80 : 460)
    modal: true
    focus: true
    padding: LingmoUI.Units.largeSpacing * 2
    font.pointSize: LingmoUI.Units.fontBody
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, LingmoUI.Theme.darkMode ? 0.45 : 0.25)
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: LingmoUI.Units.shortDuration }
        NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: LingmoUI.Units.shortDuration; easing.type: LingmoUI.Units.easing }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: LingmoUI.Units.veryShortDuration }
    }

    background: Rectangle {
        radius: LingmoUI.Theme.hugeRadius
        color: LingmoUI.Theme.secondBackgroundColor
        border.width: 1
        border.color: LingmoUI.Theme.borderColor

        LingmoUI.Elevation {
            z: -1
            anchors.fill: parent
            radius: parent.radius
            level: 3
        }
    }

    contentItem: ColumnLayout {
        spacing: LingmoUI.Units.largeSpacing

        RowLayout {
            spacing: LingmoUI.Units.largeSpacing
            Layout.fillWidth: true

            LingmoUI.IconItem {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                Layout.alignment: Qt.AlignTop
                source: control.iconName
            }

            ColumnLayout {
                spacing: LingmoUI.Units.smallSpacing
                Layout.fillWidth: true

                Label {
                    text: control.title
                    font.pointSize: LingmoUI.Units.fontHeading
                    font.bold: true
                    color: LingmoUI.Theme.textColor
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
                Label {
                    text: control.text
                    color: LingmoUI.Theme.secondaryTextColor
                    wrapMode: Text.Wrap
                    textFormat: Text.StyledText
                    Layout.fillWidth: true
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: LingmoUI.Units.smallSpacing
            spacing: LingmoUI.Units.largeSpacing

            Item { Layout.fillWidth: true }

            LingmoUI.ActionButton {
                visible: control.showReject
                text: control.rejectText
                onClicked: {
                    control.close()
                    control.rejected()
                }
            }
            LingmoUI.ActionButton {
                text: control.acceptText
                primary: true
                destructive: control.destructive
                onClicked: {
                    control.close()
                    control.accepted()
                }
            }
        }
    }
}
