# AGENTS.md

Dialtone: TERM (a modem terminal) and IRC (an IRC client) for CP/M 2.2, 8080 assembly, VT100.
Standalone project; DigitalRerun assembles the same sources into its boot disk and its Online
shelf disk. Read the README first: it has the hardware ports and the `ASM.COM` dialect rules.

- Build: `node build.js [outdir]` writes `TERM.COM` and `IRC.COM`. It needs DigitalRerun's
  `js/asm8080.js`: `ASM8080=<path>`, or a `digital-rerun` folder next to this one. On CP/M itself:
  `SUBMIT B:MAKEALL`. The `.COM` files are not in git; releases carry them.
- Test: `node --test test/*.test.js`. The build checks skip without the assembler or the built
  files. `IRC` and its buffers must end below the ring at 3000h (a test keeps them there).
- Keep to what `ASM.COM` takes (no label that is an 8080 mnemonic, no `db` string over 64
  characters, no `!` in a comment, no `HIGH`/`LOW`/`$` in `ds`), or the CP/M build breaks.
- `TERM.DIR` and `IRC.DIR` are text with a trailing `^Z`; DigitalRerun generates its own at build time.
- Version: `VERSION` and `CHANGELOG.md`; tag releases `vX.Y.Z`. Commits: `feat:`, `fix:`, `docs:`.
