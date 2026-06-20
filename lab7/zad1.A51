ljmp start

; === Adresy LCD ===
LCDstatus  equ 0FF2EH       ; rejestr statusu (bit7 = zajety)
LCDcontrol equ 0FF2CH       ; rejestr komend
LCDdataWR  equ 0FF2DH       ; rejestr danych ASCII

; === Adresy RTC (format BCD, x=jednosci, pierwsza litera=dziesiatki) ===
RTCxs equ 0FF00H    ; sekundy  - jednosci
RTCsx equ 0FF01H    ; sekundy  - dziesiatki
RTCxm equ 0FF02H    ; minuty   - jednosci
RTCmx equ 0FF03H    ; minuty   - dziesiatki
RTCxh equ 0FF04H    ; godziny  - jednosci
RTChx equ 0FF05H    ; godziny  - dziesiatki
RTCxd equ 0FF06H    ; dzien    - jednosci
RTCdx equ 0FF07H    ; dzien    - dziesiatki
RTCxn equ 0FF08H    ; miesiac  - jednosci
RTCnx equ 0FF09H    ; miesiac  - dziesiatki
RTCxy equ 0FF0AH    ; rok      - jednosci
RTCyx equ 0FF0BH    ; rok      - dziesiatki
RTCdw equ 0FF0CH    ; dzien tygodnia (1=Pon ... 7=Nd)
RTCpf equ 0FF0FH    ; konfiguracja RTC (bit2 = tryb 24h)

; === Kody komend LCD ===
HOME     equ 80H    ; kursor na poczatek linii 1
INITDISP equ 38H    ; init: tryb 8-bit, 2 linie
HOM2     equ 0C0H   ; kursor na poczatek linii 2
LCDON    equ 0EH    ; wlacz LCD, kursor widoczny
CLEAR    equ 01H    ; wyczysc wyswietlacz

org 0100H
    Czas:    db "42:00:69"     ; lancuch inicjalizujacy czas "HH:MM:SS"
    Dzien:   db "32:13:2022*1" ; lancuch inicjalizujacy date "DD:MM:YYYY*D"
    TwentyH: db "2"            ; stala cyfra tysiecy roku
    TwentyL: db "0"            ; stala cyfra setek roku
    MonthNames: db "StyLutMarKwiMajCzeLipSieWrzPazLisGru" ; skroty miesiecy (3 znaki kazdy)
    DayNames:   db "PonWtoCzwSobNiePiaSro"                ; skroty dni tyg. (1=Pon..7=Sro)

; === MACRO: LCDcntrlWR - wyslij bajt komendy do LCD, czeka az LCD bedzie gotowy ===
LCDcntrlWR MACRO x
           LOCAL loop
loop: MOV  DPTR, #LCDstatus
      MOVX A, @DPTR
      JB   ACC.7, loop
      MOV  DPTR, #LCDcontrol
      MOV  A, x
      MOVX @DPTR, A
      ENDM

; === MACRO: LCDcharWR - wyslij znak ASCII z akumulatora na LCD ===
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

; === MACRO: init_LCD - pelna sekwencja inicjalizacji wyswietlacza ===
init_LCD MACRO
         LCDcntrlWR INITDISP
         LCDcntrlWR CLEAR
         LCDcntrlWR LCDON
         ENDM

; === MACRO: disp_nibble - odczytaj polowke BCD z RTC (DPTR), wyswietl jako cyfre ASCII ===
disp_nibble MACRO
    movx A, @DPTR
    anl  A, #0Fh
    orl  A, #30H
    call putcharLCD
    ENDM

; === FUNKCJA: putcharLCD - wyslij znak z A na LCD ===
putcharLCD:
    LCDcharWR
    ret

; === FUNKCJA: disp_time - wyswietl czas na linii 1 w formacie HH:MM:SS ===
disp_time:
    LCDcntrlWR HOME
    mov DPTR, #RTChx
    disp_nibble
    mov DPTR, #RTCxh
    disp_nibble
    mov A, #':'
    call putcharLCD
    mov DPTR, #RTCmx
    disp_nibble
    mov DPTR, #RTCxm
    disp_nibble
    mov A, #':'
    call putcharLCD
    mov DPTR, #RTCsx
    disp_nibble
    mov DPTR, #RTCxs
    disp_nibble
    RET

; === FUNKCJA: disp_month_abbr - wyswietl 3-literowy skrot miesiaca, numer miesiaca w R6 ===
disp_month_abbr:
    mov  A, R6
    dec  A
    mov  B, #3
    mul  AB
    mov  DPTR, #MonthNames
    movc A, @A+DPTR
    call putcharLCD
    mov  A, R6
    dec  A
    mov  B, #3
    mul  AB
    inc  A
    mov  DPTR, #MonthNames
    movc A, @A+DPTR
    call putcharLCD
    mov  A, R6
    dec  A
    mov  B, #3
    mul  AB
    inc  A
    inc  A
    mov  DPTR, #MonthNames
    movc A, @A+DPTR
    call putcharLCD
    RET

