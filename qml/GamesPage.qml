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
    property string protonError: ""

    Component.onCompleted: {
        games.refreshSteam()
        compat.loadWatchlist()
    }

    // Steam may be opened or closed while this page is shown
    Timer {
        interval: 4000
        repeat: true
        running: page.visible && (games.protonState === "running" || games.protonState === "firstrun"
                                  || games.protonState === "off")
        onTriggered: games.refreshSteam()
    }

    function toolName(tool) {
        if (tool === "proton_experimental")
            return "Proton Experimental"
        const m = /^proton_(\d+)$/.exec(tool)
        return m ? "Proton " + m[1] : tool
    }

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
        case "great": return LingmoUI.Theme.successColor
        case "tweaks": return LingmoUI.Theme.warningColor
        case "anticheat":
        case "broken": return LingmoUI.Theme.errorColor
        default: return LingmoUI.Theme.greyColor
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
                            font.pointSize: LingmoUI.Units.fontTitle
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
                            font.pointSize: LingmoUI.Units.fontCaption
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
                                    color: modelData.done ? LingmoUI.Theme.successColor : "transparent"
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
                                        font.pointSize: LingmoUI.Units.fontCaption
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

                    LightButton {
                        visible: !games.allDone
                        enabled: catalog.ready && !installer.busy && !games.detecting
                        text: page.lastError !== "" ? qsTr("Try Again") : qsTr("Get Ready for Games")
                        onClicked: {
                            page.lastError = ""
                            games.prepare()
                        }
                    }
                    LightButton {
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

        // Proton and GameMode, explained
        GridLayout {
            Layout.fillWidth: true
            columns: width > 760 ? 2 : 1
            columnSpacing: LingmoUI.Units.largeSpacing
            rowSpacing: LingmoUI.Units.largeSpacing

            LingmoUI.Card {
                id: card1
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                implicitHeight: card1Content.implicitHeight + padding * 2

                ColumnLayout {
                    id: card1Content
                    anchors.fill: parent
                    anchors.margins: card1.padding
                    spacing: LingmoUI.Units.largeSpacing

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: LingmoUI.Units.smallSpacing

                        Label {
                            text: qsTr("Proton for all games")
                            font.bold: true
                            font.pointSize: LingmoUI.Units.fontSubheading
                            color: LingmoUI.Theme.textColor
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        LingmoUI.Badge {
                            visible: games.protonState === "on" || games.protonState === "off" || games.protonState === "running"
                            text: games.protonState === "on" ? qsTr("On") : qsTr("Off")
                            tone: LingmoUI.Theme.successColor
                            subtle: games.protonState !== "on"
                        }
                    }
                    Label {
                        text: qsTr("Proton is what lets Steam run Windows games. Steam already uses it for the games Valve tested; turned on for all titles, you can install and try any other Windows game too.")
                        color: LingmoUI.Theme.secondaryTextColor
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                    Label {
                        text: {
                            switch (games.protonState) {
                            case "on": return qsTr("Turned on with %1: Steam uses it for every Windows game.").arg(page.toolName(games.protonTool))
                            case "off": return qsTr("Turned off: only the games Valve tested can be installed.")
                            case "running": return qsTr("Close Steam (Steam menu, Exit) to change this setting.")
                            case "firstrun": return qsTr("Open Steam once and sign in, then close it and come back here.")
                            case "nosteam": return qsTr("Get ready for games above first: it installs Steam.")
                            default: return qsTr("Turn it on in Steam instead (see below).")
                            }
                        }
                        color: games.protonState === "on" ? LingmoUI.Theme.successColor : LingmoUI.Theme.textColor
                        font.bold: games.protonState === "on"
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                    Label {
                        visible: page.protonError !== ""
                        text: page.protonError
                        color: LingmoUI.Theme.errorColor
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                    RowLayout {
                        spacing: LingmoUI.Units.largeSpacing
                        LingmoUI.ActionButton {
                            visible: games.protonState === "off"
                            primary: true
                            text: qsTr("Turn On for All Games")
                            onClicked: page.protonError = games.enableProtonForAll()
                        }
                        LingmoUI.ActionButton {
                            visible: games.protonState === "firstrun"
                            text: qsTr("Open Steam")
                            onClicked: store.launch(catalog.resolve("steam"), "arch")
                        }
                    }
                    Label {
                        visible: games.protonState !== "on"
                        text: qsTr("Or in Steam: Settings › Compatibility › “Enable Steam Play for all other titles”.")
                        color: LingmoUI.Theme.secondaryTextColor
                        font.pointSize: LingmoUI.Units.fontCaption
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }
            }

            LingmoUI.Card {
                id: card2
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                implicitHeight: card2Content.implicitHeight + padding * 2

                ColumnLayout {
                    id: card2Content
                    anchors.fill: parent
                    anchors.margins: card2.padding
                    spacing: LingmoUI.Units.largeSpacing

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: LingmoUI.Units.smallSpacing

                        Label {
                            text: qsTr("Game mode (GameMode)")
                            font.bold: true
                            font.pointSize: LingmoUI.Units.fontSubheading
                            color: LingmoUI.Theme.textColor
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        LingmoUI.Badge {
                            text: games.gamemodeInstalled ? qsTr("Installed") : qsTr("Not installed")
                            tone: LingmoUI.Theme.successColor
                            subtle: !games.gamemodeInstalled
                        }
                    }
                    Label {
                        text: qsTr("Puts the processor in performance mode while a game runs and back to normal when you stop, so games run smoother without wasting power the rest of the time.")
                        color: LingmoUI.Theme.secondaryTextColor
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                    Label {
                        text: games.gamemodeInstalled
                              ? qsTr("To use it with a Steam game: right-click the game › Properties › Launch options, and type:")
                              : qsTr("Get ready for games above to install it. Then, in Steam, right-click a game › Properties › Launch options, and type:")
                        color: LingmoUI.Theme.textColor
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: LingmoUI.Units.largeSpacing

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: launchOption.implicitHeight + LingmoUI.Units.smallSpacing * 2
                            radius: LingmoUI.Theme.smallRadius
                            color: LingmoUI.Theme.alternateBackgroundColor

                            Label {
                                id: launchOption
                                anchors.verticalCenter: parent.verticalCenter
                                x: LingmoUI.Units.largeSpacing
                                text: "gamemoderun %command%"
                                font.family: fixedFontFamily
                                color: LingmoUI.Theme.textColor
                            }
                        }
                        LingmoUI.ActionButton {
                            id: copyButton
                            property bool copied: false
                            text: copied ? qsTr("Copied") : qsTr("Copy")
                            onClicked: {
                                store.copyText("gamemoderun %command%")
                                copied = true
                                copiedTimer.restart()
                            }
                            Timer {
                                id: copiedTimer
                                interval: 2000
                                onTriggered: copyButton.copied = false
                            }
                        }
                    }
                    Label {
                        visible: games.gamemodeInstalled && games.gamemodeGroupMissing
                        text: qsTr("Your user is not in the “gamemode” group yet, so it can't switch the processor's mode. “Get ready for games” above adds it; then sign out and back in once.")
                        color: LingmoUI.Theme.warningColor
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // Does my game work?
        LingmoUI.Card {
            id: card3
            Layout.fillWidth: true
            implicitHeight: card3Content.implicitHeight + padding * 2

            ColumnLayout {
                id: card3Content
                anchors.fill: parent
                anchors.margins: card3.padding
                spacing: LingmoUI.Units.largeSpacing

                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true

                    Label {
                        text: qsTr("Does your game work?")
                        font.bold: true
                        font.pointSize: LingmoUI.Units.fontHeading
                        color: LingmoUI.Theme.textColor
                    }
                    Label {
                        text: qsTr("Type the name of a Windows game to see how well it runs on Linux.")
                        color: LingmoUI.Theme.secondaryTextColor
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
                        Layout.preferredHeight: LingmoUI.Units.controlHeight
                        placeholderText: qsTr("For example: Elden Ring, Counter-Strike 2, Fortnite")
                        selectByMouse: true
                        onAccepted: compat.search(text)
                    }
                    LingmoUI.ActionButton {
                        primary: true
                        text: qsTr("Check")
                        enabled: gameField.text.trim() !== ""
                        onClicked: compat.search(gameField.text)
                    }
                }

                RowLayout {
                    visible: compat.busy && compat.results.length === 0 && compat.query !== ""
                    spacing: LingmoUI.Units.largeSpacing
                    LingmoUI.Spinner {
                        running: parent.visible
                    }
                    Label {
                        text: qsTr("Looking it up…")
                        color: LingmoUI.Theme.secondaryTextColor
                    }
                }

                Label {
                    visible: compat.errorMessage !== ""
                    text: compat.errorMessage
                    color: LingmoUI.Theme.errorColor
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
                                color: LingmoUI.Theme.secondBackgroundColor
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
                                    layer.effect: ColorOverlay { color: LingmoUI.Theme.secondaryTextColor }
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
                                    color: LingmoUI.Theme.secondaryTextColor
                                    wrapMode: Text.Wrap
                                    font.pointSize: LingmoUI.Units.fontCaption
                                    Layout.fillWidth: true
                                }
                                Label {
                                    text: modelData.antiCheatOnly ? qsTr("See details on Are We Anti-Cheat Yet")
                                                                  : qsTr("See the reports on ProtonDB")
                                    color: LingmoUI.Theme.highlightColor
                                    font.pointSize: LingmoUI.Units.fontCaption
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: store.openUrl(modelData.url)
                                    }
                                }
                            }

                            LingmoUI.Badge {
                                Layout.alignment: Qt.AlignVCenter
                                text: modelData.verdictText || ""
                                tone: page.verdictColor(modelData.verdict)
                                font.pointSize: LingmoUI.Units.fontBody
                            }
                        }
                    }
                }

                Label {
                    text: qsTr("Ratings come from the ProtonDB community and from Are We Anti-Cheat Yet.")
                    color: LingmoUI.Theme.secondaryTextColor
                    font.pointSize: LingmoUI.Units.fontCaption
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }
        }

        // Online games whose anti-cheat keeps Linux out
        LingmoUI.Card {
            id: card4
            visible: compat.blockedGames.length > 0
            Layout.fillWidth: true
            implicitHeight: card4Content.implicitHeight + padding * 2

            ColumnLayout {
                id: card4Content
                anchors.fill: parent
                anchors.margins: card4.padding
                spacing: LingmoUI.Units.largeSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: LingmoUI.Units.largeSpacing

                    LingmoUI.IconItem {
                        source: "dialog-warning"
                        Layout.preferredWidth: LingmoUI.Units.iconSizes.medium
                        Layout.preferredHeight: LingmoUI.Units.iconSizes.medium
                        Layout.alignment: Qt.AlignTop
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Label {
                            text: qsTr("Popular games that don't work on Linux")
                            font.bold: true
                            font.pointSize: LingmoUI.Units.fontSubheading
                            color: LingmoUI.Theme.textColor
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                        Label {
                            text: qsTr("Their anti-cheat blocks Linux, so they can't be played online here, not even with Proton. Check before buying.")
                            color: LingmoUI.Theme.secondaryTextColor
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: LingmoUI.Units.smallSpacing

                    Repeater {
                        model: compat.blockedGames

                        delegate: Rectangle {
                            width: blockedCol.implicitWidth + LingmoUI.Units.largeSpacing * 2
                            height: blockedCol.implicitHeight + LingmoUI.Units.smallSpacing * 2
                            radius: LingmoUI.Theme.mediumRadius
                            color: blockedMouse.containsMouse
                                   ? Qt.rgba(LingmoUI.Theme.errorColor.r, LingmoUI.Theme.errorColor.g, LingmoUI.Theme.errorColor.b, LingmoUI.Theme.darkMode ? 0.3 : 0.18)
                                   : Qt.rgba(LingmoUI.Theme.errorColor.r, LingmoUI.Theme.errorColor.g, LingmoUI.Theme.errorColor.b, LingmoUI.Theme.darkMode ? 0.18 : 0.1)

                            Behavior on color { ColorAnimation { duration: LingmoUI.Units.veryShortDuration } }

                            Column {
                                id: blockedCol
                                anchors.centerIn: parent
                                spacing: 1

                                Label {
                                    text: modelData.name
                                    font.bold: true
                                    color: LingmoUI.Theme.textColor
                                }
                                Label {
                                    text: modelData.reason + (modelData.anticheats ? " · " + modelData.anticheats : "")
                                    color: LingmoUI.Theme.secondaryTextColor
                                    font.pointSize: LingmoUI.Units.fontCaption
                                }
                            }

                            MouseArea {
                                id: blockedMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: store.openUrl(modelData.url)
                            }
                        }
                    }
                }

                Label {
                    text: qsTr("Status from Are We Anti-Cheat Yet. Search any other game above.")
                    color: LingmoUI.Theme.secondaryTextColor
                    font.pointSize: LingmoUI.Units.fontCaption
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
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
