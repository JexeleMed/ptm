$NOMOD51
$INCLUDE (reg517.inc)

LCDstatus  equ 0FF2EH
LCDcontrol equ 0FF2CH
LCDdataWR  equ 0FF2DH

MAX_CHARS  equ 32
LINE2_POS  equ 16

#define  INITDISP 0x38
#define  HOM2     0xC0
#define  LCDON    0x0E
#define  CLEAR    0x01

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

; --- PROCEDURY ---

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
    MOV R5, #0

scan_matrix:
    MOV P5, #0EFH
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, key_L4

    MOV P5, #0DFH
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, key_L3

    MOV P5, #0BFH
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, key_L2

    MOV P5, #07FH
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, key_L1

    SJMP scan_matrix

key_L4: ORL A, #0EFH
        SJMP process_key
key_L3: ORL A, #0DFH
        SJMP process_key
key_L2: ORL A, #0BFH
        SJMP process_key
key_L1: ORL A, #07FH

process_key:
    MOV R4, A

wait_for_release:
    MOV P5, #00H
    MOV A, P7
    ANL A, #0FH
    CJNE A, #0FH, wait_for_release
    ACALL delay

    MOV R2, #0
    MOV DPTR, #SCAN_CODES

search_code:
    MOV A, R2
    MOVC A, @A+DPTR         ; pobierz bajt z tabeli
    JZ   scan_matrix        ; 00H = koniec tabeli, nieznany klawisz
    XRL  A, R4              ; porównaj z zapisanym kodem (fix A22!)
    JZ   manage_cursor      ; A==R4 gdy XRL daje 0
    INC  R2
    SJMP search_code        ; pętla blisko - SJMP wystarczy

manage_cursor:
    MOV A, R5
    XRL A, #MAX_CHARS
    JNZ check_line2
    MOV R5, #0
    LCDcntrlWR #CLEAR
    SJMP print_char

check_line2:
    MOV A, R5
    XRL A, #LINE2_POS
    JNZ print_char
    LCDcntrlWR #HOM2

print_char:
    MOV DPTR, #ASCII_CHARS
    MOV A, R2
    MOVC A, @A+DPTR
    ACALL putcharLCD
    INC R5
    LJMP scan_matrix
	
; --- TABELE ---

SCAN_CODES:
    DB 0EBH, 077H, 07BH, 07DH, 0B7H, 0BBH, 0BDH, 0D7H, 0DBH, 0DDH
    DB 07EH, 0BEH, 0DEH, 0EEH, 0E7H, 0EDH, 00H

ASCII_CHARS:
    DB '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'
    DB 'A', 'B', 'C', 'D', '*', '#'

end_prog:
    SJMP $

    END