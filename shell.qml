import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property bool ready: false
    property string status: "Loading…"

    property var pads: []
    property int activeIndex: 0
    property bool switching: false
    property bool sidebarVisible: true

    function save() {
        if (!ready || switching) return;
        debounce.stop();
        pads[activeIndex].text = editor.text;
        pads[activeIndex].name = titleField.text.trim() || "Untitled";
        pads = pads.slice();
        notes.setText(JSON.stringify({ version: 1, activeIndex: activeIndex, pads: pads }, null, 2));
    }

    function selectPad(index) {
        save();
        switching = true;
        activeIndex = index;
        editor.text = pads[index].text;
        titleField.text = pads[index].name;
        switching = false;
        save();
        editor.forceActiveFocus();
    }

    function newPad() {
        if (!ready) return;
        save();
        pads = pads.concat([{ name: "Scratchpad " + (pads.length + 1), text: "" }]);
        selectPad(pads.length - 1);
        titleField.forceActiveFocus();
        titleField.selectAll();
    }

    FileView {
        id: notes
        path: Quickshell.env("SCRATCHPAD_FILE")
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (data.version !== 1 || !Array.isArray(data.pads) || !data.pads.length
                    || data.pads.some(p => typeof p.name !== "string" || typeof p.text !== "string"))
                    throw new Error("Invalid scratchpad data");
                root.pads = data.pads;
                root.activeIndex = Number.isInteger(data.activeIndex)
                    && data.activeIndex >= 0 && data.activeIndex < data.pads.length ? data.activeIndex : 0;
                editor.text = root.pads[root.activeIndex].text;
                titleField.text = root.pads[root.activeIndex].name;
                root.ready = true;
                root.status = "Saved locally";
            } catch (error) {
                root.status = "Unable to load notes — " + error.message;
            }
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
        function reveal(): void {
            window.visible = true;
            editor.forceActiveFocus();
        }
        function conceal(): void {
            root.save();
            window.visible = false;
        }
    }

    FloatingWindow {
        id: window
        visible: false
        title: "Scratchpad"
        color: "#181c24"
        implicitWidth: 384
        implicitHeight: 720
        onVisibleChanged: {
            if (!visible) root.save();
            else editor.forceActiveFocus();
        }

        Shortcut {
            sequence: "Ctrl+N"
            context: Qt.WindowShortcut
            enabled: root.ready
            onActivated: root.newPad()
        }

        Shortcut {
            sequence: "Ctrl+B"
            context: Qt.WindowShortcut
            onActivated: {
                root.sidebarVisible = !root.sidebarVisible;
                editor.forceActiveFocus();
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "Scratchpads"
                    color: "#eef0f6"
                    font.pixelSize: 19
                    font.bold: true
                    Layout.fillWidth: true
                }
                ToolButton {
                    text: "+ New"
                    enabled: root.ready
                    onClicked: root.newPad()
                }
                ToolButton {
                    text: "×"
                    onClicked: { root.save(); window.visible = false; }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10
                Rectangle {
                    visible: root.sidebarVisible
                    Layout.preferredWidth: 105
                    Layout.fillHeight: true
                    color: "#202631"
                    radius: 8
                    ListView {
                        anchors.fill: parent
                        anchors.margins: 5
                        clip: true
                        spacing: 4
                        model: root.pads
                        delegate: ItemDelegate {
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            highlighted: index === root.activeIndex
                            contentItem: Text {
                                text: modelData.name
                                color: "#eef0f6"
                                elide: Text.ElideRight
                                font.pixelSize: 12
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: index === root.activeIndex ? "#445b85" : "transparent"
                                radius: 5
                            }
                            onClicked: root.selectPad(index)
                            ToolTip.visible: hovered
                            ToolTip.text: modelData.name
                        }
                        ScrollBar.vertical: ScrollBar {}
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    TextField {
                        id: titleField
                        Layout.fillWidth: true
                        enabled: root.ready
                        color: "#eef0f6"
                        placeholderText: "Scratchpad name"
                        background: Rectangle { color: "#202631"; radius: 6 }
                        onTextEdited: {
                            root.status = "Saving…";
                            debounce.restart();
                        }
                        Keys.onEscapePressed: { root.save(); window.visible = false; }
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
                                if (root.ready && !root.switching) {
                                    root.status = "Saving…";
                                    debounce.restart();
                                }
                            }
                            Keys.onEscapePressed: { root.save(); window.visible = false; }
                        }
                    }
                }
            }
            Label {
                text: root.status + "  ·  Super+N toggles  ·  Ctrl+B sidebar  ·  Ctrl+N new"
                color: "#929baa"
                font.pixelSize: 11
            }
        }
    }
}
