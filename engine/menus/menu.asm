_2DMenu_::
	ld hl, CopyMenuData
	ld a, [wMenuData_2DMenuItemStringsBank]
	rst FarCall

	call Draw2DMenu
	call UpdateSprites
	call ApplyTilemap
	call Get2DMenuSelection
	ret

_InterpretBattleMenu::
	ld hl, CopyMenuData
	ld a, [wMenuData_2DMenuItemStringsBank]
	rst FarCall

	call Draw2DMenu
	farcall MobileTextBorder
	call UpdateSprites
	call ApplyTilemap
	call Get2DMenuSelection
	ret

_InterpretMobileMenu::
	ld hl, CopyMenuData
	ld a, [wMenuData_2DMenuItemStringsBank]
	rst FarCall

	call Draw2DMenu
	farcall MobileTextBorder
	call UpdateSprites
	call ApplyTilemap
	call Init2DMenuCursorPosition
	ld hl, w2DMenuFlags1
	set 7, [hl]
.loop
	call DelayFrame
	farcall Function10032e
	ld a, [wcd2b]
	and a
	jr nz, .quit
	call MobileMenuJoypad
	ld a, [wMenuJoypadFilter]
	and c
	jr z, .loop
	call Mobile_GetMenuSelection
	ret

.quit
	ld a, [w2DMenuNumCols]
	ld c, a
	ld a, [w2DMenuNumRows]
	call SimpleMultiply
	ld [wMenuCursorPosition], a
	and a
	ret

Draw2DMenu:
	xor a
	ldh [hBGMapMode], a
	call MenuBox
	call Place2DMenuItemStrings
	ret

Get2DMenuSelection:
	call Init2DMenuCursorPosition
	call StaticMenuJoypad
	call MenuClickSound
Mobile_GetMenuSelection:
	ld a, [wMenuDataFlags]
	bit 1, a
	jr z, .skip
	call GetMenuJoypad
	bit SELECT_F, a
	jr nz, .quit1

.skip
	ld a, [wMenuDataFlags]
	bit 0, a
	jr nz, .skip2
	call GetMenuJoypad
	bit B_BUTTON_F, a
	jr nz, .quit2

.skip2
	ld a, [w2DMenuNumCols]
	ld c, a
	ld a, [wMenuCursorY]
	dec a
	call SimpleMultiply
	ld c, a
	ld a, [wMenuCursorX]
	add c
	ld [wMenuCursorPosition], a
	and a
	ret

.quit1
	scf
	ret

.quit2
	scf
	ret

Get2DMenuNumberOfColumns:
	ld a, [wMenuData_2DMenuDimensions]
	and $f
	ret

Get2DMenuNumberOfRows:
	ld a, [wMenuData_2DMenuDimensions]
	swap a
	and $f
	ret

Place2DMenuItemStrings:
	ld hl, wMenuData_2DMenuItemStringsAddr
	ld e, [hl]
	inc hl
	ld d, [hl]
	call GetMenuTextStartCoord
	call Coord2Tile
	call Get2DMenuNumberOfRows
	ld b, a
.row
	push bc
	push hl
	call Get2DMenuNumberOfColumns
	ld c, a
.col
	push bc
	ld a, [wMenuData_2DMenuItemStringsBank]
	call Place2DMenuItemName
	inc de
	ld a, [wMenuData_2DMenuSpacing]
	ld c, a
	ld b, 0
	add hl, bc
	pop bc
	dec c
	jr nz, .col
	pop hl
	ld bc, 2 * SCREEN_WIDTH
	add hl, bc
	pop bc
	dec b
	jr nz, .row
	ld hl, wMenuData_2DMenuFunctionAddr
	ld a, [hli]
	ld h, [hl]
	ld l, a
	or h
	ret z
	ld a, [wMenuData_2DMenuFunctionBank]
	rst FarCall
	ret

Init2DMenuCursorPosition:
	call GetMenuTextStartCoord
	ld a, b
	ld [w2DMenuCursorInitY], a
	dec c
	ld a, c
	ld [w2DMenuCursorInitX], a
	call Get2DMenuNumberOfRows
	ld [w2DMenuNumRows], a
	call Get2DMenuNumberOfColumns
	ld [w2DMenuNumCols], a
	call .InitFlags_a
	call .InitFlags_b
	call .InitFlags_c
	ld a, [w2DMenuNumCols]
	ld e, a
	ld a, [wMenuCursorPosition]
	ld b, a
	xor a
	ld d, 0
