.include "longbranch.mac"
; Original sound score, rendered by native POKEY tone pairs and a noise DAC.
; Foreground owns score state. IRQ owns the live noise shift state.
.import _sound_event, _sound_queue, sound_score, sound_waves
.importzp _mode
.import _death_clock
.export sound_update, audio_init, audio_irq, sound_clock, sound_cursor
.export audio_control, audio_wave, audio_shift, audio_reload, sound_active
.export audio_noise_bits, audio_noise_byte, audio_feedback
.segment "BSS"
sound_clock:.res 1
sound_cursor:.res 1
sound_active:.res 1
audio_control:.res 1
audio_wave:.res 1
audio_shift=$64
audio_reload:.res 1
audio_last_wave:.res 1
audio_last_speed:.res 1
audio_phase:.res 1
audio_feedback=$69
audio_noise_running:.res 1
audio_noise_bits=$67
audio_noise_byte=$68
audio_noise_speed:.res 1
.segment "CODE"
audio_init:
 lda #$50
 sta $d208
 lda #$ff
 sta audio_last_wave
 sta audio_last_speed
 lda #0
 sta $d201
 sta $d203
 sta $d205
 sta $d207
 sta $d20e
 rts
sound_update:
 lda #0
 sta audio_reload
 ; Death suppresses other explicit requests for its first 31 ticks.
 lda _death_clock
 beq @request
 cmp #32
 bcs @request
 lda _sound_event
 cmp #$87
 beq @request
 lda #0
 sta _sound_event
 lda sound_clock
 bne @request
 lda #$87
 sta _sound_event
@request:
 lda _sound_event
 bne @start
 lda sound_clock
 bne @tick
 lda _sound_queue
 beq @tick
 tay
 ldx #0
 stx _sound_queue
 tya
 bmi @ambient
 ldx #$74
 and #4
 bne @queued
 tya
 and #8
 ldx #$97
 bne @queued
 ldx #$64
 bne @queued
@ambient:
 ; Queue 80+20 mine, 80+08 hit, 80+04 moving item, 80+02 fade.
 tay
 and #$20
 ldx #$b1
 bne @queued
 tya
 and #8
 ldx #$78
 bne @queued
 tya
 and #4
 ldx #$7f
 bne @queued
 tya
 and #2
 ldx #$91
 beq @tick
@queued:
 txa
@start:
 sta sound_cursor
 lda #1
 sta sound_clock
 sta sound_active
@tick:
 lda sound_active
 jeq @output
 dec sound_clock
 jne @output
@command:
 ldx sound_cursor
 lda sound_score,x
 inx
 stx sound_cursor
 ora #0
 bmi @wave
 cmp #$40
 bcs @volume
 cmp #$20
 bcs @rest
 cmp #$10
 bcs @jump
 lda #0
 sta sound_active
 jmp @output
@jump:
 lda sound_score,x
 sta sound_cursor
 jmp @command
@rest:
 and #$1f
 sta sound_clock
 lda #0
 sta audio_control
 jmp @output
@volume:
 and #$3f
 sta sound_clock
 lda sound_score,x
 sta audio_control
 inc sound_cursor
 jmp @output
@wave:
 and #$7f
 sta sound_clock
 lda sound_score,x
 tay
 inc sound_cursor
 sty audio_wave
 php
 sei
 lda sound_waves,y
 sta audio_shift
 lda sound_waves+1,y
 sta audio_shift+1
 lda sound_waves+2,y
 sta audio_shift+2
 lda sound_waves+3,y
 sta audio_control
 lda #1
 sta audio_reload
 lda #0
 sta audio_noise_bits
 plp
@output:
 jmp audio_output

