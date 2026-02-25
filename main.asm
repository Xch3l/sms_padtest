.INCLUDE "head.asm"

.DEFINE OAM         $DE00

; Uncomment to enable split-screen marker
;.DEFINE DEBUG_SPLIT

.DEFINE TILE_FILL   $C8
.DEFINE TILE_CORNER $C9
.DEFINE TILE_TOPBTM $CA
.DEFINE TILE_SIDE   $CB
.DEFINE TILE_BUTTON $CC
.DEFINE TILE_ARROW  $CE

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.RAMSECTION "RAM" SLOT SLOT_RAM
	PAUSE_BTN db
	RESET_BTN db

	PADTYP  db
	BDOWN   dsb 4
	TEXTBUF dsb 24
.ENDS

.MACRO VDPADDR
	.IF NARGS > 0
		ld DE, \1
	.ENDIF

	ld C, IO_VDPCTRL
	out (C), E
	out (C), D
	dec C
.ENDM

.SECTION "MAIN"

Main:
	; Set palette
	VDPADDR VDP_CRAM
	ld HL, Palette
	ld B, _sizeof_Palette
	otir

	; Load font (must follow palette)
	VDPADDR VDP_VRAMWR
	ld D, 128 ; chars

-	ld B, $08
--	ld A, (HL)
		out (C), A
		out (C), A
		out (C), E
		out (C), E
		inc HL
		djnz --
	dec D
	jr NZ, -

	; Load graphics (must follow Monofont)
	ld A, (>_sizeof_Tiles)+1
	ld B, <_sizeof_Tiles
-	otir
	dec A
	jr NZ, -

	; Clear screen(s)
	VDPADDR VDP_VRAMWR+$2800
	ld B, E
	ld D, ' '
	ld A, $0C

-	out (C), D
	out (C), E
	djnz -
	dec A
	jr NZ, -

	; Load layouts
	ld HL, Layout1
	ld DE, VDP_VRAMWR+$3B00
	call LoadLayout
	ld DE, VDP_VRAMWR+$3300
	call LoadLayout
	ld DE, VDP_VRAMWR+$2B00
	call LoadLayout

	ld DE, VDP_VRAMWR+$3A40
	call UnpackToVRAM

	; Set main screen
	ld HL, MainScreen
	ld DE, VDP_VRAMWR+$390E
	call UnpackToVRAM

	; Clear sprites buffer
	VDPADDR VDP_VRAMWR+$3F00
	ld HL, OAM
	ld B, $80
	ld A, $D0
-	out (C), A
	ld (HL), A
	inc HL
	djnz -

	; Set VBlank handler
	ld HL, VBLANK_INT
	ld (HL), <VBlank
	inc HL
	ld (HL), >VBlank

	; Set Pause handler
	ld HL, PAUSE_INT
	ld (HL), <PauseBtn
	inc HL
	ld (HL), >PauseBtn

	; Set scanline handler
	ld HL, RASTER_INT
	ld (HL), <ScreenSplit
	inc HL
	ld (HL), >ScreenSplit

	; Init memory
	ld HL, PAUSE_BTN
	ld DE, PAUSE_BTN+1
	ld BC, TEXTBUF-PAUSE_BTN
	ld (HL), $00
	ldir

	; Clear text buffer
	ld C, _sizeof_TEXTBUF
	ld (HL), $20
	ldir

	VDPADDR VDPREG_LINECNT|93 ; raster int every N lines
	VDPADDR VDPM1_MODE4|VDPM1_IE1
	VDPADDR VDPM2_ENABLE|VDPM2_LARGESPR
	ei ; enable interrupts

Loop:
	call GetPort

	ld HL, TEXTBUF

	; Write pad data
	ld DE, BDOWN
	ld C, _sizeof_BDOWN
