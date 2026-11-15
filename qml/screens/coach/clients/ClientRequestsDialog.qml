pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Requests from people who found the coach in the directory (public profile).
// Accepting adds them to the client list; the dialog stays open for the rest.
AuraDialog {
    id: dialog

    readonly property var requests: CoachStore.pendingRequests

    signal clientAccepted(string name)
    signal clientDeclined(string name)

    title: qsTr("Client requests")
    preferredWidth: 640

    Label {
        text: dialog.requests.length > 0
              ? qsTr("These people found you in the coach directory and would like to train with you.")
              : ""
        visible: text.length > 0
        color: Theme.textMuted
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    EmptyState {
        visible: dialog.requests.length === 0
        Layout.fillWidth: true
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        title: qsTr("No requests right now")
        message: qsTr("New requests from the coach directory will show up here.")
    }

    Repeater {
        model: dialog.requests

        Rectangle {
            id: request
            required property var modelData
            required property int index

            Layout.fillWidth: true
            implicitHeight: requestColumn.implicitHeight + 32
            radius: Theme.radiusLarge
            color: Theme.surface
            border.width: 1
            border.color: Theme.border

            ColumnLayout {
                id: requestColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 10

                RowLayout {
                    spacing: 12
                    Layout.fillWidth: true

                    Avatar {
                        name: request.modelData.name
                        size: 44
                    }
                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true

                        Label {
                            text: request.modelData.name
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: request.modelData.email
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSmall
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                    Label {
                        text: ClientStore.relativeDay(request.modelData.since)
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSmall
                        Layout.alignment: Qt.AlignTop
                    }
                }

                Label {
                    text: qsTr("<b>Goal:</b> %1").arg(request.modelData.goal)
                          + (request.modelData.message ? "<br>" + request.modelData.message : "")
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    lineHeight: 1.2
                    Layout.fillWidth: true
                }

                RowLayout {
                    spacing: 8
                    Layout.alignment: Qt.AlignRight

                    AuraButton {
                        variant: "ghostDanger"
                        text: qsTr("Decline")
                        onClicked: {
                            const name = request.modelData.name
                            CoachStore.declineRequest(request.modelData.email)
                            dialog.clientDeclined(name)
                        }
                    }
                    AuraButton {
                        text: qsTr("Accept")
                        onClicked: {
                            const name = request.modelData.name
                            CoachStore.acceptRequest(request.modelData.email)
                            dialog.clientAccepted(name)
                        }
                    }
                }
            }
        }
    }

    actions: AuraButton {
        variant: "secondary"
        text: qsTr("Close")
        onClicked: dialog.close()
    }
}
