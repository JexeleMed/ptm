$NOMOD51
NAME ORGANKI_P1
; ============================================================
; PROGRAM 1: ORGANKI - klawiatura + brzeczyk piezoelektryczny
; ============================================================
; Sprzet: ZD537, kwarc 12 MHz
; Brzeczyk piezo: P3.2 (BUZZpiezzo)
; Timer T0, tryb 1 (16-bit), przerwanie od T0
; Klawiatura: wiersze P5.7..P5.4, kolumny P7.3..P7.0
;
; Klawisze klawiatury ? dzwieki (gama C-dur + póltony):
;
;  Klawisz | Kod ska. | Nuta  | Hz
;  --------|----------|-------|------
;    1      |   77h    | C1    | 261.6
;    2      |   7Bh    | D1    | 293.7
;    3      |   7Dh    | E1    | 329.6
;    4      |   B7h    | F1    | 349.2
;    5      |   BBh    | G1    | 392.0
;    6      |   BDh    | A1    | 440.0
;    7      |   BEh    | H1    | 493.9
;    8      |   D7h    | C2    | 523.3
;    9      |   DBh    | D2    | 587.3
;    A      |   DDh    | E2    | (nie uzywany - klawisz A to DIS1)
;    B      |   DEh    | (ekstra)
;    0      |   EBh    | CIS2  | 554.4
;    *      |   E7h    | B1    | 466.2
;    #      |   EDh    | D2    | 587.3
;
; UWAGA: SW1 musi byc w pozycji OFF gdy uzywamy klawiatury!
; ============================================================

$NOLIST
$INCLUDE(reg517.inc)
$LIST
	
EA   BIT  0AFH    ; bit globalnego zezwolenia na przerwania (IE.7)

; --- Definicje ZD537 ---
BUZZpiezzo  BIT  P3.2       ; Brzeczyk piezoelektryczny

; --- Zmienne w IRAM ---
DSEG AT 30H
TH0_VAL:    DS 1    ; aktualna wartosc TH0 do przeladowania
TL0_VAL:    DS 1    ; aktualna wartosc TL0 do przeladowania
KEY_CODE:   DS 1    ; ostatni odczytany kod skaningowy
SOUND_ON:   DS 1    ; flaga: 1=generuj dzwiek, 0=cisza

; --- Stos ---
?STACK SEGMENT IDATA
RSEG ?STACK
DS 40

; --- Wektor RESET ---
CSEG AT 0000H
    LJMP START

; --- Wektor przerwania Timer0 (0x000B) ---
CSEG AT 000BH
    LJMP TIMER0_ISR

; ============================================================
; Segment kodu glównego
; ============================================================
PROG SEGMENT CODE
RSEG PROG
USING 0

START:
    MOV SP, #?STACK-1

    ; Wylacz buzzer 1kHz (P6.4)
    ANL P6, #11101111B

    ; Inicjalizacja zmiennych
    MOV TH0_VAL, #0F8H   ; domyslnie C1 (TH0=F8, TL0=89)
    MOV TL0_VAL, #089H
    MOV KEY_CODE, #0FFH
    MOV SOUND_ON, #0

    ; Konfiguracja Timer0: tryb 1 (16-bit), bez auto-reload
    MOV TMOD, #00000001B  ; T0 Mode1, T1 nie uzywany
    MOV A, TH0_VAL
    MOV TH0, A
    MOV A, TL0_VAL
    MOV TL0, A

    ; Wlacz przerwanie Timer0
    SETB ET0
    SETB EA
    CLR TR0               ; timer wylaczony na start (cisza)

    ; Port P5 jako wyjscie (wiersze klawiatury)
    ; Port P7 jako wejscie (kolumny klawiatury)
    MOV P5, #0FFH         ; wszystkie wiersze wysokie
    MOV P7, #0FFH         ; P7 wejscie (pull-up)

