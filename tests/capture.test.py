"""Check selection transport without changing the desktop or clipboard."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

repo = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="scratchpad-capture-") as folder:
    temp = Path(folder)
    shutil.copy(repo / "capture", temp / "capture")
    helper = '''#!/usr/bin/env python3
import json, os, sys, time
from pathlib import Path
name = Path(sys.argv[0]).name
with open(os.environ["CALL_LOG"], "a") as log:
    log.write(json.dumps([name, *sys.argv[1:]]) + "\\n")
if name == "wl-paste":
    if os.environ.get("STALL_SELECTION"):
        sys.stdout.write("incomplete")
        sys.stdout.flush()
        time.sleep(2)
    if os.environ.get("NO_SELECTION"):
        sys.exit(1)
    sys.stdout.write(os.environ["SELECTION"])
if name == "quickshell" and os.environ.get("COLD"):
    marker = Path(os.environ["CALL_LOG"] + ".started")
    if not marker.exists():
        marker.touch()
        sys.exit(1)
if name == "hyprctl":
    marker = Path(os.environ["CALL_LOG"] + ".mapped")
    if os.environ.get("UNMAPPED") and not marker.exists():
        marker.touch()
        print("false")
    else:
        print("true")
'''
    for name in ("wl-paste", "toggle", "quickshell", "hyprctl"):
        path = temp / name
        path.write_text(helper)
        path.chmod(0o755)
    for selection, flags in [
        ("--selected ‘text’\n\n", {}),
        ("", {"NO_SELECTION": "1"}),
        ("", {"STALL_SELECTION": "1"}),
        ("Cold selection", {"COLD": "1"}),
        ("Preloaded selection", {"UNMAPPED": "1"}),
    ]:
        log = temp / "calls.jsonl"
        log.write_text("")
        env = {**os.environ, "PATH": f"{temp}:{os.environ['PATH']}",
               "CALL_LOG": str(log), "SELECTION": selection, **flags}
        started = time.monotonic()
        subprocess.run([str(temp / "capture")], env=env, check=True, timeout=5)
        elapsed = time.monotonic() - started
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        assert calls[0] == ["wl-paste", "--primary", "--type", "text", "--no-newline"], calls
        request = ["quickshell", "ipc", "-p", str(temp), "call", "--", "scratchpad", "capture", selection]
        assert calls[1] == request, calls
        if "COLD" in flags:
            assert calls[2:4] == [["toggle", "start"], request], calls
        elif "UNMAPPED" in flags:
            assert calls[2:] == [["hyprctl", "repl", "return quickshell_scratchpad_show()"],
                                 ["toggle", "start"], ["hyprctl", "eval", "quickshell_scratchpad_show()"]], calls
        else:
            assert len(calls) == 3 and calls[2][0] == "hyprctl", calls
        if "STALL_SELECTION" in flags:
            assert elapsed < 0.8, elapsed
print("Capture fast path, cold recovery, first mapping, exact text and stalled-selection deadline passed")
