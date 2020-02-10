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
	mov DPTR,#Space
	lcall SendString
	pop acc
	sjmp Temp

end
