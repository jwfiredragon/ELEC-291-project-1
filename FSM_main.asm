$NOLIST
$MOD9351
$LIST

; TODO: initialization
; Justin adding tinerrupt shit

cseg
org 0x0000
    ljmp main
 
; External interrupt 0 vector for pin p1.3
; this
org 0x0003
    ljmp emergency_ISR
 
; Timer/Counter 0 overflow interrupt vector
org 0x000B
    ljmp Timer0_ISR

org 001BH
    ljmp 1803H ; Needed if using the debugger
; For a 7.373MHz internal oscillator, one machine
; cycle takes 2/7.373MHz =0.27126us

bseg
emergency_shutoff: dbit 1

dseg at 0x30
; These 'equ' must match the wiring between the microcontroller and the LCD!
LCD_RS equ P0.5
LCD_RW equ P0.6
LCD_E  equ P0.7
LCD_D4 equ P1.2
LCD_D5 equ P1.3
LCD_D6 equ P1.4
LCD_D7 equ P1.6

CLK         EQU 14746000  ; Microcontroller system clock frequency in Hz
CCU_RATE    EQU 22050     ; 22050Hz is the sampling rate of the wav file we are playing
CCU_RELOAD  EQU ((65536-((CLK/(2*CCU_RATE)))))
BAUD        EQU 115200
BRVAL       EQU ((CLK/BAUD)-16)
TIMER0_RATE   EQU 100000     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD EQU ((65536-(CLK/(2*TIMER0_RATE))))
TEMP_THRESHOLD EQU 500

TEMP_READ   equ P2.7
BTN_START   equ 1 ; TODO: assign port
BTN_SETVAL  equ 1
BTN_INCR    equ 1
BTN_DECR    equ 1

FSM_state:  ds 1
Var_temp:   ds 2
Var_sec:    ds 2
Var_power:  ds 1
Val_to_set: ds 1

Temp_soak:  ds 2 ; 0
Time_soak:  ds 2 ; 1
Temp_peak:  ds 2 ; 2
Time_peak:  ds 2 ; 3
Temp_cool:  ds 2 ; 4

$NOLIST
$include(LCD_4bit_LPC9351.inc) ; A library of LCD related functions and utility macros
$include(lcd_4bit.inc)
$LIST

cseg

message0: db 'Current stage: Idle',0
message1: db 'Current stage: Ramp to soak',0
message2: db 'Current stage: Preheat/soak',0
message3: db 'Current stage: Ramp to peak',0
message4: db 'Current stage: Heating at peak',0
message5: db 'Current stage: Cooling Down',0
temp_message: db 'temperature is: ',0
Time_message: db 'Duration:',0

; interrupt stuff here
emergency_ISR_Init:
	setb EX0
	ret

emergency_ISR:
	cpl p1.7
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


Incr_value:
    mov a, Val_to_set
    cjne a, #0, IV1
    mov a, Temp_soak
    ChangeDisplay(Temp_soak)
    cjne a, #255, IV0a
    ret
IV0a:
    add a, #0x01
    da a
    mov Temp_soak, a
    ret
IV1:
    cjne a, #1, IV2
    mov a, Time_soak
    ChangeDisplay(Time_soak)
    cjne a, #255, IV1a
    ret
IV1a:
    add a, #0x01
    da a
    mov Time_soak, a
    ret
IV2:
    cjne a, #2, IV3
    mov a, Temp_peak
    ChangeDisplay(Temp_peak)
    cjne a, #255, IV2a
    ret
IV2a:
    add a, #0x01
    da a
    mov Temp_peak, a
    ret
IV3:
    cjne a, #3, IV4
    mov a, Time_peak
    ChangeDisplay(Time_peak)
    cjne a, #255, IV3a
    ret
IV3a:
    add a, #0x01
    da a
    mov Time_peak, a
    ret
IV4:
    cjne a, #4, IV5
    mov a, Temp_cool
    ChangeDisplay(Temp_cool)
    cjne a, #255, IV4a
    ret
IV4a:
    add a, #0x01
    da a
    mov Temp_cool, a
    ret
IV5:
    ret

Decr_value:
    mov a, Val_to_set
    cjne a, #0, DV1
    mov a, Temp_soak
    ChangeDisplay(Temp_soak)
    cjne a, #0, DV0a
    ret
DV0a:
    subb a, #0x01
    da a
    mov Temp_soak, a
    ret
DV1:
    cjne a, #1, DV2
    mov a, Time_soak
    ChangeDisplay(Time_soak)
    cjne a, #0, DV1a
    ret
DV1a:
    subb a, #0x01
    da a
    mov Time_soak, a
    ret
