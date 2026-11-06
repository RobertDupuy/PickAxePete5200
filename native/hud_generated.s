.import _score_changed,_name_changed,_name_chars,_score,_high_score,hud_shadow
.export prepare_hud,commit_hud,hud_scene
src=$30
temp=$3e
glyph=$42
.segment "EXTRA"
.align 1024
hud_font:
.byte 0,0,0,0,0,0,0,0,80,80,80,80,80,80,80,80
.byte 10,10,40,40,40,40,40,40,168,168,10,10,10,10,10,10
.byte 40,40,40,40,10,10,0,0,10,10,10,10,168,168,0,0
.byte 0,0,2,2,0,0,0,0,160,160,160,160,160,160,160,160
.byte 0,0,0,0,2,2,0,0,160,160,160,160,168,168,0,0
.byte 2,2,10,10,0,0,0,0,168,168,10,10,40,40,160,160
.byte 2,2,10,10,10,10,0,0,128,128,0,0,170,170,0,0
.byte 10,10,40,40,0,0,2,2,168,168,10,10,10,10,168,168
.byte 0,0,40,40,10,10,0,0,40,40,40,40,40,40,42,42
.byte 40,40,40,40,40,40,170,170,40,40,40,40,40,40,0,0
.byte 42,42,40,40,40,40,10,10,170,170,0,0,0,0,168,168
.byte 10,10,40,40,40,40,42,42,168,168,10,10,0,0,168,168
.byte 42,42,0,0,0,0,0,0,170,170,10,10,40,40,160,160
.byte 2,2,10,10,40,40,0,0,128,128,0,0,0,0,0,0
.byte 10,10,40,40,40,40,10,10,168,168,10,10,10,10,170,170
.byte 15,15,60,60,60,60,60,60,252,252,15,15,15,15,15,15
.byte 60,60,60,60,15,15,0,0,15,15,15,15,252,252,0,0
.byte 0,0,3,3,0,0,0,0,240,240,240,240,240,240,240,240
.byte 0,0,0,0,3,3,0,0,240,240,240,240,252,252,0,0
.byte 3,3,15,15,0,0,0,0,252,252,15,15,60,60,240,240
.byte 3,3,15,15,15,15,0,0,192,192,0,0,255,255,0,0
.byte 15,15,60,60,0,0,3,3,252,252,15,15,15,15,252,252
.byte 0,0,60,60,15,15,0,0,60,60,60,60,60,60,63,63
.byte 60,60,60,60,60,60,255,255,60,60,60,60,60,60,0,0
.byte 63,63,60,60,60,60,15,15,255,255,0,0,0,0,252,252
.byte 15,15,60,60,60,60,63,63,252,252,15,15,0,0,252,252
.byte 63,63,0,0,0,0,0,0,255,255,15,15,60,60,240,240
.byte 3,3,15,15,60,60,0,0,192,192,0,0,0,0,0,0
.byte 15,15,60,60,60,60,15,15,252,252,15,15,15,15,255,255
.byte 192,192,192,192,192,192,192,192,192,192,192,192,192,192,0,0
.byte 0,0,192,192,192,192,192,192,192,192,192,192,0,0,0,0
.byte 0,0,0,0,0,0,192,192,0,0,0,0,192,192,0,0
.byte 0,0,192,192,0,0,0,0,0,0,0,0,0,0,42,42
.byte 0,0,160,160,40,40,170,170,40,40,160,160,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
hud_name_glyphs:
.byte 15,15,60,60,60,60,60,60,252,252,15,15,15,15,15,15
.byte 60,60,60,60,15,15,0,0,15,15,15,15,252,252,0,0
.byte 0,0,3,3,0,0,0,0,240,240,240,240,240,240,240,240
.byte 0,0,0,0,3,3,0,0,240,240,240,240,252,252,0,0
.byte 3,3,15,15,0,0,0,0,252,252,15,15,60,60,240,240
.byte 3,3,15,15,15,15,0,0,192,192,0,0,255,255,0,0
.byte 15,15,60,60,0,0,3,3,252,252,15,15,15,15,252,252
.byte 0,0,60,60,15,15,0,0,15,15,15,15,252,252,0,0
.byte 60,60,60,60,60,60,63,63,60,60,60,60,60,60,255,255
.byte 0,0,0,0,0,0,0,0,60,60,60,60,60,60,0,0
.byte 63,63,60,60,60,60,15,15,255,255,0,0,0,0,252,252
.byte 0,0,60,60,15,15,0,0,15,15,15,15,252,252,0,0
.byte 15,15,60,60,60,60,63,63,252,252,15,15,0,0,252,252
.byte 60,60,60,60,15,15,0,0,15,15,15,15,252,252,0,0
.byte 63,63,0,0,0,0,0,0,255,255,15,15,60,60,240,240
.byte 3,3,15,15,60,60,0,0,192,192,0,0,0,0,0,0
.byte 15,15,60,60,60,60,15,15,252,252,15,15,15,15,252,252
.byte 60,60,60,60,15,15,0,0,15,15,15,15,252,252,0,0
.byte 15,15,60,60,60,60,15,15,252,252,15,15,15,15,255,255
.byte 0,0,60,60,15,15,0,0,15,15,15,15,252,252,0,0
.byte 0,0,0,0,0,0,0,0,0,0,240,240,240,240,0,0
.byte 0,0,0,0,0,0,0,0,240,240,240,240,0,0,0,0
.byte 0,0,15,15,12,12,15,15,240,240,255,255,240,240,255,255
.byte 0,0,15,15,0,0,0,0,243,243,255,255,240,240,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 3,3,15,15,0,0,0,0,252,252,15,15,60,60,240,240
.byte 0,0,0,0,0,0,0,0,240,240,0,0,240,240,0,0
.byte 60,60,60,60,60,60,60,60,0,0,0,0,0,0,0,0
.byte 60,60,60,60,63,63,0,0,0,0,0,0,255,255,0,0
.byte 63,63,60,60,60,60,63,63,252,252,15,15,15,15,252,252
.byte 60,60,60,60,60,60,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,15,15,0,0,240,240,240,240,255,255
.byte 0,0,0,0,0,0,0,0,240,240,240,240,0,0,0,0
.byte 60,60,60,60,60,60,60,60,15,15,15,15,15,15,207,207
.byte 63,63,63,63,60,60,0,0,255,255,63,63,15,15,0,0
.byte 63,63,60,60,60,60,63,63,255,255,0,0,0,0,240,240
.byte 60,60,60,60,63,63,0,0,0,0,0,0,255,255,0,0
.byte 63,63,60,60,60,60,63,63,252,252,15,15,15,15,252,252
.byte 60,60,60,60,60,60,0,0,240,240,60,60,15,15,0,0
.byte 15,15,0,0,0,0,0,0,255,255,240,240,240,240,240,240
.byte 0,0,0,0,0,0,0,0,240,240,240,240,240,240,0,0
.byte 60,60,60,60,60,60,60,60,15,15,15,15,15,15,15,15
.byte 60,60,60,60,15,15,0,0,15,15,15,15,252,252,0,0
.byte 3,3,0,0,0,0,0,0,252,252,240,240,240,240,240,240
.byte 0,0,0,0,3,3,0,0,240,240,240,240,252,252,0,0
.byte 15,15,60,60,60,60,60,60,252,252,15,15,15,15,15,15
.byte 60,60,60,60,15,15,0,0,15,15,15,15,252,252,0,0
.byte 15,15,60,60,60,60,60,60,252,252,15,15,15,15,15,15
.byte 60,60,60,60,15,15,0,0,255,255,60,60,207,207,0,0
.byte 15,15,60,60,60,60,15,15,252,252,15,15,0,0,252,252
.byte 0,0,60,60,15,15,0,0,15,15,15,15,252,252,0,0
.byte 63,63,60,60,60,60,60,60,252,252,15,15,15,15,15,15
.byte 60,60,60,60,63,63,0,0,15,15,15,15,252,252,0,0
.byte 63,63,60,60,60,60,63,63,255,255,0,0,0,0,240,240
.byte 60,60,60,60,60,60,0,0,0,0,0,0,0,0,0,0
.byte 15,15,60,60,60,60,60,60,252,252,15,15,0,0,0,0
.byte 60,60,60,60,15,15,0,0,63,63,15,15,255,255,0,0
.byte 60,60,60,60,60,60,63,63,15,15,15,15,15,15,255,255
.byte 60,60,60,60,60,60,0,0,15,15,15,15,15,15,0,0
.byte 0,0,0,0,0,0,0,0,15,15,15,15,15,15,15,15
.byte 0,0,60,60,15,15,0,0,15,15,15,15,252,252,0,0
.byte 60,60,60,60,60,60,63,63,15,15,60,60,240,240,192,192
.byte 60,60,60,60,60,60,0,0,240,240,60,60,15,15,0,0
.byte 3,3,15,15,60,60,60,60,240,240,60,60,15,15,15,15
.byte 63,63,60,60,60,60,0,0,255,255,15,15,15,15,0,0
.byte 15,15,0,0,0,0,0,0,255,255,15,15,60,60,240,240
.byte 3,3,15,15,15,15,0,0,192,192,0,0,255,255,0,0
.byte 60,60,60,60,15,15,3,3,15,15,15,15,60,60,240,240
.byte 15,15,60,60,60,60,0,0,60,60,15,15,15,15,0,0
.byte 15,15,60,60,60,60,60,60,252,252,15,15,0,0,0,0
.byte 60,60,60,60,15,15,0,0,0,0,15,15,252,252,0,0
.byte 60,60,60,60,60,60,60,60,15,15,15,15,15,15,15,15
.byte 60,60,15,15,3,3,0,0,15,15,60,60,240,240,0,0
.byte 63,63,60,60,60,60,63,63,252,252,15,15,15,15,252,252
.byte 60,60,60,60,63,63,0,0,15,15,15,15,252,252,0,0
.byte 60,60,63,63,63,63,60,60,15,15,63,63,255,255,207,207
.byte 60,60,60,60,60,60,0,0,15,15,15,15,15,15,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,3,3,3,3,0,0,0,0,240,240,240,240,0,0
.byte 0,0,0,0,0,0,15,15,0,0,0,0,0,0,255,255
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,15,15,3,3,0,0,0,0,15,15,252,252,240,240
.byte 3,3,15,15,0,0,0,0,252,252,15,15,0,0,0,0
.byte 0,0,0,0,0,0,15,15,0,0,240,240,0,0,255,255
.byte 0,0,0,0,0,0,0,0,0,0,240,240,0,0,0,0
.byte 0,0,0,0,15,15,0,0,0,0,0,0,252,252,0,0
.byte 15,15,0,0,0,0,0,0,252,252,0,0,0,0,0,0
.byte 15,15,15,15,15,15,3,3,15,15,15,15,15,15,252,252
.byte 0,0,0,0,0,0,0,0,240,240,240,240,240,240,0,0
.byte 60,60,63,63,63,63,63,63,15,15,15,15,207,207,255,255
.byte 60,60,60,60,60,60,0,0,255,255,63,63,15,15,0,0
.byte 0,0,0,0,0,0,0,0,3,3,15,15,60,60,240,240
.byte 3,3,15,15,60,60,0,0,192,192,0,0,0,0,0,0
.byte 63,63,63,63,63,63,63,63,255,255,255,255,255,255,255,255
.byte 63,63,63,63,63,63,0,0,255,255,255,255,255,255,0,0
.byte 60,60,60,60,60,60,60,60,63,63,243,243,243,243,243,243
.byte 60,60,60,60,60,60,0,0,243,243,243,243,63,63,0,0
.byte 0,0,0,0,3,3,15,15,0,0,0,0,252,252,255,255
.byte 15,15,15,15,3,3,0,0,255,255,255,255,252,252,0,0
.byte 0,0,0,0,0,0,0,0,252,252,252,252,240,240,255,255
.byte 0,0,0,0,0,0,0,0,240,240,240,240,252,252,0,0
.byte 0,0,0,0,0,0,0,0,252,252,252,252,240,240,255,255
.byte 0,0,3,3,3,3,0,0,240,240,204,204,15,15,0,0
.byte 3,3,3,3,0,0,15,15,240,240,240,240,240,240,240,240
.byte 0,0,3,3,15,15,0,0,240,240,60,60,12,12,0,0
.byte 3,3,3,3,0,0,15,15,240,240,240,240,240,240,240,240
.byte 0,0,0,0,3,3,0,0,240,240,240,240,240,240,0,0
.byte 0,0,0,0,0,0,63,63,0,0,240,240,60,60,255,255
.byte 0,0,0,0,0,0,0,0,60,60,240,240,0,0,0,0
.byte 0,0,3,3,15,15,63,63,240,240,252,252,255,255,255,255
.byte 63,63,0,0,0,0,0,0,255,255,240,240,240,240,0,0
.byte 0,0,0,0,0,0,0,0,3,3,15,15,63,63,255,255
.byte 3,3,15,15,63,63,0,0,255,255,255,255,255,255,0,0
.byte 60,60,63,63,63,63,63,63,0,0,0,0,192,192,240,240
.byte 63,63,63,63,63,63,0,0,252,252,255,255,255,255,0,0
.byte 3,3,3,3,0,0,63,63,240,240,240,240,195,195,255,255
.byte 51,51,3,3,15,15,0,0,240,240,48,48,60,60,0,0
.byte 60,60,15,15,3,3,0,0,0,0,0,0,192,192,240,240
.byte 0,0,0,0,0,0,0,0,60,60,15,15,3,3,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,60,60,48,48
.byte 0,0,63,63,15,15,0,0,48,48,255,255,255,255,0,0
.byte 0,0,0,0,15,15,63,63,0,0,3,3,3,3,255,255
.byte 63,63,0,0,0,0,0,0,255,255,240,240,48,48,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,192,192
.byte 3,3,63,63,15,15,0,0,240,240,255,255,255,255,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,15,15
.byte 15,15,63,63,15,15,0,0,63,63,255,255,255,255,0,0
hud_digit_codes:
.byte 2,3,0,4,5,0,6,7,0,8,9,0,10,11,0,12
.byte 13,0,14,15,0,16,5,0,17,18,0,0,19,0,20,21
.byte 0,16,5,0,22,23,0,4,5,0,24,25,0,26,27,0
.byte 28,15,0,4,5,0,28,29,0,16,5,0,30,31,0,32
.byte 33,0,34,35,0,36,37,0,38,39,0,40,41,0,42,43
.byte 0,44,33,0,45,46,0,0,47,0,48,49,0,44,33,0
.byte 50,51,0,32,33,0,52,53,0,54,55,0,56,43,0,32
.byte 33,0,56,57,0,44,33,0
hud_tail_codes:
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,55,0,58,59
.byte 60,61,0,0,0,0,0,0,0,0,0,0,0,0,62,55
.byte 58,59,0,63,0,0,0,63,0,64,60,55,0,64,0,64
.assert hud_font=$e400, lderror, "HUD font address"
.assert hud_name_glyphs=$e800, lderror, "HUD name address"
.segment "RODATA"
hud_name_lo:
.byte 0,32,64,96,128,160,192,224,0,32,64,96,128,160,192,224
.byte 0,32,64,96,128,160,192,224,0,32,64,96,128,160,192,224
.byte 0,32,64,96,128,160,192,224,0,32,64,96,128,160,192,224
.byte 0,32,64,96,128,160,192,224,0,32,64,96,128,160,192,224
hud_name_hi:
.byte 232,232,232,232,232,232,232,232,233,233,233,233,233,233,233,233
.byte 234,234,234,234,234,234,234,234,235,235,235,235,235,235,235,235
.byte 236,236,236,236,236,236,236,236,237,237,237,237,237,237,237,237
.byte 238,238,238,238,238,238,238,238,239,239,239,239,239,239,239,239
.segment "BSS"
hud_dirty:.res 14
hud_ready:.res 84
hud_name_src_lo:.res 6
hud_name_src_hi:.res 6
.segment "CODE"
hud_scene:
 ldx #39
 lda #0
