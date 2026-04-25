; ==========================================================
; TASK 2 - DISPLAYING LONG TEXT ON LCD (TYPEWRITER EFFECT)
; ==========================================================

LCDstatus  EQU 0FF2EH       ; address to read LCD busy flag
LCDcontrol EQU 0FF2CH       ; address to write LCD command byte
LCDdataWR  EQU 0FF2DH       ; address to write ASCII code to LCD

; LCD command bytes
HOME       EQU 80H          ; cursor to the beginning of 1st line  
INITDISP   EQU 38H          ; LCD init (8-bit mode)  
HOM2       EQU 0C0H         ; cursor to the beginning of 2nd line  
LCDON      EQU 0EH          ; LCD on, cursor off, blinking off
CLEAR      EQU 01H          ; LCD display clear

ORG 0000H
    LJMP start

ORG 0100H

; --- text declarations ---
text1:  DB "Tylko noca do klubu Puls Dzem Session do rana, tam krolowal blues To juz minelo, ten klimat, ten luz Wspaniali ludzie nie powroca, nie powroca juz!", 00

; --- macro to send command byte to LCD ---
LCDcntrlWR MACRO x          
      LOCAL loop        
loop: MOV  DPTR, #LCDstatus  
      MOVX A, @DPTR          
      JB   ACC.7, loop       
      MOV  DPTR, #LCDcontrol 
      MOV  A, x              
      MOVX @DPTR, A          
ENDM
      
; --- macro to send ASCII character to LCD ---
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
      
; --- macro to initialize LCD ---
init_LCD MACRO
      LCDcntrlWR #INITDISP 
      LCDcntrlWR #CLEAR    
      LCDcntrlWR #LCDON    
ENDM

; --- long delay function (between text pages) ---
delay:    
      MOV R0, #15H
one:  MOV R1, #0FFH
dwa:  MOV R2, #0FFH
trzy: DJNZ R2, trzy
      DJNZ R1, dwa
      DJNZ R0, one
      RET

; --- Short delay for the "typewriter" effect ---
delay_char:
      MOV R3, #10H       ; <--- ADJUST TYPING SPEED HERE (smaller = faster)
dc_out:
      MOV R4, #0FFH
dc_in:
      DJNZ R4, dc_in
      DJNZ R3, dc_out
      RET
            
; --- function to print a single character ---
putcharLCD:    
      LCDcharWR
      RET
            
; --- function to print string (with line splitting) ---        
putstrLCD:  
      MOV R6, #0         ; R6 = 0 means first line
print_line:
      MOV R7, #16        ; Load counter: 16 characters per line
nextchar: 
      CLR A
      MOVC A, @A+DPTR
      JZ koniec          ; Zero found (00) = end of string
      PUSH DPH
      PUSH DPL
      
      ACALL putcharLCD   ; 1. Print single character on LCD
      ACALL delay_char   ; 2. Typewriter effect delay
      
      POP DPL
      POP DPH
      INC DPTR
      DJNZ R7, nextchar  ; Loop until 16 characters are printed

      ; Check which line we are currently on
      CJNE R6, #0, end_of_page 
      
      ; It was line 1, move to line 2
      LCDcntrlWR #HOM2 
      MOV R6, #1         ; Set flag to 1 (second line)
      SJMP print_line  

end_of_page:
      ; Both lines printed, time to pause for user to read
      ACALL delay        
      LCDcntrlWR #CLEAR  ; Clear screen
      LCDcntrlWR #HOME   ; Cursor to the beginning of 1st line
      MOV R6, #0         ; Reset flag to 0
      SJMP print_line  

koniec: 
      RET

; --- main program ---
start:    
      init_LCD
    
      MOV DPTR, #text1
      ACALL putstrLCD
      ACALL delay            
            
      SJMP $             ; infinite loop at the end of the program

END