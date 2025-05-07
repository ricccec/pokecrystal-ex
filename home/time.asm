; Functions relating to the timer interrupt and the real-time-clock.

Timer:: ; unreferenced
	push af
	ldh a, [hMobile]
	and a
	jr z, .not_mobile
	call MobileTimer

.not_mobile
	pop af
	reti

LatchClock::
; latch clock counter data
	ld a, 0
	ld [MBC3LatchClock], a
	ld a, 1
	ld [MBC3LatchClock], a
	ret

UpdateTime::
	call GetClock
	call FixDays
	call FixTime
	farcall GetTimeOfDay
	ret

; store clock data in hRTCDayHi-hRTCSeconds
GetClock::

; enable clock r/w
	ld a, SRAM_ENABLE
	ld [MBC3SRamEnable], a

; clock data is 'backwards' in hram

	call LatchClock
	ld hl, MBC3SRamBank
	ld de, MBC3RTC

	ld [hl], RTC_S
	ld a, [de]
	maskbits 60
	ldh [hRTCSeconds], a

	ld [hl], RTC_M
	ld a, [de]
	maskbits 60
	ldh [hRTCMinutes], a

	ld [hl], RTC_H
	ld a, [de]
	maskbits 24
	ldh [hRTCHours], a

	ld [hl], RTC_DL
	ld a, [de]
	ldh [hRTCDayLo], a

	ld [hl], RTC_DH
	ld a, [de]
	ldh [hRTCDayHi], a

; unlatch clock / disable clock r/w
	call CloseSRAM
	ret

FixDays::
; fix day count
; mod by 140

; check if day count > 255 (bit 8 set)
	ldh a, [hRTCDayHi] ; DH
	bit 0, a
	jr z, .daylo
; reset dh (bit 8)
	res 0, a
	ldh [hRTCDayHi], a

; mod 140
; mod twice since bit 8 (DH) was set
; In this case, since bit 8 is set, we want to compute:
;     x = (256 + DL) mod 140
;
; We can express DL as (y + n * 140), where y = DL mod 140. Substituting this
; into the expression gives:
;     256 + DL = (116 + 140) + (y + n * 140) = 116 + y + n * 140
;
; So the final result becomes:
;     x = (116 + y + n * 140) mod 140 = (116 + y) mod 140
;
; To compute y = DL mod 140, we first subtract 140 from DL in a loop until the
; result becomes negative. This leaves ACC = y - 140, which is equivalent to:
;     256 + (y - 140) = 116 + y
;
; At this point, we only need to compute (116 + y) mod 140 to get x.
; In general, to compute a mod b without division, we subtract b from a
; repeatedly until the result becomes negative, then add b back once.
;
; Here, we subtract 140 from ACC until it becomes negative, then add 140 back.
; This gives us:
;     (116 + y) mod 140 = x

	ldh a, [hRTCDayLo]
.modh
	sub 140
	jr nc, .modh	; Result not negative
.modl
	sub 140
	jr nc, .modl
	add 140

; update dl
	ldh [hRTCDayLo], a

; flag for sRTCStatusFlags
	ld a, %01000000
	jr .set

.daylo
; quit if fewer than 140 days have passed
	ldh a, [hRTCDayLo]
	cp 140
	jr c, .quit

; mod 140
.mod
	sub 140
	jr nc, .mod
	add 140

; update dl
	ldh [hRTCDayLo], a

; flag for sRTCStatusFlags
	ld a, %00100000

.set
; update clock with modded day value
	push af
	call SetClock
	pop af
	scf
	ret

.quit
	xor a
	ret

FixTime::
; add ingame time (set at newgame) to current time
; store time in wCurDay, hHours, hMinutes, hSeconds

; second
	ldh a, [hRTCSeconds]
	ld c, a
	ld a, [wStartSecond]
	add c
	sub 60
	jr nc, .updatesec
	add 60
.updatesec
	ldh [hSeconds], a

; minute
	ccf ; carry is set, so turn it off
	ldh a, [hRTCMinutes]
	ld c, a
	ld a, [wStartMinute]
	adc c
	sub 60
	jr nc, .updatemin
	add 60
.updatemin
	ldh [hMinutes], a

; hour
	ccf ; carry is set, so turn it off
	ldh a, [hRTCHours]
	ld c, a
	ld a, [wStartHour]
	adc c
	sub 24
	jr nc, .updatehr
	add 24
.updatehr
	ldh [hHours], a

; day
	ccf ; carry is set, so turn it off
	ldh a, [hRTCDayLo]
	ld c, a
	ld a, [wStartDay]
	adc c
	ld [wCurDay], a
	ret

InitTimeOfDay::
	xor a
	ld [wStringBuffer2], a
	ld a, 0 ; useless
	ld [wStringBuffer2 + 3], a
	jr InitTime

InitDayOfWeek::
	call UpdateTime
	ldh a, [hHours]
	ld [wStringBuffer2 + 1], a
	ldh a, [hMinutes]
	ld [wStringBuffer2 + 2], a
	ldh a, [hSeconds]
	ld [wStringBuffer2 + 3], a
	jr InitTime ; useless

InitTime::
	farcall _InitTime
	ret

ClearClock::
	call .ClearhRTC
	call SetClock
	ret

.ClearhRTC:
	xor a
	ldh [hRTCSeconds], a
	ldh [hRTCMinutes], a
	ldh [hRTCHours], a
	ldh [hRTCDayLo], a
	ldh [hRTCDayHi], a
	ret

SetClock::
; set clock data from hram

; enable clock r/w
	ld a, SRAM_ENABLE
	ld [MBC3SRamEnable], a

; set clock data
; stored 'backwards' in hram

	call LatchClock
	ld hl, MBC3SRamBank
	ld de, MBC3RTC

; seems to be a halt check that got partially commented out
; this block is totally pointless
	ld [hl], RTC_DH
	ld a, [de]
	bit 6, a ; halt
	ld [de], a

; seconds
	ld [hl], RTC_S
	ldh a, [hRTCSeconds]
	ld [de], a
; minutes
	ld [hl], RTC_M
	ldh a, [hRTCMinutes]
	ld [de], a
; hours
	ld [hl], RTC_H
	ldh a, [hRTCHours]
	ld [de], a
; day lo
	ld [hl], RTC_DL
	ldh a, [hRTCDayLo]
	ld [de], a
; day hi
	ld [hl], RTC_DH
	ldh a, [hRTCDayHi]
	res 6, a ; make sure timer is active
	ld [de], a

; cleanup
	call CloseSRAM ; unlatch clock, disable clock r/w
	ret

ClearRTCStatus:: ; unreferenced
; clear sRTCStatusFlags
	xor a
	push af
	ld a, BANK(sRTCStatusFlags)
	call OpenSRAM
	pop af
	ld [sRTCStatusFlags], a
	call CloseSRAM
	ret

RecordRTCStatus::
; append flags to sRTCStatusFlags
	ld hl, sRTCStatusFlags
	push af
	ld a, BANK(sRTCStatusFlags)
	call OpenSRAM
	pop af
	or [hl]
	ld [hl], a
	call CloseSRAM
	ret

CheckRTCStatus::
; check sRTCStatusFlags
	ld a, BANK(sRTCStatusFlags)
	call OpenSRAM
	ld a, [sRTCStatusFlags]
	call CloseSRAM
	ret
