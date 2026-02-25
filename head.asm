.EMPTYFILL $FF

.IFNDEF ROMBANKS
	.DEFINE ROMBANKS 1
.ELIF ROMBANKS < 1
	.FAIL "Can't have less than one ROM bank!"
.ENDIF

; SMS Bank layout
.ROMBANKMAP
	BANKSTOTAL ROMBANKS

.IF ROMBANKS == 1
	BANKSIZE $8000
.ELSE
	BANKSIZE $4000
.ENDIF

	BANKS ROMBANKS
.ENDRO

; Slot aliases
.DEFINE SLOT_ROM  0

.IF ROMBANKS == 1
	.DEFINE SLOT_RAM  1
.ELSE
	.DEFINE SLOT_ROM2 1
	.DEFINE SLOT_ROM3 2
	.DEFINE SLOT_RAM  3
.ENDIF

; SMS Memory layout
.MEMORYMAP
	DEFAULTSLOT SLOT_ROM

.IF ROMBANKS == 1
	SLOT SLOT_ROM  $0000 $8000 ; 32KB
.ELSE
	SLOT SLOT_ROM  $0000 $4000 ; 16KB
	SLOT SLOT_ROM2 $4000 $4000
	SLOT SLOT_ROM3 $8000 $4000
.ENDIF

	SLOT SLOT_RAM  $C000 $2000 ; 8KB
.ENDME

.INCLUDE "regs.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; System memory area
.RAMSECTION "SYSTEM_RAM" SLOT SLOT_RAM FORCE
	PORT_3E    db ; BIOS' copy
	STATUS     db ; RV......
	FRAMENUM   db ; Frame counter
	VBLANK_INT dw ; Pointer to VBlank handler
	RASTER_INT dw ; Pointer to Line Interrupt handler
	PAUSE_INT  dw ; Pointer to Pause Interrupt (NMI) handler
.ENDS

; Status flags
.DEFINE SF_READY  7
.DEFINE SF_VBLANK 6

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.MACRO sleep
	halt
	nop
.ENDM

.MACRO exr
	.dw $08D9
.ENDM

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.BANK 0 SLOT SLOT_ROM
.ORG $0000 ; Reset
Reset:
	di
	im 1 ; interrupt mode 1: jump to $0038
	ld SP, $DFF0
	jr Init

.ORG $0008
VSync:
	push HL
	ld HL, STATUS
	set SF_READY, (HL)
	jr fnVSYNC

.ORG $0010
	di
-	jr -
	.DSB 5, $00

.ORG $0018
	di
-	jr -
	.DSB 5, $00

.ORG $0020
	di
-	jr -
	.DSB 5, $00

.ORG $0028
	di
-	jr -
	.DSB 5, $00

.ORG $0030
	di
	push AF
	push HL
	ld HL, STATUS
	jr LockUp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.ORG $0038 ; IRQ (VBlank)
IRQ:
	exr

	in A, (IO_VDPSTAT) ; acknowledge interrupt
	rla ; check interrupt source
	jp NC, LineInterrupt

	; Check System status flags
	ld HL, STATUS
	ld A, (HL)
	xor $80
	and $C0
	jr NZ, @exit
	or $C0
	ld (HL), A

	; Run VBlank handler
	ld HL, (VBLANK_INT)
	call CallPointer

	; Increase frame counter
	ld HL, FRAMENUM
	inc (HL)

	; Clear VBlank flags
	ld L, <STATUS
	ld A, (HL)
	and $3F
	ld (HL), A

@exit:
	exr
	ei
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

CallPointer:
	jp HL

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.ORG $0066 ; NMI (Pause button)
NMI:
	push AF
	push HL

	ld HL, (PAUSE_INT)
	call CallPointer

	pop HL
	pop AF
	retn

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fnVSYNC:
	push AF
-	sleep
	ld A, (HL)
	and $C0
	jr NZ, -
	pop AF
	pop HL
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Init:
	; Initialize system RAM
	ld HL, PORT_3E+1
	ld DE, PORT_3E+2
	ld BC, 7
	ld (HL), $00
	ldir

	; Initialize VDP
	in A, (IO_VDPSTAT) ; reset write flag
	ld HL, VDPInitData
	ld BC, (_sizeof_VDPInitData<<8)+IO_VDPCTRL
	otir

	; Set I/O ports state
	ld A, $AF
	out (IO_IOCTRL), A

	; Set empty interrupt handlers
	ld HL, VBLANK_INT
	ld DE, EmptyInt
	ld B, 3
-	ld (HL), E
	inc HL
	ld (HL), D
	inc HL
	djnz -

	; Jump to main routine
	jp Main

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

EmptyInt:
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LineInterrupt:
	in A, (IO_VCOUNT) ; get current scanline
	ld HL, (RASTER_INT)
	call CallPointer

	exr
	ei
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LockUp:
	ld A, (HL) ; keep old System Status
	ld (HL), $FF

	; Lock until unlocked by debugger
-	cp (HL)
	jr Z, -

	pop HL
	pop AF
	ei
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PutHex:
	ld B, A ; keep
	rra
	rra
	rra
	rra
	call PutHexLo
	ld A, B ; restore

PutHexLo:
	or $F0
	ld E, A
	ld D, $00

	ld A, (DE) ; get char
	ld (HL), A ; write result
	inc HL     ; increase pointer
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

VDPInitData:
	.DW VDPREG_MODECTRL1|$06 ; [R0]
	.DW VDPREG_MODECTRL2|$00 ; [R1]
	.DW VDPREG_NTBASE|$FF    ; [R2] Nametable base address: $3800
	.DW VDPREG_OAMBASE|$FF   ; [R5] Sprite Attribute Table base: $3F00
	.DW VDPREG_SPGBASE|$FB   ; [R6] Sprite Pattern base address: Lower 8KB
	.DW VDPREG_BGCOLOR|$F0   ; [R7] Border color index: 0
	.DW VDPREG_XSCROLL|$00   ; [R8] Horizontal scroll: 0
	.DW VDPREG_YSCROLL|$00   ; [R9] Vertical scroll: 0
	.DW VDPREG_LINECNT|$FF   ; [RA] Raster Match interrupt: 255

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.ORG $00F0
HexChars:
	.DB "0123456789ABCDEF"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; SMS Header
.SMSHEADER
	PRODUCTCODE   $49, $58, 0
	VERSION       1
	RESERVEDSPACE 32, 32
	REGIONCODE    4
.ENDSMS
