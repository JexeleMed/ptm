$NOMOD51
$INCLUDE (reg517.inc)

; --- DEFINICJE PORTÓW I ZMIENNYCH ---
LCDstatus  equ 0FF2EH       ; adres do odczytu gotowosci LCD (XDATA)
LCDcontrol equ 0FF2CH       ; adres do podania bajtu sterujacego LCD (XDATA)
LCDdataWR  equ 0FF2DH       ; adres do podania kodu ASCII na LCD (XDATA)

HOME equ 0x80     ; kursor do 1 linii  
INITDISP equ 0x38 ; LCD init (8-bit mode)  
HOM2 equ 0xC0     ; kursor do 2 linii  
LCDON equ 0x0E    ; LCD on, cursor off, blinking off
CLEAR equ 0x01    ; LCD display clear

    ORG 0000H
    LJMP start

    ORG 0100H
        
; --- MAKRA (z ochroną DPTR) ---

LCDcntrlWR MACRO x
      LOCAL loop
      PUSH DPH              
      PUSH DPL
      PUSH ACC              
loop: MOV  DPTR,#LCDstatus
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
tutu: MOV  DPTR,#LCDstatus
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
    MOV R3, #0              ; R3 = Tryb klawiatury (0: cyfry, 1: małe litery, 2: duże litery)
    MOV R5, #0              ; R5 = Licznik znaków na ekranie (do łamania linii)

scan_matrix:
    ; Skanowanie linii 4 (klawisze: *, 0, #, D)
    MOV P5, #0EFH
    MOV A, P7
    ANL A, #0FH             
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

    LJMP scan_matrix        ; Brak wcisnietego klawisza, powtarzaj skanowanie

; --- REKONSTRUKCJA KODU (Naprawione maski!) ---
key_L4: ORL A, #0E0H
        SJMP process_key
key_L3: ORL A, #0D0H
        SJMP process_key
key_L2: ORL A, #0B0H
        SJMP process_key
key_L1: ORL A, #070H
        SJMP process_key

process_key:
    MOV R4, A               ; Zapisz kod skaningowy w R4 (adres 04H w pamieci)

wait_for_release:
    MOV P5, #00H            
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, wait_for_release 
    ACALL delay             

    MOV A, R4               ; Odzyskaj kod

check_modifiers:
    CJNE A, #0E7H, check_hash   ; '*'?
    MOV R3, #1                  ; Tryb 1: małe litery
    LJMP scan_matrix
    
check_hash:
    CJNE A, #0EDH, check_D      ; '#'?
    MOV R3, #2                  ; Tryb 2: duże litery
    LJMP scan_matrix
    
check_D:
    CJNE A, #0EEH, find_char    ; 'D'?
    MOV R3, #0                  ; Tryb 0: cyfry
    LJMP scan_matrix

find_char:
    MOV R2, #0                  ; R2 = Indeks w tabeli
    MOV DPTR, #SCAN_CODES       

find_loop:
    CLR A                       
    MOV A, R2
    MOVC A, @A+DPTR
    JZ no_match                 ; 00H -> koniec tabeli, nie znaleziono
    CJNE A, 04H, next_code      ; Porównaj z zawartością R4 (pod adresem 04H)
    SJMP print_char             ; Znaleziono! Skocz do drukowania

next_code:
    INC R2
    SJMP find_loop

no_match:
    LJMP scan_matrix            

print_char:
    MOV A, R3                   ; Wybierz tabelę na podstawie R3
    JZ do_set0                  
    DEC A
    JZ do_set1                  

do_set2:
    MOV DPTR, #SET2_CHARS       
    SJMP fetch_and_print
do_set1:
    MOV DPTR, #SET1_CHARS
    SJMP fetch_and_print
do_set0:
    MOV DPTR, #SET0_CHARS

fetch_and_print:
    CLR A                       
    MOV A, R2
    MOVC A, @A+DPTR             ; Pobierz znak ASCII
    ACALL putcharLCD            ; Wypisz na ekranie

    ; --- ZARZĄDZANIE EKRANEM (Nowa funkcjonalność) ---
    INC R5                      ; Zwiększ licznik znaków o 1
    
    MOV A, R5
    CJNE A, #16, check_clear    ; Jeśli R5 nie jest 16, sprawdź czy to 32
    LCDcntrlWR #HOM2            ; Przerzuć kursor do 2 linii
    LJMP scan_matrix            ; Wróć do nasłuchiwania
    
check_clear:
    CJNE A, #32, return_scan    ; Jeśli R5 nie jest 32, po prostu wróć
    MOV R5, #0                  ; Zeruj licznik (zaczynamy od nowa)
    LCDcntrlWR #CLEAR           ; Wyczyść ekran
    LCDcntrlWR #HOME            ; Wróć do 1 linii
    
return_scan:
    LJMP scan_matrix            

; --- TABELE DANYCH (W PAMIĘCI ROM / CODE) ---

SCAN_CODES:
    ; Kody odpowiadajace klawiszom: 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, A, B, C
    DB 0EBH, 077H, 07BH, 07DH, 0B7H, 0BBH, 0BDH, 0D7H, 0DBH, 0DDH, 07EH, 0BEH, 0DEH, 00H

SET0_CHARS:
    ; Zestaw bazowy - cyfry i znaki A, B, C
    DB '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C'

SET1_CHARS:
    ; Zestaw * - małe litery
    DB 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm'

SET2_CHARS:
    ; Zestaw # - duże litery
    DB 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M'

    NOP
    NOP
    NOP
end_prog: 
    SJMP $

    END