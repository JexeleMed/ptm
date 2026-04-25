$NOMOD51
$INCLUDE (reg517.inc)

; P5 equ 0F8H  <-- USUNIĘTE (A10)
; P7 equ 0DBH  <-- USUNIĘTE (A10)
    
LCDstatus  equ 0FF2EH       
LCDcontrol equ 0FF2CH       
LCDdataWR  equ 0FF2DH       
#define  INITDISP 0x38     
#define  LCDON    0x0E     
#define  CLEAR    0x01     

    ORG 0000H
    LJMP start
    ORG 0100H

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

start:  
    init_LCD

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
    SJMP scan_matrix

key_pressed:
    MOV B, A
    MOV A, P5
    ANL A, #0F0H
    ORL A, B
    MOV R4, A

wait_for_release:
    MOV P5, #00H
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, wait_for_release
    ACALL delay

    MOV R2, #0
    MOV DPTR, #SCAN_CODES
    MOV A, R4              ; <-- załaduj R4 do A RAZ przed pętlą

find_loop:
    PUSH ACC               ; zachowaj R4 (w A)
    MOV A, R2
    MOVC A, @A+DPTR        ; pobierz bajt z tabeli
    MOV B, A               ; B = bajt z tabeli
    POP ACC                ; A = R4 (szukany kod)
    JZ  scan_matrix        ; B==0 → koniec tabeli (sprawdź przed XRL)
    XRL A, B               ; A = 0 gdy A==B  (fix A22!)
    JZ  print_char         ; dopasowanie!
    MOV A, R4              ; przywróć R4 do A na kolejną iterację
    INC R2
    LJMP find_loop         ; LJMP zamiast SJMP (fix A51)

print_char:
    MOV DPTR, #ASCII_CHARS  
    MOV A, R2               
    MOVC A, @A+DPTR         
    ACALL putcharLCD        
    SJMP scan_matrix

SCAN_CODES:
    DB 0EBH, 077H, 07BH, 07DH, 0B7H, 0BBH, 0BDH, 0D7H, 0DBH, 0DDH
    DB 07EH, 0BEH, 0DEH, 0EEH, 0E7H, 0EDH, 00H

ASCII_CHARS:
    DB '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'
    DB 'A', 'B', 'C', 'D', '*', '#'

    NOP
    NOP
    NOP
end_prog: 
    SJMP $
    END