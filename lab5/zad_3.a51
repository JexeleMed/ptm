; =======================================================
; zad_3.a51 - Zegar z budzikiem
;             Ustawianie czasu (HH:MM) - zatwierdzenie #
;             Ustawianie alarmu (HH:MM) - zatwierdzenie *
;             Po osiagnieciu alarmu buzzer P6.4 na 10s
;             Start/Stop: P3.2, Godzina+: P3.3, Godzina-: P3.4
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
CLOCK_RUNNING EQU 20H      ; 1 = chodzi, 0 = zatrzymany
PREV_P3       EQU 21H      ; poprzedni stan P3.2-P3.5
SETUP_STEP    EQU 22H      ; 0-3 czas, 4-7 alarm
SETUP_HOUR    EQU 23H      ; tymczasowa godzina (czas lub alarm)
SETUP_MIN     EQU 24H      ; tymczasowa minuta
ALARM_HOUR    EQU 25H      ; przechowuje alarm godzine
ALARM_MIN     EQU 26H      ; przechowuje alarm minute
TEMP_KEY      EQU 27H      ; ostatni klawisz klawiatury
DIGIT_TEMP    EQU 28H      ; pomocniczy
ALARM_TRIG    EQU 29H      ; 1 = alarm aktywny (buzzer dzwoni)
ALARM_CNT     EQU 2AH      ; licznik do wylaczenia (10s = 200 * 50ms)

; ----- Wektor resetu -----
ORG 0
    ljmp start

; ----- Wektor przerwania timer0 (co 50ms) -----
ORG 000BH
    MOV TH0, #3CH
    MOV TL0, #0B0H
    DEC R0
    LCALL scan_buttons      ; skanuje P3
    LCALL scan_keyboard     ; skanuje klawiature (do wylaczania alarmu)
    LCALL alarm_handler     ; sprawdza czas i obsluguje buzzer
    RETI

; ----- Kod glówny od adresu 0100H -----
ORG 0100H

; ---------- Poprawione makra LCD (z zachowaniem DPTR) ----------
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

; ---------- Obsluga buzera (P6.4) ----------
buzzer_on:
    ORL  P6, #00010000B
    RET
buzzer_off:
    ANL  P6, #11101111B
    RET

; ---------- Obsluga alarmu (wolane co 50ms) ----------
alarm_handler:
    push acc
    ; jesli alarm juz aktywny, zmniejsz licznik
    mov  a, ALARM_TRIG
    jz   check_match
    djnz ALARM_CNT, alarm_end   ; jeszcze nie czas wylaczyc
    clr  ALARM_TRIG
    lcall buzzer_off
    sjmp alarm_end
check_match:
    ; sprawdz czy czas równa sie alarmowi
    mov  a, R5
    cjne a, ALARM_HOUR, alarm_end
    mov  a, R6
    cjne a, ALARM_MIN, alarm_end
    ; alarm!
    mov  ALARM_TRIG, #1
    mov  ALARM_CNT, #200      ; 10 sekund (200 * 50ms)
    lcall buzzer_on
alarm_end:
    ; wylacz alarm, jesli jakikolwiek klawisz wcisniety
    mov  a, TEMP_KEY
    cjne a, #0FFh, turn_off
    mov  a, PREV_P3
    jz   no_turn_off
turn_off:
    clr  ALARM_TRIG
    lcall buzzer_off
no_turn_off:
    pop acc
    ret

; ---------- Obsluga przycisków P3 (aktywne niskie) ----------
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
msg_alarm_hour:
    db 'Alarm HH: ',0
msg_alarm_min:
    db 'Alarm MM: ',0
msg_press_star:
    db ' Press *',0

puts_lcd:
    clr  a
    movc a, @a+dptr
    jz   puts_end
    lcall putcharLCD
    inc  dptr
    sjmp puts_lcd
puts_end:
    ret

