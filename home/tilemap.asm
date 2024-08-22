ClearBGPalettes::
	call ClearPalettes 			; Fills wBGPals2 and wOBPals2 with $ff
WaitBGMap::
; Tell VBlank to update BG Map 0 tile indx
	ld a, 1 ; BG Map 0 tiles
	ldh [hBGMapMode], a
; Wait for it to do its magic
	ld c, 4						; 4 frames
	call DelayFrames			; Wait 4 VBlanks (frames)
	ret

WaitBGMap2::
	ldh a, [hCGB]
	and a
	jr z, .bg0

	ld a, 2
	ldh [hBGMapMode], a
	ld c, 4
	call DelayFrames

.bg0
	ld a, 1
	ldh [hBGMapMode], a
	ld c, 4
	call DelayFrames
	ret

IsCGB::
	ldh a, [hCGB]
	and a
	ret

ApplyTilemap::
	ldh a, [hCGB]
	and a
	jr z, .dmg

	ld a, [wSpriteUpdatesEnabled]
	cp FALSE
	jr z, .dmg

	ld a, 1
	ldh [hBGMapMode], a
	jr CopyTilemapAtOnce

.dmg
; WaitBGMap
	ld a, 1
	ldh [hBGMapMode], a
	ld c, 4
	call DelayFrames
	ret

CGBOnly_CopyTilemapAtOnce::
	ldh a, [hCGB]
	and a
	jr z, WaitBGMap

CopyTilemapAtOnce::
	jr _CopyTilemapAtOnce

CopyAttrmapAndTilemapToWRAMBank3: ; unreferenced
	farcall HDMATransferAttrmapAndTilemapToWRAMBank3
	ret

_CopyTilemapAtOnce:
	ldh a, [hBGMapMode]
	push af
	xor a
	ldh [hBGMapMode], a

	ldh a, [hMapAnims]
	push af
	xor a
	ldh [hMapAnims], a

.wait
	ldh a, [rLY]
	cp $80 - 1
	jr c, .wait

	di
	ld a, BANK(vBGMap2)
	ldh [rVBK], a
	hlcoord 0, 0, wAttrmap
	call .CopyBGMapViaStack
	ld a, BANK(vBGMap0)
	ldh [rVBK], a
	hlcoord 0, 0
	call .CopyBGMapViaStack

.wait2
	ldh a, [rLY]
	cp $80 - 1
	jr c, .wait2
	ei

	pop af
	ldh [hMapAnims], a
	pop af
	ldh [hBGMapMode], a
	ret

.CopyBGMapViaStack:
; Copy all tiles to vBGMap
	ld [hSPBuffer], sp
	ld sp, hl
	ldh a, [hBGMapAddress + 1]
	ld h, a
	ld l, 0
	ld a, SCREEN_HEIGHT
	ldh [hTilesPerCycle], a
	ld b, 1 << 1 ; not in v/hblank
	ld c, LOW(rSTAT)

.loop
rept SCREEN_WIDTH / 2
	pop de
; if in v/hblank, wait until not in v/hblank
.loop\@
	ldh a, [c]
	and b
	jr nz, .loop\@
; load vBGMap
	ld [hl], e
	inc l
	ld [hl], d
	inc l
endr

	ld de, BG_MAP_WIDTH - SCREEN_WIDTH
	add hl, de
	ldh a, [hTilesPerCycle]
	dec a
	ldh [hTilesPerCycle], a
	jr nz, .loop

	ldh a, [hSPBuffer]
	ld l, a
	ldh a, [hSPBuffer + 1]
	ld h, a
	ld sp, hl
	ret

SetDefaultBGPAndOBP::
; Inits the Palettes
; depending on the system the monochromes palettes or color palettes
	ldh a, [hCGB]
	and a
	jr nz, .SetDefaultBGPAndOBPForGameBoyColor
	ld a, %11100100
	ldh [rBGP], a
	ld a, %11010000
	ldh [rOBP0], a
	ldh [rOBP1], a
	ret

.SetDefaultBGPAndOBPForGameBoyColor:
	push de
	ld a, %11100100
	call DmgToCgbBGPals				; copy the 8 BG palettes in order 11100100 (i.e. 0-1-2-3) from wBGPals1 to wBGPals2
	lb de, %11100100, %11100100
	call DmgToCgbObjPals
	pop de
	ret

; Fills wBGPals2 and wOBPals2 with $ff
; Make all palettes white
ClearPalettes::

; CGB: make all the palette colors white
	ldh a, [hCGB]
	and a
	jr nz, .cgb

; DMG: just change palettes to 0 (white)
	xor a
	ldh [rBGP], a
	ldh [rOBP0], a
	ldh [rOBP1], a
	ret

.cgb
	ldh a, [rSVBK] ; wram bank select register
	push af

	; Fills wBGPals2 and wOBPals2 with $ff
	ld a, BANK(wBGPals2)
	ldh [rSVBK], a

; Fill wBGPals2 and wOBPals2 with $ffff (white)
	ld hl, wBGPals2
	ld bc, 16 palettes
	ld a, $ff
	call ByteFill

	pop af
	ldh [rSVBK], a

; Request palette update
	ld a, TRUE
	ldh [hCGBPalUpdate], a
	ret

GetMemSGBLayout::
	ld b, SCGB_DEFAULT
; b : layout index
GetSGBLayout::
; load sgb packets unless dmg

	ldh a, [hCGB]
	and a
	jr nz, .sgb		; hCGB != 0

	ldh a, [hSGB]
	and a
	ret z			; hSGB == 0

.sgb
	predef_jump LoadSGBLayout	; hCGB != 0 OR hSGB != 0

SetHPPal::
; Set palette for hp bar pixel length e at hl.
	call GetHPPal
	ld [hl], d
	ret

GetHPPal::
; Get palette for hp bar pixel length e in d.
	ld d, HP_GREEN
	ld a, e
	cp (HP_BAR_LENGTH_PX * 50 / 100) ; 24
	ret nc
	assert HP_GREEN + 1 == HP_YELLOW
	inc d
	cp (HP_BAR_LENGTH_PX * 21 / 100) ; 10
	ret nc
	assert HP_YELLOW + 1 == HP_RED
	inc d
	ret
