const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const list = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../NoteList.js`, 'utf8').replace(/^\.pragma library\n/, ''), list);
const notes = names => names.map(name => ({ name }));
const names = rows => Array.from(rows, row => row.name);

test('empty query keeps every note in order', () => {
    assert.deepEqual(names(list.filter(notes(['Global', 'b', 'a']), '  ')), ['Global', 'b', 'a']);
});
test('search matches titles case-insensitively and needs every term', () => {
    const all = notes(['Deploy notes', 'Bug triage', 'notes on bugs', 'Groceries']);
    assert.deepEqual(names(list.filter(all, 'BUG')), ['Bug triage', 'notes on bugs']);
    assert.deepEqual(names(list.filter(all, 'notes bug')), ['notes on bugs']);
    assert.deepEqual(names(list.filter(all, 'zzz')), []);
});
test('search keeps the list order instead of ranking titles', () => {
    const all = notes(['debugging', 'my bug list', 'bug list']);
    assert.deepEqual(names(list.filter(all, 'bug')), ['debugging', 'my bug list', 'bug list']);
});
test('order puts Global, then pinned, then the rest, newest edit first', () => {
    const all = [
        { name: 'old', updated: 1 }, { name: 'pinned old', pinned: true, updated: 2 },
        { name: 'new', updated: 9 }, { name: 'Global', global: true, pinned: true, updated: 0 },
        { name: 'pinned new', pinned: true, updated: 5 }, { name: 'legacy a' }, { name: 'legacy b' },
    ];
    assert.deepEqual(names(list.order(all)), ['Global', 'pinned new', 'pinned old', 'new', 'old', 'legacy a', 'legacy b']);
});
test('pages hold twenty notes and clamp at the ends', () => {
    const rows = Array.from({ length: 45 }, (_, i) => i);
    assert.equal(list.pageCount(45), 3);
    assert.equal(list.pageCount(0), 1);
    assert.deepEqual(Array.from(list.visible(rows, false, 1, 0)), rows.slice(20, 40));
    assert.deepEqual(Array.from(list.visible(rows, false, 9, 0)), rows.slice(40));
    assert.equal(list.clampPage(-1, 45), 0);
});
test('scroll mode shows the loaded prefix, at least one page', () => {
    const rows = Array.from({ length: 45 }, (_, i) => i);
    assert.equal(list.visible(rows, true, 2, 0).length, 20);
    assert.equal(list.visible(rows, true, 0, 40).length, 40);
    assert.equal(list.visible(rows, true, 0, 60).length, 45);
});
test('snippet is the first nonblank line', () => {
    assert.equal(list.snippet('\n  \n  first line \nsecond'), 'first line');
    assert.equal(list.snippet(''), '');
    assert.equal(list.snippet('```scribblesvg\n{"version":1}\n```'), 'Diagram');
});