@clear:
 sta $9f18,x
 sta $9f40,x
 dex
 bpl @clear
 lda #1
 sta $9f1a
 sta $9f3e
 sta $9f42
 sta $9f66

 lda #65
 sta $9f24
 lda #66
 sta $9f25
 lda #0
 sta $9f4c
 lda #67
 sta $9f4d
 lda #$e4
 sta $d409
 rts
prepare_hud:
 lda _score_changed
 bne :+
 jmp @names_only
: lda #0
 sta _score_changed
 lda _high_score+0
 cmp hud_shadow+0
 beq :+
 sta hud_shadow+0
 asl a
 sta temp
 asl a
 clc
 adc temp
 tax
 lda hud_digit_codes+0,x
 sta hud_ready+0
 lda hud_digit_codes+1,x
 sta hud_ready+14
 lda hud_digit_codes+2,x
 sta hud_ready+28
 lda hud_digit_codes+3,x
 sta hud_ready+42
 lda hud_digit_codes+4,x
 sta hud_ready+56
 lda hud_digit_codes+5,x
 sta hud_ready+70
 lda #1
 sta hud_dirty+0
:
 lda _high_score+1
 cmp hud_shadow+1
 beq :+
 sta hud_shadow+1
 asl a
 sta temp
 asl a
 clc
 adc temp
 tax
 lda hud_digit_codes+0,x
 sta hud_ready+1
 lda hud_digit_codes+1,x
 sta hud_ready+15
 lda hud_digit_codes+2,x
 sta hud_ready+29
 lda hud_digit_codes+3,x
 sta hud_ready+43
 lda hud_digit_codes+4,x
 sta hud_ready+57
 lda hud_digit_codes+5,x
 sta hud_ready+71
 lda #1
 sta hud_dirty+1
