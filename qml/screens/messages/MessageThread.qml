pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// The open conversation: who it's with, the messages (newest at the bottom,
// a day label where the day changes) and the box to write in. Ended
// coachings are read-only. Messages count as read while this is on screen and
// the app is in front. Each conversation keeps its unsent draft.
Item {
    id: thread

    property string conversationId: ""
    property bool showBack: false

    readonly property var conversation: MessageStore.conversationById(conversationId, MessageStore.revision)
    readonly property var messages: MessageStore.messages(conversationId, MessageStore.revision)
    readonly property bool fetching: MessageStore.isFetching(conversationId, MessageStore.revision)
    readonly property bool onScreen: visible && Qt.application.state === Qt.ApplicationActive
    // Newest first, for the bottom-to-top list
    readonly property var items: {
        const out = []
        for (let i = messages.length - 1; i >= 0; --i)
            out.push(messages[i])
        return out
    }

    property var drafts: ({})
    property string draftOwner: ""

    signal backRequested()

    function markReadIfNeeded() {
        if (onScreen && conversation && conversation.unread > 0 && !fetching)
            MessageStore.markRead(conversationId)
    }

    onOnScreenChanged: markReadIfNeeded()
    onConversationIdChanged: {
        if (draftOwner.length > 0)
            drafts[draftOwner] = composer.text
        composer.text = drafts[conversationId] || ""
        draftOwner = conversationId
        markReadIfNeeded()
    }

    Connections {
        target: MessageStore
        function onRevisionChanged() {
            thread.markReadIfNeeded()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---- header ----
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 64
            color: Theme.surface

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.border
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: thread.showBack ? 4 : 20
                anchors.rightMargin: 20
                spacing: 12

                AuraButton {
                    visible: thread.showBack
                    variant: "ghost"
                    text: qsTr("←")
                    leftPadding: 12
                    rightPadding: 12
                    Accessible.name: qsTr("Back to conversations")
                    onClicked: thread.backRequested()
                }
                Avatar {
                    name: thread.conversation ? thread.conversation.otherName : ""
                    size: 38
                }
                Label {
                    text: thread.conversation ? thread.conversation.otherName : ""
                    font.pixelSize: Theme.fontLarge
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Chip {
                    visible: thread.conversation !== null && !thread.conversation.open
                    text: qsTr("Coaching ended")
                }
            }
        }

        // ---- messages ----
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Faint fitness doodles repeated behind the messages, like
            // WhatsApp's chat background (made by tools/chat_pattern.py; Qt
            // picks the @2x tile on high-DPI screens)
            Image {
                anchors.fill: parent
                source: "qrc:/assets/chat/pattern-" + (Theme.dark ? "dark" : "light") + ".png"
                fillMode: Image.Tile
                horizontalAlignment: Image.AlignLeft
                verticalAlignment: Image.AlignTop
                opacity: Theme.chatPatternOpacity
                cache: true
            }

            ListView {
                id: list

                readonly property real bubbleWidth: Math.min(width * 0.75, 560)

                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                verticalLayoutDirection: ListView.BottomToTop
                clip: true
                spacing: 4
                model: thread.items
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}

                header: Item { height: 12 }

                // At the top (the list grows upwards)
                footer: Item {
                    width: list.width
                    height: MessageStore.hasOlder(thread.conversationId, MessageStore.revision) ? 52 : 12

                    AuraButton {
                        anchors.centerIn: parent
                        visible: MessageStore.hasOlder(thread.conversationId, MessageStore.revision)
                        variant: "ghost"
                        text: qsTr("Show earlier messages")
                        onClicked: MessageStore.loadOlder(thread.conversationId)
                    }
                }

                delegate: ColumnLayout {
                    id: entry

                    required property var modelData
                    required property int index

                    // The message above it (older), if any
                    readonly property var older: index + 1 < thread.items.length ? thread.items[index + 1] : null
                    readonly property bool newDay: older === null
                                                   || !MessageStore.sameDay(older.createdAt, modelData.createdAt)
                    readonly property bool newGroup: newDay || older.mine !== modelData.mine
                                                     || modelData.createdAt - older.createdAt > 5 * 60 * 1000

                    width: list.width
                    spacing: 0

                    Label {
                        visible: entry.newDay
                        text: MessageStore.dayLabel(entry.modelData.createdAt)
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSmall
                        font.weight: Font.DemiBold
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 16
                        Layout.bottomMargin: 8
                    }
                    MessageBubble {
                        message: entry.modelData
                        maxBubbleWidth: list.bubbleWidth
                        Layout.fillWidth: true
                        Layout.topMargin: entry.newGroup && !entry.newDay ? 8 : 0
                        onRetryRequested: MessageStore.retry(entry.modelData.id)
                        onDiscardRequested: MessageStore.discard(entry.modelData.id)
                    }
                }
            }

            BusyIndicator {
                anchors.centerIn: parent
                running: thread.fetching
                visible: running
            }

            EmptyState {
                anchors.centerIn: parent
                width: Math.min(parent.width - 48, 340)
                visible: !thread.fetching && thread.messages.length === 0 && thread.conversation !== null
                title: thread.conversation && thread.conversation.open
                       ? qsTr("Say hello to %1").arg(thread.conversation.otherName)
                       : qsTr("No messages")
                message: thread.conversation && thread.conversation.open
                         ? qsTr("Messages you send here are only seen by the two of you.")
                         : ""
            }
        }

        // ---- write ----
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: (thread.conversation && thread.conversation.open ? composer.implicitHeight : closedLabel.implicitHeight) + 24
            color: Theme.surface

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: Theme.border
            }

            MessageComposer {
                id: composer
                visible: thread.conversation !== null && thread.conversation.open
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                onSendRequested: text => {
                    MessageStore.send(thread.conversationId, text)
                    list.positionViewAtBeginning()
                }
            }

            Label {
                id: closedLabel
                visible: !composer.visible
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                text: qsTr("This coaching has ended. You can read the conversation, but not reply.")
                color: Theme.textMuted
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
