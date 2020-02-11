$MOD9351

XTAL EQU 7373000
BAUD EQU 115200
BRVAL EQU ((XTAL/BAUD)-16)

CSEG at 0x0000
	ljmp	MainProgram

; These 'equ' must match the wiring between the microcontroller and the LCD!
LCD_RS equ P0.7
LCD_RW equ P3.0
LCD_E  equ P3.1
LCD_D4 equ P2.0
LCD_D5 equ P2.1
LCD_D6 equ P2.2
LCD_D7 equ P2.3
TEMP_READ equ P2.7
CSEG

DSEG at 30H
x: ds 4
y: ds 4
bcd: ds 5
Result: ds 5
DSEG at 30H
BSEG
mf: dbit 1
$NOLIST
$include(LCD_4bit_LPC9351.inc) ; A library of LCD related functions and utility macros
$include(math32.inc)
$LIST

putchar:
	jbc	TI,putchar_L1
	sjmp putchar
putchar_L1:
	mov	SBUF,a
	ret
	
getchar:
	jbc	RI,getchar_L1
	sjmp getchar
getchar_L1:
	mov	a,SBUF
	ret

Wait1S:
	mov R2, #40
M3:	mov R1, #250
M2:	mov R0, #184
M1:	djnz R0, M1 ; 2 machine cycles-> 2*0.27126us*184=100us
	djnz R1, M2 ; 100us*250=0.025s
	djnz R2, M3 ; 0.025s*40=1s
	ret

InitSerialPort:
	mov	BRGCON,#0x00
	mov	BRGR1,#high(BRVAL)
	mov	BRGR0,#low(BRVAL)
	mov	BRGCON,#0x03 ; Turn-on the baud rate generator
	mov	SCON,#0x52 ; Serial port in mode 1, ren, txrdy, rxempty
	mov	P1M1,#0x00 ; Enable pins RxD and TXD
	mov	P1M2,#0x00 ; Enable pins RxD and TXD
	ret

InitADC1:
    ; Configure pins P0.4, P0.3, P0.2, and P0.1 as inputs
	orl	P0M1,#0x1E
	anl	P0M2,#0xE1
	setb BURST1 ; Autoscan continuos conversion mode
    mov ADMODB, #00100000B ; Select main clock/2 for ADC/DAC.  Also enable DAC1 output (Table 25 of reference manual)
	mov	ADINS,#0xF0 ; Select the four channels for conversion
	mov	ADCON1,#0x05 ; Enable the converter and start immediately
	; Wait for first conversion to complete
InitADC1_L1:
	mov	a,ADCON1
	jnb	acc.3,InitADC1_L1
	ret

HexAscii: db '0123456789ABCDEF'

SendHex:
	mov a, #'0'
	lcall putchar
	mov a, #'x'
	lcall putchar
	mov dptr, #HexAscii 
	mov a, b
	swap a
	anl a, #0xf
	movc a, @a+dptr
	lcall putchar
	mov a, b
	anl a, #0xf
	movc a, @a+dptr
	lcall putchar
	mov a, #' '
	lcall putchar
	ret

SendString:
    clr a
    movc a, @a+dptr
    jz SendString_L1
    lcall putchar
    inc dptr
    sjmp SendString  
SendString_L1:
	ret

Title: db 'EEPROM Test', 0
InitialMessage: db '\r\nEEPROM Test\r\n', 0
Space:
    DB  '\r', '\n', 0

;;Checks Program	
MainProgram:
    mov SP, #0x7F

    ; Configure all the ports in bidirectional mode:
    mov P0M1, #00H
    mov P0M2, #00H
    mov P1M1, #00H
    mov P1M2, #00H ; WARNING: P1.2 and P1.3 need 1kohm pull-up resistors!
    mov P2M1, #00H
    mov P2M2, #00H
    mov P3M1, #00H
    mov P3M2, #00H
	
	lcall InitSerialPort

	lcall InitADC1

	mov dptr, #CLKCON
    movx a, @dptr
    orl a, #00001000B ; double the clock speed to 14.746MHz
    movx @dptr,a
	
    lcall LCD_4BIT
    ; For convenience a few handy macros are included in 'LCD_4bit_LPC9351.inc':
	Set_Cursor(1, 1)
    Send_Constant_String(#Title)

	lcall Wait1S ; Wait a bit so PUTTy has a chance to start
	mov dptr, #InitialMessage
	lcall SendString
	mov Result,#100

	; Write something to the EEPROM

Temp:
	push acc
	mov x,Result
	mov x+1,Result+1
	load_y(41)
	lcall div32
	lcall hex2bcd

	;mov DPTR,TEMP_READ
	;lcall SendString
	mov	b, AD1DAT0
	lcall SendHex
	lcall Wait1S
	mov DPTR,#Space
	lcall SendString
	pop acc
	sjmp Temp

end
