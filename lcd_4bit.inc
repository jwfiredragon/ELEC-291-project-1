; dseg
; Display_number: ds 1 ;set Display_number as 1 byte variable
; bseg
; Change_flag:ds 1;1= updated,0=not udapted
; cseg
cseg

ChangeDisplay mac
; ChangeDisplay(%0)

    mov a, %0  ;mov mac to a
    da a        ;change to hex
    mov Display_number,a ;mov to display_number
    Set_Cursor(1,1)
    Send_Constant_String(#temp_message)
    Set_Cursor(2,1)
    Display_BCD(Display_number) ;display to lcd
endmac

Regular_display:    ;if updated clear screen
	 mov a, Change_flag
    cjne a,#0x00,skip_change
    WriteCommand(#0x01)
    ;Wait for clear screen command to finish. Usually takes 1.52ms.
    Wait_Milli_Seconds(#5) ;wait 5ms
    mov Change_flag,#0x01
skip_change:
    ;mov a,Var_temp
    ;da a
    ;mov Var_temp,a
    ;display what state it is in
    Set_Cursor(1,1)
    Send_Constant_string(#message_intro)
    ;Display_BCD(temp)
    mov a, FSM_state
    Set_Cursor(2,1)
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
    ret

Send_BCD mac
    push ar0
    mov r0, %0
    lcall ?Send_BCD
    pop ar0
    endmac
?Send_BCD:
push acc; Write most significant digit
    mov a, r0
    swap a
    anl a, #0fh
    orl a, #30h
    lcall putchar; write least significant digit
    mov a, r0
    anl a, #0fh
    orl a, #30h
    lcall putchar
    pop acc
    ret
; Send a constant-zero-terminated string using the serial port
SendString:
    clr A
    movc A, @A+DPTR
    jz SendStringDone
    lcall putchar
    inc DPTR
    sjmp SendString
SendStringDone:
    ret
end









