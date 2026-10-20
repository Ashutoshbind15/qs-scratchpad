.pragma library

// The note browser: a linear list of notes filtered by title, shown either
// one page at a time or as an infinite scroll that loads a page at a time.
var pageSize = 20;

// Global first, then pinned notes, then the rest; within each group the most
// recently edited note comes first. Equal timestamps keep the given order.
function order(notes) {
    function group(note) { return note.global ? 0 : note.pinned ? 1 : 2; }
    return notes.map(function(note, i) { return { note: note, order: i }; })
        .sort(function(a, b) {
            return group(a.note) - group(b.note) || (b.note.updated || 0) - (a.note.updated || 0) || a.order - b.order;
        })
        .map(function(entry) { return entry.note; });
}

// True when every term of `query` appears in `title`, ignoring case.
function matches(title, query) {
    var q = String(query || "").toLowerCase().trim();
    if (!q) return true;
    var t = String(title).toLowerCase();
    var terms = q.split(/\s+/);
    for (var i = 0; i < terms.length; i++)
        if (t.indexOf(terms[i]) < 0) return false;
    return true;
}

// `notes` is [{ name, ... }] in display order; returns the matching notes,
// keeping that order so search results stay newest first.
function filter(notes, query) {
    return notes.filter(function(note) { return matches(note.name, query); });
}

function pageCount(total) {
    return Math.max(1, Math.ceil(total / pageSize));
}

function clampPage(page, total) {
    return Math.max(0, Math.min(page, pageCount(total) - 1));
}

// The rows on screen: one page, or the first `loaded` rows when scrolling.
function visible(rows, scroll, page, loaded) {
    if (scroll) return rows.slice(0, Math.max(pageSize, loaded));
    var start = clampPage(page, rows.length) * pageSize;
    return rows.slice(start, start + pageSize);
}

// First nonblank line of a note's points, shown under its title.
function snippet(text) {
    var lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line === "```scribblesvg") return "Diagram";
        if (line) return line;
    }
    return "";
}
