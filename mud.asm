;	MUD: a client for text worlds (MUDs) over the modem
;
;	A>MUD			the worlds of MUD.DIR, then /connect n
;	A>MUD aardwolf		a number of MUD.DIR, a word of one of its lines, or host[:port]
;
;	The screen is a VT100: a status bar on top, what the world says in the
;	rows below it, your line on the bottom row, so what comes in never
;	breaks what you type. Return sends the line (an empty one too: the
;	worlds use it for more), Ctrl-P and Ctrl-N (or the arrows) bring back
;	the lines sent before, Ctrl-U clears. After a prompt that asks for a
;	password the line shows as stars and is not kept. Colours are left out.
;
;	/connect [host[:port] | n]  /quit (hangs up)  /bye (and leaves)  /clear  /help
;	//text sends a line that begins with a slash.
;
;	MUD.DIR: a world per line, host[:port] and a name. Telnet (the bridge):
;	any port but the raw ones (13, 37, 70, 79, 6660-6669).
;
;	Copyright (c) 2026 Costin Stroie, MIT licence.

bdos	equ	0005h
conio	equ	6		;direct console I/O: E = 0FFh reads a key (A = 0: none)
print	equ	9
openf	equ	15
readsq	equ	20
setdma	equ	26
clk	equ	20		;the clock port: OUT latches, IN reads the record
mst	equ	6		;modem status: bit 0 byte waiting, bit 1 may send, bit 2 carrier
mctl	equ	6		;modem control: bit 0 DTR
mdat	equ	7		;modem data
cr	equ	13
lf	equ	10
tab	equ	9
rmask	equ	07h		;the ring is 2K: its offsets wrap at 0800h
imax	equ	76		;the longest line you can type (the bottom row)
nhist	equ	10		;lines kept to bring back

	org	100h
	lxi	h,0
	dad	sp
	shld	savesp
	lxi	sp,stktop
	in	mst
	cpi	0ffh		;nothing answers: no modem here
	lxi	d,nomsg
	jz	quitm
	call	getarg
	call	minit
	call	initscr
	lxi	h,welcome
	call	hlines
	lda	cmdarg
	ora	a
	jz	loop
	lxi	h,cmdarg
	shld	argp
	call	cconn

;	the loop: what came in to the screen, then the carrier, then a key
loop:	call	poll
	call	rget
	jc	lp1
	call	unget
	call	outq
	jmp	lp2		;the carrier is looked at once all that came is shown
lp1:	in	mst
	ani	4
	lxi	h,dcd
	cmp	m
	jnz	carr
lp2:	call	keyin
	ora	a
	cnz	key
	jmp	loop

;	the carrier went (it comes only in a dial): the modem's NO CARRIER is not the world's
carr:	sta	dcd
	ora	a
	jnz	cr9
	lxi	h,300
	call	delay
	call	flush
	lxi	h,mdisc
	call	info
cr9:	call	drawst
	jmp	loop

;	---- what the world says ----

;	the ring to the message rows, 250 bytes at most (then the keys get a look)
outq:	call	obeg
	mvi	a,250
	sta	qcnt
oq1:	call	rget
	jc	oq9
	call	ochar
	lda	qcnt
	dcr	a
	sta	qcnt
	jnz	oq1
oq9:	jmp	oend

;	the cursor to where the world's text goes on (the bottom row of the region), and back
obeg:	lxi	h,sobeg
	call	pz
	lda	mcol
	inr	a
	call	pdec
	mvi	a,'H'
	jmp	cout
oend:	lxi	h,soend
	jmp	pz

