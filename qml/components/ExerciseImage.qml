import QtQuick

// Line drawing of an exercise (Open Exercise Art, CC BY-SA 4.0): dark lines in
// the light theme, light lines in the dark one. Hidden when the exercise has
// no drawing. Size it from outside; the drawing keeps its aspect ratio.
Image {
    // Exercise.image: a drawing id, "" = none
    property string drawing: ""

    visible: drawing.length > 0
    source: drawing.length > 0
            ? "qrc:/assets/exercises/" + (Theme.dark ? "dark" : "light") + "/" + drawing + ".png"
            : ""
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    smooth: true
    mipmap: true
}
