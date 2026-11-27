pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Program editor: how much of one week of the program (the week picked in
// the editor; 0 = the all-weeks values) goes to each muscle group and each
// of its parts, by one metric: exercises or sets. A group's bar is its
// share of the whole program; a part's bar, its share of its group. Every
// group and part is listed, empty ones with an empty bar. "Min" hides the
// parts.
// Counting is ProgramStore.muscleSummary().
Card {
    id: root

    property var program: null
    property int week: 0
    property int revision: 0        // the editor's, bumped on in-place edits
    property bool wide: true

    readonly property var metrics: ["exercises", "sets"]
    readonly property string metric: metrics[metricTabs.currentIndex]
    readonly property bool showParts: detailTabs.currentIndex === 1
    readonly property var summary: program
        ? ProgramStore.muscleSummary(program, week, metric, revision, ProgramStore.revision)
        : ({ total: 0, groups: [] })

    // "3 sets · 25%"
    function valueText(value, share) {
        const text = metric === "sets"
            ? (value === 1 ? qsTr("1 set") : qsTr("%1 sets").arg(value))
            : (value === 1 ? qsTr("1 exercise") : qsTr("%1 exercises").arg(value))
        return text + " · " + Math.round(share * 100) + "%"
    }

    // One muscle: name, value, and a bar for its share
    component ShareRow: ColumnLayout {
        id: shareRow

        property string name: ""
        property string valueText: ""
        property bool empty: true
        property real share: 0
        property bool part: false

        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                text: shareRow.name
                color: shareRow.empty ? Theme.textMuted : Theme.text
                font.pixelSize: shareRow.part ? Theme.fontSmall + 1 : Theme.fontBody
                font.weight: shareRow.part ? Font.Normal : Font.DemiBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Label {
                text: shareRow.valueText
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: shareRow.part ? 4 : 6
            radius: height / 2
            color: Theme.surfaceAlt

            Rectangle {
                width: parent.width * shareRow.share
                height: parent.height
                radius: parent.radius
                color: Theme.primary
                opacity: shareRow.part ? 0.55 : 1
            }
        }
    }

    title: qsTr("Muscles worked")

    GridLayout {
        Layout.fillWidth: true
        columns: root.wide ? 2 : 1
        columnSpacing: 24
        rowSpacing: 10

        Label {
            text: (root.week === 0 ? qsTr("Per week, with the all-weeks values.")
                                   : qsTr("In week %1.").arg(root.week))
                  + " " + qsTr("A group's bar is its share of the program, a part's bar its share of the group. An exercise counts toward every muscle it works.")
            color: Theme.textMuted
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
        RowLayout {
            spacing: 8
            Layout.alignment: Qt.AlignTop | (root.wide ? Qt.AlignRight : Qt.AlignLeft)

            SegmentedTabs {
                id: metricTabs
                model: [qsTr("Exercises"), qsTr("Sets")]
                currentIndex: 1
            }
            // Muscle group details: Min hides the parts
            SegmentedTabs {
                id: detailTabs
                model: [qsTr("Min"), qsTr("Max")]
                currentIndex: 1
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        columns: root.wide ? 2 : 1
        columnSpacing: 32
        rowSpacing: 18

        Repeater {
            model: root.summary.groups

            ColumnLayout {
                id: group

                required property var modelData

                spacing: 8
                Layout.fillWidth: true
                Layout.fillHeight: false        // keep parts packed when the row's other group is taller
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop

                ShareRow {
                    Layout.fillWidth: true
                    name: group.modelData.name
                    valueText: root.valueText(group.modelData.value, group.modelData.share)
                    empty: group.modelData.value === 0
                    share: group.modelData.share
                }

                // Its parts, indented under it
                RowLayout {
                    visible: root.showParts && group.modelData.parts.length > 0
                    Layout.fillWidth: true
                    Layout.leftMargin: 6
                    spacing: 12

                    Rectangle {
                        implicitWidth: 2
                        radius: 1
                        color: Theme.border
                        Layout.fillHeight: true
                    }
                    ColumnLayout {
                        spacing: 6
                        Layout.fillWidth: true

                        Repeater {
                            model: group.modelData.parts

                            ShareRow {
                                required property var modelData
                                Layout.fillWidth: true
                                name: modelData.name
                                valueText: root.valueText(modelData.value, modelData.share)
                                empty: modelData.value === 0
                                share: modelData.share
                                part: true
                            }
                        }
                    }
                }
            }
        }
    }
}
