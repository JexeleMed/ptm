$NOMOD51
NAME ORGANKI_P3
; ============================================================
; PROGRAM 3: ORGANKI ZE ZMIANA BARWY DZWIEKU
; ============================================================
; Sprzet: ZD537 (80C537), kwarc 12 MHz
; Klawiatura matrycowa 4x4 (jak w programie 2)
; Brzeczyk: P3.2
; Przycisk zmiany trybu: P3.3 (BUTTON_MODE)
; Wyswietlacz LCD: adresy FF2xh
;
; Opis:
;   - Program jak wyzej, ale dodatkowo przycisk P3.3 przelacza
;     barwe dzwieku w trzech trybach:
;       0 – Organy   (wypelnienie 50%)
;       1 – Klarnet  (wypelnienie 25%)
;       2 – Fagot    (wypelnienie 75%)
;   - W drugiej linii LCD wyswietlana jest nazwa biezacego trybu.
;   - Tabela TIMBRE_TABLE zawiera dla kazdej nuty dwie pary
;     (TH0, TL0): dluga i krótka, które sa wykorzystywane
;     w przerwaniu Timera 0 do utworzenia niesymetrycznej fali.
;
; UWAGA: Przed wgraniem na plyte nalezy przywrócic oryginalne
;        opóznienia w LCD_INITIALIZE (R7,R6 = 0FFH) oraz
;        sprawdzic, czy SW1 sa wszystkie OFF.
; ============================================================

$NOLIST
$INCLUDE(reg517.inc)
$LIST

; Definicje bitów
EA          BIT     0AFH        ; IE.7
BUZZpiezzo  BIT     P3.2        ; brzeczyk
BUTTON_MODE BIT     P3.3        ; przycisk zmiany trybu (aktywny LOW)

; Adresy LCD
LCDstatus   EQU     0FF2EH
LCDcontrol  EQU     0FF2CH
LCDdataWR   EQU     0FF2DH

; Rozkazy LCD
LCD_CLEAR   EQU     001H
LCD_HOME    EQU     080H
LCD_LINE2   EQU     0C0H
LCD_INIT    EQU     038H
LCD_ON      EQU     00EH

; ============================================================
; Zmienne w IRAM (od adresu 30H)
; ============================================================
DSEG AT 30H
TH0_VAL:    DS      1       ; dla trybu 0 – stala TH0
TL0_VAL:    DS      1       ; dla trybu 0 – stala TL0
KEY_CODE:   DS      1
SOUND_ON:   DS      1
LAST_KEY:   DS      1
NOTE_IDX:   DS      1
SOUND_MODE: DS      1       ; aktualny tryb: 0=Organy, 1=Klarnet, 2=Fagot
PHASE:      DS      1       ; faza przebiegu (0=stan wysoki, 1=niski)

; Stos
?STACK      SEGMENT IDATA
            RSEG    ?STACK
            DS      40

; Wektory przerwan
CSEG AT 0000H
    LJMP    START

CSEG AT 000BH
    LJMP    TIMER0_ISR

; ============================================================
; Kod glówny
; ============================================================
PROG        SEGMENT CODE
            RSEG    PROG
            USING   0

START:
    MOV     WDTREL, #03CH          ; wylacz watchdog
    MOV     SP, #?STACK-1
    ANL     P6, #11101111B         ; wylacz buzzer 1kHz (P6.4)

    ; Inicjalizacja zmiennych
    MOV     TH0_VAL, #0F8H         ; domyslnie C1
    MOV     TL0_VAL, #089H
    MOV     KEY_CODE, #0FFH
    MOV     LAST_KEY, #0FFH
    MOV     SOUND_ON, #0
    MOV     NOTE_IDX, #0FFH
    MOV     SOUND_MODE, #0         ; start od Organów
    MOV     PHASE, #0

    ; Timer 0 – tryb 1
    MOV     TMOD, #00000001B
    MOV     A, TH0_VAL
    MOV     TH0, A
    MOV     A, TL0_VAL
    MOV     TL0, A
    SETB    ET0
    SETB    EA
    CLR     TR0

    MOV     P5, #0FFH
    MOV     P7, #0FFH

    CALL    LCD_INITIALIZE
    CALL    UPDATE_MODE_LCD       ; wyswietl nazwe trybu (Organy)

    ; Szablon pierwszej linii: "Nuta: ----"
    MOV     A, #LCD_HOME
    CALL    LCD_CTRL
    MOV     DPTR, #TXT_NUTA
    CALL    LCD_PUTSTR
    MOV     DPTR, #TXT_DASH
    CALL    LCD_PUTSTR

