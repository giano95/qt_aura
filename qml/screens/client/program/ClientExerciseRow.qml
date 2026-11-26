import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// One exercise as the client sees it: what to do this week. Tap to show the
// coach's notes and how to perform it. Nothing here is editable.
AbstractButton {
    id: row

    property var entry: ({ exerciseId: "", sets: "", reps: "", load: "", rest: "", notes: "", weeks: {} })
    property int position: 1
    property int week: 1
    property bool wide: true

    readonly property var exercise: ProgramStore.exerciseById(entry.exerciseId, ProgramStore.revision)
    readonly property string prescription: ProgramStore.prescriptionText(entry, week)
    readonly property string load: ProgramStore.effective(entry, week, "load")
    readonly property string rest: ProgramStore.restText(entry.rest)
    readonly property bool hasDetails: entry.notes.length > 0 || (exercise !== null && (exercise.instructions.length > 0 || exercise.videoUrl.length > 0 || exercise.image.length > 0))
    property bool expanded: false

    hoverEnabled: hasDetails
    enabled: true
    padding: 12
    implicitHeight: implicitContentHeight + topPadding + bottomPadding
    onClicked: if (hasDetails) expanded = !expanded

    Accessible.name: (exercise ? exercise.name : "") + ", " + prescription

    contentItem: ColumnLayout {
        spacing: 10

        RowLayout {
            spacing: 12
            Layout.fillWidth: true

            Label {
                text: row.position
                color: Theme.textMuted
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 20
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 1
            }

            ColumnLayout {
                spacing: 3
                Layout.fillWidth: true

                Label {
                    text: row.exercise ? row.exercise.name : qsTr("Exercise")
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                // What to do: "4 × 6–8 · RPE 7 · rest 2 min"
                Flow {
                    spacing: 6
                    Layout.fillWidth: true

                    Label {
                        text: row.prescription
                        color: Theme.primary
                        font.pixelSize: Theme.fontLarge
                        font.weight: Font.Bold
                    }
                    Label {
                        visible: row.load.length > 0
                        text: "· " + row.load
                        color: Theme.text
                        font.pixelSize: Theme.fontLarge
                        font.weight: Font.DemiBold
                    }
                    Label {
                        visible: row.rest.length > 0
                        text: "· " + qsTr("rest %1").arg(row.rest)
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontLarge
                    }
                }
            }

            // Expand / collapse indicator
            Label {
                visible: row.hasDetails
                text: "›"
                rotation: row.expanded ? 90 : 0
                color: Theme.textMuted
                font.pixelSize: 22
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 20
                Layout.alignment: Qt.AlignTop

                Behavior on rotation {
                    NumberAnimation { duration: 150 }
                }
            }
        }

        // ---- details ----
        ColumnLayout {
            visible: row.expanded
            spacing: 10
            Layout.fillWidth: true
            Layout.leftMargin: 32

            Rectangle {
                visible: row.entry.notes.length > 0
                Layout.fillWidth: true
                implicitHeight: noteLabel.implicitHeight + 20
                radius: Theme.radius
                color: Theme.primarySoft

                Label {
                    id: noteLabel
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 12
                    text: qsTr("<b>Coach's note:</b> %1").arg(row.entry.notes)
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                }
            }

            Rectangle {
                visible: row.exercise !== null && row.exercise.image.length > 0
                radius: Theme.radius
                color: Theme.surfaceAlt
                Layout.fillWidth: true
                Layout.maximumWidth: 320
                Layout.preferredHeight: 200

                ExerciseImage {
                    anchors.fill: parent
                    anchors.margins: 10
                    drawing: row.exercise ? row.exercise.image : ""
                }
            }

            ColumnLayout {
                visible: row.exercise !== null && row.exercise.instructions.length > 0
                spacing: 4
                Layout.fillWidth: true

                Label {
                    text: qsTr("How to do it")
                    font.pixelSize: Theme.fontSmall
                    font.weight: Font.DemiBold
                }
                Label {
                    text: row.exercise ? row.exercise.instructions : ""
                    color: Theme.textMuted
                    wrapMode: Text.Wrap
                    lineHeight: 1.2
                    Layout.fillWidth: true
                }
                Label {
                    text: row.exercise ? row.exercise.muscleLabel + " · " + row.exercise.equipment : ""
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                }
            }

            AuraButton {
                visible: row.exercise !== null && row.exercise.videoUrl.length > 0
                variant: "secondary"
                text: qsTr("Watch video")
                onClicked: Qt.openUrlExternally(row.exercise.videoUrl)
            }
        }
    }

    background: Rectangle {
        radius: Theme.radius
        color: row.expanded ? Theme.background
             : row.hovered ? Theme.surfaceAlt
             : "transparent"
        border.width: row.expanded ? 1 : 0
        border.color: Theme.border
    }

    HoverHandler {
        cursorShape: row.hasDetails ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
}
