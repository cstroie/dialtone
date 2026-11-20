;	GOPHER: a Gopher client for the modem port
;
;	A>GOPHER		the home menu: the holes of GOPHER.DIR
;	A>GOPHER host[:port][/type/selector]	there at once (gopher:// may lead)
;
;	A menu shows its items numbered: type the number and Return to follow
;	one (a text, another menu, a search). Space and N the next page, P or
;	- the one before, B back, G go to an address, H home, R again, W saves
;	what is shown to a file, Q quits, ? lists the keys. Esc stops a page that
;	is coming; at a G or search prompt Ctrl-P and Ctrl-N bring back the last 10.
;	A page is read whole (at the line's speed), then shown; nothing is kept
;	but the way back, so B reads the page before again.
;
;	GOPHER.DIR: a hole per line, host[:port][/type/selector] and a name.
;	Plain TCP: the bridge passes port 70 raw.
;
;	Copyright (c) 2026 Costin Stroie, MIT licence.

bdos	equ	0005h
conio	equ	6		;direct console I/O: E = 0FFh reads a key (A = 0: none)
print	equ	9
closef	equ	16
openf	equ	15
delete	equ	19
readsq	equ	20
writsq	equ	21
makef	equ	22
setdma	equ	26
clk	equ	20		;the clock port: OUT latches, IN reads the record
mst	equ	6		;modem status: bit 0 byte waiting, bit 1 may send, bit 2 carrier
mctl	equ	6		;modem control: bit 0 DTR
mdat	equ	7		;modem data
cr	equ	13
lf	equ	10
tab	equ	9
rmask	equ	03h		;the ring is 1K: its offsets wrap at 0400h
rows	equ	22		;rows of a page (2 to 23)
maxent	equ	1500		;lines of a page that can be shown
hmax	equ	8		;the way back: so many places
nhst	equ	10		;lines typed at a prompt kept for Ctrl-P (G, the searches)
;	a place: its type, port, the first row shown, the host, the selector
ltype	equ	0
lport	equ	1
ltop	equ	3
lhost	equ	8
lsel	equ	72
lsize	equ	256

	org	100h
	lxi	h,0
	dad	sp
	shld	savesp
	lxi	sp,stktop
	in	mst
	cpi	0ffh		;nothing answers: no modem here
	lxi	d,nomsg
	jz	quitm
	lhld	6		;the page is read into the room up to the BDOS
	dcr	h
	mvi	l,0
	shld	docend
	call	getarg
	call	minit
	xra	a
	sta	hcnt
	sta	nlen
	lxi	h,0
	shld	msg
	lda	cmdarg
	ora	a
	jz	start1
	lxi	h,cmdarg
	lxi	d,cur
	call	paddr
	jc	start1
	call	fetch
	jnc	view
	shld	msg
start1:	call	home
view:	call	index
	lhld	cur+ltop
	shld	top
vdraw:	call	draw
vprom:	call	prompt
vkey:	call	poll
	call	keyin
	ora	a
	jz	vkey
	cpi	'0'
	jc	vk1
	cpi	'9'+1
	jc	vdigit
vk1:	cpi	cr
	jz	venter
	cpi	8
	jz	vbksp
	cpi	7fh
	jz	vbksp
	cpi	1bh
	jz	vesc
	cpi	'?'		;before the upper case below: ? is the help
	jz	vhelp
	cpi	' '
	jz	vnext
	cpi	'-'
	jz	vprev
	ani	5fh		;upper case
	cpi	'N'
	jz	vnext
	cpi	'P'
	jz	vprev
	cpi	'B'
	jz	vback
	cpi	'U'
	jz	vback
	cpi	'G'
	jz	vgo
	cpi	'H'
	jz	vhome
	cpi	'R'
	jz	vagain
	cpi	'W'
	jz	vwrite
	cpi	'Q'
	jz	vquit
	jmp	vkey

;	a digit of the number of an item
vdigit:	mov	b,a
	lda	nlen
	cpi	4
	jnc	vkey
	mov	e,a
	mvi	d,0
	inr	a
	sta	nlen
	lxi	h,nbuf
	dad	d
	mov	m,b
	mov	a,b
	call	cout
	jmp	vkey
vbksp:	lda	nlen
	ora	a
	jz	vkey
	dcr	a
	sta	nlen
	lxi	h,sbs
	call	pz
	jmp	vkey
vesc:	xra	a
	sta	nlen
	jmp	vprom

;	?: the keys, on a page of their own; any key goes back to the page
vhelp:	xra	a
	sta	nlen
	lxi	h,scls
	call	pz
	lxi	h,hgoph
	call	hlines
	call	anykey
	jmp	vdraw

;	B: back the way we came
vback:	xra	a
	sta	nlen
	lda	hcnt
	ora	a
	lxi	h,mnoback
	jz	vmsg
	call	hpop
	lda	cur+ltype
	cpi	'H'
	jz	vb1
	call	fetch
	jnc	view
	shld	msg
vb1:	call	home
	jmp	view

;	G: go to an address
vgo:	xra	a
	sta	nlen
	lxi	h,pgo
	call	input
	jc	vprom
	jz	vprom
	lxi	h,ibuf
	lxi	d,newl
	call	paddr
	lxi	h,mbadad
	jc	vmsg
	call	going		;(it goes on to the new page)

;	H: home
vhome:	xra	a
	sta	nlen
	lhld	top
	shld	cur+ltop
	call	hpush
	call	home
	jmp	view

;	R: the same page again
vagain:	xra	a
	sta	nlen
	lda	cur+ltype
	cpi	'H'
	jz	vhome
	lhld	top
	shld	cur+ltop
	call	fetch
	jnc	view
	shld	msg
	jmp	view		;what came (if anything) is shown

vquit:	call	mfini
	lxi	h,sbye
	call	pz
exit:	lhld	savesp
	sphl
	ret
quitm:	mvi	c,print
	call	bdos
	jmp	exit

;	follow item HL (1 is the first line of the page)
follow:	mov	a,h
	ora	l
	jz	fnone
	dcx	h
	xchg
	lhld	nlines
	mov	a,e
	sub	l
	mov	a,d
	sbb	h
	jnc	fnone
	lda	mode
	cpi	'0'
	jz	fnone		;a text has no items
	xchg
	dad	h
	lxi	d,idxt
	dad	d
	mov	e,m
	inx	h
	mov	d,m
	xchg			;HL = the line
	mov	a,m
	cpi	'0'
	jz	fl1
	cpi	'1'
	jz	fl1
	cpi	'7'
	jz	fl1
fnone:	lxi	h,mnosuch
	shld	msg
	ret
fl1:	sta	newl+ltype
	inx	h
	call	field		;the name: past it
	lxi	d,newl+lsel
	mvi	b,180
	call	fcopy
	lxi	d,newl+lhost
	mvi	b,63
	call	fcopy
	push	h
	call	rdnum
	pop	h
	jnc	fl2
	lxi	d,70
fl2:	xchg
	shld	newl+lport
	lda	newl+ltype
	cpi	'7'
	jnz	going
	lxi	h,psearch	;a search: the words go after a tab
	call	input
	rc
	rz
	lxi	h,newl+lsel
fl3:	mov	a,m
	ora	a
	jz	fl4
	inx	h
	jmp	fl3
fl4:	mvi	m,tab
	inx	h
	xchg
	lxi	h,ibuf
	mvi	b,70
fl5:	mov	a,m
	stax	d
	ora	a
	jz	going
	inx	h
	inx	d
	dcr	b
	jnz	fl5
	xra	a
	stax	d
;	NEWL is where to go: the way back keeps where we are
going:	lhld	top
	shld	cur+ltop
	call	hpush
	lxi	h,newl
	lxi	d,cur
	call	copyl
	lxi	h,0
	shld	cur+ltop
	call	fetch
	jnc	gn1
	shld	msg		;no: back where we were (the page is still there)
	call	hpop
gn1:	pop	h		;the caller's return: straight to the new page
	jmp	view

;	HL in a menu line: past the next tab (or at the end of the line)
field:	mov	a,m
	cpi	lf
	rz
	ora	a
	rz
	inx	h
	cpi	tab
	rz
	jmp	field
;	copy the field at HL to DE (B at most), 0 after it; HL past its tab
fcopy:	mov	a,m
	cpi	lf
	jz	fc2
	ora	a
	jz	fc2
	inx	h
	cpi	tab
	jz	fc2
	cpi	cr
	jz	fcopy
	stax	d
	inx	d
	dcr	b
	jnz	fcopy
	call	field
fc2:	xra	a
	stax	d
	ret

;	---- the page: read, indexed, shown ----

;	read the place CUR into the page: CY set and HL what went wrong if the call failed
fetch:	lxi	h,cur+lport	;the port in decimal after a colon
	mov	e,m
	inx	h
	mov	d,m
	xchg
	lxi	d,pbuf
	mvi	a,':'
	stax	d
	inx	d
	call	wnum
	xra	a
	stax	d
	call	rowmsg
	lxi	h,mdialg
	call	pz
	lxi	h,cur+lhost
	call	pz
	lxi	h,cur+lhost
	lxi	d,pbuf
	call	mkdial
	call	mdial
	rc
	lxi	h,cur+lsel	;the selector, CR LF
	call	txz
	lxi	h,scrlf
	call	txz
	call	rowmsg
	lxi	h,mread
	call	pz
	lhld	docbeg
	shld	dptr
	lxi	h,0
	shld	count
	xra	a
	sta	utf
fe1:	call	poll
	call	rget
	jnc	fe2
	in	mst
	ani	4
	jz	fe9		;the host has hung up: it is all here
	call	keyin
	cpi	1bh
	jnz	fe1
	jmp	fe8		;Esc: what came is enough
fe2:	call	keep
	jnc	fe1
fe8:	call	hangup		;the page is full, or Esc
	jmp	fe9a
fe9:	lxi	h,300		;the modem's NO CARRIER goes
	call	delay
	call	flush
fe9a:	lhld	dptr		;the page ends with a line end and a 0
	dcx	h
	mov	a,m
	inx	h
	cpi	lf
	jz	fe9b
	mvi	m,lf
	inx	h
fe9b:	mvi	m,0
	lda	cur+ltype
	cpi	'0'
	jz	fe9c
	mvi	a,'1'		;a menu, or what a search found
fe9c:	sta	mode
	ora	a
	ret

;	a byte from the host (A) into the page: CY set if the page is full
keep:	cpi	cr
	jz	kp9
	cpi	lf
	jz	kp1
	cpi	tab
	jz	kp1
	cpi	20h
	jc	kp9		;other control characters go
	cpi	7fh
	jc	kp1
	jz	kp9
	cpi	0c0h
	jc	kp9		;the inside of a UTF-8 character
	mvi	a,'?'		;its first byte: one ?
kp1:	lhld	dptr
	mov	m,a
	inx	h
	shld	dptr
	xchg
	lhld	docend
	dcx	h
	dcx	h
	mov	a,e
	sub	l
	mov	a,d
	sbb	h
	cmc
	rc			;full
	lhld	count		;the count on the bottom row, now and then
	inx	h
	shld	count
	mov	a,l
	ani	7fh
	jnz	kp9
	call	rowmsg
	lxi	h,mread
	call	pz
	lhld	count
	call	pnum
	lxi	h,mbytes
	call	pz
kp9:	ora	a
	ret

;	the lines of the page into IDXT: a text's lines cut at 79 columns
index:	lxi	h,0
	shld	nlines
	lhld	docbeg
ix1:	mov	a,m
	ora	a
	rz
	cpi	'.'		;a line of a dot alone: the end
	jnz	ix2
	inx	h
	mov	a,m
	dcx	h
	cpi	lf
	rz
ix2:	lda	mode
	cpi	'0'
	jz	ix2a
	mov	a,m		;an empty line of a menu: nothing
	cpi	lf
	jnz	ix2a
	inx	h
	jmp	ix1
ix2a:	call	addent
	rc
	lda	mode
	cpi	'0'
	jz	ixt
ix3:	mov	a,m		;a menu line: to the next
	inx	h
	cpi	lf
	jz	ix1
	ora	a
	jnz	ix3
	dcx	h
	jmp	ix1
ixt:	mvi	c,0		;the column
ixt1:	mov	a,m
	ora	a
	rz
	inx	h
	cpi	lf
	jz	ix1
	inr	c
	cpi	tab
	jnz	ixt2
	mov	a,c		;to the next column of eight
	dcr	a
	ori	7
	inr	a
	mov	c,a
ixt2:	mov	a,c
	cpi	79
	jc	ixt1
	mov	a,m		;79 columns: the rest is a line of its own
	cpi	lf
	jz	ixt1
	ora	a
	rz
	call	addent
	rc
	jmp	ixt
;	HL into the next place of IDXT (HL kept); CY set if it is full
addent:	push	h
	lhld	nlines
	lxi	d,maxent
	mov	a,l
	sub	e
	mov	a,h
	sbb	d
	cmc
	jc	ad9
	push	h
	inx	h
	shld	nlines
	pop	h
	dad	h
	lxi	d,idxt
	dad	d
	pop	d
	mov	m,e
	inx	h
	mov	m,d
	xchg
	ora	a
	ret
ad9:	pop	h
	ret

;	the top row: GOPHER, where we are
bar:	lxi	h,sbar
	call	pz
	mvi	a,70
	sta	room
	lda	cur+ltype
	cpi	'H'
	lxi	h,shome
	jz	ba2
	lxi	h,cur+lhost
	call	pzr
	lhld	cur+lport
	lxi	d,-70
	dad	d
	mov	a,h
	ora	l
	jz	ba1
	mvi	a,':'
	call	cr1
	lhld	cur+lport
	lxi	d,pbuf
	call	wnum
	xra	a
	stax	d
	lxi	h,pbuf
	call	pzr
ba1:	mvi	a,'/'
	call	cr1
	lda	cur+ltype
	call	cr1
	lxi	h,cur+lsel
ba2:	call	pzr
	lxi	h,sbarz
	jmp	pz
;	row HL of the page
prow:	dad	h
	lxi	d,idxt
	dad	d
	mov	e,m
	inx	h
	mov	d,m
	xchg
	mvi	a,79
	sta	room
	lda	mode
	cpi	'0'
	jz	ptext
	mov	a,m		;a menu line: its type
	inx	h
	cpi	'0'
	jz	pitem
	cpi	'1'
	jz	pitem
	cpi	'7'
	jz	pitem
	push	psw
	push	h
	lxi	h,s6sp
	call	pzr
	pop	h
	call	pname
	pop	psw
	cpi	'i'
	rz
	cpi	'3'
	rz
	push	psw		;a kind GOPHER does not show: (its type)
	lxi	h,sopen
	call	pzr
	pop	psw
	call	cr1
	mvi	a,')'
	jmp	cr1
pitem:	push	psw
	push	h
	lhld	ent		;its number, four wide
	inx	h
	mvi	a,' '
	sta	lead
	call	pnum4
	mvi	a,75
	sta	room
	lxi	h,s2sp
	call	pzr
	pop	h
	call	pname
	pop	psw
	cpi	'7'
	lxi	h,sask
	jz	pzr
	cpi	'1'
	rnz
	mvi	a,'/'
	jmp	cr1
;	the name of a menu line: up to its tab
pname:	mov	a,m
	cpi	tab
	rz
	cpi	lf
	rz
	ora	a
	rz
	call	cr1
	inx	h
	jmp	pname
;	a line of a text: tabs to columns of eight, 79 columns at most
ptext:	mvi	c,0
pt1:	mov	a,m
	cpi	lf
	rz
	ora	a
	rz
	inx	h
	cpi	tab
	jz	pt3
	inr	c
	call	cout
pt2:	mov	a,c
	cpi	79
	jc	pt1
	ret
pt3:	mvi	a,' '
	call	cout
	inr	c
	mov	a,c
	ani	7
	jz	pt2
	mov	a,c
	cpi	79
	jc	pt3
	ret

;	the bottom row: a word (if one waits), where in the page, the keys, the number typed
prompt:	call	rowmsg
	lhld	msg
	mov	a,h
	ora	l
	jz	pm1
	push	h
	lxi	h,srev
	call	pz
	pop	h
	call	pz
	lxi	h,snorm
	call	pz
	lxi	h,0
	shld	msg
pm1:	mvi	a,'['
	call	cout
	lhld	top
	inx	h
	call	pnum
	mvi	a,'-'
	call	cout
	lhld	top		;the last row shown
	lxi	d,rows
	dad	d
	xchg
	lhld	nlines
	mov	a,l
	sub	e
	mov	a,h
	sbb	d
	jc	pm2
	xchg
pm2:	call	pnum
	mvi	a,'/'
	call	cout
	lhld	nlines
	call	pnum
	lxi	h,skeys
	call	pz
	lda	nlen		;the number typed so far
	ora	a
	rz
	mov	b,a
	lxi	h,nbuf
pm3:	mov	a,m
	call	cout
	inx	h
	dcr	b
	jnz	pm3
	ret

;	---- the home menu: GOPHER.DIR made a menu ----

home:	mvi	a,'H'
	sta	cur+ltype
	mvi	a,'1'
	sta	mode
	lxi	h,0
	shld	cur+ltop
	lhld	docend		;the file is read into the last 4K of the room
	lxi	d,-4096
	dad	d
	shld	dirp
	call	loaddir
	jnc	hm0
	lhld	dirp		;no GOPHER.DIR: one hole
	xchg
	lxi	h,defdir
hm00:	mov	a,m
	stax	d
	inx	h
	inx	d
	ora	a
	jnz	hm00
hm0:	lhld	docbeg
	xchg
	lxi	h,shead		;the lines on top
	call	wstr
	lhld	dirp
hm1:	mov	a,m		;a line of the file: blanks before it go
	cpi	1ah
	jz	hm9
	ora	a
	jz	hm9
	cpi	21h
	jnc	hm2
	inx	h
	jmp	hm1
hm2:	push	d
	lxi	d,newl
	call	paddr
	pop	d
	jc	hm8		;not an address: the line goes
hm3:	mov	a,m
	cpi	' '
	jz	hm3a
	cpi	tab
	jnz	hm4
hm3a:	inx	h
	jmp	hm3
hm4:	lda	newl+ltype
	stax	d
	inx	d
	mvi	b,70
hm5:	mov	a,m		;the name, up to the end of the line
	cpi	20h
	jc	hm6
	stax	d
	inx	h
	inx	d
	dcr	b
	jnz	hm5
hm6:	shld	scan
	mvi	a,tab
	stax	d
	inx	d
	lxi	h,newl+lsel
	call	wstr
	mvi	a,tab
	stax	d
	inx	d
	lxi	h,newl+lhost
	call	wstr
	mvi	a,tab
	stax	d
	inx	d
	lhld	newl+lport
	call	wnum
	mvi	a,lf
	stax	d
	inx	d
	lhld	scan
hm8:	mov	a,m		;to the next line of the file
	ora	a
	jz	hm9
	cpi	1ah
	jz	hm9
	inx	h
	cpi	lf
	jnz	hm8
	jmp	hm1
hm9:	xra	a
	stax	d
	ret
;	an address at HL (gopher:// may lead), host[:port][/type[selector]], into the place at
;	DE: type 1 and port 70 if not given; HL after it. CY set if there is no host.
paddr:	xchg
	shld	lp
	xchg
	push	h		;gopher:// is skipped
	lxi	d,sproto
pa0:	ldax	d
	ora	a
	jz	pa0b
	mov	b,a
	mov	a,m
	call	lower
	cmp	b
	jnz	pa0a
	inx	h
	inx	d
	jmp	pa0
pa0a:	pop	h
	push	h
pa0b:	pop	d		;(thrown away)
	xchg
	lhld	lp
	mvi	m,'1'		;the type
	inx	h
	mvi	m,70		;the port
	inx	h
	mvi	m,0
	lxi	b,lsel-lport-1
	dad	b
	mvi	m,0		;no selector
	lhld	lp
	lxi	b,lhost
	dad	b
	xchg			;HL the text, DE the host
	mvi	b,63
pa1:	mov	a,m
	cpi	21h
	jc	pa2
	cpi	':'
	jz	pa2
	cpi	'/'
	jz	pa2
	call	lower
	stax	d
	inx	h
	inx	d
	dcr	b
	jnz	pa1
pa2:	xra	a
	stax	d
	mov	a,b
	cpi	63
	stc
	rz			;no host
	mov	a,m
	cpi	':'
	jnz	pa3
	inx	h
	call	rdnum
	jc	pa3
	push	h
	lhld	lp
	inx	h
	mov	m,e
	inx	h
	mov	m,d
	pop	h
pa3:	mov	a,m
	cpi	'/'
	jnz	pa9
	inx	h
	mov	a,m
	cpi	21h
	jc	pa9
	xchg
	lhld	lp
	mov	m,a		;the type
	lxi	b,lsel
	dad	b
	xchg
	inx	h
	mvi	b,180
pa4:	mov	a,m		;the selector, as it is
	cpi	21h
	jc	pa5
	stax	d
	inx	h
	inx	d
	dcr	b
	jnz	pa4
pa5:	xra	a
	stax	d
pa9:	ora	a
	ret

;	W: what is shown to a file, as CP/M text
vwrite:	xra	a
	sta	nlen
	mvi	a,1
	sta	noh		;a file name is not kept for Ctrl-P
	lxi	h,psave
	call	input
	mvi	a,0
	sta	noh
	jc	vprom
	jz	vprom
	call	mkfcb
	lxi	h,mbadfn
	jc	vmsg
	lxi	d,fcb
	mvi	c,delete
	call	bdos
	lxi	d,fcb
	mvi	c,makef
	call	bdos
	inr	a
	lxi	h,mdiskf
	jz	vmsg
	lxi	h,rec
	shld	recp
	lhld	docbeg
wr1:	mov	a,m
	ora	a
	jz	wr8
	inx	h
	cpi	lf
	jnz	wr2
	mvi	a,cr
	call	wbyte
	jc	wr9
	mvi	a,lf
wr2:	call	wbyte
	jc	wr9
	jmp	wr1
wr8:	mvi	a,1ah		;^Z, and the record filled with them
	call	wbyte
	jc	wr9
	lhld	recp
	lxi	d,rec
	mov	a,l
	cmp	e
	jz	wr8b
wr8a:	mvi	a,1ah
	call	wbyte
	jc	wr9
	lhld	recp
	lxi	d,rec
	mov	a,l
	cmp	e
	jnz	wr8a
wr8b:	lxi	d,fcb
	mvi	c,closef
	call	bdos
	lxi	d,80h
	mvi	c,setdma
	call	bdos
	lxi	h,msaved
	jmp	vmsg
wr9:	lxi	d,80h
	mvi	c,setdma
	call	bdos
	lxi	h,mdiskf
	jmp	vmsg
;	---- the page viewer ----
;	include view.asm		(build.js joins VIEW.ASM here: the copy on a disk is whole)

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
mcancel:db	'Given up.',0
mnoans:	db	'No answer.',0
mend:	db	'The end.',0
mtop:	db	'The top.',0
mnoback:db	'Nothing to go back to.',0
mnosuch:db	'No such item.',0
mbadad:	db	'Not an address: host[:port][/type/selector]',0
mbadfn:	db	'Not a file name.',0
mdiskf:	db	'The disk is full, or will not take it.',0
msaved:	db	'Saved.',0
mdialg:	db	'Dialing ',0
mread:	db	'Reading ... ',0
mbytes:	db	' bytes (Esc stops)',0
pgo:	db	'Go to (host[:port][/type/selector]): ',0
psearch:db	'Search for: ',0
psave:	db	'Save as (d:name.typ): ',0
shead:	db	'iGopher for CP/M: a number and Return follows an item.',tab,tab
	db	'home',tab,'70',lf,'i',tab,tab,'home',tab,'70',lf,0
defdir:	db	'gopher.floodgap.com Floodgap',lf,0
dirname:db	'GOPHER  DIR'
sproto:	db	'gopher://',0
sbye:	db	27,'[r',27,'[0m',27,'[2J',27,'[H',0
scls:	db	27,'[r',27,'[0m',27,'[2J',27,'[H',0
sbar:	db	27,'[1;1H',27,'[7m GOPHER  ',0
sbarz:	db	27,'[K',27,'[0m',0
shome:	db	'home (GOPHER.DIR)',0
srow:	db	27,'[24;1H',27,'[K',0
srev:	db	27,'[7m',0
snorm:	db	27,'[0m  ',0
skeys:	db	'] # Ret  Spc next  B back  G go  ? help  Q quit> ',0
s6sp:	db	'      ',0
s2sp:	db	'  ',0
sopen:	db	'  (',0
sask:	db	' <?>',0
sbs:	db	8,' ',8,0
scrlf:	db	cr,lf,0
sate0:	db	'ATE0',cr,0
sate1:	db	'ATE1',cr,0
rhead:	dw	0
rtail:	dw	0
t0:	dw	0
tlim:	dw	0
lptr:	dw	0
savesp:	dw	0
docbeg:	dw	doc
docend:	dw	0
dptr:	dw	0
count:	dw	0
nlines:	dw	0
top:	dw	0
ent:	dw	0
msg:	dw	0
lp:	dw	0
wp:	dw	0
recp:	dw	0
dirp:	dw	0
scan:	dw	0
mode:	db	'1'
nlen:	db	0
ipr:	dw	0		;the prompt of the line being typed
ihpos:	db	0		;the line of the history shown (0: the one being typed)
ihcnt:	db	0		;lines kept (nhst at most)
noh:	db	0		;1 while a file name is typed: not kept
ihist:	ds	nhst*80
;	?: the keys
hgoph:	dw	hg0,hg1,hg2,hg3,hg4,hg5,hg6,hg7,hg8,hg9,hg10,hg11,hg12,0
hg0:	db	27,'[1m','GOPHER: the keys (any key goes back to the page)',27,'[0m',0
hg1:	db	'  a number, then Return: follow that item (text, menu, search)',0
hg2:	db	'  Space, N, or Return: the next page     P, -: the page before',0
hg3:	db	'  B, U: back to the place before (its page is read again)',0
hg4:	db	'  G: go to an address   Ctrl-P, Ctrl-N: the ones typed before',0
hg5:	db	'  H: home (GOPHER.DIR)      R: this page again',0
hg6:	db	'  W: save the page shown as CP/M text (d:name.typ)',0
hg7:	db	'  Esc: stop a page that is coming     Q: quit',0
hg8:	db	'  ?: this help',0
hg9:	db	0
hg10:	db	27,'[1m','THE ROWS',27,'[0m',0
hg11:	db	'  The top row: the server and where you are.',0
hg12:	db	'  The bottom row: [first-last/total] of this page, the keys.',0
hcnt:	db	0
rcnt:	db	0
room:	db	0
lead:	db	0
utf:	db	0
nbuf:	ds	6
pbuf:	ds	8
dialbuf:db	'ATDT'
	ds	72
lbuf:	ds	80
cmdarg:	ds	72
ibuf:	ds	72
fcb:	ds	36
rec:	ds	128
cur:	ds	256
newl:	ds	256
	ds	256
stktop	equ	$
ring:	ds	1024
hist:	ds	2048
idxt:	ds	3000
doc	equ	$
	end
