pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Pick a program and a start date for a client.
AuraDialog {
    id: dialog

    property string clientId: ""
    property string programId: ""
    property double startMs: ClientStore.today()
    property bool submitted: false

    readonly property var client: ClientStore.clientById(clientId, ClientStore.revision)
    readonly property var program: ProgramStore.programs.find(p => p.id === programId) || null
    readonly property int weeks: program ? ProgramStore.weekCount(program) : 0
    readonly property var current: client ? ClientStore.programStatus(client) : ({ kind: "none", assignment: null })
    readonly property double endMs: program ? ClientStore.lastDay({ start: startMs, weeks: weeks }) : 0
    readonly property bool twoColumns: availableWidth >= 640
    readonly property var programs: ProgramStore.searchPrograms(search.text, ProgramStore.revision)

    signal assigned(string clientName, string programName)

    function openFor(id, preselectProgramId) {
        clientId = id
        programId = preselectProgramId ? String(preselectProgramId) : ""
        startMs = ClientStore.today()
        search.text = ""
        noteField.text = ""
        submitted = false
        open()
    }

    function assign() {
        submitted = true
        if (!program)
            return
        ClientStore.assign(clientId, programId, startMs, noteField.text)
        close()
        assigned(client.name, program.name)
    }

    title: qsTr("Assign a program")
    preferredWidth: 820

    Label {
        text: dialog.client ? qsTr("For <b>%1</b>").arg(dialog.client.name) : ""
        textFormat: Text.StyledText
        color: Theme.textMuted
        font.pixelSize: Theme.fontLarge
        Layout.fillWidth: true
    }

    Notice {
        tone: "info"
        visible: dialog.current.kind === "active" || dialog.current.kind === "endingSoon" || dialog.current.kind === "scheduled"
        Layout.fillWidth: true
        text: dialog.current.assignment
              ? (dialog.current.kind === "scheduled"
                 ? qsTr("%1 is scheduled to start <b>%2</b>. Assigning a new program replaces it.")
                       .arg(dialog.client.name).arg(dialog.current.assignment.programName)
                 : qsTr("%1 is following <b>%2</b> (%3). Assigning a new program ends it today and moves it to the history.")
                       .arg(dialog.client.name).arg(dialog.current.assignment.programName).arg(ClientStore.statusText(dialog.current).toLowerCase()))
              : ""
    }

    GridLayout {
        Layout.fillWidth: true
        columns: dialog.twoColumns ? 2 : 1
        columnSpacing: 28
        rowSpacing: 20

        // ---- program ----
        ColumnLayout {
            spacing: 10
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop

            Label {
                text: qsTr("Program")
                font.pixelSize: Theme.fontSmall
                font.weight: Font.DemiBold
            }
            AuraSearchField {
                id: search
                placeholderText: qsTr("Search programs")
                Layout.fillWidth: true
            }

            Repeater {
                model: dialog.programs

                AbstractButton {
                    id: option
                    required property var modelData
                    readonly property bool selected: dialog.programId === modelData.id

                    Layout.fillWidth: true
                    hoverEnabled: true
                    padding: 12
                    implicitHeight: implicitContentHeight + topPadding + bottomPadding
                    onClicked: dialog.programId = modelData.id

                    contentItem: RowLayout {
                        spacing: 12

                        Rectangle {
                            implicitWidth: 18
                            implicitHeight: 18
                            radius: 9
                            color: "transparent"
                            border.width: option.selected ? 5 : 2
                            border.color: option.selected ? Theme.primary : Theme.border
                        }
                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true

                            Label {
                                text: option.modelData.name
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Label {
                                text: [
                                    option.modelData.days.length === 1 ? qsTr("1 day a week") : qsTr("%1 days a week").arg(option.modelData.days.length),
                                    ProgramStore.weekCount(option.modelData) === 1 ? qsTr("1 week") : qsTr("%1 weeks").arg(ProgramStore.weekCount(option.modelData)),
                                    ProgramStore.exerciseCount(option.modelData) === 1 ? qsTr("1 exercise") : qsTr("%1 exercises").arg(ProgramStore.exerciseCount(option.modelData))
                                ].join(" · ")
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontSmall
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    background: Rectangle {
                        radius: Theme.radius
                        color: option.selected ? Theme.primarySoft
                             : option.hovered ? Theme.surfaceAlt
                             : Theme.surface
                        border.width: option.selected ? 2 : 1
                        border.color: option.selected ? Theme.primary : Theme.border
                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }

            Label {
                visible: dialog.programs.length === 0
                text: qsTr("No programs match \"%1\".").arg(search.text)
                color: Theme.textMuted
            }
            Label {
                visible: dialog.submitted && !dialog.program
                text: qsTr("Choose a program.")
                color: Theme.danger
                font.pixelSize: Theme.fontSmall
            }
        }

        // ---- start date ----
        ColumnLayout {
            spacing: 10
            Layout.alignment: Qt.AlignTop
            Layout.fillWidth: !dialog.twoColumns

            Label {
                text: qsTr("Start date")
                font.pixelSize: Theme.fontSmall
                font.weight: Font.DemiBold
            }
            Flow {
                spacing: 6
                Layout.fillWidth: true
                Layout.preferredWidth: calendar.implicitWidth

                FilterChip {
                    text: qsTr("Today")
                    selected: dialog.startMs === ClientStore.today()
                    onClicked: dialog.startMs = ClientStore.today()
                }
                FilterChip {
                    text: qsTr("Tomorrow")
                    selected: dialog.startMs === ClientStore.dayOffset(1)
                    onClicked: dialog.startMs = ClientStore.dayOffset(1)
                }
                FilterChip {
                    text: qsTr("Next Monday")
                    selected: dialog.startMs === ClientStore.nextMonday()
                    onClicked: dialog.startMs = ClientStore.nextMonday()
                }
            }
            DatePicker {
                id: calendar
                selectedMs: dialog.startMs
                onPicked: ms => dialog.startMs = ms
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // Summary
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: summary.implicitHeight + 24
        radius: Theme.radius
        color: dialog.program ? Theme.primarySoft : Theme.surfaceAlt

        Label {
            id: summary
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 14
            wrapMode: Text.Wrap
            textFormat: Text.StyledText
            color: dialog.program ? Theme.text : Theme.textMuted
            text: dialog.program
                  ? qsTr("<b>%1</b> for %2 weeks: <b>%3</b> to <b>%4</b>")
                        .arg(dialog.program.name).arg(dialog.weeks)
                        .arg(ClientStore.formatDay(dialog.startMs)).arg(ClientStore.formatDayLong(dialog.endMs))
                  : qsTr("Choose a program to see when it ends.")
        }
    }

    AuraTextArea {
        id: noteField
        Layout.fillWidth: true
        label: qsTr("Message to the client (optional)")
        placeholderText: qsTr("e.g. Focus on technique in the first two weeks.")
        minimumHeight: 64
    }

    actions: [
        AuraButton {
            variant: "secondary"
            text: qsTr("Cancel")
            onClicked: dialog.close()
        },
        AuraButton {
            text: qsTr("Assign program")
            onClicked: dialog.assign()
        }
    ]
}
