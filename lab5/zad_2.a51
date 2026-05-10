; =======================================================
; zad_2.a51 - Ustawianie poczatkowego czasu (HH:MM) z klawiatury 4x4
;             Zatwierdzenie #, potem praca zegara
; =======================================================

$NOMOD51

; ----- Definicje rejestrów SFR dla 80C537 -----
P0      DATA 080H
P1      DATA 090H
P2      DATA 0A0H
P3      DATA 0B0H
P4      DATA 0C0H
P5      DATA 0F8H
P6      DATA 0F9H
P7      DATA 0DBH

TMOD    DATA 089H
TL0     DATA 08AH
TH0     DATA 08CH
TCON    DATA 088H
IE      DATA 0A8H

TR0     BIT 08CH
TF0     BIT 08DH

; ----- Rejestry LCD -----
LCDstatus  EQU 0FF2EH
LCDcontrol EQU 0FF2CH
LCDdataWR  EQU 0FF2DH

#define  HOME     0x80
#define  INITDISP 0x38
#define  LCDON    0x0E
#define  CLEAR    0x01

; ----- Zmienne w IRAM -----
CLOCK_RUNNING EQU 20H
PREV_P3       EQU 21H
SETUP_STEP    EQU 22H
SETUP_HOUR    EQU 23H
SETUP_MIN     EQU 24H
TEMP_KEY      EQU 25H
DIGIT_TEMP    EQU 26H

; ----- Wektor resetu (obowiazkowy!) -----
ORG 0
    ljmp start

; ----- Wektor przerwania timer0 (co 50ms) -----
ORG 000BH
    MOV TH0, #3CH
    MOV TL0, #0B0H
    DEC R0
    LCALL scan_buttons
    RETI

; ----- Kod glówny zaczyna sie od adresu 0100H -----
ORG 0100H

; Makra LCD
LCDcntrlWR MACRO x
           LOCAL loop
           PUSH DPL
           PUSH DPH
loop:      MOV  DPTR,#LCDstatus
           MOVX A,@DPTR
           JB   ACC.7,loop
           MOV  DPTR,#LCDcontrol
           MOV  A, x
           MOVX @DPTR,A
           POP  DPH
           POP  DPL
           ENDM

LCDcharWR MACRO
           LOCAL tutu
           PUSH DPL
           PUSH DPH
           PUSH ACC
tutu:      MOV  DPTR,#LCDstatus
           MOVX A,@DPTR
           JB   ACC.7,tutu
           MOV  DPTR,#LCDdataWR
           POP  ACC
           MOVX @DPTR,A
           POP  DPH
           POP  DPL
           ENDM

init_LCD MACRO
         LCDcntrlWR #INITDISP
         LCDcntrlWR #CLEAR
         LCDcntrlWR #LCDON
         ENDM

; ---------- Funkcje wyswietlania ----------
putdigitLCD:
    mov  b, #10
    div  ab
    add  a, #30H
    lcall putcharLCD
    mov  a, b
    add  a, #30H
    lcall putcharLCD
    ret

putcharLCD:
    LCDcharWR
    ret

clear_display:
    LCDcntrlWR #CLEAR
    ret

display_clock:
    LCDcntrlWR #HOME
    mov  a, R5
    lcall putdigitLCD
    mov  a, #':'
    lcall putcharLCD
    mov  a, R6
    lcall putdigitLCD
    mov  a, #':'
    lcall putcharLCD
    mov  a, R7
    lcall putdigitLCD
    ret

; ---------- Inkremntacja czasu ----------
inc_clock:
    inc  R7
    mov  a, R7
    cjne a, #60, inc_sec_ok
    mov  R7, #0
    inc  R6
    mov  a, R6
    cjne a, #60, inc_min_ok
    mov  R6, #0
    inc  R5
    mov  a, R5
    cjne a, #24, inc_hour_ok
    mov  R5, #0
