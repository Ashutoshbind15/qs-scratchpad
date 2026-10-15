.pragma library

// Leave prose rendering to Qt; give top-level fenced code its own viewport.
function parse(source) {
    const lines = source.split(/\r?\n/);
    const blocks = [];
    let prose = [];
    function flush() {
        if (prose.join("\n").trim())
            blocks.push({ code: false, text: prose.join("\n"), language: "" });
        prose = [];
    }
    for (let i = 0; i < lines.length; i++) {
        const open = /^( {0,3})(`{3,}|~{3,})([^]*)$/.exec(lines[i]);
        if (!open || (open[2][0] === "`" && open[3].indexOf("`") >= 0)) {
            prose.push(lines[i]);
            continue;
        }
        flush();
        const close = new RegExp("^ {0,3}" + open[2][0] + "{" + open[2].length + ",}[ \\t]*$");
        const code = [];
        for (++i; i < lines.length && !close.test(lines[i]); i++) {
            // CommonMark removes up to the opening fence's indentation.
            code.push(lines[i].replace(new RegExp("^ {0," + open[1].length + "}"), ""));
        }
        blocks.push({ code: true, text: code.join("\n"), language: open[3].trim().split(/\s+/)[0] || "Code" });
    }
    flush();
    return blocks;
}
