#!/usr/bin/env node
'use strict';
/*
 * build.js: assemble TERM.COM, IRC.COM, GOPHER.COM, MUD.COM, FINGER.COM and NETTIME.COM.
 *
 *   node build.js [outdir]
 *
 * The sources are 8080 code in the dialect of CP/M's ASM.COM. The assembler is
 * DigitalRerun's js/asm8080.js: the path in ASM8080, else ../../js/asm8080.js when this
 * repository is its submodule (system/dialtone), else a digital-rerun folder next to this one.
 */
const fs = require('fs');
const path = require('path');

function loadAssembler() {
    const file = process.env.ASM8080 || [path.join(__dirname, '../../js/asm8080.js'), path.join(__dirname, '../digital-rerun/js/asm8080.js')].find(f => fs.existsSync(f));
    if (!file || !fs.existsSync(file)) return null;
    return require(path.resolve(file));
}

/** The .COM image of one source file (loaded at 100h). */
function com(asm, file) {
    const r = asm.assemble(fs.readFileSync(path.join(__dirname, file), 'latin1'), {});
    return Buffer.from(r.image(0x100, r.high));
}

/** The programs: their source and the .COM it makes. */
const PROGRAMS = [['term.asm', 'TERM.COM'], ['irc.asm', 'IRC.COM'], ['gopher.asm', 'GOPHER.COM'], ['mud.asm', 'MUD.COM'],
    ['finger.asm', 'FINGER.COM'], ['nettime.asm', 'NETTIME.COM']];

module.exports = { loadAssembler, com, PROGRAMS };

if (require.main === module) {
    const asm = loadAssembler();
    if (!asm) { console.error('no assembler: clone digital-rerun next to this folder, or set ASM8080=<it>/js/asm8080.js'); process.exit(1); }
    const out = process.argv[2] || __dirname;
    for (const [src, name] of PROGRAMS) {
        const img = com(asm, src);
        fs.writeFileSync(path.join(out, name), img);
        console.log(`${name}: ${img.length} bytes`);
    }
}
