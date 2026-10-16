import QtQuick
import QtQuick.Controls

// Single-line field with an underline that turns accent-colored on focus.
TextField {
    id: field
    required property var colors
    color: colors.foreground
    selectionColor: colors.textSelection
    selectedTextColor: colors.selectedText
    placeholderTextColor: colors.muted
    font.pixelSize: colors.px(13)
    padding: 4
    background: Rectangle {
        color: field.colors.surface
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: field.activeFocus ? field.colors.accent : field.colors.border
        }
    }
}