:
 lda _high_score+2
 cmp hud_shadow+2
 beq :+
 sta hud_shadow+2
 asl a
 sta temp
 asl a
 clc
 adc temp
 tax
 lda hud_digit_codes+0,x
 sta hud_ready+2
 lda hud_digit_codes+1,x
 sta hud_ready+16
 lda hud_digit_codes+2,x
 sta hud_ready+30
 lda hud_digit_codes+3,x
 sta hud_ready+44
 lda hud_digit_codes+4,x
 sta hud_ready+58
 lda hud_digit_codes+5,x
 sta hud_ready+72
 lda #1
 sta hud_dirty+2
:
 lda _high_score+3
 cmp hud_shadow+3
 beq :+
 sta hud_shadow+3
 asl a
 sta temp
 asl a
 clc
 adc temp
 tax
 lda hud_digit_codes+0,x
 sta hud_ready+3
 lda hud_digit_codes+1,x
 sta hud_ready+17
 lda hud_digit_codes+2,x
 sta hud_ready+31
 lda hud_digit_codes+3,x
 sta hud_ready+45
 lda hud_digit_codes+4,x
 sta hud_ready+59
 lda hud_digit_codes+5,x
 sta hud_ready+73
 lda #1
 sta hud_dirty+3
:
 lda _score+0
 cmp hud_shadow+4
 beq :+
 sta hud_shadow+4
 asl a
 sta temp
 asl a
 clc
 adc temp
 clc
 adc #60
 tax
 lda hud_digit_codes+0,x
 sta hud_ready+4
 lda hud_digit_codes+1,x
 sta hud_ready+18
 lda hud_digit_codes+2,x
 sta hud_ready+32
 lda hud_digit_codes+3,x
 sta hud_ready+46
 lda hud_digit_codes+4,x
 sta hud_ready+60
 lda hud_digit_codes+5,x
 sta hud_ready+74
 lda #1
 sta hud_dirty+4
