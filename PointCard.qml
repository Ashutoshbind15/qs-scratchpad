import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: card
    required property var colors
    required property int number
    required property int pointCount
    property string source: ""
    property bool editing: false
    readonly property bool rendering: !editing && source.trim().length > 0
    property bool showControls: true
    property alias editor: input
    function focusContent() {
        editing = true;
        input.forceActiveFocus();
    }
    signal edited(string text)
    signal focused()
    signal caretMoved()
    signal removeRequested()
    signal moveRequested(int offset)
    implicitHeight: contents.implicitHeight + 8
    color: colors.surface
    radius: 0
    border.color: input.activeFocus ? colors.accent : colors.border

    ColumnLayout {
        id: contents
        x: 4
        y: 4
        width: parent.width - 8
        spacing: 3
        RowLayout {
            Layout.fillWidth: true
            visible: card.showControls
            spacing: 2
            Item { Layout.fillWidth: true }
            PointButton {
                text: "↑"
                colors: card.colors
                enabled: card.number > 1
                onClicked: card.moveRequested(-1)
                tooltip: "Move point up"
            }
            PointButton {
                text: "↓"
                colors: card.colors
                enabled: card.number < card.pointCount
                onClicked: card.moveRequested(1)
                tooltip: "Move point down"
            }
            PointButton {
                text: "×"
                colors: card.colors
                onClicked: card.removeRequested()
                tooltip: card.pointCount === 1 ? "Clear point" : "Remove point"
            }
        }
        TextArea {
            id: input
            Layout.fillWidth: true
            Layout.minimumHeight: card.colors.px(64)
            visible: !card.rendering
            text: card.source
            color: card.colors.foreground
            selectionColor: card.colors.textSelection
            selectedTextColor: card.colors.selectedText
            placeholderTextColor: card.colors.muted
            placeholderText: "…"
            textFormat: TextEdit.PlainText
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            font.pixelSize: card.colors.px(15)
            padding: 2
            background: null
            onTextChanged: if (text !== card.source) card.edited(text)
            onActiveFocusChanged: {
                card.editing = activeFocus;
                if (activeFocus) card.focused();
            }
            onCursorRectangleChanged: if (activeFocus) card.caretMoved()

        }
        // Keep the source editor alive across focus changes: rendering must
        // never replace its document, cursor, selection or undo history.
        Loader {
            id: rendered
            objectName: "markdownLoader"
            Layout.fillWidth: true
            Layout.preferredHeight: item ? Math.max(card.colors.px(64), item.contentHeight) : 0
            active: card.rendering || item !== null
            visible: card.rendering
            sourceComponent: Component {
                MarkdownPreview {
                    colors: card.colors
                    markdown: card.rendering ? card.source : ""
                    onEditRequested: card.focusContent()
                }
            }
        }
    }
}
