;	DIR.ASM: a directory file (TERM.DIR, IRC.DIR, MUD.DIR, FINGER.DIR) read and searched: shared by
;	TERM, IRC, MUD and FINGER. Not a program: build.js joins it into each where its include line is.
;

;	read IRC.DIR into DIRBUF (^Z ends it); CY set: no such file
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

;	CY set if A is a digit
isdig:	cpi	'0'
	jc	idn
	cpi	'9'+1
	jnc	idn
	stc
	ret
idn:	ora	a
	ret