:
 lda _score+1
 cmp hud_shadow+5
 beq :+
 sta hud_shadow+5
 asl a
 sta temp
 asl a
 clc
 adc temp
 clc
 adc #60
 tax
 lda hud_digit_codes+0,x
 sta hud_ready+5
 lda hud_digit_codes+1,x
 sta hud_ready+19
 lda hud_digit_codes+2,x
 sta hud_ready+33
 lda hud_digit_codes+3,x
 sta hud_ready+47
 lda hud_digit_codes+4,x
 sta hud_ready+61
 lda hud_digit_codes+5,x
 sta hud_ready+75
 lda #1
 sta hud_dirty+5
:
 lda _score+2
 cmp hud_shadow+6
 beq :+
 sta hud_shadow+6
 asl a
 sta temp
 asl a
 clc
 adc temp
 clc
 adc #60
 tax
 lda hud_digit_codes+0,x
 sta hud_ready+6
 lda hud_digit_codes+1,x
 sta hud_ready+20
 lda hud_digit_codes+2,x
 sta hud_ready+34
 lda hud_digit_codes+3,x
 sta hud_ready+48
 lda hud_digit_codes+4,x
 sta hud_ready+62
 lda hud_digit_codes+5,x
 sta hud_ready+76
 lda #1
 sta hud_dirty+6
