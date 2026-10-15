"""Check selection transport without changing the desktop or clipboard."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="scratchpad-capture-") as folder:
    temp = Path(folder)
    shutil.copy(repo / "capture", temp / "capture")
    helper = '''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
name = Path(sys.argv[0]).name
with open(os.environ["CALL_LOG"], "a") as log:
    log.write(json.dumps([name, *sys.argv[1:]]) + "\\n")
if name == "wl-paste":
    if os.environ.get("NO_SELECTION"):
        sys.exit(1)
    sys.stdout.write(os.environ["SELECTION"])
'''
    for name in ("wl-paste", "toggle", "quickshell", "hyprctl"):
        path = temp / name
        path.write_text(helper)
        path.chmod(0o755)
    for selection, absent in [("--selected ‘text’\n\n", False), ("", True)]:
        log = temp / "calls.jsonl"
        log.write_text("")
        env = {**os.environ, "PATH": f"{temp}:{os.environ['PATH']}",
               "CALL_LOG": str(log), "SELECTION": selection}
        if absent:
            env["NO_SELECTION"] = "1"
        subprocess.run([str(temp / "capture")], env=env, check=True, timeout=5)
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        assert calls[0] == ["wl-paste", "--primary", "--type", "text", "--no-newline"], calls
        assert calls[1] == ["toggle", "start"], calls
        assert calls[2] == ["quickshell", "ipc", "-p", str(temp), "call", "--", "scratchpad", "capture", selection], calls
        assert calls[3][0] == "hyprctl", calls
print("Selection read before focus change; exact multiline text and no-selection fallback passed")
