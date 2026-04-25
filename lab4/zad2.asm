$NOMOD51
$INCLUDE (reg517.inc)

; --- DEFINICJE PORTÓW I ZMIENNYCH ---
P5 equ 0F8H
P7 equ 0DBH
    
LCDstatus  equ 0FF2EH       ; adres do odczytu gotowosci LCD (XDATA)
LCDcontrol equ 0FF2CH       ; adres do podania bajtu sterujacego LCD (XDATA)
LCDdataWR  equ 0FF2DH       ; adres do podania kodu ASCII na LCD (XDATA)

#define  HOME     0x80      ; kursor do 1 linii  
#define  INITDISP 0x38      ; LCD init (8-bit mode)  
#define  HOM2     0xC0      ; kursor do 2 linii  
#define  LCDON    0x0E      ; LCD wlaczone, kursor wylaczony
#define  CLEAR    0x01      ; czyszczenie ekranu (i powrot do 1 linii)

    ORG 0000H
    LJMP start

    ORG 0100H
        
; --- MAKRA BEZPIECZNE ---

LCDcntrlWR MACRO x
      LOCAL loop
      PUSH DPH              ; Zabezpiecz wskaźnik danych
      PUSH DPL
      PUSH ACC              ; Zabezpiecz zawartosc akumulatora
loop: MOV  DPTR,#LCDstatus
      MOVX A,@DPTR
      JB   ACC.7,loop       ; Czekaj na flage zajetosci (Busy Flag = 0)
      MOV  DPTR,#LCDcontrol
      MOV  A, x
      MOVX @DPTR,A          ; Wyslij komende
      POP  ACC
      POP  DPL
      POP  DPH
      ENDM
      
LCDcharWR MACRO
      LOCAL tutu
      PUSH DPH
      PUSH DPL
      PUSH ACC
tutu: MOV  DPTR,#LCDstatus
      MOVX A,@DPTR
      JB   ACC.7,tutu       ; Czekaj na flage zajetosci
      MOV  DPTR,#LCDdataWR
      POP  ACC              ; Przywroc kod ASCII
      MOVX @DPTR,A          ; Wyslij znak
      POP  DPL
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
    MOV R5, #0              ; R5 = Licznik znaków na ekranie (od 0 do 31)

scan_matrix:
    MOV P5, #0EFH           ; Skanowanie linii 4
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, key_L4

    MOV P5, #0DFH           ; Skanowanie linii 3
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, key_L3

    MOV P5, #0BFH           ; Skanowanie linii 2
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, key_L2

    MOV P5, #07FH           ; Skanowanie linii 1
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, key_L1

    SJMP scan_matrix        ; Powtarzaj, dopóki nic nie wciśnięto

key_L4: ORL A, #0EFH
        SJMP process_key
key_L3: ORL A, #0DFH
        SJMP process_key
key_L2: ORL A, #0BFH
        SJMP process_key
key_L1: ORL A, #07FH
        SJMP process_key

process_key:
    MOV R4, A               ; Zapisz zrekonstruowany kod w R4

wait_for_release:
    MOV P5, #00H            ; Ustaw 0 na wszystkich liniach
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, wait_for_release ; Czekaj na puszczenie przycisku
    ACALL delay             ; Opóźnienie na drgania styków (debounce)

    MOV A, R4               ; Odzyskaj kod z R4
    MOV R2, #0              ; Indeks tabeli w R2
    MOV DPTR, #SCAN_CODES   ; Szukamy kodu klawisza w tabeli

find_loop:
    MOV A, R2
    MOVC A, @A+DPTR
    JZ scan_matrix          ; Koda 00H to koniec tabeli, ignorujemy błąd
    CJNE A, R4, next_code   ; Brak dopasowania -> szukaj dalej
    SJMP manage_cursor      ; Znalazl kod! Idz do logiki ekranu

next_code:
    INC R2
    SJMP find_loop

manage_cursor:
    ; Sprawdzamy stan licznika w R5, aby wiedzieć gdzie wpisać znak
    MOV A, R5
    CJNE A, #32, check_line2
    ; Jesli R5 == 32 (ekran pelny)
    MOV R5, #0              ; Zerujemy licznik
    LCDcntrlWR #CLEAR       ; Czyszczenie ekranu (i kursor wraca do 1. linii)
    SJMP print_char         

check_line2:
    CJNE A, #16, print_char
    ; Jesli R5 == 16 (pierwsza linia pelna)
    LCDcntrlWR #HOM2        ; Przenies kursor na start drugiej linii

print_char:
    MOV DPTR, #ASCII_CHARS  ; Adres tabeli z odpowiednikami ASCII
    MOV A, R2               ; Ten sam indeks, ktory znalezlismy wczesniej
    MOVC A, @A+DPTR         ; Pobranie kodu ASCII do akumulatora
    ACALL putcharLCD        ; Wyswietlenie znaku
    INC R5                  ; Zwiekszenie licznika znakow na ekranie
    SJMP scan_matrix        ; Gotowe! Wroc do czekania na kolejny klawisz

; --- TABELE DANYCH (ROM) ---

SCAN_CODES:
    ; Kody z dokumentacji: 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, A, B, C, D, *, #
    DB 0EBH, 077H, 07BH, 07DH, 0B7H, 0BBH, 0BDH, 0D7H, 0DBH, 0DDH
    DB 07EH, 0BEH, 0DEH, 0EEH, 0E7H, 0EDH, 00H

ASCII_CHARS:
    ; Odpowiadajace im kody ASCII, ktore trafia na LCD
    DB '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'
    DB 'A', 'B', 'C', 'D', '*', '#'

    NOP
    NOP
    NOP
end_prog: 
    SJMP $

    END