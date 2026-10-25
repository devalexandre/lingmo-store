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

// A featured collection of the home page (catalog.collections()): a banner with an
// optional one-click bundle, then the collection's apps
ColumnLayout {
    id: control

    property var collection: ({})
    property bool expanded: false
    readonly property int shownCount: 6
    readonly property var apps: collection.apps || []
    readonly property var bundle: collection.bundle || null
    readonly property bool bundleBusy: installer.busy && !!bundle
                                       && installer.currentKey === "pkg:" + bundle.packages.join(",")

    spacing: LingmoUI.Units.largeSpacing

    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: LingmoUI.Units.largeSpacing
        implicitHeight: banner.implicitHeight + LingmoUI.Units.largeSpacing * 4
        radius: LingmoUI.Theme.hugeRadius + 4
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: control.collection.colors ? control.collection.colors[0] : LingmoUI.Theme.highlightColor }
            GradientStop { position: 1.0; color: control.collection.colors ? control.collection.colors[1] : LingmoUI.Theme.highlightColor }
        }

        RowLayout {
            id: banner
            anchors.fill: parent
            anchors.margins: LingmoUI.Units.largeSpacing * 2
            spacing: LingmoUI.Units.largeSpacing * 2

            // The first apps' icons, overlapping
            Item {
                Layout.preferredWidth: 56 + 3 * 22
                Layout.preferredHeight: 56
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                    model: (control.collection.apps || []).slice(0, 4)

                    AppIcon {
                        x: index * 22
                        z: 4 - index
                        size: 56
                        source: modelData.iconUrl || ""
                        iconName: modelData.iconName || ""
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: LingmoUI.Units.smallSpacing

                LingmoUI.Badge {
                    visible: !!control.collection.experimental
                    text: qsTr("Experimental — pre-alpha")
                    tone: LingmoUI.Theme.warningColor
                }
                Label {
                    text: control.collection.title || ""
                    color: LingmoUI.Theme.highlightedTextColor
                    font.bold: true
                    font.pointSize: LingmoUI.Units.fontHeading
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
                Label {
                    text: control.collection.text || ""
                    color: Qt.rgba(1, 1, 1, 0.85)
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }

            ColumnLayout {
                visible: !!control.bundle && control.bundle.available
                Layout.alignment: Qt.AlignVCenter
                spacing: LingmoUI.Units.smallSpacing

                LingmoUI.ActionButton {
                    light: true
                    text: control.bundle && control.bundle.installed ? qsTr("Office suite installed")
                                                                     : (control.bundle ? control.bundle.label : "")
                    enabled: !!control.bundle && !control.bundle.installed && !installer.busy
                    busy: control.bundleBusy
                    Layout.alignment: Qt.AlignRight
                    onClicked: rootWindow.installBundle(control.bundle)
                }
                Label {
                    text: control.bundleBusy ? installer.statusText
                                             : (control.bundle ? control.bundle.apps.join(" · ") : "")
                    color: Qt.rgba(1, 1, 1, 0.8)
                    font.pointSize: LingmoUI.Units.fontCaption
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignRight
                    Layout.maximumWidth: 240
                    Layout.alignment: Qt.AlignRight
                }
            }
        }
    }

    AppGrid {
        apps: control.expanded ? control.apps : control.apps.slice(0, control.shownCount)
        Layout.fillWidth: true
        onAppClicked: (key) => rootWindow.openApp(key)
    }

    Label {
        visible: control.apps.length > control.shownCount
        text: control.expanded ? qsTr("Show fewer") : qsTr("Show all %n app(s)", "", control.apps.length)
        color: LingmoUI.Theme.highlightColor
        font.bold: true
        Layout.alignment: Qt.AlignRight

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: control.expanded = !control.expanded
        }
    }
}
