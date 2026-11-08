# Dialtone

Two programs for a CP/M machine with a modem on its serial port: **TERM**, a terminal you
dial out with (a bulletin board, a telnet host, XMODEM file transfer), and **IRC**, an IRC
client. 8080 assembly, CP/M 2.2, a VT100 screen of 80x24, plain ASCII, no colour. Together
about 10K of program.

| TERM | IRC |
|---|---|
| ![TERM's modem menu](docs/term.png) | ![IRC's help](docs/irc.png) |

They were written for [DigitalRerun](https://github.com/cstroie/digital-rerun), a CP/M computer
in the browser, whose modem they were made to drive, and that is where they run out of the box
(see [Hardware](#hardware) for what any other machine must provide). The same sources serve
the boot disk (TERM) and the **Online** shelf disk (both).

## TERM

What you type goes out of the modem, what comes in goes to the screen. Talk to the modem in AT
commands: `ATDT` and a number or a name. **Ctrl-]** opens a full-screen menu (the keys on top,
the state of the line and the modem's answers below):

| Key | |
|---|---|
| `D` | dial a number from `TERM.DIR` (or type one) |
| `L` | redial the last number |
| `Z`, `F` | reset the modem; factory settings |
| `E`, `O` | escape to command mode (`+++`); back on line (`ATO`) |
| `M`, `K`, `A` | speaker, echo and auto-answer on and off |
| `I` | ask the modem who it is (`ATI3`) |
| `R`, `S` | receive and send a file, XMODEM (checksum, 128-byte blocks) |
| `H` | hang up (drops DTR) |
| `Q` | quit TERM (the call stays up; run `TERM` again to come back) |
| `Esc` or `Space` | back to the terminal; `Ctrl-]` in the menu sends a Ctrl-] |

```
A>TERM
ATDT0100            the Digital Rerun BBS
```

Or dial from the command line, and TERM starts already calling:

```
A>TERM telehack         a word of a line of TERM.DIR (a name, a host)
A>TERM telehack.com     a host, or host:port
A>TERM 0100             a number: always dialed as it is
```

A word that is in `TERM.DIR` dials that line's first word; anything else is dialed as given
(in lower case; at most 24 characters). A number, or anything that starts with a digit, is never
looked up.

## IRC

On start it shows how to begin (`/connect`, `/connect 1`, `/help`); `/help` lists every command in four groups (connecting, channels, people, other); the welcome and the whole help fit the 22 message rows together, so nothing scrolls off. It dials a server through the modem, registers (`NICK`, `USER`) and talks IRC. A status bar on
the top row (your nick, the server, who you are talking to), the messages scrolling below it,
your line (76 characters; backspace edits, Ctrl-U clears) on the bottom row. A line that does
not start with a slash is said to the current channel or person; `//text` says a line that
begins with a slash.

| Command | |
|---|---|
| `/connect [host[:port] \| n \| word]` | dial a server; no argument lists `IRC.DIR`; a one- or two-digit number is a line of it; a word is the first line that has it |
| `/nick name` | set the nick (before a connection) or change it |
| `/join #chan [key]`, `/part [#chan]` | the channel you join is where you talk |
| `/msg nick text`, `/query nick [text]`, `/me action` | private messages; `/query` makes a person the target |
| `/list`, `/names`, `/whois`, `/who`, `/topic`, `/mode`, `/away` | the rest of the line goes to the server |
| `/raw line` | a line to the server as it is |
| `/quit [text]`, `/bye [text]` | hang up (IRC stays); hang up and leave |
| `/help`, `/clear` | the commands, grouped; clear the screen |

From the command line, `IRC` takes the same as `/connect` and dials at once:

```
B>IRC libera            a word of a line of IRC.DIR (a name, a host)
B>IRC 3                 the third line of IRC.DIR
B>IRC irc.example.org   a host, or host:port (the port defaults to 6667)
```

Plain TCP only: the program does no TLS, so the server must listen on a port of 6660-6669
(6667 usually).

## The directories

`TERM.DIR` and `IRC.DIR` are plain text files beside the programs, one place per line, edited
with any CP/M editor (`ED`). Both ship here filled in, ready to copy next to the `.COM` files
(copy them as text, so the file ends in a `^Z`):

```
TERM.DIR   the string to dial, then a name       telehack.com Telehack
IRC.DIR    host[:port], then a name              irc.libera.chat:6667 Libera.Chat: free and open source projects
```

- **TERM.DIR** lists up to 16 places, shown in two columns, so keep a line to 37 characters; the
  first word (at most 24 characters) is what `ATDT` gets. The ten here are telnet hosts: BBSes,
  a MUD, NetHack, Telehack, a public-access Unix. They need a modem that dials a host name (a WiFi
  modem, or DigitalRerun's bridge); on a modem that dials numbers, put numbers.
- **IRC.DIR** lists up to 16 servers, ten here (Libera.Chat, OFTC, Rizon, EFnet, DALnet,
  Undernet, QuakeNet, IRCnet, Snoonet, GameSurge), all on port 6667. `/connect` shows them
  numbered; `/connect 3` dials the third.

In DigitalRerun both files are generated at build time from the emulator's own dial list
(`js/devices/directory.js`), because the numbers must match what its modem can dial; the files
here are for every other machine.

## Running

On DigitalRerun: the shelf's *Comm* section, **Online**, *Insert* (in B:), then `B:` and `IRC` or
`TERM`; TERM is also on the boot disk. On a machine of your own, copy `TERM.COM`, `IRC.COM` and
the `.DIR` files you want onto a disk. The docs say more about the system they were made for:
[docs/ONLINE.txt](docs/ONLINE.txt) is the disk's own readme.

## Hardware

The programs talk to the hardware directly, not through the BIOS:

| Port | In | Out |
|---|---|---|
| 6 | modem status: bit 0 byte waiting, bit 1 may send, bit 2 carrier | modem control: bit 0 DTR (dropping it hangs up) |
| 7 | the received byte | the byte to send |
| 20 | the clock: `IN` reads the record latched by an `OUT` | latch the clock |

A status of `0FFh` on port 6 means no modem. The clock gives TERM's and IRC's timeouts and the
XMODEM timing in milliseconds. Console I/O goes through BDOS (function 6, direct console I/O) and
the screen must be a VT100. On a machine that is not DigitalRerun you provide ports 6, 7 and 20
as above.

## Building

### On the CP/M machine itself

The sources are 8080 code in the dialect of CP/M's own `ASM.COM`, so the machine can build
them with what it ships with: `ASM`, `LOAD` and `SUBMIT`. Put the system disk in A: and a disk
in B: with `TERM.ASM`, `IRC.ASM`, `MAKE.SUB` and `MAKEALL.SUB` (copied as text; on DigitalRerun
the **Online** disk already has them, and `TERM.COM` and `IRC.COM` get rebuilt in place):

```
A>SUBMIT B:MAKEALL          both programs
A>SUBMIT B:MAKE TERM        one of them (TERM or IRC)
```

`MAKE.SUB` is three lines, with `$1` the name:

```
ASM $1.BBZ          source on B:, the .HEX on B:, no listing
LOAD B:$1           .HEX to .COM
ERA B:$1.HEX
```

On the 4 MHz emulator `TERM` takes about 25 seconds and `IRC` about 40 (a real floppy is slower). For a listing, use `ASM IRC.BBX`
(the listing goes to the screen) or `ASM IRC.BBB` (to `IRC.PRN` on B:).
Things `ASM.COM` does not take, which the sources keep to: no label that is an 8080
mnemonic (`cm`, `cz`...), no string over 64 characters in one `db` operand, no `!` in a
comment, no `HIGH`, `LOW` or `$` arithmetic in `ds`. `IRC` keeps its 256-byte receive ring at the
fixed address 3000h, above the program and its buffers (a test keeps them below it).

### On another machine, with Node.js

DigitalRerun's [`js/asm8080.js`](https://github.com/cstroie/digital-rerun/blob/main/js/asm8080.js)
assembles them (no dependencies):

```
ASM8080=/path/to/digital-rerun/js/asm8080.js node build.js [outdir]
node --test            checks TERM.COM and IRC.COM against the sources (skipped without ASM8080)
```

Inside DigitalRerun, where this repository is the submodule `system/dialtone`, no variable is
needed and `node tools/build.js` builds the disks. `TERM.COM` (4.0K) and `IRC.COM` (6.5K) are
committed. Both builds make the same program: DigitalRerun's own test builds both ways and
compares them.

## Files

| File | |
|---|---|
| `term.asm`, `irc.asm` | the sources |
| `MAKE.SUB`, `MAKEALL.SUB` | build on CP/M: `SUBMIT B:MAKEALL` |
| `TERM.COM`, `IRC.COM` | as built |
| `build.js`, `test/` | the build and its check; the directories' limits |
| `TERM.DIR`, `IRC.DIR` | ready-made directories of places to go |
| `docs/` | the disk's readme, the screenshots |

## Licence

MIT, see [LICENSE](LICENSE). Copyright (c) 2026 Costin Stroie.
