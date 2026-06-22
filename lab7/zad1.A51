ljmp start
	
LCDstatus  equ 0FF2EH       ; adres do odczytu gotowosci LCD
LCDcontrol equ 0FF2CH       ; adres do podania bajtu sterujacego LCD
LCDdataWR  equ 0FF2DH       ; adres do podania kodu ASCII na LCD

RTCxs equ 0FF00H	; seconds
RTCsx equ 0FF01H
RTCxm equ 0FF02H	; minutes
RTCmx equ 0FF03H
RTCxh equ 0FF04H	; hours
RTChx equ 0FF05H
RTCxd equ 0FF06H	; day
RTCdx equ 0FF07H
RTCxn equ 0FF08H	; month
RTCnx equ 0FF09H
RTCxy equ 0FF0AH	; year
RTCyx equ 0FF0BH
RTCdw equ 0FF0CH	; day of week
RTCpd equ 0FF0DH
RTCpf equ 0FF0FH

// bajty sterujace LCD, inne dostepne w opisie LCD na stronie WWW
#define  HOME     0x80     // put cursor to second line  
#define  INITDISP 0x38     // LCD init (8-bit mode)  
#define  HOM2     0xc0     // put cursor to second line  
#define  LCDON    0x0e     // LCD nn, cursor off, blinking off
#define  CLEAR    0x01     // LCD display clear

org 0100H
	TwentyH: db "2"
	TwentyL: db "0"
		
// macro do wprowadzenia bajtu sterujacego na LCD
LCDcntrlWR MACRO x          ; x – parametr wywolania macra – bajt sterujacy
           LOCAL loop       ; LOCAL oznacza ze etykieta loop moze sie powtórzyc w programie
loop: MOV  DPTR,#LCDstatus  ; DPTR zaladowany adresem statusu
      MOVX A,@DPTR          ; pobranie bajtu z biezacym statusem LCD
      JB   ACC.7,loop       ; testowanie najstarszego bitu akumulatora
                            ; – wskazuje gotowosc LCD
      MOV  DPTR,#LCDcontrol ; DPTR zaladowany adresem do podania bajtu sterujacego
      MOV  A, x             ; do akumulatora trafia argument wywolania macra–bajt sterujacy
      MOVX @DPTR,A          ; bajt sterujacy podany do LCD – zadana akcja widoczna na LCD
      ENDM
	  
// macro do wypisania znaku ASCII na LCD, znak ASCII przed wywolaniem macra ma byc w A
LCDcharWR MACRO
      LOCAL tutu            ; LOCAL oznacza ze etykieta tutu moze sie powtórzyc w programie
      PUSH ACC              ; odlozenie biezacej zawartosci akumulatora na stos
tutu: MOV  DPTR,#LCDstatus  ; DPTR zaladowany adresem statusu
      MOVX A,@DPTR          ; pobranie bajtu z biezacym statusem LCD
      JB   ACC.7,tutu       ; testowanie najstarszego bitu akumulatora
                            ; – wskazuje gotowosc LCD
      MOV  DPTR,#LCDdataWR  ; DPTR zaladowany adresem do podania bajtu sterujacego
      POP  ACC              ; w akumulatorze ponownie kod ASCII znaku na LCD
      MOVX @DPTR,A          ; kod ASCII podany do LCD – znak widoczny na LCD
      ENDM
	  
// macro do inicjalizacji wyswietlacza – bez parametrów
init_LCD MACRO
         LCDcntrlWR #INITDISP ; wywolanie macra LCDcntrlWR – inicjalizacja LCD
         LCDcntrlWR #CLEAR    ; wywolanie macra LCDcntrlWR – czyszczenie LCD
         LCDcntrlWR #LCDON    ; wywolanie macra LCDcntrlWR – konfiguracja kursora
         ENDM

// macro do wypisywania polowki wskazania pozycji czasu lub daty
disp_nibble MACRO
	movx A,@DPTR
	anl A,#0Fh	; select 4-bits
	orl A,#30H	; change to ASCII
	call putcharLCD
	ENDM

// funkcja wypisywania znaku na LCD
putcharLCD:	LCDcharWR
			ret
		 
// wypisywanie czasu
disp_time:
	LCDcntrlWR #HOME
	mov DPTR,#RTChx	; get hours from RTC (higher nibble)
	disp_nibble
	mov DPTR,#RTCxh	; get hours from RTC (lower nibble)
	disp_nibble
	mov A,#':'
	call putcharLCD
	mov DPTR,#RTCmx	; get minutes from RTC (higher nibble)
	disp_nibble
	mov DPTR,#RTCxm	; get minutes from RTC (lower nibble)
	disp_nibble
	mov A,#':'
	call putcharLCD;
	mov DPTR,#RTCsx	; get seconds from RTC (higher nibble)
	disp_nibble
	mov DPTR,#RTCxs	; get seconds from RTC (lower nibble)
	disp_nibble
	RET

// wypisywanie daty
disp_date:
	LCDcntrlWR #HOM2
	mov DPTR,#RTCdx	; get day from RTC (higher nibble)
	disp_nibble
	mov DPTR,#RTCxd	; get day from RTC (lower nibble)
	disp_nibble
	mov A,#'-'
	call putcharLCD
	mov DPTR,#RTCnx	; get month from RTC (higher nibble)
	disp_nibble
	mov DPTR,#RTCxn	; get month from RTC (lower nibble)
	disp_nibble
	mov A,#'-'
	call putcharLCD;
	clr a
	mov DPTR,#TwentyH
	movc a, @a+dptr
	call putcharLCD;
	clr a
	mov DPTR,#TwentyL
	movc a, @a+dptr
	call putcharLCD;
	mov DPTR,#RTCyx	; get year from RTC (higher nibble)
	disp_nibble
	mov DPTR,#RTCxy	; get year from RTC (lower nibble)
	disp_nibble
	mov A,#" "
	call putcharLCD;
	mov DPTR,#RTCdw	; get day of week from RTC
	disp_nibble
	RET


        ; program glówny
START:	init_LCD
		mov DPTR, #RTCpf ; 24h zegar
		movx a, @DPTR
		orl a, #04H
		movx @DPTR, a
		
		mov a, #00h
		mov dptr, #RTCxs
		movx @dptr, a	; set sec
		inc dptr
		movx @dptr, a
		inc dptr
		movx @dptr, a	; set min
		inc dptr
		movx @dptr, a
		inc dptr
		movx @dptr, a	; set hour
		inc dptr
		movx @dptr, a
		inc dptr
		mov a, #3		; set day
		movx @dptr, a
		inc dptr
		mov a, #0
		movx @dptr, a
		inc dptr
		mov a, #5		; set month
		movx @dptr, a
		inc dptr
		mov a, #0
		movx @dptr, a
		inc dptr
		mov a, #2		; set year
		movx @dptr, a
		inc dptr
		mov a, #2
		movx @dptr, a
		inc dptr
		mov a, #1		; set day of week
		movx @dptr, a

		
czas_plynie:		acall disp_time
					acall disp_date
					sjmp czas_plynie
		NOP
		NOP
		NOP
		JMP $
END START