:
 lda _score+3
 cmp hud_shadow+7
 beq :+
 sta hud_shadow+7
 asl a
 sta temp
 asl a
 clc
 adc temp
 clc
 adc #60
 tax
 lda hud_digit_codes+0,x
 sta hud_ready+7
 lda hud_digit_codes+1,x
 sta hud_ready+21
 lda hud_digit_codes+2,x
 sta hud_ready+35
 lda hud_digit_codes+3,x
 sta hud_ready+49
 lda hud_digit_codes+4,x
 sta hud_ready+63
 lda hud_digit_codes+5,x
 sta hud_ready+77
 lda #1
 sta hud_dirty+7
:
@names_only:
 lda _name_changed
 bne :+
 rts
: lda #0
 sta _name_changed
 ldx #8
@field:
 cpx #4
 bcc @high
 cpx #8
 bcc @score
 lda _name_chars-8,x
 jmp @check
@score:
 lda _score-4,x
 jmp @check
@high:
 lda _high_score,x
@check:
 cmp hud_shadow,x
 bne :+
 jmp @next
: sta hud_shadow,x
 cpx #8
 bcs @name
 asl a
 sta temp
 asl a
 clc
 adc temp
 cpx #4
 bcc :+
 clc
 adc #60
: clc
 adc #<hud_digit_codes
 sta src
 lda #>hud_digit_codes
 adc #0
 sta src+1

 ldy #0
 lda (src),y
 sta hud_ready+0,x
 ldy #1
 lda (src),y
 sta hud_ready+14,x
 ldy #2
 lda (src),y
 sta hud_ready+28,x
 ldy #3
 lda (src),y
 sta hud_ready+42,x
 ldy #4
 lda (src),y
 sta hud_ready+56,x
 ldy #5
 lda (src),y
 sta hud_ready+70,x
 jmp @dirty
