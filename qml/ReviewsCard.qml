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

// Stars and recent reviews of an app, from ODRS
Card {
    id: control

    property string appKey: ""
    property string appName: ""
    property string version: ""
    property bool installed: false
    signal writeReview()

    readonly property var rating: { reviews.revision; return reviews.rating(appKey) }
    readonly property var revs: { reviews.revision; return reviews.reviews(appKey) }
    readonly property var items: revs.items || []
    readonly property bool hasRating: !!rating.count

    RowLayout {
        Layout.fillWidth: true
        spacing: LingmoUI.Units.largeSpacing

        Label {
            text: qsTr("Ratings and reviews")
            font.bold: true
            font.pointSize: LingmoUI.Theme.fontSize * 1.15
            color: LingmoUI.Theme.textColor
            Layout.fillWidth: true
        }
        ActionButton {
            visible: control.installed && reviews.canSubmit && !control.revs.reviewed
            text: qsTr("Write a Review")
            enabled: !reviews.submitting
            onClicked: control.writeReview()
        }
    }

    // Average and distribution
    RowLayout {
        visible: control.hasRating
        Layout.fillWidth: true
        spacing: LingmoUI.Units.largeSpacing * 2

        ColumnLayout {
            spacing: 2
            Layout.alignment: Qt.AlignVCenter

            Label {
                text: control.hasRating ? Number(control.rating.average).toLocaleString(Qt.locale(), 'f', 1) : ""
                font.pointSize: LingmoUI.Theme.fontSize * 3
                font.bold: true
                color: LingmoUI.Theme.textColor
                Layout.alignment: Qt.AlignHCenter
            }
            RatingStars {
                size: 16
                value: control.rating.average || 0
                Layout.alignment: Qt.AlignHCenter
            }
            Label {
                text: qsTr("%n rating(s)", "", control.rating.count || 0)
                color: LingmoUI.Theme.disabledTextColor
                font.pointSize: LingmoUI.Theme.fontSize * 0.9
                Layout.alignment: Qt.AlignHCenter
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: 420
            spacing: 3

            Repeater {
                model: [5, 4, 3, 2, 1]

                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: LingmoUI.Units.smallSpacing
                    readonly property int amount: control.hasRating ? control.rating.stars[modelData - 1] : 0

                    Label {
                        text: modelData
                        color: LingmoUI.Theme.disabledTextColor
                        font.pointSize: LingmoUI.Theme.fontSize * 0.85
                        Layout.preferredWidth: 10
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 8
                        radius: 4
                        color: LingmoUI.Theme.alternateBackgroundColor

                        Rectangle {
                            width: control.hasRating ? parent.width * parent.parent.amount / control.rating.count : 0
                            height: parent.height
                            radius: 4
                            color: LingmoUI.Theme.orangeColor
                        }
                    }
                }
            }
        }
        Item { Layout.fillWidth: true }
    }

    Label {
        visible: !control.hasRating && control.items.length === 0 && control.revs.state === "ready"
        text: control.installed ? qsTr("Nobody reviewed %1 yet. Be the first!").arg(control.appName)
                                : qsTr("Nobody reviewed %1 yet.").arg(control.appName)
        color: LingmoUI.Theme.disabledTextColor
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    RowLayout {
        visible: control.revs.state === "loading" && control.items.length === 0
        spacing: LingmoUI.Units.largeSpacing
        Spinner {
            running: parent.visible
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
        }
        Label {
            text: qsTr("Loading reviews…")
            color: LingmoUI.Theme.disabledTextColor
        }
    }

    Label {
        visible: control.revs.state === "offline" || control.revs.state === "error"
        text: control.revs.state === "offline" ? qsTr("Reviews need an internet connection.")
                                               : qsTr("Could not load the reviews right now.")
        color: LingmoUI.Theme.disabledTextColor
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    Label {
        visible: !!control.revs.english && control.items.length > 0
        text: qsTr("No reviews in your language yet; these were written in English.")
        color: LingmoUI.Theme.disabledTextColor
        font.pointSize: LingmoUI.Theme.fontSize * 0.9
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    Repeater {
        model: control.items

        delegate: Rectangle {
            Layout.fillWidth: true
            implicitHeight: review.implicitHeight + LingmoUI.Units.largeSpacing * 2
            radius: LingmoUI.Theme.mediumRadius
            color: LingmoUI.Theme.alternateBackgroundColor

            ColumnLayout {
                id: review
                anchors.fill: parent
                anchors.margins: LingmoUI.Units.largeSpacing
                spacing: LingmoUI.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: LingmoUI.Units.smallSpacing

                    RatingStars {
                        size: 13
                        value: modelData.stars
                    }
                    Label {
                        text: modelData.summary
                        font.bold: true
                        color: LingmoUI.Theme.textColor
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Badge {
                        visible: !!modelData.mine
                        text: qsTr("Your review")
                        tint: LingmoUI.Theme.highlightColor
                    }
                }
                Label {
                    visible: text !== ""
                    text: modelData.description
                    color: LingmoUI.Theme.textColor
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    maximumLineCount: 8
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Label {
                    text: [modelData.author, modelData.date,
                           modelData.version ? qsTr("version %1").arg(modelData.version) : ""]
                          .filter(s => s !== "").join("  ·  ")
                    color: LingmoUI.Theme.disabledTextColor
                    font.pointSize: LingmoUI.Theme.fontSize * 0.85
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }
    }

    Label {
        text: control.installed || !reviews.canSubmit ? qsTr("Reviews come from ODRS, the service shared with GNOME Software and KDE Discover.")
                                                     : qsTr("Reviews come from ODRS, the service shared with GNOME Software and KDE Discover. Install the app to review it.")
        color: LingmoUI.Theme.disabledTextColor
        font.pointSize: LingmoUI.Theme.fontSize * 0.85
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }
}
