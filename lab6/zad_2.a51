$NOMOD51
NAME ORGANKI_P2
; ============================================================
; PROGRAM 2: ORGANKI Z WYSWIETLACZEM LCD
; ============================================================
; Sprzet: ZD537 (mikrokontroler 80C537), kwarc 12 MHz
; Brzeczyk piezoelektryczny: P3.2 (BUZZpiezzo)
; Klawiatura matrycowa 4x4:
;   - wiersze: P5.4, P5.5, P5.6, P5.7 (wyjscia, aktywne LOW)
;   - kolumny: P7.0, P7.1, P7.2, P7.3 (wejscia z pull-up)
; Wyswietlacz LCD: rejestry w przestrzeni XRAM (adresy FF2xh)
;   - sterowanie zgodne z HD44780
; Timer T0: tryb 1 (16-bit), przerwanie do generowania fali prostokatnej
;
; Opis dzialania:
;   1. Inicjalizacja sprzetu i wyswietlacza.
;   2. Wyswietlenie stalego napisu "Organki ZD537" (druga linia)
;      oraz "Nuta: ----" (pierwsza linia).
;   3. Petla glówna skanuje klawiature. Po wcisnieciu klawisza:
;      - rozpoznaje nute (C1..C2) i uruchamia dzwiek na P3.2,
;      - wyswietla nazwe nuty (np. "C1 ") w pierwszej linii.
;   4. Po zwolnieniu klawisza dzwiek gasnie, a wyswietlacz wraca
;      do napisu "Nuta: ----".
;
; UWAGA: Przelaczniki SW1 musza byc wszystkie w pozycji OFF!
; ============================================================

$NOLIST
$INCLUDE(reg517.inc)        ; definicje rejestrów procesora 80C537
$LIST

; Definicje bitów
EA          BIT     0AFH    ; globalne zezwolenie na przerwania (IE.7)
BUZZpiezzo  BIT     P3.2    ; brzeczyk piezo (bezposrednio na pinie)

; Adresy rejestrów LCD w przestrzeni XRAM (zgodne z ZD537)
LCDstatus   EQU     0FF2EH  ; rejestr stanu (bit 7 = busy)
LCDcontrol  EQU     0FF2CH  ; rejestr rozkazów
LCDdataWR   EQU     0FF2DH  ; rejestr danych do zapisu

; Rozkazy sterownika LCD
LCD_CLEAR   EQU     001H    ; wyczysc wyswietlacz
LCD_HOME    EQU     080H    ; kursor na poczatek pierwszej linii
LCD_LINE2   EQU     0C0H    ; kursor na poczatek drugiej linii
LCD_INIT    EQU     038H    ; tryb 8-bitowy, 2 linie
LCD_ON      EQU     00EH    ; wlacz LCD, kursor wylaczony, miganie wyl.

; ============================================================
; Zmienne w wewnetrznym RAM (adresy od 30H)
; ============================================================
DSEG AT 30H
TH0_VAL:    DS      1       ; wartosc do przeladowania TH0 (starszy bajt)
TL0_VAL:    DS      1       ; wartosc do przeladowania TL0 (mlodszy bajt)
KEY_CODE:   DS      1       ; kod skaningowy ostatnio wcisnietego klawisza
SOUND_ON:   DS      1       ; flaga: 1 = dzwiek aktywny, 0 = cisza
LAST_KEY:   DS      1       ; poprzedni klawisz (do wykrywania zmian)
NOTE_IDX:   DS      1       ; indeks nuty (0..7) -> numer w tabeli nazw

; ============================================================
; Stos (wewnetrzny RAM)
; ============================================================
?STACK      SEGMENT IDATA
            RSEG    ?STACK
            DS      40      ; rezerwuj 40 bajtów na stos

; ============================================================
; Wektory przerwan
; ============================================================
CSEG AT 0000H
    LJMP    START           ; po resecie skocz do START

CSEG AT 000BH
    LJMP    TIMER0_ISR      ; przerwanie od Timera 0

; ============================================================
; Glówny segment kodu
; ============================================================
PROG        SEGMENT CODE
            RSEG    PROG
            USING   0

