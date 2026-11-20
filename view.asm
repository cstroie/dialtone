;	VIEW.ASM: the page viewer of GOPHER, GEMINI and NEWS: the screen, the input line and its history,
;	the way back, numbers, saving to a file, the directory file.
;	Not a program: build.js joins it into each where its include line is.
;

;	a table of lines (0-ended, each a string), each on a row of its own
hlines:	mov	e,m
	inx	h
	mov	d,m
	inx	h
	mov	a,d
	ora	e
	rz
	push	h
	xchg
	call	pz
	lxi	h,scrlf
	call	pz
	pop	h
	jmp	hlines

;	wait for a key
anykey:	call	poll
	call	keyin
	ora	a
	jz	anykey
	ret

;	Return: follow the item numbered; with no number, the next page
venter:	lda	nlen
	ora	a
	jz	vnext
	lxi	h,nbuf		;the number into HL
	mov	b,a
	lxi	d,0
ve1:	push	h
	mov	h,d
	mov	l,e
	dad	h
	dad	h
	dad	d
	dad	h
	xchg
	pop	h
	mov	a,m
	sui	'0'
	add	e
	mov	e,a
	mvi	a,0
	adc	d
	mov	d,a
	inx	h
	dcr	b
	jnz	ve1
	xra	a
	sta	nlen
	xchg
	call	follow
	jmp	vdraw

vnext:	xra	a
	sta	nlen
	lhld	top		;another page if there is more below
	lxi	d,rows
	dad	d
	xchg
	lhld	nlines
	mov	a,e
	sub	l
	mov	a,d
	sbb	h
	lxi	h,mend
	jnc	vmsg
	xchg
	shld	top
	jmp	vdraw
vprev:	xra	a
	sta	nlen
	lhld	top
	mov	a,h
	ora	l
	lxi	h,mtop
	jz	vmsg
	lhld	top
	lxi	d,-rows
	dad	d
	jc	vp1		;no borrow: it stays at 0 or more
	lxi	h,0
vp1:	shld	top
	jmp	vdraw
vmsg:	shld	msg
	jmp	vprom

;	the place at HL to the one at DE
copyl:	mvi	b,0
cl1:	mov	a,m
	stax	d
	inx	h
	inx	d
	dcr	b
	jnz	cl1
	ret

;	the way back: CUR pushed (the oldest goes when it is full), and popped
hpush:	lda	hcnt
	cpi	hmax
	jc	hp1
	lxi	h,hist+lsize	;full: all move down one
	lxi	d,hist
	mvi	c,hmax-1
hp0:	call	copyl
	dcr	c
	jnz	hp0
	lda	hcnt
	dcr	a
	sta	hcnt
hp1:	call	hslot
	xchg
	lxi	h,cur
	call	copyl
	lda	hcnt
	inr	a
	sta	hcnt
	ret
hpop:	lda	hcnt
	dcr	a
	sta	hcnt
	call	hslot
	lxi	d,cur
	jmp	copyl

;	HL = the slot HCNT of the way back
hslot:	lda	hcnt
	mov	h,a
	mvi	l,0
	lxi	d,hist
	dad	d
	ret

;	the whole screen: the bar, a page of rows from TOP
draw:	lxi	h,scls
	call	pz
	call	bar
	lhld	top
	shld	ent
	mvi	a,rows
	sta	rcnt
dr1:	lhld	ent
	xchg
	lhld	nlines
	mov	a,e
	sub	l
	mov	a,d
	sbb	h
	rnc
	lxi	h,scrlf
	call	pz
	lhld	ent
	call	prow
	lhld	ent
	inx	h
	shld	ent
	lda	rcnt
	dcr	a
	sta	rcnt
	jnz	dr1
	ret

;	the text at HL, as much as ROOM says (a tab, the search words after it, as a space)
pzr:	mov	a,m
	ora	a
	rz
	inx	h
	cpi	tab
	jnz	pr1
	mvi	a,' '
pr1:	call	cr1
	jmp	pzr
cr1:	push	psw
	lda	room
	ora	a
	jz	cr2
	dcr	a
	sta	room
	pop	psw
	jmp	cout
cr2:	pop	psw
	ret

;	the cursor to the bottom row, the row cleared
rowmsg:	lxi	h,srow
	jmp	pz

;	a line typed on the bottom row after the text at HL, into IBUF: CY set if Esc, Z set if empty
input:	shld	ipr		;the prompt: Ctrl-P redraws the line after it
	xra	a
	sta	ihpos
	push	h
	call	rowmsg
	pop	h
	call	pz
	mvi	b,0
