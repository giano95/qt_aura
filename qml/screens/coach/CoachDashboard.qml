pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Coach landing page: today's numbers, today's sessions, clients to follow up.
ScrollView {
    id: page

    signal navigateRequested(int index)

    // Coach app tab indices (see CoachHome)
    readonly property int clientsTab: 1
    readonly property int calendarTab: 2

    readonly property bool twoColumns: availableWidth >= 860

    contentWidth: availableWidth
    padding: width < 600 ? 16 : 32

    function statusLabel(status) {
        switch (status) {
        case "done": return qsTr("Done")
        case "next": return qsTr("Next")
        default: return qsTr("Upcoming")
        }
    }

    ColumnLayout {
        width: page.availableWidth
        spacing: 24

        GreetingHeader {
            Layout.fillWidth: true
            name: Session.firstName
            subtitle: Qt.formatDate(new Date(), "dddd d MMMM")

            AuraButton {
                text: qsTr("Add client")
                onClicked: page.navigateRequested(page.clientsTab)
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: page.availableWidth >= 760 ? 4 : 2
            columnSpacing: 16
            rowSpacing: 16

            Repeater {
                model: MockData.coachStats
                StatCard {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    label: modelData.label
                    value: modelData.value
                    note: modelData.note
                    tone: modelData.tone
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: page.twoColumns ? 2 : 1
            columnSpacing: 16
            rowSpacing: 16

            Card {
                title: qsTr("Today's sessions")
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 3

                Repeater {
                    model: MockData.coachTodaySessions

                    RowLayout {
                        id: sessionRow
                        required property var modelData
                        spacing: 12
                        Layout.fillWidth: true
                        opacity: modelData.status === "done" ? 0.6 : 1

                        Label {
                            text: sessionRow.modelData.time
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                            Layout.preferredWidth: 48
                        }
                        Avatar {
                            name: sessionRow.modelData.client
                            size: 36
                        }
                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true

                            Label {
                                text: sessionRow.modelData.client
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Label {
                                text: sessionRow.modelData.type + " · " + sessionRow.modelData.mode
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontSmall
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                        Chip {
                            text: page.statusLabel(sessionRow.modelData.status)
                            tone: sessionRow.modelData.status === "next" ? "primary" : "neutral"
                        }
                    }
                }

                AuraButton {
                    variant: "ghost"
                    text: qsTr("Open calendar →")
                    leftPadding: 0
                    onClicked: page.navigateRequested(page.calendarTab)
                }
            }

            Card {
                title: qsTr("Needs your attention")
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 2

                Repeater {
                    model: MockData.coachAttention

                    RowLayout {
                        id: attentionRow
                        required property var modelData
                        spacing: 12
                        Layout.fillWidth: true

                        Avatar {
                            name: attentionRow.modelData.client
                            size: 36
                        }
                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true

                            Label {
                                text: attentionRow.modelData.client
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Label {
                                text: attentionRow.modelData.reason
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontSmall
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }
                        Chip {
                            text: attentionRow.modelData.tag
                            tone: attentionRow.modelData.tone
                        }
                    }
                }

                AuraButton {
                    variant: "ghost"
                    text: qsTr("All clients →")
                    leftPadding: 0
                    onClicked: page.navigateRequested(page.clientsTab)
                }
            }
        }
    }
}
