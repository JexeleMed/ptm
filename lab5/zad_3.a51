$NOMOD51
$INCLUDE (reg517.inc)

; =======================================================
; ZEGAR Z KREATOREM (CZAS + ALARM) I BUZEREM
; =======================================================

ljmp start

; ----- Definicje portów (zgodne z ZD537) -----
LCDstatus  equ 0FF2EH
LCDcontrol equ 0FF2CH
LCDdataWR  equ 0FF2DH

HOME     equ 0x80
INITDISP equ 0x38
HOM2     equ 0xc0
LCDON    equ 0x0e
CLEAR    equ 0x01

; ----- Zmienne w IRAM -----
F_RUNNING  EQU 00H         ; FLAGA BITOWA: bit 0 w bajcie 20H (1=chodzi, 0=stop)
PREV_P3    EQU 21H         ; poprzedni stan P3.2-P3.5
TEMP_D1    EQU 22H         ; pierwsza wpisana cyfra
ALARM_HOUR EQU 23H         ; zapisana godzina alarmu
ALARM_MIN  EQU 24H         ; zapisana minuta alarmu
ALARM_TRIG EQU 25H         ; flaga: 1 = buzer dzwoni
ALARM_CNT  EQU 26H         ; licznik czasu dzwonienia (200 * 50ms = 10s)
ALARM_DONE EQU 27H         ; flaga blokująca ponowne wyzwolenie w tej samej minucie

; ----- Przerwanie timer0 (co 50ms) -----
ORG 000BH
    PUSH PSW
    PUSH DPH
    PUSH DPL
    PUSH ACC
    PUSH B

    MOV TH0, #3CH
    MOV TL0, #0B0H
    DEC R0
    
    LCALL scan_buttons          ; Przyciski sterujące czasem
    LCALL check_alarm_silence   ; Wyłączanie alarmu z klawiatury matrycowej
    LCALL alarm_handler         ; Logika dzwonienia i odliczania 10s

    POP B
    POP ACC
    POP DPL
    POP DPH
    POP PSW
    RETI

; ----- Kod glówny -----
ORG 0100H

; Makra LCD
LCDcntrlWR MACRO x
           LOCAL loop
           PUSH DPH
           PUSH DPL
           PUSH ACC
loop:      MOV  DPTR,#LCDstatus
           MOVX A,@DPTR
           JB   ACC.7,loop
           MOV  DPTR,#LCDcontrol
           MOV  A, x
           MOVX @DPTR,A
           POP  ACC
           POP  DPL
           POP  DPH
           ENDM

LCDcharWR MACRO
           LOCAL tutu
           PUSH DPH
           PUSH DPL
           PUSH ACC
tutu:      MOV  DPTR,#LCDstatus
           MOVX A,@DPTR
           JB   ACC.7,tutu
           MOV  DPTR,#LCDdataWR
           POP  ACC
           MOVX @DPTR,A
           POP  DPL
           POP  DPH
           ENDM

init_LCD MACRO
         LCDcntrlWR #INITDISP
         LCDcntrlWR #CLEAR
         LCDcntrlWR #LCDON
         ENDM

; ---------- Procedury opóźnienia ----------
delay:
    MOV R0, #5
one:MOV R1, #5
dwa:MOV R2, #5
trzy:DJNZ R2, trzy
    DJNZ R1, dwa
    DJNZ R0, one
    RET

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
    
    ; --- NOWOŚĆ: WYPISANIE ALARMU W 2 LINII ---
    LCDcntrlWR #HOM2
    mov  a, ALARM_HOUR
    lcall putdigitLCD
    mov  a, #':'
    lcall putcharLCD
    mov  a, ALARM_MIN
    lcall putdigitLCD
    ; ------------------------------------------
    
    ret

; =======================================================
; OBSŁUGA KLAWIATURY MATRYCOWEJ (DO KREATORA)
; =======================================================
get_key:
    ; Odczytuje klawisz i zwraca: 0-9 dla cyfr, 0FFH dla '#', 0FEH dla '*'
