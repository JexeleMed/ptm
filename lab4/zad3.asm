$NOMOD51
$INCLUDE (reg517.inc)

; --- DEFINICJE PORTÓW I ZMIENNYCH ---
P5 equ 0F8H
P7 equ 0DBH
    
LCDstatus  equ 0FF2EH       
LCDcontrol equ 0FF2CH       
LCDdataWR  equ 0FF2DH       

#define  INITDISP 0x38     
#define  LCDON    0x0E     
#define  CLEAR    0x01     

    ORG 0000H
    LJMP start

    ORG 0100H
        
; --- MAKRA BEZPIECZNE ---
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

; --- PROCEDURA OPÓŹNIAJĄCA (DEBOUNCING) ---
delay:  
        MOV R0, #15H
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

scan_matrix:
    ; --- ETAP 1: Czekanie na wciśniecie (Skanowanie) ---
    MOV P5, #0EFH           ; Linia 4
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, key_pressed

    MOV P5, #0DFH           ; Linia 3
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, key_pressed

    MOV P5, #0BFH           ; Linia 2
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, key_pressed

    MOV P5, #07FH           ; Linia 1
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, key_pressed

    SJMP scan_matrix        ; Powtarzaj, dopóki nic nie wciśnięto

key_pressed:
    ; Rekonstrukcja kodu z P5 i P7
    MOV B, A                ; Chwilowo przechowaj stan kolumn w B
    MOV A, P5               ; Pobierz stan wierszy
    ANL A, #0F0H            ; Zostaw tylko najstarsze bity wierszy
    ORL A, B                ; Połącz wiersze (starsze 4 bity) i kolumny (młodsze 4 bity)
    
    ; --- ETAP 2: ZAMROŻENIE KODU SKANINGOWEGO ---
    MOV R4, A               ; Zapisz zrekonstruowany kod do R4, aby go nie stracić

    ; --- ETAP 3: BLOKADA REPETYCJI (CZEKANIE NA PUSZCZENIE) ---
wait_for_release:
    MOV P5, #00H            ; Podaj zera na WSZYSTKIE wiersze klawiatury jednocześnie
    MOV A, P7               ; Odczytaj stan kolumn
    ANL A, #0FH             ; Interesują nas tylko 4 najmłodsze bity (P7.0 - P7.3)
    
    ; Jeśli puszczono WSZYSTKIE klawisze, stan P7 wyniesie 0FH (1111b z powodu rezystorów podciągających)
    CJNE A, #0FH, wait_for_release 

    ; --- ETAP 4: DEBOUNCING (TŁUMIENIE DRGAŃ) ---
    ACALL delay             ; Odczekaj chwilę, aby uniknąć wykrycia zakłóceń mechanicznych styku

    ; --- ETAP 5: WŁAŚCIWE WYKONANIE OPERACJI ---
    ; Dopiero tutaj przystępujemy do odkodowania i wyświetlenia znaku!
    MOV A, R4               ; Odzyskaj zamrożony kod z R4
    MOV R2, #0              ; R2 to nasz indeks do przeszukiwania tabeli
    MOV DPTR, #SCAN_CODES   

find_loop:
    MOV A, R2
    MOVC A, @A+DPTR
    JZ scan_matrix          ; Zabezpieczenie: jeśli 00H (koniec tabeli), zignoruj i wróć
    CJNE A, R4, next_code   
    SJMP print_char         

next_code:
    INC R2
    SJMP find_loop

print_char:
    MOV DPTR, #ASCII_CHARS  
    MOV A, R2               
    MOVC A, @A+DPTR         
    ACALL putcharLCD        
    
    SJMP scan_matrix        ; Wróć do nasłuchiwania kolejnego znaku

; --- TABELE DANYCH (ROM) ---
SCAN_CODES:
    DB 0EBH, 077H, 07BH, 07DH, 0B7H, 0BBH, 0BDH, 0D7H, 0DBH, 0DDH, 07EH, 0BEH, 0DEH, 0EEH, 0E7H, 0EDH, 00H

ASCII_CHARS:
    DB '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', '*', '#'

    NOP
    NOP
    NOP
end_prog: 
    SJMP $

    END