import QtQuick
import QtQuick.Controls

ToolTip {
    id: tip
    required property var colors
    delay: 500
    timeout: 4000
    leftPadding: 7
    rightPadding: 7
    topPadding: 4
    bottomPadding: 4
    margins: 4
    implicitWidth: Math.min(tip.colors.px(240), contentItem.implicitWidth + leftPadding + rightPadding)
    enter: null
    exit: null

    contentItem: Text {
        text: tip.text
        color: tip.colors.foreground
        font.pixelSize: tip.colors.px(12)
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }
    background: Rectangle {
        color: tip.colors.background
        border.color: tip.colors.border
        border.width: 1
        radius: 0
    }
}
