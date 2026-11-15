pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Frame shared by the coach app and the client app.
//  - wide window (desktop): sidebar with navigation, theme toggle, user, log out
//  - narrow window (phone): top bar + bottom tab bar
// Pages are declared as children and shown one at a time by currentIndex.
Item {
    id: shell

    property var navItems: []          // list of page titles
    property var compactNavItems: navItems   // shorter titles for the phone tab bar
    property var navBadges: []               // per nav item (same order): list of { count, tone, label } (see NavButton)
    property int currentIndex: 0
    property string roleLabel: ""
    default property alias pages: pageStack.data

    readonly property bool wide: width >= 820

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
                        current: sideNavButton.index === shell.currentIndex
                        onClicked: shell.currentIndex = sideNavButton.index
                    }
                }

                Item { Layout.fillHeight: true }

                AuraButton {
                    Layout.fillWidth: true
                    variant: "ghost"
                    text: Theme.dark ? qsTr("Switch to light mode") : qsTr("Switch to dark mode")
                    onClicked: Theme.dark = !Theme.dark
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
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: shell.currentIndex
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
                            current: tabButton.index === shell.currentIndex
                            onClicked: shell.currentIndex = tabButton.index
                        }
                    }
                }
            }
        }
    }
}
