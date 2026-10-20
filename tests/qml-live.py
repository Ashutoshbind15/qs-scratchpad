"""Exercise the embedded live editor with real Qt key events and isolated notes."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="scratchpad-live-") as folder:
    temp = Path(folder)
    for pattern in ("*.qml", "*.js"):
        for source in repo.glob(pattern):
            shutil.copy(source, temp)
    for name in ("editor", "node_modules"):
        (temp / name).symlink_to(repo / name, target_is_directory=True)
    store = temp / "notes.json"
    original = ("- First item\n- Second item\n\n"
                + "A paragraph in a long point.\n\n" * 30
                + "| Name | Value |\n| --- | --- |\n| hello | world |")
    store.write_text(json.dumps({"version": 3, "activeIndex": 0, "pads": [
        {"name": "Global", "global": True, "pinned": True,
         "points": [original, "A second **formatted** point."]},
    ]}))
    harness = '''
    TestCase { id: interaction; name: "LiveMarkdown"; when: false }
    Timer {
        interval: 400; running: true; repeat: true
        property int step: 0
        property bool waiting: false
        property int ticks: 0
        function check(value, message) { if (!value) throw new Error(message); }
        function js(code, callback) {
            waiting = true;
            pointEditor.browser.runJavaScript(code, result => {
                waiting = false;
                try { callback(result); }
                catch (error) { console.error("LIVE_FAILED: " + error.message); Qt.quit(); }
            });
        }
        onTriggered: {
            try {
                if (++ticks > 45) throw new Error("live editor timed out at step " + step);
                if (waiting) return;
                switch (step) {
                case 0:
                    if (!pointEditor.loaded) return;
                    js("window.scratchpad.points.length === 2 && window.scratchpad.points.every(p => p.ready)", ready => {
                        if (ready) { root.focusContent(); step++; }
                    }); break;
                case 1:
                    check(points.get(0).body.indexOf("| hello | world |") >= 0, "loading preserves exact source");
                    js(`(() => {
                        const editor = document.querySelector('.vditor-ir [contenteditable="true"]');
                        const cell = editor.querySelector('td');
                        editor.focus();
                        const range = document.createRange(); range.selectNodeContents(cell); range.collapse(false);
                        getSelection().removeAllRanges(); getSelection().addRange(range);
                        return editor.querySelectorAll('li').length === 2 && editor.querySelectorAll('table').length === 1;
                    })()`, value => { check(value, "list and table render in the same editable point"); step++; }); break;
                case 2:
                    interaction.keyClick(Qt.Key_X);
                    step++; break;
                case 3:
                    check(points.get(0).body.indexOf("hellox") >= 0, "typing in a table updates saved Markdown");
                    js(`(() => {
                        const editor = document.querySelector('.vditor-ir [contenteditable="true"]');
                        const list = editor.querySelector('ul');
                        return list && getComputedStyle(list.querySelector('li')).display === 'list-item'
                            && list.textContent.includes('First item') && editor.querySelector('td').textContent === 'hellox'
                            && window.scrollY > 0;
                    })()`, value => { check(value, "editing table keeps preceding list formatted"); step++; }); break;
                case 4:
                    interaction.keyClick(Qt.Key_Down, Qt.AltModifier);
                    step++; break;
                case 5:
                    check(root.activePoint === 1, "Alt+Down moves between points from inside the browser");
                    interaction.keyClick(Qt.Key_Up, Qt.AltModifier);
                    step++; break;
                case 6:
                    check(root.activePoint === 0, "Alt+Up returns to the original editor");
                    interaction.keyClick(Qt.Key_Z, Qt.ControlModifier);
                    step++; break;
                case 7:
                    check(points.get(0).body.indexOf("hellox") < 0 && points.get(0).body.indexOf("hello") >= 0,
                          "undo survives switching points");
                    interaction.keyClick(Qt.Key_Return, Qt.ControlModifier);
                    step++; break;
                case 8:
                    check(points.count === 3 && root.activePoint === 2, "Ctrl+Enter adds a point");
                    js("window.scratchpad.points.length === 3 && window.scratchpad.points[2].ready", ready => {
                        if (ready) step++;
                    }); break;
                case 9:
                    interaction.keyClick(Qt.Key_X);
                    // Immediately changing notes must flush this last keystroke.
                    interaction.keyClick(Qt.Key_N, Qt.ControlModifier);
                    step++; break;
                case 10:
                    check(root.activeTitle.indexOf("untitled-") === 0, "Ctrl+N works inside the editor");
                    root.selectPad(0);
                    step++; break;
                case 11:
                    check(points.get(2).body.trim() === "x", "last keystroke survives an immediate note switch");
                    const document = pointEditor.documentId;
                    root.renameNote();
                    check(pointEditor.documentId === document, "renaming keeps the open editors and their undo");
                    root.save();
                    console.log("LIVE_EDITOR_OK"); Qt.quit(); break;
                }
            } catch (error) {
                console.error("LIVE_FAILED: " + error.message); Qt.quit();
            }
        }
    }
'''
    source = "import QtTest\n" + (repo / "shell.qml").read_text()
    (temp / "shell.qml").write_text(source[:source.rfind('}')] + harness + '}\n')
    env = {**os.environ, "QT_QPA_PLATFORM": "offscreen", "SCRATCHPAD_FILE": str(store),
           "QML_IMPORT_PATH": str(repo), "QTWEBENGINE_CHROMIUM_FLAGS": "--disable-gpu"}
    env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
    result = subprocess.run(["quickshell", "-p", str(temp), "--no-color"], env=env,
                            capture_output=True, text=True, timeout=25)
    output = result.stdout + result.stderr
    assert "LIVE_EDITOR_OK" in output, output
    assert "TypeError" not in output and "ReferenceError" not in output, output
    saved = json.loads(store.read_text())
    points = next(note for note in saved["pads"] if note.get("global"))["points"]
    assert points[2].strip() == "x", points
    assert "First item" in points[0] and "hellox" not in points[0], points
    print("Live table editing keeps lists rendered; native keys, undo, point insertion, immediate note switching and saving passed")
