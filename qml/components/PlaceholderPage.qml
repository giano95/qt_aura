pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Stand-in for a screen that isn't designed yet. Lists what the screen will
// do, so the prototype doubles as the feature spec.
ScrollView {
    id: page

    property string title: ""
    property string summary: ""
    property var plannedFeatures: []

    contentWidth: availableWidth
    padding: width < 600 ? 16 : 32

    ColumnLayout {
        width: page.availableWidth
        spacing: 16

        Label {
            text: page.title
            font.pixelSize: Theme.fontHeadline
            font.weight: Font.Bold
            Layout.fillWidth: true
        }
        Label {
            text: page.summary
            color: Theme.textMuted
            font.pixelSize: Theme.fontLarge
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Layout.maximumWidth: 640
        }
        Chip {
            text: qsTr("Not designed yet")
            tone: "accent"
        }

        Card {
            title: qsTr("Planned for this screen")
            Layout.fillWidth: true
            Layout.maximumWidth: 640
            Layout.topMargin: 8

            Repeater {
                model: page.plannedFeatures
                RowLayout {
                    id: featureRow
                    required property string modelData
                    spacing: 12
                    Layout.fillWidth: true

                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 7
                        implicitWidth: 6
                        implicitHeight: 6
                        radius: 3
                        color: Theme.primary
                    }
                    Label {
                        text: featureRow.modelData
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
