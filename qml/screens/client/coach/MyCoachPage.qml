pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// "My coach" in the client app:
//  - no coach:      the coach directory, to request a (public) coach
//  - declined:      the directory, with a note that the coach said no
//  - invited:       a (private) coach invited you: accept or decline
//  - request sent:  who you asked, with the option to cancel
//  - has a coach:   their details, next session, your program, contact
Item {
    id: page

    // Indices of the client app's tabs this page links to
    readonly property int calendarTab: 2
    readonly property int programTab: 3
    readonly property int messagesTab: 5

    readonly property var relation: CoachStore.myRelation
    readonly property string status: relation ? relation.status : "none"
    readonly property var coach: CoachStore.myCoach
    readonly property string firstName: coach ? coach.name.split(" ")[0] : ""
    readonly property bool wide: scroll.availableWidth >= 820

    // The client's program with the demo coach (others have no data yet)
    readonly property var me: Session.loggedIn ? ClientStore.clientByEmail(Session.user.email, ClientStore.revision) : null
    readonly property var programStatus: me ? ClientStore.programStatus(me) : ({ kind: "none", assignment: null })
    readonly property var booked: Session.loggedIn ? CalendarStore.nextSessionFor(Session.user.email, Session.user.name, CalendarStore.revision) : null
    readonly property var nextSession: booked
        ? { date: new Date(CalendarStore.startMs(booked)), duration: qsTr("%1 min").arg(booked.end - booked.start),
            topic: booked.type, mode: booked.mode, pending: booked.status === "pending" }
        : null

    signal navigateRequested(int index)

    ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth
        padding: width < 600 ? 16 : 32

        ColumnLayout {
            width: Math.min(scroll.availableWidth, 1080)
            x: (scroll.availableWidth - width) / 2
            spacing: 20

            // ---- request declined ----
            Rectangle {
                visible: page.status === "declined"
                Layout.fillWidth: true
                implicitHeight: declinedRow.implicitHeight + 20
                radius: Theme.radius
                color: Theme.surfaceAlt

                RowLayout {
                    id: declinedRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 16
                    anchors.rightMargin: 8
                    spacing: 8

                    Label {
                        text: qsTr("%1 can't take on new clients right now. Choose another coach below.").arg(page.coach ? page.coach.name : "")
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                    AuraButton {
                        variant: "ghost"
                        text: qsTr("Dismiss")
                        implicitHeight: 34
                        onClicked: CoachStore.dismissDeclined()
                    }
                }
            }

            // ---- no coach: directory ----
            CoachDirectory {
                visible: page.status === "none" || page.status === "declined"
                Layout.fillWidth: true
                onProfileRequested: coachId => profileDialog.openFor(coachId, true)
            }

            // ---- invited by a private coach ----
            ColumnLayout {
                visible: page.status === "invited" && page.coach !== null
                spacing: 20
                Layout.fillWidth: true

                PageHeader {
                    Layout.fillWidth: true
                    title: qsTr("My coach")
                    subtitle: qsTr("You've been invited to train with a coach.")
                }

                Card {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 760

                    RowLayout {
                        spacing: 16
                        Layout.fillWidth: true

                        Avatar {
                            name: page.coach ? page.coach.name : ""
                            size: 56
                            Layout.alignment: Qt.AlignTop
                        }
                        ColumnLayout {
                            spacing: 4
                            Layout.fillWidth: true

                            Label {
                                text: qsTr("%1 invited you to be their client").arg(page.coach ? page.coach.name : "")
                                font.pixelSize: Theme.fontTitle
                                font.weight: Font.Bold
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                            Label {
                                text: page.coach ? page.coach.title + " · " + page.coach.city : ""
                                color: Theme.textMuted
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }
                        Chip {
                            text: qsTr("Invitation")
                            tone: "primary"
                            Layout.alignment: Qt.AlignTop
                        }
                    }

                    CoachProfile {
                        coach: page.coach
                        showHeader: false
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        spacing: 8
                        Layout.alignment: Qt.AlignRight
                        Layout.topMargin: 4

                        AuraButton {
                            variant: "ghostDanger"
                            text: qsTr("Decline")
                            onClicked: declineInviteDialog.open()
                        }
                        AuraButton {
                            text: qsTr("Accept invitation")
                            onClicked: {
                                const name = page.firstName
                                CoachStore.acceptInvitation()
                                toast.show(qsTr("%1 is now your coach").arg(name))
                            }
                        }
                    }
                }
            }

            // ---- request sent ----
            ColumnLayout {
                visible: page.status === "pending"
                spacing: 20
                Layout.fillWidth: true

                PageHeader {
                    Layout.fillWidth: true
                    title: qsTr("My coach")
                    subtitle: qsTr("Your request is on its way.")
                }

                Card {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 720

                    RowLayout {
                        spacing: 16
                        Layout.fillWidth: true

                        Avatar {
                            name: page.coach ? page.coach.name : ""
                            size: 56
                            Layout.alignment: Qt.AlignTop
                        }
                        ColumnLayout {
                            spacing: 4
                            Layout.fillWidth: true

                            Label {
                                text: qsTr("Request sent to %1").arg(page.coach ? page.coach.name : "")
                                font.pixelSize: Theme.fontTitle
                                font.weight: Font.Bold
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                            Label {
                                text: page.relation && page.relation.since
                                      ? qsTr("Sent %1 at %2. You'll be notified when %3 replies.")
                                            .arg(ClientStore.relativeDay(page.relation.since).toLowerCase())
                                            .arg(Qt.formatTime(new Date(page.relation.since), "HH:mm"))
                                            .arg(page.firstName)
                                      : ""
                                color: Theme.textMuted
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }
                        Chip {
                            text: qsTr("Waiting")
                            tone: "accent"
                            Layout.alignment: Qt.AlignTop
                        }
                    }

                    Rectangle {
                        visible: page.relation !== null && page.relation.goal.length > 0
                        Layout.fillWidth: true
                        implicitHeight: requestText.implicitHeight + 24
                        radius: Theme.radius
                        color: Theme.surfaceAlt

                        Label {
                            id: requestText
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 12
                            wrapMode: Text.Wrap
                            textFormat: Text.StyledText
                            text: page.relation
                                  ? qsTr("<b>Your goal:</b> %1").arg(page.relation.goal)
                                    + (page.relation.message ? "<br><b>" + qsTr("Message:") + "</b> " + page.relation.message : "")
                                  : ""
                        }
                    }

                    Notice {
                        tone: "info"
                        Layout.fillWidth: true
                        text: page.coach
                              ? qsTr("Demo: to answer it, log out and log in as %1 (password: password), then open Clients → Accept clients. This page updates as soon as they answer.").arg(page.coach.email)
                              : ""
                    }

                    RowLayout {
                        spacing: 8
                        AuraButton {
                            variant: "secondary"
                            text: qsTr("View profile")
                            onClicked: profileDialog.openFor(page.coach.id, false)
                        }
                        AuraButton {
                            variant: "ghostDanger"
                            text: qsTr("Cancel request")
                            onClicked: cancelDialog.open()
                        }
                    }
                }
            }

            // ---- has a coach ----
            ColumnLayout {
                visible: page.status === "active" && page.coach !== null
                spacing: 20
                Layout.fillWidth: true

                // Header
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: headerRow.implicitHeight + 48
                    radius: Theme.radiusLarge
                    color: Theme.surface
                    border.width: 1
                    border.color: Theme.border

                    GridLayout {
                        id: headerRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 24
                        columns: page.wide ? 3 : 2
                        columnSpacing: 20
                        rowSpacing: 16

                        Avatar {
                            name: page.coach ? page.coach.name : ""
                            size: page.wide ? 80 : 60
                            Layout.alignment: Qt.AlignTop
                        }
                        ColumnLayout {
                            spacing: 4
                            Layout.fillWidth: true

                            Label {
                                text: qsTr("Your coach")
                                color: Theme.primary
                                font.pixelSize: Theme.fontSmall
                                font.weight: Font.DemiBold
                            }
                            Label {
                                text: page.coach ? page.coach.name : ""
                                font.pixelSize: Theme.fontHeadline
                                font.weight: Font.Bold
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                            Label {
                                text: page.coach ? page.coach.title + " · " + page.coach.city : ""
                                color: Theme.textMuted
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                            Flow {
                                spacing: 6
                                Layout.fillWidth: true
                                Layout.topMargin: 4

                                Chip {
                                    text: page.relation && page.relation.since
                                          ? qsTr("Together since %1").arg(Qt.formatDate(new Date(page.relation.since), "MMM yyyy"))
                                          : ""
                                    tone: "primary"
                                }
                                Chip {
                                    text: page.coach ? CoachStore.modesText(page.coach) : ""
                                }
                            }
                        }
                        RowLayout {
                            spacing: 8
                            Layout.columnSpan: page.wide ? 1 : 2
                            Layout.alignment: page.wide ? Qt.AlignTop | Qt.AlignRight : Qt.AlignLeft

                            AuraButton {
                                text: qsTr("Message %1").arg(page.firstName)
                                onClicked: {
                                    MessageStore.open(page.relation.id)
                                    page.navigateRequested(page.messagesTab)
                                }
                            }
                            AuraButton {
                                variant: "secondary"
                                text: qsTr("Book a session")
                                onClicked: page.navigateRequested(page.calendarTab)
                            }
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: page.wide ? 2 : 1
                    columnSpacing: 16
                    rowSpacing: 16

                    // Next session
                    Card {
                        title: qsTr("Next session")
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1

                        RowLayout {
                            visible: page.nextSession !== null
                            spacing: 16
                            Layout.fillWidth: true

                            Rectangle {
                                implicitWidth: 64
                                implicitHeight: 72
                                radius: 12
                                color: Theme.primarySoft

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 0
                                    Label {
                                        text: page.nextSession ? Qt.formatDate(page.nextSession.date, "MMM").toUpperCase() : ""
                                        color: Theme.primary
                                        font.pixelSize: Theme.fontSmall
                                        font.weight: Font.DemiBold
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    Label {
                                        text: page.nextSession ? Qt.formatDate(page.nextSession.date, "d") : ""
                                        color: Theme.primary
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
                                    text: page.nextSession ? page.nextSession.topic : ""
                                    font.pixelSize: Theme.fontLarge
                                    font.weight: Font.DemiBold
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                }
                                Label {
                                    text: page.nextSession
                                          ? Qt.formatDate(page.nextSession.date, "dddd") + ", " + Qt.formatTime(page.nextSession.date, "HH:mm")
                                            + " · " + page.nextSession.duration + " · " + page.nextSession.mode
                                          : ""
                                    color: Theme.textMuted
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        Label {
                            visible: page.nextSession === null
                            text: qsTr("No session booked yet.")
                            color: Theme.textMuted
                        }

                        AuraButton {
                            variant: "ghost"
                            text: qsTr("Open calendar →")
                            leftPadding: 0
                            onClicked: page.navigateRequested(page.calendarTab)
                        }
                    }

                    // Program
                    Card {
                        title: qsTr("Your program")
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1

                        RowLayout {
                            visible: page.programStatus.assignment !== null
                            spacing: 10
                            Layout.fillWidth: true

                            Label {
                                text: page.programStatus.assignment ? page.programStatus.assignment.programName : ""
                                font.pixelSize: Theme.fontLarge
                                font.weight: Font.DemiBold
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                            Chip {
                                text: ClientStore.statusText(page.programStatus)
                                tone: ClientStore.statusTone(page.programStatus)
                            }
                        }
                        ProgressTrack {
                            visible: page.programStatus.kind === "active" || page.programStatus.kind === "endingSoon"
                            Layout.fillWidth: true
                            value: page.programStatus.progress || 0
                        }
                        Label {
                            visible: page.programStatus.assignment === null
                            text: qsTr("No program yet. %1 will set one up for you.").arg(page.firstName)
                            color: Theme.textMuted
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                        AuraButton {
                            visible: page.programStatus.assignment !== null
                            variant: "ghost"
                            text: qsTr("Open my program →")
                            leftPadding: 0
                            onClicked: page.navigateRequested(page.programTab)
                        }
                    }
                }

                // About + practical details
                Card {
                    title: qsTr("About %1").arg(page.firstName)
                    Layout.fillWidth: true

                    CoachProfile {
                        coach: page.coach
                        showHeader: false
                        showContact: true
                        Layout.fillWidth: true
                    }
                }

                AuraButton {
                    variant: "ghostDanger"
                    text: qsTr("Stop working with %1").arg(page.firstName)
                    Layout.alignment: Qt.AlignLeft
                    Layout.bottomMargin: 16
                    onClicked: leaveDialog.open()
                }
            }
        }
    }

    Toast {
        id: toast
    }

    Connections {
        target: CoachStore
        function onRequestAccepted(coachName) {
            toast.show(qsTr("%1 accepted your request").arg(coachName))
        }
    }

    CoachProfileDialog {
        id: profileDialog
        onRequestRequested: coachId => requestDialog.openFor(coachId)
    }

    RequestCoachDialog {
        id: requestDialog
        onSent: toast.show(qsTr("Request sent"))
    }

    ConfirmDialog {
        id: cancelDialog
        title: qsTr("Cancel your request?")
        message: qsTr("%1 won't see your request any more. You can choose a coach again afterwards.").arg(page.firstName)
        cancelText: qsTr("Keep it")
        confirmText: qsTr("Cancel request")
        destructive: true
        onConfirmed: CoachStore.cancelRequest()
    }

    ConfirmDialog {
        id: declineInviteDialog
        title: qsTr("Decline the invitation?")
        message: qsTr("%1 will be told you declined. You can still choose a coach from the directory.").arg(page.firstName)
        cancelText: qsTr("Keep it")
        confirmText: qsTr("Decline")
        destructive: true
        onConfirmed: CoachStore.declineInvitation()
    }

    ConfirmDialog {
        id: leaveDialog
        title: qsTr("Stop working with %1?").arg(page.firstName)
        message: qsTr("%1 will no longer see your progress, and your program and sessions with them will no longer be available. You can choose a new coach afterwards.").arg(page.firstName)
        cancelText: qsTr("Stay")
        confirmText: qsTr("Stop coaching")
        destructive: true
        onConfirmed: {
            const name = page.firstName
            CoachStore.leave()
            toast.show(qsTr("You're no longer working with %1").arg(name))
        }
    }
}
