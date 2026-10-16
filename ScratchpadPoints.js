.pragma library

function isBlank(text) {
    return text.trim().length === 0;
}

// Points as stored on disk. Version 1 kept a single `text` per note; later
// versions keep a `points` array, which is never empty in memory.
function readPoints(pad, version) {
    if (version === 1) {
        if (typeof pad.text !== "string") throw new Error("Invalid scratchpad text");
        return [pad.text];
    }
    if (!Array.isArray(pad.points) || !pad.points.every(p => typeof p === "string"))
        throw new Error("Invalid scratchpad points");
    return pad.points.length ? pad.points : [""];
}

function combined(points) {
    return points.join("\n\n");
}

// First line of the first nonblank point; used to title pre-version-3 notes.
function title(points) {
    const first = points.find(p => !isBlank(p)) || "";
    return first.split("\n")[0].trim() || "Untitled";
}

// Nonblank points as a numbered Markdown list. Continuation lines are indented
// under their number so multiline points stay one list item.
function forAgents(points) {
    return points.filter(p => !isBlank(p)).map((point, index) => {
        const prefix = (index + 1) + ". ";
        const indent = " ".repeat(prefix.length);
        return prefix + point.replace(/\r\n/g, "\n").split("\n").join("\n" + indent);
    }).join("\n\n");
}