; ============================================================
; Petla glówna
; ============================================================
MAIN_LOOP:
    CALL SCAN_KEYBOARD    ; szuka wcisnietego klawisza
    JZ   NO_KEY           ; jesli A=0 to zaden klawisz

    ; Znaleziono klawisz - zaladuj parametry dzwieku
    CALL FIND_NOTE        ; szuka TH0/TL0 dla kodu w A
    JNC  PLAY_NOTE        ; jesli znaleziono (CY=0), graj

NO_KEY:
    ; Zaden klawisz nie wcisniety - wylacz dzwiek
    CLR TR0
    MOV SOUND_ON, #0
    CLR BUZZpiezzo        ; upewnij sie ze piezzo nie dzwoni
    SJMP MAIN_LOOP

PLAY_NOTE:
    ; Zaladuj wartosci do rejestru i timera
    ; TH0_VAL i TL0_VAL zostaly ustawione przez FIND_NOTE
    CLR TR0
    MOV A, TH0_VAL
    MOV TH0, A
    MOV A, TL0_VAL
    MOV TL0, A
    MOV SOUND_ON, #1
    SETB TR0
    SJMP MAIN_LOOP
; ============================================================
; Procedura przerwania Timer0
; Przelacza P3.2 i przeladowuje timer
; ============================================================
TIMER0_ISR:
    CLR TR0
    MOV A, TH0_VAL
    MOV TH0, A
    MOV A, TL0_VAL
    MOV TL0, A
    SETB TR0
    CPL BUZZpiezzo
    RETI

; ============================================================
; SCAN_KEYBOARD
; Zwraca w A: kod skaningowy (7-bitowy) lub 0 jesli brak
; Kolumny: P7.3..P7.0 (wejscia z pull-up)
; Wiersze:  P5.7..P5.4 (wyj. - aktywne LOW)
;
; Schemat klawiatury ZD537 (ze schematu str.21):
; Wiersz P5.4 (maska 0EFH):  kl. 1,4,7,*
; Wiersz P5.5 (maska 0DFH):  kl. 2,5,8,0
; Wiersz P5.6 (maska 0BFH):  kl. 3,6,9,#
; Wiersz P5.7 (maska 07FH):  kl. A,B,C,D
;
; Kolumny P7: bit3=lewa, bit0=prawa
; Kod skaningowy = P5 OR P7 (aktywne bity = 0)
; ============================================================
SCAN_KEYBOARD:
    MOV P5, #0FFH         ; wszystkie wiersze wysokie
    MOV P7, #0FFH

    ; Skanuj wiersz 1 (P5.4 = 0)
    MOV P5, #11101111B    ; P5.4 = 0
    NOP
    NOP
    MOV A, P7
    ANL A, #0FH           ; dolne 4 bity
    CPL A
    ANL A, #0FH
    JNZ ROW1_HIT

    ; Skanuj wiersz 2 (P5.5 = 0)
    MOV P5, #11011111B
    NOP
    NOP
    MOV A, P7
    ANL A, #0FH
    CPL A
    ANL A, #0FH
    JNZ ROW2_HIT

    ; Skanuj wiersz 3 (P5.6 = 0)
    MOV P5, #10111111B
    NOP
    NOP
    MOV A, P7
    ANL A, #0FH
    CPL A
    ANL A, #0FH
    JNZ ROW3_HIT

    ; Skanuj wiersz 4 (P5.7 = 0)
    MOV P5, #01111111B
    NOP
    NOP
    MOV A, P7
    ANL A, #0FH
    CPL A
    ANL A, #0FH
    JNZ ROW4_HIT

    ; Zaden klawisz nie wcisniety
    MOV P5, #0FFH
    MOV A, #0
    RET

ROW1_HIT:
    MOV P5, #11101111B
    NOP
    NOP
    MOV A, P7
    ANL A, #0FH           ; dolne 4 bity bez negacji -> 0Eh dla kl.1
    ORL A, #70H           ; dodaj wiersz -> 7Eh
    MOV KEY_CODE, A
    MOV A, KEY_CODE
    RET