scan_m:
    MOV P5, #0EFH
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, k_pressed
    MOV P5, #0DFH
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, k_pressed
    MOV P5, #0BFH
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, k_pressed
    MOV P5, #07FH
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, k_pressed
    SJMP scan_m

k_pressed:
    MOV B, A
    MOV A, P5
    ANL A, #0F0H
    ORL A, B
    MOV R4, A
wait_rel:
    MOV P5, #00H
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, wait_rel
    ACALL delay

    MOV R2, #0
    MOV DPTR, #SCAN_CODES
f_loop:
    MOV A, R2
    MOVC A, @A+DPTR
    JZ  scan_m             
    XRL A, R4
    JZ  k_found
    INC R2
    SJMP f_loop

k_found:
    MOV DPTR, #NUM_VALUES
    MOV A, R2
    MOVC A, @A+DPTR
    ; Jeśli to A, B, C lub D (zwraca 0EEH) - ignorujemy
    CJNE A, #0EEH, digit_ok
    SJMP scan_m
digit_ok:
    RET

; =======================================================
; KREATOR POCZĄTKOWEGO USTAWIANIA (CZAS + ALARM)
; =======================================================
setup_full:
    ; --- ETAP 1: USTAWIENIE CZASU ---
    LCDcntrlWR #CLEAR
    MOV DPTR, #TXT_HOUR
    LCALL print_str
input_hour:
    LCALL get_key
    CJNE A, #0FFH, chk_ast1
    SJMP input_hour
chk_ast1:
    CJNE A, #0FEH, h_d1_ok
    SJMP input_hour
h_d1_ok:
    MOV TEMP_D1, A
    ADD A, #30H
    LCALL putcharLCD
get_h0:
    LCALL get_key
    CJNE A, #0FFH, chk_ast2
    SJMP get_h0
chk_ast2:
    CJNE A, #0FEH, h_d0_ok
    SJMP get_h0
h_d0_ok:
    MOV B, A
    ADD A, #30H
    LCALL putcharLCD
    ; Synteza (TEMP_D1 * 10) + B
    MOV A, TEMP_D1
    MOV R4, B
    MOV B, #10
    MUL AB
    ADD A, R4
    ; Weryfikacja
    CLR C
    SUBB A, #24
    JNC hour_error
    ; Zapis
    MOV A, TEMP_D1
    MOV B, #10
    MUL AB
    ADD A, R4
    MOV R5, A
    SJMP ask_mins
hour_error:
    LCDcntrlWR #CLEAR
    MOV DPTR, #TXT_ERR
    LCALL print_str
    ACALL delay
    LJMP setup_full

ask_mins:
    LCDcntrlWR #CLEAR
    MOV DPTR, #TXT_MIN
    LCALL print_str
input_min:
    LCALL get_key
    CJNE A, #0FFH, chk_ast3
    SJMP input_min
chk_ast3:
    CJNE A, #0FEH, m_d1_ok
    SJMP input_min
m_d1_ok:
    MOV TEMP_D1, A
    ADD A, #30H
    LCALL putcharLCD
get_m0:
    LCALL get_key
    CJNE A, #0FFH, chk_ast4
    SJMP get_m0
chk_ast4:
    CJNE A, #0FEH, m_d0_ok
    SJMP get_m0
m_d0_ok:
    MOV B, A
    ADD A, #30H
    LCALL putcharLCD
    
    MOV A, TEMP_D1
    MOV R4, B
    MOV B, #10
    MUL AB
    ADD A, R4
    CLR C
    SUBB A, #60
    JNC min_error
    MOV A, TEMP_D1
    MOV B, #10
    MUL AB
    ADD A, R4
    MOV R6, A
    SJMP wait_confirm
min_error:
    LCDcntrlWR #CLEAR
    MOV DPTR, #TXT_ERR
    LCALL print_str
    ACALL delay
    LJMP ask_mins

wait_confirm:
    LCDcntrlWR #CLEAR
    MOV DPTR, #TXT_CONF
    LCALL print_str
wc_loop:
    LCALL get_key
    CJNE A, #0FFH, wc_loop ; Czekamy na '#'
    
    ; --- ETAP 2: USTAWIENIE ALARMU ---
