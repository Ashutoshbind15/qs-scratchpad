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
                    root.selectPad(2);
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
    env = {**os.environ, "QT_QPA_PLATFORM": "offscreen", "SCRATCHPAD_FILE": str(store)}
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
    # Relaunch the same store to exercise the v2 reader too.
    text = shell.read_text()
    start = text.index('    Timer {\n        interval: 120;')
    shell.write_text(text[:start] + '''
    Timer {
        interval: 300; running: true
        onTriggered: {
            if (root.ready && root.activeTitle === "Legacy" && points.count === 2 && points.get(1).body === "Final point")
                console.log("POINTS_RELOAD_OK");
            Qt.quit();
        }
    }
}\n''')
    result = subprocess.run(["quickshell", "-p", str(temp), "--no-color"], env=env,
                            capture_output=True, text=True, timeout=10)
    assert "POINTS_RELOAD_OK" in result.stdout + result.stderr, result.stdout + result.stderr
    print("QML points, editing, ordering, preview, switching, pinning, save and reload passed")
