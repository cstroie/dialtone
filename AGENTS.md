# AGENTS.md

Dialtone: TERM (a modem terminal), IRC (an IRC client), GOPHER, GEMINI, MUD, FINGER and NETTIME for CP/M 2.2,
8080 assembly, VT100.
Standalone project; DigitalRerun assembles the same sources into its boot disk and its Online
shelf disk. Read the README first: it has the hardware ports and the `ASM.COM` dialect rules.

- Build: `node build.js [outdir]` writes the seven `.COM` files (`PROGRAMS` in build.js). It needs DigitalRerun's
  `js/asm8080.js`: `ASM8080=<path>`, or a `digital-rerun` folder next to this one. On CP/M itself:
  `SUBMIT B:MAKEALL`. The `.COM` files are not in git; releases carry them.
- Test: `node --test test/*.test.js`. The build checks skip without the assembler or the built
  files. `IRC` and its buffers must end below the ring at 3000h (a test keeps them there).
  GOPHER, GEMINI, MUD, FINGER and NETTIME share a block of modem code ("the same in FINGER, NETTIME,
  GOPHER, MUD and GEMINI"): a change to it goes into all five. GEMINI takes more of GOPHER's routines
  (the way back, input, saving, numbers): they are copied, so a fix in one goes into the other. A new program goes into `PROGRAMS` and `MAKEALL.SUB`.
- Keep to what `ASM.COM` takes (no label that is an 8080 mnemonic, no `db` string over 64
  characters, no `!` in a comment, no `HIGH`/`LOW`/`$` in `ds`), or the CP/M build breaks (a test checks
  the first three).
- The `.DIR` files are text; DigitalRerun generates its own at build time.
- Version: `VERSION` and `CHANGELOG.md`; tag releases `vX.Y.Z`. Commits: `feat:`, `fix:`, `docs:`.
