pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Client landing page: next session, today's actions, goals, latest coach message.
ScrollView {
    id: page

    signal navigateRequested(int index)

    // Client app tab indices (see ClientHome)
    readonly property int coachTab: 1
    readonly property int calendarTab: 2
    readonly property int messagesTab: 5

    readonly property var coach: CoachStore.myCoach
    readonly property string coachName: coach ? coach.name : MockData.clientCoachName
    // The conversation with the current coach, or null
    readonly property var chat: MessageStore.currentConversation(MessageStore.revision)

    function openChat() {
        if (chat)
            MessageStore.open(chat.id)
        navigateRequested(messagesTab)
    }

    readonly property bool twoColumns: availableWidth >= 860
    // The client's next confirmed or pending session (CalendarStore)
    readonly property var booked: Session.loggedIn ? CalendarStore.nextSessionFor(Session.user.email, Session.user.name, CalendarStore.revision) : null
    readonly property bool hasNext: booked !== null
    readonly property var nextSession: hasNext
        ? { date: new Date(CalendarStore.startMs(booked)), duration: qsTr("%1 min").arg(booked.end - booked.start),
            topic: booked.type, mode: booked.mode, pending: booked.status === "pending" }
        : { date: new Date(), duration: "", topic: "", mode: "", pending: false }

    // The program stat comes from the coach's assignment; the rest is sample data
    readonly property var me: Session.loggedIn ? ClientStore.clientByEmail(Session.user.email, ClientStore.revision) : null
    readonly property var programStatus: me ? ClientStore.programStatus(me) : ({ kind: "none", assignment: null })
    readonly property var stats: {
        const list = MockData.clientStats.slice(0, 2)
        const s = programStatus
        let stat
        if (s.kind === "active" || s.kind === "endingSoon")
            stat = { value: qsTr("Week %1").arg(s.week), note: qsTr("of %1 · %2").arg(s.assignment.weeks).arg(s.assignment.programName), tone: "neutral" }
        else if (s.kind === "scheduled")
            stat = { value: qsTr("Starts soon"), note: ClientStore.statusText(s), tone: "primary" }
        else if (s.kind === "expired")
            stat = { value: qsTr("Finished"), note: qsTr("Your coach will set up the next one"), tone: "accent" }
        else
            stat = { value: qsTr("None yet"), note: qsTr("Your coach will assign one"), tone: "neutral" }
        stat.label = qsTr("Current program")
        list.push(stat)
        return list
    }

    property ListModel todayModel: ListModel {
        ListElement { title: qsTr("Morning check-in: mood and energy"); done: true }
        ListElement { title: qsTr("30-minute walk"); done: true }
        ListElement { title: qsTr("Read: \"Building habits that stick\""); done: false }
        ListElement { title: qsTr("Write down one thing that felt hard this week"); done: false }
    }
    property int doneCount: 0

    function recount() {
        let n = 0
        for (let i = 0; i < todayModel.count; ++i)
            if (todayModel.get(i).done)
                ++n
        doneCount = n
    }

    Component.onCompleted: recount()

    contentWidth: availableWidth
    padding: width < 600 ? 16 : 32

    ColumnLayout {
        width: page.availableWidth
        spacing: 24

        GreetingHeader {
            Layout.fillWidth: true
            name: Session.firstName
            subtitle: page.coach ? qsTr("Coached by %1").arg(page.coach.name)
                                 : qsTr("You don't have a coach yet")

            AuraButton {
                variant: page.coach ? "secondary" : "primary"
                text: page.coach ? qsTr("Message coach") : qsTr("Find a coach")
                onClicked: page.coach ? page.openChat() : page.navigateRequested(page.coachTab)
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: page.availableWidth >= 560 ? 3 : 1
            columnSpacing: 16
            rowSpacing: 16

            Repeater {
                model: page.stats
                StatCard {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    label: modelData.label
                    value: modelData.value
                    note: modelData.note
                    tone: modelData.tone
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: page.twoColumns ? 2 : 1
            columnSpacing: 16
            rowSpacing: 16

            // ---- next session ----
            Card {
                title: qsTr("Next session")
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1

                RowLayout {
                    visible: page.hasNext
                    spacing: 16
                    Layout.fillWidth: true

                    Rectangle {
                        implicitWidth: 64
                        implicitHeight: 72
                        radius: 12
                        color: page.nextSession.pending ? Theme.accentSoft : Theme.primarySoft

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 0

                            Label {
                                text: Qt.formatDate(page.nextSession.date, "MMM").toUpperCase()
                                color: page.nextSession.pending ? Theme.accent : Theme.primary
                                font.pixelSize: Theme.fontSmall
                                font.weight: Font.DemiBold
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Label {
                                text: Qt.formatDate(page.nextSession.date, "d")
                                color: page.nextSession.pending ? Theme.accent : Theme.primary
                                font.pixelSize: 26
                                font.weight: Font.Bold
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 4
                        Layout.fillWidth: true

                        Label {
                            text: page.nextSession.topic
                            font.pixelSize: Theme.fontLarge
                            font.weight: Font.DemiBold
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                        Label {
                            text: Qt.formatDate(page.nextSession.date, "dddd") + ", "
                                  + Qt.formatTime(page.nextSession.date, "HH:mm")
                                  + " · " + page.nextSession.duration
                            color: Theme.textMuted
                            Layout.fillWidth: true
                        }
                        Label {
                            text: qsTr("%1 with %2").arg(page.nextSession.mode).arg(page.coachName)
                            color: Theme.textMuted
                            Layout.fillWidth: true
                        }
                        Chip {
                            visible: page.nextSession.pending
                            text: qsTr("Waiting for confirmation")
                            tone: "accent"
                            Layout.topMargin: 2
                        }
                    }
                }

                Label {
                    visible: !page.hasNext
                    text: page.coach ? qsTr("No session booked.") : qsTr("Book sessions once you have a coach.")
                    color: Theme.textMuted
                }

                RowLayout {
                    spacing: 8
                    AuraButton {
                        visible: page.hasNext && page.nextSession.mode === qsTr("Video call") && !page.nextSession.pending
                        text: qsTr("Join call")
                        enabled: false
                    }
                    AuraButton {
                        visible: page.coach !== null
                        variant: page.hasNext ? "secondary" : "primary"
                        text: page.hasNext ? qsTr("Open calendar") : qsTr("Book a session")
                        onClicked: page.navigateRequested(page.calendarTab)
                    }
                }
                Label {
                    visible: page.hasNext && page.nextSession.mode === qsTr("Video call") && !page.nextSession.pending
                    text: qsTr("The call link opens 10 minutes before the start.")
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }

            // ---- today's actions ----
            Card {
                title: qsTr("Today")
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1

                RowLayout {
                    spacing: 12
                    Layout.fillWidth: true

                    ProgressTrack {
                        Layout.fillWidth: true
                        value: page.todayModel.count > 0 ? page.doneCount / page.todayModel.count : 0
                    }
                    Label {
                        text: qsTr("%1 of %2 done").arg(page.doneCount).arg(page.todayModel.count)
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSmall
                    }
                }

                Repeater {
                    model: page.todayModel

                    CheckRow {
                        id: checkRow
                        required property int index
                        required property var model
                        Layout.fillWidth: true
                        Layout.leftMargin: -8
                        text: checkRow.model.title
                        done: checkRow.model.done
                        onClicked: {
                            page.todayModel.setProperty(checkRow.index, "done", !checkRow.done)
                            page.recount()
                        }
                    }
                }
            }

            // ---- goals ----
            Card {
                title: qsTr("Your goals")
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1

                Repeater {
                    model: MockData.clientGoals

                    ColumnLayout {
                        id: goal
                        required property var modelData
                        spacing: 6
                        Layout.fillWidth: true
                        Layout.bottomMargin: 6

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: goal.modelData.title
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Label {
                                text: Math.round(goal.modelData.progress * 100) + "%"
                                color: Theme.primary
                                font.weight: Font.DemiBold
                            }
                        }
                        ProgressTrack {
                            Layout.fillWidth: true
                            value: goal.modelData.progress
                        }
                        Label {
                            text: goal.modelData.note
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSmall
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // ---- latest message ----
            Card {
                visible: page.chat !== null
                title: qsTr("From your coach")
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1

                RowLayout {
                    spacing: 12
                    Avatar {
                        name: page.coachName
                        size: 36
                    }
                    ColumnLayout {
                        spacing: 0
                        Label {
                            text: page.coachName
                            font.weight: Font.DemiBold
                        }
                        Label {
                            visible: text.length > 0
                            text: page.chat ? MessageStore.listTime(page.chat.otherLastAt) : ""
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSmall
                        }
                    }
                }

                Label {
                    text: page.chat && page.chat.otherLastBody.length > 0
                          ? page.chat.otherLastBody
                          : qsTr("No messages from %1 yet.").arg(page.coachName)
                    color: page.chat && page.chat.otherLastBody.length > 0 ? Theme.text : Theme.textMuted
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    lineHeight: 1.25
                    Layout.fillWidth: true
                }

                AuraButton {
                    variant: "ghost"
                    text: page.chat && page.chat.otherLastBody.length > 0 ? qsTr("Reply →") : qsTr("Write a message →")
                    leftPadding: 0
                    onClicked: page.openChat()
                }
            }
        }
    }
}
