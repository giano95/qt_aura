import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// One exercise in the library grid. Click to edit.
AbstractButton {
    id: card

    property var exercise: ({ id: "", name: "", muscleTags: [], equipment: "", instructions: "", image: "", builtIn: false })

    hoverEnabled: true
    padding: 18
    implicitWidth: 280
    implicitHeight: implicitContentHeight + topPadding + bottomPadding

    contentItem: ColumnLayout {
        spacing: 8

        Rectangle {
            visible: card.exercise.image !== ""
            radius: Theme.radius
            color: Theme.surfaceAlt
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            Layout.bottomMargin: 4

            ExerciseImage {
                anchors.fill: parent
                anchors.margins: 8
                drawing: card.exercise.image
            }
        }

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

            // Each group's parts, or the group itself
            Repeater {
                model: card.exercise.muscleTags
                Chip {
                    required property string modelData
                    text: modelData
                    tone: "primary"
                }
            }
            Chip { text: card.exercise.equipment }
            Chip { visible: !card.exercise.builtIn; text: qsTr("Custom"); tone: "accent" }
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
