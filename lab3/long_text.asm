; ==========================================================
; ZADANIE 2 - WYSWIETLANIE DLUGIEGO TEKSTU NA LCD
; ==========================================================

LCDstatus  EQU 0FF2EH       ; adres do odczytu gotowosci LCD
LCDcontrol EQU 0FF2CH       ; adres do podania bajtu sterujacego LCD
LCDdataWR  EQU 0FF2DH       ; adres do podania kodu ASCII na LCD

; bajty sterujace LCD
HOME       EQU 80H          ; kursor na poczatek 1 linii  
INITDISP   EQU 38H          ; LCD init (8-bit mode)  
HOM2       EQU 0C0H         ; kursor na poczatek 2 linii  
LCDON      EQU 0EH          ; LCD on, cursor off, blinking off
CLEAR      EQU 01H          ; LCD display clear

ORG 0000H
    LJMP start

ORG 0100H

; --- deklaracje tekstow ---
text1:  DB "Pierwszy Dzien Wiosny juz za nami, piekne slonce za oknem nam swieci, ale poranki jeszcze rzeskie - o przeziebienie latwo", 00

; --- makro do wprowadzenia bajtu sterujacego na LCD ---
LCDcntrlWR MACRO x          
      LOCAL loop        
loop: MOV  DPTR, #LCDstatus  
      MOVX A, @DPTR          
      JB   ACC.7, loop       
      MOV  DPTR, #LCDcontrol 
      MOV  A, x              
      MOVX @DPTR, A          
ENDM
      
; --- makro do wypisania znaku ASCII na LCD ---
LCDcharWR MACRO
      LOCAL tutu            
      PUSH ACC              
tutu: MOV  DPTR, #LCDstatus  
      MOVX A, @DPTR          
      JB   ACC.7, tutu       
      MOV  DPTR, #LCDdataWR  
      POP  ACC              
      MOVX @DPTR, A          
ENDM
      
; --- makro do inicjalizacji wyswietlacza ---
init_LCD MACRO
      LCDcntrlWR #INITDISP 
      LCDcntrlWR #CLEAR    
      LCDcntrlWR #LCDON    
ENDM

; --- funkcja opoznienia ---
delay:    
      MOV R0, #15H
one:  MOV R1, #0FFH
dwa:  MOV R2, #0FFH
trzy: DJNZ R2, trzy
      DJNZ R1, dwa
      DJNZ R0, one
      RET
            
; --- funkcja wypisania pojedynczego znaku ---
putcharLCD:    
      LCDcharWR
      RET
            
; --- funkcja wypisania lancucha znakow (z podzialem na linie) ---        
putstrLCD:  
      MOV R6, #0       ; R6 = 0 oznacza pierwsza linie
print_line:
      MOV R7, #16      ; Ladujemy licznik: 16 znakow na linie
nextchar: 
      CLR A
      MOVC A, @A+DPTR
      JZ koniec        ; Znaleziono zero (00) = koniec stringa
      PUSH DPH
      PUSH DPL
      ACALL putcharLCD ; Wypisanie znaku
      POP DPL
      POP DPH
      INC DPTR
      DJNZ R7, nextchar ; Krecimy sie az wypiszemy 16 znakow

      ; Sprawdzamy, w ktorej jestesmy linii
      CJNE R6, #0, end_of_page 
      
      ; Byla linia 1, przechodzimy do linii 2
      LCDcntrlWR #HOM2 
      MOV R6, #1       ; Flaga na 1 (druga linia)
      SJMP print_line  

end_of_page:
      ; Zapisalismy obie linie, czas na pauze
      ACALL delay      ; Opoznienie zeby przeczytac tekst
      LCDcntrlWR #CLEAR; Kasowanie ekranu
      LCDcntrlWR #HOME ; Kursor na poczatek 1 linii
      MOV R6, #0       ; Reset flagi do 0
      SJMP print_line  

koniec: 
      RET

; --- program glowny ---
start:    
      init_LCD
    
      MOV DPTR, #text1
      ACALL putstrLCD
      ACALL delay            
            
      SJMP $           ; petla nieskonczona na koniec programu

END