;	a character from the world (A): ANSI codes go, a line wraps at 80
ochar:	mov	b,a
	lda	ansi
	ora	a
	jz	oc2
	cpi	1
	mov	a,b
	jnz	oc1
	cpi	'['		;after ESC: [ opens a sequence, anything else ends it
	mvi	a,2
	jz	oc0
	xra	a
oc0:	sta	ansi
	ret
oc1:	cpi	40h		;in a sequence: a letter (40h-7Eh) ends it
	rc
	xra	a
	sta	ansi
	ret
oc2:	mov	a,b
	cpi	1bh
	jnz	oc3
	mvi	a,1
	sta	ansi
	ret
oc3:	cpi	lf
	jz	onl
	cpi	tab
	jz	otab
	cpi	20h
	rc			;CR and the other control characters: nothing
	cpi	7fh
	jc	oc4
	rz
	cpi	0c0h
	rc			;the inside of a UTF-8 character
	mvi	a,'?'
oc4:	push	psw
	lda	mcol
	cpi	80
	cnc	onl
	lda	mcol
	inr	a
	sta	mcol
	pop	psw
	push	psw
	call	cout
	pop	psw
;	a prompt that asks for a password: the next line you type is hidden
	call	lower
	mov	b,a
	lxi	h,pwpat
	lda	pwi
	mov	e,a
	mvi	d,0
	dad	d
	mov	a,m
	cmp	b
	jnz	oc5
	inr	e
	mov	a,e
	sta	pwi
	cpi	7		;'assword'
	rnz
	mvi	a,1
	sta	mask
	xra	a
	sta	pwi
	ret
oc5:	mov	a,b
	cpi	'a'
	mvi	a,0
	jnz	oc6
	inr	a
oc6:	sta	pwi
	ret
otab:	mvi	a,' '
	call	oc4
	lda	mcol
	ani	7
	jnz	otab
	ret
;	a new line in the message rows
onl:	mvi	a,cr
	call	cout
	mvi	a,lf
	call	cout
	xra	a
	sta	mcol
	sta	pwi
	ret

;	a line of our own in the message rows: *** and the text at HL
info:	push	h
	call	obeg
	lda	mcol
	ora	a
	cnz	onl
	lxi	h,sstar
	call	pz
	pop	h
	call	pz
	call	onl
	jmp	oend
;	a line as it is
hline:	push	h
	call	obeg
	lda	mcol
	ora	a
	cnz	onl
	pop	h
	call	pz
	call	onl
	jmp	oend
;	the lines of a table of words (0-ended), each in the message rows
hlines:	mov	e,m
	inx	h
	mov	d,m
	inx	h
	mov	a,d
	ora	e
	rz
	push	h
	xchg
	call	hline
	pop	h
	jmp	hlines

;	A (1-99) in decimal
pdec:	mvi	b,'0'
pd1:	cpi	10
	jc	pd2
	sui	10
	inr	b
	jmp	pd1
pd2:	push	psw
	mov	a,b
	cpi	'0'
	cnz	cout
	pop	psw
	adi	'0'
	jmp	cout

;	---- the screen ----

initscr:lxi	h,sinit
	call	pz
	xra	a
	sta	mcol
	call	drawst
	jmp	drawin

;	the status bar (the cursor kept where it was)
drawst:	lxi	h,sst1
	call	pz
	lda	dcd
	ora	a
	lxi	h,son
	jnz	ds1
	lda	dialing
	ora	a
	lxi	h,sdial
	jnz	ds1
	lxi	h,snot
	call	pz
	jmp	ds2
ds1:	call	pz
	lxi	h,where
	call	pz
ds2:	lxi	h,sst2
	jmp	pz

;	your line on the bottom row (stars if hidden)
drawin:	lxi	h,sprompt
	call	pz
	lxi	h,ibuf
dw1:	mov	a,m
	ora	a
	rz
	call	ichr
	inx	h
	jmp	dw1
ichr:	push	psw
	lda	mask
	ora	a
	jz	ic1
	pop	psw
	mvi	a,'*'
	jmp	cout
ic1:	pop	psw
	jmp	cout

;	---- what you type ----

key:	mov	b,a
	lda	kesc		;the arrows: ESC [ A and ESC [ B
	ora	a
	jz	ky1
	cpi	1
	jnz	ky0
	mov	a,b
	cpi	'['
	mvi	a,2
	jz	ky00
	xra	a
ky00:	sta	kesc
	ret
ky0:	xra	a
	sta	kesc
	mov	a,b
	cpi	'A'
	jz	hprev
	cpi	'B'
	jz	hnext
	ret
ky1:	mov	a,b
	cpi	1bh
	jnz	ky2
	mvi	a,1
	sta	kesc
	ret
ky2:	cpi	cr
	jz	enter
	cpi	8
	jz	bksp
	cpi	7fh
	jz	bksp
	cpi	15h		;Ctrl-U
	jz	kill
	cpi	18h		;Ctrl-X
	jz	kill
	cpi	10h		;Ctrl-P
	jz	hprev
	cpi	0eh		;Ctrl-N
	jz	hnext
	cpi	20h
	rc
	mov	b,a
	lda	ilen
	cpi	imax
	rnc
	mov	e,a
	mvi	d,0
	inr	a
	sta	ilen
	lxi	h,ibuf
	dad	d
	mov	m,b
	inx	h
	mvi	m,0
	mov	a,b
	jmp	ichr
bksp:	lda	ilen
	ora	a
	rz
	dcr	a
	sta	ilen
	mov	e,a
	mvi	d,0
	lxi	h,ibuf
	dad	d
	mvi	m,0
	lxi	h,sbs
	jmp	pz
kill:	xra	a
	sta	ilen
	sta	ibuf
	sta	hpos
	jmp	drawin

;	Return: a command, or the line to the world
enter:	lda	ibuf
	cpi	'/'
	jnz	en1
	lda	ibuf+1
	cpi	'/'
	jz	en0
	call	docmd
	jmp	en9
en0:	lxi	h,ibuf+1	;// : a line that begins with a slash
	jmp	en2
en1:	lxi	h,ibuf
en2:	lda	dcd
	ora	a
	jnz	en3
	lxi	h,mnocon
	call	info
	jmp	en9
en3:	push	h
	call	hsave
	pop	h
	call	txz
	mvi	a,cr		;CR alone: the bridge makes it a telnet end of line
	call	txb
en9:	xra	a
	sta	ilen
	sta	ibuf
	sta	mask
	sta	hpos
	jmp	drawin

;	the line typed kept for Ctrl-P (not an empty one, not a password)
hsave:	lda	mask
	ora	a
	rnz
	lda	ilen
	ora	a
	rz
	lxi	h,hist+(nhist-1)*80	;all move down one, the newest first
	lxi	d,hist+nhist*80-1
	lxi	b,(nhist-1)*80
hs1:	dcx	h		;(from the end: the copy overlaps)
	mov	a,m
	stax	d
	dcx	d
	dcx	b
	mov	a,b
	ora	c
	jnz	hs1
	lxi	h,ibuf
	lxi	d,hist
hs2:	mov	a,m
	stax	d
	inx	h
	inx	d
	ora	a
	jnz	hs2
	lda	hcnt
	cpi	nhist
	rnc
	inr	a
	sta	hcnt
	ret
;	Ctrl-P: the line before; Ctrl-N: the one after
hprev:	lda	hpos
	lxi	h,hcnt
	cmp	m
	rnc
	inr	a
	sta	hpos
	jmp	hget
hnext:	lda	hpos
	ora	a
	rz
	dcr	a
	sta	hpos
	jz	kill
hget:	dcr	a		;line HPOS (1 the newest) into IBUF
	mov	l,a
	mvi	h,0
	dad	h
	dad	h
	dad	h
	dad	h
	push	h
	dad	h
	dad	h
	pop	d
	dad	d		;* 80
	lxi	d,hist
	dad	d
	lxi	d,ibuf
	mvi	b,0
hg1:	mov	a,m
	stax	d
	ora	a
	jz	hg2
	inx	h
	inx	d
	inr	b
	jmp	hg1
hg2:	mov	a,b
	sta	ilen
	jmp	drawin

;	a slash command: the line is in IBUF
docmd:	lxi	h,ibuf+1
	push	h
dc1:	mov	a,m
	ora	a
	jz	dc2
	cpi	' '
	jz	dc3
	inx	h
	jmp	dc1
dc3:	mvi	m,0
	inx	h
dc4:	mov	a,m
	cpi	' '
	jnz	dc2
	inx	h
	jmp	dc4
dc2:	shld	argp
	pop	h
	push	h
	call	upcase
	pop	b
	lxi	d,cmdtab
	call	lookup
	jc	badcmd
	pchl
badcmd:	lxi	h,mbad
	jmp	info

cmdtab:	db	'CONNECT',0
	dw	cconn
	db	'C',0
	dw	cconn
	db	'QUIT',0
	dw	cquit
	db	'BYE',0
	dw	cbye
	db	'EXIT',0
	dw	cbye
	db	'HELP',0
	dw	chelp
	db	'CLEAR',0
	dw	cclear
	db	0

chelp:	lxi	h,helptab
	jmp	hlines
cclear:	jmp	initscr

;	/quit: the call is dropped, MUD stays
cquit:	lda	dcd
	ora	a
	lxi	h,mnocon
	jz	info
	call	hangup
	xra	a
	sta	dcd
	call	drawst
	lxi	h,mdisc
	jmp	info

;	/bye: the call dropped, MUD left
cbye:	call	mfini
	lxi	h,sclr
	call	pz
exit:	lhld	savesp
	sphl
	ret
quitm:	mvi	c,print
	call	bdos
	jmp	exit

;	/connect [host[:port] | n | a word of MUD.DIR]
cconn:	lhld	argp
	call	word
	lhld	argp
	mov	a,m
	ora	a
	jz	showdir
	lda	dcd
	ora	a
	lxi	h,malready
	jnz	info
	lhld	argp
	shld	w1
	call	isidx
	jc	cc2
	sta	nth
	call	loaddir
	lxi	h,mnodir
	jc	info
	lxi	h,dirbuf
cc1:	call	nextline
	jc	ccnos
	lda	nth
	dcr	a
	sta	nth
	jz	cc4
	xchg
	jmp	cc1
cc2:	lhld	w1
	mov	a,m
	call	isdig
	jc	cc3		;it starts with a digit: dialed as it is
	call	loaddir		;a word of MUD.DIR's lines (a name, a host) dials that line
	jc	cc3
	call	findkey
	jnc	cc4
cc3:	lhld	w1
cc4:	lxi	d,nul		;no port: the bridge takes 23
	call	mkdial
	lxi	h,dialbuf+4	;the place, for the status bar
	lxi	d,where
	mvi	b,40
cc5:	mov	a,m
	cpi	cr
	jz	cc6
	stax	d
	inx	h
	inx	d
	dcr	b
	jnz	cc5
cc6:	xra	a
	stax	d
	mvi	a,1
	sta	dialing
	call	drawst
	lxi	h,mdialg
	call	info
	call	mdial
	push	h
	push	psw
	xra	a
	sta	dialing
	pop	psw
	pop	h
	jc	cc8
	mvi	a,4
	sta	dcd
	call	drawst
	lxi	h,mconn
	jmp	info
cc8:	call	info		;what the modem said
	jmp	drawst
ccnos:	lxi	h,mnosuch
	jmp	info

;	the end of the first word at HL is made a 0 (the rest of the line is not needed)
word:	mov	a,m
	ora	a
	rz
	cpi	' '
	jz	wd1
	inx	h
	jmp	word
wd1:	mvi	m,0
	ret

;	/connect alone: the worlds of MUD.DIR, numbered
showdir:call	loaddir
	lxi	h,mnodir
	jc	info
	xra	a
	sta	nent
	lxi	h,dirbuf
sd1:	call	nextline
	jc	sd9
	lda	nent
	cpi	16
	jnc	sd9
	inr	a
	sta	nent
	push	d
	push	h
	call	obeg
	lda	mcol
	ora	a
	cnz	onl
	lda	nent
	call	p2s
	pop	h
	pop	d
sd2:	mov	a,m
	call	cout
	inx	h
	mov	a,l
	cmp	e
	jnz	sd2
	mov	a,h
	cmp	d
	jnz	sd2
	push	d
	call	onl
	call	oend
	pop	h
	jmp	sd1
sd9:	lxi	h,mpick
	jmp	info
;	A (1-99) two wide, two blanks after it
p2s:	cpi	10
	jnc	p2a
	push	psw
	mvi	a,' '
	call	cout
	pop	psw
p2a:	call	pdec
	mvi	a,' '
	call	cout
	mvi	a,' '
	jmp	cout

;	---- strings and MUD.DIR (as in IRC) ----

upper:	cpi	'a'
	rc
	cpi	'{'
	rnc
	sui	20h
	ret
lower:	cpi	'A'
	rc
	cpi	'['
	rnc
	adi	20h
	ret
upcase:	mov	a,m
	ora	a
	rz
	call	upper
	mov	m,a
	inx	h
	jmp	upcase
;	BC = a word, DE = a table of 0-ended names each followed by the address of its routine,
;	the table ended by a 0: HL = the routine, CY clear; or CY set
lookup:	ldax	d
	ora	a
	jz	lkn
	push	b
lk2:	ldax	b
	mov	h,a
	ldax	d
	cmp	h
	jnz	lk3
	ora	a
	jz	lkm
	inx	b
	inx	d
	jmp	lk2
lk3:	ldax	d
	inx	d
	ora	a
	jnz	lk3
	inx	d
	inx	d
	pop	b
	jmp	lookup
lkm:	inx	d
	xchg
	mov	e,m
	inx	h
	mov	d,m
	xchg
	pop	b
	ora	a
	ret
lkn:	stc
	ret

;	the first line of MUD.DIR (in DIRBUF) that has the text at W1 in it, in either case:
;	CY clear and HL its start; CY set if there is none
findkey:lxi	h,dirbuf
fk1:	call	nextline
	rc
	shld	fkst
	xchg
	shld	fkend
	lhld	fkst
fk2:	shld	fkp
	xchg
	lhld	w1
	xchg			;DE the text, HL the place in the line
fk3:	ldax	d
	ora	a
	jz	fkyes
	call	lower
	mov	b,a
	mov	a,m
	call	lower
	cmp	b
	jnz	fk4
	inx	h
	inx	d
	jmp	fk3
fk4:	lhld	fkp
	inx	h
	xchg			;DE the new place
	lhld	fkend
	mov	a,e
	sub	l
	mov	a,d
	sbb	h
	jnc	fk5		;past the end of the line
	xchg
	jmp	fk2
fk5:	lhld	fkend
	jmp	fk1
fkyes:	lhld	fkst
	ora	a
	ret

;	---- the modem ----
;	include net.asm		(build.js joins NET.ASM here: the copy on a disk is whole)

;	---- the console ----

;	one character (A) to the console, then the modem looked at (BC, DE, HL kept)
cout:	push	b
	push	d
	push	h
	mov	e,a
	mvi	c,conio
	call	bdos
	pop	h
	pop	d
	pop	b
	jmp	poll

;	the 0-ended text at HL to the console
pz:	mov	a,m
	ora	a
	rz
	inx	h
	call	cout
	jmp	pz

;	the command line into CMDARG, the blanks before it skipped, in lower case (0-ended, 70 at most)
getarg:	lxi	h,cmdarg
	mvi	m,0
	lda	80h
	ora	a
	rz
	mov	b,a
	lxi	d,81h
ga1:	ldax	d
	cpi	' '
	jnz	ga2
	inx	d
	dcr	b
	jnz	ga1
	ret
ga2:	mvi	c,70
ga3:	ldax	d
	cpi	'A'
	jc	ga4
	cpi	'['
	jnc	ga4
	adi	20h
ga4:	mov	m,a
	inx	h
	inx	d
	dcr	c
	jz	ga9
	dcr	b
	jnz	ga3
ga9:	mvi	m,0
	ret

;	---- the directory file ----
;	include dir.asm		(build.js joins DIR.ASM here: the copy on a disk is whole)

;	---- the data ----

nomsg:	db	'No modem on this machine.',cr,lf,'$'
mcancel:db	'Given up.',0
mnoans:	db	'No answer.',0
welcome:dw	w1h,w2h,w3h,w4h,0
w1h:	db	27,'[1m','MUD for CP/M',27,'[0m',', a client for text worlds',0
w2h:	db	'  /connect         the worlds of MUD.DIR'
	db	', or /connect host[:port]',0
w3h:	db	'  /connect 1       dial the first one; t'
	db	'hen type, and Return sends',0
w4h:	db	'  /help            the rest',0
helptab:dw	hl1,hl2,hl3,hl4,hl5,hl6,0
hl1:	db	'  /connect [host[:port]|n]  dial a world'
	db	'; with nothing, list MUD.DIR',0
hl2:	db	'  /quit   hang up, MUD stays;   /bye   h'
	db	'ang up and leave',0
hl3:	db	'  /clear  a clean screen;   //text sends'
	db	' a line that begins with /',0
hl4:	db	'  Return sends the line, an empty one too'
	db	' (for more)',0
hl5:	db	'  Ctrl-P, Ctrl-N (or the arrows): the li'
	db	'nes sent before; Ctrl-U clears',0
hl6:	db	'  After a password prompt the line shows'
	db	' as stars and is not kept.',0
mconn:	db	'Connected.',0
mdisc:	db	'Disconnected.',0
mdialg:	db	'Dialing ...',0
mnocon:	db	'Not connected: use /connect first.',0
mbad:	db	'Unknown command: /help lists them.',0
malready:db	'Already connected: /quit first.',0
mnodir:	db	'No MUD.DIR on this disk. /connect host[:'
	db	'port] dials by name.',0
mnosuch:db	'No such entry in MUD.DIR.',0
mpick:	db	'/connect n dials one of these, /connect '
	db	'host[:port] any other.',0
sstar:	db	'*** ',0
pwpat:	db	'assword'
nul:	db	0
dirname:db	'MUD     DIR'
sinit:	db	27,'[0m',27,'[r',27,'[2J',27,'[2;23r',0
sst1:	db	27,'7',27,'[1;1H',27,'[7m',27,'[K MUD  ',0
son:	db	'on ',0
sdial:	db	'dialing ',0
snot:	db	'not connected',0
sst2:	db	27,'[0m',27,'8',0
sprompt:db	27,'[24;1H',27,'[K> ',0
sobeg:	db	27,'7',27,'[23;',0
soend:	db	27,'8',0
sbs:	db	8,' ',8,0
sclr:	db	27,'[r',27,'[0m',27,'[?25h',27,'[2J',27,'[H',0
sate0:	db	'ATE0',cr,0
sate1:	db	'ATE1',cr,0
rhead:	dw	0
rtail:	dw	0
t0:	dw	0
tlim:	dw	0
lptr:	dw	0
savesp:	dw	0
argp:	dw	0
w1:	dw	0
fkst:	dw	0
fkend:	dw	0
fkp:	dw	0
dcd:	db	0
dialing:db	0
mcol:	db	0
ansi:	db	0
pwi:	db	0
mask:	db	0
kesc:	db	0
ilen:	db	0
hpos:	db	0
hcnt:	db	0
qcnt:	db	0
nth:	db	0
nent:	db	0
where:	ds	42
ibuf:	db	0
	ds	imax+2
dialbuf:db	'ATDT'
	ds	72
lbuf:	ds	80
cmdarg:	ds	72
fcb:	ds	36
	ds	256
stktop	equ	$
hist:	ds	nhist*80
ring:	ds	2048
dirbuf:	ds	1664
dirend	equ	dirbuf+1536
	end
