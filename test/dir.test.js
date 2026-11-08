'use strict';
// The example directories are real lists the programs can read: TERM shows at most
// 16 entries, each in a column of 38 characters; IRC lists 16, a line of 76.
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