; === FUNKCJA: disp_dow_abbr - wyswietl 3-literowy skrot dnia tygodnia z RTCdw ===
disp_dow_abbr:
    mov  DPTR, #RTCdw
    movx A, @DPTR
    anl  A, #0Fh
    dec  A
    mov  B, #3
    mul  AB
    mov  DPTR, #DayNames
    movc A, @A+DPTR
    call putcharLCD
    mov  DPTR, #RTCdw
    movx A, @DPTR
    anl  A, #0Fh
    dec  A
    mov  B, #3
    mul  AB
    inc  A
    mov  DPTR, #DayNames
    movc A, @A+DPTR
    call putcharLCD
    mov  DPTR, #RTCdw
    movx A, @DPTR
    anl  A, #0Fh
    dec  A
    mov  B, #3
    mul  AB
    inc  A
    inc  A
    mov  DPTR, #DayNames
    movc A, @A+DPTR
    call putcharLCD
    RET

; === FUNKCJA: disp_date - wyswietl date na linii 2 w formacie DD-MMM-20YY DOW ===
disp_date:
    LCDcntrlWR HOM2
    mov DPTR, #RTCdx
    disp_nibble
    mov DPTR, #RTCxd
    disp_nibble
    mov A, #'-'
    call putcharLCD
    clr  A
    mov  DPTR, #RTCnx
    movx A, @DPTR
    anl  A, #0Fh
    mov  B, #0Ah
    mul  AB
    mov  R6, A
    mov  DPTR, #RTCxn
    movx A, @DPTR
    anl  A, #0Fh
    add  A, R6
    mov  R6, A
    call disp_month_abbr
    mov A, #'-'
    call putcharLCD
    clr  A
    mov  DPTR, #TwentyH
    movc A, @A+DPTR
    call putcharLCD
    clr  A
    mov  DPTR, #TwentyL
    movc A, @A+DPTR
    call putcharLCD
    mov  DPTR, #RTCyx
    disp_nibble
    mov  DPTR, #RTCxy
    disp_nibble
    mov A, #' '
    call putcharLCD
    call disp_dow_abbr
    RET

; === FUNKCJA: czas_start - inicjalizacja czasu z lancucha ASCII "HH:MM:SS" do RTC ===
czas_start:
    mov  DPTR, #RTCpf
    movx A, @DPTR
    orl  A, #04H
    movx @DPTR, A
    clr  C
    clr  A
    mov  dptr, #Czas
    movc A, @A+DPTR
    subb A, #30h
    push dph
    push dpl
    mov  dptr, #RTChx
    movx @dptr, A
    pop  dpl
    pop  dph
    inc  dptr
    clr  A
    movc A, @A+DPTR
    subb A, #30h
    push dph
    push dpl
    mov  dptr, #RTCxh
    movx @dptr, A
    pop  dpl
    pop  dph
    inc  dptr
    clr  A
    movc A, @A+DPTR
    inc  dptr
    clr  A
    movc A, @A+DPTR
    subb A, #30h
    push dph
    push dpl
    mov  dptr, #RTCmx
    movx @dptr, A
    pop  dpl
    pop  dph
    inc  dptr
    clr  A
    movc A, @A+DPTR
    subb A, #30h
    push dph
    push dpl
    mov  dptr, #RTCxm
    movx @dptr, A
    pop  dpl
    pop  dph
    inc  dptr
    clr  A
    movc A, @A+DPTR
    inc  dptr
    clr  A
    movc A, @A+DPTR
    subb A, #30h
    push dph
    push dpl
    mov  dptr, #RTCsx
    movx @dptr, A
    pop  dpl
    pop  dph
    inc  dptr
    clr  A
    movc A, @A+DPTR
    subb A, #30h
    push dph
    push dpl
    mov  dptr, #RTCxs
    movx @dptr, A
    pop  dpl
    pop  dph
    ret

