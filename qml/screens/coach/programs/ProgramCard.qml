import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Summary card for one program. Click to edit.
AbstractButton {
    id: card

    property var program: ({ id: 0, name: "", description: "", weeks: "", updatedAt: 0, days: [] })

    readonly property int dayCount: program.days.length
    readonly property int exerciseCount: ProgramStore.exerciseCount(program)
    readonly property int clientCount: ClientStore.countForProgram(program.id, ClientStore.revision)
    readonly property int changedWeekCount: ProgramStore.programChangedWeeks(program).length

    hoverEnabled: true
    padding: 20
    implicitWidth: 300
    implicitHeight: implicitContentHeight + topPadding + bottomPadding

    contentItem: ColumnLayout {
        spacing: 10

        Label {
            text: card.program.name
            font.pixelSize: Theme.fontLarge
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
        Label {
            visible: text.length > 0
            text: card.program.description
            color: Theme.textMuted
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Flow {
            spacing: 6
            Layout.fillWidth: true
            Layout.topMargin: 2

            Chip { text: card.dayCount === 1 ? qsTr("1 day") : qsTr("%1 days").arg(card.dayCount) }
            Chip { text: card.exerciseCount === 1 ? qsTr("1 exercise") : qsTr("%1 exercises").arg(card.exerciseCount) }
            Chip {
                visible: card.program.weeks.length > 0
                text: card.program.weeks === "1" ? qsTr("1 week") : qsTr("%1 weeks").arg(card.program.weeks)
            }
            Chip {
                visible: card.changedWeekCount > 0
                tone: "accent"
                text: qsTr("Weekly progression")
            }
        }

        Item { Layout.fillHeight: true }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.border
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                text: card.clientCount > 0
                      ? (card.clientCount === 1 ? qsTr("1 client") : qsTr("%1 clients").arg(card.clientCount))
                      : qsTr("Not assigned")
                color: card.clientCount > 0 ? Theme.primary : Theme.textMuted
                font.pixelSize: Theme.fontSmall
                font.weight: Font.DemiBold
            }
            Item { Layout.fillWidth: true }
            Label {
                text: ProgramStore.editedLabel(card.program.updatedAt)
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
            }
        }
    }

    background: Rectangle {
        radius: Theme.radiusLarge
        color: Theme.surface
        border.width: card.hovered || card.visualFocus ? 1.5 : 1
        border.color: card.hovered || card.visualFocus ? Theme.primary : Theme.border
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