inc_hour_ok:
inc_min_ok:
inc_sec_ok:
    ret

; ---------- Obsluga przycisków P3 ----------
scan_buttons:
    push acc
    push b
    mov  a, P3
    anl  a, #3Ch
    cpl  a
    mov  b, a
    xrl  a, PREV_P3
    anl  a, b
    mov  PREV_P3, b
    jb   acc.2, do_start_stop
    jb   acc.3, do_hour_plus
    jb   acc.4, do_hour_minus
    ljmp sb_end
do_start_stop:
    cpl  CLOCK_RUNNING
    ljmp sb_end
do_hour_plus:
    mov  a, R5
    inc  a
    cjne a, #24, hp_ok
    mov  a, #0
hp_ok:
    mov  R5, a
    lcall display_clock
    ljmp sb_end
do_hour_minus:
    mov  a, R5
    dec  a
    cjne a, #0FFh, hm_ok
    mov  a, #23
hm_ok:
    mov  R5, a
    lcall display_clock
sb_end:
    pop b
    pop acc
    ret

; ---------- Skanowanie klawiatury 4x4 ----------
scan_keyboard:
    push b
    push dpl
    push dph
    mov  TEMP_KEY, #0FFh
    mov  r0, #4
    mov  r1, #0
    mov  dptr, #keymap
next_row:
    mov  a, r1
    cjne a, #0, row1
    mov  b, #11111110b
    sjmp row_common
row1:
    cjne a, #1, row2
    mov  b, #11111101b
    sjmp row_common
row2:
    cjne a, #2, row3
    mov  b, #11111011b
    sjmp row_common
row3:
    mov  b, #11110111b
row_common:
    mov  a, P5
    anl  a, #0F0h
    orl  a, b
    mov  P5, a
    nop
    nop
    mov  a, P7
    anl  a, #0Fh
    cpl  a
    jz   next_row_end
    mov  r2, #0
col_loop:
    rrc  a
    jc   col_found
    inc  r2
    sjmp col_loop
col_found:
    mov  a, r1
    mov  b, #4
    mul  ab
    add  a, r2
    movc a, @a+dptr
    mov  TEMP_KEY, a
next_row_end:
    inc  r1
    djnz r0, next_row
    mov  P5, #0FFh
    pop  dph
    pop  dpl
    pop  b
    mov  a, TEMP_KEY
    ret

keymap:
    db '1','2','3','A'
    db '4','5','6','B'
    db '7','8','9','C'
    db '*','0','#','D'

; ---------- Komunikaty tekstowe ----------
msg_enter_hour:
    db 'Set HH: ',0
msg_enter_min:
    db 'Set MM: ',0
msg_press_hash:
    db ' Press #',0

puts_lcd:
    clr  a
    movc a, @a+dptr
    jz   puts_end
    lcall putcharLCD
    inc  dptr
    sjmp puts_lcd
puts_end:
    ret

; ---------- Procedura ustawiania czasu poczatkowego ----------
setup_time:
    mov  SETUP_STEP, #0
    mov  SETUP_HOUR, #0
    mov  SETUP_MIN, #0
    lcall clear_display
    mov  dptr, #msg_enter_hour
    lcall puts_lcd
setup_loop:
    lcall scan_keyboard
    mov  a, TEMP_KEY
    cjne a, #0FFh, setup_key
    sjmp setup_loop
setup_key:
    push acc
wait_rel:
    lcall scan_keyboard
    mov  a, TEMP_KEY
    cjne a, #0FFh, wait_rel
    pop acc
    cjne a, #'0', chk1
    mov  DIGIT_TEMP, #0
    ljmp proc_digit
chk1:
    cjne a, #'1', chk2
    mov  DIGIT_TEMP, #1
    ljmp proc_digit
chk2:
    cjne a, #'2', chk3
    mov  DIGIT_TEMP, #2
    ljmp proc_digit
chk3:
    cjne a, #'3', chk4
    mov  DIGIT_TEMP, #3
    ljmp proc_digit
