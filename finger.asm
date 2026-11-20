;	FINGER: who is on a host, or what someone's plan says, over the modem
;
;	A>FINGER user@host	A>FINGER @host	A>FINGER user@host:port
;	A>FINGER		the lines of FINGER.DIR, numbered
;	A>FINGER 2		asks what line 2 of FINGER.DIR says
;
;	It dials host:79 (through the bridge, which passes port 79 raw), asks
;	for the user (nothing: who is on), and shows what comes back, a page
;	at a time, until the host hangs up. At --More--: Space the next page,
;	Return one line more, Q or Esc stops. A key while it reads stops too.
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
ring	equ	2000h		;what the modem brings: 8K above the program
rmask	equ	1fh		;the offsets in the ring wrap at 2000h
rows	equ	22		;lines of a page before --More--

	org	100h
	lxi	h,0
	dad	sp
	shld	savesp
	lxi	sp,stktop
	call	getarg
	lda	cmdarg
	ora	a
	jz	showdir		;nothing: what FINGER.DIR offers
	lxi	h,cmdarg
	call	isidx
	cnc	fromdir		;a number: that line of FINGER.DIR
	in	mst
	cpi	0ffh		;nothing answers: no modem here
	lxi	d,nomsg
	jz	quitm
	call	split
	lxi	d,musage
	jc	quitm
	call	minit
	lxi	h,sbra		;[host]
	call	pz
	lxi	h,dialbuf+4
fg1:	mov	a,m
	cpi	':'
	jz	fg2
	cpi	cr
	jz	fg2
	call	cout
	inx	h
	jmp	fg1
fg2:	lxi	h,sket
	call	pz
	call	mdial
	jc	failed
	lxi	h,user		;the question: a name, or nothing, and CR LF
	call	txz
	lxi	h,scrlf
	call	txz
	call	show
	jmp	done
failed:	call	pz		;what the modem said
	lxi	h,scrlf
	call	pz
done:	call	mfini
exit:	lhld	savesp
	sphl
	ret
quitm:	mvi	c,print
	call	bdos
	jmp	exit

;	CMDARG is a number of a line of FINGER.DIR (in A): the first word of that line into CMDARG
fromdir:sta	nth
	call	loaddir
	lxi	d,mnodir
	jc	quitm
	lxi	h,dirbuf
fd1:	call	nextline
	jc	fdnone
	lda	nth
	dcr	a
	sta	nth
	jz	fd2
	xchg			;the end of this line: look on from there
	jmp	fd1
fd2:	lxi	d,cmdarg
	mvi	b,70
fd3:	mov	a,m
	cpi	21h
	jc	fd4
	stax	d
	inx	h
	inx	d
	dcr	b
	jnz	fd3
fd4:	xra	a
	stax	d
	ret
fdnone:	lxi	d,mnosuch
	jmp	quitm

;	FINGER alone: the lines of FINGER.DIR, numbered (no modem needed)
showdir:call	loaddir
	lxi	d,musage
	jc	quitm		;no FINGER.DIR: how to use it
	xra	a
	sta	nth
	lxi	h,dirbuf
sd1:	call	nextline
	jc	sd9
	lda	nth
	cpi	16
	jnc	sd9
	inr	a
	sta	nth
	push	h
	push	d
	cpi	10		;the number, two wide, and two blanks
	mvi	a,' '
	cc	putc
	lda	nth
	call	pdec
	mvi	a,' '
	call	putc
	mvi	a,' '
	call	putc
	pop	d
	pop	h
sd2:	mov	a,m
	push	h
	push	d
	call	putc
	pop	d
	pop	h
	inx	h
	mov	a,l
	cmp	e
	jnz	sd2
	mov	a,h
	cmp	d
	jnz	sd2
	push	d
	mvi	a,cr
	call	putc
	mvi	a,lf
	call	putc
	pop	h
	jmp	sd1
sd9:	lxi	d,mpick
	jmp	quitm

;	A to the console, through the BDOS (no modem looked at: there may be none; no register kept)
putc:	mov	e,a
	mvi	c,conio
	jmp	bdos
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
	cnz	putc
	pop	psw
	adi	'0'
	jmp	putc

;	HL = a word, 1 or 2 digits and no more: its value (1-99) in A, CY clear; else CY set
isidx:	mov	a,m
	call	isdig
	jnc	nix
	sui	'0'
	mov	b,a
	inx	h
	mov	a,m
	ora	a
	jz	ix9
	call	isdig
	jnc	nix
	sui	'0'
	mov	c,a
	mov	a,b
	add	a
	mov	b,a
	add	a
	add	a
	add	b
	add	c
	mov	b,a
	inx	h
	mov	a,m
	ora	a
	jnz	nix
ix9:	mov	a,b
	ora	a
	jz	nix
	ora	a
	ret
nix:	stc
	ret
;	CY set if A is a digit
isdig:	cpi	'0'
	jc	idn
	cpi	'9'+1
	jnc	idn
	stc
	ret
idn:	ora	a
	ret

;	HL = where to look in DIRBUF: the next line (CY clear): HL its start, DE its end; or CY set at the end
nextline:
nl1:	mov	a,m
	cpi	1ah
	jz	nlend
	ora	a
	jz	nlend
	cpi	21h
	jnc	nl2
	inx	h
	jmp	nl1
nl2:	mov	d,h
	mov	e,l
nl3:	ldax	d
	cpi	20h
	jc	nl4
	inx	d
	jmp	nl3
nl4:	ora	a
	ret
nlend:	stc
	ret

;	read FINGER.DIR into DIRBUF (^Z ends it); CY set: no such file
loaddir:lxi	h,fcb
	mvi	c,36
	xra	a
