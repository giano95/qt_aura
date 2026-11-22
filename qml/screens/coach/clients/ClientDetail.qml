pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// One client: current program (with expired / ending-soon states), contact
// details and program history. Assign, change, extend or end the program here.
Item {
    id: page

    property int clientId: 0

    readonly property var client: ClientStore.clientById(clientId)
    readonly property var status: client ? ClientStore.programStatus(client) : ({ kind: "none", assignment: null })
    readonly property var current: status.assignment
    readonly property var history: client ? ClientStore.pastAssignments(client) : []
    readonly property bool wide: width >= 860
    readonly property bool hasRunningProgram: status.kind === "active" || status.kind === "endingSoon" || status.kind === "scheduled"

    signal closeRequested()
    signal openProgramRequested(string programId, string clientName)

    function programExists(programId) {
        return ProgramStore.programs.some(p => p.id === programId)
    }

    function openProgram(programId) {
        openProgramRequested(programId, client ? client.name : "")
    }

    function statusLine() {
        if (!current)
            return ""
        if (status.kind === "scheduled")
            return qsTr("Starts %1 · ends %2").arg(ClientStore.formatDay(current.start)).arg(ClientStore.formatDayLong(status.lastDay))
        if (status.kind === "expired")
            return qsTr("Ran %1 – %2").arg(ClientStore.formatDay(current.start)).arg(ClientStore.formatDayLong(status.lastDay))
        return qsTr("Started %1 · ends %2").arg(ClientStore.formatDay(current.start)).arg(ClientStore.formatDayLong(status.lastDay))
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Toolbar
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
                anchors.leftMargin: page.wide ? 20 : 8
                anchors.rightMargin: page.wide ? 24 : 12

                AuraButton {
                    variant: "ghost"
                    text: qsTr("← Clients")
                    leftPadding: 12
                    rightPadding: 12
                    onClicked: page.closeRequested()
                }
                Item { Layout.fillWidth: true }
            }
        }

        ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            padding: page.wide ? 32 : 16

            ColumnLayout {
                width: Math.min(scroll.availableWidth, 1040)
                x: (scroll.availableWidth - width) / 2
                spacing: 20

                // ---- header ----
                RowLayout {
                    visible: page.client !== null
                    Layout.fillWidth: true
                    spacing: 16

                    Avatar {
                        name: page.client ? page.client.name : ""
                        size: page.wide ? 64 : 48
                        Layout.alignment: Qt.AlignTop
                    }
                    ColumnLayout {
                        spacing: 4
                        Layout.fillWidth: true

                        Label {
                            text: page.client ? page.client.name : ""
                            font.pixelSize: Theme.fontHeadline
                            font.weight: Font.Bold
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                        Flow {
                            spacing: 6
                            Layout.fillWidth: true

                            Chip {
                                text: !page.client ? ""
                                    : page.client.status === "invited" ? qsTr("Invite sent")
                                    : page.client.status === "paused" ? qsTr("Paused")
                                    : qsTr("Active client")
                                tone: page.client && page.client.status === "active" ? "primary" : "neutral"
                            }
                            Chip {
                                text: page.client ? qsTr("Client since %1").arg(Qt.formatDate(new Date(page.client.since), "MMM yyyy")) : ""
                            }
                        }
                    }
                    AuraButton {
                        visible: page.wide
                        Layout.alignment: Qt.AlignTop
                        text: page.hasRunningProgram ? qsTr("Change program") : qsTr("Assign program")
                        variant: page.hasRunningProgram ? "secondary" : "primary"
                        onClicked: assignDialog.openFor(page.clientId)
                    }
                }

                GridLayout {
                    visible: page.client !== null
                    Layout.fillWidth: true
                    columns: page.wide ? 2 : 1
                    columnSpacing: 16
                    rowSpacing: 16

                    // ---- current program ----
                    Card {
                        title: qsTr("Program")
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 3

                        // No program
                        ColumnLayout {
                            visible: page.status.kind === "none"
                            spacing: 12
                            Layout.fillWidth: true

                            Label {
                                text: page.client && page.client.status === "invited"
                                      ? qsTr("No program yet. You can assign one now; they'll see it once they accept the invite.")
                                      : qsTr("No program assigned yet.")
                                color: Theme.textMuted
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                            AuraButton {
                                text: qsTr("Assign program")
                                onClicked: assignDialog.openFor(page.clientId)
                            }
                        }

                        // Has a program (any state)
                        ColumnLayout {
                            visible: page.current !== null
                            spacing: 12
                            Layout.fillWidth: true

                            Rectangle {
                                visible: page.status.kind === "expired"
                                Layout.fillWidth: true
                                implicitHeight: expiredText.implicitHeight + 24
                                radius: Theme.radius
                                color: Theme.dangerSoft

                                Label {
                                    id: expiredText
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: 14
                                    wrapMode: Text.Wrap
                                    textFormat: Text.StyledText
                                    color: Theme.danger
                                    text: page.status.kind === "expired"
                                          ? qsTr("<b>Program expired %1.</b> %2 has nothing new to follow. Assign a new program or extend this one.")
                                                .arg(page.status.daysAgo === 1 ? qsTr("yesterday") : qsTr("%1 days ago").arg(page.status.daysAgo))
                                                .arg(page.client.name.split(" ")[0])
                                          : ""
                                }
                            }

                            RowLayout {
                                spacing: 10
                                Layout.fillWidth: true

                                Label {
                                    text: page.current ? page.current.programName : ""
                                    font.pixelSize: Theme.fontTitle
                                    font.weight: Font.Bold
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                }
                                Chip {
                                    text: ClientStore.statusText(page.status)
                                    tone: ClientStore.statusTone(page.status)
                                }
                            }

                            ProgressTrack {
                                visible: page.status.kind === "active" || page.status.kind === "endingSoon"
                                Layout.fillWidth: true
                                value: page.status.progress || 0
                                fillColor: page.status.kind === "endingSoon" ? Theme.accent : Theme.primary
                            }

                            RowLayout {
                                spacing: 8
                                Layout.fillWidth: true

                                Label {
                                    text: page.statusLine()
                                    color: Theme.textMuted
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                }
                                AuraButton {
                                    visible: page.current !== null && page.programExists(page.current.programId)
                                    variant: "ghost"
                                    text: qsTr("Open program →")
                                    implicitHeight: 34
                                    leftPadding: 10
                                    rightPadding: 10
                                    onClicked: page.openProgram(page.current.programId)
                                }
                                Label {
                                    visible: page.current !== null && !page.programExists(page.current.programId)
                                    text: qsTr("Program deleted")
                                    color: Theme.textMuted
                                    font.italic: true
                                }
                            }

                            Label {
                                visible: page.current !== null && page.current.note.length > 0
                                text: page.current ? "“" + page.current.note + "”" : ""
                                font.italic: true
                                color: Theme.textMuted
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }

                            Flow {
                                spacing: 8
                                Layout.fillWidth: true
                                Layout.topMargin: 4

                                AuraButton {
                                    visible: page.status.kind === "expired"
                                    text: qsTr("Assign new program")
                                    onClicked: assignDialog.openFor(page.clientId)
                                }
                                AuraButton {
                                    visible: page.status.kind !== "expired" && !page.wide
                                    variant: "secondary"
                                    text: qsTr("Change program")
                                    onClicked: assignDialog.openFor(page.clientId)
                                }
                                AuraButton {
                                    visible: page.status.kind !== "scheduled"
                                    variant: page.status.kind === "expired" || page.status.kind === "endingSoon" ? "secondary" : "ghost"
                                    text: qsTr("Extend by 4 weeks")
                                    onClicked: {
                                        ClientStore.extend(page.clientId, 4)
                                        toast.show(qsTr("Extended by 4 weeks"))
                                    }
                                }
                                AuraButton {
                                    visible: page.status.kind !== "expired"
                                    variant: "ghostDanger"
                                    text: page.status.kind === "scheduled" ? qsTr("Cancel program") : qsTr("End program")
                                    onClicked: endDialog.open()
                                }
                            }
                        }
                    }

                    // ---- about ----
                    Card {
                        title: qsTr("About")
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 2

                        Repeater {
                            model: page.client ? [
                                { label: qsTr("Goal"), value: page.client.goal || qsTr("Not set") },
                                { label: qsTr("Email"), value: page.client.email },
                                { label: qsTr("Phone"), value: page.client.phone || qsTr("Not set") },
                                { label: qsTr("Last check-in"), value: ClientStore.relativeDay(page.client.lastCheckIn) },
                                { label: qsTr("Next session"), value: page.client.nextSession ? ClientStore.relativeDay(page.client.nextSession) : qsTr("None booked") }
                            ] : []

                            RowLayout {
                                id: infoRow
                                required property var modelData
                                spacing: 12
                                Layout.fillWidth: true

                                Label {
                                    text: infoRow.modelData.label
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fontSmall
                                    font.weight: Font.DemiBold
                                    Layout.preferredWidth: 96
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: 1
                                }
                                Label {
                                    text: infoRow.modelData.value
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }

                // ---- history ----
                Card {
                    visible: page.client !== null
                    title: qsTr("Program history")
                    Layout.fillWidth: true

                    Label {
                        visible: page.history.length === 0
                        text: qsTr("No previous programs.")
                        color: Theme.textMuted
                    }

                    Repeater {
                        model: page.history

                        RowLayout {
                            id: historyRow
                            required property var modelData
                            required property int index
                            spacing: 12
                            Layout.fillWidth: true

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true

                                Label {
                                    text: historyRow.modelData.programName
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Label {
                                    text: qsTr("%1 – %2").arg(ClientStore.formatDay(historyRow.modelData.start))
                                                         .arg(ClientStore.formatDayLong(historyRow.modelData.endedAt))
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fontSmall
                                    Layout.fillWidth: true
                                }
                            }
                            Chip {
                                text: ClientStore.endReasonText(historyRow.modelData.endReason)
                                tone: historyRow.modelData.endReason === "completed" ? "primary" : "neutral"
                            }
                            AuraButton {
                                visible: page.programExists(historyRow.modelData.programId)
                                variant: "ghost"
                                text: qsTr("Open →")
                                implicitHeight: 32
                                leftPadding: 10
                                rightPadding: 10
                                onClicked: page.openProgram(historyRow.modelData.programId)
                            }
                        }
                    }
                }

                Item { implicitHeight: 16 }
            }
        }
    }

    Toast {
        id: toast
    }

    AssignProgramDialog {
        id: assignDialog
        onAssigned: (clientName, programName) => toast.show(qsTr("%1 assigned").arg(programName))
    }

    ConfirmDialog {
        id: endDialog
        title: page.status.kind === "scheduled" ? qsTr("Cancel program?") : qsTr("End program?")
        message: !page.current ? ""
                 : page.status.kind === "scheduled"
                   ? qsTr("\"%1\" won't start for %2.").arg(page.current.programName).arg(page.client.name)
                   : qsTr("\"%1\" ends today for %2 and moves to the program history.").arg(page.current.programName).arg(page.client.name)
        confirmText: page.status.kind === "scheduled" ? qsTr("Cancel program") : qsTr("End program")
        cancelText: qsTr("Keep it")
        destructive: true
        onConfirmed: {
            ClientStore.endProgram(page.clientId)
            toast.show(qsTr("Program ended"))
        }
    }
}