-	ld A, (DE)
	inc DE
	push DE
	call PutHex
	pop DE
	dec C
	jr NZ, -

	ld A, (PADTYP)
	call PutHex

	ld IY, OAM
	ld IX, OAM+128
	call FlashButtons
	ld (IY+0), $D0 ; Flag last sprite

	rst VSync
	jp Loop

;-------------------------------

VBlank:
	; Load sprites
	VDPADDR VDP_VRAMWR+$3F00
	ld HL, OAM
	ld B, E
	otir

	; Show text
	VDPADDR VDP_VRAMWR+$3922
	ld HL, TEXTBUF
	ld B, 8
	ld A, 8
-	xor $08
	outi
	out (C), A
	outi
	out (C), A
	jr NZ, -

	VDPADDR VDP_VRAMWR+$396E
	ld B, 2
	xor A
-	outi
	out (C), A
	jr NZ, -

	; Restore nametable base
	VDPADDR VDPREG_NTBASE|VDP_NTBASE3800
	ret

;-------------------------------

FlashButtons:
	ld HL, ButtonLayouts@console

	ld A, (PAUSE_BTN)
	and A
	jr Z, +
	call @put2
	dec A
	ld (PAUSE_BTN), A
	jr ++
+	call @skip

++
	in A, (IO_PORT2)
	cpl
	bit 4, A ; Reset
	call @put2

	; Flash DPAD buttons
	ld HL, ButtonLayouts@dpad
	ld A, (BDOWN+1)

	rra ; up
	call @put

	rra ; down
	call @put

	rra ; left
	call @put

	rra ; right
	call @put

 ; Vary by type
	ld A, (PADTYP)
	and $03
	jr Z, @sms
	cp 1
	jr Z, @gen3
	cp 2
	jr Z, @gen6
	ret

@sms:
	ld HL, ButtonLayouts@sms
	ld A, (BDOWN+1)

	bit 4, A ; (1)
	call @put2
	bit 5, A ; (2)
	ret Z
	jr @put2

@gen3:
	ld HL, ButtonLayouts@gen3
	ld A, (BDOWN+1)

	bit 4, A ; (B)
	call @put2
	bit 5, A ; (C)
	call @put2

	ld A, (BDOWN+2)
	bit 4, A ; (A)
	call @put2
	bit 5, A ; (S)
	ret Z
	jr @put2

@gen6:
	ld HL, ButtonLayouts@gen6

	ld A, (BDOWN+1)
	bit 4, A ; (B)
	call @put2
	bit 5, A ; (C)
	call @put2

	ld A, (BDOWN+2)
	bit 4, A ; (A)
	call @put2
	bit 5, A ; (S)
	call @put2

	ld A, (BDOWN+3)
	bit 0, A ; (Z)
	call @put2
	bit 1, A ; (Y)
	call @put2
	bit 2, A ; (X)
	call @put2
	bit 3, A ; (M)
	ret Z
	jr @put2

@put:
	jr NC, @skip

	push AF

	ld A, (HL) ; y
	inc HL

	ld (IY+0), A
	inc IY

	ld A, (HL) ; x
	inc HL

	ld (IX+0), A
	inc IX
	ld A, TILE_BUTTON ; n
	ld (IX+0), A
	inc IX

	pop AF
	ret

@put2:
	jr Z, @skip

	push AF

	ld A, (HL) ; y
	inc HL

	ld (IY+0), A
	inc IY
	ld (IY+0), A
	inc IY

	ld A, (HL) ; x
	inc HL

	ld (IX+0), A
	add 8
	ld (IX+2), A

	ld A, TILE_BUTTON ; n
	ld (IX+1), A
	ld (IX+3), A

	inc IX
	inc IX
	inc IX
	inc IX

	pop AF
	ret

@skip:
	inc HL
	inc HL
	ret

;-------------------------------

LoadLayout:
	VDPADDR

	; Fill top section
	ld B, 7 ; top-left margin
	ld A, $20
