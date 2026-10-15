.pragma library

function readPoints(pad, version) {
    if (version === 1) {
        if (typeof pad.text !== "string") throw new Error("Invalid scratchpad text");
        return [pad.text];
    }
    if (!Array.isArray(pad.points) || !pad.points.every(p => typeof p === "string"))
        throw new Error("Invalid scratchpad points");
    return pad.points.length ? pad.points : [""];
}

function combined(points) { return points.join("\n\n"); }
function title(points) {
    const first = points.find(p => p.trim().length > 0) || "";
    return first.split("\n")[0].trim() || "Untitled";
}
function forAgents(points) {
    return points.filter(p => p.trim().length > 0).map((point, index) => {
        const prefix = (index + 1) + ". ";
        const indent = " ".repeat(prefix.length);
        return prefix + point.replace(/\r\n/g, "\n").split("\n").join("\n" + indent);
    }).join("\n\n");
}
