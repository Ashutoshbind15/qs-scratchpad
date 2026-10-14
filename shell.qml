import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property bool ready: false
    property string status: "Loading…"

    function save() {
        if (!ready) return;
        debounce.stop();
        notes.setText(editor.text);
    }

    FileView {
        id: notes
        path: Quickshell.env("SCRATCHPAD_FILE")
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        onLoaded: {
            editor.text = text();
            root.ready = true;
            root.status = "Saved locally";
        }
        onLoadFailed: { root.status = "Unable to load notes"; }
        onSaved: root.status = "Saved locally"
        onSaveFailed: root.status = "Save failed — keep this window open"
    }

    Timer {
        id: debounce
        interval: 300
        onTriggered: root.save()
    }

    IpcHandler {
        target: "scratchpad"
        function toggle(): void {
            root.save();
            window.visible = !window.visible;
            if (window.visible) editor.forceActiveFocus();
        }
    }

    FloatingWindow {
        id: window
        title: "Scratchpad"
        color: "#181c24"
        implicitWidth: 384
        implicitHeight: 720
        onVisibleChanged: {
            if (!visible) root.save();
            else editor.forceActiveFocus();
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "Scratchpad"
                    color: "#eef0f6"
                    font.pixelSize: 19
                    font.bold: true
                    Layout.fillWidth: true
                }
                ToolButton {
                    text: "×"
                    onClicked: { root.save(); window.visible = false; }
                }
            }
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                TextArea {
                    id: editor
                    enabled: root.ready
                    focus: true
                    color: "#eef0f6"
                    selectionColor: "#445b85"
                    placeholderTextColor: "#929baa"
                    placeholderText: "Paste thread output or write a note…"
                    textFormat: TextEdit.PlainText
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    font.pixelSize: 15
                    background: Rectangle { color: "#202631"; radius: 8 }
                    onTextChanged: {
                        if (root.ready) {
                            root.status = "Saving…";
                            debounce.restart();
                        }
                    }
                    Keys.onEscapePressed: { root.save(); window.visible = false; }
                }
            }
            Label {
                text: root.status + "  ·  Super+N toggles"
                color: "#929baa"
                font.pixelSize: 11
            }
        }
    }
}
