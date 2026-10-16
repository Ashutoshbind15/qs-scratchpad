const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
function library(file, imports = {}) {
    const context = vm.createContext({ ...imports });
    const source = fs.readFileSync(`${__dirname}/../${file}`, 'utf8')
        .replace(/^\.pragma library\n/, '')
        .replace(/^\.import .*\n/gm, '');
    vm.runInContext(source, context);
    return context;
}
const store = library('NoteStore.js', { Points: library('ScratchpadPoints.js') });
const names = parsed => Array.from(parsed.notes, note => note.name);

test('orders Global, then pinned, then the rest, and keeps the active note', () => {
    const parsed = store.parse(JSON.stringify({ version: 3, activeIndex: 2, pads: [
        { name: 'Plain', points: ['a'] },
        { name: 'Pinned', points: ['b'], pinned: true },
        { name: 'Global', points: [''], global: true },
    ] }));
    assert.deepEqual(names(parsed), ['Global', 'Pinned', 'Plain']);
    assert.equal(parsed.activeIndex, 0);
    assert.equal(parsed.notes[0].pinned, true);
});
test('adds an empty Global to stores without one and drops empty notes', () => {
    const parsed = store.parse(JSON.stringify({ version: 3, activeIndex: 1, pads: [
        { name: '', points: ['  '] },
        { name: 'Kept', points: ['text'] },
        { name: 'Title only', points: [''] },
    ] }));
    assert.deepEqual(names(parsed), ['Global', 'Kept', 'Title only']);
    assert.equal(parsed.activeIndex, 1);
    assert.equal(parsed.notes[0].updated, 0);
});
test('older versions take their title from the first point', () => {
    const parsed = store.parse(JSON.stringify({ version: 1, pads: [
        { name: 'Ignored', text: 'First line\nbody' },
        { name: 'Empty title-only', text: '' },
    ] }));
    assert.deepEqual(names(parsed), ['Global', 'First line']);
});
test('rejects malformed stores instead of overwriting them', () => {
    assert.throws(() => store.parse('{"version": 9, "pads": []}'));
    assert.throws(() => store.parse('{"version": 3, "pads": [{"name": 4, "points": []}]}'));
    assert.throws(() => store.parse(JSON.stringify({ version: 3, pads: [
        { name: 'Global', points: [''], global: true },
        { name: 'Global', points: [''], global: true },
    ] })));
});
test('reads view settings with safe defaults', () => {
    const defaults = store.parse('{"version": 3, "pads": []}').settings;
    assert.deepEqual({ ...defaults }, { browseScroll: false, pointControls: true, zen: false, shortWindow: false, fontSize: null });
    const saved = store.parse('{"version": 3, "pads": [], "browseMode": "scroll", "pointControls": false, "zen": true, "shortWindow": true, "fontSize": 20}').settings;
    assert.deepEqual({ ...saved }, { browseScroll: true, pointControls: false, zen: true, shortWindow: true, fontSize: 20 });
});
test('serialize round-trips through parse and skips fully empty notes', () => {
    const notes = [store.globalNote(), { ...store.newNote(''), updated: 5 }, { ...store.newNote('Kept'), text: 'x', pointsJson: '["x"]', updated: 7 }];
    const raw = store.serialize(notes, { activeIndex: 2, browseScroll: true, fontSize: 18, pointControls: true, zen: false, shortWindow: false });
    const saved = JSON.parse(raw);
    assert.equal(saved.version, store.CURRENT_VERSION);
    assert.deepEqual(saved.pads.map(pad => pad.name), ['Global', 'Kept']);
    assert.equal(saved.activeIndex, 1);
    assert.equal(saved.browseMode, 'scroll');
    const reloaded = store.parse(raw);
    assert.deepEqual(names(reloaded), ['Global', 'Kept']);
    assert.equal(reloaded.activeIndex, 1);
    assert.equal(reloaded.notes[1].updated, 7);
});