.loop
	inc d
	add e
	cp b
	jr c, .loop
	sub e
	ld c, a
	ld a, b
	sub c
	and a
	jr z, .reset1
	cp e
	jr z, .okay1
	jr c, .okay1
.reset1
	ld a, 1
.okay1
	ld [wMenuCursorX], a
	ld a, [w2DMenuNumRows]
	ld e, a
	ld a, d
	and a
	jr z, .reset2
	cp e
	jr z, .okay2
	jr c, .okay2
.reset2
	ld a, 1
.okay2
	ld [wMenuCursorY], a
	xor a
	ld [wCursorOffCharacter], a
	ld [wCursorCurrentTile], a
	ld [wCursorCurrentTile + 1], a
	ret

.InitFlags_a:
	xor a
	ld hl, w2DMenuFlags1
	ld [hli], a
	ld [hld], a
	ld a, [wMenuDataFlags]
	bit 5, a
	ret z
	set 5, [hl]
	set 4, [hl]
	ret

.InitFlags_b:
	ld a, [wMenuData_2DMenuSpacing]
	or $20
	ld [w2DMenuCursorOffsets], a
	ret

.InitFlags_c:
	ld hl, wMenuDataFlags
	ld a, A_BUTTON
	bit 0, [hl]
	jr nz, .skip
	or B_BUTTON
.skip
	bit 1, [hl]
	jr z, .skip2
	or SELECT
.skip2
	ld [wMenuJoypadFilter], a
	ret

_StaticMenuJoypad::
	call Place2DMenuCursor
_ScrollingMenuJoypad::
; Reset bit 7 of w2DMenuFlags2
	ld hl, w2DMenuFlags2
	res 7, [hl]
	ldh a, [hBGMapMode]
	push af
	; Update time of day palettes and cursor position until a button
	; that matches wMenuJoypadFilter is pressed 
	call MenuJoypadLoop
	pop af
	ldh [hBGMapMode], a
	ret

MobileMenuJoypad:
	ld hl, w2DMenuFlags2
	res 7, [hl]
	ldh a, [hBGMapMode]
	push af
	call Move2DMenuCursor
	call Do2DMenuRTCJoypad
	jr nc, .skip_joypad
	call _2DMenuInterpretJoypad
.skip_joypad
	pop af
	ldh [hBGMapMode], a
	call GetMenuJoypad
	ld c, a
	ret

Function241d5: ; unreferenced
	call Place2DMenuCursor
.loop
	call Move2DMenuCursor
	call HDMATransferTilemapToWRAMBank3 ; should be farcall
	call .loop2
	jr nc, .done
	call _2DMenuInterpretJoypad
	jr c, .done
	ld a, [w2DMenuFlags1]
	bit 7, a
	jr nz, .done
	call GetMenuJoypad
	ld c, a
	ld a, [wMenuJoypadFilter]
	and c
	jr z, .loop

.done
	ret

.loop2
	call Menu_WasButtonPressed
	ret c
	ld c, 1
	ld b, 3
	call AdvanceMobileInactivityTimerAndCheckExpired ; should be farcall
	ret c
	farcall Function100337
	ret c
	ld a, [w2DMenuFlags1]
	bit 7, a
	jr z, .loop2
	and a
	ret

MenuJoypadLoop:
.loop
	; Draw menu cursor
	call Move2DMenuCursor
	call .BGMap_OAM
	; Read the RTC and update the palettes
	call Do2DMenuRTCJoypad
	jr nc, .done	; No button pressed?
	; Update wMenuCursorX and wMenuCursorY
	call _2DMenuInterpretJoypad
	jr c, .done
	ld a, [w2DMenuFlags1]
	bit 7, a
	jr nz, .done
	; Exit loop if any relevant button was pressed
	call GetMenuJoypad
	ld b, a
	ld a, [wMenuJoypadFilter]
	and b
	jr z, .loop

.done
	ret

.BGMap_OAM:
	ldh a, [hOAMUpdate]
	push af
	; Set the hOAMUpdate flag to 1. See vblank.asm
	ld a, $1
	ldh [hOAMUpdate], a
	call WaitBGMap
	pop af
	ldh [hOAMUpdate], a
	xor a
	ldh [hBGMapMode], a
	ret

