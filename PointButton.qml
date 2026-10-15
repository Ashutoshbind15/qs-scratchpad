import QtQuick
import QtQuick.Controls

Button {
    id: control
    required property var colors
    property string tooltip: ""
    implicitHeight: 24
    implicitWidth: Math.max(22, implicitContentWidth + 12)
    padding: 3
    opacity: enabled ? 1 : 0.4
    ScratchpadToolTip {
        colors: control.colors
        text: control.tooltip
        visible: control.hovered && !control.down && control.tooltip.length > 0
    }
    contentItem: Text {
        text: control.text
        color: control.colors.foreground
        font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        color: control.down ? control.colors.selection : control.hovered ? control.colors.hover : control.colors.surface
        border.width: 1
        border.color: control.hovered ? control.colors.accent : control.colors.border
        radius: 0
    }
}