ROW2_HIT:
    MOV P5, #11011111B
    NOP
    NOP
    MOV A, P7
    ANL A, #0FH
    ORL A, #0B0H          ; kod wiersza 2 = 1011xxxx
    MOV KEY_CODE, A
    MOV A, KEY_CODE
    RET

ROW3_HIT:
    MOV P5, #10111111B
    NOP
    NOP
    MOV A, P7
    ANL A, #0FH
    ORL A, #0D0H          ; kod wiersza 3 = 1101xxxx
    MOV KEY_CODE, A
    MOV A, KEY_CODE
    RET

ROW4_HIT:
    MOV P5, #01111111B
    NOP
    NOP
    MOV A, P7
    ANL A, #0FH
    ORL A, #0E0H          ; kod wiersza 4 = 1110xxxx
    MOV KEY_CODE, A
    MOV A, KEY_CODE
    RET

; ============================================================
; FIND_NOTE
; Wejscie: A = kod skaningowy z P7 (dolne 4 bity = kolumna,
;          górne bity = wiersz)
; Wyjscie: TH0_VAL, TL0_VAL ustawione
;          CY=0 jesli znaleziono, CY=1 jesli nie
;
; Tabela: kod_skan, TH0, TL0
; Kody zgodne z dokumentem XRAM-Key-Muz-16-key.pdf
; ============================================================
FIND_NOTE:
    MOV DPTR, #NOTE_TABLE
    MOV R0, #0            ; indeks w tabeli

FIND_LOOP:
    MOV A, R0
    MOVC A, @A+DPTR       ; pobierz kod skaningowy z tabeli
    JZ  FIND_NOTFOUND     ; 00h = koniec tabeli
    CJNE A, KEY_CODE, FIND_NEXT

    ; Znaleziono - pobierz TH0 i TL0
    INC R0
    MOV A, R0
    MOVC A, @A+DPTR
    MOV TH0_VAL, A
    INC R0
    MOV A, R0
    MOVC A, @A+DPTR
    MOV TL0_VAL, A
    CLR C                 ; CY=0: znaleziono
    RET

FIND_NEXT:
    INC R0
    INC R0
    INC R0                ; przeskocz 3 bajty (kod, TH0, TL0)
    SJMP FIND_LOOP

FIND_NOTFOUND:
    SETB C                ; CY=1: nie znaleziono
    RET

; ============================================================
; Tabela nut: kod_skan, TH0, TL0
; Dane z arkusza XRAM-Key-Muz-16-key.pdf
;
; Klawiatura ZD537: po analizie schematu kody P7 OR P5_row:
;   Klawisz 1 ? P5.4=0, P7.0=0 ? A = EEh (inv) ? kod 77h
;   Klawisz 4 ? P5.4=0, P7.1=0 ? kod B7h
;   itp.
; Uzywamy kodów z kolumny "Kod skaningowy" z dokumentu
; ============================================================
?CO?NOTES SEGMENT CODE
RSEG ?CO?NOTES

NOTE_TABLE:
    DB 07EH, 0F8H, 089H   ; klawisz "1" -> C1  261.6 Hz
    DB 07DH, 0F9H, 05AH   ; klawisz "4" -> D1  293.7 Hz
    DB 07BH, 0FAH, 013H   ; klawisz "7" -> E1  329.6 Hz
    DB 077H, 0FAH, 068H   ; klawisz "*" -> F1  349.2 Hz
    DB 0BEH, 0FBH, 004H   ; klawisz "2" -> G1  392.0 Hz
    DB 0BDH, 0FBH, 090H   ; klawisz "5" -> A1  440.0 Hz
    DB 0BBH, 0FCH, 00CH   ; klawisz "8" -> H1  493.9 Hz
    DB 0B7H, 0FCH, 045H   ; klawisz "0" -> C2  523.3 Hz
    DB 000H               ; koniec tabeli

END