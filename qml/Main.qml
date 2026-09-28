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

LingmoUI.Window {
    id: rootWindow

    width: 1180
    height: 760
    minimumWidth: 920
    minimumHeight: 600
    visible: false
    title: qsTr("App Store")

    background.opacity: LingmoUI.Theme.darkMode ? 0.9 : 0.98
    header.height: 50
    contentTopMargin: 0

    // Bumped whenever the catalog or what's installed changes: pages re-query
    property int rev: 0
    property string pendingApp: ""
    property string pendingSearch: ""
    property bool pendingGames: false
    property string consentKey: ""   // Flathub app waiting for the user to enable Flathub
    property string removeKey: ""
    property string removeSource: ""
    property string removePackageName: ""   // a native game package instead of an app

    LingmoUI.WindowBlur {
        view: rootWindow
        geometry: Qt.rect(rootWindow.x, rootWindow.y, rootWindow.width, rootWindow.height)
        windowRadius: rootWindow.windowRadius
        enabled: true
    }

    Connections {
        target: catalog
        function onChanged() {
            rootWindow.rev++
            rootWindow.processPending()
        }
        function onInstalledChanged() { rootWindow.rev++ }
    }

    Connections {
        target: flatpak
        function onStateChanged() {
            rootWindow.rev++
            if (flatpak.state === Flatpak.Ready && rootWindow.consentKey !== "") {
                installer.install(rootWindow.consentKey, "flathub")
                rootWindow.consentKey = ""
            }
        }
        function onRemoteAdded(ok, error) {
            if (!ok)
                rootWindow.showPassiveNotification(error, 6000)
        }
    }

    Connections {
        target: installer
        function onFlathubConsentNeeded(key) {
            rootWindow.consentKey = key
            consentDialog.open()
        }
        function onFinished(key, source, action, ok, message) {
            rootWindow.rev++
            const top = stack.currentItem
            const shownThere = top && ((top.appKey !== undefined && top.appKey === key)
                                       || (action === "gaming" && top.pageName === "games"))
            if (!shownThere) {
                if (!ok && message !== "")
                    rootWindow.showPassiveNotification(message, 6000)
                else if (ok && action === "install")
                    rootWindow.showPassiveNotification(qsTr("%1 is installed").arg(installer.currentName), 4000)
            }
        }
    }

    Connections {
        target: store
        function onAppRequested(query) {
            rootWindow.pendingApp = query
            rootWindow.processPending()
        }
        function onSearchRequested(text) {
            rootWindow.pendingApp = ""
            rootWindow.showSearch(text)
        }
        function onGamesRequested() {
            rootWindow.showGames()
        }
    }

    function processPending() {
        if (!catalog.ready || pendingApp === "")
            return
        const query = pendingApp
        pendingApp = ""
        const key = catalog.resolve(query)
        if (key !== "") {
            openApp(key)
        } else {
            // Unknown here: search for its name instead
            let text = query.replace(/^appstream:\/*/i, "").replace(/^app\//, "").split("/")[0]
            const parts = text.split(".")
            if (parts.length > 2)
                text = parts[parts.length - 1]
            showSearch(text)
        }
    }

    function navigate(name) {
        if (name === "updates") {
            store.openUpdater()
            showPassiveNotification(qsTr("Updates are installed by the Updates app."), 3000)
            return
        }
        searchField.clearSilently()
        stack.clear()
        if (name === "home")
            stack.push("qrc:/qml/HomePage.qml")
        else if (name === "games")
            stack.push("qrc:/qml/GamesPage.qml")
        else if (name === "installed")
            stack.push("qrc:/qml/InstalledPage.qml")
        else if (name === "native")
            stack.push("qrc:/qml/NativeGamesPage.qml")
        else {
            const info = sideBar.categoryInfo(name)
            stack.push("qrc:/qml/CategoryPage.qml", { category: name, title: info ? info.title : name,
                                                      tint: info ? info.iconColor : LingmoUI.Theme.highlightColor })
        }
    }

    function showHome() {
        sideBar.select("home")
        navigate("home")
    }

    function showGames() {
        sideBar.select("games")
        navigate("games")
    }

    function showNative() {
        sideBar.select("native")
        navigate("native")
    }

    // "You need your own copy of the game"; with a package, installs it after
    property var ownCopyGame: null
    function showOwnCopy(game, install) {
        ownCopyGame = install ? game : null
        ownCopyDialog.showReject = install
        ownCopyDialog.acceptText = install ? qsTr("Install") : qsTr("OK")
        ownCopyDialog.open()
    }

    function installNative(game) {
        if (game.needsOwnCopy)
            showOwnCopy(game, true)
        else
            installer.installPackage(game.pkg, game.name)
    }

    function showCategory(name) {
        sideBar.select(name)
        navigate(name)
    }

    // A category page on top of the current one (e.g. all games from the games page)
    function pushCategory(name) {
        const info = sideBar.categoryInfo(name)
        stack.push("qrc:/qml/CategoryPage.qml", { category: name, title: info ? info.title : name,
                                                  tint: info ? info.iconColor : LingmoUI.Theme.highlightColor })
    }

    function openApp(key) {
        const top = stack.currentItem
        if (top && top.appKey === key)
            return
        stack.push("qrc:/qml/AppPage.qml", { appKey: key })
    }

    function showSearch(text) {
        searchField.text = text
        searchField.forceActiveFocus()
        runSearch()
    }

    function runSearch() {
        const text = searchField.text.trim()
        const top = stack.currentItem
        const onSearch = top && top.pageName === "search"
        if (text === "") {
            if (onSearch)
                stack.pop()
            return
        }
        if (onSearch)
            top.query = text
        else
            stack.push("qrc:/qml/SearchPage.qml", { query: text })
    }

    function askRemovePackage(pkg, name) {
        removePackageName = pkg
        removeKey = name
        removeDialog.title = qsTr("Remove %1?").arg(name)
        removeDialog.open()
    }

    function askRemove(key, source, name) {
        removePackageName = ""
        removeKey = key
        removeSource = source
        removeDialog.title = qsTr("Remove %1?").arg(name)
        removeDialog.open()
    }

    headerItem: Item {
        id: headerBar

        property real originX: 0
        function updateOrigin() { originX = mapToItem(null, 0, 0).x }
        Component.onCompleted: Qt.callLater(updateOrigin)
        onWidthChanged: Qt.callLater(updateOrigin)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Math.max(0, sideBar.width - headerBar.originX) + LingmoUI.Units.largeSpacing * 1.5
            anchors.rightMargin: LingmoUI.Units.largeSpacing * 2
            spacing: LingmoUI.Units.largeSpacing

            // Back
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 16
                visible: stack.depth > 1
                color: backMouse.containsMouse ? LingmoUI.Theme.alternateBackgroundColor : "transparent"

                Image {
                    anchors.centerIn: parent
                    source: "qrc:/icons/back.svg"
                    width: 18
                    height: 18
                    sourceSize: Qt.size(36, 36)
                }
                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (stack.currentItem && stack.currentItem.pageName === "search")
                            searchField.clearSilently()
                        stack.pop()
                    }
                }
            }

            Item { Layout.fillWidth: true }

            TextField {
                id: searchField
                Layout.preferredWidth: Math.min(460, headerBar.width * 0.5)
                Layout.preferredHeight: 34
                placeholderText: qsTr("Search apps")
                leftPadding: 36
                rightPadding: 30
                selectByMouse: true
                color: LingmoUI.Theme.textColor
                placeholderTextColor: LingmoUI.Theme.disabledTextColor
                font.pointSize: LingmoUI.Theme.fontSize

                property bool silent: false
                function clearSilently() {
                    silent = true
                    text = ""
                    silent = false
                }

                background: Rectangle {
                    radius: height / 2
                    color: LingmoUI.Theme.darkMode ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)
                    border.width: searchField.activeFocus ? 2 : 0
                    border.color: LingmoUI.Theme.highlightColor

                    Image {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        source: "qrc:/icons/search.svg"
                        width: 16
                        height: 16
                        sourceSize: Qt.size(32, 32)
                    }
                }

                Label {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchField.text !== ""
                    text: "✕"
                    color: LingmoUI.Theme.disabledTextColor

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: searchField.text = ""
                    }
                }

                onTextChanged: if (!silent) searchTimer.restart()
                Keys.onEscapePressed: text = ""
                Keys.onReturnPressed: {
                    searchTimer.stop()
                    rootWindow.runSearch()
                }
            }

            Item { Layout.fillWidth: true }

            Badge {
                visible: store.fakeMode
                text: qsTr("Test mode")
                tint: LingmoUI.Theme.orangeColor
                filled: true
            }

            Item {
                Layout.preferredWidth: 32
                visible: !store.fakeMode
            }
        }

        Timer {
            id: searchTimer
            interval: 150
            onTriggered: rootWindow.runSearch()
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        SideBar {
            id: sideBar
            Layout.fillHeight: true
            onActivated: (name) => rootWindow.navigate(name)
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StackView {
                id: stack
                anchors.fill: parent
                anchors.topMargin: rootWindow.header.height
                clip: true
                initialItem: "qrc:/qml/HomePage.qml"

                pushEnter: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140 }
                }
                pushExit: Transition {
                    NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
                }
                popEnter: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140 }
                }
                popExit: Transition {
                    NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
                }
                replaceEnter: Transition {}
                replaceExit: Transition {}
            }
        }
    }

    StoreDialog {
        id: consentDialog
        iconName: "system-software-install"
        title: qsTr("Turn on Flathub?")
        text: qsTr("Flathub is the app store of the Linux world, with thousands of apps such as Spotify, Discord and Zoom. Its apps run isolated from the rest of the system.<br><br>Turn it on to install this app?")
        acceptText: qsTr("Turn On Flathub")
        rejectText: qsTr("Not Now")
        onAccepted: flatpak.addFlathub()
        onRejected: rootWindow.consentKey = ""
    }

    StoreDialog {
        id: ownCopyDialog
        iconName: "media-flash"
        title: qsTr("You need your own copy of the game")
        text: qsTr("The program is free, but the game itself (its graphics, music and levels) belongs to the publisher and is not included.<br><br>To play, copy your own cartridge to a file with a cartridge reader such as GB Operator or Sanni Cart Reader, or use the files of the version you bought.<br><br>The first time you open the program, it asks for that file and builds the game from it.")
        rejectText: qsTr("Cancel")
        onAccepted: {
            if (rootWindow.ownCopyGame)
                installer.installPackage(rootWindow.ownCopyGame.pkg, rootWindow.ownCopyGame.name)
            rootWindow.ownCopyGame = null
        }
        onRejected: rootWindow.ownCopyGame = null
    }

    StoreDialog {
        id: removeDialog
        iconName: "edit-delete"
        text: qsTr("Your own files and documents are not deleted.")
        acceptText: qsTr("Remove")
        destructive: true
        onAccepted: {
            if (rootWindow.removePackageName !== "")
                installer.removePackage(rootWindow.removePackageName, rootWindow.removeKey)
            else
                installer.remove(rootWindow.removeKey, rootWindow.removeSource)
        }
    }

    Shortcut {
        sequences: [StandardKey.Find]
        onActivated: searchField.forceActiveFocus()
    }
    Shortcut {
        sequence: "Alt+Left"
        onActivated: if (stack.depth > 1) stack.pop()
    }
}
