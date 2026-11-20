# AGENTS.md

Dialtone: TERM (a modem terminal), IRC (an IRC client), GOPHER, GEMINI, NEWS, MUD, FINGER and NETTIME for CP/M 2.2,
8080 assembly, VT100.
Standalone project; DigitalRerun assembles the same sources into its boot disk and its Online
shelf disk. Read the README first: it has the hardware ports and the `ASM.COM` dialect rules.

- Build: `node build.js [outdir]` writes the eight `.COM` files (`PROGRAMS` in build.js). It needs DigitalRerun's
  `js/asm8080.js`: `ASM8080=<path>`, or a `digital-rerun` folder next to this one. On CP/M itself:
  `SUBMIT B:MAKEALL`. The `.COM` files are not in git; releases carry them.
- Test: `node --test test/*.test.js`. The build checks skip without the assembler or the built
  files. `IRC` and its buffers must end below the ring at 3000h (a test keeps them there).
  GOPHER, GEMINI, NEWS, MUD, FINGER and NETTIME share the modem code in `net.asm`: each source has a line
  `;<tab>include net.asm` where `build.js` (`source()`) joins it, as ASM.COM has no include. Anything that
  assembles a program or puts its source on a disk uses `source()`, never the raw file. GOPHER, GEMINI and NEWS share the
  page viewer's routines (the screen, the input line and its history, saving, numbers, the directory file) in `view.asm`,
  joined the same way; TERM, IRC, MUD and FINGER their directory file (`loaddir` ...) in `dir.asm`. What is still alike but kept apart (the way back, `prompt`, the keys) is copied: a fix in one goes into the others. A new program goes into `PROGRAMS` and `MAKEALL.SUB`.
- Keep to what `ASM.COM` takes (no label that is an 8080 mnemonic, no `db` string over 64
  characters, no `!` in a comment, no `HIGH`/`LOW`/`$` in `ds`), or the CP/M build breaks (a test checks
  the first three).
- The `.DIR` files are text; DigitalRerun generates its own at build time.
- Version: `VERSION` and `CHANGELOG.md`; tag releases `vX.Y.Z`. Commits: `feat:`, `fix:`, `docs:`.
