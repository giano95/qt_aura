pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Grid of the coach's programs, with search and a "new program" tile.
ColumnLayout {
    id: root

    signal editRequested(int programId)

    readonly property var results: ProgramStore.searchPrograms(search.text)
    readonly property int columns: Math.max(1, Math.min(3, Math.floor((width + 16) / 316)))

    spacing: 16

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        AuraSearchField {
            id: search
            placeholderText: qsTr("Search programs")
            Layout.fillWidth: true
            Layout.maximumWidth: 420
        }
        Item { Layout.fillWidth: true }
        Label {
            text: root.results.length === 1 ? qsTr("1 program") : qsTr("%1 programs").arg(root.results.length)
            color: Theme.textMuted
        }
    }

    GridLayout {
        visible: root.results.length > 0 || search.text.length === 0
        Layout.fillWidth: true
        columns: root.columns
        columnSpacing: 16
        rowSpacing: 16

        Repeater {
            model: root.results

            ProgramCard {
                required property var modelData
                program: modelData
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                onClicked: root.editRequested(modelData.id)
            }
        }

        // "New program" tile, always last
        AbstractButton {
            id: newTile
            visible: search.text.length === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            Layout.minimumHeight: 180
            hoverEnabled: true
            onClicked: root.editRequested(0)

            contentItem: ColumnLayout {
                spacing: 6

                Item { Layout.fillHeight: true }
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 44
                    implicitHeight: 44
                    radius: 22
                    color: Theme.primarySoft
                    Label {
                        anchors.centerIn: parent
                        text: "+"
                        color: Theme.primary
                        font.pixelSize: 24
                        font.weight: Font.DemiBold
                    }
                }
                Label {
                    text: qsTr("New program")
                    font.weight: Font.DemiBold
                    Layout.alignment: Qt.AlignHCenter
                }
                Label {
                    text: qsTr("Start from an empty program")
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                    Layout.alignment: Qt.AlignHCenter
                }
                Item { Layout.fillHeight: true }
            }

            background: Rectangle {
                radius: Theme.radiusLarge
                color: newTile.hovered ? Theme.primarySoft : "transparent"
                border.width: 1.5
                border.color: newTile.hovered ? Theme.primary : Theme.border
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
        }
    }

    EmptyState {
        visible: root.results.length === 0 && search.text.length > 0
        Layout.fillWidth: true
        Layout.topMargin: 40
        title: qsTr("No programs match \"%1\"").arg(search.text)
        message: qsTr("Try a different name, or create a new program.")

        AuraButton {
            variant: "secondary"
            text: qsTr("Clear search")
            onClicked: search.text = ""
        }
    }
}
