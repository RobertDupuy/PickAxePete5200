; Generated from Odyssey2 BIOS $2f2-$2fc and the original character ROM.
.import _scene_changed
.export select_setup
.segment "EXTRA"
select_bitmap:
.byte 0,0,0,0,0,0,0,0,0,0,1,85,10,170,143,0
.byte 0,0,0,0,0,0,0,0,0,0,0,84,10,2,143,255
.byte 192,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,1,85,10,170,143,0,0,0,0,0,0,0,0,0
.byte 0,0,0,84,10,2,143,255,192,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,5,1,74,0,15,0
.byte 0,0,0,0,0,0,0,0,0,0,1,69,10,138,143,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,5,1,74,0,15,0,0,0,0,0,0,0,0,0
.byte 0,0,1,69,10,138,143,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,5,0,10,0,15,0
.byte 0,0,0,0,0,0,0,0,0,0,5,1,74,170,143,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,5,0,10,0,15,0,0,0,0,0,0,0,0,0
.byte 0,0,5,1,74,170,143,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,1,85,10,168,15,0
.byte 0,0,0,0,0,0,0,0,0,0,5,1,74,34,143,252
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,1,85,10,168,15,0,0,0,0,0,0,0,0,0
.byte 0,0,5,1,74,34,143,252,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,1,74,0,15,0
.byte 0,0,0,0,0,0,0,0,0,0,5,85,74,2,143,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,1,74,0,15,0,0,0,0,0,0,0,0,0
.byte 0,0,5,85,74,2,143,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,5,1,74,0,15,0
.byte 0,0,0,0,0,0,0,0,0,0,5,1,74,2,143,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,5,1,74,0,15,0,0,0,0,0,0,0,0,0
.byte 0,0,5,1,74,2,143,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,1,85,10,170,143,255
.byte 192,0,0,0,0,0,0,0,0,0,5,1,74,2,143,255
.byte 192,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,1,85,10,170,143,255,192,0,0,0,0,0,0,0
.byte 0,0,5,1,74,2,143,255,192,0,0,0,0,0,0,0
select_player0:
.byte 254,254,192,192,192,192,248,248,192,192,192,192,254,254
select_player1:
.byte 124,124,198,198,192,192,192,192,192,192,198,198,124,124
select_player2:
.byte 126,126,24,24,24,24,24,24,24,24,24,24,24,24
select_player3:
.byte 124,124,198,198,192,192,192,192,206,206,198,198,126,126
select_dlist:
.byte $70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70
.byte $4e,<select_bitmap,>select_bitmap
.byte $0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e
.byte $41,<$0400,>$0400
select_dlist_end:
.segment "CODE"
select_setup:
 lda #0
 sta $d40e
 lda #0
 sta $d400
 sta _scene_changed
 sta $c01a
 ldx #0
@clear:
 .repeat 8,P
 sta $1800+P*256,x
 .endrepeat
 inx
 bne @clear
 ldx #select_dlist_end-select_dlist-1
@list:
 lda select_dlist,x
 sta $0400,x
 dex
 bpl @list
 lda #<$0400
 sta $d402
 lda #>$0400
 sta $d403
 lda #$18
 sta $d407
 lda #3
 sta $c01d
 lda #1
 sta $c01b
 lda #0
 .repeat 4,P
 sta $c008+P
 .endrepeat
 ldx #13
@players:
 .repeat 4,P
 lda .ident(.sprintf("select_player%d",P)),x
 sta $1c80+P*256,x
 .endrepeat
 dex
 bpl @players
 lda #114
 sta $c000
 lda #122
 sta $c001
 lda #130
 sta $c002
 lda #146
 sta $c003
 lda #$6e
 sta $c012
 lda #$ac
 sta $c013
 lda #$0e
 sta $c014
 lda #$4a
 sta $c015
 lda #$cc
 sta $c016
 lda #$2c
 sta $c017
 lda #$9c
 sta $c018
 lda #$3e
 sta $d400
 lda #0
 sta $d40f
 lda #$c0
 sta $d40e
 rts
