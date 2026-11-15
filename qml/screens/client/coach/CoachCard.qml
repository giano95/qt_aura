pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// A coach in the directory. Click to see the full profile.
AbstractButton {
    id: card

    property var coach: ({ name: "", title: "", city: "", online: false, inPerson: false,
                           specialties: [], priceFrom: 0, accepting: true, years: 0 })

    hoverEnabled: true
    padding: 20
    implicitWidth: 320
    implicitHeight: implicitContentHeight + topPadding + bottomPadding

    contentItem: ColumnLayout {
        spacing: 12

        RowLayout {
            spacing: 14
            Layout.fillWidth: true

            Avatar {
                name: card.coach.name
                size: 52
            }
            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true

                Label {
                    text: card.coach.name
                    font.pixelSize: Theme.fontLarge
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Label {
                    text: card.coach.title
                    color: Theme.textMuted
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Label {
                    text: card.coach.city + " · " + CoachStore.modesText(card.coach)
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Chip {
                    visible: !card.coach.accepting
                    text: qsTr("Not taking new clients")
                    Layout.topMargin: 4
                }
            }
        }

        Flow {
            spacing: 6
            Layout.fillWidth: true

            Repeater {
                model: card.coach.specialties
                Chip {
                    required property string modelData
                    text: modelData
                    tone: "primary"
                }
            }
        }

        Item { Layout.fillHeight: true }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.border
        }

        RowLayout {
            spacing: 8
            Layout.fillWidth: true

            Label {
                text: qsTr("From €%1 / session").arg(card.coach.priceFrom)
                font.weight: Font.DemiBold
            }
            Label {
                text: "· " + (card.coach.years === 1 ? qsTr("1 year") : qsTr("%1 years").arg(card.coach.years))
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
            }
            Item { Layout.fillWidth: true }
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
