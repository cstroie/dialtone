# Changelog

Releases carry `TERM.COM` and `IRC.COM`, and the ready-made `TERM.DIR` and `IRC.DIR`.

## 1.0.0 (2026-11-13)

First release.

- **TERM**: a modem terminal (AT commands, a Ctrl-] menu, a directory of places, XMODEM send and
  receive) that also dials from the command line: `TERM telehack`.
- **IRC**: an IRC client over the same modem: `/connect`, channels, private messages, a status bar,
  a grouped `/help` that fits one screen with the welcome; it dials from the command line too.
- 8080 assembly in the dialect of CP/M's own `ASM.COM`, so the machine builds both with `ASM`,
  `LOAD` and `SUBMIT` (`SUBMIT B:MAKEALL`); `node build.js` does it on the host. About 10K together.
- VT100, 80x24, plain ASCII; talks to the modem on ports 6 and 7 and the clock on port 20.
