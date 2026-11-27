import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// App settings, the same for coaches and clients. Saved on this device
// (AppSettings). For now: appearance (system, light or dark).
ScrollView {
    id: page

    readonly property var modes: ["system", "light", "dark"]

    contentWidth: availableWidth
    padding: width < 600 ? 16 : 32

    ColumnLayout {
        width: page.availableWidth
        spacing: 24

        PageHeader {
            title: qsTr("Settings")
            subtitle: qsTr("Saved on this device.")
            Layout.fillWidth: true
        }

        Card {
            title: qsTr("Appearance")
            Layout.fillWidth: true
            Layout.maximumWidth: 640

            Label {
                text: qsTr("Choose how Aura looks. System follows your device's setting.")
                color: Theme.textMuted
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            SegmentedTabs {
                id: themeTabs
                model: [qsTr("System"), qsTr("Light"), qsTr("Dark")]
                currentIndex: Math.max(0, page.modes.indexOf(AppSettings.themeMode))
                Layout.fillWidth: true
                Layout.maximumWidth: 360
                Accessible.name: qsTr("Appearance")
                onCurrentIndexChanged: AppSettings.themeMode = page.modes[currentIndex]
            }

            Label {
                visible: AppSettings.themeMode === "system"
                text: Theme.dark ? qsTr("Your device is using dark mode now.")
                                 : qsTr("Your device is using light mode now.")
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
                Layout.fillWidth: true
            }
        }
    }

    // A click replaces the tabs' binding; follow changes made elsewhere too
    Connections {
        target: AppSettings
        function onThemeModeChanged() {
            themeTabs.currentIndex = Math.max(0, page.modes.indexOf(AppSettings.themeMode))
        }
    }
}
