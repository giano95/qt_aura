import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Programs overview: the coach's programs.
ScrollView {
    id: page

    signal editRequested(int programId)

    contentWidth: availableWidth
    padding: width < 600 ? 16 : 32

    ColumnLayout {
        width: page.availableWidth
        spacing: 20

        PageHeader {
            Layout.fillWidth: true
            title: qsTr("Programs")
            subtitle: qsTr("Build training programs once and assign them to any client.")

            AuraButton {
                text: qsTr("New program")
                onClicked: page.editRequested(0)
            }
        }

        ProgramList {
            Layout.fillWidth: true
            onEditRequested: programId => page.editRequested(programId)
        }
    }
}