-	out (C), A
	out (C), A
	djnz -

	ld D, TILE_CORNER ; top-left corner
	ld A, $10
	out (C), D
	out (C), A

	ld B, 16 ; top border
	inc D
-	out (C), D
	out (C), A
	djnz -

	ld A, $12 ; top-right corner
	dec D
	out (C), D
	out (C), A

	ld B, 7 ; top-right margin
	ld A, $20
-	out (C), A
	out (C), A
	djnz -

	; Fill middle section
	ld DE, TILE_SIDE<<8|$06
--	ld B, 7 ; left margin
		ld A, $20
-		out (C), A
		out (C), A
		djnz -

		ld A, $10 ; left border
		out (C), D
		out (C), A

		ld B, 16 ; layout content
-		outi
		out (C), A
		jr NZ, -

		ld A, $12 ; right border
		out (C), D
		out (C), A

		ld B, 7 ; right margin
		ld A, $20
-		out (C), A
		out (C), A
		djnz -

	dec E
	jr NZ, --

	; Fill bottom border
	ld B, 7 ; bottom left margin
	ld A, $20
-	out (C), A
	out (C), A
	djnz -

	ld D, TILE_CORNER ; bottom-left corner
	ld A, $14
	out (C), D
	out (C), A
	inc D

	ld B, 16; bottom border
-	out (C), D
	out (C), A
	djnz -

	dec D ; bottom-right corner
	ld A, $16
	out (C), D
	out (C), A

	ld A, $20
	ld B, 135
-	out (C), A
	out (C), A
	djnz -

	ret

;-------------------------------

GetPort:
	ld C, IO_IOCTRL

	; Toggle TH line twice
	ld A, $0D
	out (C), A
	ld A, $FD
	out (C), A

	ld HL, BDOWN
	ld B, 2
-	; Read with TH low
	ld A, $0D
	out (C), A
	in A, (IO_PORT1)
	cpl
	and $3F ; take off PORT2 bits
	ld (HL), A
	inc HL

	; Read with TH high
	ld A, $FD
	out (C), A
	in A, (IO_PORT1)
	cpl
	and $3F ; take off PORT2 bits
	ld (HL), A
	inc HL
	djnz -

	; Toggle TH line two more times
	;   completing the protocol
	ld A, $0D
	out (C), A
	ld A, $FD
	out (C), A

	; Load results
	ld HL, BDOWN
	ld B, (HL)
	inc HL
	ld C, (HL)
	inc HL
	ld D, (HL)
	inc HL
	ld E, (HL)

	; Process data
	ld A, B ; check SMS data
	cp C
	jr NZ, +
	cp D
	jr NZ, +
	cp E
	jr NZ, +
	xor A
	jr @save

+	; check GEN3 data
	ld A, B
	cp D
	jr NZ, +
	ld A, C
	cp E
	jr NZ, +
	ld A, $01
	jr @save

+	; check GEN6 data
	ld A, $02 ; assume GEN6 (!)

@save:
	ld (PADTYP), A
	ret

	; MasterSystem: FF FF FF FF
	; Rd. ; TH out ; TR in ; TL in ; D3 in ; D2 in ; D1 in ; D0 in
	; any ; n/a    ; 2     ; 1     ; Right ; Left  ; Down  ; Up

	; Genesis 3-button: F3 FF F3 FF
	; Rd. ; TH out ; TR in ; TL in ; D3 in ; D2 in ; D1 in ; D0 in
	; 1   ; 1      ; C     ; B     ; Right ; Left  ; Down  ; Up
	; 2   ; 0      ; Start ; A     ; 0     ; 0     ; Down  ; Up

	; Genesis 6-Button: F3 FF F0 FF
	; Rd. ; TH out ; TR in ; TL in ; D3 in ; D2 in ; D1 in ; D0 in
	; 1   ; 1      ; C     ; B     ; Right ; Left  ; Down  ; Up
	; 2   ; 0      ; Start ; A     ; 0     ; 0     ; Down  ; Up
	; 3   ; 1      ; C     ; B     ; Right ; Left  ; Down  ; Up
	; 4   ; 0      ; Start ; A     ; 0     ; 0     ; Down  ; Up
	; 5   ; 1      ; C     ; B     ; Right ; Left  ; Down  ; Up
	; 6   ; 0      ; Start ; A     ; 0     ; 0     ; 0     ; 0
	; 7   ; 1      ; C     ; B     ; Mode  ; X     ; Y     ; Z
	; 8   ; 0      ; Start ; A     ; ---   ; ---   ; ---   ; --- 

	; Button mapping
	;       01234567 01234567 01234567 01234567
	; SMS   UDLR12.. UDLR12.. UDLR12.. UDLR12..
	; GEN3  UD--AS.. UDLRBC.. UD--AS.. UDLRBC..
	; GEN6  UD--AS.. UDLRBC.. ----AS.. ZYXMBC..