@name:
 tay
 lda hud_name_lo,y
 sta hud_name_src_lo-8,x
 lda hud_name_hi,y
 sta hud_name_src_hi-8,x
 tya
 asl a
 tay
 txa
 sec
 sbc #8
 asl a
 asl a
 clc
 adc #68
 sta glyph
 lda glyph
 sta hud_ready+0,x
 inc glyph
 lda glyph
 sta hud_ready+14,x
 inc glyph
 lda hud_tail_codes+0,y
 sta hud_ready+28,x
 lda glyph
 sta hud_ready+42,x
 inc glyph
 lda glyph
 sta hud_ready+56,x
 inc glyph
 lda hud_tail_codes+1,y
 sta hud_ready+70,x
@dirty:
 lda #1
 sta hud_dirty,x
 cpx #8
 bcc @next
 cpx #13
 bcs @next
 sta hud_dirty+1,x
@next:
 inx
 cpx #14
 beq :+
 jmp @field
: rts
commit_hud:
 lda hud_dirty+0
 bne :+
 jmp hud_done0
: lda #0
 sta hud_dirty+0
 lda hud_ready+0
 sta $9f1c
 lda hud_ready+14
 sta $9f1d
 lda hud_ready+28
 sta $9f1e
 lda hud_ready+42
 sta $9f44
 lda hud_ready+56
 sta $9f45
 lda hud_ready+70
 sta $9f46
hud_done0:
 lda hud_dirty+1
 bne :+
 jmp hud_done1
: lda #0
 sta hud_dirty+1
 lda hud_ready+1
 sta $9f1e
 lda hud_ready+15
 sta $9f1f
 lda hud_ready+29
 sta $9f20
 lda hud_ready+43
 sta $9f46
 lda hud_ready+57
 sta $9f47
 lda hud_ready+71
 sta $9f48
hud_done1:
 lda hud_dirty+2
 bne :+
 jmp hud_done2
: lda #0
 sta hud_dirty+2
 lda hud_ready+2
 sta $9f20
 lda hud_ready+16
 sta $9f21
 lda hud_ready+30
 sta $9f22
 lda hud_ready+44
 sta $9f48
 lda hud_ready+58
 sta $9f49
 lda hud_ready+72
 sta $9f4a
hud_done2:
 lda hud_dirty+3
 bne :+
 jmp hud_done3
: lda #0
 sta hud_dirty+3
 lda hud_ready+3
 sta $9f22
 lda hud_ready+17
 sta $9f23
 lda hud_ready+45
 sta $9f4a
 lda hud_ready+59
 sta $9f4b
hud_done3:
 lda hud_dirty+4
 bne :+
 jmp hud_done4
: lda #0
 sta hud_dirty+4
 lda hud_ready+4
 sta $9f34
 lda hud_ready+18
 sta $9f35
 lda hud_ready+32
 sta $9f36
 lda hud_ready+46
 sta $9f5c
 lda hud_ready+60
 sta $9f5d
 lda hud_ready+74
 sta $9f5e
hud_done4:
 lda hud_dirty+5
 bne :+
 jmp hud_done5
