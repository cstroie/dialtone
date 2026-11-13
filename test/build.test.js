'use strict';
// TERM.COM and IRC.COM (not in git: node build.js, or the release) are current with their sources.
// Needs DigitalRerun's assembler (see build.js); skipped without it or without the built files.
// Run: node --test test/*.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { loadAssembler, com } = require('../build.js');

const asm = loadAssembler();
for (const [src, name] of [['term.asm', 'TERM.COM'], ['irc.asm', 'IRC.COM']]) {
    const built = fs.existsSync(path.join(__dirname, '..', name));
    test(`${name} is assembled from ${src} as it stands`, { skip: (!asm && 'no assembler (ASM8080)') || (!built && `${name} is not built`) }, () => {
        assert.deepEqual(com(asm, src), fs.readFileSync(path.join(__dirname, '..', name)));
    });
}

test('IRC and its buffers end below the ring at 3000h (irc.asm: RING)', { skip: !asm && 'no assembler (ASM8080)' }, () => {
    const r = asm.assemble(fs.readFileSync(path.join(__dirname, '..', 'irc.asm'), 'latin1'), {});
    assert.ok(r.high < 0x3000, `the program and its buffers end at ${r.high.toString(16)}`);
});
