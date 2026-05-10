; =======================================================
; zad_1.a51 - Zegar z funkcjami:
;             - start/stop (P3.2)
;             - godzina + (P3.3)
;             - godzina - (P3.4)
; =======================================================

ljmp start

; ----- Definicje portów (zgodne z ZD537) -----
P5 equ 0F8H
P7 equ 0DBH

; ----- Rejestry LCD -----
LCDstatus  equ 0FF2EH
LCDcontrol equ 0FF2CH
LCDdataWR  equ 0FF2DH

#define  HOME     0x80
#define  INITDISP 0x38
#define  HOM2     0xc0
#define  LCDON    0x0e
#define  CLEAR    0x01

; ----- Zmienne w IRAM -----
CLOCK_RUNNING EQU 20H      ; 1 = chodzi, 0 = zatrzymany
PREV_P3       EQU 21H      ; poprzedni stan P3.2-P3.5

; ----- Przerwanie timer0 (co 50ms) -----
ORG 000BH
    MOV TH0, #3CH
    MOV TL0, #0B0H
    DEC R0
    LCALL scan_buttons
    RETI

; ----- Kod glówny -----
ORG 0100H

; Makra LCD
LCDcntrlWR MACRO x
           LOCAL loop
loop:      MOV  DPTR,#LCDstatus
           MOVX A,@DPTR
           JB   ACC.7,loop
           MOV  DPTR,#LCDcontrol
           MOV  A, x
           MOVX @DPTR,A
           ENDM

LCDcharWR MACRO
           LOCAL tutu
           PUSH ACC
tutu:      MOV  DPTR,#LCDstatus
           MOVX A,@DPTR
           JB   ACC.7,tutu
           MOV  DPTR,#LCDdataWR
           POP  ACC
           MOVX @DPTR,A
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

; ---------- Inkremntacja czasu (tylko gdy CLOCK_RUNNING=1) ----------
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

; ---------- Obsluga przycisków P3 (aktywne niskie) ----------
scan_buttons:
    push acc
    push b
    mov  a, P3
    anl  a, #3Ch          ; tylko bity 2,3,4,5
    cpl  a                ; 1 = wcisniety
    mov  b, a
    xrl  a, PREV_P3       ; wykryj zbocze opadajace
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

; ---------- Program glówny ----------
start:
    init_LCD
    mov  TMOD, #01H
    mov  TH0, #3CH
    mov  TL0, #0B0H
    setb TR0
    mov  IE, #82H          ; wlacz przerwanie timer0
    mov  CLOCK_RUNNING, #1
    mov  PREV_P3, #0
    mov  R5, #0
    mov  R6, #0
    mov  R7, #0
    lcall display_clock
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