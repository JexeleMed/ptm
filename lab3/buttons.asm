; ==========================================================
; TASK 1 - BUTTONS AND LCD DISPLAY HANDLING
; ==========================================================

LCDstatus  EQU 0FF2EH       
LCDcontrol EQU 0FF2CH       
LCDdataWR  EQU 0FF2DH       

HOME       EQU 80H          
INITDISP   EQU 38H          
LCDON      EQU 0EH          
CLEAR      EQU 01H          

ORG 0000H
    LJMP start

ORG 0100H

; --- text declarations for buttons ---
text1:  DB "Button 1 pressed", 00
text2:  DB "Button 2 pressed", 00
text3:  DB "Button 3 pressed", 00
text4:  DB "Button 4 pressed", 00

; --- LCD macros ---
LCDcntrlWR MACRO x          
      LOCAL loop        
loop: MOV  DPTR, #LCDstatus  
      MOVX A, @DPTR          
      JB   ACC.7, loop       
      MOV  DPTR, #LCDcontrol 
      MOV  A, x              
      MOVX @DPTR, A          
ENDM
      
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
      
init_LCD MACRO
      LCDcntrlWR #INITDISP 
      LCDcntrlWR #CLEAR    
      LCDcntrlWR #LCDON    
ENDM

; --- delay function ---
delay:    
      MOV R0, #15H
one:  MOV R1, #0FFH
dwa:  MOV R2, #0FFH
trzy: DJNZ R2, trzy
      DJNZ R1, dwa
      DJNZ R0, one
      RET
            
putcharLCD:    
      LCDcharWR
      RET
            
; --- print short string (without line breaks) ---        
putstrLCD:  
      CLR A
      MOVC A, @A+DPTR
      JZ koniec
      PUSH DPH
      PUSH DPL
      ACALL putcharLCD
      POP DPL
      POP DPH
      INC DPTR
      SJMP putstrLCD
koniec: 
      RET

; --- actions after pressing specific buttons ---
przycisk1:
      LCDcntrlWR #CLEAR
      LCDcntrlWR #HOME
      MOV DPTR, #text1
      ACALL putstrLCD
      ACALL delay
      LJMP begin

przycisk2:
      LCDcntrlWR #CLEAR
      LCDcntrlWR #HOME
      MOV DPTR, #text2
      ACALL putstrLCD
      ACALL delay
      LJMP begin

przycisk3:
      LCDcntrlWR #CLEAR
      LCDcntrlWR #HOME
      MOV DPTR, #text3
      ACALL putstrLCD
      ACALL delay
      LJMP begin

przycisk4:
      LCDcntrlWR #CLEAR
      LCDcntrlWR #HOME
      MOV DPTR, #text4
      ACALL putstrLCD
      ACALL delay
      LJMP begin

; --- main program ---
start:    
      init_LCD
      
begin:
      MOV A, P3
      
      ; 1. Check two outer buttons simultaneously (P3.5 and P3.2 pressed)
      ; Mask: 1101 1011 = 0DBH
      CJNE A, #0DBH, chk_btn1
      LJMP finito             ; Outer buttons pressed - end of program
      
chk_btn1:
      ; 2. Button 1 (P3.5) pressed = 1101 1111 = 0DFH
      CJNE A, #0DFH, chk_btn2
      LJMP przycisk1
      
chk_btn2:
      ; 3. Button 2 (P3.4) pressed = 1110 1111 = 0EFH
      CJNE A, #0EFH, chk_btn3
      LJMP przycisk2
      
chk_btn3:
      ; 4. Button 3 (P3.3) pressed = 1111 0111 = 0F7H
      CJNE A, #0F7H, chk_btn4
      LJMP przycisk3
      
chk_btn4:
      ; 5. Button 4 (P3.2) pressed = 1111 1011 = 0FBH
      CJNE A, #0FBH, begin    ; If none match, return to the beginning (loop)
      LJMP przycisk4
      
finito: 
      LCDcntrlWR #CLEAR                
      SJMP $                  ; end of program, infinite loop

END