; A tone uses the exact full period of the 24-bit waveform. AUDF1/2 joined,
; 1.79 MHz clock: half period = 228 * shifts * speed, divisor subtracts 7.
audio_output:
 php
 sei
 lda audio_control
 bpl @quiet
 and #$10
 bne @noise
 lda #0
 sta $d20e
 sta audio_noise_running
 sta $d205
 lda audio_control
 and #15
 ora #$a0
 sta $d203
 lda audio_wave
 cmp audio_last_wave
 bne @frequency
 lda audio_control
 and #$20
 cmp audio_last_speed
 beq @return
@frequency:
 lda audio_wave
 sta audio_last_wave
 lsr a
 lsr a
 tax
 lda audio_control
 and #$20
 sta audio_last_speed
 bne :+
 txa
 clc
 adc #10
 tax
: lda audio_divlow,x
 sta $d200
 lda audio_divhigh,x
 sta $d202
 sta $d209
@return:
 plp
 rts
@quiet:
 lda #0
 sta $d20e
 sta audio_noise_running
 sta $d203
 sta $d205
 plp
 rts
@noise:
 lda #0
 sta $d203
 lda audio_control
 and #15
 ora #$10
 sta noise_volume+1
 lda audio_control
 and #$20
 cmp audio_noise_speed
 bne @noise_timer
 lda audio_noise_running
 bne @return
@noise_timer:
 lda audio_control
 and #$20
 sta audio_noise_speed
 lda #1
 sta audio_noise_running
 lda #$ff
 sta audio_last_wave
 lda #$c1
 ldx #1
 ldy audio_noise_speed
 bne :+
 lda #$19
 ldx #7
: sta $d200
 stx $d202
 sta $d209
 lda #2
 sta $d20e
 plp
 rts

; Eight consecutive output bits are the old low byte. Advance the 16-bit
; feedback recurrence eight steps together: hi' = lo XOR (word >> 5).
; The source's upper eight bits do not feed either noise tap. This emits
; exactly the same bit sequence with much less interrupt work.
audio_irq:
 pha
 lda #0
 sta $d20e
 lda #2
 sta $d20e
 lda audio_noise_bits
 bne @bit
 lda audio_shift+2
 sta audio_noise_byte
 lsr a
 lsr a
 lsr a
 lsr a
 lsr a
 eor audio_shift+2
 sta audio_feedback
 lda audio_shift+1
 sta audio_shift+2
 asl a
 asl a
 asl a
 eor audio_feedback
 sta audio_shift+1
 sta audio_shift
 lda #8
 sta audio_noise_bits
@bit:
 lsr audio_noise_byte
 bcc noise_off
noise_volume:
 lda #$1f
 bne noise_dac
noise_off:
 lda #$10
noise_dac:
 sta $d205
 dec audio_noise_bits
 pla
 rti
.segment "RODATA"
; Wave offsets / 4: slow 24,12,8,6,4; fast 12,8,6,4,2.
periods:.byte 24,12,8,6,4,12,8,6,4,2
audio_divlow:
.repeat 2,S
 .repeat 10,I
  .if I=0
   .byte <(228*(1+3*S)*24-7)
  .elseif I=1 .or I=5
   .byte <(228*(1+3*S)*12-7)
  .elseif I=2 .or I=6
   .byte <(228*(1+3*S)*8-7)
  .elseif I=3 .or I=7
   .byte <(228*(1+3*S)*6-7)
  .elseif I=4 .or I=8
   .byte <(228*(1+3*S)*4-7)
  .else
   .byte <(228*(1+3*S)*2-7)
  .endif
 .endrepeat
.endrepeat
audio_divhigh:
.repeat 2,S
 .repeat 10,I
  .if I=0
   .byte >(228*(1+3*S)*24-7)
  .elseif I=1 .or I=5
   .byte >(228*(1+3*S)*12-7)
  .elseif I=2 .or I=6
   .byte >(228*(1+3*S)*8-7)
  .elseif I=3 .or I=7
   .byte >(228*(1+3*S)*6-7)
  .elseif I=4 .or I=8
   .byte >(228*(1+3*S)*4-7)
  .else
   .byte >(228*(1+3*S)*2-7)
  .endif
 .endrepeat
.endrepeat