DV2:
    cjne a, #2, DV3
    mov a, Temp_peak
    ChangeDisplay(Temp_peak)
    cjne a, #0, DV2a
    ret
DV2a:
    subb a, #0x01
    da a
    mov Temp_peak, a
    ret
DV3:
    cjne a, #3, DV4
    mov a, Time_peak
    ChangeDisplay(Time_peak)
    cjne a, #0, DV3a
    ret
DV3a:
    subb a, #0x01
    da a
    mov Time_peak, a
    ret
DV4:
    cjne a, #4, DV5
    mov a, Temp_cool
    ChangeDisplay(Temp_cool)
    cjne a, #0, DV4a
    ret
DV4a:
    subb a, #0x01
    da a
    mov Temp_cool, a
    ret
DV5:
    ret

Set_Reflow_Params:
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
    jb BTN_SETVAL, SRP2
	Wait_Milli_Seconds(#100)
	jb BTN_SETVAL, SRP2
	jnb BTN_SETVAL, $
    lcall Incr_value
SRP2:
    ; if DECR is pressed, subtract one from current variable (minimum of 0)
    jb BTN_SETVAL, SRP3
	Wait_Milli_Seconds(#100)
	jb BTN_SETVAL, SRP3
	jnb BTN_SETVAL, $
    lcall Decr_Value
SRP3:
    ret

main:
    ;;Set_Cursor(1,1)
    ;;Send_Constant_String(#temp_message)
	; initialize
    mov SP, #7FH
    lcall LCD_4BIT
 	lcall Timer0_Init ;enable timer0 interrupt
 	lcall emergency_ISR_Init ;enable pin12 emergency stop
 	setb EA   ; Enable Global interrupts
    mov P0M1, #00H
    mov P0M2, #00H
    mov P1M1, #00H
    mov P1M2, #00H ; WARNING: P1.2 and P1.3 need 1kohm pull-up resistors!
    mov P2M1, #00H
    mov P2M2, #00H
    mov P3M1, #00H
    mov P3M2, #00H
    setb p1.7
    clr emergency_shutoff

    ; Initialize default values for reflow parameter
    mov Temp_soak, #150
    mov Time_soak, #60
    mov Temp_peak, #220
    mov Time_peak, #45
    mov Temp_cool, #60

    mov Val_to_set, #0
    mov FSM_state, #0

FSM_loop:
    ; TODO: read temperature, time into variables
    ; TODO: check for abort conditions
    
    jnb emergency_shutoff, abortSkip
    mov FSM_state, #0
    
abortSkip:
    mov a, FSM_state
    lcall Regular_display

FSM_0: ; Idle
    cjne a, #0, FSM_1
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
    cjne a, #1, FSM_2
    mov Var_power, #100
    mov a, Var_temp
    cjne a, Temp_soak, FSM_1b
    sjmp FSM_1a
FSM_1b:
    jc FSM_1a
    mov FSM_state, #2
    ljmp FSM_done
FSM_1a:
    mov FSM_state, #1
    ljmp FSM_done

FSM_2: ; Preheat/soak
    cjne a, #2, FSM_3
    mov Var_power, #20
    mov a, Var_sec
    cjne a, Time_soak, FSM_2b
    sjmp FSM_2a
FSM_2b:
    jc FSM_2a
    mov FSM_state, #3
    ljmp FSM_done
FSM_2a:
    mov FSM_state, #2
    ljmp FSM_done

FSM_3: ; Ramp to peak
    cjne a, #3, FSM_4
    mov Var_power, #100
    mov a, Var_temp
    cjne a, Temp_peak, FSM_3b
    sjmp FSM_3a
FSM_3b:
    jc FSM_3a
    mov FSM_state, #4
    ljmp FSM_done
FSM_3a:
    mov FSM_state, #3
    ljmp FSM_done

FSM_4: ; Heating at peak
    cjne a, #4, FSM_5
    mov Var_power, #20
    mov a, Var_sec
    cjne a, Time_peak, FSM_4b
    sjmp FSM_4a
FSM_4b:
    jc FSM_4a
    mov FSM_state, #5
    ljmp FSM_done
FSM_4a:
    mov FSM_state, #4
    ljmp FSM_done

FSM_5: ; Cooling down
    cjne a, #5, FSM_done
    mov Var_power, #0
    mov a, Var_temp
    cjne a, Temp_cool, FSM_5b
    sjmp FSM_5c
FSM_5b:
    jc FSM_5a
FSM_5c:
    mov FSM_state, #5
    ljmp FSM_done
FSM_5a:
    mov FSM_state, #0
    ljmp FSM_done

FSM_done:
    ; TODO: report status
    ljmp FSM_loop
end
