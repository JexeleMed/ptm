$NOMOD51
$INCLUDE (reg517.inc)

; =======================================================
; ZEGAR Z KREATOREM POCZĄTKOWYM (KLAWIATURA MATRYCOWA)
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
F_RUNNING EQU 00H          ; FLAGA BITOWA: bit 0 w bajcie 20H (1=chodzi, 0=stop)
PREV_P3   EQU 21H          ; poprzedni stan P3.2-P3.5
TEMP_D1   EQU 22H          ; pierwsza wpisana cyfra (dziesiątki)

; ----- Przerwanie timer0 (co 50ms) -----
ORG 000BH
    PUSH PSW
    PUSH DPH
    PUSH DPL
    
    MOV TH0, #3CH
    MOV TL0, #0B0H
    DEC R0
    LCALL scan_buttons
    
    POP DPL
    POP DPH
    POP PSW
    RETI

; ----- Kod glówny -----
ORG 0100H

; Makra LCD (zabezpieczone)
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
    ret

; =======================================================
; OBSŁUGA KLAWIATURY MATRYCOWEJ (DO KREATORA)
; =======================================================
get_key:
    ; Odczytuje klawisz i zwraca jego binarną wartość (0-9) w ACC
    ; Jeśli wciśnięto '#', zwraca 0FFH
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
    JZ  scan_m             ; nieznany klawisz, ignoruj
    XRL A, R4
    JZ  k_found
    INC R2
    SJMP f_loop

k_found:
    ; Sprawdzamy czy to '#' (indeks 15 w naszej tabeli)
    MOV A, R2
    CJNE A, #15, check_digit
    MOV A, #0FFH           ; Zwracamy kod specjalny FFH dla '#'
    RET
check_digit:
    ; Pobieramy wartość numeryczną 0-9
    MOV DPTR, #NUM_VALUES
    MOV A, R2
    MOVC A, @A+DPTR
    ; Jeśli wybrano literę A-D lub '*', wartość to 0EEH (nie cyfra)
    CJNE A, #0EEH, digit_ok
    SJMP scan_m            ; ignorujemy litery, czekamy na cyfrę
digit_ok:
    RET

; =======================================================
; KREATOR POCZĄTKOWEGO USTAWIANIA CZASU
; =======================================================
setup_time:
    LCDcntrlWR #CLEAR
    MOV DPTR, #TXT_HOUR
    LCALL print_str

input_hour:
    ; 1. Pobierz dziesiątki godzin
    LCALL get_key
    CJNE A, #0FFH, h_d1_ok
    SJMP input_hour        ; ignoruj '#' na tym etapie
h_d1_ok:
    MOV TEMP_D1, A         ; Zapisz pierwszą cyfrę
    ADD A, #30H            ; Pokaż ASCII na LCD
    LCALL putcharLCD

    ; 2. Pobierz jedności godzin
get_h0:
    LCALL get_key
    CJNE A, #0FFH, h_d0_ok
    SJMP get_h0
h_d0_ok:
    MOV B, A               ; B = druga cyfra
    ADD A, #30H            ; Pokaż na LCD
    LCALL putcharLCD
    
    ; 3. Synteza: (TEMP_D1 * 10) + B
    MOV A, TEMP_D1
    MOV R4, B              ; Zabezpiecz B
    MOV B, #10
    MUL AB
    ADD A, R4
    
    ; 4. Weryfikacja zakresu (< 24)
    CLR C
    SUBB A, #24
    JNC hour_error         ; Jeśli wynik >= 0, błąd (godzina >= 24)
    
    ; Godzina poprawna
    MOV A, TEMP_D1
    MOV B, #10
    MUL AB
    ADD A, R4
    MOV R5, A              ; Zapisz gotową godzinę do R5
    SJMP ask_mins

hour_error:
    LCDcntrlWR #CLEAR
    MOV DPTR, #TXT_ERR
    LCALL print_str
    ACALL delay
    SJMP setup_time

ask_mins:
    LCDcntrlWR #CLEAR
    MOV DPTR, #TXT_MIN
    LCALL print_str

input_min:
    ; 1. Pobierz dziesiątki minut
    LCALL get_key
    CJNE A, #0FFH, m_d1_ok
    SJMP input_min
m_d1_ok:
    MOV TEMP_D1, A
    ADD A, #30H
    LCALL putcharLCD

    ; 2. Pobierz jedności minut
get_m0:
    LCALL get_key
    CJNE A, #0FFH, m_d0_ok
    SJMP get_m0
m_d0_ok:
    MOV B, A
    ADD A, #30H
    LCALL putcharLCD

    ; 3. Synteza: (TEMP_D1 * 10) + B
    MOV A, TEMP_D1
    MOV R4, B
    MOV B, #10
    MUL AB
    ADD A, R4

    ; 4. Weryfikacja zakresu (< 60)
    CLR C
    SUBB A, #60
    JNC min_error

    ; Minuty poprawne
    MOV A, TEMP_D1
    MOV B, #10
    MUL AB
    ADD A, R4
    MOV R6, A              ; Zapisz gotowe minuty do R6
    SJMP wait_confirm

min_error:
    LCDcntrlWR #CLEAR
    MOV DPTR, #TXT_ERR
    LCALL print_str
    ACALL delay
    SJMP ask_mins

wait_confirm:
    LCDcntrlWR #CLEAR
    MOV DPTR, #TXT_CONF
    LCALL print_str
    LCDcntrlWR #CLEAR
wc_loop:
    LCALL get_key
    CJNE A, #0FFH, wc_loop ; Czekamy wyłącznie na '#' (0FFH)
    RET                    ; Koniec kreatora!

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

; ---------- Inkrementacja czasu (Zegar) ----------
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

; ---------- Obsluga przycisków P3 (Start/Stop, + / -) ----------
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
    pop b
    pop acc
    ret

; ---------- Program glówny ----------
start:
    init_LCD
    MOV R7, #0             ; Sekundy zawsze startują od 0
    
    ; Uruchamiamy interaktywny kreator ustawiania czasu
    LCALL setup_time       
    
    ; Po zatwierdzeniu klawiszem '#', startujemy właściwy zegar
    mov  TMOD, #01H
    mov  TH0, #3CH
    mov  TL0, #0B0H
    setb TCON.4
    mov  0A8H, #82H          ; Włącz przerwanie Timera 0
    
    setb F_RUNNING         ; Zegar zaczyna chodzić
    mov  PREV_P3, #0
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
    ; Mapowanie klawiszy na czyste wartości liczbowe
    ; Kolejno dla klawiszy: 0,1,2,3,4,5,6,7,8,9, A, B, C, D, *, #
    DB 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0EEH, 0EEH, 0EEH, 0EEH, 0EEH, 0FFH

TXT_HOUR:  DB "Ustaw Godz: ", 0
TXT_MIN:   DB "Ustaw Min: ", 0
TXT_ERR:   DB "Blad! Zly zakres", 0
TXT_CONF:  DB "Zatwierdz [#]", 0

END start