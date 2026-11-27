pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Programs overview: grid of the coach's programs, with search and a
// "new program" tile.
ScrollView {
    id: page

    signal editRequested(string programId)

    readonly property var results: ProgramStore.searchPrograms(search.text, ProgramStore.revision)
    readonly property int columns: Math.max(1, Math.min(3, Math.floor((availableWidth + 16) / 316)))

    contentWidth: availableWidth
    padding: width < 600 ? 16 : 32

    ColumnLayout {
        width: page.availableWidth
        spacing: 16

        PageHeader {
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            title: qsTr("Programs")
            subtitle: qsTr("Build training programs once and assign them to any client.")

            AuraButton {
                text: qsTr("New program")
                onClicked: page.editRequested("")
            }
        }

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
                text: page.results.length === 1 ? qsTr("1 program") : qsTr("%1 programs").arg(page.results.length)
                color: Theme.textMuted
            }
        }

        GridLayout {
            visible: page.results.length > 0 || search.text.length === 0
            Layout.fillWidth: true
            columns: page.columns
            columnSpacing: 16
            rowSpacing: 16

            Repeater {
                model: page.results

                ProgramCard {
                    required property var modelData
                    program: modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    onClicked: page.editRequested(modelData.id)
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
                onClicked: page.editRequested("")

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
            visible: page.results.length === 0 && search.text.length > 0
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
}