; Reads the RTC to update the in-game time, updates the BG and OBJ palettes
; based on the time of the day, packs the joypad state into a and sets the
; carry flag if a button was pressed
Do2DMenuRTCJoypad:
.loopRTC
	call UpdateTimeAndPals
	call Menu_WasButtonPressed
	ret c
	ld a, [w2DMenuFlags1]
	bit 7, a
	jr z, .loopRTC
	and a	; Update flags
	ret

; Packs the joypad state into a and sets the carry flag if a button was pressed
Menu_WasButtonPressed:
	ld a, [w2DMenuFlags1]
	bit 6, a
	jr z, .skip_to_joypad
	callfar PlaySpriteAnimationsAndDelayFrame

.skip_to_joypad
	call JoyTextDelay
	call GetMenuJoypad
	; No button pressed?
	and a
	ret z
	vc_hook Forbid_printing_photo_studio
	scf
	vc_hook Forbid_printing_PC_Box
	ret

; Moves the cursor in the menu and handles the wrap-around (if enabled)
; Sets the carry flag if the menu needs to be closed
_2DMenuInterpretJoypad:
	call GetMenuJoypad
	bit A_BUTTON_F, a
	jp nz, .a_b_start_select
	bit B_BUTTON_F, a
	jp nz, .a_b_start_select
	bit SELECT_F, a
	jp nz, .a_b_start_select
	bit START_F, a
	jp nz, .a_b_start_select
	bit D_RIGHT_F, a
	jr nz, .d_right
	bit D_LEFT_F, a
	jr nz, .d_left
	bit D_UP_F, a
	jr nz, .d_up
	bit D_DOWN_F, a
	jr nz, .d_down
	and a
	ret

.set_bit_7
	ld hl, w2DMenuFlags2
	set 7, [hl]
	scf		; Set carry flag
	ret

.d_down
	ld hl, wMenuCursorY
	ld a, [w2DMenuNumRows]
	cp [hl]
	jr z, .check_wrap_around_down
	inc [hl]
	xor a	; Reset carry flag
	ret

.check_wrap_around_down
	ld a, [w2DMenuFlags1]
	bit 5, a
	jr nz, .wrap_around_down
	bit 3, a
	jp nz, .set_bit_7
	xor a
	ret

.wrap_around_down
	ld [hl], $1
	xor a
	ret

.d_up
	ld hl, wMenuCursorY
	ld a, [hl]
	dec a
	jr z, .check_wrap_around_up
	ld [hl], a
	xor a
	ret

.check_wrap_around_up
	ld a, [w2DMenuFlags1]
	bit 5, a
	jr nz, .wrap_around_up
	bit 2, a
	jp nz, .set_bit_7
	xor a
	ret

.wrap_around_up
	ld a, [w2DMenuNumRows]
	ld [hl], a
	xor a
	ret

.d_left
	ld hl, wMenuCursorX
	ld a, [hl]
	dec a
	jr z, .check_wrap_around_left
	ld [hl], a
	xor a
	ret

.check_wrap_around_left
	ld a, [w2DMenuFlags1]
	bit 4, a
	jr nz, .wrap_around_left
	bit 1, a
	jp nz, .set_bit_7
	xor a
	ret

.wrap_around_left
	ld a, [w2DMenuNumCols]
	ld [hl], a
	xor a
	ret

.d_right
	ld hl, wMenuCursorX
	ld a, [w2DMenuNumCols]
	cp [hl]
	jr z, .check_wrap_around_right
	inc [hl]
	xor a
	ret

.check_wrap_around_right
	ld a, [w2DMenuFlags1]
	bit 4, a
	jr nz, .wrap_around_right
	bit 0, a
	jp nz, .set_bit_7
	xor a
	ret

.wrap_around_right
	ld [hl], $1
	xor a
	ret

.a_b_start_select
	xor a
	ret

; Writes "▶" to wTilemap at the current cursor position
; Uses the following vars:
;	wCursorCurrentTile: wTilemap addr. of the cursor's prev. tile
;	wCursorOffCharacter: character used to "erease" the cursor from it's prev. tile
;	w2DMenuCursorInitY: cursor's initial row
;	w2DMenuCursorInitX: cursor's initial col
;	w2DMenuCursorOffsets: 
;	wMenuCursorY: cursor offset from w2DMenuCursorInitY
;	wMenuCursorX
Move2DMenuCursor:
	; hl <- addr. of the cursor's current tile in wTilemap
	ld hl, wCursorCurrentTile
	ld a, [hli]
	ld h, [hl]
	ld l, a
	; Load the tile character at the current cursor position into a
	ld a, [hl]
	; Compare the tile character with the cursor tile ("▶")
	cp "▶"
	jr nz, Place2DMenuCursor
	; Overwrite the current cursor tile with the character from wCursorOffCharacter
	ld a, [wCursorOffCharacter]
	ld [hl], a