; ============================================================
; Petla glówna
; ============================================================
MAIN_LOOP:
    ; Obsluga przycisku trybu (P3.3)
    JB      BUTTON_MODE, SCAN_KEY   ; jesli nie wcisniety -> pomin
    CALL    DELAY_DEBOUNCE
    JB      BUTTON_MODE, SCAN_KEY   ; sprawdz powtórnie (drgania)
WAIT_RELEASE:
    JNB     BUTTON_MODE, WAIT_RELEASE ; czekaj na puszczenie
    CALL    DELAY_DEBOUNCE
    ; Zwieksz tryb cyklicznie
    INC     SOUND_MODE
    MOV     A, SOUND_MODE
    CJNE    A, #3, MODE_OK
    MOV     SOUND_MODE, #0
MODE_OK:
    CALL    UPDATE_MODE_LCD         ; odswiez nazwe trybu na LCD
    ; Jesli aktualnie gra, zrestartuj timer, by zmiana byla natychmiastowa
    MOV     A, SOUND_ON
    JZ      SCAN_KEY
    CLR     TR0
    SETB    TR0
    SJMP    SCAN_KEY

SCAN_KEY:
    CALL    SCAN_KEYBOARD
    JZ      NO_KEY

    CJNE    A, LAST_KEY, NEW_KEY
    SJMP    MAIN_LOOP

NEW_KEY:
    MOV     LAST_KEY, A
    MOV     KEY_CODE, A
    CALL    FIND_NOTE
    JC      NO_KEY

    CLR     TR0
    ; W trybie 0 ladujemy stale, w 1 i 2 – wartosci pobierze ISR
    MOV     A, SOUND_MODE
    JNZ     NOT_MODE0
    MOV     A, TH0_VAL
    MOV     TH0, A
    MOV     A, TL0_VAL
    MOV     TL0, A
NOT_MODE0:
    MOV     SOUND_ON, #1
    MOV     PHASE, #0
    SETB    TR0

    CALL    UPDATE_LCD_NOTE
    SJMP    MAIN_LOOP

NO_KEY:
    CLR     TR0
    MOV     SOUND_ON, #0
    CLR     BUZZpiezzo

    MOV     A, LAST_KEY
    CJNE    A, #0FFH, CLEAR_NOTE
    SJMP    MAIN_LOOP

CLEAR_NOTE:
    MOV     LAST_KEY, #0FFH
    MOV     A, #LCD_HOME
    CALL    LCD_CTRL
    MOV     DPTR, #TXT_NUTA
    CALL    LCD_PUTSTR
    MOV     DPTR, #TXT_DASH
    CALL    LCD_PUTSTR
    SJMP    MAIN_LOOP

; ============================================================
; Przerwanie Timera 0 – generowanie dzwieku zaleznie od trybu
; ============================================================
TIMER0_ISR:
    CLR     TR0
    CPL     BUZZpiezzo              ; przelacz stan wyjscia

    MOV     A, SOUND_MODE
    JZ      LOAD_ORGAN              ; tryb 0 – stale parametry

    ; Tryby 1 i 2 – parametry z tablicy TIMBRE_TABLE
    PUSH    DPH                     ; ochrona DPTR (kluczowe!)
    PUSH    DPL

    MOV     A, NOTE_IDX
    MOV     B, #4                   ; wpis dla nuty to 4 bajty
    MUL     AB
    MOV     DPTR, #TIMBRE_TABLE
    ADD     A, DPL
    MOV     DPL, A
    MOV     A, B
    ADDC    A, DPH
    MOV     DPH, A                  ; DPTR -> poczatek wpisu dla nuty

    MOV     A, PHASE
    JZ      LOAD_HIGH_PHASE
    ; Faza niska – drugie slowo (indeks +2)
    INC     DPTR
    INC     DPTR
LOAD_HIGH_PHASE:
    CLR     A
    MOVC    A, @A+DPTR
    MOV     TH0, A
    INC     DPTR
    CLR     A
    MOVC    A, @A+DPTR
    MOV     TL0, A

    XRL     PHASE, #1               ; zmien faze (0->1 lub 1->0)

    POP     DPL
    POP     DPH
    SJMP    ISR_EXIT

LOAD_ORGAN:
    ; Tryb Organy – stale wartosci (50% wypelnienia)
    MOV     A, TH0_VAL
    MOV     TH0, A
    MOV     A, TL0_VAL
    MOV     TL0, A

ISR_EXIT:
    SETB    TR0
    RETI