ld0:	mov	m,a
	inx	h
	dcr	c
	jnz	ld0
	lxi	h,fcb+1
	lxi	d,dirname
	mvi	c,11
ld1:	ldax	d
	mov	m,a
	inx	h
	inx	d
	dcr	c
	jnz	ld1
	lxi	d,fcb
	mvi	c,openf
	call	bdos
	inr	a
	jnz	ld2
	stc
	ret
ld2:	lxi	h,dirbuf
ld3:	push	h
	xchg
	mvi	c,setdma
	call	bdos
	lxi	d,fcb
	mvi	c,readsq
	call	bdos
	pop	h
	ora	a
	jnz	ld4		;the end of the file
	lxi	d,128
	dad	d
	lxi	d,dirend
	mov	a,l
	sub	e
	mov	a,h
	sbb	d
	jc	ld3
ld4:	mvi	m,1ah
	lxi	d,80h
	mvi	c,setdma
	call	bdos
	xra	a
	ret

;	CMDARG is user@host[:port], @host or host: the user into USER, ATDT host:port CR into
;	DIALBUF; CY set if there is no host
split:	lxi	h,cmdarg	;the last @ splits it
	lxi	d,0
sp1:	mov	a,m
	ora	a
	jz	sp2
	cpi	' '
	jz	sp2
	cpi	'@'
	jnz	sp1a
	mov	d,h
	mov	e,l
sp1a:	inx	h
	jmp	sp1
sp2:	mvi	m,0		;the first word only
	mov	a,d
	ora	e
	lxi	h,cmdarg	;no @: all of it is the host
	jz	sp4
	xchg			;HL at the @
	mvi	m,0
	inx	h
	push	h
	lxi	h,cmdarg
	lxi	d,user
	mvi	b,40
sp3:	mov	a,m
	stax	d
	ora	a
	jz	sp3a
	inx	h
	inx	d
	dcr	b
	jnz	sp3
	xra	a
	stax	d
sp3a:	pop	h
sp4:	mov	a,m
	ora	a
	stc
	rz			;no host
	lxi	d,sport
	jmp	mkdial

;	---- what comes back: on the screen, a page at a time ----

show:	xra	a
	sta	lines
	sta	col
sh1:	call	poll
	call	rget
	jnc	sh2
	in	mst
	ani	4
	rz			;nothing waits and the carrier is gone: it is all here
	call	keyin
	ora	a
	jz	sh1
	jmp	hangup		;a key: stop
sh2:	call	putch
	jnc	sh1
	jmp	hangup		;Q at --More--

;	a character of the answer to the screen (A): CY set if the reader said stop
putch:	cpi	lf
	jz	newl
	cpi	9
	jz	ptab
	cpi	20h
	jc	pnone		;other control characters: nothing
	cpi	7fh
	jc	pc1
	jz	pnone
	cpi	0c0h
	jc	pnone		;the inside of a UTF-8 character
	mvi	a,'?'		;its first byte: one ?
pc1:	push	psw
	lda	col
	cpi	80
	jc	pc1a
	call	newl		;a long line wraps
	jc	pc2
pc1a:	lda	col
	inr	a
	sta	col
	pop	psw
	call	cout
	ora	a
	ret
pc2:	pop	psw
	stc
	ret
pnone:	ora	a
	ret
ptab:	mvi	a,' '
	call	putch
	rc
	lda	col
	ani	7
	jnz	ptab
	ret

;	a new line: CR LF, and --More-- at the end of a page; CY set if the reader said stop
newl:	mvi	a,cr
	call	cout
	mvi	a,lf
	call	cout
	xra	a
	sta	col
	lda	lines
	inr	a
	sta	lines
	cpi	rows
	jnc	more
	ora	a		;not yet: no stop
	ret
more:	lxi	h,smore
	call	pz
mo1:	call	poll
	call	keyin
	ora	a
	jz	mo1
	push	psw
	lxi	h,sunmore
	call	pz
	pop	psw
	cpi	'q'
	jz	mostop
	cpi	'Q'
	jz	mostop
	cpi	1bh
	jz	mostop
	cpi	cr
	mvi	a,rows-1	;Return: one line more
	jz	mo2
	xra	a		;else a page
mo2:	sta	lines
	ora	a
	ret
mostop:	stc
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

;	---- the data ----

nomsg:	db	'No modem on this machine.',cr,lf,'$'
musage:	db	'FINGER user@host, FINGER @host (who is on), host:port for a'
	db	'nother port.',cr,lf,'$'
mnodir:	db	'No FINGER.DIR on this disk.',cr,lf,'$'
mnosuch:db	'No such line in FINGER.DIR.',cr,lf,'$'
mpick:	db	'FINGER n asks one of these, FINGER user@host any other.',cr,lf,'$'
dirname:db	'FINGER  DIR'
mcancel:db	'Given up.',0
mnoans:	db	'No answer.',0
sbra:	db	'[',0
sket:	db	']',cr,lf,0
smore:	db	27,'[7m--More--',27,'[0m',0
sunmore:db	cr,27,'[K',0
scrlf:	db	cr,lf,0
sport:	db	':79',0
sate0:	db	'ATE0',cr,0
sate1:	db	'ATE1',cr,0
rhead:	dw	0
rtail:	dw	0
t0:	dw	0
tlim:	dw	0
lptr:	dw	0
savesp:	dw	0
lines:	db	0
nth:	db	0
col:	db	0
user:	db	0
	ds	42
dialbuf:db	'ATDT'
	ds	72
lbuf:	ds	80
cmdarg:	ds	72
fcb:	ds	36
	ds	128
stktop	equ	$
dirbuf:	ds	2176		;FINGER.DIR: 2K read at most (below the ring at 2000h)
dirend	equ	dirbuf+2048
	end
