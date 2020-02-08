$NOLIST
$MOD9351
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
    mov FSM_state, #0

FSM_loop:
    ; TODO: read temperature, time into variables
    ; TODO: check for abort conditions
    mov a, FSM_state

FSM_0: ; Idle
    cjne a, #0, FSM_1
    mov Var_power, #0
    mov a, BTN_start
    cjne a, #0, FSM_0a ; Check if button is pressed
    mov FSM_state, #1 ; Go to state 1 if button is pressed
    ljmp FSM_done
FSM_0a:
    mov FSM_state, #0 ; Else stay in state 0
    ljmp FSM_done

FSM_1: ; Ramp to soak
    cjne a, #1, FSM_2
    mov Var_power, #100
    mov a, Var_temp
    cjne a, #TEMP_SOAK, FSM_1b
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
    cjne a, #TIME_SOAK, FSM_2b
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
    cjne a, #TEMP_PEAK, FSM_3b
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
    cjne a, #TIME_PEAK, FSM_4b
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
    cjne a, #TEMP_COOL, FSM_5b
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
    ljmp FSM_loop
    