;-------------------------------

PauseBtn:
	ld A, 15 ; ~.25sec
	ld (PAUSE_BTN), A
	ret

;-------------------------------

ScreenSplit:
	cp 160
	ret NC ; return after 1st raster int

	ld B, A
	ld HL, PageOffsets
	cp 80
	jr C, +

	; Split at lower part
	ld A, (PADTYP)
	and 3
	add L
	ld L, A
	jr NC, +
	inc H

+	ld D, >VDPREG_NTBASE
	ld E, (HL)
	ld C, IO_VDPCTRL
	out (C), E
	out (C), D

.IFDEF DEBUG_SPLIT
	; Scan sprites
	ld HL, OAM

-	ld A, (HL)
	cp $D0
	jr NC, +
	inc HL
	bit 6, L
	jr Z, -
	ret

+	dec B
	ld (HL), B
	push HL
	ld A, L
	add A
	add 128
	ld L, A
	ld (HL), 48
	inc HL
	ld (HL), TILE_ARROW

	pop HL
	inc HL
	ld (HL), $D0
.ENDIF

	ret

PageOffsets:
	.db <VDP_NTBASE3800
	.db <VDP_NTBASE3000
	.db <VDP_NTBASE2800
	.db <VDP_NTBASE3800

;-------------------------------

UnpackToVRAM:
	VDPADDR

@next:
	ld A, (HL)
	inc HL

	and A
	ret Z

	ld B, A
	rr B
	jr C, @copylen

@reptlen:
	ld D, (HL)
	inc HL
	ld E, (HL)
	inc HL

-	out (C), D
	out (C), E
	djnz -
	jp @next

@copylen:
	clc
	rr B
	jr C, @copytext

@copybytes:
	otir
	jp @next

@copytext:
	ld A, (HL) ; get attribute byte
	inc HL

-	outi
	out (C), A
	jr NZ, -
	jp @next

.ENDS

; Copies the text string to VRAM with a set attribute
;   up to 63 characters
.MACRO CTextDef ARGS attr, text
	.db text.length<<2|3
	.db attr, text
.ENDM

; Repeat writing the same VRAM word
;   up to 127 times
.MACRO CReptDef ARGS count, data
	.db count<<1
	.dw data
.ENDM

.MACRO CCopyDef ; Copy up to 31 VRAM words
	.db NARGS<<3|1

	.REPEAT NARGS
		.dw \1
		.SHIFT
	.ENDR
.ENDM

.MACRO CStopDef ; Repeat of 0 marks end of data
	.db $00
.ENDM

.SECTION "DATA" SUPERFREE

Palette:
	.db $00, $15, $2A, $3F, $10, $25, $3A, $33 ; set 1
	.db $33, $33, $33, $33, $33, $33, $33, $00
	.db $00, $0B, $33, $2A, $33, $33, $33, $33 ; set 2
	.db $33, $33, $33, $33, $33, $33, $33, $33

