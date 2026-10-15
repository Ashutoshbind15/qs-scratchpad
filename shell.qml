import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "ScratchpadPoints.js" as Points

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
        if (switching || !ready || activeIndex < 0) return;
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

    function copyForAgents() {
        Quickshell.clipboardText = Points.forAgents(pointTexts());
        copied.restart();
    }

    function togglePreview() {
        if (!ready || activeIndex < 0) return;
        previewMode = !previewMode;
        focusContent();
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
            data.push({ name: pad.name, points: JSON.parse(pad.pointsJson), pinned: !!pad.pinned });
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
        pads.append({ name: title, text: "", pointsJson: JSON.stringify([""]), pinned: false });
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
        const entry = { name: pad.name, text: pad.text, pointsJson: pad.pointsJson, pinned: !!pad.pinned };
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
                const pinned = [];
                const rest = [];
                const activeSource = Number.isInteger(data.activeIndex) ? data.activeIndex : -1;
                for (let i = 0; i < data.pads.length; i++) {
                    const p = data.pads[i];
                    if (typeof p.name !== "string"
                            || (p.pinned !== undefined && typeof p.pinned !== "boolean"))
                        throw new Error("Invalid scratchpad data");
                    const entries = Points.readPoints(p, data.version);
                    const content = Points.combined(entries);
                    if (root.isBlank(content) && (data.version < 3 || root.isBlank(p.name))) continue;
                    const pad = {
                        name: data.version === 3 ? p.name : Points.title(entries),
                        text: content,
                        pointsJson: JSON.stringify(entries),
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
                    pads.append({ name: pad.name, text: pad.text, pointsJson: pad.pointsJson, pinned: pad.pinned });
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
                Qt.callLater(root.focusContent);
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
            root.focusContent();
        }
    }

    // Stays mapped for the instance's lifetime; Hyprland hides it by parking
    // it on a special workspace (see omarchy.lua).
    FloatingWindow {
        id: window
        visible: true
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
            enabled: root.ready && root.activeIndex >= 0
            onActivated: root.removePad(root.activeIndex)
        }

        Shortcut {
            sequence: "Ctrl+B"
            context: Qt.WindowShortcut
            onActivated: {
                root.sidebarVisible = !root.sidebarVisible;
                root.focusContent();
            }
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
            padding: 2
            background: Rectangle {
                color: theme.surface
                radius: 0
                border.color: theme.border
                border.width: 1
            }

            MenuItem {
                id: pinAction
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
                                text: "Remove every note"
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
