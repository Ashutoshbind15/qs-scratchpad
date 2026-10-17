const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const keybinds = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../Keybinds.js`, 'utf8').replace(/^\.pragma library\n/, ''), keybinds);
const labels = query => Array.from(keybinds.filter(query), row => row.label);
const best = query => { const rows = keybinds.filter(query); return rows[keybinds.bestIndex(rows)].label; };

test('keys use Omarchy notation', () => {
    assert.equal(keybinds.formatSequence('Ctrl+Shift+C'), 'CTRL SHIFT + C');
    assert.equal(keybinds.formatSequence('Ctrl+Return'), 'CTRL + ENTER');
    assert.equal(keybinds.formatSequence('Ctrl+/'), 'CTRL + /');
    assert.equal(keybinds.formatSequence('Escape'), 'ESCAPE');
});
test('empty query lists every shortcut in order', () => {
    assert.equal(JSON.stringify(labels('  ')), JSON.stringify(Array.from(keybinds.entries, entry => entry.label)));
    assert.equal(best(''), 'New note');
});
test('sections stay contiguous and paired shortcuts stay adjacent', () => {
    for (const query of ['', 'point', 'delete', 'ctrl', 'up']) {
        const sections = Array.from(keybinds.filter(query), row => row.section);
        assert.equal(new Set(sections).size, sections.filter((s, i) => s !== sections[i - 1]).length, query);
    }
    assert.equal(JSON.stringify(labels('delete')), JSON.stringify(['Delete note', 'Delete point']));
    const points = labels('point');
    assert.equal(points.indexOf('Next point'), points.indexOf('Previous point') + 1);
    assert.equal(points.indexOf('Move point down'), points.indexOf('Move point up') + 1);
});
test('search ranks label prefixes first and requires every term', () => {
    assert.equal(best('copy'), 'Copy points for agents');
    assert.equal(best('del'), 'Delete note');
    assert.deepEqual(labels('preview'), []);
    assert.deepEqual(labels('delete point'), ['Delete point']);
    assert.deepEqual(labels('point zzz'), []);
});
test('search matches keys, keywords, and acronyms', () => {
    assert.equal(best('ctrl shift c'), 'Copy points for agents');
    assert.equal(best('alt shift'), 'Move point up');
    assert.ok(labels('clipboard').includes('Copy points for agents'));
    assert.equal(best('mpd'), 'Move point down');
    assert.equal(best('super a'), 'Capture to Global');
});
test('point shortcuts add Shift to the matching note shortcut', () => {
    const keys = action => keybinds.entries.find(entry => entry.action === action).sequences[0];
    assert.equal(keys('addPoint'), keys('newNote').replace('Ctrl+', 'Ctrl+Shift+'));
    assert.equal(keys('deletePoint'), keys('deleteNote').replace('Ctrl+', 'Ctrl+Shift+'));
});
test('every listed shortcut is bound', () => {
    const shell = fs.readFileSync(`${__dirname}/../shell.qml`, 'utf8');
    const lua = fs.readFileSync(`${__dirname}/../omarchy.lua`, 'utf8');
    for (const entry of keybinds.entries) for (const sequence of entry.sequences) {
        if (sequence.startsWith('Super+')) assert.ok(lua.includes(`"SUPER + ${sequence.slice(6)}"`), sequence);
        else assert.ok(shell.includes(`"${sequence}"`), sequence);
    }
});