: lda #0
 sta hud_dirty+5
 lda hud_ready+5
 sta $9f36
 lda hud_ready+19
 sta $9f37
 lda hud_ready+33
 sta $9f38
 lda hud_ready+47
 sta $9f5e
 lda hud_ready+61
 sta $9f5f
 lda hud_ready+75
 sta $9f60
hud_done5:
 lda hud_dirty+6
 bne :+
 jmp hud_done6
: lda #0
 sta hud_dirty+6
 lda hud_ready+6
 sta $9f38
 lda hud_ready+20
 sta $9f39
 lda hud_ready+34
 sta $9f3a
 lda hud_ready+48
 sta $9f60
 lda hud_ready+62
 sta $9f61
 lda hud_ready+76
 sta $9f62
hud_done6:
 lda hud_dirty+7
 bne :+
 jmp hud_done7
: lda #0
 sta hud_dirty+7
 lda hud_ready+7
 sta $9f3a
 lda hud_ready+21
 sta $9f3b
 lda hud_ready+35
 sta $9f3c
 lda hud_ready+49
 sta $9f62
 lda hud_ready+63
 sta $9f63
 lda hud_ready+77
 sta $9f64
hud_done7:
 lda hud_dirty+8
 bne :+
 jmp hud_done8
: lda #0
 sta hud_dirty+8
 lda hud_name_src_lo+0
 sta $21
 lda hud_name_src_hi+0
 sta $22
 ldy #31
@copy8:
 lda ($21),y
 sta $e620,y
 dey
 bpl @copy8
 lda hud_ready+8
 sta $9f26
 lda hud_ready+22
 sta $9f27
 lda hud_ready+36
 sta $9f28
 lda hud_ready+50
 sta $9f4e
 lda hud_ready+64
 sta $9f4f
 lda hud_ready+78
 sta $9f50
hud_done8:
 lda hud_dirty+9
 bne :+
 jmp hud_done9
: lda #0
 sta hud_dirty+9
 lda hud_name_src_lo+1
 sta $21
 lda hud_name_src_hi+1
 sta $22
 ldy #31
@copy9:
 lda ($21),y
 sta $e640,y
 dey
 bpl @copy9
 lda hud_ready+36
 asl a
 asl a
 asl a
 sta $21
 lda hud_ready+36
 lsr a
 lsr a
 lsr a
 lsr a
 lsr a
 clc
 adc #$e4
 sta $22
 ldy #7
@merge9_0:
 lda ($21),y
 ora $e640,y
 sta $e640,y
 dey
 bpl @merge9_0
 lda hud_ready+78
 asl a
 asl a
 asl a
 sta $21
 lda hud_ready+78
 lsr a
 lsr a
 lsr a
 lsr a
 lsr a
 clc
 adc #$e4
 sta $22
 ldy #7
@merge9_1:
 lda ($21),y
 ora $e650,y
 sta $e650,y
 dey
 bpl @merge9_1
 lda hud_ready+9
 sta $9f28
 lda hud_ready+23
 sta $9f29
 lda hud_ready+37
 sta $9f2a
 lda hud_ready+51
 sta $9f50
 lda hud_ready+65
 sta $9f51
 lda hud_ready+79
 sta $9f52
hud_done9:
 lda hud_dirty+10
 bne :+
 jmp hud_done10
: lda #0
 sta hud_dirty+10
 lda hud_name_src_lo+2
 sta $21
 lda hud_name_src_hi+2
 sta $22
 ldy #31
@copy10:
 lda ($21),y
 sta $e660,y
 dey
 bpl @copy10
 lda hud_ready+37
 asl a
 asl a
 asl a
 sta $21
 lda hud_ready+37
 lsr a
 lsr a
 lsr a
 lsr a
 lsr a
 clc
 adc #$e4
 sta $22
 ldy #7
@merge10_0:
 lda ($21),y
 ora $e660,y
 sta $e660,y
 dey
 bpl @merge10_0
 lda hud_ready+79
 asl a
 asl a
 asl a
 sta $21
 lda hud_ready+79
 lsr a
 lsr a
 lsr a
 lsr a
 lsr a
 clc
 adc #$e4
 sta $22
 ldy #7
@merge10_1:
 lda ($21),y
 ora $e670,y
 sta $e670,y
 dey
 bpl @merge10_1
 lda hud_ready+10
 sta $9f2a
 lda hud_ready+24
 sta $9f2b
 lda hud_ready+38
 sta $9f2c
 lda hud_ready+52
 sta $9f52
 lda hud_ready+66
 sta $9f53
 lda hud_ready+80
 sta $9f54
