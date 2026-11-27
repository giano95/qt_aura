pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Frame shared by the coach app and the client app.
//  - wide window (desktop): sidebar with navigation, Settings, user, log out
//  - narrow window (phone): top bar (Settings, log out) + bottom tab bar
// Pages are declared as children and shown one at a time by currentIndex.
// Settings isn't one of them (tab indexes stay the same): it covers the
// current page until a tab is picked.
Item {
    id: shell

    property var navItems: []          // list of page titles
    property var compactNavItems: navItems   // shorter titles for the phone tab bar
    property var navBadges: []               // per nav item (same order): list of { count, tone, label } (see NavButton)
    property int currentIndex: 0
    property string roleLabel: ""
    // Index of the Messages page: a message arriving while its chat isn't on
    // screen pops up a MessageToast that opens it. -1 = no pop-ups.
    property int messagesIndex: -1
    // The Settings page is shown instead of the current page
    property bool settingsOpen: false
    default property alias pages: pageStack.data

    readonly property bool wide: width >= 820

    // Going to a page (a tab, a link inside a page, a pop-up) closes Settings
    onCurrentIndexChanged: settingsOpen = false

    function showPage(index) {
        settingsOpen = false
        currentIndex = index
    }

    MessageToast {
        id: messageToast
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 16
        anchors.bottomMargin: shell.wide ? 16 : 76
        onOpenRequested: id => {
            MessageStore.open(id)
            shell.showPage(shell.messagesIndex)
        }
    }

    Connections {
        target: MessageStore
        enabled: shell.messagesIndex >= 0
        function onMessageReceived(conversationId, senderName, body) {
            if (!shell.settingsOpen && shell.currentIndex === shell.messagesIndex
                    && MessageStore.selectedId === conversationId)
                return
            messageToast.show(conversationId, senderName, body)
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ---- sidebar (desktop) ----
        Rectangle {
            visible: shell.wide
            Layout.fillHeight: true
            Layout.preferredWidth: 248
            color: Theme.surface

            Rectangle {
                anchors.right: parent.right
                width: 1
                height: parent.height
                color: Theme.border
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 4

                RowLayout {
                    spacing: 10
                    Layout.leftMargin: 6
                    Layout.topMargin: 6
                    Layout.bottomMargin: 24

                    BrandMark { size: 28 }
                    Label {
                        text: "Aura"
                        font.pixelSize: 20
                        font.weight: Font.Bold
                    }
                    Chip {
                        text: shell.roleLabel
                        tone: "primary"
                    }
                }

                Repeater {
                    model: shell.navItems
                    NavButton {
                        id: sideNavButton
                        required property int index
                        required property string modelData
                        Layout.fillWidth: true
                        text: modelData
                        badges: shell.navBadges[sideNavButton.index] || []
                        current: sideNavButton.index === shell.currentIndex && !shell.settingsOpen
                        onClicked: shell.showPage(sideNavButton.index)
                    }
                }

                Item { Layout.fillHeight: true }

                NavButton {
                    Layout.fillWidth: true
                    text: qsTr("Settings")
                    current: shell.settingsOpen
                    onClicked: shell.settingsOpen = true
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    Layout.bottomMargin: 12
                    implicitHeight: 1
                    color: Theme.border
                }

                RowLayout {
                    spacing: 10
                    Layout.fillWidth: true

                    Avatar { name: Session.loggedIn ? Session.user.name : "" }
                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true
                        Label {
                            text: Session.loggedIn ? Session.user.name : ""
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: Session.loggedIn ? Session.user.email : ""
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSmall
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                AuraButton {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    variant: "secondary"
                    text: qsTr("Log out")
                    onClicked: Session.logout()
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ---- top bar (phone) ----
            Rectangle {
                visible: !shell.wide
                Layout.fillWidth: true
                implicitHeight: 56
                color: Theme.surface

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.border
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 8
                    spacing: 10

                    BrandMark { size: 24 }
                    Label {
                        text: "Aura"
                        font.pixelSize: 18
                        font.weight: Font.Bold
                    }
                    Chip {
                        text: shell.roleLabel
                        tone: "primary"
                    }
                    Item { Layout.fillWidth: true }
                    AuraButton {
                        variant: shell.settingsOpen ? "secondary" : "ghost"
                        text: qsTr("Settings")
                        leftPadding: 10
                        rightPadding: 10
                        Accessible.checked: shell.settingsOpen
                        onClicked: shell.settingsOpen = true
                    }
                    AuraButton {
                        variant: "ghost"
                        text: qsTr("Log out")
                        leftPadding: 10
                        rightPadding: 10
                        onClicked: Session.logout()
                    }
                }
            }

            StackLayout {
                id: pageStack
                visible: !shell.settingsOpen
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: shell.currentIndex
            }

            SettingsPage {
                visible: shell.settingsOpen
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            // ---- tab bar (phone) ----
            Rectangle {
                visible: !shell.wide
                Layout.fillWidth: true
                implicitHeight: 60
                color: Theme.surface

                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1
                    color: Theme.border
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    Repeater {
                        model: shell.compactNavItems
                        NavButton {
                            id: tabButton
                            required property int index
                            required property string modelData
                            compact: true
                            compactFontSize: shell.navItems.length > 5 ? 11 : Theme.fontSmall
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: modelData
                            badges: shell.navBadges[tabButton.index] || []
                            current: tabButton.index === shell.currentIndex && !shell.settingsOpen
                            onClicked: shell.showPage(tabButton.index)
                        }
                    }
                }
            }
        }
    }
}
