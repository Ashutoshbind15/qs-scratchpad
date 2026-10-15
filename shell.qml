import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root
    property bool ready: false
    property string errorMessage: ""

    property int activeIndex: 0
    property bool switching: false
    property bool sidebarVisible: true

    // Only the first line is scanned, so long notes stay cheap per keystroke.
    function noteTitle(text) {
        const end = text.indexOf("\n");
        return (end < 0 ? text : text.slice(0, end)).trim() || "Untitled";
    }

    function save() {
        if (!ready || switching) return;
        debounce.stop();
        pads.setProperty(activeIndex, "text", editor.text);
        const data = [];
        for (let i = 0; i < pads.count; i++) {
            const pad = pads.get(i);
            data.push({ name: pad.name, text: pad.text });
        }
        notes.setText(JSON.stringify({ version: 1, activeIndex: activeIndex, pads: data }, null, 2));
    }

    function selectPad(index) {
        pads.setProperty(activeIndex, "text", editor.text);
        switching = true;
        activeIndex = index;
        editor.text = pads.get(index).text;
        switching = false;
        save();
        editor.forceActiveFocus();
    }

    function newPad() {
        if (!ready) return;
        pads.append({ name: "Untitled", text: "" });
        selectPad(pads.count - 1);
    }

    // The sidebar model. Titles are updated in place so typing never rebuilds
    // the list's delegates.
    ListModel { id: pads }

    FileView {
        id: notes
        path: Quickshell.env("SCRATCHPAD_FILE")
        blockLoading: true
        atomicWrites: true
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (data.version !== 1 || !Array.isArray(data.pads) || !data.pads.length
                    || data.pads.some(p => typeof p.name !== "string" || typeof p.text !== "string"))
                    throw new Error("Invalid scratchpad data");
                pads.clear();
                for (const p of data.pads) pads.append({ name: root.noteTitle(p.text), text: p.text });
                root.activeIndex = Number.isInteger(data.activeIndex)
                    && data.activeIndex >= 0 && data.activeIndex < data.pads.length ? data.activeIndex : 0;
                editor.text = pads.get(root.activeIndex).text;
                root.ready = true;
                root.errorMessage = "";
            } catch (error) {
                root.errorMessage = "Unable to load notes — " + error.message;
            }
        }
        onLoadFailed: { root.errorMessage = "Unable to load notes"; }
        onSaved: root.errorMessage = ""
        onSaveFailed: root.errorMessage = "Save failed — keep this window open"
    }

    Timer {
        id: debounce
        interval: 300
        onTriggered: root.save()
    }

    // Used by `toggle start` to re-create the window if it was closed.
    IpcHandler {
        target: "scratchpad"
        function reveal(): void {
            window.visible = true;
            editor.forceActiveFocus();
        }
    }

    // Stays mapped for the instance's lifetime; Hyprland hides it by parking
    // it on a special workspace (see omarchy.lua).
    FloatingWindow {
        id: window
        visible: true
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
                        model: pads
                        delegate: ItemDelegate {
                            required property string name
                            required property int index
                            width: ListView.view.width
                            highlighted: index === root.activeIndex
                            contentItem: Text {
                                text: name
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
                            ToolTip.text: name
                        }
                        ScrollBar.vertical: ScrollBar {}
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
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
                                    const title = root.noteTitle(text);
                                    if (pads.get(root.activeIndex).name !== title)
                                        pads.setProperty(root.activeIndex, "name", title);
                                    debounce.restart();
                                }
                            }
                            Keys.onEscapePressed: {
                                root.save();
                                Hyprland.dispatch("quickshell_scratchpad_toggle");
                            }
                        }
                    }
                }
            }
            Label {
                visible: root.errorMessage.length > 0
                text: root.errorMessage
                color: "#929baa"
                font.pixelSize: 11
            }
        }
    }
}