hud_done10:
 lda hud_dirty+11
 bne :+
 jmp hud_done11
: lda #0
 sta hud_dirty+11
 lda hud_name_src_lo+3
 sta $21
 lda hud_name_src_hi+3
 sta $22
 ldy #31
@copy11:
 lda ($21),y
 sta $e680,y
 dey
 bpl @copy11
 lda hud_ready+38
 asl a
 asl a
 asl a
 sta $21
 lda hud_ready+38
 lsr a
 lsr a
 lsr a
 lsr a
 lsr a
 clc
 adc #$e4
 sta $22
 ldy #7
@merge11_0:
 lda ($21),y
 ora $e680,y
 sta $e680,y
 dey
 bpl @merge11_0
 lda hud_ready+80
 asl a
 asl a
 asl a
 sta $21
 lda hud_ready+80
 lsr a
 lsr a
 lsr a
 lsr a
 lsr a
 clc
 adc #$e4
 sta $22
 ldy #7
@merge11_1:
 lda ($21),y
 ora $e690,y
 sta $e690,y
 dey
 bpl @merge11_1
 lda hud_ready+11
 sta $9f2c
 lda hud_ready+25
 sta $9f2d
 lda hud_ready+39
 sta $9f2e
 lda hud_ready+53
 sta $9f54
 lda hud_ready+67
 sta $9f55
 lda hud_ready+81
 sta $9f56
hud_done11:
 lda hud_dirty+12
 bne :+
 jmp hud_done12
: lda #0
 sta hud_dirty+12
 lda hud_name_src_lo+4
 sta $21
 lda hud_name_src_hi+4
 sta $22
 ldy #31
@copy12:
 lda ($21),y
 sta $e6a0,y
 dey
 bpl @copy12
 lda hud_ready+39
 asl a
 asl a
 asl a
 sta $21
 lda hud_ready+39
 lsr a
 lsr a
 lsr a
 lsr a
 lsr a
 clc
 adc #$e4
 sta $22
 ldy #7
@merge12_0:
 lda ($21),y
 ora $e6a0,y
 sta $e6a0,y
 dey
 bpl @merge12_0
 lda hud_ready+81
 asl a
 asl a
 asl a
 sta $21
 lda hud_ready+81
 lsr a
 lsr a
 lsr a
 lsr a
 lsr a
 clc
 adc #$e4
 sta $22
 ldy #7
@merge12_1:
 lda ($21),y
 ora $e6b0,y
 sta $e6b0,y
 dey
 bpl @merge12_1
 lda hud_ready+12
 sta $9f2e
 lda hud_ready+26
 sta $9f2f
 lda hud_ready+40
 sta $9f30
 lda hud_ready+54
 sta $9f56
 lda hud_ready+68
 sta $9f57
 lda hud_ready+82
 sta $9f58
hud_done12:
 lda hud_dirty+13
 bne :+
 jmp hud_done13
: lda #0
 sta hud_dirty+13
 lda hud_name_src_lo+5
 sta $21
 lda hud_name_src_hi+5
 sta $22
 ldy #31
@copy13:
 lda ($21),y
 sta $e6c0,y
 dey
 bpl @copy13
 lda hud_ready+40
 asl a
 asl a
 asl a
 sta $21
 lda hud_ready+40
 lsr a
 lsr a
 lsr a
 lsr a
 lsr a
 clc
 adc #$e4
 sta $22
 ldy #7
@merge13_0:
 lda ($21),y
 ora $e6c0,y
 sta $e6c0,y
 dey
 bpl @merge13_0
 lda hud_ready+82
 asl a
 asl a
 asl a
 sta $21
 lda hud_ready+82
 lsr a
 lsr a
 lsr a
 lsr a
 lsr a
 clc
 adc #$e4
 sta $22
 ldy #7
@merge13_1:
 lda ($21),y
 ora $e6d0,y
 sta $e6d0,y
 dey
 bpl @merge13_1
 lda hud_ready+13
 sta $9f30
 lda hud_ready+27
 sta $9f31
 lda hud_ready+41
 sta $9f32
 lda hud_ready+55
 sta $9f58
 lda hud_ready+69
 sta $9f59
 lda hud_ready+83
 sta $9f5a
hud_done13:
 rts
.segment "CODE"
