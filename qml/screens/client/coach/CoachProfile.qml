pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// A coach's public profile: header, bio, specialties and practical details.
// Used in the profile dialog (directory) and on the "my coach" page.
ColumnLayout {
    id: root

    property var coach: null
    property bool showHeader: true
    property bool showContact: false        // email / phone: only once they're your coach

    readonly property var details: {
        if (!coach)
            return []
        const list = [
            { label: qsTr("Works"), value: CoachStore.modesText(coach) }
        ]
        if (coach.inPerson && coach.studio)
            list.push({ label: qsTr("Where"), value: coach.studio })
        list.push({ label: qsTr("Usual hours"), value: CoachStore.hoursSummary(coach).join("\n") })
        list.push({ label: qsTr("Languages"), value: coach.languages.join(", ") })
        list.push({ label: qsTr("Qualifications"), value: coach.certifications.join(", ") })
        if (showContact) {
            list.push({ label: qsTr("Email"), value: coach.email })
            if (coach.phone)
                list.push({ label: qsTr("Phone"), value: coach.phone })
        }
        list.push({ label: qsTr("Price"), value: qsTr("From €%1 per session").arg(coach.priceFrom) })
        return list
    }

    spacing: 16

    RowLayout {
        visible: root.showHeader && root.coach !== null
        spacing: 16
        Layout.fillWidth: true

        Avatar {
            name: root.coach ? root.coach.name : ""
            size: 64
            Layout.alignment: Qt.AlignTop
        }
        ColumnLayout {
            spacing: 4
            Layout.fillWidth: true

            Label {
                text: root.coach ? root.coach.name : ""
                font.pixelSize: Theme.fontTitle
                font.weight: Font.Bold
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            Label {
                text: root.coach ? root.coach.title + " · " + root.coach.city : ""
                color: Theme.textMuted
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            Chip {
                visible: root.coach !== null && !root.coach.accepting
                text: qsTr("Not taking new clients right now")
                Layout.topMargin: 4
            }
        }
    }

    Label {
        text: root.coach ? root.coach.bio : ""
        wrapMode: Text.Wrap
        lineHeight: 1.25
        Layout.fillWidth: true
    }

    Flow {
        spacing: 6
        Layout.fillWidth: true

        Repeater {
            model: root.coach ? root.coach.specialties : []
            Chip {
                required property string modelData
                text: modelData
                tone: "primary"
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.border
    }

    Repeater {
        model: root.details

        RowLayout {
            id: detailRow
            required property var modelData
            spacing: 12
            Layout.fillWidth: true

            Label {
                text: detailRow.modelData.label
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
                font.weight: Font.DemiBold
                Layout.preferredWidth: 110
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 1
            }
            Label {
                text: detailRow.modelData.value
                wrapMode: Text.Wrap
                lineHeight: 1.2
                Layout.fillWidth: true
            }
        }
    }
}
