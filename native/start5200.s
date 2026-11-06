.import __RAMCODE_LOAD__,__RAMCODE_RUN__,__RAMCODE_SIZE__,__HUDFONT_LOAD__
.export dli_entry
start:
 sei
 cld
 lda #0
 sta $d40e
 sta $d400
 sta $e80e
 sta $c01d
 sta $e808
 ldx #0
@clear:
 .repeat 64,P
 sta P*256,x
 .endrepeat
 inx
 beq :+
 jmp @clear
: ldx #$ff
 txs
 lda #$40
 sta c_sp+1
 ldy #0
@code:
 lda __RAMCODE_LOAD__,y
 sta __RAMCODE_RUN__,y
 iny
 cpy #<__RAMCODE_SIZE__
 bne @code
 ldx #0
@hud:
 .repeat 4,P
 lda __HUDFONT_LOAD__+P*256,x
 sta $2c00+P*256,x
 .endrepeat
 inx
 bne @hud
 lda #<nmi
 sta $0202
 lda #>nmi
 sta $0203
 lda #<dli_entry
 sta $0206
 lda #>dli_entry
 sta $0207
 lda #<audio_irq
 sta $0200
 lda #>audio_irq
 sta $0201
 lda #2
 sta $e80f
 lda #4
 sta $c01f
 lda #0
 sta $e80b
 lda #255
 sta old_key
 jsr audio_init
 jsr _game_init
 jsr scene_setup
 lda #$c0
 sta $d40e
 lda frame_number
 sta frame_seen
 cli
.assert __RAMCODE_SIZE__ <= 256, lderror,"RAM routines too large"