Monofont:
	.INCBIN "font_mono.bin"

Tiles:
	.INCBIN "tiles.bin"

.IFDEF DEBUG_SPLIT
	.HEX FF000000FE000000FC000000F8000000
	.HEX F0000000E0000000C000000080000000
	.DSB 32, 0
.ENDIF

MainScreen:
	CTextDef $10, "Pad data"
	CReptDef 24, $0020
	CTextDef $10, "Type"
	CStopDef

Layout1: ; SMS
	;    0 1 2 3 4 5 6 7 8 9 A B C D E F
	.HEX C8C8C8C8C8C8C8C8C8C8C8C8C8C8C8C8
	.HEX A8A9AAABC8C8C8C8C8C8C8C8C8C8C8C8
	.HEX ACADAEAFC8C8C8C8C8C8C8C8C8C8C8C8
	.HEX B0B1B2B3C8C8C8C8C8C8C88081C88485
	.HEX B4B5B6B7C8C8C8C8C8C8C88283C88687
	.HEX C8C8C8C8C8C8C8C8C8C8C8C8C8C8C8C8

Layout2: ; GEN3
	.HEX C8C8C8C8C8C8C8C8C8C8C8C8C8C8C8C8
	.HEX B8B9BABBC8C8C8C8C8C8A0A1C8C8C8C8
	.HEX BCBDBEBFC8C8C8C8C8C8C89899C88C8D
	.HEX C0C1C2C3C8C8C8C88889C89A9BC88E8F
	.HEX C4C5C6C7C8C8C8C88A8BC89E9FC8C8C8
	.HEX C8C8C8C8C8C8C8C8C8C8C8C8C8C8C8C8

Layout3: ; GEN6
	.HEX C8C8C8C8C8C8C8C8C8C8C89899C89495
	.HEX B8B9BABBC8C8C8C89091C89C9DC89697
	.HEX BCBDBEBFC8A2A3C89293C89E9FC8C8C8
	.HEX C0C1C2C3C8C8C8C8C8C8C89899C88C8D
	.HEX C4C5C6C7C8C8C8C88889C89A9BC88E8F
	.HEX C8C8C8C8C8A0A1C88A8BC89E9FC8C8C8

LayoutSMS: ; Console Reset/Pause
	CReptDef 12, $0020
	CCopyDef $1000|TILE_CORNER
	CReptDef 6, $1000|TILE_TOPBTM
	CCopyDef $1200|TILE_CORNER
	CReptDef 24, $0020
	CCopyDef $1000|TILE_SIDE, $10A4, $10A5, $10C8, $10C8, $10A6, $10A7, $1200|TILE_SIDE
	CReptDef 24, $0020
	CCopyDef $1400|TILE_CORNER
	CReptDef 6, $1400|TILE_TOPBTM
	CCopyDef $1600|TILE_CORNER
	CReptDef 12, $0020
	CStopDef

ButtonLayouts:
	; data is ypos, xpos, index is $B8

@console:
	.db $4B, $88 ; Pause
	.db $4B, $68 ; Reset

@dpad:
	.db $68, $4C ; up
	.db $86, $4C ; down
	.db $76, $41 ; left
	.db $76, $57 ; right

@sms: ; SMS layout
	.db $7F, $98 ; (1)
	.db $7F, $B0 ; (2)

@gen3: ; GEN3 layout
	.db $7B, $98 ; (B)
	.db $77, $B0 ; (C)
	.db $7F, $80 ; (A)
	.db $6B, $90 ; ( S )

@gen6: ; GEN6 layout
	.db $83, $98 ; (B)
	.db $7F, $B0 ; (C)
	.db $87, $80 ; (A)
	.db $8B, $68 ; ( S )
	.db $67, $B0 ; (Z)
	.db $6B, $98 ; (Y)
	.db $6F, $80 ; (X)
	.db $77, $68 ; ( M )

_dataend_:

.ENDS