; === FUNKCJA: data_start - inicjalizacja daty z lancucha ASCII "DD:MM:YYYY*D" do RTC ===
data_start:
    clr  C
    clr  A
    mov  dptr, #Dzien
    movc A, @A+DPTR
    subb A, #30h
    push dph
    push dpl
    mov  dptr, #RTCdx
    movx @dptr, A
    pop  dpl
    pop  dph
    inc  dptr
    clr  A
    movc A, @A+DPTR
    subb A, #30h
    push dph
    push dpl
    mov  dptr, #RTCxd
    movx @dptr, A
    pop  dpl
    pop  dph
    inc  dptr
    clr  A
    movc A, @A+DPTR
    inc  dptr
    clr  A
    movc A, @A+DPTR
    subb A, #30h
    push dph
    push dpl
    mov  dptr, #RTCnx
    movx @dptr, A
    pop  dpl
    pop  dph
    inc  dptr
    clr  A
    movc A, @A+DPTR
    subb A, #30h
    push dph
    push dpl
    mov  dptr, #RTCxn
    movx @dptr, A
    pop  dpl
    pop  dph
    inc  dptr
    clr  A
    movc A, @A+DPTR
    inc  dptr
    clr  A
    movc A, @A+DPTR
    inc  dptr
    clr  A
    movc A, @A+DPTR
    inc  dptr
    clr  A
    movc A, @A+DPTR
    subb A, #30h
    push dph
    push dpl
    mov  dptr, #RTCyx
    movx @dptr, A
    pop  dpl
    pop  dph
    inc  dptr
    clr  A
    movc A, @A+DPTR
    subb A, #30h
    push dph
    push dpl
    mov  dptr, #RTCxy
    movx @dptr, A
    pop  dpl
    pop  dph
    inc  dptr
    clr  A
    movc A, @A+DPTR
    inc  dptr
    clr  A
    movc A, @A+DPTR
    subb A, #30h
    push dph
    push dpl
    mov  dptr, #RTCdw
    movx @dptr, A
    pop  dpl
    pop  dph
    ret

; === FUNKCJA: check_time_date - kontrola zakresu danych inicjalizujacych
;     sek/min: 0-59 | godz: 0-23 | mies: 1-12 | dni: 1-31
;     przy bledzie ustawia minimalna dopuszczalna wartosc ===
check_time_date:
    clr  A
    mov  dptr, #RTChx
    movx A, @dptr
    anl  A, #0Fh
    mov  B, #0Ah
    mul  AB
    mov  R5, A
    mov  dptr, #RTCxh
    clr  A
    movx A, @dptr
    anl  A, #0Fh
    add  A, R5
    clr  C
    subb A, #24
    jc   check_minutes
    mov  dptr, #RTChx
    clr  A
    movx @dptr, A
    mov  dptr, #RTCxh
    movx @dptr, A

check_minutes:
    clr  A
    mov  dptr, #RTCmx
    movx A, @dptr
    anl  A, #0Fh
    mov  B, #0Ah
    mul  AB
    mov  R5, A
    mov  dptr, #RTCxm
    clr  A
    movx A, @dptr
    anl  A, #0Fh
    add  A, R5
    clr  C
    subb A, #60
    jc   check_seconds
    mov  dptr, #RTCmx
    clr  A
    movx @dptr, A
    mov  dptr, #RTCxm
    movx @dptr, A

check_seconds:
    clr  A
    mov  dptr, #RTCsx
    movx A, @dptr
    anl  A, #0Fh
    mov  B, #0Ah
    mul  AB
    mov  R5, A
    mov  dptr, #RTCxs
    clr  A
    movx A, @dptr
    anl  A, #0Fh
    add  A, R5
    clr  C
    subb A, #60
    jc   check_months
    mov  dptr, #RTCsx
    clr  A
    movx @dptr, A
    mov  dptr, #RTCxs
    movx @dptr, A

check_months:
    clr  A
    mov  dptr, #RTCnx
    movx A, @dptr
    anl  A, #0Fh
    mov  B, #0Ah
    mul  AB
    mov  R5, A
    mov  dptr, #RTCxn
    clr  A
    movx A, @dptr
    anl  A, #0Fh
    add  A, R5
    mov  R6, A
    jz   month_zero_case
    clr  C
    subb A, #13
    jc   check_days

month_zero_case:
    mov  dptr, #RTCnx
    clr  A
    movx @dptr, A
    mov  dptr, #RTCxn
    mov  A, #1
    movx @dptr, A
    mov  R6, #1

check_days:
    clr  A
    mov  dptr, #RTCdx
    movx A, @dptr
    anl  A, #0Fh
    mov  B, #0Ah
    mul  AB
    mov  R5, A
    mov  dptr, #RTCxd
    clr  A
    movx A, @dptr
    anl  A, #0Fh
    add  A, R5
    jz   day_zero_case
    clr  C
    subb A, #32
    jc   check_done

day_zero_case:
    mov  dptr, #RTCdx
    clr  A
    movx @dptr, A
    mov  dptr, #RTCxd
    mov  A, #1
    movx @dptr, A

check_done:
    ret

start:
    init_LCD
    acall czas_start
    acall data_start
    acall check_time_date

czas_plynie:
    acall disp_time
    acall disp_date
    sjmp  czas_plynie

    NOP
    NOP
    NOP
    JMP $
END START