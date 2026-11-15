pragma Singleton
import QtQuick

// Design tokens for the whole app. Every color, radius and font size used by
// screens and components comes from here, so restyling happens in one place.
QtObject {
    id: theme

    // Follows the OS color scheme until the user toggles it manually.
    property bool dark: Application.styleHints.colorScheme === Qt.Dark

    // Surfaces
    readonly property color background: dark ? "#111513" : "#F5F4F0"
    readonly property color surface: dark ? "#1A1F1D" : "#FFFFFF"
    readonly property color surfaceAlt: dark ? "#232A27" : "#EEEDE8"
    readonly property color border: dark ? "#2E3633" : "#E1DFD8"

    // Text
    readonly property color text: dark ? "#EBEFED" : "#191C1A"
    readonly property color textMuted: dark ? "#97A39D" : "#5E6761"

    // Brand and status
    readonly property color primary: dark ? "#3FCFA9" : "#0E7C66"
    readonly property color primaryHover: dark ? "#5ADDB9" : "#0B6B58"
    readonly property color textOnPrimary: dark ? "#052019" : "#FFFFFF"
    readonly property color primarySoft: dark ? "#16352D" : "#DCEFE9"
    readonly property color accent: dark ? "#F2B25C" : "#A35D06"
    readonly property color accentSoft: dark ? "#3A2C17" : "#FBEBD3"
    readonly property color danger: dark ? "#FF8A80" : "#B3261E"
    readonly property color dangerSoft: dark ? "#3B1D1B" : "#FBE3E1"

    // Brand gradient, identical in light and dark mode
    readonly property color brandTop: "#0F8A70"
    readonly property color brandBottom: "#0A3F35"

    // Metrics
    readonly property int radius: 10
    readonly property int radiusLarge: 16
    readonly property int controlHeight: 44

    // Type scale (px)
    readonly property int fontSmall: 12
    readonly property int fontBody: 14
    readonly property int fontLarge: 16
    readonly property int fontTitle: 22
    readonly property int fontHeadline: 28
    readonly property int fontDisplay: 36

    function toneColor(tone) {
        switch (tone) {
        case "primary": return primary
        case "accent": return accent
        case "danger": return danger
        default: return textMuted
        }
    }

    function toneSoftColor(tone) {
        switch (tone) {
        case "primary": return primarySoft
        case "accent": return accentSoft
        case "danger": return dangerSoft
        default: return surfaceAlt
        }
    }
}