START:
    ; Wylacz watchdog (inaczej bedzie resetowal procesor!)
    MOV     WDTREL, #03CH

    MOV     SP, #?STACK-1   ; ustaw wskaznik stosu na koniec obszaru
    ANL     P6, #11101111B  ; wylacz buzzer 1kHz (P6.4 = 0)

    ; Domyslne parametry dzwieku (C1)
    MOV     TH0_VAL, #0F8H
    MOV     TL0_VAL, #089H
    MOV     KEY_CODE, #0FFH
    MOV     LAST_KEY, #0FFH
    MOV     SOUND_ON, #0
    MOV     NOTE_IDX, #0FFH

    ; Konfiguracja Timera 0: tryb 1 (16-bit), bez auto-reload
    MOV     TMOD, #00000001B ; T0 = tryb 1, T1 nieuzywany
    MOV     A, TH0_VAL
    MOV     TH0, A
    MOV     A, TL0_VAL
    MOV     TL0, A
    SETB    ET0             ; zezwól na przerwanie od T0
    SETB    EA              ; globalne zezwolenie na przerwania
    CLR     TR0             ; timer zatrzymany (cisza)

    ; Porty klawiatury: P5 jako wyjscia (wiersze), P7 jako wejscia (kolumny)
    MOV     P5, #0FFH
    MOV     P7, #0FFH

    ; Inicjalizacja wyswietlacza LCD
    CALL    LCD_INITIALIZE

    ; Wyswietlenie stalego napisu w drugiej linii: "Organki ZD537"
    MOV     A, #LCD_LINE2   ; kursor na druga linie
    CALL    LCD_CTRL
    MOV     DPTR, #TXT_HEADER
    CALL    LCD_PUTSTR

    ; Wyswietlenie szablonu pierwszej linii: "Nuta: ----"
    MOV     A, #LCD_HOME    ; kursor na pierwsza linie
    CALL    LCD_CTRL
    MOV     DPTR, #TXT_NUTA
    CALL    LCD_PUTSTR
    MOV     DPTR, #TXT_DASH
    CALL    LCD_PUTSTR

; ============================================================
; Petla glówna
; ============================================================
MAIN_LOOP:
    CALL    SCAN_KEYBOARD   ; A = kod skan. lub 0 jesli brak klawisza
    JZ      NO_KEY          ; brak klawisza -> cisza

    ; Czy klawisz zmienil sie?
    CJNE    A, LAST_KEY, NEW_KEY
    SJMP    MAIN_LOOP       ; ten sam klawisz trzymany – nic nie rób

NEW_KEY:
    MOV     LAST_KEY, A     ; zapamietaj nowy klawisz
    MOV     KEY_CODE, A
    CALL    FIND_NOTE       ; wyszukaj parametry nuty
    JC      NO_KEY          ; nieznaleziona nuta -> cisza

    ; Zatrzymaj timer, zaladuj nowe wartosci i wlacz dzwiek
    CLR     TR0
    MOV     A, TH0_VAL
    MOV     TH0, A
    MOV     A, TL0_VAL
    MOV     TL0, A
    MOV     SOUND_ON, #1
    SETB    TR0

    CALL    UPDATE_LCD_NOTE ; pokaz nazwe nuty na LCD
    SJMP    MAIN_LOOP

NO_KEY:
    ; Zatrzymaj dzwiek i wylacz brzeczyk
    CLR     TR0
    MOV     SOUND_ON, #0
    CLR     BUZZpiezzo

    ; Jesli ostatnio byl jakis klawisz, przywróc "Nuta: ----"
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
; Przerwanie Timera 0 – generowanie fali prostokatnej
; ============================================================
TIMER0_ISR:
    CLR     TR0             ; zatrzymaj timer
    MOV     A, TH0_VAL      ; przeladuj wartosci poczatkowa
    MOV     TH0, A
    MOV     A, TL0_VAL
    MOV     TL0, A
    SETB    TR0             ; uruchom ponownie
    CPL     BUZZpiezzo      ; zmien stan brzeczyka (0->1 lub 1->0)
    RETI

; ============================================================
; Skanowanie klawiatury matrycowej 4x4
; Zwraca: A = kod skaningowy (0 jesli zaden klawisz)
; Kod = (stan P7 & 0Fh) OR maska_wiersza (70h/B0h/D0h/E0h)
; ============================================================
SCAN_KEYBOARD:
    MOV     P5, #0FFH       ; wszystkie wiersze wysokie
    MOV     P7, #0FFH

    ; --- Wiersz 1: P5.4 = 0 (maska EFh) ---
    MOV     P5, #11101111B
    NOP                     ; krótkie opóznienie na ustalenie stanu
    NOP
    MOV     A, P7
    ANL     A, #0FH         ; tylko mlodsze 4 bity (kolumny)
    CJNE    A, #0FH, ROW1_HIT   ; jesli nie wszystkie '1' – zwarcie

    ; --- Wiersz 2: P5.5 = 0 (maska DFh) ---
    MOV     P5, #11011111B
    NOP
    NOP
    MOV     A, P7
    ANL     A, #0FH
    CJNE    A, #0FH, ROW2_HIT

    ; --- Wiersz 3: P5.6 = 0 (maska BFh) ---
    MOV     P5, #10111111B
    NOP
    NOP
    MOV     A, P7
    ANL     A, #0FH
    CJNE    A, #0FH, ROW3_HIT

    ; --- Wiersz 4: P5.7 = 0 (maska 7Fh) ---
    MOV     P5, #01111111B
    NOP
    NOP
    MOV     A, P7
    ANL     A, #0FH
    CJNE    A, #0FH, ROW4_HIT

    ; Zaden klawisz nie wcisniety
    MOV     P5, #0FFH
    MOV     A, #0
    RET

