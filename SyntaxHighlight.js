.pragma library

function escapeHtml(text) {
    return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
               .replace(/"/g, "&quot;");
}

// Explicit breaks preserve leading and trailing blank lines in Qt rich text.
function preformatted(html) {
    return '<pre style="margin:0">' + html.replace(/\n/g, "<br>") + "</pre>";
}

// Small, dependency-free lexer. Unsupported fence languages stay plain text.
function highlight(source, language, colors) {
    const lang = language.toLowerCase();
    const python = /^(py|python)$/.test(lang);
    const shell = /^(sh|bash|zsh|shell)$/.test(lang);
    const yaml = /^(yaml|yml|toml|ini)$/.test(lang);
    const cStyle = /^(js|javascript|jsx|ts|typescript|tsx|qml|json|jsonc|c|cpp|c\+\+|h|hpp|cs|csharp|java|go|rust|rs|css)$/.test(lang);
    if (!python && !shell && !yaml && !cStyle)
        return preformatted(escapeHtml(source));
    const keywords = /^(?:async|await|break|case|catch|class|const|continue|def|del|do|elif|else|enum|except|export|extends|finally|fn|for|from|func|function|if|impl|import|in|interface|let|match|namespace|new|of|package|pass|private|property|public|raise|readonly|required|return|self|static|struct|super|switch|throw|trait|try|type|typeof|using|var|void|while|with|yield|and|as|assert|not|or|then|fi|done|echo|local|esac|select|until)$/;
    // Match against raw source once; HTML escaping happens only after tokenization.
    const comments = cStyle ? /\/\*[\s\S]*?(?:\*\/|$)|\/\/[^\n]*/ : /#[^\n]*/;
    const tokens = /"""[\s\S]*?(?:"""|$)|'''[\s\S]*?(?:'''|$)|"(?:\\[\s\S]|[^"\\])*"?|'(?:\\[\s\S]|[^'\\])*'?|`(?:\\[\s\S]|[^`\\])*`?|\b(?:0[xX][\da-fA-F]+|\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)\b|\b[A-Za-z_$][\w$]*\b/;
    const lexer = new RegExp(comments.source + "|" + tokens.source, "g");
    let result = "", end = 0, match;
    while ((match = lexer.exec(source)) !== null) {
        result += escapeHtml(source.slice(end, match.index));
        const value = match[0];
        let role = "";
        if (/^["'`]/.test(value)) role = "string";
        else if ((value[0] === "#" && (python || shell || yaml))
                 || (cStyle && /^(\/\/|\/\*)/.test(value))) role = "comment";
        else if (/^\d/.test(value)) role = "number";
        else if (/^(true|false|null|undefined|None|True|False|nil)$/.test(value)) role = "literal";
        else if (keywords.test(value) && !/^(json|jsonc|css)$/.test(lang)) role = "keyword";
        const escaped = escapeHtml(value);
        result += role ? '<span style="color:' + escapeHtml(String(colors[role])) + '">' + escaped + '</span>' : escaped;
        end = lexer.lastIndex;
    }
    return preformatted(result + escapeHtml(source.slice(end)));
}
