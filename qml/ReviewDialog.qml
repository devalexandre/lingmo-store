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

// Writing a review: stars, a title and a few words, sent to ODRS
Popup {
    id: control

    property string appKey: ""
    property string appName: ""
    property string version: ""
    property int stars: 0
    property string error: ""

    readonly property bool valid: stars > 0 && titleField.text.trim().length > 0
                                  && textArea.text.trim().length >= 15
                                  && textArea.text.trim().length <= 3000

    function openFor(key, name, ver) {
        appKey = key
        appName = name
        version = ver
        stars = 0
        error = ""
        titleField.text = ""
        textArea.text = ""
        nameField.text = reviews.userName
        open()
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(520, parent ? parent.width - 80 : 520)
    modal: true
    focus: true
    padding: LingmoUI.Units.largeSpacing * 2
    closePolicy: reviews.submitting ? Popup.NoAutoClose : Popup.CloseOnEscape

    Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, LingmoUI.Theme.darkMode ? 0.45 : 0.25)
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 }
        NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: 120; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
    }

    background: Rectangle {
        radius: LingmoUI.Theme.hugeRadius
        color: LingmoUI.Theme.secondBackgroundColor
        border.width: 1
        border.color: LingmoUI.Theme.darkMode ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.08)
    }

    Connections {
        target: reviews
        function onSubmitted(key, ok, message) {
            if (key !== control.appKey)
                return
            if (ok) {
                control.close()
                rootWindow.showPassiveNotification(qsTr("Thanks! Your review was sent."), 4000)
            } else {
                control.error = message
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: LingmoUI.Units.largeSpacing

        Label {
            text: qsTr("Review %1").arg(control.appName)
            font.pointSize: LingmoUI.Theme.fontSize * 1.25
            font.bold: true
            color: LingmoUI.Theme.textColor
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        RowLayout {
            spacing: LingmoUI.Units.largeSpacing
            RatingStars {
                size: 28
                interactive: !reviews.submitting
                value: control.stars
                onPicked: (n) => control.stars = n
            }
            Label {
                text: [qsTr("Tap a star to rate"), qsTr("Terrible"), qsTr("Bad"), qsTr("OK"), qsTr("Good"),
                       qsTr("Excellent")][control.stars]
                color: LingmoUI.Theme.disabledTextColor
            }
        }

        TextField {
            id: titleField
            Layout.fillWidth: true
            placeholderText: qsTr("Title (for example: Does everything I need)")
            maximumLength: 70
            selectByMouse: true
            enabled: !reviews.submitting
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: 140

            TextArea {
                id: textArea
                placeholderText: qsTr("What did you like? What could be better?")
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                enabled: !reviews.submitting
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: LingmoUI.Units.largeSpacing

            Label {
                text: qsTr("Your name")
                color: LingmoUI.Theme.textColor
            }
            TextField {
                id: nameField
                Layout.fillWidth: true
                placeholderText: qsTr("Anonymous")
                maximumLength: 40
                selectByMouse: true
                enabled: !reviews.submitting
            }
        }

        Label {
            text: textArea.text.trim().length > 0 && textArea.text.trim().length < 15
                  ? qsTr("Write a little more (at least 15 letters).")
                  : qsTr("Your review is public and shared with other Linux app stores. It's linked to an anonymous code of this computer, not to your account.")
            color: LingmoUI.Theme.disabledTextColor
            font.pointSize: LingmoUI.Theme.fontSize * 0.88
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        Label {
            visible: control.error !== ""
            text: control.error
            color: LingmoUI.Theme.redColor
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: LingmoUI.Units.largeSpacing

            Spinner {
                visible: reviews.submitting
                running: visible
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
            }
            Item { Layout.fillWidth: true }
            ActionButton {
                text: qsTr("Cancel")
                enabled: !reviews.submitting
                onClicked: control.close()
            }
            ActionButton {
                primary: true
                text: qsTr("Send Review")
                enabled: control.valid && !reviews.submitting
                onClicked: {
                    control.error = ""
                    if (!reviews.submit(control.appKey, control.version, control.stars, titleField.text,
                                        textArea.text, nameField.text))
                        control.error = qsTr("Could not send your review. Try again later.")
                }
            }
        }
    }
}
