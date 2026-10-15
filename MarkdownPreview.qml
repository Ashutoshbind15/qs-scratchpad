import QtQuick
import QtQuick.Controls
import Quickshell
import "MarkdownBlocks.js" as MarkdownBlocks

ScrollView {
    id: view
    property string markdown: ""
    readonly property var blocks: MarkdownBlocks.parse(markdown)
    clip: true
    contentWidth: availableWidth
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    onMarkdownChanged: contentItem.contentY = 0
    background: Rectangle { color: "#202631"; radius: 8 }

    Column {
        width: view.availableWidth
        padding: 12
        spacing: 12
        Repeater {
            model: view.blocks
            delegate: Column {
                id: block
                required property var modelData
                width: parent.width - 24
                TextArea {
                    visible: !block.modelData.code
                    width: parent.width
                    height: visible ? implicitHeight : 0
                    text: block.modelData.code ? "" : block.modelData.text
                    textFormat: TextEdit.MarkdownText
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    color: "#eef0f6"
                    selectionColor: "#445b85"
                    font.pixelSize: 15
                    padding: 0
                    background: null
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }
                Rectangle {
                    visible: block.modelData.code
                    width: parent.width
                    height: visible ? codeColumn.implicitHeight + 2 : 0
                    color: "#141922"
                    radius: 6
                    border.color: "#343d4d"
                    Column {
                        id: codeColumn
                        x: 1
                        y: 1
                        width: parent.width - 2
                        Item {
                            width: parent.width
                            height: 32
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: block.modelData.language
                                color: "#9aa9be"
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                width: Math.max(0, parent.width - copyButton.width - 24)
                            }
                            Button {
                                id: copyButton
                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: copied.running ? "Copied" : "Copy"
                                flat: true
                                implicitHeight: 26
                                onClicked: {
                                    Quickshell.clipboardText = block.modelData.text;
                                    copied.restart();
                                }
                                Timer { id: copied; interval: 1500 }
                                contentItem: Text {
                                    text: copyButton.text
                                    color: copyButton.hovered ? "#eef0f6" : "#9aa9be"
                                    font.pixelSize: 11
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle {
                                    color: copyButton.hovered ? "#2a3344" : "transparent"
                                    radius: 4
                                }
                            }
                        }
                        Rectangle { width: parent.width; height: 1; color: "#343d4d" }
                        ScrollView {
                            id: codeScroll
                            width: parent.width
                            height: codeText.implicitHeight + (codeText.implicitWidth > availableWidth ? 12 : 0)
                            clip: true
                            contentWidth: Math.max(availableWidth, codeText.implicitWidth)
                            ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                            ScrollBar.horizontal.policy: codeText.implicitWidth > availableWidth
                                                        ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                            TextArea {
                                id: codeText
                                objectName: "codeText"
                                text: block.modelData.code ? block.modelData.text : ""
                                textFormat: TextEdit.PlainText
                                readOnly: true
                                selectByMouse: true
                                wrapMode: TextEdit.NoWrap
                                font.family: "monospace"
                                font.pixelSize: 13
                                color: "#d5dfee"
                                selectionColor: "#445b85"
                                padding: 10
                                background: null
                            }
                        }
                    }
                }
            }
        }
    }
}
