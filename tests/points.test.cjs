const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const points = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../ScratchpadPoints.js`, 'utf8').replace(/^\.pragma library\n/, ''), points);

test('legacy notes remain one intact point', () => {
    const text = 'Title\n\n1. Existing list\n2. More\n\n```js\nconst a = 1;\n```';
    assert.equal(JSON.stringify(points.readPoints({ text }, 1)), JSON.stringify([text]));
});
test('version two preserves point boundaries, blanks, and whitespace', () => {
    const entries = ['Title', '', '  indented\n\nlast line\n'];
    assert.equal(JSON.stringify(points.readPoints({ points: entries }, 2)), JSON.stringify(entries));
    assert.throws(() => points.readPoints({ points: ['okay', 4] }, 2));
    assert.throws(() => points.readPoints({ text: 'legacy' }, 2));
});
test('agent export numbers nonblank points and nests multiline Markdown', () => {
    assert.equal(points.forAgents(['Do this\n\n```js\n  run();\n```', '  ', 'Next\r\n- detail']),
        '1. Do this\n   \n   ```js\n     run();\n   ```\n\n2. Next\n   - detail');
    const entries = Array.from({ length: 11 }, (_, i) => `Point ${i}\ncontinued`);
    assert.ok(points.forAgents(entries).includes('10. Point 9\n    continued'));
    assert.equal(points.forAgents(['', '  ']), '');
});
test('title follows the first nonblank point', () => {
    assert.equal(points.title(['', '  My title\nbody', 'Other']), 'My title');
    assert.equal(points.title(['', ' ']), 'Untitled');
});
