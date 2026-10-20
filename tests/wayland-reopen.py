"""Exercise compositor closes and real Wayland mapping with isolated notes.

Requires a running Hyprland session. Briefly opens a Scratchpad test window.
Pass --shell PATH to check a previous shell.qml against this regression.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

repo = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--shell", type=Path, default=repo / "shell.qml")
args = parser.parse_args()


def lua(source):
    result = subprocess.run(["hyprctl", "eval", source], capture_output=True, text=True, check=True)
    assert result.stdout.strip() == "ok", result.stdout + result.stderr


def clients():
    return json.loads(subprocess.check_output(["hyprctl", "-j", "clients"], text=True))


lua("scratchpad_reopen_test_focus = hl.get_active_window()")
try:
    with tempfile.TemporaryDirectory(prefix="scratchpad-wayland-") as folder:
        temp = Path(folder)
        for pattern in ("*.qml", "*.js"):
            for source in repo.glob(pattern):
                shutil.copy(source, temp)
        for name in ("editor", "node_modules"):
            (temp / name).symlink_to(repo / name, target_is_directory=True)
        (temp / "shell.qml").write_text(args.shell.read_text())
        store = temp / "notes.json"
        store.write_text(json.dumps({"version": 3, "activeIndex": 0, "pads": [
            {"name": "Global", "points": ["Original point"], "global": True, "pinned": True}
        ]}))
        env = {**os.environ, "QT_QPA_PLATFORM": "wayland", "SCRATCHPAD_FILE": str(store),
               "SCRATCHPAD_PREWARM": "1", "QML_IMPORT_PATH": str(repo)}
        process = subprocess.Popen(["quickshell", "-p", str(temp), "--no-color"], env=env,
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

        def mapped():
            return any(w["pid"] == process.pid and w["mapped"] for w in clients())

        def wait_mapped(expected, timeout=0.5):
            start = time.monotonic()
            while mapped() != expected:
                assert time.monotonic() - start < timeout, f"Window mapped != {expected} after {timeout}s"
                time.sleep(0.01)

        def ipc(action, *arguments):
            result = subprocess.run(["quickshell", "ipc", "-p", str(temp), "call", "--",
                                     "scratchpad", action, *arguments], env=env,
                                    capture_output=True, text=True, timeout=2, check=True)
            assert not result.stdout.strip(), result.stdout + result.stderr

        try:
            # Startup readiness must check the actual target, not merely the
            # CLI exit code (some IPC errors are printed with exit status 0).
            for attempt in range(100):
                result = subprocess.run(["quickshell", "ipc", "-p", str(temp), "show"],
                                        env=env, capture_output=True, text=True, timeout=2)
                if "reveal" in result.stdout:
                    break
                assert process.poll() is None, "Quickshell exited during preload"
                time.sleep(0.01)
            else:
                raise AssertionError("Preloaded IPC did not become ready")
            assert not mapped(), "Preload mapped a window"
            ipc("reveal")
            wait_mapped(True)
            timings = []
            for cycle in range(6):
                lua(f'for _, w in ipairs(hl.get_windows({{ class = "org.quickshell", title = "Scratchpad" }})) do '
                    f'if w.pid == {process.pid} then hl.dispatch(hl.dsp.window.close({{ window = w }})) end end')
                wait_mapped(False)
                start = time.monotonic()
                if cycle % 2:
                    ipc("capture", f"Capture {cycle}")
                else:
                    ipc("reveal")
                wait_mapped(True)
                timings.append(round((time.monotonic() - start) * 1000))
                assert process.poll() is None, "Reopen restarted Quickshell"
            # Read the store after the final capture's atomic save completes.
            for attempt in range(50):
                entries = json.loads(store.read_text())["pads"][0]["points"]
                if entries == ["Original point", "Capture 1", "Capture 3", "Capture 5"]:
                    break
                time.sleep(0.01)
            else:
                raise AssertionError(f"Reopening lost point data: {entries}")
            print(f"Real Wayland close/reopen and capture passed without restart; mapping latencies: {timings} ms")
        finally:
            process.terminate()
            output, _ = process.communicate(timeout=5)
            assert "TypeError" not in output and "ReferenceError" not in output, output
finally:
    lua("if scratchpad_reopen_test_focus then "
        "hl.dispatch(hl.dsp.focus({ window = scratchpad_reopen_test_focus })) end; "
        "scratchpad_reopen_test_focus = nil")
