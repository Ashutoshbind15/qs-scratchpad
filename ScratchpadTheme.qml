import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: theme
    property var values: ({})
    readonly property string home: Quickshell.env("HOME")
    property bool legacyPath: false
    readonly property color background: pick("background", "#181c24")
    readonly property color foreground: pick("foreground", "#eef0f6")
    readonly property color surface: pick("lighter_background", blend(background, foreground, 0.04))
    readonly property color codeBackground: pick("dark_background", blend(background, foreground, 0.02))
    readonly property color accent: pick("accent", pick("color4", "#9eb6e0"))
    readonly property color selection: pick("selection", blend(background, accent, 0.35))
    readonly property color muted: blend(background, foreground, 0.65)
    readonly property color border: blend(background, foreground, 0.2)
    readonly property color hover: blend(background, accent, 0.18)
    readonly property color danger: pick("red", pick("color1", "#f7768e"))
    readonly property color dangerBackground: blend(background, danger, 0.3)
    readonly property var syntax: ({
        keyword: pick("magenta", pick("color5", "#bb9af7")),
        string: pick("green", pick("color2", "#9ece6a")),
        number: pick("orange", pick("color3", "#e0af68")),
        comment: String(muted),
        literal: pick("cyan", pick("color6", "#7dcfff"))
    })

    function pick(key, fallback) { return values[key] || fallback; }
    function blend(base, tint, amount) {
        const a = Qt.color(base), b = Qt.color(tint);
        return Qt.rgba(a.r * (1 - amount) + b.r * amount,
                       a.g * (1 - amount) + b.g * amount,
                       a.b * (1 - amount) + b.b * amount, 1);
    }
    function load(raw) {
        const next = {};
        for (const line of raw.split("\n")) {
            const match = /^\s*([\w-]+)\s*=\s*["'](#[\da-fA-F]{6})["']/.exec(line);
            if (match) next[match[1]] = match[2];
        }
        if (JSON.stringify(next) !== JSON.stringify(values)) values = next;
    }

    FileView {
        id: palette
        path: Quickshell.env("SCRATCHPAD_THEME_FILE") || (theme.legacyPath
              ? (Quickshell.env("XDG_CONFIG_HOME") || theme.home + "/.config") + "/omarchy/current/theme/colors.toml"
              : theme.home + "/.local/state/omarchy/current/theme/colors.toml")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: theme.load(text())
        onLoadFailed: {
            theme.values = ({});
            if (!theme.legacyPath && !Quickshell.env("SCRATCHPAD_THEME_FILE")) theme.legacyPath = true;
        }
    }
    // Theme switches can replace the entire directory, invalidating file watches.
    Timer { interval: 2000; running: true; repeat: true; onTriggered: palette.reload() }
}
