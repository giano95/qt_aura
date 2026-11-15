import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Exercise library page (its own entry in the coach sidebar).
ScrollView {
    id: page

    contentWidth: availableWidth
    padding: width < 600 ? 16 : 32

    ColumnLayout {
        width: page.availableWidth
        spacing: 20

        PageHeader {
            Layout.fillWidth: true
            title: qsTr("Exercise library")
            subtitle: qsTr("Every exercise you can add to a program. Add your own anytime.")

            AuraButton {
                text: qsTr("New exercise")
                onClicked: library.createExercise("")
            }
        }

        ExerciseLibrary {
            id: library
            Layout.fillWidth: true
        }
    }
}
