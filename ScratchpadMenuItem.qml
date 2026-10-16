import QtQuick
import QtQuick.Controls

MenuItem {
    id: item
    required property var colors
    implicitHeight: colors.px(28)
    contentItem: Text {
        text: item.text
        color: item.colors.foreground
        font.pixelSize: item.colors.px(12)
        leftPadding: 6
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        color: item.highlighted ? item.colors.selection : "transparent"
        radius: 0
    }
}
