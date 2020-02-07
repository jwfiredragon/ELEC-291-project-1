$NOLIST
$MODE9351
$LIST

; TODO: initialization

TEMP_SOAK   EQU 150
TIME_SOAK   EQU 60
TEMP_PEAK   EQU 220
TIME_PEAK   EQU 45
TEMP_COOL   EQU 60

dseg at 0x30
FSM_state:  ds 1
Var_temp:   ds 1
Var_sec:    ds 1
Var_power:  ds 1

bseg
BTN_start:  dbit 1 ; TODO: set up button (maybe interrupt?)

main:
    ; TODO: initialization
    mov FSM_state: #0

FSM_loop:
    ; TODO: read temperature, time into variables
    ; TODO: check for abort conditions
    mov a, FSM_state

FSM_state0: ; Idle
    cjne a, #0, FSM_state1
    mov Var_power, #0
    cjne BTN_start, #0, FSM_state0a ; Check if button is pressed
    mov FSM_state, #1 ; Go to state 1 if button is pressed
    sjmp FSM_state1
FSM_state0a:
    mov FSM_state, #0 ; Else stay in state 0

FSM_state1: ; Ramp to soak
    cjne a, #1, FSM_state2
    mov Var_power, #100
    mov a, Var_temp
    cmp a, TEMP_SOAK
    bne FSM_state1a ; Check if soak temperature reached
    mov FSM_state, #2 ; Go to state 2 if soak temperature reached
    sjmp FSM_state2
FSM_state1a:
    mov FSM_state, #1 ; Else stay in state 1

FSM_state2: ; Preheat/soak
    cjne a, #2, FSM_state3
    mov Var_power, #20
    mov a, Var_sec
    cmp a, TIME_SOAK
    bne FSM_state2a ; Check if soak time reached
    mov FSM_state, #3 ; Go to state 3 if soak time reached
    sjmp FSM_state2
FSM_state2a:
    mov FSM_state, #2 ; Else stay in state 2

FSM_state3: ; Ramp to peak
    cjne a, #3, FSM_state4
    mov Var_power, #100
    mov a, Var_temp
    cmp a, TEMP_PEAK
    bne FSM_state3a ; Check if peak temperature reached
    mov FSM_state, #4 ; Go to state 4 if peak temperature reached
    sjmp FSM_state4
FSM_state3a:
    mov FSM_state, #3 ; Else stay in state 3

FSM_state4: ; Heating at peak
    cjne a, #4, FSM_state5
    mov Var_power, #20
    mov a, Var_sec
    cmp a, TIME_PEAK
    bne FSM_state4a ; Check if peak time reached
    mov FSM_state, #5 ; Go to state 5 if peak time reached
    sjmp FSM_state5
FSM_state4a:
    mov FSM_state, #4 ; Else stay in state 4

FSM_state5: ; Cooling down
    cjne a, #5, FSM_done

FSM_done:
    ljmp FSM_loop