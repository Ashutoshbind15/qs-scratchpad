.pragma library

// The note browser: a linear list of notes filtered by title, shown either
// one page at a time or as an infinite scroll that loads a page at a time.
var pageSize = 20;

// Rank of `title` for `query`, or -1 when some term is missing. Every term
// must appear in the title; then a title prefix beats a word prefix, which
// beats a match inside a word. Ties keep the list order.
function score(title, query) {
    var q = String(query || "").toLowerCase().trim();
    if (!q) return 0;
    var t = String(title).toLowerCase();
    var terms = q.split(/\s+/);
    for (var i = 0; i < terms.length; i++)
        if (t.indexOf(terms[i]) < 0) return -1;
    if (t.indexOf(q) === 0) return 3;
    if ((" " + t.replace(/[^a-z0-9]+/g, " ")).indexOf(" " + terms[0]) >= 0) return 2;
    return 1;
}

// `notes` is [{ name, ... }] in display order; returns the matching notes.
function filter(notes, query) {
    var matches = [];
    for (var i = 0; i < notes.length; i++) {
        var value = score(notes[i].name, query);
        if (value >= 0) matches.push({ note: notes[i], score: value, order: i });
    }
    matches.sort(function(a, b) { return b.score - a.score || a.order - b.order; });
    return matches.map(function(match) { return match.note; });
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
        if (line) return line;
    }
    return "";
}
