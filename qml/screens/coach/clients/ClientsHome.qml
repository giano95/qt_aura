pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Client list: search, filter by program status, invite, assign programs.
Item {
    id: page

    signal openRequested(string clientId)

    property string filter: "all"

    readonly property var results: ClientStore.search(search.text, filter, ClientStore.revision)
    readonly property bool wide: scroll.availableWidth >= 760
    readonly property int programColumnWidth: 290
    readonly property int checkInColumnWidth: 110
    readonly property int actionColumnWidth: 150
    readonly property int expiredCount: ClientStore.count("expired", ClientStore.revision)
    readonly property int requestCount: CoachStore.pendingRequests.length

    readonly property var filters: [
        { key: "all", label: qsTr("All") },
        { key: "expired", label: qsTr("Program expired") },
        { key: "endingSoon", label: qsTr("Ending soon") },
        { key: "none", label: qsTr("No program") },
        { key: "invited", label: qsTr("Invited") },
        { key: "paused", label: qsTr("Paused") }
    ]

    ScrollView {
    id: scroll
    anchors.fill: parent
    contentWidth: availableWidth
    padding: width < 600 ? 16 : 32

    ColumnLayout {
        width: scroll.availableWidth
        spacing: 16

        PageHeader {
            Layout.fillWidth: true
            title: qsTr("Clients")
            subtitle: qsTr("Everyone you coach, and where they are with their program.")

            // Profile visibility decides how new clients join (see CoachStore)
            AuraButton {
                variant: "secondary"
                text: CoachStore.isPublic ? qsTr("Public profile") : qsTr("Private profile")
                onClicked: visibilityDialog.openEditor()
            }
            AuraButton {
                visible: !CoachStore.isPublic
                text: qsTr("Invite client")
                onClicked: inviteDialog.openNew()
            }
            AuraButton {
                visible: CoachStore.isPublic
                text: page.requestCount > 0 ? qsTr("Accept clients · %1").arg(page.requestCount) : qsTr("Accept clients")
                onClicked: requestsDialog.open()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            AuraSearchField {
                id: search
                placeholderText: qsTr("Search by name, email or program")
                Layout.fillWidth: true
                Layout.maximumWidth: 420
            }
            Item { Layout.fillWidth: true }
            Label {
                text: page.results.length === 1 ? qsTr("1 client") : qsTr("%1 clients").arg(page.results.length)
                color: Theme.textMuted
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: page.filters
                FilterChip {
                    required property var modelData
                    text: modelData.label
                    count: String(ClientStore.count(modelData.key, ClientStore.revision))
                    selected: page.filter === modelData.key
                    onClicked: page.filter = modelData.key
                }
            }
        }

        // Column headings (desktop)
        RowLayout {
            visible: page.wide && page.results.length > 0
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: 16

            Label {
                text: qsTr("Client")
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }
            Label {
                text: qsTr("Program")
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
                font.weight: Font.DemiBold
                Layout.preferredWidth: page.programColumnWidth
            }
            Label {
                text: qsTr("Last check-in")
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
                font.weight: Font.DemiBold
                Layout.preferredWidth: page.checkInColumnWidth
            }
            Item { Layout.preferredWidth: page.actionColumnWidth }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: page.results

                ClientRow {
                    required property var modelData
                    Layout.fillWidth: true
                    client: modelData
                    wide: page.wide
                    programColumnWidth: page.programColumnWidth
                    checkInColumnWidth: page.checkInColumnWidth
                    actionColumnWidth: page.actionColumnWidth
                    onClicked: page.openRequested(modelData.id)
                    onAssignRequested: assignDialog.openFor(modelData.id)
                }
            }
        }

        EmptyState {
            visible: page.results.length === 0
            Layout.fillWidth: true
            Layout.topMargin: 40
            title: search.text.length > 0 ? qsTr("No clients match \"%1\"").arg(search.text)
                                          : qsTr("No clients here")
            message: page.filter !== "all" ? qsTr("Try another filter.") : ""

            AuraButton {
                visible: page.filter !== "all" || search.text.length > 0
                variant: "secondary"
                text: qsTr("Show all clients")
                onClicked: {
                    page.filter = "all"
                    search.text = ""
                }
            }
        }
    }
    }

    AssignProgramDialog {
        id: assignDialog
        onAssigned: (clientName, programName) => toast.show(qsTr("%1 assigned to %2").arg(programName).arg(clientName))
    }

    InviteClientDialog {
        id: inviteDialog
        onInvited: clientId => page.openRequested(clientId)
    }

    ClientRequestsDialog {
        id: requestsDialog
        onClientAccepted: name => toast.show(qsTr("%1 is now your client").arg(name))
        onClientDeclined: name => toast.show(qsTr("Request from %1 declined").arg(name))
    }

    ProfileVisibilityDialog {
        id: visibilityDialog
        onSaved: visibility => toast.show(visibility === "public"
                                         ? qsTr("Your profile is public")
                                         : qsTr("Your profile is private"))
    }

    Toast {
        id: toast
    }
}