Place2DMenuCursor:
	; hl ‹- Addr. of initial cursor position in wTilemap
	ld a, [w2DMenuCursorInitY]
	ld b, a
	ld a, [w2DMenuCursorInitX]
	ld c, a
	call Coord2Tile
	; Move tile addr. to the correct row 
	; c ‹- High nibble of w2DMenuCursorOffsets
	; b ‹- wMenuCursorY
	; a ‹- c*(b-1)
	ld a, [w2DMenuCursorOffsets]
	swap a
	and $f
	ld c, a
	ld a, [wMenuCursorY]
	ld b, a
	xor a
	dec b
	jr z, .got_row
.row_loop
	add c
	dec b
	jr nz, .row_loop

.got_row
	; hl ‹- hl + a*SCREEN_WIDTH
	ld c, SCREEN_WIDTH
	call AddNTimes
	; Move tile addr. to the right col.
	ld a, [w2DMenuCursorOffsets]
	and $f
	ld c, a
	ld a, [wMenuCursorX]
	ld b, a
	xor a
	dec b
	jr z, .got_col
.col_loop
	add c
	dec b
	jr nz, .col_loop

.got_col
	ld c, a
	add hl, bc
	; Update wTilemap and wCursorOffCharacter
	ld a, [hl]
	cp "▶"
	jr z, .cursor_on
	ld [wCursorOffCharacter], a
	ld [hl], "▶"

.cursor_on
	; wCursorCurrentTile <- cursor tile addr. in wTilemap
	ld a, l
	ld [wCursorCurrentTile], a
	ld a, h
	ld [wCursorCurrentTile + 1], a
	ret

_PushWindow::
	ldh a, [rSVBK]
	push af
	ld a, BANK(wWindowStack)
	ldh [rSVBK], a
	; de point to the current head of the windows stack
	ld hl, wWindowStackPointer
	ld e, [hl]
	inc hl
	ld d, [hl]
	; Push curr. addr. of win. stack head
	push de 								
	; Push wMenuHeader in the windows stack
	ld b, wMenuHeaderEnd - wMenuHeader
	ld hl, wMenuHeader
.loop
	ld a, [hli]
	ld [de], a
	dec de
	dec b
	jr nz, .loop
	; Done pushing (de now points to the top of the stack)

; Jump to .bit_6 if either bit 6 or 7 of wMenuFlags is set, otherwise jump to .not_bit_7
	ld a, [wMenuFlags]
	bit 6, a
	jr nz, .bit_6
	bit 7, a
	jr z, .not_bit_7

.bit_6	; Bit 6 or 7 is set
	; Set bit 0 of wWindowStackPointer
	; At this point wWindowStackPointer still points to the first byte (the flag byte) of the
	; menu header that was on the top of the stack
	ld hl, wWindowStackPointer
	ld a, [hli]
	ld h, [hl]
	ld l, a
	set 0, [hl]
	
	; draw the menu using the coordinates from the header.
	call MenuBoxCoord2Tile					; hl <- wTilemap addr. of the top-left corner
	call .copy
	call MenuBoxCoord2Attr
	call .copy
	jr .done

.not_bit_7
	; Reset bit 0 of 7:[wWindowStackPointer]
	pop hl ; Pop prev. addr. of win. stack head
	push hl
	ld a, [hld]
	ld l, [hl]
	ld h, a
	res 0, [hl]

.done
	; Update wWindowStackPointer
	pop hl									; pop prev. wWindowStackPointer
	call .ret ; empty function
	; Push prev. wWindowStackPointer to the top of the windows stack
	ld a, h
	ld [de], a
	dec de
	ld a, l
	ld [de], a
	dec de
	; Update wWindowStackPointer
	ld hl, wWindowStackPointer
	ld [hl], e
	inc hl
	ld [hl], d

	pop af
	ldh [rSVBK], a
	; Update wWindowStackSize
	ld hl, wWindowStackSize
	inc [hl]
	ret

; Pushes all the bytes of the menu from wTilemap/wAttrmap to the windows stack 
; hl : wTilemap/wAttrmap addr top-left corner
; de : head of the window stack 
.copy
	; b <- menu height + 1 
	; c <- menu width + 1
	call GetMenuBoxDims
	inc b
	inc c
	call .ret ; empty function

