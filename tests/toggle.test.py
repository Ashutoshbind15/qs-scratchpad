"""Check preload and failed-IPC recovery without touching the desktop."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

repo = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="scratchpad-startup-") as folder:
    temp = Path(folder)
    shutil.copy(repo / "toggle", temp / "toggle")
    helper = '''#!/usr/bin/env python3
import json, os, sys, time
from pathlib import Path
name = Path(sys.argv[0]).name
with open(os.environ["CALL_LOG"], "a") as log:
    log.write(json.dumps([name, *sys.argv[1:], os.environ.get("SCRATCHPAD_PREWARM", "")]) + "\\n")
if name == "pkill":
    sys.exit(1)
if name == "hyprctl":
    print("1")
if name == "quickshell" and "ipc" in sys.argv:
    if os.environ["TEST_MODE"] == "hang":
        time.sleep(2)
    if os.environ["TEST_MODE"] != "running":
        sys.exit(1)
'''
    for name in ("quickshell", "hyprctl", "pkill"):
        path = temp / name
        path.write_text(helper)
        path.chmod(0o755)
    for mode, action in [("running", "prewarm"), ("absent", "prewarm"),
                         ("running", "start"), ("absent", "start"), ("hang", "start")]:
        log = temp / "calls.jsonl"
        log.write_text("")
        env = {**os.environ, "PATH": f"{temp}:{os.environ['PATH']}",
               "CALL_LOG": str(log), "TEST_MODE": mode,
               "XDG_DATA_HOME": str(temp / "data"), "XDG_RUNTIME_DIR": str(temp)}
        env.pop("SCRATCHPAD_PREWARM", None)
        started = time.monotonic()
        subprocess.run([str(temp / "toggle"), action], env=env, check=True, timeout=3)
        elapsed = time.monotonic() - started
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        assert calls[0][0:5] == ["quickshell", "ipc", "-p", str(temp), "call"], calls
        assert calls[0][5:7] == ["scratchpad", "ping" if action == "prewarm" else "reveal"], calls
        if action == "prewarm":
            assert all(call[0] != "hyprctl" for call in calls), calls
            if mode == "running":
                assert len(calls) == 1, calls
            else:
                assert calls[1] == ["quickshell", "-p", str(temp), "--no-duplicate", "--daemonize", "1"], calls
        elif mode == "running":
            assert len(calls) == 2 and calls[1][0] == "hyprctl", calls
        else:
            assert calls[1][0] == "pkill", calls
            assert calls[2] == ["quickshell", "-p", str(temp), "--no-duplicate", "--daemonize", ""], calls
            assert calls[3][0] == "hyprctl", calls
            assert elapsed < 1.5, elapsed
    store = json.loads((temp / "data/quickshell-scratchpad/scratchpads.json").read_text())
    assert store["version"] == 1 and len(store["pads"]) == 1, store
print("Hidden preload, existing instance reuse, cold startup and hung-IPC recovery passed")
