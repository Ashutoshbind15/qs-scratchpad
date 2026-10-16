.pragma library
.import "ScratchpadPoints.js" as Points

// The notes file (scratchpads.json). Versions 1 and 2 are still read; saves
// always write CURRENT_VERSION.
//
// In memory each note is a ListModel row:
//   { name, text, pointsJson, pinned, global, updated }
// `text` is every point joined (for snippets and blank checks), `pointsJson`
// is the points array, and `updated` is the last edit in ms since the epoch.
var CURRENT_VERSION = 3;
var SUPPORTED_VERSIONS = [1, 2, 3];
var GLOBAL_NAME = "Global";
var UNTITLED_NAME = "Untitled";
var EMPTY_POINTS_JSON = JSON.stringify([""]);

function newNote(name) {
    return { name: name, text: "", pointsJson: EMPTY_POINTS_JSON, pinned: false, global: false, updated: Date.now() };
}

// The permanent capture target. It sorts first and counts as never edited.
function globalNote() {
    return { name: GLOBAL_NAME, text: "", pointsJson: EMPTY_POINTS_JSON, pinned: true, global: true, updated: 0 };
}

function isOptionalBoolean(value) {
    return value === undefined || typeof value === "boolean";
}

// One stored note as a row, or null for an empty note that should be dropped.
function readNote(stored, version) {
    if (typeof stored.name !== "string" || !isOptionalBoolean(stored.pinned) || !isOptionalBoolean(stored.global))
        throw new Error("Invalid scratchpad data");

    const points = Points.readPoints(stored, version);
    const text = Points.combined(points);
    const global = stored.global === true;
    // Before version 3 the name was derived from the text, so it can't keep
    // an otherwise empty note alive.
    if (!global && Points.isBlank(text) && (version < 3 || Points.isBlank(stored.name)))
        return null;

    return {
        name: global ? GLOBAL_NAME : version === 3 ? stored.name : Points.title(points),
        text: text,
        pointsJson: JSON.stringify(points),
        pinned: global || stored.pinned === true,
        global: global,
        updated: Number.isFinite(stored.updated) ? stored.updated : 0
    };
}

// Parses the notes file into rows ordered Global, pinned, then the rest, plus
// the saved view settings. Throws on malformed data so nothing is overwritten.
function parse(raw) {
    const data = JSON.parse(raw);
    if (SUPPORTED_VERSIONS.indexOf(data.version) < 0 || !Array.isArray(data.pads))
        throw new Error("Invalid scratchpad data");

    const globals = [];
    const pinned = [];
    const rest = [];
    let active = null;
    for (let i = 0; i < data.pads.length; i++) {
        const note = readNote(data.pads[i], data.version);
        if (!note) continue;
        if (i === data.activeIndex) active = note;
        if (note.global) globals.push(note);
        else if (note.pinned) pinned.push(note);
        else rest.push(note);
    }
    if (globals.length > 1) throw new Error("Multiple global containers");
    if (!globals.length) globals.push(globalNote());

    const notes = globals.concat(pinned, rest);
    return {
        notes: notes,
        activeIndex: Math.max(0, notes.indexOf(active)),
        settings: {
            browseScroll: data.browseMode === "scroll",
            pointControls: data.pointControls !== false,
            zen: data.zen === true,
            shortWindow: data.shortWindow === true,
            fontSize: Number.isInteger(data.fontSize) ? data.fontSize : null
        }
    };
}

// `notes` are rows in display order; notes with an empty title and empty
// points are left out. `state` carries the active row and view settings.
function serialize(notes, state) {
    const pads = [];
    let activeIndex = 0;
    for (let i = 0; i < notes.length; i++) {
        const note = notes[i];
        if (Points.isBlank(note.text) && Points.isBlank(note.name)) continue;
        if (i === state.activeIndex) activeIndex = pads.length;
        pads.push({
            name: note.name,
            points: JSON.parse(note.pointsJson),
            pinned: !!note.pinned,
            global: !!note.global,
            updated: note.updated
        });
    }

    return JSON.stringify({
        version: CURRENT_VERSION,
        activeIndex: activeIndex,
        browseMode: state.browseScroll ? "scroll" : "pages",
        fontSize: state.fontSize,
        pointControls: state.pointControls,
        zen: state.zen,
        shortWindow: state.shortWindow,
        pads: pads
    }, null, 2);
}
