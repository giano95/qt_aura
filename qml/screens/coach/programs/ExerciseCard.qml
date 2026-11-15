import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// One exercise in the library grid. Click to edit.
AbstractButton {
    id: card

    property var exercise: ({ id: 0, name: "", muscle: "", equipment: "", instructions: "" })
    readonly property int usage: ProgramStore.usageCount(exercise.id)

    hoverEnabled: true
    padding: 18
    implicitWidth: 280
    implicitHeight: implicitContentHeight + topPadding + bottomPadding

    contentItem: ColumnLayout {
        spacing: 8

        Label {
            text: card.exercise.name
            font.pixelSize: Theme.fontLarge
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
        Flow {
            spacing: 6
            Layout.fillWidth: true

            Chip { text: card.exercise.muscle; tone: "primary" }
            Chip { text: card.exercise.equipment }
        }
        Label {
            visible: text.length > 0
            text: card.exercise.instructions
            color: Theme.textMuted
            font.pixelSize: Theme.fontSmall + 1
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Item { Layout.fillHeight: true }
        Label {
            text: card.usage === 0 ? qsTr("Not used in any program")
                : card.usage === 1 ? qsTr("Used in 1 program")
                : qsTr("Used in %1 programs").arg(card.usage)
            color: Theme.textMuted
            font.pixelSize: Theme.fontSmall
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
