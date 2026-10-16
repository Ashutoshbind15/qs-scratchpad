"""Exercise real QML delegates and persistence without touching the user's notes."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="scratchpad-points-") as folder:
    temp = Path(folder)
    for pattern in ("*.qml", "*.js"):
        for source in repo.glob(pattern):
            shutil.copy(source, temp)
    store = temp / "notes.json"
    store.write_text(json.dumps({"version": 1, "activeIndex": 0, "pads": [
        {"name": "Old", "text": "Legacy\n\noriginal text", "pinned": False},
        {"name": "Other", "text": "Other note", "pinned": True},
    ]}))
    harness = '''
    Timer {
        interval: 120; running: true; repeat: true
        property int step: 0
        function check(value, message) { if (!value) throw new Error(message); }
        function findChild(item, name) {
            if (item.objectName === name) return item;
            for (const child of item.children || []) {
                const found = findChild(child, name);
                if (found) return found;
            }
            return null;
        }
        onTriggered: {
            try {
                switch (step++) {
                case 0:
                    check(root.ready, "loaded");
                    check(points.count === 1 && points.get(0).body === "Legacy\\n\\noriginal text", "legacy migration");
                    check(root.editor !== null, "editor available");
                    check(root.editor.activeFocus, "startup editor focus");
                    check(findChild(pointRepeater.itemAt(0), "markdownLoader").item === null, "preview deferred while editing");
                    root.addPoint(); break;
                case 1:
                    check(points.count === 2 && root.editor !== null, "new point editor");
                    root.editor.text = "Second point\\n- nested detail"; break;
                case 2:
                    check(points.get(1).body === "Second point\\n- nested detail", "edits update model");
                    check(root.activeTitle === "Legacy", "body edits preserve separate title");
                    root.movePoint(1, -1); break;
                case 3:
                    check(root.editor.text === "Second point\\n- nested detail", "moved editor");
                    root.focusPoint(1);
                    check(root.activePoint === 1 && root.editor.text.indexOf("original text") >= 0, "next point");
                    root.focusPoint(1);
                    check(root.activePoint === 1, "next point stops at the end");
                    root.focusPoint(-1);
                    check(root.activePoint === 0 && root.editor.text.indexOf("Second") === 0, "previous point");
                    root.reorderPoint(1);
                    check(points.get(1).body.indexOf("Second") === 0, "reorder down");
                    root.reorderPoint(-1);
                    check(points.get(0).body.indexOf("Second") === 0 && root.activePoint === 0, "reorder up");
                    root.reorderPoint(-1);
                    check(root.activePoint === 0 && points.get(0).body.indexOf("Second") === 0, "reorder stops at the top");
                    root.togglePreview(); break;
                case 4:
                    check(findChild(pointRepeater.itemAt(0), "markdownLoader").item !== null, "preview loaded on demand");
                    root.togglePreview();
                    check(findChild(pointRepeater.itemAt(0), "markdownLoader").item !== null, "preview retained for reuse");
                    root.newPad(); break;
                case 5:
                    check(titleInput.selectedText.indexOf("untitled-") === 0, "new title selected");
                    check(root.editor.text === "", "new point starts empty");
                    root.updateTitle("Custom title");
                    root.editor.text = "New scratchpad";
                    root.selectPad(2); break;
                case 6:
                    check(points.count === 2 && points.get(0).body.indexOf("Second") === 0, "switch restores points");
                    root.togglePin(root.activeIndex); break;
                case 7:
                    check(root.editor.text.indexOf("Second") === 0, "pin preserves editor");
                    root.removePoint(1); break;
                case 8:
                    check(points.count === 1, "remove point");
                    root.addPoint(); break;
                case 9:
                    root.editor.text = "Final point";
                    root.save(); break;
                case 10:
                    root.captureGlobal(); break;
                case 11:
                    check(root.activeGlobal && root.activeTitle === "Global", "capture targets Global");
                    check(points.count === 1 && root.editor.activeFocus, "capture focuses empty Global");
                    root.editor.text = "Captured point";
                    root.captureGlobal(); break;
                case 12:
                    check(points.count === 2 && root.editor.text === "", "capture appends fresh point");
                    root.editor.text = "Second capture";
                    root.selectPad(2);
                    root.captureGlobal(); break;
                case 13:
                    check(points.count === 3 && points.get(0).body === "Captured point", "capture preserves Global across switches");
                    root.removePad(root.activeIndex);
                    check(root.activeGlobal, "Global cannot be deleted");
                    root.armClearPoints();
                    check(points.count === 3, "clear requires confirmation");
                    root.armClearPoints();
                    check(points.count === 1 && root.activeTitle === "Global", "clear keeps Global container");
                    root.selectPad(2);
                    root.armClearPoints(); root.armClearPoints();
                    check(points.count === 1 && root.activeTitle === "Legacy", "clear keeps individual title");
                    root.updatePoint(0, "Second point\\n- nested detail");
                    root.addPoint(); root.updatePoint(1, "Final point");
                    root.save(); break;
                case 14:
                    root.captureGlobal("Selected text\\nwith trailing newline\\n"); break;
                case 15:
                    check(root.activeGlobal && points.count === 1, "selection reuses empty Global point");
                    check(root.editor.text === "Selected text\\nwith trailing newline\\n", "selection preserves exact text");
                    root.captureGlobal("- second selection"); break;
                case 16:
                    check(points.count === 2 && root.editor.text === "- second selection", "selection appends without replacing existing point");
                    root.openHelp(); break;
                case 17:
                    check(helpPopup.opened && helpPopup.searchField.activeFocus, "help opens with search focused");
                    check(helpPopup.rows.length > 10, "help lists shortcuts");
                    helpPopup.searchField.text = "browse";
                    check(helpPopup.rows.length === 1 && helpPopup.rows[0].keys === "CTRL + B", "help filters shortcuts");
                    helpPopup.run(helpPopup.currentIndex); break;
                case 18:
                    check(!helpPopup.opened && root.browsing, "help runs the selected shortcut");
                    check(browseSearch.activeFocus, "browser focuses search");
                    check(root.browseSelected.index === root.activeIndex, "browser selects the open note");
                    check(root.browseRows.length === 4 && root.browseVisible.length === 4, "browser lists every note");
                    check(JSON.stringify(root.browseRows.map(r => r.name)) === JSON.stringify(["Global", "Legacy", "Other note", "Custom title"]),
                          "browser lists pinned notes, then newest edit first");
                    root.setBrowseCurrent(3);
                    root.pinNote();
                    check(root.browseSelected.name === "Custom title" && root.browseCurrent === 2, "pinning keeps the selection on the note");
                    root.pinNote();
                    check(root.browseSelected.name === "Custom title" && root.browseCurrent === 3, "unpinning keeps the selection on the note");
                    browseSearch.text = "cust";
                    check(root.browseRows.length === 1 && root.browseRows[0].name === "Custom title", "browser filters by title");
                    check(root.browseRows[0].snippet === "New scratchpad", "browser shows a snippet");
                    browseSearch.text = "";
                    for (let i = 0; i < 45; i++)
                        pads.append({ name: "bulk-" + i, text: "", pointsJson: JSON.stringify([""]), pinned: false, global: false, updated: 0 });
                    check(root.browseRows.length === 49 && root.browseVisible.length === 20, "browser shows one page");
                    root.turnBrowsePage(1);
                    check(root.browsePageShown === 1 && root.browseVisible[0].name === "bulk-16", "next page");
                    root.turnBrowsePage(5);
                    check(root.browsePageShown === 2 && root.browseVisible.length === 9, "last page");
                    root.browseMove(-root.browseCurrent - 1);
                    check(root.browsePageShown === 1 && root.browseCurrent === 19, "moving up crosses pages");
                    root.setBrowseScroll(true);
                    check(root.browseVisible.length >= 40 && root.browseSelected.name === "bulk-35", "scroll mode keeps the selection");
                    root.browseMove(20);
                    check(root.browseVisible.length === 49, "scroll mode loads more");
                    root.browseEscape();
                    check(!root.browsing, "escape closes the browser");
                    for (let i = pads.count - 1; i >= 4; i--) pads.remove(i);
                    root.openBrowser();
                    browseSearch.text = "legacy";
                    root.openBrowseRow(0); break;
                case 19:
                    check(!root.browsing && root.activeTitle === "Legacy", "browser opens the selected note");
                    check(theme.fontSize === theme.defaultFontSize, "default text size");
                    root.zoom(1); root.zoom(1); root.zoom(-1);
                    check(theme.fontSize === theme.defaultFontSize + 1, "zoom steps text size");
                    for (let i = 0; i < 40; i++) root.zoom(1);
                    check(theme.fontSize === theme.maxFontSize, "zoom is clamped");
                    root.zoom(0); root.zoom(1);
                    root.renameNote(); break;
                case 20:
                    check(titleInput.activeFocus && titleInput.selectedText === "Legacy", "F2 selects the title");
                    root.openGlobal();
                    check(root.activeGlobal, "Ctrl+G opens Global");
                    check(pointRepeater.itemAt(0).showControls, "point buttons shown by default");
                    check(!findChild(window.contentItem, "toast").visible, "no toast outside zen");
                    root.toggleZen();
                    check(root.zen && !pointRepeater.itemAt(0).showControls, "zen hides point buttons");
                    check(findChild(window.contentItem, "toast").visible && root.toastText.indexOf("Ctrl+H") >= 0, "zen shows how to exit");
                    root.copyForAgents();
                    check(root.toastText === "Copied to clipboard", "zen copy toast");
                    root.zoom(1); root.zoom(-1);
                    check(root.toastText === "Text size " + theme.fontSize + " px", "zen zoom toast");
                    root.runBinding("clearPoints");
                    check(root.clearPointsArmed && points.count === 2 && root.toastText.indexOf("again") >= 0, "zen clear asks to press again");
                    root.clearPointsArmed = false;
                    root.runBinding("shortWindow");
                    check(root.shortWindow && root.toastText.indexOf("Short window") === 0, "short window");
                    root.runBinding("tallWindow");
                    check(!root.shortWindow, "tall window");
                    root.setShortWindow(true);
                    root.togglePointControls();
                    check(!root.zen && root.pointControls, "point buttons toggle leaves zen");
                    root.togglePointControls();
                    check(!root.pointControls && !pointRepeater.itemAt(0).showControls, "point buttons hide");
                    root.newPad(); break;
                case 21:
                    root.editor.text = "Throwaway";
                    root.runBinding("clearPoints"); root.runBinding("clearPoints");
                    check(points.count === 1 && root.editor.text === "", "clear points shortcut action");
                    root.editor.text = "Fresh note";
                    for (let i = 0; i < pads.count; i++) if (pads.get(i).name === "Custom title") root.selectPad(i);
                    break;
                case 22:
                    check(root.activeTitle === "Custom title", "reopened older note");
                    root.updateTitle("Custom title");
                    root.openBrowser();
                    check(JSON.stringify(root.browseRows.map(r => r.name)) === JSON.stringify(["Global", "Legacy", "Other note", "Custom title", "untitled-1"]),
                          "editing moves a note above newer ones");
                    browseSearch.text = "t";
                    check(JSON.stringify(root.browseRows.map(r => r.name)) === JSON.stringify(["Other note", "Custom title", "untitled-1"]),
                          "search keeps the newest-first order");
                    root.closeBrowser();
                    for (let i = 0; i < pads.count; i++) if (pads.get(i).name === "Legacy") root.selectPad(i);
                    root.save();
                    console.log("POINTS_SMOKE_OK"); Qt.quit(); break;
                }
            } catch (error) {
                console.error("POINTS_SMOKE_FAILED: " + error.message);
                Qt.quit();
            }
        }
    }
'''
    shell = temp / "shell.qml"
    text = shell.read_text()
    shell.write_text(text[:text.rfind('}')] + harness + '}\n')
    # Without Hyprland's socket, window-size requests can't reach the live scratchpad.
    env = {**os.environ, "QT_QPA_PLATFORM": "offscreen", "SCRATCHPAD_FILE": str(store)}
    env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
    result = subprocess.run(["quickshell", "-p", str(temp), "--no-color"], env=env,
                            capture_output=True, text=True, timeout=15)
    output = result.stdout + result.stderr
    assert "POINTS_SMOKE_OK" in output, output
    assert "TypeError" not in output and "ReferenceError" not in output, output
    saved = json.loads(store.read_text())
    assert saved["version"] == 3, saved
    assert len([p for p in saved["pads"] if p.get("global")]) == 1, saved
    assert next(p for p in saved["pads"] if p.get("global"))["points"] == ["Selected text\nwith trailing newline\n", "- second selection"], saved
    active = saved["pads"][saved["activeIndex"]]
    assert active["points"] == ["Second point\n- nested detail", "Final point"], saved
    assert active["pinned"], saved
    assert any(p["points"] == ["New scratchpad"] and p["name"] == "Custom title" for p in saved["pads"]), saved
    assert active["name"] == "Legacy", saved
    assert saved["browseMode"] == "scroll", saved
    assert saved["fontSize"] == 18, saved
    assert saved["pointControls"] is False and saved["zen"] is False, saved
    assert saved["shortWindow"] is True, saved
    assert active["updated"] > 0, saved
    assert next(p for p in saved["pads"] if p["name"] == "Other note")["updated"] == 0, saved
    # Relaunch the same store to exercise the v2 reader too.
    text = shell.read_text()
    start = text.index('    Timer {\n        interval: 120;')
    shell.write_text(text[:start] + '''
    Timer {
        interval: 300; running: true
        onTriggered: {
            if (root.ready && root.activeTitle === "Legacy" && points.count === 2 && points.get(1).body === "Final point"
                    && theme.fontSize === 18 && !root.pointControls && root.shortWindow)
                console.log("POINTS_RELOAD_OK");
            Qt.quit();
        }
    }
}\n''')
    result = subprocess.run(["quickshell", "-p", str(temp), "--no-color"], env=env,
                            capture_output=True, text=True, timeout=10)
    assert "POINTS_RELOAD_OK" in result.stdout + result.stderr, result.stdout + result.stderr
    print("QML points, editing, ordering, preview, switching, pinning, save and reload passed")

    # A login preload must load data without mapping or stealing focus. Exercise
    # the real IPC entry points, including first capture before a surface exists.
    source = (repo / "shell.qml").read_text().replace('function ping(): void {}',
        'function ping(): void {}\n        function isVisible(): bool { return window.visible; }')
    shell.write_text(source)
    preload_env = {**env, "SCRATCHPAD_PREWARM": "1"}
    process = subprocess.Popen(["quickshell", "-p", str(temp), "--no-color"],
                               env=preload_env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    try:
        import time
        for attempt in range(50):
            ping = subprocess.run(["quickshell", "ipc", "-p", str(temp), "call", "scratchpad", "ping"],
                                  env=preload_env, capture_output=True, timeout=2)
            if ping.returncode == 0:
                break
            time.sleep(0.02)
        else:
            raise AssertionError("preload IPC did not become ready")
        for attempt in range(50):
            state = subprocess.run(["quickshell", "ipc", "-p", str(temp), "call", "scratchpad", "isVisible"],
                                   env=preload_env, capture_output=True, text=True, timeout=2)
            if state.stdout.strip() in ("true", "false"):
                break
            time.sleep(0.02)
        assert state.stdout.strip() == "false", state.stdout + state.stderr
        request = subprocess.run(["quickshell", "ipc", "-p", str(temp), "call", "--", "scratchpad", "capture", "Preloaded capture"],
                                 env=preload_env, capture_output=True, text=True, timeout=2)
        assert request.returncode == 0, request.stderr
        state = subprocess.run(["quickshell", "ipc", "-p", str(temp), "call", "scratchpad", "isVisible"],
                               env=preload_env, capture_output=True, text=True, timeout=2)
        assert state.stdout.strip() == "true", state.stdout + state.stderr
        for attempt in range(50):
            loaded = json.loads(store.read_text())
            global_pad = next(p for p in loaded["pads"] if p.get("global"))
            if global_pad["points"][-1] == "Preloaded capture":
                break
            time.sleep(0.02)
        else:
            raise AssertionError("preloaded capture was not saved")
        print("Preload stays hidden; first IPC capture reveals and persists passed")
    finally:
        process.terminate()
        output, _ = process.communicate(timeout=5)
        assert "TypeError" not in output and "ReferenceError" not in output, output