setup_alarm:
    LCDcntrlWR #CLEAR
    MOV DPTR, #TXT_ALARM_H
    LCALL print_str
input_ahour:
    LCALL get_key
    CJNE A, #0FFH, chk_ast5
    SJMP input_ahour
chk_ast5:
    CJNE A, #0FEH, ah_d1_ok
    SJMP input_ahour
ah_d1_ok:
    MOV TEMP_D1, A
    ADD A, #30H
    LCALL putcharLCD
get_ah0:
    LCALL get_key
    CJNE A, #0FFH, chk_ast6
    SJMP get_ah0
chk_ast6:
    CJNE A, #0FEH, ah_d0_ok
    SJMP get_ah0
ah_d0_ok:
    MOV B, A
    ADD A, #30H
    LCALL putcharLCD
    ; Synteza i weryfikacja
    MOV A, TEMP_D1
    MOV R4, B
    MOV B, #10
    MUL AB
    ADD A, R4
    CLR C
    SUBB A, #24
    JNC ahour_error
    MOV A, TEMP_D1
    MOV B, #10
    MUL AB
    ADD A, R4
    MOV ALARM_HOUR, A
    SJMP ask_amins
ahour_error:
    LCDcntrlWR #CLEAR
    MOV DPTR, #TXT_ERR
    LCALL print_str
    ACALL delay
    LJMP setup_alarm

ask_amins:
    LCDcntrlWR #CLEAR
    MOV DPTR, #TXT_ALARM_M
    LCALL print_str
input_amin:
    LCALL get_key
    CJNE A, #0FFH, chk_ast7
    SJMP input_amin
chk_ast7:
    CJNE A, #0FEH, am_d1_ok
    SJMP input_amin
am_d1_ok:
    MOV TEMP_D1, A
    ADD A, #30H
    LCALL putcharLCD
get_am0:
    LCALL get_key
    CJNE A, #0FFH, chk_ast8
    SJMP get_am0
chk_ast8:
    CJNE A, #0FEH, am_d0_ok
    SJMP get_am0
am_d0_ok:
    MOV B, A
    ADD A, #30H
    LCALL putcharLCD
    
    MOV A, TEMP_D1
    MOV R4, B
    MOV B, #10
    MUL AB
    ADD A, R4
    CLR C
    SUBB A, #60
    JNC amin_error
    MOV A, TEMP_D1
    MOV B, #10
    MUL AB
    ADD A, R4
    MOV ALARM_MIN, A
    SJMP wait_aconfirm
amin_error:
    LCDcntrlWR #CLEAR
    MOV DPTR, #TXT_ERR
    LCALL print_str
    ACALL delay
    LJMP ask_amins

wait_aconfirm:
    LCDcntrlWR #CLEAR
    MOV DPTR, #TXT_ACONF
    LCALL print_str
wac_loop:
    LCALL get_key
    CJNE A, #0FEH, wac_loop ; Czekamy na '*'
    LCDcntrlWR #CLEAR
    RET

; ---------- Wypisywanie łańcucha z ROM ----------
print_str:
    CLR A
    MOVC A, @A+DPTR
    JZ  p_str_end
    LCALL putcharLCD
    INC DPTR
    SJMP print_str
p_str_end:
    RET

; ---------- Inkrementacja czasu ----------
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

; =======================================================
; SYSTEM ALARMU I BUZERA
; =======================================================
buzzer_on:
    ORL  P6, #00010000B
    RET
buzzer_off:
    ANL  P6, #11101111B
    RET

alarm_handler:
    MOV A, ALARM_TRIG
    JZ check_match
    MOV A, R7
    RRC A
    JC sound_on
    LCALL buzzer_off
    SJMP check_counter
    ; Jeśli alarm jest aktywny, odliczamy czas
    DJNZ ALARM_CNT, ah_end
    ; 10 sekund minęło - wyłącz
    CLR ALARM_TRIG
    LCALL buzzer_off
    SJMP ah_end