.row
	push bc
	push hl

.col
	ld a, [hli]
	ld [de], a
	dec de
	dec c
	jr nz, .col

	pop hl
	ld bc, SCREEN_WIDTH
	add hl, bc
	pop bc
	dec b
	jr nz, .row

	ret

.ret
	ret

_ExitMenu::
	xor a
	ldh [hBGMapMode], a

	ldh a, [rSVBK]
	push af
	ld a, BANK(wWindowStack)
	ldh [rSVBK], a

	; hl <= second and third bytes on the top of the stack
	call GetWindowStackTop
	; hl == 0?
	ld a, l
	or h
	jp z, Error_Cant_ExitMenu
	ld a, l
	ld [wWindowStackPointer], a
	ld a, h
	ld [wWindowStackPointer + 1], a
	call PopWindow
	ld a, [wMenuFlags]
	bit 0, a
	jr z, .loop
	ld d, h
	ld e, l
	call RestoreTileBackup

.loop
	call GetWindowStackTop
	ld a, h
	or l
	jr z, .done
	call PopWindow

.done
	pop af
	ldh [rSVBK], a
	ld hl, wWindowStackSize
	dec [hl]
	ret

RestoreOverworldMapTiles: ; unreferenced
	ld a, [wStateFlags]
	bit SPRITE_UPDATES_DISABLED_F, a
	ret z
	xor a ; sScratch
	call OpenSRAM
	hlcoord 0, 0
	ld de, sScratch
	ld bc, SCREEN_WIDTH * SCREEN_HEIGHT
	call CopyBytes
	call CloseSRAM
	call LoadOverworldTilemapAndAttrmapPals
	xor a ; sScratch
	call OpenSRAM
	ld hl, sScratch
	decoord 0, 0
	ld bc, SCREEN_WIDTH * SCREEN_HEIGHT
.loop
	ld a, [hl]
	cp $61
	jr c, .next
	ld [de], a
.next
	inc hl
	inc de
	dec bc
	ld a, c
	or b
	jr nz, .loop
	call CloseSRAM
	ret

Error_Cant_ExitMenu:
	ld hl, .WindowPoppingErrorText
	call PrintText
	call WaitBGMap
.infinite_loop
	jr .infinite_loop

.WindowPoppingErrorText:
	text_far _WindowPoppingErrorText
	text_end

_InitVerticalMenuCursor::
; Init w2DMenuCursorInitY
	ld a, [wMenuDataFlags]
	ld b, a
	ld hl, w2DMenuCursorInitY
	ld a, [wMenuBorderTopCoord]
	inc a
	bit 6, b
	jr nz, .skip_offset ; Skip only one row
	inc a
.skip_offset
	ld [hli], a						; hl : w2DMenuCursorInitX
; Init w2DMenuCursorInitX
	ld a, [wMenuBorderLeftCoord]
	inc a
	ld [hli], a						; hl : w2DMenuNumRows
; Init w2DMenuNumRows
	ld a, [wMenuDataItems]
	ld [hli], a
; Init w2DMenuNumCols
	ld a, 1
	ld [hli], a						; hl : w2DMenuFlags1
; Init w2DMenuFlags1
	ld [hl], $0
	bit 5, b
	jr z, .skip_bit_5
	set 5, [hl]
.skip_bit_5
	ld a, [wMenuFlags]
	bit 4, a
	jr z, .skip_bit_6
	set 6, [hl]
.skip_bit_6
	inc hl
; Init w2DMenuFlags2
	xor a
	ld [hli], a
; Init w2DMenuCursorOffsets
	ln a, 2, 0
	ld [hli], a
; Init wMenuJoypadFilter
	ld a, A_BUTTON
	bit 0, b
	jr nz, .skip_bit_1
	add B_BUTTON
.skip_bit_1
	ld [hli], a
; Init wMenuCursorY
	ld a, [wMenuCursorPosition]
	and a
	jr z, .load_at_the_top
	ld c, a
	ld a, [wMenuDataItems]
	cp c
	jr nc, .load_position
.load_at_the_top
	ld c, 1
.load_position
	ld [hl], c
	inc hl
; Init wMenuCursorX
	ld a, 1
	ld [hli], a
; Init wCursorOffCharacter, wCursorCurrentTile
	xor a
	ld [hli], a
	ld [hli], a
	ld [hli], a
	ret