; --- Obsluga wykrycia klawisza w poszczególnych wierszach ---
ROW1_HIT:
    MOV     P5, #11101111B  ; ponownie ustaw wiersz
    NOP
    NOP
    MOV     A, P7
    ANL     A, #0FH         ; odczytaj kolumny
    ORL     A, #70H         ; dodaj maske wiersza (0111xxxx)
    MOV     KEY_CODE, A
    MOV     A, KEY_CODE
    RET

ROW2_HIT:
    MOV     P5, #11011111B
    NOP
    NOP
    MOV     A, P7
    ANL     A, #0FH
    ORL     A, #0B0H        ; maska wiersza 2 (1011xxxx)
    MOV     KEY_CODE, A
    MOV     A, KEY_CODE
    RET

ROW3_HIT:
    MOV     P5, #10111111B
    NOP
    NOP
    MOV     A, P7
    ANL     A, #0FH
    ORL     A, #0D0H        ; maska wiersza 3 (1101xxxx)
    MOV     KEY_CODE, A
    MOV     A, KEY_CODE
    RET

ROW4_HIT:
    MOV     P5, #01111111B
    NOP
    NOP
    MOV     A, P7
    ANL     A, #0FH
    ORL     A, #0E0H        ; maska wiersza 4 (1110xxxx)
    MOV     KEY_CODE, A
    MOV     A, KEY_CODE
    RET

; ============================================================
; Wyszukiwanie nuty w tabeli NOTE_TABLE
; Wejscie: KEY_CODE – kod skan. klawisza
; Wyjscie: TH0_VAL, TL0_VAL – parametry timera
;         NOTE_IDX – indeks nuty (0..7)
;         CY=1 jesli nie znaleziono
; ============================================================
FIND_NOTE:
    MOV     DPTR, #NOTE_TABLE
    MOV     R0, #0          ; indeks bajtów w tabeli (0,3,6,...)
    MOV     R1, #0          ; indeks nuty (0..7)

FIND_LOOP:
    MOV     A, R0
    MOVC    A, @A+DPTR      ; pobierz kod skan. z tabeli
    JZ      FIND_NOTFOUND   ; koniec tabeli (0x00) -> nie znaleziono
    CJNE    A, KEY_CODE, FIND_NEXT   ; czy kod pasuje?

    ; Znaleziono – pobierz TH0 i TL0
    INC     R0
    MOV     A, R0
    MOVC    A, @A+DPTR
    MOV     TH0_VAL, A
    INC     R0
    MOV     A, R0
    MOVC    A, @A+DPTR
    MOV     TL0_VAL, A
    MOV     NOTE_IDX, R1    ; zapamietaj indeks nuty
    CLR     C               ; sukces (CY=0)
    RET

FIND_NEXT:
    INC     R0              ; przejdz do nastepnej trójki bajtów
    INC     R0
    INC     R0
    INC     R1              ; kolejny indeks nuty
    SJMP    FIND_LOOP

FIND_NOTFOUND:
    SETB    C               ; blad – nie znaleziono (CY=1)
    RET

; ============================================================
; UPDATE_LCD_NOTE – wyswietla nazwe nuty (np. "C1 ")
; ============================================================
UPDATE_LCD_NOTE:
    MOV     A, #LCD_HOME
    CALL    LCD_CTRL
    MOV     DPTR, #TXT_NUTA
    CALL    LCD_PUTSTR       ; "Nuta: "

    ; Oblicz adres w tabeli NAME_TABLE: NOTE_IDX * 4
    MOV     A, NOTE_IDX
    MOV     B, #4
    MUL     AB
    MOV     DPTR, #NAME_TABLE
    ADD     A, DPL
    MOV     DPL, A
    MOV     A, B
    ADDC    A, DPH
    MOV     DPH, A

    MOV     R2, #4           ; 4 znaki na nazwe
