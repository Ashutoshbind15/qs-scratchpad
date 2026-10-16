import QtQuick
import QtQuick.Controls
import Quickshell
import "MarkdownBlocks.js" as MarkdownBlocks
import "SyntaxHighlight.js" as SyntaxHighlight

ScrollView {
    id: view
    required property var colors
    property string markdown: ""
    readonly property var blocks: MarkdownBlocks.parse(markdown)
    clip: true
    contentWidth: availableWidth
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    onMarkdownChanged: contentItem.contentY = 0
    background: Rectangle { color: view.colors.surface; radius: 0 }

    Column {
        width: view.availableWidth
        padding: 4
        spacing: 6
        Repeater {
            model: view.blocks
            delegate: Column {
                id: block
                required property var modelData
                width: parent.width - 8
                TextArea {
                    visible: !block.modelData.code
                    width: parent.width
                    height: visible ? implicitHeight : 0
                    text: block.modelData.code ? "" : block.modelData.text
                    textFormat: TextEdit.MarkdownText
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    color: view.colors.foreground
                    selectionColor: view.colors.textSelection
                    selectedTextColor: view.colors.selectedText
                    font.pixelSize: view.colors.px(15)
                    padding: 0
                    background: null
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }
                Rectangle {
                    visible: block.modelData.code
                    width: parent.width
                    height: visible ? codeColumn.implicitHeight + 2 : 0
                    color: view.colors.codeBackground
                    radius: 0
                    border.color: view.colors.border
                    Column {
                        id: codeColumn
                        x: 1
                        y: 1
                        width: parent.width - 2
                        Item {
                            width: parent.width
                            height: view.colors.px(26)
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                text: block.modelData.language
                                color: view.colors.muted
                                font.pixelSize: view.colors.px(11)
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
                                implicitHeight: view.colors.px(26)
                                onClicked: {
                                    Quickshell.clipboardText = block.modelData.text;
                                    copied.restart();
                                }
                                Timer { id: copied; interval: 1500 }
                                contentItem: Text {
                                    text: copyButton.text
                                    color: copyButton.hovered ? view.colors.foreground : view.colors.muted
                                    font.pixelSize: view.colors.px(11)
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle {
                                    color: copyButton.hovered ? view.colors.hover : "transparent"
                                    radius: 0
                                }
                            }
                        }
                        Rectangle { width: parent.width; height: 1; color: view.colors.border }
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
                                text: block.modelData.code
                                      ? SyntaxHighlight.highlight(block.modelData.text, block.modelData.language, view.colors.syntax) : ""
                                textFormat: TextEdit.RichText
                                readOnly: true
                                selectByMouse: true
                                wrapMode: TextEdit.NoWrap
                                font.family: "monospace"
                                font.pixelSize: view.colors.px(13)
                                color: view.colors.foreground
                                selectionColor: view.colors.textSelection
                                selectedTextColor: view.colors.selectedText
                                padding: 6
                                background: null
                            }
                        }
                    }
                }
            }
        }
    }
}
