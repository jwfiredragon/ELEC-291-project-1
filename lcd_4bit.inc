dseg at 0x30
Display_number: ds 1 ;set Display_number as 1 byte variable

cseg
message0: db 'Current stage: Idle',0
message1: db 'Current stage: Ramp to soak',0
message2: db 'Current stage: Preheat/soak',0
message3: db 'Current stage: Ramp to peak',0
message4: db 'Current stage: Heating at peak',0
message5: db 'Current stage: Cooling Down',0
temp_message: db 'temperature is: ',0
Time_message: db 'Duration:',0

ChangeDisplay mac
    push AR2
    WriteCommand(#0x01)
    ;Wait for clear screen command to finish. Usually takes 1.52ms.
    mov R2, #2
    Wait_Milli_Seconds(#5) ;wait 5ms

    mov a,%0 ;mov mac to a
    da a        ;change to hex
    mov Display_number,a ;mov to display_number
    Set_Cursor(1,1)
    Send_Constant_String(#temp_message)
    Display_BCD(Display_number) ;display to lcd
    pop AR2
endmac

Regular_display:
    mov a,Var_temp
    da a
    mov Var_temp,a
    ;display what state it is in
    Set_Cursor(1,1)
    mov a, FSM_state
    cjne a,#5,next_line4
    Send_Constant_String(#message5)
    ljmp skip_display
next_line4:
    cjne a,#4,next_line3
    Send_Constant_String(#message4)
    ljmp skip_display
next_line3:
    cjne a,#3,next_line2
    Send_Constant_String(#message3)
    ljmp skip_display
next_line2:
    cjne a,#2,next_line1
    Send_Constant_String(#message2)
    ljmp skip_display
next_line1:
    cjne a,#1,next_line0
    Send_Constant_String(#message1)
    ljmp skip_display
next_line0:
    Send_Constant_String(#message0)
skip_display:;display the temp
    Set_Cursor(2,1)
    Send_Constant_String(#temp_message)
    Display_BCD(Var_temp)
    ret
end





