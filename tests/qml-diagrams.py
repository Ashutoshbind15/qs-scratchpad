"""Draw in the real embedded ScribbleSVG canvas, with throwaway notes."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="scratchpad-diagrams-") as folder:
    temp = Path(folder)
    for pattern in ("*.qml", "*.js"):
        for source in repo.glob(pattern):
            shutil.copy(source, temp)
    for name in ("editor", "node_modules"):
        (temp / name).symlink_to(repo / name, target_is_directory=True)
    store = temp / "notes.json"
    invalid = '```scribblesvg\n{"version":99}\n```'
    store.write_text(json.dumps({"version": 3, "activeIndex": 0, "pads": [
        {"name": "Global", "global": True, "pinned": True, "points": ["", "**Keep this text.**", invalid]},
    ]}))
    harness = r'''
    TestCase { id: interaction; name: "LocalDiagrams"; when: false }
    Timer {
        interval: 200; running: true; repeat: true
        property int step: 0
        property int ticks: 0
        property bool waiting: false
        property real canvasX: 0
        property real canvasY: 0
        property string diagramSource: ""
        function check(value, message) { if (!value) throw new Error(message); }
        function diagram() { return JSON.parse(points.get(0).body.split("\n")[1]); }
        function js(code, callback) {
            waiting = true;
            pointEditor.browser.runJavaScript(code, result => {
                waiting = false;
                try { callback(result); }
                catch (error) { console.error("DIAGRAMS_FAILED step " + step + ": " + error.message); Qt.quit(); }
            });
        }
        onTriggered: {
            try {
                if (++ticks > 160) throw new Error("timed out at step " + step);
                if (waiting) return;
                switch (step) {
                case 0:
                    if (!pointEditor.loaded) return;
                    js("window.scratchpad.points.length === 3 && window.scratchpad.points.every(p => p.ready)", ready => {
                        if (ready) { root.focusContent(); step++; }
                    }); break;
                case 1:
                    interaction.keyClick(Qt.Key_D, Qt.ControlModifier | Qt.ShiftModifier);
                    step++; break;
                case 2:
                    js(`(() => {
                        const svg = document.querySelector('.scribblesvg-editor__svg');
                        if (!svg) return null;
                        document.querySelector('button[aria-label="Rectangle"]').click();
                        const box = svg.getBoundingClientRect();
                        return [box.x + 80, box.y + 80];
                    })()`, value => {
                        if (!value) return;
                        check(points.count === 3, "new diagram reuses the blank point");
                        canvasX = value[0]; canvasY = value[1]; step++;
                    }); break;
                case 3:
                    interaction.mouseDrag(pointEditor.browser, canvasX, canvasY, 110, 70, Qt.LeftButton);
                    step++; break;
                case 4:
                    check(diagram().elements.length === 1 && diagram().elements[0].type === "rectangle",
                          "real pointer input creates and autosaves a rectangle");
                    interaction.keyClick(Qt.Key_Z, Qt.ControlModifier);
                    step++; break;
                case 5:
                    check(diagram().elements.length === 0, "drawing undo works");
                    interaction.keyClick(Qt.Key_Z, Qt.ControlModifier | Qt.ShiftModifier);
                    step++; break;
                case 6:
                    check(diagram().elements.length === 1, "drawing redo works");
                    interaction.keyClick(Qt.Key_Return, Qt.ControlModifier);
                    step++; break;
                case 7:
                    js(`!document.querySelector('dialog') &&
                        document.querySelector('.diagram-preview svg [data-element-id]') !== null`, value => {
                        check(value, "Done returns to a rendered diagram preview");
                        diagramSource = points.get(0).body;
                        check(points.get(1).body === "**Keep this text.**", "Markdown is unchanged");
                        root.movePoint(0, 1); step++;
                    }); break;
                case 8:
                    check(points.get(1).body === diagramSource, "diagram reorders like other points");
                    root.movePoint(1, -1);
                    root.newPad(); step++; break;
                case 9:
                    root.updateTitle("Other");
                    root.updatePoint(0, "Another note");
                    root.openGlobal(); step++; break;
                case 10:
                    js(`(() => {
                        const button = document.querySelector('.diagram-preview');
                        if (!button) return false;
                        button.click(); return true;
                    })()`, value => { if (value) step++; }); break;
                case 11:
                    js(`(() => {
                        if (!document.querySelector('dialog')) return false;
                        document.querySelector('button[aria-label="Text"]').click();
                        return true;
                    })()`, value => { if (value) step++; }); break;
                case 12:
                    interaction.mouseClick(pointEditor.browser, canvasX + 10, canvasY + 170);
                    step++; break;
                case 13:
                    js("!!document.querySelector('.scribblesvg-editor__text-input')", value => {
                        check(value, "text tool opens its input"); step++;
                    }); break;
                case 14:
                    interaction.keyClick(Qt.Key_X);
                    // Close while the text is still focused; Done must commit it.
                    interaction.keyClick(Qt.Key_Return, Qt.ControlModifier);
                    step++; break;
                case 15:
                    check(diagram().elements.some(e => e.type === "text" && e.text === "x"),
                          "Done commits a label still being typed");
                    js("document.querySelector('.diagram-preview').click(); true", () => { step++; }); break;
                case 16:
                    interaction.keyClick(Qt.Key_Escape);
                    interaction.keyClick(Qt.Key_W, Qt.ControlModifier | Qt.ShiftModifier);
                    step++; break;
                case 17:
                    check(window.visible && points.count === 3, "drawing keys do not hide or delete note points");
                    js("!!document.querySelector('dialog')", value => {
                        check(value, "Escape belongs to the drawing editor");
                        interaction.keyClick(Qt.Key_Return, Qt.ControlModifier); step++;
                    }); break;
                case 18:
                    js(`document.querySelectorAll('.diagram-error').length === 1 &&
                        window.scratchpad.points[2].kind === 'markdown'`, value => {
                        check(value, "invalid diagrams stay editable as Markdown");
                        check(points.get(2).body === '```scribblesvg\n{"version":99}\n```', "invalid source preserved");
                        root.save(); console.log("DIAGRAMS_OK"); Qt.quit();
                    }); break;
                }
            } catch (error) {
                console.error("DIAGRAMS_FAILED step " + step + ": " + error.message); Qt.quit();
            }
        }
    }
'''
    source = "import QtTest\n" + (repo / "shell.qml").read_text()
    shell = temp / "shell.qml"
    shell.write_text(source[:source.rfind("}")] + harness + "}\n")
    env = {**os.environ, "QT_QPA_PLATFORM": "offscreen", "SCRATCHPAD_FILE": str(store),
           "QML_IMPORT_PATH": str(repo), "QTWEBENGINE_CHROMIUM_FLAGS": "--disable-gpu"}
    env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
    result = subprocess.run(["quickshell", "-p", str(temp), "--no-color"], env=env,
                            capture_output=True, text=True, timeout=40)
    output = result.stdout + result.stderr
    assert "DIAGRAMS_OK" in output, output
    assert "TypeError" not in output and "ReferenceError" not in output, output
    saved = json.loads(store.read_text())
    points = next(note for note in saved["pads"] if note.get("global"))["points"]
    diagram = json.loads(points[0].split("\n")[1])
    assert any(element["type"] == "rectangle" for element in diagram["elements"]), diagram
    assert any(element["type"] == "text" and element["text"] == "x" for element in diagram["elements"]), diagram
    assert points[1:] == ["**Keep this text.**", invalid], points
    saved_source = points[0]
    shell.write_text(source[:source.rfind("}")] + r'''
    Timer {
        interval: 200; running: true; repeat: true
        property int ticks: 0
        onTriggered: {
            if (++ticks > 50) { console.error("DIAGRAM_RELOAD_FAILED"); Qt.quit(); }
            if (!pointEditor.loaded) return;
            pointEditor.browser.runJavaScript(
                "document.querySelectorAll('.diagram-preview svg [data-element-id]').length", count => {
                    if (count === 2) { console.log("DIAGRAM_RELOAD_OK"); Qt.quit(); }
                });
        }
    }
}
''')
    result = subprocess.run(["quickshell", "-p", str(temp), "--no-color"], env=env,
                            capture_output=True, text=True, timeout=15)
    assert "DIAGRAM_RELOAD_OK" in result.stdout + result.stderr, result.stdout + result.stderr
    reloaded = json.loads(store.read_text())
    assert next(note for note in reloaded["pads"] if note.get("global"))["points"][0] == saved_source
    print("Local diagrams: native drawing, undo/redo, autosave, label commit, reorder, note switching, "
          "shortcut isolation, invalid-source recovery and process reload passed")
