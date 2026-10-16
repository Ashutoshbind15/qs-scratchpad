import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "ScratchpadPoints.js" as Points
import "Keybinds.js" as Keybinds

Scope {
    id: root
    ScratchpadTheme { id: theme }

    property bool ready: false
    property string errorMessage: ""

    property int activeIndex: 0
    property bool switching: false
    property bool sidebarVisible: true
    property bool previewMode: false
    property bool clearArmed: false
    property bool clearPointsArmed: false
    property var pendingCaptures: []
    property bool activeGlobal: activeIndex >= 0 && pads.count > activeIndex && pads.get(activeIndex).global
    property int titleFocusGeneration: 0

    property string activeTitle: ""
    property int activePoint: 0
    property var editor: pointRepeater.count > activePoint && pointRepeater.itemAt(activePoint) ? pointRepeater.itemAt(activePoint).editor : null

    function pointTexts() {
        const result = [];
        for (let i = 0; i < points.count; i++) result.push(points.get(i).body);
        return result;
    }

    function activeText() { return activeTitle.trim() + "\n" + Points.combined(pointTexts()); }

    function updateTitle(text) {
        if (switching || !ready || activeIndex < 0 || activeGlobal) return;
        activeTitle = text;
        pads.setProperty(activeIndex, "name", text.trim() || "Untitled");
        debounce.restart();
    }

    function focusContent() {
        const card = pointRepeater.itemAt(activePoint);
        if (card) card.focusContent();
        Qt.callLater(ensureCursorVisible);
    }

    function ensureCursorVisible() {
        if (previewMode || !editor) return;
        const flick = pointScroll.contentItem;
        const caret = editor.mapToItem(flick.contentItem, 0, editor.cursorRectangle.y);
        const bottom = caret.y + editor.cursorRectangle.height + 12;
        const top = Math.max(0, caret.y - 12);
        if (top < flick.contentY) flick.contentY = top;
        else if (bottom > flick.contentY + flick.height)
            flick.contentY = Math.max(0, bottom - flick.height);
    }

    function updatePoint(index, text) {
        if (switching || !ready || activeIndex < 0) return;
        points.setProperty(index, "body", text);
        copied.stop();
        debounce.restart();
    }

    function addPoint() {
        if (!ready || activeIndex < 0) return;
        previewMode = false;
        points.append({ body: "" });
        activePoint = points.count - 1;
        save();
        Qt.callLater(focusContent);
    }

    function globalIndex() {
        for (let i = 0; i < pads.count; i++) if (pads.get(i).global) return i;
        return -1;
    }

    function captureGlobal(text = "") {
        if (!ready) { pendingCaptures.push(text); return; }
        selectPad(globalIndex());
        sidebarVisible = true;
        previewMode = false;
        clearPointsArmed = false;
        // Reuse an empty last point so repeated presses do not pile up blanks.
        if (points.count && isBlank(points.get(points.count - 1).body)) {
            activePoint = points.count - 1;
            Qt.callLater(focusContent);
        } else addPoint();
        if (text.length) {
            updatePoint(activePoint, text);
            save();
            Qt.callLater(function() {
                focusContent();
                if (editor) editor.cursorPosition = editor.length;
            });
        }
    }

    function armClearPoints() {
        if (!clearPointsArmed) {
            clearPointsArmed = true;
            clearPointsArm.restart();
            return;
        }
        clearPointsArmed = false;
        previewMode = false;
        points.clear();
        points.append({ body: "" });
        activePoint = 0;
        copied.stop();
        save();
        Qt.callLater(focusContent);
    }

    function removePoint(index) {
        if (points.count === 1) points.setProperty(0, "body", "");
        else points.remove(index);
        activePoint = Math.min(index, points.count - 1);
        copied.stop();
        save();
        Qt.callLater(focusContent);
    }

    function movePoint(index, offset) {
        points.move(index, index + offset, 1);
        activePoint = index + offset;
        copied.stop();
        save();
        Qt.callLater(focusContent);
    }

    function focusPoint(offset) {
        if (!ready || activeIndex < 0) return;
        const next = activePoint + offset;
        if (next < 0 || next >= points.count) return;
        activePoint = next;
        Qt.callLater(focusContent);
    }

    function reorderPoint(offset) {
        if (!ready || activeIndex < 0) return;
        if (activePoint + offset < 0 || activePoint + offset >= points.count) return;
        movePoint(activePoint, offset);
    }

    function deletePoint() {
        if (!ready || activeIndex < 0 || points.count === 0) return;
        removePoint(activePoint);
    }

    function copyForAgents() {
        Quickshell.clipboardText = Points.forAgents(pointTexts());
        copied.restart();
    }

    function togglePreview() {
        if (!ready || activeIndex < 0) return;
        previewMode = !previewMode;
        focusContent();
    }

    function toggleSidebar() {
        sidebarVisible = !sidebarVisible;
        focusContent();
    }

    function openHelp() {
        if (!helpPopup.opened) helpPopup.open();
    }

    // Runs a help-overlay entry; each action keeps its shortcut's guards.
    function runBinding(action) {
        const hasText = !isBlank(Points.combined(pointTexts()));
        switch (action) {
        case "help": openHelp(); break;
        case "newNote": newPad(); break;
        case "deleteNote": if (ready && !activeGlobal) removePad(activeIndex); break;
        case "toggleSidebar": toggleSidebar(); break;
        case "addPoint": addPoint(); break;
        case "previousPoint": focusPoint(-1); break;
        case "nextPoint": focusPoint(1); break;
        case "movePointUp": reorderPoint(-1); break;
        case "movePointDown": reorderPoint(1); break;
        case "deletePoint": deletePoint(); break;
        case "copy": if (ready && activeIndex >= 0 && hasText) copyForAgents(); break;
        case "preview": togglePreview(); break;
        case "hide": hideScratchpad(); break;
        case "capture": captureGlobal(); break;
        }
    }

    function isBlank(text) {
        return text.trim().length === 0;
    }

    function commitActive() {
        if (activeIndex < 0 || activeIndex >= pads.count) return;
        const entries = pointTexts();
        pads.setProperty(activeIndex, "text", Points.combined(entries));
        pads.setProperty(activeIndex, "pointsJson", JSON.stringify(entries));
        pads.setProperty(activeIndex, "name", activeTitle.trim() || "Untitled");
    }

    // Swap the editor without touching the sidebar model, so opening a note
    // does not rebuild the rows. selectTitle highlights the title field so a
    // new note's name can be replaced immediately.
    function showEditor(index, selectTitle) {
        clearPointsArmed = false;
        const generation = ++titleFocusGeneration;
        switching = true;
        activeIndex = index;
        activeTitle = index >= 0 ? pads.get(index).name : "";
        points.clear();
        const entries = index >= 0 ? JSON.parse(pads.get(index).pointsJson) : [];
        for (const body of entries) points.append({ body: body });
        activePoint = 0;
        copied.stop();
        switching = false;
        save();
        if (index < 0)
            return;
        Qt.callLater(function() {
            if (generation !== titleFocusGeneration) return;
            if (selectTitle) focusTitle(generation);
            else focusContent();
        });
    }

    function focusTitle(generation) {
        if (generation !== titleFocusGeneration) return;
        titleInput.forceActiveFocus();
        titleInput.selectAll();
    }

    function save() {
        if (!ready || switching) return;
        debounce.stop();
        commitActive();
        const data = [];
        let storedActive = 0;
        for (let i = 0; i < pads.count; i++) {
            const pad = pads.get(i);
            if (isBlank(pad.text) && isBlank(pad.name)) continue;
            if (i === activeIndex) storedActive = data.length;
            data.push({ name: pad.name, points: JSON.parse(pad.pointsJson), pinned: !!pad.pinned, global: !!pad.global });
        }
        notes.setText(JSON.stringify({
            version: 3,
            activeIndex: data.length ? storedActive : 0,
            pads: data
        }, null, 2));
    }

    function selectPad(index) {
        if (!ready || index < 0 || index >= pads.count) return -1;
        if (index === activeIndex) return index;
        clearArmed = false;
        if (activeIndex >= 0 && isBlank(activeText())) {
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
            const name = i === activeIndex ? activeTitle.trim() : pads.get(i).name;
            const match = /^untitled-(\d+)$/.exec(name);
            if (match) used[Number(match[1])] = true;
        }
        let n = 1;
        while (used[n]) n++;
        return "untitled-" + n;
    }

    function newPad() {
        if (!ready || switching) return;
        previewMode = false;
        clearArmed = false;
        if (activeIndex >= 0 && activeIndex < pads.count && isBlank(activeText())) {
            pads.remove(activeIndex);
            activeIndex = -1;
        } else if (activeIndex >= 0) {
            commitActive();
        }
        const title = nextUntitled();
        pads.append({ name: title, text: "", pointsJson: JSON.stringify([""]), pinned: false, global: false });
        showEditor(pads.count - 1, true);
    }

    function removePad(index) {
        if (!ready || index < 0 || index >= pads.count) return;
        clearArmed = false;
        if (pads.get(index).global) return;
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
        if (pads.get(index).global) return;
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
        const entry = { name: pad.name, text: pad.text, pointsJson: pad.pointsJson, pinned: !!pad.pinned, global: !!pad.global };
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
        if (!isBlank(activeText())) return;
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
        activeTitle = "";
        points.clear();
        copied.stop();
        pads.append({ name: "Global", text: "", pointsJson: JSON.stringify([""]), pinned: true, global: true });
        switching = false;
        showEditor(0);
    }

    function hideScratchpad() {
        pruneActiveIfBlank();
        save();
        Quickshell.execDetached(["hyprctl", "eval", "quickshell_scratchpad_toggle()"]);
    }

    function revealWindow() {
        if (!window.visible || !window.backingWindowVisible) {
            // A compositor close hides the backing window without clearing
            // Quickshell's requested-visible state. Assigning true alone is
            // then a no-op. Reset it before requesting another surface.
            window.visible = false;
            Qt.callLater(function() {
                window.visible = true;
                root.focusContent();
            });
        } else focusContent();
    }

    // The sidebar model. Titles are updated in place so typing never rebuilds
    // the list's delegates.
    ListModel { id: pads }
    ListModel { id: points }
    Timer { id: copied; interval: 1500 }

    FileView {
        id: notes
        path: Quickshell.env("SCRATCHPAD_FILE")
        // Load notes asynchronously so disk I/O cannot block window creation.
        blockLoading: false
        atomicWrites: true
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if ((data.version !== 1 && data.version !== 2 && data.version !== 3) || !Array.isArray(data.pads))
                    throw new Error("Invalid scratchpad data");
                const globals = [];
                const pinned = [];
                const rest = [];
                const activeSource = Number.isInteger(data.activeIndex) ? data.activeIndex : -1;
                for (let i = 0; i < data.pads.length; i++) {
                    const p = data.pads[i];
                    if (typeof p.name !== "string"
                            || (p.pinned !== undefined && typeof p.pinned !== "boolean")
                            || (p.global !== undefined && typeof p.global !== "boolean"))
                        throw new Error("Invalid scratchpad data");
                    const entries = Points.readPoints(p, data.version);
                    const content = Points.combined(entries);
                    if (!p.global && root.isBlank(content) && (data.version < 3 || root.isBlank(p.name))) continue;
                    const pad = {
                        name: p.global ? "Global" : data.version === 3 ? p.name : Points.title(entries),
                        global: p.global === true,
                        text: content,
                        pointsJson: JSON.stringify(entries),
                        pinned: p.global === true || p.pinned === true,
                        sourceIndex: i
                    };
                    if (pad.global) globals.push(pad);
                    else if (pad.pinned) pinned.push(pad);
                    else rest.push(pad);
                }
                if (globals.length > 1) throw new Error("Multiple global containers");
                if (!globals.length) globals.push({ name: "Global", text: "", pointsJson: JSON.stringify([""]), pinned: true, global: true, sourceIndex: -2 });
                const ordered = globals.concat(pinned, rest);
                pads.clear();
                let active = -1;
                for (let i = 0; i < ordered.length; i++) {
                    const pad = ordered[i];
                    pads.append({ name: pad.name, text: pad.text, pointsJson: pad.pointsJson, pinned: pad.pinned, global: pad.global });
                    if (pad.sourceIndex === activeSource) active = i;
                }
                if (active < 0 && pads.count > 0) active = 0;
                root.activeIndex = active;
                root.activeTitle = active >= 0 ? pads.get(active).name : "";
                points.clear();
                if (active >= 0) {
                    for (const body of JSON.parse(pads.get(active).pointsJson))
                        points.append({ body: body });
                }
                root.ready = true;
                root.errorMessage = "";
                if (root.pendingCaptures.length) {
                    const captures = root.pendingCaptures;
                    root.pendingCaptures = [];
                    for (const body of captures) root.captureGlobal(body);
                } else Qt.callLater(root.focusContent);
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

    Timer {
        id: clearPointsArm
        interval: 2500
        onTriggered: root.clearPointsArmed = false
    }

    // Used by `toggle start` to re-create the window if it was closed.
    IpcHandler {
        target: "scratchpad"
        function ping(): void {}
        function capture(text: string): void {
            root.revealWindow();
            root.captureGlobal(text);
        }
        function reveal(): void {
            root.revealWindow();
        }
    }

    // Stays mapped for the instance's lifetime; Hyprland hides it by parking
    // it on a special workspace (see omarchy.lua).
    FloatingWindow {
        id: window
        visible: Quickshell.env("SCRATCHPAD_PREWARM") !== "1"
        title: "Scratchpad"
        color: theme.background
        implicitWidth: 384
        implicitHeight: 720
        onVisibleChanged: {
            if (!visible) {
                root.pruneActiveIfBlank();
                root.save();
            } else root.focusContent();
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
            enabled: root.ready && root.activeIndex >= 0 && !root.activeGlobal
            onActivated: root.removePad(root.activeIndex)
        }

        Shortcut {
            sequence: "Ctrl+B"
            context: Qt.WindowShortcut
            onActivated: root.toggleSidebar()
        }

        Shortcut {
            sequences: ["F1", "Ctrl+/", "Ctrl+?"]
            context: Qt.WindowShortcut
            onActivated: root.openHelp()
        }

        Shortcut {
            sequences: ["Ctrl+Shift+N", "Ctrl+Return", "Ctrl+Enter"]
            context: Qt.WindowShortcut
            enabled: root.ready && root.activeIndex >= 0
            onActivated: root.addPoint()
        }

        Shortcut {
            sequence: "Alt+Up"
            context: Qt.WindowShortcut
            enabled: root.ready && root.activeIndex >= 0 && points.count > 1
            onActivated: root.focusPoint(-1)
        }

        Shortcut {
            sequence: "Alt+Down"
            context: Qt.WindowShortcut
            enabled: root.ready && root.activeIndex >= 0 && points.count > 1
            onActivated: root.focusPoint(1)
        }

        Shortcut {
            sequence: "Alt+Shift+Up"
            context: Qt.WindowShortcut
            enabled: root.ready && root.activeIndex >= 0 && root.activePoint > 0
            onActivated: root.reorderPoint(-1)
        }

        Shortcut {
            sequence: "Alt+Shift+Down"
            context: Qt.WindowShortcut
            enabled: root.ready && root.activeIndex >= 0 && root.activePoint < points.count - 1
            onActivated: root.reorderPoint(1)
        }

        Shortcut {
            sequence: "Ctrl+Shift+W"
            context: Qt.WindowShortcut
            enabled: root.ready && root.activeIndex >= 0
            onActivated: root.deletePoint()
        }

        Shortcut {
            sequence: "Ctrl+Shift+C"
            context: Qt.WindowShortcut
            enabled: root.ready && root.activeIndex >= 0 && !root.isBlank(Points.combined(root.pointTexts()))
            onActivated: root.copyForAgents()
        }

        Shortcut {
            sequence: "Ctrl+Shift+M"
            context: Qt.WindowShortcut
            enabled: root.ready && root.activeIndex >= 0
            onActivated: root.togglePreview()
        }

        Shortcut {
            sequence: "Escape"
            context: Qt.WindowShortcut
            enabled: !padMenu.opened && !helpPopup.opened
            onActivated: root.hideScratchpad()
        }

        // Searchable list of shortcuts, styled after Omarchy's keybindings
        // menu: type to filter, Up/Down to pick, Enter to run, Escape clears
        // the search and then closes. Modal, so window shortcuts stay inactive.
        Popup {
            id: helpPopup
            property var rows: Keybinds.filter(helpSearch.text)
            x: 4
            y: 4
            width: window.width - 8
            height: window.height - 8
            modal: true
            dim: false
            padding: 4
            closePolicy: Popup.NoAutoClose
            onRowsChanged: helpList.currentIndex = Keybinds.bestIndex(rows)
            onOpened: {
                helpSearch.text = "";
                helpList.currentIndex = Keybinds.bestIndex(rows);
                helpSearch.forceActiveFocus();
            }
            onClosed: root.focusContent()

            function run(index) {
                if (index < 0 || index >= rows.length) return;
                const action = rows[index].action;
                close();
                if (action !== "help") Qt.callLater(root.runBinding, action);
            }

            function move(offset) {
                if (!rows.length) return;
                helpList.currentIndex = Math.max(0, Math.min(rows.length - 1, helpList.currentIndex + offset));
            }

            background: Rectangle {
                color: theme.background
                border.color: theme.border
                border.width: 1
                radius: 0
            }

            contentItem: ColumnLayout {
                spacing: 4
                TextField {
                    id: helpSearch
                    Layout.fillWidth: true
                    placeholderText: "Search shortcuts…"
                    color: theme.foreground
                    selectionColor: theme.selection
                    selectedTextColor: theme.foreground
                    placeholderTextColor: theme.muted
                    font.pixelSize: 13
                    padding: 4
                    background: Rectangle {
                        color: theme.surface
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: helpSearch.activeFocus ? theme.accent : theme.border
                        }
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            if (text) text = "";
                            else helpPopup.close();
                        } else if (event.key === Qt.Key_F1) helpPopup.close();
                        else if (event.key === Qt.Key_Up) helpPopup.move(-1);
                        else if (event.key === Qt.Key_Down) helpPopup.move(1);
                        else if (event.key === Qt.Key_PageUp) helpPopup.move(-6);
                        else if (event.key === Qt.Key_PageDown) helpPopup.move(6);
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) helpPopup.run(helpList.currentIndex);
                        else return;
                        event.accepted = true;
                    }
                }
                ListView {
                    id: helpList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: helpPopup.rows
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
                        color: theme.accent
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1
                    }
                    delegate: ItemDelegate {
                        id: helpRow
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: 26
                        padding: 0
                        onClicked: helpPopup.run(index)
                        contentItem: RowLayout {
                            spacing: 8
                            Text {
                                Layout.fillWidth: true
                                leftPadding: 6
                                text: helpRow.modelData.label
                                color: theme.foreground
                                elide: Text.ElideRight
                                font.pixelSize: 12
                            }
                            Text {
                                rightPadding: 6
                                text: helpRow.modelData.keys
                                color: helpRow.index === helpList.currentIndex ? theme.foreground : theme.muted
                                font.pixelSize: 11
                                font.family: "monospace"
                            }
                        }
                        background: Rectangle {
                            color: helpRow.index === helpList.currentIndex ? theme.selection
                                    : helpRow.hovered ? theme.hover : "transparent"
                            radius: 0
                        }
                    }
                    ScrollBar.vertical: ScrollBar {}
                }
                Label {
                    visible: helpPopup.rows.length === 0
                    text: "No matching shortcuts"
                    color: theme.muted
                    font.pixelSize: 12
                }
            }
        }

        Menu {
            id: padMenu
            property int target: -1
            property string pinText: "Pin"
            modal: false
            dim: false
            width: 132
            padding: 2
            background: Rectangle {
                color: theme.surface
                radius: 0
                border.color: theme.border
                border.width: 1
            }

            MenuItem {
                id: pinAction
                enabled: !root.activeGlobal
                text: padMenu.pinText
                implicitHeight: 28
                onTriggered: root.togglePin(padMenu.target)
                contentItem: Text {
                    text: pinAction.text
                    color: theme.foreground
                    font.pixelSize: 12
                    leftPadding: 6
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: pinAction.highlighted ? theme.selection : "transparent"
                    radius: 0
                }
            }
            MenuItem {
                id: deleteAction
                enabled: !root.activeGlobal
                text: "Delete"
                implicitHeight: 28
                onTriggered: root.removePad(padMenu.target)
                contentItem: Text {
                    text: deleteAction.text
                    color: theme.foreground
                    font.pixelSize: 12
                    leftPadding: 6
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: deleteAction.highlighted ? theme.selection : "transparent"
                    radius: 0
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4
                Rectangle {
                    visible: root.sidebarVisible
                    Layout.preferredWidth: 108
                    Layout.fillHeight: true
                    color: theme.surface
                    radius: 0
                    // Anchored, not laid out, so the row geometry is final on the
                    // first frame and does not settle after the window maps.
                    ListView {
                        id: padList
                        anchors.fill: parent
                        anchors.margins: 3
                        anchors.bottomMargin: 28
                        clip: true
                        spacing: 2
                        model: pads
                        reuseItems: true
                        delegate: ItemDelegate {
                            id: padRow
                            required property string name
                            required property int index
                            required property bool pinned
                            width: ListView.view.width
                            height: 26
                            padding: 0
                            highlighted: index === root.activeIndex
                            contentItem: Item {
                                Rectangle {
                                    x: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 6
                                    height: 6
                                    radius: 0
                                    visible: padRow.pinned
                                    color: theme.accent
                                }
                                Text {
                                    x: 14
                                    width: parent.width - 16
                                    height: parent.height
                                    text: padRow.name
                                    color: theme.foreground
                                    elide: Text.ElideRight
                                    font.pixelSize: 12
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            background: Rectangle {
                                color: padRow.index === root.activeIndex ? theme.selection
                                        : padRow.hovered ? theme.hover : "transparent"
                                radius: 0
                            }
                            onClicked: root.selectPad(padRow.index)

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
                        anchors.margins: 3
                        height: 22
                        radius: 0
                        visible: pads.count > 0
                        color: root.clearArmed ? theme.dangerBackground : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: root.clearArmed ? "Sure?" : "Clear all"
                            color: root.clearArmed ? theme.foreground : theme.muted
                            font.pixelSize: 12
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.armClear()
                            ScratchpadToolTip {
                                colors: theme
                                text: "Remove all notes and empty Global"
                                visible: parent.containsMouse && !parent.pressed
                            }
                            hoverEnabled: true
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4
                    TextField {
                        id: titleInput
                        Layout.fillWidth: true
                        visible: root.activeIndex >= 0
                        enabled: root.ready
                        readOnly: root.activeGlobal
                        text: root.activeTitle
                        placeholderText: "Title"
                        color: theme.foreground
                        selectionColor: theme.selection
                        selectedTextColor: theme.foreground
                        placeholderTextColor: theme.muted
                        font.pixelSize: 16
                        font.bold: true
                        padding: 4
                        onTextEdited: root.updateTitle(text)
                        onAccepted: root.focusContent()
                        background: Rectangle {
                            color: theme.surface
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 1
                                color: titleInput.activeFocus ? theme.accent : theme.border
                            }
                        }
                    }
                    ScrollView {
                        id: pointScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: availableWidth
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        Column {
                            width: pointScroll.availableWidth
                            spacing: 4
                            Repeater {
                                id: pointRepeater
                                model: points
                                delegate: PointCard {
                                    required property int index
                                    required property string body
                                    width: parent.width
                                    colors: theme
                                    number: index + 1
                                    pointCount: points.count
                                    source: body
                                    previewMode: root.previewMode
                                    onEdited: text => root.updatePoint(index, text)
                                    onFocused: root.activePoint = index
                                    onCaretMoved: Qt.callLater(root.ensureCursorVisible)
                                    onRemoveRequested: root.removePoint(index)
                                    onMoveRequested: offset => root.movePoint(index, offset)
                                }
                            }
                            PointButton {
                                colors: theme
                                anchors.right: parent.right
                                text: "+"
                                Accessible.name: "Add point"
                                enabled: root.ready && root.activeIndex >= 0
                                onClicked: root.addPoint()
                            }
                            Label {
                                width: parent.width
                                visible: root.activeIndex < 0
                                text: "Ctrl+N for a new scratchpad"
                                color: theme.muted
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        PointButton {
                            colors: theme
                            text: root.clearPointsArmed ? "Sure?" : "Clear points"
                            enabled: root.ready && root.activeIndex >= 0 && !root.isBlank(Points.combined(root.pointTexts()))
                            onClicked: root.armClearPoints()
                        }
                        PointButton {
                            colors: theme
                            text: "?"
                            tooltip: "Keyboard shortcuts (F1)"
                            Accessible.name: "Keyboard shortcuts"
                            onClicked: root.openHelp()
                        }
                        Item { Layout.fillWidth: true }
                        PointButton {
                            colors: theme
                            text: root.previewMode ? "Edit" : "Preview"
                            enabled: root.ready && root.activeIndex >= 0
                            onClicked: root.togglePreview()
                        }
                        PointButton {
                            colors: theme
                            text: copied.running ? "Copied!" : "Copy"
                            enabled: root.ready && root.activeIndex >= 0 && !root.isBlank(Points.combined(root.pointTexts()))
                            onClicked: root.copyForAgents()
                        }
                    }
                }
            }
            Label {
                visible: root.errorMessage.length > 0
                text: root.errorMessage
                color: theme.muted
                font.pixelSize: 11
            }
        }
    }
}
