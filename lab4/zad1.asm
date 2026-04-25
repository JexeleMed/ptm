$NOMOD51
$INCLUDE (reg517.inc)

; --- DEFINICJE PORTÓW I ZMIENNYCH ---
P5 equ 0F8H
P7 equ 0DBH
    
LCDstatus  equ 0FF2EH       ; adres do odczytu gotowosci LCD (XDATA)
LCDcontrol equ 0FF2CH       ; adres do podania bajtu sterujacego LCD (XDATA)
LCDdataWR  equ 0FF2DH       ; adres do podania kodu ASCII na LCD (XDATA)

#define  HOME     0x80     ; kursor do 1 linii  
#define  INITDISP 0x38     ; LCD init (8-bit mode)  
#define  HOM2     0xc0     ; kursor do 2 linii  
#define  LCDON    0x0e     ; LCD on, cursor off, blinking off
#define  CLEAR    0x01     ; LCD display clear

    ORG 0000H
    LJMP start

    ORG 0100H
        
; --- MAKRA (z ochroną DPTR) ---

LCDcntrlWR MACRO x
      LOCAL loop
      PUSH DPH              ; 1. Zabezpiecz biezacy adres danych
      PUSH DPL
      PUSH ACC              ; 2. Zabezpiecz ewentualne dane w ACC
loop: MOV  DPTR,#LCDstatus
      MOVX A,@DPTR
      JB   ACC.7,loop       ; Sprawdzanie flagi zajetosci (Busy Flag)
      MOV  DPTR,#LCDcontrol
      MOV  A, x             ; Podanie bajtu sterujacego
      MOVX @DPTR,A
      POP  ACC              ; Odzyskiwanie wartosci w odwrotnej kolejnosci
      POP  DPL
      POP  DPH
      ENDM
      
LCDcharWR MACRO
      LOCAL tutu
      PUSH DPH              ; 1. Zabezpiecz wskaźnik danych
      PUSH DPL
      PUSH ACC              ; 2. Zabezpiecz kod ASCII, ktory chcemy wyswietlic
tutu: MOV  DPTR,#LCDstatus
      MOVX A,@DPTR
      JB   ACC.7,tutu       ; Sprawdzanie flagi zajetosci (Busy Flag)
      MOV  DPTR,#LCDdataWR
      POP  ACC              ; Odzyskaj kod ASCII (teraz ACC jest na szczycie stosu)
      MOVX @DPTR,A          ; Wyslij kod ASCII na LCD
      POP  DPL              ; Odzyskaj oryginalny wskaźnik danych
      POP  DPH
      ENDM
      
init_LCD MACRO
      LCDcntrlWR #INITDISP
      LCDcntrlWR #CLEAR
      LCDcntrlWR #LCDON
      ENDM

; --- PROCEDURY POMOCNICZE ---

delay:  MOV R0, #15H
one:    MOV R1, #0FFH
dwa:    MOV R2, #0FFH
trzy:   DJNZ R2, trzy
        DJNZ R1, dwa
        DJNZ R0, one
        RET
            
putcharLCD: 
        LCDcharWR
        RET

; --- PROGRAM GŁÓWNY ---

start:  
    init_LCD
    MOV R3, #0              ; R3 przechowuje aktualny tryb (0 = cyfry/ABC, 1 = małe, 2 = duże)

scan_matrix:
    ; Skanowanie linii 4 (klawisze: *, 0, #, D)
    MOV P5, #0EFH
    MOV A, P7
    ANL A, #0FH             ; Maskujemy tylko bity kolumn
    CJNE A, #0FH, key_L4

    ; Skanowanie linii 3 (klawisze: 7, 8, 9, C)
    MOV P5, #0DFH
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, key_L3

    ; Skanowanie linii 2 (klawisze: 4, 5, 6, B)
    MOV P5, #0BFH
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, key_L2

    ; Skanowanie linii 1 (klawisze: 1, 2, 3, A)
    MOV P5, #07FH
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, key_L1

    SJMP scan_matrix        ; Brak wcisnietego klawisza, powtarzaj skanowanie

; Rekonstrukcja kodu skaningowego (połączenie P5 i P7)
key_L4: ORL A, #0EFH
        SJMP process_key
key_L3: ORL A, #0DFH
        SJMP process_key
key_L2: ORL A, #0BFH
        SJMP process_key
key_L1: ORL A, #07FH
        SJMP process_key

process_key:
    MOV R4, A               ; Zapisz zrekonstruowany kod skaningowy w R4

wait_for_release:
    MOV P5, #00H            ; Ustaw 0 na wszystkich wierszach
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, wait_for_release ; Czekaj, az uzytkownik pusci klawisz
    ACALL delay             ; Debouncing (opoznienie przeciw drganiom stykow)

    MOV A, R4               ; Odzyskaj kod skaningowy

check_modifiers:
    CJNE A, #0E7H, check_hash   ; Czy wcisnieto '*'?
    MOV R3, #1                  ; Tryb 1: małe litery
    SJMP scan_matrix
    
check_hash:
    CJNE A, #0EDH, check_D      ; Czy wcisnieto '#'?
    MOV R3, #2                  ; Tryb 2: duże litery
    SJMP scan_matrix
    
check_D:
    CJNE A, #0EEH, find_char    ; Czy wcisnieto 'D'?
    MOV R3, #0                  ; Tryb 0: cyfry i bazowe znaki
    SJMP scan_matrix

find_char:
    MOV R2, #0                  ; R2 = Indeks (0-12) wyszukiwanego klawisza
    MOV DPTR, #SCAN_CODES       ; Tabela z kodami skaningowymi

find_loop:
    MOV A, R2
    MOVC A, @A+DPTR
    JZ scan_matrix              ; 00H -> koniec tabeli, ignoruj niezidentyfikowane kody
    CJNE A, R4, next_code       ; Jesli brak zgodnosci -> szukaj dalej
    SJMP print_char             ; Znaleziono zgodny kod skaningowy!

next_code:
    INC R2
    SJMP find_loop

print_char:
    MOV A, R3                   ; Sprawdz ktory zestaw aktywowac (na bazie R3)
    JZ do_set0                  ; R3 = 0
    DEC A
    JZ do_set1                  ; R3 = 1

do_set2:
    MOV DPTR, #SET2_CHARS       ; R3 = 2
    SJMP fetch_and_print
do_set1:
    MOV DPTR, #SET1_CHARS
    SJMP fetch_and_print
do_set0:
    MOV DPTR, #SET0_CHARS

fetch_and_print:
    MOV A, R2
    MOVC A, @A+DPTR             ; Pobierz gotowy kod ASCII z wybranej tabeli
    ACALL putcharLCD            ; Wyswietl go na ekranie LCD
    SJMP scan_matrix            ; Wroc do poczatku (nieskonczona petla programu)

; --- TABELE DANYCH (W PAMIĘCI ROM / CODE) ---

SCAN_CODES:
    ; Kody odpowiadajace klawiszom: 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, A, B, C
    DB 0EBH, 077H, 07BH, 07DH, 0B7H, 0BBH, 0BDH, 0D7H, 0DBH, 0DDH, 07EH, 0BEH, 0DEH, 00H

SET0_CHARS:
    ; Zestaw D (domyślny) - cyfry i znaki A, B, C
    DB '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C'

SET1_CHARS:
    ; Zestaw * - małe litery od a do m
    DB 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm'

SET2_CHARS:
    ; Zestaw # - duże litery od A do M
    DB 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M'

    NOP
    NOP
    NOP
end_prog: 
    SJMP $

    END