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
    property bool clearArmed: false
    property int titleFocusGeneration: 0

    // Only the first line is scanned, so long notes stay cheap per keystroke.
    function noteTitle(text) {
        const end = text.indexOf("\n");
        return (end < 0 ? text : text.slice(0, end)).trim() || "Untitled";
    }

    function isBlank(text) {
        return text.trim().length === 0;
    }

    function commitActive() {
        if (activeIndex < 0 || activeIndex >= pads.count) return;
        const text = editor.text;
        pads.setProperty(activeIndex, "text", text);
        pads.setProperty(activeIndex, "name", noteTitle(text));
    }

    // Swap the editor without touching the sidebar model, so opening a note
    // does not rebuild the rows. selectTitle highlights the first line so a
    // new note's name can be replaced immediately.
    function showEditor(index, selectTitle) {
        const generation = ++titleFocusGeneration;
        switching = true;
        activeIndex = index;
        editor.text = index >= 0 ? pads.get(index).text : "";
        switching = false;
        save();
        if (index < 0)
            return;
        if (selectTitle)
            focusTitle(generation);
        else
            editor.forceActiveFocus();
    }

    // Selecting in the same turn as a text assignment gets cleared when the
    // editor takes focus, so the highlight is applied again once that settles.
    function focusTitle(generation) {
        const end = titleEnd(editor.text);
        editor.select(0, end);
        editor.forceActiveFocus();
        Qt.callLater(function() {
            if (generation !== titleFocusGeneration)
                return;
            if (titleEnd(editor.text) !== end)
                return;
            if (editor.selectionStart !== 0 || editor.selectionEnd !== end)
                editor.select(0, end);
            editor.forceActiveFocus();
        });
    }

    function titleEnd(text) {
        const newline = text.indexOf("\n");
        return newline < 0 ? text.length : newline;
    }

    function save() {
        if (!ready || switching) return;
        debounce.stop();
        if (activeIndex >= 0 && activeIndex < pads.count) {
            const text = editor.text;
            pads.setProperty(activeIndex, "text", text);
            pads.setProperty(activeIndex, "name", noteTitle(text));
        }
        const data = [];
        let storedActive = 0;
        for (let i = 0; i < pads.count; i++) {
            const pad = pads.get(i);
            if (isBlank(pad.text)) continue;
            if (i === activeIndex) storedActive = data.length;
            data.push({ name: pad.name, text: pad.text, pinned: !!pad.pinned });
        }
        notes.setText(JSON.stringify({
            version: 1,
            activeIndex: data.length ? storedActive : 0,
            pads: data
        }, null, 2));
    }

    function selectPad(index) {
        if (!ready || index < 0 || index >= pads.count) return -1;
        if (index === activeIndex) return index;
        clearArmed = false;
        if (activeIndex >= 0 && isBlank(editor.text)) {
            const removed = activeIndex;
            pads.remove(removed);
            if (index > removed) index--;
        } else if (activeIndex >= 0) {
            commitActive();
        }
        if (index < 0 || index >= pads.count) {
            showEditor(-1);
            return -1;
        }
        showEditor(index);
        return index;
    }

    // Lowest unused untitled-N among the notes already in the sidebar.
    function nextUntitled() {
        const used = [];
        for (let i = 0; i < pads.count; i++) {
            const name = i === activeIndex ? noteTitle(editor.text) : pads.get(i).name;
            const match = /^untitled-(\d+)$/.exec(name);
            if (match) used[Number(match[1])] = true;
        }
        let n = 1;
        while (used[n]) n++;
        return "untitled-" + n;
    }

    function newPad() {
        if (!ready || switching) return;
        clearArmed = false;
        if (activeIndex >= 0 && activeIndex < pads.count && isBlank(editor.text)) {
            pads.remove(activeIndex);
            activeIndex = -1;
        } else if (activeIndex >= 0) {
            commitActive();
        }
        const title = nextUntitled();
        const text = title + "\n";
        pads.append({ name: title, text: text, pinned: false });
        showEditor(pads.count - 1, true);
    }

    function removePad(index) {
        if (!ready || index < 0 || index >= pads.count) return;
        clearArmed = false;
        const removingActive = index === activeIndex;
        if (!removingActive)
            commitActive();
        pads.remove(index);
        let next = activeIndex;
        if (pads.count === 0) next = -1;
        else if (removingActive) next = Math.min(index, pads.count - 1);
        else if (index < activeIndex) next = activeIndex - 1;
        // Reloading the editor scrolls it back to the top, so a delete of some
        // other note only moves the index.
        if (removingActive)
            showEditor(next);
        else {
            activeIndex = next;
            save();
        }
    }

    // Pinned notes stay in a prefix. Move only the one row; the others stay put.
    function togglePin(index) {
        if (!ready || index < 0 || index >= pads.count) return;
        clearArmed = false;
        commitActive();
        pads.setProperty(index, "pinned", !pads.get(index).pinned);
        let otherPinned = 0;
        for (let i = 0; i < pads.count; i++) {
            if (i !== index && pads.get(i).pinned) otherPinned++;
        }
        if (otherPinned === index) {
            save();
            return;
        }
        const pad = pads.get(index);
        const entry = { name: pad.name, text: pad.text, pinned: !!pad.pinned };
        pads.remove(index);
        let active = activeIndex === index ? -1 : activeIndex;
        if (active > index) active--;
        pads.insert(otherPinned, entry);
        if (active < 0) active = otherPinned;
        else if (active >= otherPinned) active++;
        activeIndex = active;
        save();
    }

    // A cleared note is discarded once you leave it, so blanks don't pile up.
    function pruneActiveIfBlank() {
        if (!ready || activeIndex < 0 || activeIndex >= pads.count) return;
        if (!isBlank(editor.text)) return;
        removePad(activeIndex);
    }

    function openPadMenu(index) {
        const resolved = index === activeIndex ? index : selectPad(index);
        if (resolved < 0 || resolved >= pads.count) return;
        padMenu.target = resolved;
        padMenu.pinText = pads.get(resolved).pinned ? "Unpin" : "Pin";
        padMenu.popup();
    }

    function armClear() {
        if (!clearArmed) {
            clearArmed = true;
            clearArm.restart();
            return;
        }
        clearAll();
    }

    function clearAll() {
        clearArmed = false;
        switching = true;
        pads.clear();
        activeIndex = -1;
        editor.text = "";
        switching = false;
        save();
    }

    function hideScratchpad() {
        pruneActiveIfBlank();
        save();
        Hyprland.dispatch("quickshell_scratchpad_toggle");
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
                if (data.version !== 1 || !Array.isArray(data.pads))
                    throw new Error("Invalid scratchpad data");
                const pinned = [];
                const rest = [];
                const activeSource = Number.isInteger(data.activeIndex) ? data.activeIndex : -1;
                for (let i = 0; i < data.pads.length; i++) {
                    const p = data.pads[i];
                    if (typeof p.name !== "string" || typeof p.text !== "string"
                            || (p.pinned !== undefined && typeof p.pinned !== "boolean"))
                        throw new Error("Invalid scratchpad data");
                    if (root.isBlank(p.text)) continue;
                    const pad = {
                        name: root.noteTitle(p.text),
                        text: p.text,
                        pinned: p.pinned === true,
                        sourceIndex: i
                    };
                    if (pad.pinned) pinned.push(pad);
                    else rest.push(pad);
                }
                const ordered = pinned.concat(rest);
                pads.clear();
                let active = -1;
                for (let i = 0; i < ordered.length; i++) {
                    const pad = ordered[i];
                    pads.append({ name: pad.name, text: pad.text, pinned: pad.pinned });
                    if (pad.sourceIndex === activeSource) active = i;
                }
                if (active < 0 && pads.count > 0) active = 0;
                root.activeIndex = active;
                editor.text = active >= 0 ? pads.get(active).text : "";
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

    Timer {
        id: clearArm
        interval: 2500
        onTriggered: root.clearArmed = false
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
            if (!visible) {
                root.pruneActiveIfBlank();
                root.save();
            } else editor.forceActiveFocus();
        }

        Shortcut {
            sequence: "Ctrl+N"
            context: Qt.WindowShortcut
            enabled: root.ready
            onActivated: root.newPad()
        }

        Shortcut {
            sequence: "Ctrl+W"
            context: Qt.WindowShortcut
            enabled: root.ready && root.activeIndex >= 0
            onActivated: root.removePad(root.activeIndex)
        }

        Shortcut {
            sequence: "Ctrl+B"
            context: Qt.WindowShortcut
            onActivated: {
                root.sidebarVisible = !root.sidebarVisible;
                editor.forceActiveFocus();
            }
        }

        Shortcut {
            sequence: "Escape"
            context: Qt.WindowShortcut
            enabled: !padMenu.opened
            onActivated: root.hideScratchpad()
        }

        Menu {
            id: padMenu
            property int target: -1
            property string pinText: "Pin"
            modal: false
            dim: false
            width: 132
            padding: 4
            background: Rectangle {
                color: "#202631"
                radius: 6
                border.color: "#3a4458"
                border.width: 1
            }

            MenuItem {
                id: pinAction
                text: padMenu.pinText
                implicitHeight: 28
                onTriggered: root.togglePin(padMenu.target)
                contentItem: Text {
                    text: pinAction.text
                    color: "#eef0f6"
                    font.pixelSize: 12
                    leftPadding: 8
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: pinAction.highlighted ? "#445b85" : "transparent"
                    radius: 4
                }
            }
            MenuItem {
                id: deleteAction
                text: "Delete"
                implicitHeight: 28
                onTriggered: root.removePad(padMenu.target)
                contentItem: Text {
                    text: deleteAction.text
                    color: "#eef0f6"
                    font.pixelSize: 12
                    leftPadding: 8
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: deleteAction.highlighted ? "#445b85" : "transparent"
                    radius: 4
                }
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
                    Layout.preferredWidth: 120
                    Layout.fillHeight: true
                    color: "#202631"
                    radius: 8
                    // Anchored, not laid out, so the row geometry is final on the
                    // first frame and does not settle after the window maps.
                    ListView {
                        id: padList
                        anchors.fill: parent
                        anchors.margins: 5
                        anchors.bottomMargin: 34
                        clip: true
                        spacing: 4
                        model: pads
                        reuseItems: true
                        delegate: ItemDelegate {
                            id: padRow
                            required property string name
                            required property int index
                            required property bool pinned
                            width: ListView.view.width
                            height: 28
                            padding: 0
                            highlighted: index === root.activeIndex
                            contentItem: Item {
                                Rectangle {
                                    x: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 6
                                    height: 6
                                    radius: 3
                                    visible: padRow.pinned
                                    color: "#9eb6e0"
                                }
                                Text {
                                    x: 14
                                    width: parent.width - 16
                                    height: parent.height
                                    text: padRow.name
                                    color: "#eef0f6"
                                    elide: Text.ElideRight
                                    font.pixelSize: 12
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            background: Rectangle {
                                color: padRow.index === root.activeIndex ? "#445b85"
                                        : padRow.hovered ? "#2a3344" : "transparent"
                                radius: 5
                            }
                            onClicked: root.selectPad(padRow.index)
                            ToolTip.visible: hovered
                            ToolTip.text: name

                            // Right-click only, so a left-button drag can still scroll the list.
                            TapHandler {
                                acceptedButtons: Qt.RightButton
                                onTapped: root.openPadMenu(padRow.index)
                            }
                        }
                        ScrollBar.vertical: ScrollBar {}
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 5
                        height: 26
                        radius: 5
                        visible: pads.count > 0
                        color: root.clearArmed ? "#6e3b3b" : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: root.clearArmed ? "Sure?" : "Clear all"
                            color: root.clearArmed ? "#f0d0d0" : "#929baa"
                            font.pixelSize: 12
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.armClear()
                            ToolTip.visible: containsMouse
                            ToolTip.text: "Remove every note"
                            hoverEnabled: true
                        }
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
                            enabled: root.ready && root.activeIndex >= 0
                            focus: true
                            color: "#eef0f6"
                            selectionColor: "#445b85"
                            placeholderTextColor: "#929baa"
                            placeholderText: root.activeIndex < 0
                                    ? "Ctrl+N for a new note"
                                    : "Paste thread output or write a note…"
                            textFormat: TextEdit.PlainText
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            font.pixelSize: 15
                            background: Rectangle { color: "#202631"; radius: 8 }
                            onTextChanged: {
                                if (root.ready && !root.switching && root.activeIndex >= 0) {
                                    const title = root.noteTitle(text);
                                    if (pads.get(root.activeIndex).name !== title)
                                        pads.setProperty(root.activeIndex, "name", title);
                                    debounce.restart();
                                }
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
