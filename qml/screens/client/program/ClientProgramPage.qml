pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// "My program" in the client app: the program the coach assigned, read-only.
// Opens on the current week and shows that week's sets / reps / load; other
// weeks can be browsed.
ScrollView {
    id: page

    readonly property var me: Session.loggedIn ? ClientStore.clientByEmail(Session.user.email) : null
    readonly property var status: me ? ClientStore.programStatus(me) : ({ kind: "none", assignment: null })
    readonly property var assignment: status.assignment
    readonly property var program: assignment ? (ProgramStore.programs.find(p => p.id === assignment.programId) || null) : null
    readonly property string coachName: CoachStore.myCoach ? CoachStore.myCoach.name : qsTr("your coach")
    readonly property string coachFirstName: CoachStore.myCoach ? coachName.split(" ")[0] : qsTr("Your coach")

    // Week the client is in: 1 before the start, the last week after the end
    readonly property int currentWeek: {
        if (!assignment)
            return 1
        if (status.kind === "active" || status.kind === "endingSoon")
            return status.week
        return status.kind === "expired" ? assignment.weeks : 1
    }
    property int selectedWeek: currentWeek
    readonly property int programWeek: program ? ProgramStore.programWeekFor(program, selectedWeek) : 1
    readonly property bool wide: availableWidth >= 760

    onCurrentWeekChanged: selectedWeek = currentWeek

    function weekCaption() {
        if (status.kind === "scheduled")
            return selectedWeek === 1 ? qsTr("Your first week") : qsTr("Coming up")
        if (selectedWeek === currentWeek && status.kind !== "expired")
            return qsTr("This week")
        return selectedWeek < currentWeek || status.kind === "expired" ? qsTr("Done") : qsTr("Coming up")
    }

    contentWidth: availableWidth
    padding: width < 600 ? 16 : 32

    ColumnLayout {
        width: Math.min(page.availableWidth, 960)
        x: (page.availableWidth - width) / 2
        spacing: 20

        // ---- no program ----
        EmptyState {
            visible: page.assignment === null
            Layout.fillWidth: true
            Layout.topMargin: 80
            title: qsTr("No program yet")
            message: CoachStore.myCoach
                     ? qsTr("When %1 assigns you a program, you'll find it here: every training day, with sets, reps and load for each week.").arg(page.coachName)
                     : qsTr("Choose a coach in the My coach tab. Once they assign you a program, you'll find it here.")
        }

        // ---- program removed by the coach ----
        EmptyState {
            visible: page.assignment !== null && page.program === null
            Layout.fillWidth: true
            Layout.topMargin: 80
            title: page.assignment ? page.assignment.programName : ""
            message: qsTr("This program is no longer available. %1 will set up your next one.").arg(page.coachFirstName)
        }

        // ---- program ----
        ColumnLayout {
            visible: page.program !== null
            spacing: 20
            Layout.fillWidth: true

            PageHeader {
                Layout.fillWidth: true
                title: page.assignment ? page.assignment.programName : ""
                subtitle: page.program ? page.program.description : ""
            }

            Card {
                Layout.fillWidth: true

                RowLayout {
                    spacing: 12
                    Layout.fillWidth: true

                    Label {
                        text: !page.assignment ? ""
                            : page.status.kind === "scheduled"
                              ? qsTr("Starts %1").arg(ClientStore.formatDay(page.assignment.start))
                            : page.status.kind === "expired"
                              ? qsTr("Finished %1").arg(ClientStore.formatDay(page.status.lastDay))
                            : qsTr("Week %1 of %2").arg(page.status.week).arg(page.assignment.weeks)
                        font.pixelSize: Theme.fontTitle
                        font.weight: Font.Bold
                        Layout.fillWidth: true
                    }
                    Chip {
                        visible: page.status.kind === "endingSoon" || page.status.kind === "scheduled"
                        text: ClientStore.statusText(page.status)
                        tone: ClientStore.statusTone(page.status)
                    }
                }

                ProgressTrack {
                    Layout.fillWidth: true
                    value: page.status.kind === "expired" ? 1 : (page.status.progress || 0)
                    fillColor: page.status.kind === "endingSoon" ? Theme.accent : Theme.primary
                }

                Label {
                    text: page.assignment
                          ? qsTr("%1 – %2 · %3")
                                .arg(ClientStore.formatDay(page.assignment.start))
                                .arg(ClientStore.formatDayLong(page.status.lastDay))
                                .arg(page.program && page.program.days.length === 1
                                     ? qsTr("1 training day a week")
                                     : qsTr("%1 training days a week").arg(page.program ? page.program.days.length : 0))
                          : ""
                    color: Theme.textMuted
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                Notice {
                    tone: "info"
                    visible: page.status.kind === "expired"
                    Layout.fillWidth: true
                    text: qsTr("You've reached the end of this program. %1 will set up what comes next. You can still look back at every week.").arg(page.coachFirstName)
                }

                // Coach's message from the assignment
                RowLayout {
                    visible: page.assignment !== null && page.assignment.note.length > 0
                    spacing: 12
                    Layout.fillWidth: true
                    Layout.topMargin: 4

                    Avatar {
                        name: page.coachName
                        size: 32
                        Layout.alignment: Qt.AlignTop
                    }
                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true

                        Label {
                            text: page.coachName
                            font.pixelSize: Theme.fontSmall
                            font.weight: Font.DemiBold
                        }
                        Label {
                            text: page.assignment ? page.assignment.note : ""
                            color: Theme.textMuted
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // ---- week selector ----
            ColumnLayout {
                spacing: 10
                Layout.fillWidth: true
                Layout.topMargin: 4

                RowLayout {
                    spacing: 10
                    Layout.fillWidth: true

                    Label {
                        text: qsTr("Week %1").arg(page.selectedWeek)
                        font.pixelSize: Theme.fontTitle
                        font.weight: Font.Bold
                    }
                    Chip {
                        text: page.weekCaption()
                        tone: page.weekCaption() === qsTr("This week") ? "primary" : "neutral"
                    }
                    Item { Layout.fillWidth: true }
                    AuraButton {
                        visible: page.selectedWeek !== page.currentWeek
                        variant: "ghost"
                        text: page.status.kind === "scheduled" ? qsTr("Back to week 1") : qsTr("Back to this week")
                        implicitHeight: 34
                        onClicked: page.selectedWeek = page.currentWeek
                    }
                }

                Flow {
                    spacing: 6
                    Layout.fillWidth: true

                    Repeater {
                        model: page.assignment ? page.assignment.weeks : 0
                        FilterChip {
                            required property int index
                            readonly property int week: index + 1
                            text: week === page.currentWeek && (page.status.kind === "active" || page.status.kind === "endingSoon")
                                  ? qsTr("Week %1 · now").arg(week)
                                  : qsTr("Week %1").arg(week)
                            selected: page.selectedWeek === week
                            onClicked: page.selectedWeek = week
                        }
                    }
                }
            }

            // ---- days ----
            Repeater {
                model: page.program ? page.program.days : []

                ClientDayCard {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    day: modelData
                    dayNumber: index + 1
                    week: page.programWeek
                    wide: page.wide
                }
            }

            Label {
                text: qsTr("Questions about an exercise? Message %1 from the Messages tab.").arg(page.coachFirstName)
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 16
            }
        }
    }
}