in1:	push	b
in2:	call	poll
	call	keyin
	ora	a
	jz	in2
	pop	b
	cpi	cr
	jz	in9
	cpi	10h		;Ctrl-P: the line before, Ctrl-N: the one after
	jz	ihprev
	cpi	0eh
	jz	ihnext
	cpi	1bh
	jz	in8
	cpi	8
	jz	in3
	cpi	7fh
	jz	in3
	cpi	' '
	jc	in1
	mov	c,a
	mov	a,b
	cpi	70
	jnc	in1
	mov	e,b
	mvi	d,0
	lxi	h,ibuf
	dad	d
	mov	m,c
	inr	b
	mov	a,c
	push	b
	call	cout
	pop	b
	jmp	in1
in3:	mov	a,b
	ora	a
	jz	in1
	dcr	b
	push	b
	lxi	h,sbs
	call	pz
	pop	b
	jmp	in1
in8:	stc
	ret
in9:	mov	e,b
	mvi	d,0
	lxi	h,ibuf
	dad	d
	mvi	m,0
	mov	a,b
	ora	a		;Z: nothing typed
	push	psw
	call	ihsave
	pop	psw
	ret

;	the line typed kept for Ctrl-P (not an empty one, not a file name: noh)
ihsave:	lda	noh
	ora	a
	rnz
	lda	ibuf
	ora	a
	rz
	lxi	h,ihist+(nhst-1)*80	;all move down one (from the end: the copy overlaps)
	lxi	d,ihist+nhst*80-1
	lxi	b,(nhst-1)*80
ihs1:	dcx	h
	mov	a,m
	stax	d
	dcx	d
	dcx	b
	mov	a,b
	ora	c
	jnz	ihs1
	lxi	h,ibuf
	lxi	d,ihist
ihs2:	mov	a,m
	stax	d
	inx	h
	inx	d
	ora	a
	jnz	ihs2
	lda	ihcnt
	cpi	nhst
	rnc
	inr	a
	sta	ihcnt
	ret

;	Ctrl-P: the line before (the empty line after the newest); Ctrl-N: the one after
ihprev:	lda	ihpos
	lxi	h,ihcnt
	cmp	m
	jnc	in1
	inr	a
	sta	ihpos
	jmp	ihget
ihnext:	lda	ihpos
	ora	a
	jz	in1
	dcr	a
	sta	ihpos

;	the line ihpos (1 the newest; 0 the empty one) into IBUF, the line redrawn, B its length
ihget:	lda	ihpos
	mvi	b,0
	ora	a
	jnz	ihg0
	lxi	h,ibuf
	mvi	m,0
	jmp	ihg3
ihg0:	dcr	a
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
	lxi	d,ihist
	dad	d
	lxi	d,ibuf
ihg1:	mov	a,m
	stax	d
	ora	a
	jz	ihg3
	inx	h
	inx	d
	inr	b
	jmp	ihg1
ihg3:	push	b
	call	rowmsg
	lhld	ipr
	call	pz
	lxi	h,ibuf
	call	pz
	pop	b
	jmp	in1

;	the 0-ended text at HL to DE (the 0 left out)
wstr:	mov	a,m
	ora	a
	rz
	stax	d
	inx	h
	inx	d
	jmp	wstr

;	read GOPHER.DIR to DIRP (^Z ends it); CY set if there is none
loaddir:lxi	h,fcb
	call	clrfcb
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
	stc
	rz
	lhld	dirp
ld2:	push	h
	xchg
	mvi	c,setdma
	call	bdos
	lxi	d,fcb
	mvi	c,readsq
	call	bdos
	pop	h
	ora	a
	jnz	ld3
	lxi	d,128
	dad	d
	push	h
	xchg
	lhld	docend
	lxi	b,-130
	dad	b
	mov	a,e
	sub	l
	mov	a,d
	sbb	h
	pop	h
	jc	ld2
ld3:	mvi	m,1ah
	lxi	d,80h
	mvi	c,setdma
	call	bdos
	ora	a
	ret
clrfcb:	mvi	c,36
	xra	a
cf1:	mov	m,a
	inx	h
	dcr	c
	jnz	cf1
	ret

;	HL at decimal digits: their value in DE (5 at most), HL after them; CY set if there are none
rdnum:	lxi	d,0
	mvi	c,0
