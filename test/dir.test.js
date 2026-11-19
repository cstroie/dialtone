'use strict';
// The example directories are real lists the programs can read: TERM shows at most
// 16 entries, each in a column of 38 characters; IRC and MUD list 16, a line of 76; GOPHER
// and NEWS make their home menus of them (an address, then a name of 70 at most); FINGER lists 16.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const lines = f => fs.readFileSync(path.join(__dirname, '..', f), 'latin1').split('\n').filter(Boolean);

test('TERM.DIR: entries a dial string and a name, each fits its column', () => {
    const l = lines('TERM.DIR');
    assert.ok(l.length >= 5 && l.length <= 16, `${l.length} entries`);
    for (const e of l) { assert.ok(e.length <= 37, e); assert.match(e, /^\S{1,24}( .+)?$/, e); }
});

test('IRC.DIR: host:port and a name, a plain port', () => {
    const l = lines('IRC.DIR');
    assert.ok(l.length >= 5 && l.length <= 16, `${l.length} entries`);
    for (const e of l) { assert.ok(e.length <= 76, e); assert.match(e, /^[a-z0-9.-]+:66(6\d|60) \S/, e); }
});

test('GOPHER.DIR: host[:port][/type/selector] and a name', () => {
    const l = lines('GOPHER.DIR');
    assert.ok(l.length >= 3 && l.length <= 40, `${l.length} entries`);
    for (const e of l) { assert.match(e, /^[a-z0-9.-]+(:\d+)?(\/[017]\S*)? \S/, e); assert.ok(e.length - e.indexOf(' ') - 1 <= 70, e); }
});

test('MUD.DIR: host:port and a name; no port the bridge passes raw (a MUD wants telnet)', () => {
    const l = lines('MUD.DIR');
    assert.ok(l.length >= 3 && l.length <= 16, `${l.length} entries`);
    for (const e of l) {
        assert.ok(e.length <= 76, e);
        const m = /^[a-z0-9.-]+:(\d+) \S/.exec(e);
        assert.ok(m, e);
        assert.ok(![13, 37, 70, 79, 119, 563].includes(+m[1]) && !(+m[1] >= 6660 && +m[1] <= 6669), e);
    }
});

test('FINGER.DIR: user@host or @host (host[:port]) and a name; 16 at most, a line of 76', () => {
    const l = lines('FINGER.DIR');
    assert.ok(l.length >= 3 && l.length <= 16, `${l.length} entries`);
    for (const e of l) { assert.ok(e.length <= 74, e); assert.match(e, /^[^\s@]*@[a-z0-9.-]+(:\d+)? \S/, e); }
});

test('GEMINI.DIR: a gemini:// address and a name', () => {
    const l = lines('GEMINI.DIR');
    assert.ok(l.length >= 1 && l.length <= 40, `${l.length} entries`);
    for (const e of l) assert.match(e, /^gemini:\/\/[a-z0-9.-]+(:\d+)?\/\S* \S/, e);
});

test('NEWS.DIR: host[:port][/group] and a name of 70 at most', () => {
    const l = lines('NEWS.DIR');
    assert.ok(l.length >= 1 && l.length <= 40, `${l.length} entries`);
    for (const e of l) { assert.match(e, /^[a-z0-9.-]+(:\d+)?(\/[a-z0-9.+_-]+)? \S/, e); assert.ok(e.length - e.indexOf(' ') - 1 <= 70, e); }
});
