.include "longbranch.mac"
.export key_age,latched_key
.import audio_noise_running
.segment "BSS"
key_age:.res 1
latched_key:.res 1
paused:.res 1
.segment "CODE"
read_input:
 lda #0
 sta _input_x
 sta _input_y
 sta _input_fire
 lda $e800
 cmp #85
 bcs :+
 dec _input_x
: cmp #145
 bcc :+
 inc _input_x
: lda $e801
 cmp #85
 bcs :+
 dec _input_y
: cmp #145
 bcc :+
 inc _input_y
: lda #0
 sta $e80b
 lda $c010
 bne :+
 inc _input_fire
: lda key_age
 beq @released
 dec key_age
 jmp @key
@released:
 lda #255
 sta old_key
 jmp @done
@key:
 lda latched_key
 cmp old_key
 jeq @done
 sta old_key
 lsr a
 tax
 cpx #12
 bne @pause
 lda _mode
 bne :+
 lda #1
 sta _input_fire
: lda #0
 sta paused
 jmp @done
@pause:
 cpx #8
 bne @reset
 lda paused
 eor #1
 sta paused
 beq @unmute
 lda #0
 sta $e801
 sta $e803
 sta $e805
 sta $e807
 sta audio_noise_running
 lda #$40
 sta $e80e
@unmute:
 jmp @done
@reset:
 cpx #4
 bne @number
 lda #0
 sta _mode
 sta paused
 lda #1
 sta _scene_changed
 jsr scene_setup
 jmp @done
@number:
 lda _mode
 bne @done
 lda keypad_digits,x
 cmp #10
 bcs @done
 sta _input_mine
@done:
 rts
.segment "RODATA"
keypad_digits:.byte 255,255,0,255,255,9,8,7,255,6,5,4,255,3,2,1
.segment "CODE"
