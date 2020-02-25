; LPC9351_Receiver_LCD_ADC0.asm:  This program implements a simple serial port
; communication protocol to program, verify, and read SPI flash memories.  Since
; the program was developed to store wav audio files, it also allows 
; for the playback of said audio.  It is assumed that the wav sampling rate is
; 22050Hz, 8-bit, mono.
;
; Copyright (C) 2012-2019  Jesus Calvino-Fraga, jesusc (at) ece.ubc.ca
; 
; This program is free software; you can redistribute it and/or modify it
; under the terms of the GNU General Public License as published by the
; Free Software Foundation; either version 2, or (at your option) any
; later version.
; 
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
; 
; You should have received a copy of the GNU General Public License
; along with this program; if not, write to the Free Software
; Foundation, 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
; 
; Connections:
; 
; P89LPC9351  SPI_FLASH
; P2.5        Pin 6 (SPI_CLK)
; P2.2        Pin 5 (MOSI)
; P2.3        Pin 2 (MISO)
; P2.4        Pin 1 (CS/)
; GND         Pin 4
; 3.3V        Pins 3, 7, 8
;
; P0.4 is the DAC output which should be connected to the input of an amplifier (LM386 or similar)
;
; Pins P1.7, P0.0, P2.1, and P2.0 are connected to the internal Analog to Digital Converter 0 (ADC0)
;
; P3.0 is connected to a push button
;
; LCD uses pins P0.5, P0.6, P0.7, P1.2, P1.3, P1.4, P1.6
; WARNING: P1.2 and P1.3 need each a 1k ohm pull-up resistor to VCC.
;
; P2.7 is used (with a transistor) to turn the speaker on/off so it doesn't have a clicking sound.  Use a NPN BJT
; like the 2N3904 or 2N2222A.  The emitter is connected to GND.  The base is connected to a 330 ohm resistor
; and pin P2.7; the other pin of the resistor is connected to 5V.  The collector is connected to the '-'
; terminal of the speaker.
;
; Pins not used in this program: P2.6, P3.1, P0.1, P0.2, P0.3

$NOLIST
$MOD9351
$LIST

CLK         EQU 14746000  ; Microcontroller system clock frequency in Hz
CCU_RATE    EQU 22050     ; 22050Hz is the sampling rate of the wav file we are playing
CCU_RELOAD  EQU ((65536-((CLK/(2*CCU_RATE)))))
BAUD        EQU 115200
BRVAL       EQU ((CLK/BAUD)-16)

TIMER0_RATE   	EQU 100000     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD 	EQU ((65536-(CLK/(2*TIMER0_RATE))))
TEMP_THRESHOLD 	EQU 500
TIMER1_RATE   EQU 100   ; 1000Hz, for a timer tick of 1ms
TIMER1_RELOAD EQU ((65536-(CLK/TIMER1_RATE)))

FLASH_CE    EQU P2.4
SOUND       EQU P2.7
OVEN_PIN	EQU P2.6

; Commands supported by the SPI flash memory according to the datasheet
WRITE_ENABLE     EQU 0x06  ; Address:0 Dummy:0 Num:0
WRITE_DISABLE    EQU 0x04  ; Address:0 Dummy:0 Num:0
READ_STATUS      EQU 0x05  ; Address:0 Dummy:0 Num:1 to infinite
READ_BYTES       EQU 0x03  ; Address:3 Dummy:0 Num:1 to infinite
READ_SILICON_ID  EQU 0xab  ; Address:0 Dummy:3 Num:1 to infinite
FAST_READ        EQU 0x0b  ; Address:3 Dummy:1 Num:1 to infinite
WRITE_STATUS     EQU 0x01  ; Address:0 Dummy:0 Num:1
WRITE_BYTES      EQU 0x02  ; Address:3 Dummy:0 Num:1 to 256
ERASE_ALL        EQU 0xc7  ; Address:0 Dummy:0 Num:0
ERASE_BLOCK      EQU 0xd8  ; Address:3 Dummy:0 Num:0
READ_DEVICE_ID   EQU 0x9f  ; Address:0 Dummy:2 Num:1 to infinite

; NAME
TEMP_READ   EQU P2.7
BTN_START   EQU P0.2 ; TODO: assign port
BTN_SETVAL  EQU P0.1
BTN_INCR    EQU P0.3

; These 'equ' must match the wiring between the microcontroller and the LCD!
LCD_RS EQU P0.5
LCD_RW EQU P0.6
LCD_E  EQU P0.7
LCD_D4 EQU P1.2
LCD_D5 EQU P3.1
LCD_D6 EQU P1.4
LCD_D7 EQU P1.6

; List of sound bite index
DegC 	equ 0
one 	equ 1
two 	equ 2
three 	equ 3
four 	equ 4
five 	equ 5
six 	equ 6
seven 	equ 7
eight 	equ 8 
nine 	equ 9
ten 	equ 10
eleven 	equ 11 
twelve 	equ 12
thirteen equ 13
fourteen equ 14
fifteen	equ 15
sixteen equ 16
seventeen equ 17
eighteen equ 18
nineteen equ 19
twenty equ 20
thirty equ 21
fourty equ 22
fifty equ 23
sixty equ 24
seventy equ 25
eighty equ 28
ninety equ 29
hundred equ 30
twohund equ 31
threehund equ 32
RtoS equ 33
PheatS equ 34
RtoP equ 35
Reflow equ 36
Cooling equ 37
Start equ 38
Stop equ 39
Warning equ 40 
didntreach equ 41
abortion equ 42