sound_on:
    LCALL buzzer_on
check_counter:
    DJNZ ALARM_CNT, ah_end
    MOV ALARM_TRIG, #0
    LCALL buzzer_off
    SJMP ah_end
check_match:
    MOV A, R7
    JZ time_is_zero
    ; Gdy sekundy > 0, resetujemy blokadę
    MOV ALARM_DONE, #0
    SJMP ah_end
time_is_zero:
    ; Sprawdzamy czy już dzwonił w tej minucie
    MOV A, ALARM_DONE
    JNZ ah_end 
    ; Porównujemy czas
    MOV A, R6
    CJNE A, ALARM_MIN, ah_end
    MOV A, R5
    CJNE A, ALARM_HOUR, ah_end
    ; Wyzwól alarm!
    MOV ALARM_TRIG, #1
    MOV ALARM_DONE, #1       ; Zablokuj na resztę minuty
    MOV ALARM_CNT, #200      ; 200 * 50ms = 10 sekund
    LCALL buzzer_on
ah_end:
    RET

check_alarm_silence:
    MOV A, ALARM_TRIG
    JZ cas_end
    MOV A, P3
    JB ACC.4, cas_end
silence_it:
    MOV ALARM_TRIG, #0
    LCALL buzzer_off
cas_end:
    RET

; ---------- Obsluga przycisków P3 ----------
scan_buttons:
    mov  a, P3
    anl  a, #3Ch
    cpl  a
    mov  b, a
    xrl  a, PREV_P3
    anl  a, b
    mov  PREV_P3, b

    jb   acc.2, do_start_stop
    jb   acc.3, do_hour_plus	     
    jb   acc.5, do_hour_minus
    ljmp sb_end

do_start_stop:
    cpl  F_RUNNING
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
    jz   hm_zero
    dec  a
    sjmp hm_ok
hm_zero:
    mov  a, #23
hm_ok:
    mov  R5, a
    lcall display_clock
    ljmp sb_end
sb_end:
    ret

; ---------- Program glówny ----------
start:
    init_LCD
    MOV R7, #0             

    ; Uruchamiamy interaktywny kreator
    LCALL setup_full

    ; Startujemy zegar
    mov  TMOD, #01H
    mov  TH0, #3CH
    mov  TL0, #0B0H
    setb TCON.4            ; TR0
    mov  0A8H, #82H        ; IE (przerwania)

    setb F_RUNNING
    mov  PREV_P3, #0
    mov  ALARM_TRIG, #0
    mov  ALARM_DONE, #0
    LCALL buzzer_off
    lcall display_clock
    
    mov  R0, #20
    mov  A, #0FH
    mov  P1, A

main_loop:
    mov  A, R0
    jnz  main_loop
    mov  R0, #20

    jnb  F_RUNNING, skip_tick
    lcall inc_clock
    lcall display_clock

skip_tick:
    mov  A, P1
    cpl  A
    mov  P1, A
    ljmp main_loop

; --- TABELE DANYCH (W PAMIĘCI ROM / CODE) ---

SCAN_CODES:
    DB 0EBH, 077H, 07BH, 07DH, 0B7H, 0BBH, 0BDH, 0D7H, 0DBH, 0DDH
    DB 07EH, 0BEH, 0DEH, 0EEH, 0E7H, 0EDH, 00H

NUM_VALUES:
    ; Indeks: 0,1,2,3,4,5,6,7,8,9, A, B, C, D, *, #
    ; Znak '*' to teraz 0FEH, znak '#' to 0FFH
    DB 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0EEH, 0EEH, 0EEH, 0EEH, 0FEH, 0FFH

TXT_HOUR:    DB "Ustaw Godz: ", 0
TXT_MIN:     DB "Ustaw Min: ", 0
TXT_CONF:    DB "Zatwierdz [#]", 0
TXT_ALARM_H: DB "Alarm Godz: ", 0
TXT_ALARM_M: DB "Alarm Min: ", 0
TXT_ACONF:   DB "Zatwierdz [*]", 0
TXT_ERR:     DB "Blad! Zly zakres", 0

END start