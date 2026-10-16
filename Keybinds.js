.pragma library

// Shortcuts listed in the help overlay, grouped by what they act on. Ctrl+key
// acts on the note and Ctrl+Shift+key does the same to the current point
// (Ctrl+N / Ctrl+Shift+N, Ctrl+W / Ctrl+Shift+W). Alt moves between points.
// `sequences` use Qt's syntax and must match the Shortcut items in shell.qml;
// `action` is run by root.runBinding().
var entries = [
    { section: "Notes", action: "newNote", label: "New note", sequences: ["Ctrl+N"], keywords: "create add scratchpad" },
    { section: "Notes", action: "deleteNote", label: "Delete note", sequences: ["Ctrl+W"], keywords: "remove close scratchpad" },
    { section: "Notes", action: "toggleSidebar", label: "Show or hide note list", sequences: ["Ctrl+B"], keywords: "toggle sidebar" },

    { section: "Points", action: "addPoint", label: "New point", sequences: ["Ctrl+Shift+N", "Ctrl+Return"], keywords: "create add" },
    { section: "Points", action: "deletePoint", label: "Delete point", sequences: ["Ctrl+Shift+W"], keywords: "remove clear" },
    { section: "Points", action: "previousPoint", label: "Previous point", sequences: ["Alt+Up"], keywords: "focus go navigate" },
    { section: "Points", action: "nextPoint", label: "Next point", sequences: ["Alt+Down"], keywords: "focus go navigate" },
    { section: "Points", action: "movePointUp", label: "Move point up", sequences: ["Alt+Shift+Up"], keywords: "reorder" },
    { section: "Points", action: "movePointDown", label: "Move point down", sequences: ["Alt+Shift+Down"], keywords: "reorder" },
    { section: "Points", action: "copy", label: "Copy points for agents", sequences: ["Ctrl+Shift+C"], keywords: "clipboard markdown list export" },
    { section: "Points", action: "preview", label: "Preview points as Markdown", sequences: ["Ctrl+Shift+M"], keywords: "toggle edit render view" },

    { section: "Window", action: "hide", label: "Hide scratchpad", sequences: ["Escape"], keywords: "close dismiss" },
    { section: "Window", action: "help", label: "Keyboard shortcuts", sequences: ["F1", "Ctrl+/"], keywords: "help keybinds keybindings search" },

    { section: "Anywhere", action: "hide", label: "Show or hide scratchpad", sequences: ["Super+N"], keywords: "toggle open global" },
    { section: "Anywhere", action: "capture", label: "Capture to Global", sequences: ["Super+A"], keywords: "selection primary add point" }
];

// Omarchy's notation: "SUPER SHIFT + F".
function formatSequence(sequence) {
    var parts = String(sequence).split("+");
    var key = parts.pop();
    var name = key === "Return" ? "ENTER" : key.toUpperCase();
    return parts.length ? parts.join(" ").toUpperCase() + " + " + name : name;
}

function keysText(entry) {
    return entry.sequences.map(formatSequence).join("  /  ");
}

// Matching and ranking follow Omarchy's AppSearch.js: every term must appear
// in the label, keys, or keywords (or the label's acronym); then exact
// prefixes beat substrings, which beat keyword and acronym matches.
// Keys are searched without "+", so "ctrl shift c" finds CTRL SHIFT + C.
function plainKeys(text) {
    return String(text).toLowerCase().replace(/\s*\+\s*/g, " ").replace(/\s+/g, " ").trim();
}

function searchText(entry) {
    return [entry.label.toLowerCase(), plainKeys(keysText(entry)), (entry.keywords || "").toLowerCase()].join(" ");
}

function acronym(entry) {
    return entry.label.toLowerCase().split(/[^a-z0-9]+/)
        .filter(function(word) { return word.length; })
        .map(function(word) { return word.charAt(0); }).join("");
}

function termMatches(entry, term) {
    if (searchText(entry).indexOf(term) >= 0) return true;
    return term.length <= 5 && acronym(entry).indexOf(term) >= 0;
}

function score(entry, query) {
    var q = plainKeys(query || "");
    if (!q) return 0;
    var terms = q.split(/\s+/);
    for (var i = 0; i < terms.length; i++)
        if (!termMatches(entry, terms[i])) return -1;

    var label = entry.label.toLowerCase();
    var keys = plainKeys(keysText(entry));
    var labelIndex = label.indexOf(q);
    var keysIndex = keys.indexOf(q);
    if (labelIndex === 0) return 10000 - label.length;
    if (keysIndex === 0) return 9500 - keys.length;
    if (labelIndex > 0) return 8000 - labelIndex * 10 - label.length;
    if (keysIndex > 0) return 7600 - keysIndex * 10 - keys.length;
    var hayIndex = searchText(entry).indexOf(q);
    if (hayIndex >= 0) return 6000 - hayIndex;
    var acronymIndex = acronym(entry).indexOf(q);
    if (acronymIndex === 0) return 5000 - label.length;
    if (acronymIndex > 0) return 4600 - acronymIndex * 10 - label.length;
    return 4000 - label.length;
}

// Entries matching `query`, grouped by section. Sections are ordered by their
// best match, but entries keep their listed order so pairs stay together;
// bestIndex() picks the row to select.
function filter(query) {
    var sections = [];
    var bySection = {};
    for (var i = 0; i < entries.length; i++) {
        var entry = entries[i];
        var value = score(entry, query);
        if (value < 0) continue;
        var group = bySection[entry.section];
        if (!group) {
            group = bySection[entry.section] = { best: value, order: sections.length, rows: [] };
            sections.push(group);
        }
        group.best = Math.max(group.best, value);
        group.rows.push({ section: entry.section, action: entry.action, label: entry.label, keys: keysText(entry), score: value });
    }
    sections.sort(function(a, b) { return b.best - a.best || a.order - b.order; });
    var rows = [];
    for (var j = 0; j < sections.length; j++) rows = rows.concat(sections[j].rows);
    return rows;
}

function bestIndex(rows) {
    var best = 0;
    for (var i = 1; i < rows.length; i++) if (rows[i].score > rows[best].score) best = i;
    return best;
}
