pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Coach directory for clients without a coach: search, filter, open a profile.
// Requesting a coach is done from the profile dialog.
ColumnLayout {
    id: root

    property string mode: "all"            // "all" | "online" | "inPerson"

    readonly property var results: CoachStore.search(search.text, mode)
    readonly property int columns: Math.max(1, Math.min(3, Math.floor((width + 16) / 336)))

    // The profile dialog's "Request" button
    signal requestRequested(int coachId)
    signal profileRequested(int coachId)

    spacing: 16

    PageHeader {
        Layout.fillWidth: true
        title: qsTr("Find your coach")
        subtitle: qsTr("You don't have a coach yet. Pick one to work with: they'll see your request and get back to you.")
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        AuraSearchField {
            id: search
            placeholderText: qsTr("Search by name, city or specialty")
            Layout.fillWidth: true
            Layout.maximumWidth: 420
        }
        Item { Layout.fillWidth: true }
        Label {
            text: root.results.length === 1 ? qsTr("1 coach") : qsTr("%1 coaches").arg(root.results.length)
            color: Theme.textMuted
        }
    }

    Flow {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: [
                { key: "all", label: qsTr("All") },
                { key: "online", label: qsTr("Online") },
                { key: "inPerson", label: qsTr("In person") }
            ]
            FilterChip {
                required property var modelData
                text: modelData.label
                selected: root.mode === modelData.key
                onClicked: root.mode = modelData.key
            }
        }
    }

    GridLayout {
        visible: root.results.length > 0
        Layout.fillWidth: true
        columns: root.columns
        columnSpacing: 16
        rowSpacing: 16

        Repeater {
            model: root.results

            CoachCard {
                required property var modelData
                coach: modelData
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                onClicked: root.profileRequested(modelData.id)
            }
        }
    }

    EmptyState {
        visible: root.results.length === 0
        Layout.fillWidth: true
        Layout.topMargin: 40
        title: qsTr("No coaches match your search")
        message: qsTr("Try another name or city, or a different filter.")

        AuraButton {
            variant: "secondary"
            text: qsTr("Show all coaches")
            onClicked: {
                search.text = ""
                root.mode = "all"
            }
        }
    }
}
