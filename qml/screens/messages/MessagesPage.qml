pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Messages, for coaches and clients alike. Wide window: the conversations on
// the left (current ones, then a collapsed list of past ones) and the chosen
// chat on the right. Phone: the list, then the chat with a back button.
Item {
    id: page

    // Coach: one conversation per client. Client: their coach, and past coaches.
    property bool coach: true

    readonly property bool wide: width >= 760
    readonly property var current: MessageStore.conversations.filter(c => c.open)
    readonly property var past: MessageStore.conversations.filter(c => !c.open)
    readonly property bool chatShown: MessageStore.selectedId.length > 0
    property bool pastExpanded: false

    // Client without a coach: go to the directory
    signal findCoachRequested()

    function choose(id) {
        MessageStore.open(id)
    }

    // A single conversation (a client with one coach) opens by itself on a
    // wide window
    function autoSelect() {
        if (wide && visible && !chatShown && MessageStore.conversations.length === 1)
            choose(MessageStore.conversations[0].id)
    }

    onVisibleChanged: autoSelect()
    onWideChanged: autoSelect()
    Connections {
        target: MessageStore
        function onRevisionChanged() {
            page.autoSelect()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ---- conversation list ----
        Rectangle {
            visible: page.wide || !page.chatShown
            Layout.preferredWidth: page.wide ? 340 : -1
            Layout.fillWidth: !page.wide
            Layout.fillHeight: true
            color: Theme.surface

            Rectangle {
                visible: page.wide
                anchors.right: parent.right
                width: 1
                height: parent.height
                color: Theme.border
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Label {
                    text: qsTr("Messages")
                    font.pixelSize: Theme.fontTitle
                    font.weight: Font.Bold
                    Layout.leftMargin: 20
                    Layout.topMargin: 20
                    Layout.bottomMargin: 12
                }

                ScrollView {
                    id: listScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: listScroll.availableWidth
                        spacing: 2

                        Repeater {
                            model: page.current
                            ConversationRow {
                                required property var modelData
                                conversation: modelData
                                selected: page.wide && modelData.id === MessageStore.selectedId
                                Layout.fillWidth: true
                                Layout.leftMargin: 8
                                Layout.rightMargin: 8
                                onClicked: page.choose(modelData.id)
                            }
                        }

                        AuraButton {
                            visible: page.past.length > 0
                            variant: "ghost"
                            text: (page.pastExpanded ? "▾ " : "▸ ")
                                  + (page.coach ? qsTr("Past clients (%1)") : qsTr("Past coaches (%1)")).arg(page.past.length)
                            Layout.leftMargin: 8
                            Layout.topMargin: 12
                            onClicked: page.pastExpanded = !page.pastExpanded
                        }

                        Repeater {
                            model: page.pastExpanded ? page.past : []
                            ConversationRow {
                                required property var modelData
                                conversation: modelData
                                selected: page.wide && modelData.id === MessageStore.selectedId
                                Layout.fillWidth: true
                                Layout.leftMargin: 8
                                Layout.rightMargin: 8
                                onClicked: page.choose(modelData.id)
                            }
                        }

                        EmptyState {
                            visible: MessageStore.conversations.length === 0 && !MessageStore.loading
                            title: page.coach ? qsTr("No clients yet") : qsTr("No coach yet")
                            message: page.coach
                                     ? qsTr("When you have clients, you can message each of them here.")
                                     : qsTr("Once you have a coach, you can message them here.")
                            Layout.fillWidth: true
                            Layout.margins: 24
                            Layout.topMargin: 48

                            AuraButton {
                                visible: !page.coach
                                text: qsTr("Find a coach")
                                onClicked: page.findCoachRequested()
                            }
                        }
                    }
                }
            }
        }

        // ---- chat ----
        Item {
            visible: page.wide || page.chatShown
            Layout.fillWidth: true
            Layout.fillHeight: true

            MessageThread {
                anchors.fill: parent
                visible: page.chatShown
                conversationId: MessageStore.selectedId
                showBack: !page.wide
                onBackRequested: MessageStore.selectedId = ""
            }

            EmptyState {
                visible: !page.chatShown && MessageStore.conversations.length > 0
                anchors.centerIn: parent
                width: Math.min(parent.width - 48, 340)
                title: qsTr("Your messages")
                message: page.coach ? qsTr("Choose a client on the left to see your conversation.")
                                    : qsTr("Choose a conversation on the left.")
            }
        }
    }
}