; ---------- Procedura ustawiania czasu i alarmu ----------
setup_full:
    ; ---- czesc 1: ustawianie czasu (zatwierdzenie #) ----
    mov  SETUP_STEP, #0
    mov  SETUP_HOUR, #0
    mov  SETUP_MIN, #0
    lcall clear_display
    mov  dptr, #msg_enter_hour
    lcall puts_lcd
setup_time_loop:
    lcall scan_keyboard
    mov  a, TEMP_KEY
    cjne a, #0FFh, setup_time_key
    sjmp setup_time_loop
setup_time_key:
    push acc
wait_rel_t:
    lcall scan_keyboard
    mov  a, TEMP_KEY
    cjne a, #0FFh, wait_rel_t
    pop acc
    ; sprawdz czy cyfra
    cjne a, #'0', tch1
    mov  DIGIT_TEMP, #0
    ljmp proc_time_digit
tch1:
    cjne a, #'1', tch2
    mov  DIGIT_TEMP, #1
    ljmp proc_time_digit
tch2:
    cjne a, #'2', tch3
    mov  DIGIT_TEMP, #2
    ljmp proc_time_digit
tch3:
    cjne a, #'3', tch4
    mov  DIGIT_TEMP, #3
    ljmp proc_time_digit
tch4:
    cjne a, #'4', tch5
    mov  DIGIT_TEMP, #4
    ljmp proc_time_digit
tch5:
    cjne a, #'5', tch6
    mov  DIGIT_TEMP, #5
    ljmp proc_time_digit
tch6:
    cjne a, #'6', tch7
    mov  DIGIT_TEMP, #6
    ljmp proc_time_digit
tch7:
    cjne a, #'7', tch8
    mov  DIGIT_TEMP, #7
    ljmp proc_time_digit
tch8:
    cjne a, #'8', tch9
    mov  DIGIT_TEMP, #8
    ljmp proc_time_digit
tch9:
    cjne a, #'9', tch_hash
    mov  DIGIT_TEMP, #9
    ljmp proc_time_digit
tch_hash:
    cjne a, #'#', setup_time_loop
    mov  a, SETUP_STEP
    cjne a, #4, setup_time_loop
    ; czas zatwierdzony
    mov  R5, SETUP_HOUR
    mov  R6, SETUP_MIN
    mov  R7, #0
    ; ---- czesc 2: ustawianie alarmu (zatwierdzenie *) ----
    mov  SETUP_STEP, #4        ; kroki 4-7
    mov  SETUP_HOUR, #0
    mov  SETUP_MIN, #0
    lcall clear_display
    mov  dptr, #msg_alarm_hour
    lcall puts_lcd
setup_alarm_loop:
    lcall scan_keyboard
    mov  a, TEMP_KEY
    cjne a, #0FFh, setup_alarm_key
    sjmp setup_alarm_loop
setup_alarm_key:
    push acc
wait_rel_a:
    lcall scan_keyboard
    mov  a, TEMP_KEY
    cjne a, #0FFh, wait_rel_a
    pop acc
    cjne a, #'0', ach1
    mov  DIGIT_TEMP, #0
    ljmp proc_alarm_digit
ach1:
    cjne a, #'1', ach2
    mov  DIGIT_TEMP, #1
    ljmp proc_alarm_digit
ach2:
    cjne a, #'2', ach3
    mov  DIGIT_TEMP, #2
    ljmp proc_alarm_digit
ach3:
    cjne a, #'3', ach4
    mov  DIGIT_TEMP, #3
    ljmp proc_alarm_digit
ach4:
    cjne a, #'4', ach5
    mov  DIGIT_TEMP, #4
    ljmp proc_alarm_digit
ach5:
    cjne a, #'5', ach6
    mov  DIGIT_TEMP, #5
    ljmp proc_alarm_digit
ach6:
    cjne a, #'6', ach7
    mov  DIGIT_TEMP, #6
    ljmp proc_alarm_digit
ach7:
    cjne a, #'7', ach8
    mov  DIGIT_TEMP, #7
    ljmp proc_alarm_digit
ach8:
    cjne a, #'8', ach9
    mov  DIGIT_TEMP, #8
    ljmp proc_alarm_digit
ach9:
    cjne a, #'9', ach_star
    mov  DIGIT_TEMP, #9
    ljmp proc_alarm_digit
ach_star:
    cjne a, #'*', setup_alarm_loop
    mov  a, SETUP_STEP
    cjne a, #8, setup_alarm_loop
    ; alarm zatwierdzony
    mov  ALARM_HOUR, SETUP_HOUR
    mov  ALARM_MIN, SETUP_MIN
    lcall clear_display
    ret

; Obsluga cyfr dla czasu (kroki 0-3)
proc_time_digit:
    mov  a, SETUP_STEP
    cjne a, #0, tstep1
    mov  a, DIGIT_TEMP
    mov  SETUP_HOUR, a
    inc  SETUP_STEP
    mov  a, SETUP_HOUR
    add  a, #30h
    lcall putcharLCD
    ljmp setup_time_loop
tstep1:
    cjne a, #1, tstep2
    mov  a, SETUP_HOUR
    mov  b, #10
    mul  ab
    add  a, DIGIT_TEMP
    mov  SETUP_HOUR, a
    mov  a, SETUP_HOUR
    cjne a, #24, thr_ok
thr_ok:
    jnc  thr_error
    inc  SETUP_STEP
    lcall clear_display
    mov  dptr, #msg_enter_min
    lcall puts_lcd
    ljmp setup_time_loop
thr_error:
    mov  SETUP_STEP, #0
    mov  SETUP_HOUR, #0
    lcall clear_display
    mov  dptr, #msg_enter_hour
    lcall puts_lcd
    ljmp setup_time_loop
tstep2:
    cjne a, #2, tstep3
    mov  a, DIGIT_TEMP
    mov  SETUP_MIN, a
    inc  SETUP_STEP
    mov  a, SETUP_MIN
    add  a, #30h
    lcall putcharLCD
    ljmp setup_time_loop
tstep3:
    cjne a, #3, tstep_err
    mov  a, SETUP_MIN
    mov  b, #10
    mul  ab
    add  a, DIGIT_TEMP
    mov  SETUP_MIN, a
    mov  a, SETUP_MIN
    cjne a, #60, tmin_ok
tmin_ok:
    jnc  tmin_error
    inc  SETUP_STEP
    lcall clear_display
    mov  dptr, #msg_press_hash
    lcall puts_lcd
    ljmp setup_time_loop
tmin_error:
    mov  SETUP_STEP, #2
    mov  SETUP_MIN, #0
    lcall clear_display
    mov  dptr, #msg_enter_min
    lcall puts_lcd
    ljmp setup_time_loop
tstep_err:
    ljmp setup_time_loop

; Obsluga cyfr dla alarmu (kroki 4-7)
proc_alarm_digit:
    mov  a, SETUP_STEP
    cjne a, #4, astep5
    mov  a, DIGIT_TEMP
    mov  SETUP_HOUR, a
    inc  SETUP_STEP
    mov  a, SETUP_HOUR
    add  a, #30h
    lcall putcharLCD
    ljmp setup_alarm_loop
astep5:
    cjne a, #5, astep6
    mov  a, SETUP_HOUR
    mov  b, #10
    mul  ab
    add  a, DIGIT_TEMP
    mov  SETUP_HOUR, a
    mov  a, SETUP_HOUR
    cjne a, #24, ahr_ok
ahr_ok:
    jnc  ahr_error
    inc  SETUP_STEP
    lcall clear_display
    mov  dptr, #msg_alarm_min
    lcall puts_lcd
    ljmp setup_alarm_loop
ahr_error:
    mov  SETUP_STEP, #4
    mov  SETUP_HOUR, #0
    lcall clear_display
    mov  dptr, #msg_alarm_hour
    lcall puts_lcd
    ljmp setup_alarm_loop
astep6:
    cjne a, #6, astep7
    mov  a, DIGIT_TEMP
    mov  SETUP_MIN, a
    inc  SETUP_STEP
    mov  a, SETUP_MIN
    add  a, #30h
    lcall putcharLCD
    ljmp setup_alarm_loop
astep7:
    cjne a, #7, astep_err
    mov  a, SETUP_MIN
    mov  b, #10
    mul  ab
    add  a, DIGIT_TEMP
    mov  SETUP_MIN, a
    mov  a, SETUP_MIN
    cjne a, #60, amin_ok
amin_ok:
    jnc  amin_error
    inc  SETUP_STEP
    lcall clear_display
    mov  dptr, #msg_press_star
    lcall puts_lcd
    ljmp setup_alarm_loop
amin_error:
    mov  SETUP_STEP, #6
    mov  SETUP_MIN, #0
    lcall clear_display
    mov  dptr, #msg_alarm_min
    lcall puts_lcd
    ljmp setup_alarm_loop
astep_err:
    ljmp setup_alarm_loop

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
    mov  ALARM_TRIG, #0
    lcall buzzer_off
    ; pelna konfiguracja (czas + alarm)
    lcall setup_full
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