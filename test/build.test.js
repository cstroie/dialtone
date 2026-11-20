'use strict';
// The .COM files (not in git: node build.js, or the release) are current with their sources.
// Needs DigitalRerun's assembler (see build.js); skipped without it or without the built files.
// Run: node --test test/*.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { loadAssembler, source, com, PROGRAMS } = require('../build.js');

const asm = loadAssembler();
for (const [src, name] of PROGRAMS) {
    const built = fs.existsSync(path.join(__dirname, '..', name));
    test(`${name} is assembled from ${src} as it stands`, { skip: (!asm && 'no assembler (ASM8080)') || (!built && `${name} is not built`) }, () => {
        assert.deepEqual(com(asm, src), fs.readFileSync(path.join(__dirname, '..', name)));
    });
}

test('IRC and its buffers end below the ring at 3000h (irc.asm: RING)', { skip: !asm && 'no assembler (ASM8080)' }, () => {
    const r = asm.assemble(source('irc.asm'), {});
    assert.ok(r.high < 0x3000, `the program and its buffers end at ${r.high.toString(16)}`);
});

test('MAKEALL.SUB builds every program with MAKE.SUB\'s three lines', () => {
    const want = PROGRAMS.map(([, name]) => name.replace('.COM', '')).map(n => `ASM ${n}.BBZ\nLOAD B:${n}\nERA B:${n}.HEX\n`).join('');
    assert.equal(fs.readFileSync(path.join(__dirname, '..', 'MAKEALL.SUB'), 'latin1'), want);
});

test('the sources keep to what ASM.COM takes: no label that is a mnemonic, no string over 64, no ! in a comment', () => {
    const mnemonics = new Set(('MOV MVI LXI LDA STA LHLD SHLD LDAX STAX XCHG ADD ADI ADC ACI SUB SUI SBB SBI INR DCR INX DCX DAD DAA ' +
        'ANA ANI ORA ORI XRA XRI CMP CPI RLC RRC RAL RAR CMA CMC STC JMP JNZ JZ JNC JC JPO JPE JP JM CALL CNZ CZ CNC CC CPO CPE CP CM ' +
        'RET RNZ RZ RNC RC RPO RPE RP RM RST PCHL SPHL XTHL IN OUT EI DI HLT NOP PUSH POP A B C D E H L M SP PSW').split(' '));
    for (const src of [...PROGRAMS.map(([s]) => s), 'net.asm', 'view.asm', 'dir.asm']) {
        fs.readFileSync(path.join(__dirname, '..', src), 'latin1').split('\n').forEach((line, i) => {
            const at = `${src}:${i + 1}`;
            const label = /^([A-Za-z_][A-Za-z0-9_]*)/.exec(line);
            if (label) assert.ok(!mnemonics.has(label[1].toUpperCase()), `${at}: the label ${label[1]}`);
            const code = line.replace(/'[^']*'/g, q => { assert.ok(q.length - 2 <= 64, `${at}: a string of ${q.length - 2}`); return "''"; });
            const semi = code.indexOf(';');
            if (semi >= 0) assert.ok(!code.slice(semi).includes('!'), `${at}: ! in a comment`);
        });
    }
});

for (const [part, mark] of [['net.asm', '\npoll:\tpush\tpsw\n'], ['view.asm', '\nmkfcb:'], ['dir.asm', '\nloaddir:']]) {
    test(`${part.toUpperCase()} is joined whole where a program includes it, and only there`, () => {
        const whole = fs.readFileSync(path.join(__dirname, '..', part), 'latin1');
        const want = new RegExp(`^;\\tinclude ${part.replace('.', '\\.')}`, 'm');
        for (const [src] of PROGRAMS) {
            const raw = fs.readFileSync(path.join(__dirname, '..', src), 'latin1'), made = source(src);
            assert.ok(!/^;\tinclude /m.test(made), `${src}: an include left`);
            if (want.test(raw)) assert.ok(made.includes(mark) && made.length > raw.length + whole.length / 2, `${src}: ${part} joined`);
            else if (!/^;\tinclude /m.test(raw)) assert.equal(made, raw, `${src}: unchanged`);
        }
    });
}