; ============================================================
; UPDATE_MODE_LCD – wyswietla nazwe trybu w drugiej linii
; ============================================================
UPDATE_MODE_LCD:
    MOV     A, #LCD_LINE2
    CALL    LCD_CTRL
    MOV     DPTR, #MODE_NAMES
    MOV     A, SOUND_MODE
    MOV     B, #10                  ; kazdy napis ma 10 znaków
    MUL     AB
    ADD     A, DPL
    MOV     DPL, A
    MOV     A, B
    ADDC    A, DPH
    MOV     DPH, A
    MOV     R2, #10
MODE_DISP:
    CLR     A
    MOVC    A, @A+DPTR
    PUSH    DPH                     ; ochrona wskaznika
    PUSH    DPL
    CALL    LCD_PUTCHAR
    POP     DPL
    POP     DPH
    INC     DPTR
    DJNZ    R2, MODE_DISP
    RET

; ============================================================
; DELAY_DEBOUNCE – opóznienie dla przycisku trybu
; ============================================================
DELAY_DEBOUNCE:
    MOV     R7, #100
DEB_LOOP:
    MOV     R6, #250
    DJNZ    R6, $
    DJNZ    R7, DEB_LOOP
    RET

; ============================================================
; SCAN_KEYBOARD, FIND_NOTE, UPDATE_LCD_NOTE, procedury LCD
; – identyczne jak w zadaniu 2, ale UPDATE_LCD_NOTE juz z
;   ochrona DPTR (PUSH/POP) – tu powtarzamy dla kompletnosci
; ============================================================
SCAN_KEYBOARD:
    MOV     P5, #0FFH
    MOV     P7, #0FFH

    MOV     P5, #11101111B
    NOP
    NOP
    MOV     A, P7
    ANL     A, #0FH
    CJNE    A, #0FH, ROW1_HIT

    MOV     P5, #11011111B
    NOP
    NOP
    MOV     A, P7
    ANL     A, #0FH
    CJNE    A, #0FH, ROW2_HIT

    MOV     P5, #10111111B
    NOP
    NOP
    MOV     A, P7
    ANL     A, #0FH
    CJNE    A, #0FH, ROW3_HIT

    MOV     P5, #01111111B
    NOP
    NOP
    MOV     A, P7
    ANL     A, #0FH
    CJNE    A, #0FH, ROW4_HIT

    MOV     P5, #0FFH
    MOV     A, #0
    RET

ROW1_HIT:
    MOV     P5, #11101111B
    NOP
    NOP
    MOV     A, P7
    ANL     A, #0FH
    ORL     A, #70H
    MOV     KEY_CODE, A
    MOV     A, KEY_CODE
    RET

ROW2_HIT:
    MOV     P5, #11011111B
    NOP
    NOP
    MOV     A, P7
    ANL     A, #0FH
    ORL     A, #0B0H
    MOV     KEY_CODE, A
    MOV     A, KEY_CODE
    RET

ROW3_HIT:
    MOV     P5, #10111111B
    NOP
    NOP
    MOV     A, P7
    ANL     A, #0FH
    ORL     A, #0D0H
    MOV     KEY_CODE, A
    MOV     A, KEY_CODE
    RET

ROW4_HIT:
    MOV     P5, #01111111B
    NOP
    NOP
    MOV     A, P7
    ANL     A, #0FH
    ORL     A, #0E0H
    MOV     KEY_CODE, A
    MOV     A, KEY_CODE
    RET

FIND_NOTE:
    MOV     DPTR, #NOTE_TABLE
    MOV     R0, #0
    MOV     R1, #0
FIND_LOOP:
    MOV     A, R0
    MOVC    A, @A+DPTR
    JZ      FIND_NOTFOUND
    CJNE    A, KEY_CODE, FIND_NEXT
    INC     R0
    MOV     A, R0
    MOVC    A, @A+DPTR
    MOV     TH0_VAL, A
    INC     R0
    MOV     A, R0
    MOVC    A, @A+DPTR
    MOV     TL0_VAL, A
    MOV     NOTE_IDX, R1
    CLR     C
    RET

FIND_NEXT:
    INC     R0
    INC     R0
    INC     R0
    INC     R1
    SJMP    FIND_LOOP

FIND_NOTFOUND:
    SETB    C
    RET