rn1:	mov	a,m
	sui	'0'
	jc	rn9
	cpi	10
	jnc	rn9
	push	h
	mov	h,d		;DE = DE * 10 + A
	mov	l,e
	dad	h
	dad	h
	dad	d
	dad	h
	mov	e,a
	mvi	d,0
	dad	d
	xchg
	pop	h
	inx	h
	inr	c
	mov	a,c
	cpi	5
	jc	rn1
rn9:	mov	a,c
	ora	a
	stc
	rz
	cmc
	ret

lower:	cpi	'A'
	rc
	cpi	'['
	rnc
	adi	20h
	ret

;	HL in decimal to DE (no 0 after it); DE after it
wnum:	xchg
	shld	wp
	xchg
	xra	a
	sta	lead
	lxi	d,10000
	call	wdig
	lxi	d,1000
	call	wdig
	lxi	d,100
	call	wdig
	lxi	d,10
	call	wdig
	mov	a,l
	adi	'0'
	call	wput
	xchg
	lhld	wp
	xchg
	ret
wdig:	mvi	b,'0'-1
wd1:	inr	b
	mov	a,l
	sub	e
	mov	l,a
	mov	a,h
	sbb	d
	mov	h,a
	jnc	wd1
	dad	d
	mov	a,b
	cpi	'0'
	jnz	wd2
	lda	lead
	ora	a
	rz
wd2:	sta	lead
	mov	a,b
wput:	push	h
	lhld	wp
	mov	m,a
	inx	h
	shld	wp
	pop	h
	ret

;	HL in decimal on the console: no zeros before it (PNUM), or four wide (PNUM4)
pnum:	xra	a
	sta	lead
	lxi	d,10000
	call	pdig
	jmp	pn3
pnum4:	mvi	a,' '
	sta	lead
pn3:	lxi	d,1000
	call	pdig
	lxi	d,100
	call	pdig
	lxi	d,10
	call	pdig
	mov	a,l
	adi	'0'
	jmp	cout
pdig:	mvi	b,'0'-1
pg1:	inr	b
	mov	a,l
	sub	e
	mov	l,a
	mov	a,h
	sbb	d
	mov	h,a
	jnc	pg1
	dad	d
	mov	a,b
	cpi	'0'
	jnz	pg2
	lda	lead		;a zero in front: nothing, a blank, or 0 once it has begun
	ora	a
	rz
	jmp	cout
pg2:	mvi	a,'0'
	sta	lead
	mov	a,b
	jmp	cout

;	a byte (A) into the record, written when it is full: CY set if the disk is (HL kept)
wbyte:	push	h
	lhld	recp
	mov	m,a
	inx	h
	shld	recp
	mov	a,l
	sui	(rec+128) and 0ffh
	jnz	wb9
	lxi	h,rec
	shld	recp
	lxi	d,rec
	mvi	c,setdma
	call	bdos
	lxi	d,fcb
	mvi	c,writsq
	call	bdos
	ora	a
	pop	h
	stc
	rnz
	ora	a
	ret
wb9:	pop	h
	ora	a
	ret

;	IBUF ([d:]name[.typ]) into FCB; CY set if there is no name
mkfcb:	lxi	h,fcb
	call	clrfcb
	lxi	h,fcb+1
	mvi	c,11
mf0:	mvi	m,' '
	inx	h
	dcr	c
	jnz	mf0
	lxi	h,ibuf
	inx	h
	mov	a,m
	dcx	h
	cpi	':'
	jnz	mf1
	mov	a,m
	call	upper
	sui	'A'-1
	sta	fcb
	inx	h
	inx	h
mf1:	lxi	d,fcb+1
	mvi	b,8
	mvi	c,0
mf2:	mov	a,m
	cpi	'.'
	jz	mf3
	cpi	21h
	jc	mf5
	call	upper
	stax	d
	inx	d
	inx	h
	inr	c
	dcr	b
	jnz	mf2
mf2a:	mov	a,m		;a name longer than 8: the rest goes
	cpi	'.'
	jz	mf3
	cpi	21h
	jc	mf5
	inx	h
	jmp	mf2a
mf3:	inx	h
	lxi	d,fcb+9
	mvi	b,3
mf4:	mov	a,m
	cpi	21h
	jc	mf5
	call	upper
	stax	d
	inx	d
	inx	h
	dcr	b
	jnz	mf4
mf5:	mov	a,c
	ora	a
	stc
	rz
	cmc
	ret
upper:	cpi	'a'
	rc
	cpi	'{'
	rnc
	sui	20h
	ret
