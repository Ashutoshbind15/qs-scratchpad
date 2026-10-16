import QtQuick

// Brief message pinned to the bottom of the window. Has no mouse handling,
// so clicks pass through to whatever is underneath.
Rectangle {
    id: toast
    required property var colors
    property string text: ""
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 12
    width: Math.min(parent.width - 24, label.implicitWidth + 20)
    height: label.implicitHeight + 10
    color: colors.surface
    border.color: colors.accent
    border.width: 1
    radius: 0

    Text {
        id: label
        anchors.fill: parent
        anchors.margins: 5
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        text: toast.text
        color: toast.colors.foreground
        font.pixelSize: toast.colors.px(12)
        elide: Text.ElideMiddle
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
