const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
function library(file) {
    const context = vm.createContext({});
    vm.runInContext(fs.readFileSync(`${__dirname}/../${file}`, 'utf8').replace(/^\.pragma library\n/, ''), context);
    return context;
}
const { highlight } = library('SyntaxHighlight.js');
const { parse } = library('MarkdownBlocks.js');
const colors = { keyword: '#111111', string: '#222222', number: '#333333', comment: '#444444', literal: '#555555' };
const span = (role, value) => `<span style="color:${colors[role]}">${value}</span>`;

test('highlights tokens without parsing strings as comments or markup', () => {
    const html = highlight('const x = "<b>// &"; // comment\nreturn 42;', 'js', colors);
    assert.ok(html.includes(span('keyword', 'const')));
    assert.ok(html.includes(span('string', '&quot;&lt;b&gt;// &amp;&quot;')));
    assert.ok(html.includes(span('comment', '// comment')));
    assert.ok(html.includes(span('number', '42')));
});
test('uses language-appropriate comments and literals', () => {
    const html = highlight('x = 4 // 2; s = "ok" # comment\nreturn None', 'python', colors);
    assert.ok(html.includes(span('string', '&quot;ok&quot;')));
    assert.ok(html.includes(span('comment', '# comment')));
    assert.ok(html.includes(span('literal', 'None')));
    assert.ok(highlight('echo "ok" # comment', 'bash', colors).includes(span('keyword', 'echo')));
    assert.ok(highlight('{"ok": true}', 'json', colors).includes(span('literal', 'true')));
});
test('preserves whitespace and escapes unsupported languages', () => {
    assert.equal(highlight('  <tag>\n\t&\n', 'unknown', colors), '<pre style="margin:0">  &lt;tag&gt;<br>\t&amp;<br></pre>');
});
test('keeps raw fenced source and language for copying and highlighting', () => {
    const blocks = parse('Text\n\n```js\n  const x = "<b>";\n\n```\nAfter');
    assert.equal(blocks.length, 3);
    assert.equal(blocks[1].language, 'js');
    assert.equal(blocks[1].text, '  const x = "<b>";\n');
});
