pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Last step of booking: what the session is for, online or in person, and a
// note. Sending creates a pending session (any length in 30-minute steps) that
// the coach confirms or declines.
AuraDialog {
    id: dialog

    property string coachId: ""
    property double dayMs: 0
    property int start: 0
    property int end: 0
    property string type: ""
    property string mode: ""
    property string error: ""

    readonly property var coach: CoachStore.coachById(coachId, CoachStore.revision)
    readonly property string firstName: coach ? coach.name.split(" ")[0] : ""
    readonly property var types: [qsTr("Training"), qsTr("Technique session"), qsTr("Weekly check-in"), qsTr("Program review")]
    readonly property var modes: !coach ? []
                                 : coach.inPerson && coach.online ? [qsTr("In person"), qsTr("Video call")]
                                 : coach.inPerson ? [qsTr("In person")] : [qsTr("Video call")]

    signal sent()

    function openFor(id, day, from, to) {
        coachId = id
        dayMs = day
        start = from
        end = to
        type = types[0]
        mode = modes.length > 0 ? modes[0] : ""
        noteField.text = ""
        error = ""
        open()
    }

    function send() {
        // Someone else may have taken the slot meanwhile
        if (!CalendarStore.isRangeFree(coachId, dayMs, start, end, CalendarStore.revision)) {
            error = qsTr("This time isn't free any more. Please choose another one.")
            return
        }
        CalendarStore.requestSession(coachId, dayMs, start, end, type, mode, noteField.text,
                                     Session.user.name, Session.user.email)
        close()
        sent()
    }

    title: qsTr("Request a session")
    preferredWidth: 560

    // Summary
    RowLayout {
        spacing: 14
        Layout.fillWidth: true

        Avatar {
            name: dialog.coach ? dialog.coach.name : ""
            size: 48
        }
        ColumnLayout {
            spacing: 2
            Layout.fillWidth: true

            Label {
                text: dialog.dayMs > 0 ? Qt.formatDate(new Date(dialog.dayMs), "dddd d MMMM") : ""
                font.pixelSize: Theme.fontLarge
                font.weight: Font.Bold
            }
            Label {
                text: qsTr("%1–%2 (%3) with %4")
                          .arg(CalendarStore.formatMinutes(dialog.start))
                          .arg(CalendarStore.formatMinutes(dialog.end))
                          .arg(CalendarStore.durationText(dialog.end - dialog.start))
                          .arg(dialog.coach ? dialog.coach.name : "")
                color: Theme.textMuted
            }
        }
    }

    ColumnLayout {
        spacing: 8
        Layout.fillWidth: true

        Label {
            text: qsTr("What's it for?")
            font.pixelSize: Theme.fontSmall
            font.weight: Font.DemiBold
        }
        Flow {
            spacing: 6
            Layout.fillWidth: true
            Repeater {
                model: dialog.types
                FilterChip {
                    required property string modelData
                    text: modelData
                    selected: dialog.type === modelData
                    onClicked: dialog.type = modelData
                }
            }
        }
    }

    ColumnLayout {
        visible: dialog.modes.length > 1
        spacing: 8
        Layout.fillWidth: true

        Label {
            text: qsTr("Where")
            font.pixelSize: Theme.fontSmall
            font.weight: Font.DemiBold
        }
        Flow {
            spacing: 6
            Layout.fillWidth: true
            Repeater {
                model: dialog.modes
                FilterChip {
                    required property string modelData
                    text: modelData
                    selected: dialog.mode === modelData
                    onClicked: dialog.mode = modelData
                }
            }
        }
        Label {
            visible: dialog.mode === qsTr("In person") && dialog.coach !== null && dialog.coach.studio.length > 0
            text: dialog.coach ? dialog.coach.studio : ""
            color: Theme.textMuted
            font.pixelSize: Theme.fontSmall
        }
    }

    AuraTextArea {
        id: noteField
        Layout.fillWidth: true
        label: qsTr("Note for %1 (optional)").arg(dialog.firstName)
        placeholderText: qsTr("Anything to work on, or something to know beforehand…")
        minimumHeight: 64
    }

    Notice {
        tone: "info"
        Layout.fillWidth: true
        text: qsTr("%1 confirms or declines every request. Until then it shows as waiting for confirmation, and the time is held for you. You can cancel up to %2 hours before it starts.")
                  .arg(dialog.firstName).arg(CalendarStore.cancelNoticeHours)
              + "<br>" + qsTr("Demo: to answer it, log in as %1 (password: password) and open Calendar.").arg(dialog.coach ? dialog.coach.email : "")
    }

    Notice {
        tone: "danger"
        Layout.fillWidth: true
        text: dialog.error
    }

    actions: [
        AuraButton {
            variant: "secondary"
            text: qsTr("Cancel")
            onClicked: dialog.close()
        },
        AuraButton {
            text: qsTr("Send request")
            onClicked: dialog.send()
        }
    ]
}
