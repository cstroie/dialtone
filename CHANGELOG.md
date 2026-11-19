# Changelog

Releases carry the `.COM` files and the ready-made `.DIR` files.

## 1.2.0 (2026-11-19)

- **GEMINI**: a Gemini client, built like GOPHER. Gemtext laid out for 80 columns (headings bold,
  paragraphs wrapped at the words, lists and quotes set in, preformatted text as it is), links
  numbered and followed with relative addresses resolved, input (`1x`) asked and sent encoded,
  redirects followed, errors shown; the way back, go to an address, save the gemtext; a home page
  from `GEMINI.DIR`. TLS is the modem bridge's (an 8080 cannot do it): DigitalRerun's speaks it for
  port 1965. `SUBMIT B:MAKEALL` builds all seven.

## 1.1.0 (2026-11-19)

Four more programs, on the same modem and in the same `ASM.COM` dialect; `SUBMIT B:MAKEALL` builds all six.

- **GOPHER**: a Gopher client. Numbered menus, texts cut at 79 columns, searches, the way back (8 places), go to an
  address, save a page as CP/M text; a home menu from `GOPHER.DIR`.
- **MUD**: a client for text worlds on IRC's screen: the world's text above, your line below, never broken by it;
  ANSI codes left out, Ctrl-P/N history, a password shown as stars and not kept; `MUD.DIR`.
- **FINGER**: `user@host` or `@host`, a page at a time; alone it lists `FINGER.DIR` (graph.no's weather, who is on
  SDF), and `FINGER 2` asks its second line.
- **NETTIME**: the time from a NIST daytime server, how far the machine's clock is from it, and under CP/M 3 the date
  and time set (with an offset) and read back.
- A test keeps the sources to what `ASM.COM` takes; `MAKEALL.SUB` is checked against the list of programs.

## 1.0.0 (2026-11-13)

First release.

- **TERM**: a modem terminal (AT commands, a Ctrl-] menu, a directory of places, XMODEM send and
  receive) that also dials from the command line: `TERM telehack`.
- **IRC**: an IRC client over the same modem: `/connect`, channels, private messages, a status bar,
  a grouped `/help` that fits one screen with the welcome; it dials from the command line too.
- 8080 assembly in the dialect of CP/M's own `ASM.COM`, so the machine builds both with `ASM`,
  `LOAD` and `SUBMIT` (`SUBMIT B:MAKEALL`); `node build.js` does it on the host. About 10K together.
- VT100, 80x24, plain ASCII; talks to the modem on ports 6 and 7 and the clock on port 20.
