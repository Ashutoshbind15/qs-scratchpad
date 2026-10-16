import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Keybinds.js" as Keybinds

// Searchable list of shortcuts, styled after Omarchy's keybindings menu: type
// to filter, Up/Down to pick, Enter to run, Escape clears the search and then
// closes. Modal, so the window's own shortcuts stay inactive while it's open.
Popup {
    id: help
    required property var colors
    readonly property var rows: Keybinds.filter(search.text)
    property alias searchField: search
    property alias currentIndex: list.currentIndex

    // Emitted after closing, for every entry except the help shortcut itself.
    signal actionRequested(string action)

    x: 4
    y: 4
    width: parent ? parent.width - 8 : 0
    height: parent ? parent.height - 8 : 0
    modal: true
    dim: false
    padding: 4
    closePolicy: Popup.NoAutoClose
    onRowsChanged: list.currentIndex = Keybinds.bestIndex(rows)
    onOpened: {
        search.text = "";
        list.currentIndex = Keybinds.bestIndex(rows);
        search.forceActiveFocus();
    }

    function run(index) {
        if (index < 0 || index >= rows.length) return;
        const action = rows[index].action;
        close();
        if (action !== "help") actionRequested(action);
    }

    function move(offset) {
        if (!rows.length) return;
        list.currentIndex = Math.max(0, Math.min(rows.length - 1, list.currentIndex + offset));
    }

    background: Rectangle {
        color: help.colors.background
        border.color: help.colors.border
        border.width: 1
        radius: 0
    }

    contentItem: ColumnLayout {
        spacing: 4
        ScratchpadTextField {
            id: search
            Layout.fillWidth: true
            colors: help.colors
            placeholderText: "Search shortcuts…"
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    if (text) text = "";
                    else help.close();
                } else if (event.key === Qt.Key_F1) help.close();
                else if (event.key === Qt.Key_Up) help.move(-1);
                else if (event.key === Qt.Key_Down) help.move(1);
                else if (event.key === Qt.Key_PageUp) help.move(-6);
                else if (event.key === Qt.Key_PageDown) help.move(6);
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) help.run(list.currentIndex);
                else return;
                event.accepted = true;
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: help.rows
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
            section.property: "section"
            section.delegate: Text {
                required property string section
                width: ListView.view.width
                topPadding: 6
                bottomPadding: 2
                leftPadding: 6
                text: section.toUpperCase()
                color: help.colors.accent
                font.pixelSize: help.colors.px(10)
                font.bold: true
                font.letterSpacing: 1
            }
            delegate: ItemDelegate {
                id: row
                required property var modelData
                required property int index
                readonly property bool current: index === list.currentIndex
                width: ListView.view.width
                height: help.colors.px(26)
                padding: 0
                onClicked: help.run(index)
                contentItem: RowLayout {
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        leftPadding: 6
                        text: row.modelData.label
                        color: help.colors.foreground
                        elide: Text.ElideRight
                        font.pixelSize: help.colors.px(12)
                    }
                    Text {
                        rightPadding: 6
                        text: row.modelData.keys
                        color: row.current ? help.colors.foreground : help.colors.muted
                        font.pixelSize: help.colors.px(11)
                        font.family: "monospace"
                    }
                }
                background: Rectangle {
                    color: row.current ? help.colors.selection : row.hovered ? help.colors.hover : "transparent"
                    radius: 0
                }
            }
            ScrollBar.vertical: ScrollBar {}
        }

        Label {
            visible: help.rows.length === 0
            text: "No matching shortcuts"
            color: help.colors.muted
            font.pixelSize: help.colors.px(12)
        }
    }
}