org 0x0000 ; Reset vector
    ljmp MainProgram

org 0x0003 ; External interrupt 0 vector (not used in this code)
	ljmp emergency_ISR

org 0x000B ; Timer/Counter 0 overflow interrupt vector (not used in this code)
	ljmp Timer0_ISR

org 0x0013 ; External interrupt 1 vector (not used in this code)
	reti

org 0x001B ; Timer/Counter 1 overflow interrupt vector (not used in this code
	ljmp Timer1_ISR

org 0x0023 ; Serial port receive/transmit interrupt vector (not used in this code)
	reti

org 0x005b ; CCU interrupt vector.  Used in this code to replay the wave file.
	ljmp CCU_ISR

dseg at 0x30
;counter: ds 1
x:   ds 4
y:   ds 4
bcd: ds 5
w:   ds 3 ; 24-bit play counter.  Decremented in CCU ISR.
FSM_state:  ds 1
Var_temp:   ds 2
Var_sec:    ds 2
Var_power:  ds 1
Val_to_set: ds 1
temp: 		ds 1
Display_number: ds 2

Count10ms:    ds 1 ; Used to determine when half second has passed
BCD_counter:  ds 1 ; The BCD counter incrememted in the ISR and displayed in the main loop
Count1ms: ds 2 ;

SoundINDEX: 		ds 1 ; Index of the sound

Temp_soak:  ds 2 ; 0
Time_soak:  ds 2 ; 1
Temp_peak:  ds 2 ; 2
Time_peak:  ds 2 ; 3
Temp_cool:  ds 2 ; 4

bseg
mf: dbit 1
emergency_shutoff: dbit 1
Change_flag: dbit 1
voice_flag1: dbit 1
voice_flag2: dbit 1
voice_flag3: dbit 1
voice_flag4: dbit 1
voice_flag5: dbit 1
half_seconds_flag: dbit 1 ; Set to one in the ISR every time 500 ms had passed


cseg

message0: db 'Idle',0
message1: db 'Ramp to soak',0
message2: db 'Preheat/soak',0
message3: db 'Ramp to peak',0
message4: db 'Heating at peak',0
message5: db 'Cooling Down',0
tempsoak_message: db 'Soak temp: ',0
timesoak_message: db 'Soak time: ',0
temppeak_message: db 'Peak temp: ',0
timepeak_message: db 'Peak time: ',0
tempcool_message: db 'Cool temp: ',0
time_message: db 'Time:', 0
temp_message: db 'Temp:', 0
 
Hello_World:
    DB  '\r', '\n', 0
 

Line1: db 'CH3 CH2 CH1 CH0', 0
Line2: db 'xxx xxx xxx xxx', 0

$NOLIST
$include(LCD_4bit_LPC9351.inc) ; A library of LCD related functions and utility macros
$include(lcd_4bit.inc)
$include(speaker.inc)
$include(math32.inc)
$LIST

; interrupt stuff here
emergency_ISR_Init:
	setb EX0
	ret

emergency_ISR:
	;cpl P1.7
	cpl emergency_shutoff

	Wait_Milli_Seconds(#150)
	reti
	
;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 0                     ;
;---------------------------------;
Timer0_Init:
	mov a, TMOD
	anl a, #0xf0 ; Clear the bits for timer 0
	orl a, #0x01 ; Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0
	ret

;---------------------------------;
; ISR for timer 0.  Set to execute;
; every 1/4096Hz to generate a    ;
; 2048 Hz square wave at pin P3.7 ;
;---------------------------------;
Timer0_ISR:
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	;cpl heatPin ; Connect speaker to this pin
	reti
	
;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 1                     ;
;---------------------------------;
Timer1_Init:
	mov a, TMOD
	anl a, #0x0f ; Clear the bits for timer 1
	orl a, #0x10 ; Configure timer 1 as 16-timer
	mov TMOD, a
	mov TH1, #high(TIMER1_RELOAD)
	mov TL1, #low(TIMER1_RELOAD)
	
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	
	; Enable the timer and interrupts
    setb ET1  ; Enable timer 1 interrupt
    setb TR1  ; Start timer 1
	ret

Timer1_ISR:
	mov TH1, #high(TIMER1_RELOAD)
	mov TL1, #low(TIMER1_RELOAD)
	;cpl P2.6 ; To check the interrupt rate with oscilloscope. It must be precisely a 10 ms pulse.
	
	; The two registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	; Increment the 8-bit 10-mili-second counter
	inc Count1ms+0    ; Increment the low 8-bits first
	mov a, Count1ms+0 ; If the low 8-bits overflow, then increment high 8-bits
	jnz Inc_Done
	inc Count1ms+1

Inc_Done:
	; Check if half second has passed
	mov a, Count1ms+0
	cjne a, #low(500), Timer1_ISR_done ; Warning: this instruction changes the carry flag!
	mov a, Count1ms+1
	cjne a, #high(500), Timer1_ISR_done
	
	; 500 milliseconds have passed.  Set a flag so the main program knows
	setb half_seconds_flag ; Let the main program know half second had passed
	cpl TR0 ; Enable/disable timer/counter 0. This line creates a beep-silence-beep-silence sound.
	; Reset to zero the 10-milli-seconds counter, it is a 8-bit variable
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Increment the BCD counter
	mov a, BCD_counter
	add a, #0x01
	sjmp Timer1_ISR_da

Timer1_ISR_da:
	da a ; Decimal adjust instruction.  Check datasheet for more details!
	mov BCD_counter, a
    mov a,Var_sec
    add a,#0x01
    da a
    mov Var_sec,a
	
Timer1_ISR_done:
	pop psw
	pop acc
	reti


;---------------------------------;
; Routine to initialize the CCU.  ;
; We are using the CCU timer in a ;
; manner similar to the timer 2   ;
; available in other 8051s        ;
;---------------------------------;
CCU_Init:
	mov TH2, #high(CCU_RELOAD)
	mov TL2, #low(CCU_RELOAD)
	mov TOR2H, #high(CCU_RELOAD)
	mov TOR2L, #low(CCU_RELOAD)
	mov TCR21, #10000000b ; Latch the reload value
	mov TICR2, #10000000b ; Enable CCU Timer Overflow Interrupt
	setb ECCU ; Enable CCU interrupt
	setb TMOD20 ; Start CCU timer
	ret

;---------------------------------;
; ISR for CCU.  Used to playback  ;
; the WAV file stored in the SPI  ;
; flash memory.                   ;
;---------------------------------;
CCU_ISR:
	mov TIFR2, #0 ; Clear CCU Timer Overflow Interrupt Flag bit. Actually, it clears all the bits!
	
	; The registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	; Check if the play counter is zero.  If so, stop playing sound.
	mov a, w+0
	orl a, w+1
	orl a, w+2
	jz stop_playing
	
	; Decrement play counter 'w'.  In this implementation 'w' is a 24-bit counter.
	mov a, #0xff
	dec w+0
	cjne a, w+0, keep_playing
	dec w+1
	cjne a, w+1, keep_playing
	dec w+2
	
keep_playing:

	lcall Send_SPI ; Read the next byte from the SPI Flash...
	mov AD1DAT3, a ; and send it to the DAC
	
	sjmp CCU_ISR_Done

stop_playing:
	clr TMOD20 ; Stop CCU timer
	setb FLASH_CE  ; Disable SPI Flash
	clr SOUND ; Turn speaker off

CCU_ISR_Done:	
	pop psw
	pop acc
	reti

;---------------------------------;
; Initial configuration of ports. ;
; After reset the default for the ;
; pins is 'Open Drain'.  This     ;
; routine changes them pins to    ;
; Quasi-bidirectional like in the ;
; original 8051.                  ;
; Notice that P1.2 and P1.3 are   ;
; always 'Open Drain'. If those   ;
; pins are to be used as output   ;
; they need a pull-up resistor.   ;
;---------------------------------;
Ports_Init:
    ; Configure all the ports in bidirectional mode:
    mov P0M1, #00H
    mov P0M2, #00H
    mov P1M1, #00H
    mov P1M2, #00H ; WARNING: P1.2 and P1.3 need 1 kohm pull-up resistors if used as outputs!
    mov P2M1, #00H
    mov P2M2, #00H
    mov P3M1, #00H
    mov P3M2, #00H
	ret

;---------------------------------;
; Sends a byte via serial port    ;
;---------------------------------;
putchar:
	jbc	TI,putchar_L1
	sjmp putchar
putchar_L1:
	mov	SBUF,a
	ret

;---------------------------------;
; Receive a byte from serial port ;
;---------------------------------;
getchar:
	jbc	RI,getchar_L1
	sjmp getchar
getchar_L1:
	mov	a,SBUF
	ret

;---------------------------------;
; Initialize the serial port      ;
;---------------------------------;
InitSerialPort:
	mov	BRGCON,#0x00
	mov	BRGR1,#high(BRVAL)
	mov	BRGR0,#low(BRVAL)
	mov	BRGCON,#0x03 ; Turn-on the baud rate generator
	mov	SCON,#0x52 ; Serial port in mode 1, ren, txrdy, rxempty
	; Make sure that TXD(P1.0) and RXD(P1.1) are configured as bidrectional I/O
	anl	P1M1,#11111100B
	anl	P1M2,#11111100B
	ret

;---------------------------------;
; Initialize ADC1/DAC1 as DAC1.   ;
; Warning, the ADC1/DAC1 can work ;
; only as ADC or DAC, not both.   ;
; The P89LPC9351 has two ADC/DAC  ;
; interfaces.  One can be used as ;
; ADC and the other can be used   ;
; as DAC.  Also configures the    ;
; pin associated with the DAC, in ;
; this case P0.4 as 'Open Drain'. ;
;---------------------------------;
InitDAC1:
    ; Configure pin P0.4 (DAC1 output pin) as open drain
	orl	P0M1,   #00010000B
	orl	P0M2,   #00010000B
    mov ADMODB, #00101000B ; Select main clock/2 for ADC/DAC.  Also enable DAC1 output (Table 25 of reference manual)
	mov	ADCON1, #00000100B ; Enable the converter
	mov AD1DAT3, #0x80     ; Start value is 3.3V/2 (zero reference for AC WAV file)
	ret

;---------------------------------;
; Initialize ADC0/DAC0 as ADC0.   ;
;---------------------------------;
InitADC0:
	; ADC0_0 is connected to P1.7
	; ADC0_1 is connected to P0.0
	; ADC0_2 is connected to P2.1
	; ADC0_3 is connected to P2.0
    ; Configure pins P1.7, P0.0, P2.1, and P2.0 as inputs
    orl P0M1, #00000001b
    anl P0M2, #11111110b
    orl P1M1, #10000000b
    anl P1M2, #01111111b
    orl P2M1, #00000011b
    anl P2M2, #11111100b
	; Setup ADC0
	setb BURST0 ; Autoscan continuos conversion mode
	mov	ADMODB,#0x20 ;ADC0 clock is 7.3728MHz/2
	mov	ADINS,#0x0f ; Select the four channels of ADC0 for conversion
	mov	ADCON0,#0x05 ; Enable the converter and start immediately
	; Wait for first conversion to complete
InitADC0_L1:
	mov	a,ADCON0
	jnb	acc.3,InitADC0_L1
	ret

;---------------------------------;
; Change the internal RC osc. clk ;
; from 7.373MHz to 14.746MHz.     ;
;---------------------------------;
Double_Clk:
    mov dptr, #CLKCON
    movx a, @dptr
    orl a, #00001000B ; double the clock speed to 14.746MHz
    movx @dptr,a
	ret

;---------------------------------;
; Initialize the SPI interface    ;
; and the pins associated to SPI. ;
;---------------------------------;
Init_SPI:
	; Configure MOSI (P2.2), CS* (P2.4), and SPICLK (P2.5) as push-pull outputs (see table 42, page 51)
	anl P2M1, #low(not(00110100B))
	orl P2M2, #00110100B
	; Configure MISO (P2.3) as input (see table 42, page 51)
	orl P2M1, #00001000B
	anl P2M2, #low(not(00001000B)) 
	; Configure SPI
	mov SPCTL, #11010000B ; Ignore /SS, Enable SPI, DORD=0, Master=1, CPOL=0, CPHA=0, clk/4
	ret

;---------------------------------;
; Sends AND receives a byte via   ;
; SPI.                            ;
;---------------------------------;
Send_SPI:
	mov SPDAT, a
Send_SPI_1:
	mov a, SPSTAT 
	jnb acc.7, Send_SPI_1 ; Check SPI Transfer Completion Flag
	mov SPSTAT, a ; Clear SPI Transfer Completion Flag
	mov a, SPDAT ; return received byte via accumulator
	ret

;---------------------------------;
; SPI flash 'write enable'        ;
; instruction.                    ;
;---------------------------------;
Enable_Write:
	clr FLASH_CE
	mov a, #WRITE_ENABLE
	lcall Send_SPI
	setb FLASH_CE
	ret

;---------------------------------;
; This function checks the 'write ;
; in progress' bit of the SPI     ;
; flash memory.                   ;
;---------------------------------;
Check_WIP:
	clr FLASH_CE
	mov a, #READ_STATUS
	lcall Send_SPI
	mov a, #0x55
	lcall Send_SPI
	setb FLASH_CE
	jb acc.0, Check_WIP ;  Check the Write in Progress bit
	ret
	
;---------------------------------;
; CRC-CCITT (XModem) Polynomial:  ;
; x^16 + x^12 + x^5 + 1 (0x1021)  ;
; CRC in [R7,R6].                 ;
; Converted to a macro to remove  ;
; the overhead of 'lcall' and     ;
; 'ret' instructions, since this  ;
; 'routine' may be executed over  ;
; 4 million times!                ;
;---------------------------------;
;crc16:
crc16 mac
	xrl	a, r7			; XOR high of CRC with byte
	mov r0, a			; Save for later use
	mov	dptr, #CRC16_TH ; dptr points to table high
	movc a, @a+dptr		; Get high part from table
	xrl	a, r6			; XOR With low byte of CRC
	mov	r7, a			; Store to high byte of CRC
	mov a, r0			; Retrieve saved accumulator
	mov	dptr, #CRC16_TL	; dptr points to table low	
	movc a, @a+dptr		; Get Low from table
	mov	r6, a			; Store to low byte of CRC
	;ret
endmac

;---------------------------------;
; High constants for CRC-CCITT    ;
; (XModem) Polynomial:            ;
; x^16 + x^12 + x^5 + 1 (0x1021)  ;
;---------------------------------;
CRC16_TH:
	db	000h, 010h, 020h, 030h, 040h, 050h, 060h, 070h
	db	081h, 091h, 0A1h, 0B1h, 0C1h, 0D1h, 0E1h, 0F1h
	db	012h, 002h, 032h, 022h, 052h, 042h, 072h, 062h
	db	093h, 083h, 0B3h, 0A3h, 0D3h, 0C3h, 0F3h, 0E3h
	db	024h, 034h, 004h, 014h, 064h, 074h, 044h, 054h
	db	0A5h, 0B5h, 085h, 095h, 0E5h, 0F5h, 0C5h, 0D5h
	db	036h, 026h, 016h, 006h, 076h, 066h, 056h, 046h
	db	0B7h, 0A7h, 097h, 087h, 0F7h, 0E7h, 0D7h, 0C7h
	db	048h, 058h, 068h, 078h, 008h, 018h, 028h, 038h
	db	0C9h, 0D9h, 0E9h, 0F9h, 089h, 099h, 0A9h, 0B9h
	db	05Ah, 04Ah, 07Ah, 06Ah, 01Ah, 00Ah, 03Ah, 02Ah
	db	0DBh, 0CBh, 0FBh, 0EBh, 09Bh, 08Bh, 0BBh, 0ABh
	db	06Ch, 07Ch, 04Ch, 05Ch, 02Ch, 03Ch, 00Ch, 01Ch
	db	0EDh, 0FDh, 0CDh, 0DDh, 0ADh, 0BDh, 08Dh, 09Dh
	db	07Eh, 06Eh, 05Eh, 04Eh, 03Eh, 02Eh, 01Eh, 00Eh
	db	0FFh, 0EFh, 0DFh, 0CFh, 0BFh, 0AFh, 09Fh, 08Fh
	db	091h, 081h, 0B1h, 0A1h, 0D1h, 0C1h, 0F1h, 0E1h
	db	010h, 000h, 030h, 020h, 050h, 040h, 070h, 060h
	db	083h, 093h, 0A3h, 0B3h, 0C3h, 0D3h, 0E3h, 0F3h
	db	002h, 012h, 022h, 032h, 042h, 052h, 062h, 072h
	db	0B5h, 0A5h, 095h, 085h, 0F5h, 0E5h, 0D5h, 0C5h
	db	034h, 024h, 014h, 004h, 074h, 064h, 054h, 044h
	db	0A7h, 0B7h, 087h, 097h, 0E7h, 0F7h, 0C7h, 0D7h
	db	026h, 036h, 006h, 016h, 066h, 076h, 046h, 056h
	db	0D9h, 0C9h, 0F9h, 0E9h, 099h, 089h, 0B9h, 0A9h
	db	058h, 048h, 078h, 068h, 018h, 008h, 038h, 028h
	db	0CBh, 0DBh, 0EBh, 0FBh, 08Bh, 09Bh, 0ABh, 0BBh
	db	04Ah, 05Ah, 06Ah, 07Ah, 00Ah, 01Ah, 02Ah, 03Ah
	db	0FDh, 0EDh, 0DDh, 0CDh, 0BDh, 0ADh, 09Dh, 08Dh
	db	07Ch, 06Ch, 05Ch, 04Ch, 03Ch, 02Ch, 01Ch, 00Ch
	db	0EFh, 0FFh, 0CFh, 0DFh, 0AFh, 0BFh, 08Fh, 09Fh
	db	06Eh, 07Eh, 04Eh, 05Eh, 02Eh, 03Eh, 00Eh, 01Eh

;---------------------------------;
; Low constants for CRC-CCITT     ;
; (XModem) Polynomial:            ;
; x^16 + x^12 + x^5 + 1 (0x1021)  ;
;---------------------------------;
CRC16_TL:
	db	000h, 021h, 042h, 063h, 084h, 0A5h, 0C6h, 0E7h
	db	008h, 029h, 04Ah, 06Bh, 08Ch, 0ADh, 0CEh, 0EFh
	db	031h, 010h, 073h, 052h, 0B5h, 094h, 0F7h, 0D6h
	db	039h, 018h, 07Bh, 05Ah, 0BDh, 09Ch, 0FFh, 0DEh
	db	062h, 043h, 020h, 001h, 0E6h, 0C7h, 0A4h, 085h
	db	06Ah, 04Bh, 028h, 009h, 0EEh, 0CFh, 0ACh, 08Dh
	db	053h, 072h, 011h, 030h, 0D7h, 0F6h, 095h, 0B4h
	db	05Bh, 07Ah, 019h, 038h, 0DFh, 0FEh, 09Dh, 0BCh
	db	0C4h, 0E5h, 086h, 0A7h, 040h, 061h, 002h, 023h
	db	0CCh, 0EDh, 08Eh, 0AFh, 048h, 069h, 00Ah, 02Bh
	db	0F5h, 0D4h, 0B7h, 096h, 071h, 050h, 033h, 012h
	db	0FDh, 0DCh, 0BFh, 09Eh, 079h, 058h, 03Bh, 01Ah
	db	0A6h, 087h, 0E4h, 0C5h, 022h, 003h, 060h, 041h
	db	0AEh, 08Fh, 0ECh, 0CDh, 02Ah, 00Bh, 068h, 049h
	db	097h, 0B6h, 0D5h, 0F4h, 013h, 032h, 051h, 070h
	db	09Fh, 0BEh, 0DDh, 0FCh, 01Bh, 03Ah, 059h, 078h
	db	088h, 0A9h, 0CAh, 0EBh, 00Ch, 02Dh, 04Eh, 06Fh
	db	080h, 0A1h, 0C2h, 0E3h, 004h, 025h, 046h, 067h
	db	0B9h, 098h, 0FBh, 0DAh, 03Dh, 01Ch, 07Fh, 05Eh
	db	0B1h, 090h, 0F3h, 0D2h, 035h, 014h, 077h, 056h
	db	0EAh, 0CBh, 0A8h, 089h, 06Eh, 04Fh, 02Ch, 00Dh
	db	0E2h, 0C3h, 0A0h, 081h, 066h, 047h, 024h, 005h
	db	0DBh, 0FAh, 099h, 0B8h, 05Fh, 07Eh, 01Dh, 03Ch
	db	0D3h, 0F2h, 091h, 0B0h, 057h, 076h, 015h, 034h
	db	04Ch, 06Dh, 00Eh, 02Fh, 0C8h, 0E9h, 08Ah, 0ABh
	db	044h, 065h, 006h, 027h, 0C0h, 0E1h, 082h, 0A3h
	db	07Dh, 05Ch, 03Fh, 01Eh, 0F9h, 0D8h, 0BBh, 09Ah
	db	075h, 054h, 037h, 016h, 0F1h, 0D0h, 0B3h, 092h
	db	02Eh, 00Fh, 06Ch, 04Dh, 0AAh, 08Bh, 0E8h, 0C9h
	db	026h, 007h, 064h, 045h, 0A2h, 083h, 0E0h, 0C1h
	db	01Fh, 03Eh, 05Dh, 07Ch, 09Bh, 0BAh, 0D9h, 0F8h
	db	017h, 036h, 055h, 074h, 093h, 0B2h, 0D1h, 0F0h

; Display a 3-digit BCD number in the LCD
LCD_3BCD:
	mov a, bcd+1
	anl a, #0x0f
	orl a, #'0'
	lcall ?WriteData
	mov a, bcd+0
	swap a
	anl a, #0x0f
	orl a, #'0'
	lcall ?WriteData
	mov a, bcd+0
	anl a, #0x0f
	orl a, #'0'
	lcall ?WriteData
	ret
	
;
;	ADC Handling
;

Wait10us:
	mov R0, #18
	djnz R0, $
	ret
Average_AD0DAT2:
	Load_x(0)
	mov R5, #100
Sum_loop0:
	mov y+3, #0
	mov y+2, #0
	mov y+1, #0
	mov y+0, AD0DAT0

	lcall add32
	lcall Wait10us

	djnz R5, Sum_loop0
	Load_y(100)
	lcall div32
	ret

Display_ADC_Values:
	; Analog input to pin P0.0
	mov x+0, AD0DAT3
	mov x+1, #0
	mov x+2, #0
	mov x+3, #0

	;lcall Average_AD0DAT2

	Load_y(368)
	lcall mul32

	Load_y(255)
	lcall div32

	Load_y(20)
	lcall add32

	mov a, x+0
	mov Var_temp, a

	lcall Hex2BCD
	Set_Cursor(1, 12)
	lcall LCD_3BCD
    Send_BCD(bcd)
    mov DPTR, #Hello_World
    lcall SendString
	; Some delay so the LCD looks ok
	Wait_Milli_Seconds(#250)
	ret

; ; What's this?????

Incr_value:
    mov a, Val_to_set
    cjne a, #0, IV1
    mov a, Temp_soak
    cjne a, #1, IV0a
	mov Temp_soak, #0
    ret
IV0a:
    add a, #1
    da a
    mov Temp_soak, a
    ret
IV1:
    cjne a, #1, IV2
    mov a, Time_soak
    cjne a, #255, IV1a
	mov Temp_soak, #0
    ret
IV1a:
    add a, #1
    da a
    mov Time_soak, a
    ret
IV2:
    cjne a, #2, IV3
    mov a, Temp_peak
    cjne a, #255, IV2a
	mov Temp_soak, #0
    ret
IV2a:
    add a, #1
    da a
    mov Temp_peak, a
    ret
IV3:
    cjne a, #3, IV4
    mov a, Time_peak
    cjne a, #255, IV3a
	mov Temp_soak, #0
    ret
IV3a:
    add a, #1
    da a
    mov Time_peak, a
    ret
IV4:
    cjne a, #4, IV5
    mov a, Temp_cool
    cjne a, #255, IV4a
	mov Temp_soak, #0
    ret
IV4a:
    add a, #1
    da a
    mov Temp_cool, a
    ret
IV5:
    ret

Set_Reflow_Params:
    lcall DisplayEdit
    ; If SETVAL button is pressed, change variable to be incremented
	jb BTN_SETVAL, SRP1
	Wait_Milli_Seconds(#50)
	jb BTN_SETVAL, SRP1
	jnb BTN_SETVAL, $
    mov a, Val_to_set
    cjne a, #4, SV1
    mov Val_to_set, #0x00 ; Set Val_to_set to 0 if it's at 4
    sjmp SRP1
SV1:
    mov a, Val_to_set ; Otherwise increment Val_to_set by 1
    add a, #0x01
    da a
    mov Val_to_set, a
SRP1:
    ; if INCR is pressed, add one to current variable (maximum of 255)
    jb BTN_INCR, SRP2
	Wait_Milli_Seconds(#100)
	;;jb BTN_INCR, SRP2
	;;jnb BTN_INCR, $
    lcall Incr_value
SRP2:
    ret

DisplayEdit:
    WriteCommand(#0x01)
    Wait_Milli_Seconds(#5)
    mov a, Val_to_set
    cjne a, #0, next_edit1
    
    Set_Cursor(1,1)
    Send_Constant_String(#tempsoak_message)
    Set_Cursor(2,1)
    mov x+0, Temp_soak
	mov x+1, #0
	mov x+2, #0
	mov x+3, #0
	lcall Hex2BCD
	lcall LCD_3BCD
    ljmp end_edit
next_edit1:
    cjne a, #1, next_edit2
    Set_Cursor(1,1)
    Send_Constant_String(#timesoak_message)
    Set_Cursor(2,1)
    mov x+0, Time_soak
	mov x+1, #0
	mov x+2, #0
	mov x+3, #0
	lcall Hex2BCD
    lcall LCD_3BCD
    ljmp end_edit
next_edit2:
    cjne a, #2, next_edit3
    Set_Cursor(1,1)
    Send_Constant_String(#temppeak_message)
    Set_Cursor(2,1)
    mov x+0, Temp_peak
	mov x+1, #0
	mov x+2, #0
	mov x+3, #0
	lcall Hex2BCD
    lcall LCD_3BCD
    ljmp end_edit
next_edit3:
    cjne a, #3, next_edit4
    Set_Cursor(1,1)
    Send_Constant_String(#timepeak_message)
    Set_Cursor(2,1)
    mov x+0, Time_peak
	mov x+1, #0
	mov x+2, #0
	mov x+3, #0
	lcall Hex2BCD
    lcall LCD_3BCD
    ljmp end_edit
next_edit4:
    cjne a, #4, end_edit
    Set_Cursor(1,1)
    Send_Constant_String(#tempcool_message)
    Set_Cursor(2,1)
    mov x+0, Temp_cool
	mov x+1, #0
	mov x+2, #0
	mov x+3, #0
	lcall Hex2BCD
    lcall LCD_3BCD
end_edit:
    ret
    
;---------------------------------;
; Main program. Includes hardware ;
; initialization and 'forever'    ;
; loop.                           ;
;---------------------------------;
MainProgram:
    mov SP, #0x7F
    
    lcall Ports_Init ; Default all pins as bidirectional I/O. See Table 42.
    lcall LCD_4BIT
    lcall Double_Clk
	lcall InitSerialPort
	lcall InitADC0 ; Call after 'Ports_Init'
	lcall InitDAC1 ; Call after 'Ports_Init'
	lcall CCU_Init
	lcall Init_SPI
	lcall Timer1_init

 	lcall emergency_ISR_Init ;enable pin12 emergency stop
	
	clr emergency_shutoff
	clr TMOD20 	; Stop CCU timer
	setb EA ; Enable global interrupts.
	
	clr SOUND ; Turn speaker off
	
	; Initialize variables
	setb OVEN_PIN

	;;Set_Cursor(1, 1)
    ;;Send_Constant_String(#Line1)
	;;Set_Cursor(2, 1)
    ;;Send_Constant_String(#Line2)

	; Initialize default values for reflow parameter
    mov Temp_soak, #150
    mov Time_soak, #60
    mov Temp_peak, #200
    mov Time_peak, #45
    mov Temp_cool, #60

    mov Val_to_set, #0
    mov FSM_state, #0

	setb voice_flag1
	setb voice_flag2
	setb voice_flag3
	setb voice_flag4
	setb voice_flag5
	
forever_loop:
	jnb emergency_shutoff, abortSkip
		mov Change_flag,#0x00
    mov FSM_state, #0
    ; subb the number of
    
abortSkip:
    mov a, FSM_state
    lcall Regular_display

FSM_0: ; Idle
    cjne a, #0, FSM_1
    setb OVEN_PIN
	setb voice_flag5
    mov Var_power, #0
    lcall Set_Reflow_Params
	jb BTN_START, FSM_0a  ; if the 'RESET' button is not pressed skip
	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	jb BTN_START, FSM_0a  ; if the 'RESET' button is not pressed skip
	jnb BTN_START, $		; Wait for button release.  The '$' means: jump to same instruction.
    mov FSM_state, #1 ; Go to state 1 if button is pressed
    ljmp FSM_done
FSM_0a:
    mov FSM_state, #0 ; Else stay in state 0
    ljmp FSM_done

FSM_1: ; Ramp to soak
	jnb voice_flag1, Skip_voice1
	clr voice_flag1
	; Announce the state
	push acc
	mov a, #RtoS

	lcall Play_Sound_Using_Index
	jb TMOD20, $ ; Wait for sound to finish playing

	pop acc

	;
Skip_voice1: 
	;clr OVEN_PIN
    ;lcall Display_ADC_Values
    mov a,FSM_state
    cjne a, #1, FSM_2
	mov Var_power, #100
    mov a, Var_temp
	Set_Cursor(2, 14)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(Var_sec) ; This macro is also in 'LCD_4bit_LPC9351.inc'
    cjne a, Temp_soak, FSM_1b
    sjmp FSM_1b
FSM_1b:
    jc FSM_1a
    clr OVEN_PIN
    ;;turn on oven
    mov Var_sec,#0x00
    mov FSM_state, #2
    ljmp FSM_done
FSM_1a:
    Set_Cursor(1,5)
    Send_Constant_String(#temp_message)
    ;goes next state
    mov FSM_state, #1
    ljmp FSM_done

FSM_2: ; Preheat/soak

	jnb voice_flag2, Skip_voice2
	clr voice_flag2
	setb voice_flag1
	; Announce the state
	push acc
	mov a, #RtoS
	lcall Play_Sound_Using_Index
	jb TMOD20, $ ; Wait for sound to finish playing
	pop acc
	;
Skip_voice2:
    cjne a, #2, FSM_3
    setb OVEN_PIN
    
    ; INSERT TIME COMPARISON HERE
    ; TIMER 1 HAS BEEN IMPLEMENTED AND TAKES DATA
    ; in ~1s inervals
    ; subb the number of a from something im tired
    
    ; upon entering this timed state, reset a variable (and flag)
    ; that holds time that the timer1 interrupt is constantly
    ; incrementing. (in interrupt) once the elapsed time has passed,
    ; set the flag and go into the next state.

    mov a,Var_sec
    cjne a, Time_soak, FSM_2b
    sjmp FSM_2b
    ;cjne a, Time_soak, FSM_2b
    ;sjmp FSM_2a
FSM_2b:
    ;if its greater than time_soak goes next state
    ;;if not goes 2a
    jc FSM_2a
    mov FSM_state, #3
    ljmp FSM_done

toggle_temp:
    jc turn_on_soak
    setb OVEN_PIN
    mov FSM_state,#2
    ljmp FSM_done

turn_on_soak:
    clr OVEN_PIN
    mov FSM_state,#2
    ljmp FSM_done

FSM_2a:
    mov a,Var_temp
    ;;checks temp
    ;;if its less, turn on, if its more turn off
    cjne a,Temp_soak,toggle_temp
    mov FSM_state, #2
    ljmp FSM_done

FSM_3: ; Ramp to peak
	jnb voice_flag3, Skip_voice3
	clr voice_flag3
	setb voice_flag2
	; Announce the state
	push acc
	mov a, #RtoS
	lcall Play_Sound_Using_Index
	jb TMOD20, $ ; Wait for sound to finish playing
	pop acc
	;
Skip_voice3:
    cjne a, #3, FSM_4
    mov Var_power, #100
    mov a, Var_temp
    ;;checls temp_peak to current temp
    cjne a, Temp_peak, FSM_3b
    sjmp FSM_3b
FSM_3b:
    jc FSM_3a
    ;;if its greater than goes next state if its less goes 3a
    mov Var_sec,#0x00
    mov FSM_state, #4
    ljmp FSM_done
FSM_3a:
    mov FSM_state, #3
    ;;keep heat on
    clr OVEN_PIN
    ljmp FSM_done

FSM_4: ; Heating at peak/reflow
	jnb voice_flag4, Skip_voice4
	clr voice_flag4
	setb voice_flag3
	; Announce the state
	push acc
	mov a, #Reflow
	lcall Play_Sound_Using_Index
	jb TMOD20, $ ; Wait for sound to finish playing
	pop acc
	;
Skip_voice4:
    cjne a, #4, FSM_5
    mov Var_power, #20
    mov a, Var_sec;;reflow time
    cjne a, Time_peak, FSM_4b
    sjmp FSM_4b
FSM_4b:
    jc FSM_4a
    ;goes to next stage if it is time is more the time peak
    mov FSM_state, #5
    ljmp FSM_done
FSM_4a:
    mov FSM_state, #4
    mov a,Var_temp
    ;checks temp, if its less turn on,if its more turn off
    cjne a,Temp_peak,toggle_reflow
    ljmp FSM_done

toggle_reflow:
    jnc reflow_on
    setb OVEN_PIN
    ljmp FSM_done

reflow_on:
    clr OVEN_PIN
    ljmp FSM_done

FSM_5: ; Cooling down
	jnb voice_flag5, Skip_voice5
	clr voice_flag5
	setb voice_flag4
	; Announce the state
	push acc
	mov a, #Cooling
	lcall Play_Sound_Using_Index
	jb TMOD20, $ ; Wait for sound to finish playing
	pop acc
	;
Skip_voice5:
    cjne a, #5, FSM_done
    mov Var_power, #0
    mov a, Var_temp
    cjne a, Temp_cool, FSM_5b
    sjmp FSM_5c
FSM_5b:
    jnc FSM_5a
FSM_5c:
    setb OVEN_PIN
    mov FSM_state, #0
    ljmp FSM_done
FSM_5a:
    mov FSM_state, #5
    ljmp FSM_done

FSM_done:

	;lcall Display_ADC_Values

	Wait_Milli_Seconds(#200)
	ljmp forever_loop
	
END