DISP_LOOP:
    CLR     A
    MOVC    A, @A+DPTR        ; odczytaj znak z tabeli
    PUSH    DPH               ; zachowaj wskaznik do tablicy
    PUSH    DPL
    CALL    LCD_PUTCHAR       ; wyslij znak do LCD (to zmienia DPTR!)
    POP     DPL               ; odtwórz wskaznik
    POP     DPH
    INC     DPTR              ; nastepny znak w nazwie
    DJNZ    R2, DISP_LOOP
    RET

; ============================================================
; Procedury obslugi wyswietlacza LCD (HD44780)
; ============================================================

; Czekaj az flaga zajetosci (bit 7) wróci do 0
LCD_WAIT:
    PUSH    DPH
    PUSH    DPL
LCD_WAIT_LOOP:
    MOV     DPTR, #LCDstatus
    MOVX    A, @DPTR
    JB      ACC.7, LCD_WAIT_LOOP  ; powtarzaj dopóki busy=1
    POP     DPL
    POP     DPH
    RET

; Wyslij rozkaz do LCD (A = kod rozkazu)
LCD_CTRL:
    PUSH    ACC
    CALL    LCD_WAIT
    MOV     DPTR, #LCDcontrol
    POP     ACC
    MOVX    @DPTR, A
    RET

; Wyslij znak do LCD (A = kod ASCII)
LCD_PUTCHAR:
    PUSH    ACC
    CALL    LCD_WAIT
    MOV     DPTR, #LCDdataWR
    POP     ACC
    MOVX    @DPTR, A
    RET

; Wyslij ciag znaków z pamieci CODE (zakonczony 0x00)
; DPTR wskazuje na poczatek napisu
LCD_PUTSTR:
    CLR     A
    MOVC    A, @A+DPTR        ; odczytaj bajt
    JZ      LCD_PUTSTR_END    ; koniec napisu (zero)
    PUSH    DPH
    PUSH    DPL
    CALL    LCD_PUTCHAR
    POP     DPL
    POP     DPH
    INC     DPTR
    SJMP    LCD_PUTSTR
LCD_PUTSTR_END:
    RET

; Inicjalizacja LCD: opóznienie startowe + sekwencja rozkazów
LCD_INITIALIZE:
    ; Opóznienie dla stabilizacji zasilania LCD
    MOV     R7, #0FFH
INIT_DLY:
    MOV     R6, #0FFH
INIT_DLY2:
    DJNZ    R6, INIT_DLY2
    DJNZ    R7, INIT_DLY
    ; Sekwencja inicjalizacyjna
    MOV     A, #LCD_INIT      ; 8-bit, 2 linie
    CALL    LCD_CTRL
    MOV     A, #LCD_CLEAR      ; wyczysc ekran
    CALL    LCD_CTRL
    MOV     A, #LCD_ON         ; wlacz LCD
    CALL    LCD_CTRL
    RET

; ============================================================
; Stale tekstowe i tabele w pamieci CODE
; ============================================================
?CO?DATA    SEGMENT CODE
            RSEG    ?CO?DATA

; Tabela nut: [kod skan.][TH0][TL0] (gama C-dur, 8 dzwieków)
NOTE_TABLE:
    DB 07EH, 0F8H, 089H   ; "1" -> C1  261.6 Hz
    DB 07DH, 0F9H, 05AH   ; "4" -> D1  293.7 Hz
    DB 07BH, 0FAH, 013H   ; "7" -> E1  329.6 Hz
    DB 077H, 0FAH, 068H   ; "*" -> F1  349.2 Hz
    DB 0BEH, 0FBH, 004H   ; "2" -> G1  392.0 Hz
    DB 0BDH, 0FBH, 090H   ; "5" -> A1  440.0 Hz
    DB 0BBH, 0FCH, 00CH   ; "8" -> H1  493.9 Hz
    DB 0B7H, 0FCH, 045H   ; "0" -> C2  523.3 Hz
    DB 000H                ; znacznik konca

; Nazwy nut (po 4 znaki, indeksowane przez NOTE_IDX)
NAME_TABLE:
    DB 'C','1',' ',' '     ; 0 – C1
    DB 'D','1',' ',' '     ; 1 – D1
    DB 'E','1',' ',' '     ; 2 – E1
    DB 'F','1',' ',' '     ; 3 – F1
    DB 'G','1',' ',' '     ; 4 – G1
    DB 'A','1',' ',' '     ; 5 – A1
    DB 'H','1',' ',' '     ; 6 – H1
    DB 'C','2',' ',' '     ; 7 – C2

; Napisy stale
TXT_HEADER:
    DB 'O','r','g','a','n','k','i',' ','Z','D','5','3','7',0
TXT_NUTA:
    DB 'N','u','t','a',':',' ',0
TXT_DASH:
    DB '-','-','-','-',0

    END