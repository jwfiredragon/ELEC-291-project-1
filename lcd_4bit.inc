; dseg
; bcd: ds 1 ;set bcd as 1 byte variable
; bseg
; Change_flag:ds 1;1= updated,0=not udapted
; cseg
cseg

DisplayEdit:
    WriteCommand(#0x01)
    Wait_Milli_Seconds(#5)
    mov a, Val_to_set
    cjne a, #0, next_edit1
    mov a, Temp_soak
    da a
    mov bcd, a
    Set_Cursor(1,1)
    Send_Constant_String(#tempsoak_message)
    Set_Cursor(2,1)
    lcall LCD_3BCD
    ljmp end_edit
next_edit1:
    cjne a, #1, next_edit2
    mov a, Time_soak
    da a
    mov bcd, a
    Set_Cursor(1,1)
    Send_Constant_String(#timesoak_message)
    Set_Cursor(2,1)
    lcall LCD_3BCD
    ljmp end_edit
next_edit2:
    cjne a, #2, next_edit3
    mov a, Temp_peak
    da a
    mov bcd, a
    Set_Cursor(1,1)
    Send_Constant_String(#temppeak_message)
    Set_Cursor(2,1)
    lcall LCD_3BCD
    ljmp end_edit
next_edit3:
    cjne a, #3, next_edit4
    mov a, Time_peak
    da a
    mov bcd, a
    Set_Cursor(1,1)
    Send_Constant_String(#timepeak_message)
    Set_Cursor(2,1)
    lcall LCD_3BCD
    ljmp end_edit
next_edit4:
    cjne a, #4, end_edit
    mov a, Temp_cool
    da a
    mov bcd, a
    Set_Cursor(1,1)
    Send_Constant_String(#tempcool_message)
    Set_Cursor(2,1)
    lcall LCD_3BCD
end_edit:
    ret

Regular_display:    ;if updated clear screen
    WriteCommand(#0x01)
    ;Wait for clear screen command to finish. Usually takes 1.52ms.
    Wait_Milli_Seconds(#5) ;wait 5ms
	mov a, Change_flag
    cjne a,#0x00,skip_change
    mov Change_flag,#0x01
skip_change:
    ;mov a,Var_temp
    ;da a
    ;mov Var_temp,a
    ;display what state it is in
    Set_Cursor(1,1)
    Send_Constant_string(#temp_message)
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









