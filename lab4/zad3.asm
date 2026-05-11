$NOMOD51
$INCLUDE (reg517.inc)

; --- DEFINICJE PORTÓW I ZMIENNYCH ---
LCDstatus  equ 0FF2EH       
LCDcontrol equ 0FF2CH       
LCDdataWR  equ 0FF2DH       

HOME equ 0x80       
INITDISP equ 0x38     
HOM2 equ 0xC0     
LCDON equ 0x0E     
CLEAR equ 0x01     

    ORG 0000H
    LJMP start

    ORG 0100H
        
; --- MAKRA ---
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
    MOV R3, #0              ; R3 = Tryb (0: cyfry, 1: małe litery, 2: duże litery)
    MOV R5, #0              ; R5 = Licznik znaków na ekranie (do łamania linii)

scan_matrix:
    MOV P5, #0EFH
    MOV A, P7
    ANL A, #0FH             
    CJNE A, #0FH, key_pressed

    MOV P5, #0DFH
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, key_pressed

    MOV P5, #0BFH
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, key_pressed

    MOV P5, #07FH
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, key_pressed

    LJMP scan_matrix        ; Brak wcisnietego klawisza, powtarzaj skanowanie

key_pressed:
    ; Sprytna rekonstrukcja kodu skaningowego (połączenie P5 i P7)
    MOV B, A                ; Zapisz stan kolumn (np. 07H) w B
    MOV A, P5               ; Pobierz stan wierszy (np. 0EFH)
    ANL A, #0F0H            ; Wyzeruj dolną połówkę (robi się 0E0H)
    ORL A, B                ; Złącz wiersz z kolumną (robi się 0E7H)
    MOV R4, A               ; Zapisz gotowy fizyczny kod klawisza w R4

wait_for_release:
    ; Zadanie 3: Blokada repetycji - czekamy na zwolnienie przycisku
    MOV P5, #00H            ; Ustaw zero na wszystkich wierszach
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, wait_for_release ; Kreci sie w petli dopoki trzymasz palec!
    ACALL delay             ; Antydrgawkowo odczekaj chwile po puszczeniu

    MOV A, R4               ; Odzyskaj kod wcisnietego klawisza

check_modifiers:
    CJNE A, #0E7H, check_hash   ; '*' ?
    MOV R3, #1                  ; Tryb 1: małe litery
    LJMP scan_matrix
    
check_hash:
    CJNE A, #0EDH, check_D      ; '#' ?
    MOV R3, #2                  ; Tryb 2: duże litery
    LJMP scan_matrix
    
check_D:
    CJNE A, #0EEH, find_char    ; 'D' ?
    MOV R3, #0                  ; Tryb 0: cyfry
    LJMP scan_matrix

find_char:
    MOV R2, #0                  ; R2 = Indeks w tabeli
    MOV DPTR, #SCAN_CODES       

find_loop:
    MOV A, R2
    MOVC A, @A+DPTR             ; Pobierz bajt z tabeli
    JZ no_match                 ; 00H -> koniec tabeli, nie znaleziono
    XRL A, R4                   ; Porownaj pobrany bajt z R4
    JZ print_char               ; Znaleziono! (XRL dał 0)
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
    MOV A, R2
    MOVC A, @A+DPTR             ; Pobierz znak ASCII
    ACALL putcharLCD            ; Wypisz na ekranie

    ; --- ZARZĄDZANIE EKRANEM (Zadanie 2) ---
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
    DB 0EBH, 077H, 07BH, 07DH, 0B7H, 0BBH, 0BDH, 0D7H, 0DBH, 0DDH, 07EH, 0BEH, 0DEH, 00H

SET0_CHARS:
    DB '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C'

SET1_CHARS:
    DB 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm'

SET2_CHARS:
    DB 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M'

    NOP
    NOP
    NOP
end_prog: 
    SJMP $

    END