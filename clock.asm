$NOLIST
$MOD9351
$LIST

CLK             EQU 7373000 ; Microcontroller system crystal frequency in Hz
TIMER1_RATE     EQU 10      ; 10Hz, for a timer tick of 100ms
TIMER1_RELOAD   EQU ((65536-(CLK/(2*TIMER1_RATE))))

org 0x0000 ; Reset
    ljmp main
org 0x0003 ; External interrupt 0
	reti
org 0x000B ; Timer/Counter 0 overflow
	reti
org 0x0013 ; External interrupt 1
	reti
org 0x001B ; Timer/Counter 1 overflow
	ljmp Timer1_ISR
org 0x0023 ; Serial port receive/transmit
	reti

dseg at 0x30
count_seconds:    ds 1
count_minutes:    ds 1
count_hours:      ds 1

cseg
; These 'equ' must match the wiring between the microcontroller and the LCD!
LCD_RS equ P0.7
LCD_RW equ P3.0
LCD_E  equ P3.1
LCD_D4 equ P2.0
LCD_D5 equ P2.1
LCD_D6 equ P2.2
LCD_D7 equ P2.3
$NOLIST
$include(LCD_4bit_LPC9351.inc) ; A library of LCD related functions and utility macros
$LIST

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
	; Enable the timer and interrupts
    setb ET1  ; Enable timer 1 interrupt
    setb TR1  ; Start timer 1
	ret

;---------------------------------;
; ISR for timer 1                 ;
;---------------------------------;
Timer1_ISR:
	mov TH1, #high(TIMER1_RELOAD)
	mov TL1, #low(TIMER1_RELOAD)
	cpl P2.6 ; To check the interrupt rate with oscilloscope. It must be precisely a 10 ms pulse.
	
	; The two registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	; Increment the 8-bit 10-mili-second counter
	inc Count10ms

Inc_Done:
	; Check if half second has passed
	mov a, Count10ms
	cjne a, #50, Timer1_ISR_done ; Warning: this instruction changes the carry flag!
	
	; 500 milliseconds have passed.  Set a flag so the main program knows
	setb half_seconds_flag ; Let the main program know half second had passed
	;cpl TR0 ; Enable/disable timer/counter 0. This line creates a beep-silence-beep-silence sound.
	; Reset to zero the 10-milli-seconds counter, it is a 8-bit variable
	mov Count10ms, #0
	; Increment the BCD counter
	mov a, BCD_counter
	cjne a, #0x59, reset_sixty ; continue with normal incrementing unless seconds is at 59
	mov a,BCD_counter
	add a, #0x01
	sjmp Timer1_ISR_da
Timer2_ISR_decrements:
	mov a,BCD_counter
	cjne a,#0x00,skip_s
	mov a,#0x60
skip_s:
	add a, #0x99 ; Adding the 10-complement of -1 is like subtracting 1.
	mov BCD_counter,a
Timer2_ISR_da:
	da a ; Decimal adjust instruction.  Check datasheet for more details!
	mov BCD_counter, a
Timer2_ISR_done:
	pop psw
	pop acc
	reti
Timer2_ISR_decrementm:
	mov a,minute
	cjne a,#0x00,skip_m
	mov a,#0x60
skip_m:
	add a, #0x99 ; Adding the 10-complement of -1 is like subtracting 1.
	mov minute,a
	da a ; Decimal adjust instruction.  Check datasheet for more details!
	mov minute, a
	ljmp Timer2_ISR_done
Timer2_ISR_decrementh:
	mov a,hour
	cjne a,#0x00,skip_h
	mov a,#0x13
skip_h:
	add a, #0x99 ; Adding the 10-complement of -1 is like subtracting 1.
	mov hour,a
	da a
	mov hour,a
	ljmp Timer2_ISR_done
reset_sixty:
	mov a,minute
	add a,#1
	da a	
	mov minute,a
	SUBB a,#0x4
	jz	reset_hour
	clr TR2                 ; Stop timer 2
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Now clear the BCD counter
	mov BCD_counter, a
	setb TR2                ; Start timer 2
	ljmp Inc_Done             ; Display the new value
reset_hour:
	mov minute,#0x00
	mov a,hour
	add a,#1
	da a;
	mov hour,a	
	clr TR2                 ; Stop timer 2
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Now clear the BCD counter
	mov BCD_counter, a
	setb TR2                ; Start timer 2
	ljmp Inc_Done  