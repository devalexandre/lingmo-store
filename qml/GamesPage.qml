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
import Qt5Compat.GraphicalEffects
import LingmoUI.CompatibleModule 3.0 as LingmoUI

Flickable {
    id: page

    readonly property string pageName: "games"
    readonly property int margin: LingmoUI.Units.largeSpacing * 2
    readonly property var apps: { rootWindow.rev; return catalog.gameApps() }
    readonly property bool preparing: installer.busy && installer.currentAction === "gaming"
    property string lastError: ""
    property bool justFinished: false
    property bool showLog: false

    contentWidth: width
    contentHeight: column.implicitHeight + margin * 2
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}

    LingmoUI.WheelHandler {
        target: page
    }

    Connections {
        target: installer
        function onFinished(key, source, action, ok, message) {
            if (action !== "gaming")
                return
            page.lastError = ok ? "" : message
            page.justFinished = ok
        }
    }

    function verdictColor(verdict) {
        switch (verdict) {
        case "great": return "#2EB67D"
        case "tweaks": return "#E8A317"
        case "anticheat":
        case "broken": return "#E5484D"
        default: return "#8E8E93"
        }
    }

    ColumnLayout {
        id: column
        x: page.margin
        y: LingmoUI.Units.smallSpacing
        width: page.width - page.margin * 2
        spacing: LingmoUI.Units.largeSpacing * 1.5

        // Get ready for games
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: prep.implicitHeight + LingmoUI.Units.largeSpacing * 5
            radius: LingmoUI.Theme.hugeRadius + 4
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#1b1446" }
                GradientStop { position: 0.55; color: "#3b1f7a" }
                GradientStop { position: 1.0; color: "#6d34c7" }
            }

            Rectangle {
                width: 320
                height: 320
                radius: 160
                x: parent.width - 220
                y: -120
                color: Qt.rgba(1, 1, 1, 0.05)
            }

            ColumnLayout {
                id: prep
                anchors.fill: parent
                anchors.margins: LingmoUI.Units.largeSpacing * 2.5
                spacing: LingmoUI.Units.largeSpacing * 1.5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: LingmoUI.Units.largeSpacing * 2

                    Image {
                        source: "qrc:/icons/games.svg"
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 64
                        Layout.alignment: Qt.AlignTop
                        sourceSize: Qt.size(128, 128)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: LingmoUI.Units.smallSpacing

                        Label {
                            text: games.allDone ? qsTr("Ready for games!") : qsTr("Get ready for games")
                            color: "white"
                            font.bold: true
                            font.pointSize: LingmoUI.Theme.fontSize * 2
                        }
                        Label {
                            text: games.allDone
                                  ? qsTr("Steam, the drivers and the optimizations are installed. Open Steam and have fun.")
                                  : qsTr("Installs Steam, the video drivers and the tweaks for playing on Linux, all in one click. You'll be asked for your password once.")
                            color: Qt.rgba(1, 1, 1, 0.85)
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                        Label {
                            visible: games.gpuName !== "" || games.detecting
                            text: games.detecting ? qsTr("Detecting your video card…") : qsTr("Video card: %1").arg(games.gpuName)
                            color: Qt.rgba(1, 1, 1, 0.65)
                            font.pointSize: LingmoUI.Theme.fontSize * 0.92
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }

                // Checklist
                GridLayout {
                    Layout.fillWidth: true
                    columns: width > 700 ? 2 : 1
                    columnSpacing: LingmoUI.Units.largeSpacing
                    rowSpacing: LingmoUI.Units.smallSpacing

                    Repeater {
                        model: games.items

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: itemRow.implicitHeight + LingmoUI.Units.largeSpacing * 1.5
                            radius: LingmoUI.Theme.mediumRadius
                            color: Qt.rgba(1, 1, 1, 0.08)
                            opacity: modelData.optional && !games.includeOptional && !modelData.done ? 0.6 : 1

                            RowLayout {
                                id: itemRow
                                anchors.fill: parent
                                anchors.margins: LingmoUI.Units.largeSpacing * 0.75
                                spacing: LingmoUI.Units.largeSpacing

                                Rectangle {
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 22
                                    Layout.alignment: Qt.AlignTop
                                    radius: 11
                                    color: modelData.done ? "#2EB67D" : "transparent"
                                    border.width: modelData.done ? 0 : 2
                                    border.color: Qt.rgba(1, 1, 1, 0.5)

                                    Image {
                                        anchors.centerIn: parent
                                        visible: modelData.done
                                        source: "qrc:/icons/check.svg"
                                        width: 14
                                        height: 14
                                        sourceSize: Qt.size(28, 28)
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Label {
                                        text: modelData.title
                                        color: "white"
                                        font.bold: true
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                    Label {
                                        text: modelData.detail
                                        color: Qt.rgba(1, 1, 1, 0.7)
                                        font.pointSize: LingmoUI.Theme.fontSize * 0.9
                                        wrapMode: Text.Wrap
                                        Layout.fillWidth: true
                                    }
                                }

                                Switch {
                                    visible: modelData.optional && !modelData.done
                                    checked: games.includeOptional
                                    enabled: !page.preparing
                                    onToggled: games.includeOptional = checked
                                }
                            }
                        }
                    }
                }

                // Progress
                ColumnLayout {
                    visible: page.preparing
                    Layout.fillWidth: true
                    spacing: LingmoUI.Units.smallSpacing

                    Label {
                        text: installer.statusText
                        color: "white"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    ProgressBar {
                        Layout.fillWidth: true
                        indeterminate: installer.progress < 0
                        value: Math.max(0, installer.progress)
                    }
                }

                Label {
                    visible: page.lastError !== "" && !page.preparing
                    text: page.lastError
                    color: "#FFB4B4"
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    visible: !page.preparing
                    Layout.fillWidth: true
                    spacing: LingmoUI.Units.largeSpacing

                    ActionButton {
                        light: true
                        visible: !games.allDone
                        enabled: catalog.ready && !installer.busy && !games.detecting
                        text: page.lastError !== "" ? qsTr("Try Again") : qsTr("Get Ready for Games")
                        onClicked: {
                            page.lastError = ""
                            games.prepare()
                        }
                    }
                    ActionButton {
                        light: true
                        visible: games.allDone
                        text: qsTr("Open Steam")
                        onClicked: store.launch(catalog.resolve("steam"), "arch")
                    }
                    Label {
                        visible: installer.log !== "" && (page.lastError !== "" || page.justFinished)
                        text: page.showLog ? qsTr("Hide details") : qsTr("Details")
                        color: "white"
                        font.underline: true
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.showLog = !page.showLog
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Label {
                        visible: !games.allDone && installer.busy && !page.preparing
                        text: qsTr("Waiting for %1 to finish…").arg(installer.currentName)
                        color: Qt.rgba(1, 1, 1, 0.7)
                    }
                }

                LogView {
                    visible: page.showLog && !page.preparing
                    text: installer.log
                    Layout.fillWidth: true
                    Layout.preferredHeight: 180
                }
            }
        }

        // Does my game work?
        Card {
            Layout.fillWidth: true

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true

                Label {
                    text: qsTr("Does your game work?")
                    font.bold: true
                    font.pointSize: LingmoUI.Theme.fontSize * 1.35
                    color: LingmoUI.Theme.textColor
                }
                Label {
                    text: qsTr("Type the name of a Windows game to see how well it runs on Linux.")
                    color: LingmoUI.Theme.disabledTextColor
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: LingmoUI.Units.largeSpacing

                TextField {
                    id: gameField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    placeholderText: qsTr("For example: Elden Ring, Counter-Strike 2, Fortnite")
                    selectByMouse: true
                    color: LingmoUI.Theme.textColor
                    placeholderTextColor: LingmoUI.Theme.disabledTextColor
                    leftPadding: 14
                    background: Rectangle {
                        radius: height / 2
                        color: LingmoUI.Theme.darkMode ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)
                        border.width: gameField.activeFocus ? 2 : 0
                        border.color: LingmoUI.Theme.highlightColor
                    }
                    onAccepted: compat.search(text)
                }
                ActionButton {
                    primary: true
                    text: qsTr("Check")
                    enabled: gameField.text.trim() !== ""
                    onClicked: compat.search(gameField.text)
                }
            }

            RowLayout {
                visible: compat.busy && compat.results.length === 0
                spacing: LingmoUI.Units.largeSpacing
                Spinner {
                    running: visible
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                }
                Label {
                    text: qsTr("Looking it up…")
                    color: LingmoUI.Theme.disabledTextColor
                }
            }

            Label {
                visible: compat.errorMessage !== ""
                text: compat.errorMessage
                color: LingmoUI.Theme.redColor
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            Repeater {
                model: compat.results

                delegate: Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: resultRow.implicitHeight + LingmoUI.Units.largeSpacing * 1.5
                    radius: LingmoUI.Theme.mediumRadius
                    color: LingmoUI.Theme.alternateBackgroundColor

                    RowLayout {
                        id: resultRow
                        anchors.fill: parent
                        anchors.margins: LingmoUI.Units.largeSpacing * 0.75
                        spacing: LingmoUI.Units.largeSpacing

                        Rectangle {
                            id: capsule
                            Layout.preferredWidth: 138
                            Layout.preferredHeight: 52
                            radius: LingmoUI.Theme.smallRadius
                            color: LingmoUI.Theme.darkMode ? "#202024" : "#dfe1e6"
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: capsule.width
                                    height: capsule.height
                                    radius: capsule.radius
                                }
                            }

                            Image {
                                anchors.fill: parent
                                source: modelData.image
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                            Image {
                                anchors.centerIn: parent
                                visible: !modelData.image
                                source: "qrc:/icons/games.svg"
                                width: 28
                                height: 28
                                sourceSize: Qt.size(56, 56)
                                opacity: 0.8
                                layer.enabled: true
                                layer.effect: ColorOverlay { color: LingmoUI.Theme.disabledTextColor }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: LingmoUI.Units.smallSpacing

                                Label {
                                    text: modelData.name
                                    font.bold: true
                                    color: LingmoUI.Theme.textColor
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                            Label {
                                visible: text !== ""
                                text: modelData.notes || ""
                                color: LingmoUI.Theme.disabledTextColor
                                wrapMode: Text.Wrap
                                font.pointSize: LingmoUI.Theme.fontSize * 0.92
                                Layout.fillWidth: true
                            }
                            Label {
                                text: modelData.antiCheatOnly ? qsTr("See details on Are We Anti-Cheat Yet")
                                                              : qsTr("See the reports on ProtonDB")
                                color: LingmoUI.Theme.highlightColor
                                font.pointSize: LingmoUI.Theme.fontSize * 0.92
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: store.openUrl(modelData.url)
                                }
                            }
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: verdictLabel.implicitWidth + 24
                            implicitHeight: 30
                            radius: 15
                            color: page.verdictColor(modelData.verdict)

                            Label {
                                id: verdictLabel
                                anchors.centerIn: parent
                                text: modelData.verdictText || ""
                                color: "white"
                                font.bold: true
                            }
                        }
                    }
                }
            }

            Label {
                text: qsTr("Ratings come from the ProtonDB community and from Are We Anti-Cheat Yet.")
                color: LingmoUI.Theme.disabledTextColor
                font.pointSize: LingmoUI.Theme.fontSize * 0.85
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }

        SectionHeader {
            text: qsTr("Native games")
            subtitle: qsTr("Classics rebuilt as native Linux programs. Bring your own copy of the game.")
            actionText: qsTr("See all")
            onActionClicked: rootWindow.showNative()
        }

        GridLayout {
            Layout.fillWidth: true
            columns: Math.max(1, Math.floor((width + columnSpacing) / (300 + columnSpacing)))
            columnSpacing: LingmoUI.Units.largeSpacing
            rowSpacing: LingmoUI.Units.largeSpacing

            Repeater {
                model: { rootWindow.rev; return catalog.nativeGames().slice(0, 3) }

                NativeGameCard {
                    game: modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 300
                }
            }
        }

        SectionHeader {
            text: qsTr("Apps for gamers")
            subtitle: qsTr("Launchers, compatibility tools and emulators")
            actionText: qsTr("All games")
            onActionClicked: rootWindow.pushCategory("games")
        }

        AppGrid {
            apps: page.apps
            Layout.fillWidth: true
            onAppClicked: (key) => rootWindow.openApp(key)
        }
    }
}