UPDATE_LCD_NOTE:
    MOV     A, #LCD_HOME
    CALL    LCD_CTRL
    MOV     DPTR, #TXT_NUTA
    CALL    LCD_PUTSTR

    MOV     A, NOTE_IDX
    MOV     B, #4
    MUL     AB
    MOV     DPTR, #NAME_TABLE
    ADD     A, DPL
    MOV     DPL, A
    MOV     A, B
    ADDC    A, DPH
    MOV     DPH, A

    MOV     R2, #4
DISP_LOOP:
    CLR     A
    MOVC    A, @A+DPTR
    PUSH    DPH
    PUSH    DPL
    CALL    LCD_PUTCHAR
    POP     DPL
    POP     DPH
    INC     DPTR
    DJNZ    R2, DISP_LOOP
    RET

; Procedury LCD (takie same jak w zadaniu 2)
LCD_WAIT:
    PUSH    DPH
    PUSH    DPL
LCD_WAIT_LOOP:
    MOV     DPTR, #LCDstatus
    MOVX    A, @DPTR
    JB      ACC.7, LCD_WAIT_LOOP
    POP     DPL
    POP     DPH
    RET

LCD_CTRL:
    PUSH    ACC
    CALL    LCD_WAIT
    MOV     DPTR, #LCDcontrol
    POP     ACC
    MOVX    @DPTR, A
    RET

LCD_PUTCHAR:
    PUSH    ACC
    CALL    LCD_WAIT
    MOV     DPTR, #LCDdataWR
    POP     ACC
    MOVX    @DPTR, A
    RET

LCD_PUTSTR:
    CLR     A
    MOVC    A, @A+DPTR
    JZ      LCD_PUTSTR_END
    PUSH    DPH
    PUSH    DPL
    CALL    LCD_PUTCHAR
    POP     DPL
    POP     DPH
    INC     DPTR
    SJMP    LCD_PUTSTR
LCD_PUTSTR_END:
    RET

LCD_INITIALIZE:
    MOV     R7, #0FFH
INIT_DLY:
    MOV     R6, #0FFH
INIT_DLY2:
    DJNZ    R6, INIT_DLY2
    DJNZ    R7, INIT_DLY
    MOV     A, #LCD_INIT
    CALL    LCD_CTRL
    MOV     A, #LCD_CLEAR
    CALL    LCD_CTRL
    MOV     A, #LCD_ON
    CALL    LCD_CTRL
    RET

; ============================================================
; Dane stale
; ============================================================
?CO?DATA    SEGMENT CODE
            RSEG    ?CO?DATA

NOTE_TABLE:
    DB 07EH, 0F8H, 089H   ; C1
    DB 07DH, 0F9H, 05AH   ; D1
    DB 07BH, 0FAH, 013H   ; E1
    DB 077H, 0FAH, 068H   ; F1
    DB 0BEH, 0FBH, 004H   ; G1
    DB 0BDH, 0FBH, 090H   ; A1
    DB 0BBH, 0FCH, 00CH   ; H1
    DB 0B7H, 0FCH, 045H   ; C2
    DB 000H

NAME_TABLE:
    DB 'C','1',' ',' '     ; 0
    DB 'D','1',' ',' '     ; 1
    DB 'E','1',' ',' '     ; 2
    DB 'F','1',' ',' '     ; 3
    DB 'G','1',' ',' '     ; 4
    DB 'A','1',' ',' '     ; 5
    DB 'H','1',' ',' '     ; 6
    DB 'C','2',' ',' '     ; 7

TXT_NUTA:
    DB 'N','u','t','a',':',' ',0
TXT_DASH:
    DB '-','-','-','-',0

; Nazwy trybów – dokladnie 10 znaków kazdy
MODE_NAMES:
    DB 'Organy   '
    DB 'Klarnet  '
    DB 'Fagot    '

; Tablica par (dlugi, krótki) dla kazdej nuty (tryby 1 i 2)
; Format: TH_long, TL_long, TH_short, TL_short
TIMBRE_TABLE:
    ; C1 261.6 Hz
    DB 0F4H, 0CDH, 0FCH, 044H
    ; D1 293.7 Hz
    DB 0F9H, 05AH, 0FAH, 013H
    ; E1 329.6 Hz
    DB 0FAH, 013H, 0FAH, 068H
    ; F1 349.2 Hz
    DB 0FAH, 068H, 0FAH, 0B9H
    ; G1 392.0 Hz
    DB 0FBH, 004H, 0FBH, 04CH
    ; A1 440.0 Hz
    DB 0FBH, 090H, 0FBH, 0BFH
    ; H1 493.9 Hz
    DB 0FCH, 00CH, 0FCH, 045H
    ; C2 523.3 Hz
    DB 0FCH, 045H, 0FCH, 07AH

    END