chk4:
    cjne a, #'4', chk5
    mov  DIGIT_TEMP, #4
    ljmp proc_digit
chk5:
    cjne a, #'5', chk6
    mov  DIGIT_TEMP, #5
    ljmp proc_digit
chk6:
    cjne a, #'6', chk7
    mov  DIGIT_TEMP, #6
    ljmp proc_digit
chk7:
    cjne a, #'7', chk8
    mov  DIGIT_TEMP, #7
    ljmp proc_digit
chk8:
    cjne a, #'8', chk9
    mov  DIGIT_TEMP, #8
    ljmp proc_digit
chk9:
    cjne a, #'9', chk_hash
    mov  DIGIT_TEMP, #9
    ljmp proc_digit
chk_hash:
    cjne a, #'#', setup_loop
    mov  a, SETUP_STEP
    cjne a, #4, setup_loop
    mov  R5, SETUP_HOUR
    mov  R6, SETUP_MIN
    mov  R7, #0
    lcall clear_display
    lcall display_clock
    ret

proc_digit:
    mov  a, SETUP_STEP
    cjne a, #0, step1_proc
    mov  a, DIGIT_TEMP
    mov  SETUP_HOUR, a
    inc  SETUP_STEP
    mov  a, SETUP_HOUR
    add  a, #30h
    lcall putcharLCD
    ljmp setup_loop
step1_proc:
    cjne a, #1, step2_proc
    mov  a, SETUP_HOUR
    mov  b, #10
    mul  ab
    add  a, DIGIT_TEMP
    mov  SETUP_HOUR, a
    mov  a, SETUP_HOUR
    cjne a, #24, hr_ok
hr_ok:
    jnc  hr_error
    inc  SETUP_STEP
    lcall clear_display
    mov  dptr, #msg_enter_min
    lcall puts_lcd
    ljmp setup_loop
hr_error:
    mov  SETUP_STEP, #0
    mov  SETUP_HOUR, #0
    lcall clear_display
    mov  dptr, #msg_enter_hour
    lcall puts_lcd
    ljmp setup_loop
step2_proc:
    cjne a, #2, step3_proc
    mov  a, DIGIT_TEMP
    mov  SETUP_MIN, a
    inc  SETUP_STEP
    mov  a, SETUP_MIN
    add  a, #30h
    lcall putcharLCD
    ljmp setup_loop
step3_proc:
    cjne a, #3, step_err_proc
    mov  a, SETUP_MIN
    mov  b, #10
    mul  ab
    add  a, DIGIT_TEMP
    mov  SETUP_MIN, a
    mov  a, SETUP_MIN
    cjne a, #60, min_ok
min_ok:
    jnc  min_error
    inc  SETUP_STEP
    lcall clear_display
    mov  dptr, #msg_press_hash
    lcall puts_lcd
    ljmp setup_loop
min_error:
    mov  SETUP_STEP, #2
    mov  SETUP_MIN, #0
    lcall clear_display
    mov  dptr, #msg_enter_min
    lcall puts_lcd
    ljmp setup_loop
step_err_proc:
    ljmp setup_loop

; ---------- Program glówny ----------
start:
    init_LCD
    mov  TMOD, #01H
    mov  TH0, #3CH
    mov  TL0, #0B0H
    setb TR0
    mov  IE, #82H
    mov  CLOCK_RUNNING, #0
    mov  PREV_P3, #0
    lcall setup_time
    mov  CLOCK_RUNNING, #1
    mov  R0, #20
    mov  A, #0FH
    mov  P1, A

main_loop:
    mov  A, R0
    jnz  main_loop
    mov  R0, #20
    mov  A, CLOCK_RUNNING
    jz   skip_tick
    lcall inc_clock
    lcall display_clock
skip_tick:
    mov  A, P1
    cpl  A
    mov  P1, A
    ljmp main_loop

END start