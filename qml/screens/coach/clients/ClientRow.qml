import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// One client in the list. Wide: table-like row. Narrow: compact card.
// Clients without a running program get an "Assign program" button.
AbstractButton {
    id: row

    property var client: ({ id: 0, name: "", email: "", status: "active", lastCheckIn: 0, assignments: [] })
    property bool wide: true
    property int programColumnWidth: 290
    property int checkInColumnWidth: 110
    property int actionColumnWidth: 150

    readonly property var status: ClientStore.programStatus(client)
    readonly property bool needsProgram: (status.kind === "none" || status.kind === "expired") && client.status !== "invited"
    readonly property string programName: status.assignment ? status.assignment.programName : qsTr("No program")

    signal assignRequested()

    hoverEnabled: true
    padding: 16
    topPadding: 12
    bottomPadding: 12
    implicitHeight: implicitContentHeight + topPadding + bottomPadding

    contentItem: Item {
        implicitHeight: row.wide ? wideRow.implicitHeight : narrowColumn.implicitHeight

        // ---- wide ----
        RowLayout {
            id: wideRow
            visible: row.wide
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16

            RowLayout {
                spacing: 12
                Layout.fillWidth: true

                Avatar {
                    name: row.client.name
                    size: 40
                }
                ColumnLayout {
                    id: nameColumn
                    spacing: 2
                    Layout.fillWidth: true

                    RowLayout {
                        spacing: 8
                        Layout.fillWidth: true
                        Label {
                            text: row.client.name
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Layout.maximumWidth: nameColumn.width - (statusChip.visible ? statusChip.width + 8 : 0)
                        }
                        Chip {
                            id: statusChip
                            visible: row.client.status !== "active"
                            text: row.client.status === "invited" ? qsTr("Invite sent") : qsTr("Paused")
                        }
                        Item { Layout.fillWidth: true }
                    }
                    Label {
                        text: row.client.email
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSmall
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            ColumnLayout {
                spacing: 4
                Layout.preferredWidth: row.programColumnWidth
                Layout.fillWidth: false

                Label {
                    text: row.programName
                    color: row.status.assignment ? Theme.text : Theme.textMuted
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                RowLayout {
                    spacing: 10
                    Layout.fillWidth: true

                    Chip {
                        visible: row.status.kind !== "none"
                        text: ClientStore.statusText(row.status)
                        tone: ClientStore.statusTone(row.status)
                    }
                    ProgressTrack {
                        visible: row.status.kind === "active" || row.status.kind === "endingSoon"
                        value: row.status.progress || 0
                        fillColor: row.status.kind === "endingSoon" ? Theme.accent : Theme.primary
                        implicitHeight: 6
                        Layout.fillWidth: true
                        Layout.maximumWidth: 110
                    }
                }
            }

            Label {
                text: ClientStore.relativeDay(row.client.lastCheckIn)
                color: row.client.lastCheckIn && ClientStore.daysBetween(row.client.lastCheckIn, ClientStore.today()) > 7
                       ? Theme.danger : Theme.textMuted
                Layout.preferredWidth: row.checkInColumnWidth
            }

            Item {
                Layout.preferredWidth: row.actionColumnWidth
                implicitHeight: assignButton.implicitHeight

                AuraButton {
                    id: assignButton
                    visible: row.needsProgram
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    variant: row.status.kind === "expired" ? "primary" : "secondary"
                    text: qsTr("Assign program")
                    implicitHeight: 36
                    leftPadding: 14
                    rightPadding: 14
                    onClicked: row.assignRequested()
                }
                Label {
                    visible: !row.needsProgram
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: "›"
                    color: Theme.textMuted
                    font.pixelSize: 22
                }
            }
        }

        // ---- narrow ----
        ColumnLayout {
            id: narrowColumn
            visible: !row.wide
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            RowLayout {
                spacing: 12
                Layout.fillWidth: true

                Avatar {
                    name: row.client.name
                    size: 40
                }
                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true

                    Label {
                        text: row.client.name
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Label {
                        text: row.client.status === "invited" ? qsTr("Invite sent") : row.programName
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSmall
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
                Chip {
                    visible: row.status.kind !== "none"
                    text: ClientStore.statusText(row.status)
                    tone: ClientStore.statusTone(row.status)
                }
            }

            AuraButton {
                visible: row.needsProgram
                variant: row.status.kind === "expired" ? "primary" : "secondary"
                text: qsTr("Assign program")
                implicitHeight: 36
                Layout.fillWidth: true
                onClicked: row.assignRequested()
            }
        }
    }

    background: Rectangle {
        radius: Theme.radiusLarge
        color: Theme.surface
        border.width: row.hovered || row.visualFocus ? 1.5 : 1
        border.color: row.hovered || row.visualFocus ? Theme.primary
                    : row.status.kind === "expired" ? Qt.alpha(Theme.danger, 0.45)
                    : Theme.border

        // Red edge marks an expired program
        Rectangle {
            visible: row.status.kind === "expired"
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 1
            width: 4
            radius: 2
            color: Theme.danger
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
