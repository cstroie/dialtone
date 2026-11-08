'use strict';
// TERM.COM and IRC.COM are current with their sources. Needs DigitalRerun's
// assembler (see build.js); skipped without it. Run: node --test
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { loadAssembler, com } = require('../build.js');

const asm = loadAssembler();
for (const [src, name] of [['term.asm', 'TERM.COM'], ['irc.asm', 'IRC.COM']]) {
    test(`${name} is assembled from ${src} as it stands`, { skip: !asm && 'no assembler (ASM8080)' }, () => {
        assert.deepEqual(com(asm, src), fs.readFileSync(path.join(__dirname, '..', name)));
    });
}
