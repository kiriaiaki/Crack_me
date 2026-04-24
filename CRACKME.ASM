.model tiny
.code
org 100h

SAVE_REGS MACRO
	PUSH AX
	PUSH BX
	PUSH CX
	PUSH DX
	PUSH SI
	PUSH DI
	PUSH BP
	PUSH SP
	PUSH ES
	PUSH DS
	PUSHF
ENDM

RESTORE_REGS MACRO
	POPF
	POP DS
	POP ES
	POP SP
	POP BP
	POP DI
	POP SI
	POP DX
	POP CX
	POP BX
	POP AX
ENDM

Start:
	CALL Print_Window

	Try_Again:
		MOV AL, 8
		MOV AH, 7
		MOV SI, offset Password_Buffer
		CALL Input_Password
		JC Try_Again					; if CF = 1

	CALL Print_Answer

	CALL Restore_Screen

	MOV AX, 4C00h		; finish
	INT 21h




;--------------------------------------------------------------------
; Print_Answer - displays the result of password processing (success
;				 or incorrect password)
;
; Input:	none
;
; Output:	none
;--------------------------------------------------------------------

Print_Answer:

	SAVE_REGS

	MOV AH, 7
	MOV AL, 7
	MOV CX, 66
	MOV BX, 7020h
	CALL Print_Line

	ADD AL, 1
	CALL Print_Line


    MOV SI, OFFSET Password_Buffer
    MOV DI, OFFSET Correct_Password
    MOV CX, Len_Correct
	MOV DX, Len_Input

	CMP CX, DX
	JNE Incorrect_Password

	CLD
	REPE CMPSB						; DS:[SI] and ES:[DI], SI++ and DI++
    JE Correct_Password_User
	JMP Incorrect_Password

	Correct_Password_User:

		MOV CX, Len_Text_4
		MOV SI, offset Text_4
		CALL Record_String

		ADD AH, Len_Text_4
		INC AH
		CALL Calculate_Offset
		MOV ES:[DI], 7256h
		JMP Expectation_2


	Incorrect_Password:

		MOV CX, Len_Text_5
		MOV SI, offset Text_5
		CALL Record_String

		ADD AH, Len_Text_5
		INC AH
		CALL Calculate_Offset
		MOV ES:[DI], 7458h

	Expectation_2:
		MOV AH, 08h				; function take one click
		INT 21h					;
		CMP AL, 13				; comparison with "Enter"
		JNE Expectation_2		;

	RESTORE_REGS

	RET




;--------------------------------------------------------------------
; Input_Password - displaying the password on the screen
;
; Input:	AL = line (0-24)
;			AH = column (0-79)
;			DS:[SI] = address begin buffer for pasword in memory
;
; Output:	CF = 0 - success
;			CF = 1 - try again
;--------------------------------------------------------------------

Input_Password:

	SAVE_REGS

	CALL Calculate_Offset      ; ES:[DI] position for input

    XOR BP, BP                 ; counter
    MOV BX, 66                 ; max len

	Process_Symbol:

		CMP BP, BX                 	; if max len
		JE Not_Print_Pointer

		MOV ES:[DI], 0B05Fh

		Not_Print_Pointer:

		MOV AH, 00h
		INT 16h                    	; AL = symbol, AH = key scan code

		CMP AL, 0Dh                	; if enter
		JE Finish_Input_Password

		CMP AL, 08h                	; if delete
		JE Delete

		CMP BP, BX                 	; if max len
		JE Error_Len

		MOV BYTE PTR DS:[SI + BP], AL	; saved symbol in buffer
		INC BP

		MOV AH, 30h
		STOSW						; ES:[DI] = AX, DI += 2
		JMP Process_Symbol

		Delete:

			CMP BP, 0
			JE Process_Symbol

			DEC BP

			SUB DI, 2
			MOV AX, 3020h
			STOSW					; ES:[DI] = AX, DI += 2
			STOSW

			SUB DI, 4

			JMP Process_Symbol

	Error_Len:

		MOV AH, 7
		MOV AL, 7
		MOV CX, 66
		MOV BX, 7020h
		CALL Print_Line

		ADD AL, 1
		CALL Print_Line

		MOV CX, Len_Text_3
		MOV SI, offset Text_3
		CALL Record_String

		Expectation_1:
			MOV AH, 08h				; function take one click
			INT 21h					;
			CMP AL, 13				; comparison with "Enter"
			JNE Expectation_1		;


		MOV AH, 7
		MOV AL, 7
		MOV CX, Len_Text_2
		MOV SI, offset Text_2
		CALL Record_String

		ADD AL, 1
		MOV CX, 66
		MOV BX, 3020h
		CALL Print_Line

		RESTORE_REGS

		STC

		RET

	Finish_Input_Password:

		MOV Len_Input, BP

		RESTORE_REGS

		CLC

		RET




;--------------------------------------------------------------------
; Record_String - prints string to the screen
;
; Input:   AL = line (0-24)
;          AH = column (0-79)
;          CX = lenght string
;		   SI =	address begin string in memory
;
; Output:  none
;--------------------------------------------------------------------

Record_String:

	JCXZ Finish_Record_String

	SAVE_REGS

	CALL Calculate_Offset

	Passage_Symbol:

		LODSB					; AL = DS:[SI], SI++

		MOV AH, 70h

		STOSW                	; ES:[DI] = AX, DI += 2

		LOOP Passage_Symbol


	RESTORE_REGS

	Finish_Record_String:

	RET




;--------------------------------------------------------------------
; Print_Window - draws a filled turquoise rectangle with a white
;                double border and two compartments
;
; Input:   none
;
; Output:  none
;--------------------------------------------------------------------

Print_Window:

	SAVE_REGS

	MOV BX, 7020h         	; BX = attribute + symbol (white on light blue space)

	MOV AL, 5				; number line
    MOV DX, 6				; vertical length

	MOV CX, 74				; horizontal lenght
    MOV AH, 3              	;

    CALL Print_Rectangle


	ADD AL, 1
	ADD AH, 2
	SUB CX, 4
	SUB DX, 2
	CALL Print_Frame

	ADD AH, 28
	MOV CX, Len_Text_1
	MOV SI, offset Text_1
	CALL Record_String

	SUB AH, 26
	ADD AL, 1
	MOV CX, Len_Text_2
	MOV SI, offset Text_2
	CALL Record_String

	ADD AL, 1
	MOV CX, 66
	MOV BX, 3020h
	CALL Print_Line

	RESTORE_REGS

	RET




;--------------------------------------------------------------------
; Print_Rectangle - draws a rectangle of symbol, saves old values ​​and
;					offsets cells in Array_Values and Array_Offsets
;
; Input:   AL = line (0-24)
;          AH = column (0-79)
;          BX = word (BH = attribute, BL = symbol)
;          CX = horizontal length (from 0 to 80-AL)
;          DX = vertical length (from 0 to 25-AH)
;
; Output:  none
;--------------------------------------------------------------------

Print_Rectangle:

	JCXZ Finish_Print_Rectangle

	CMP DX, 0
	JE Finish_Print_Rectangle

	SAVE_REGS

	CALL Calculate_Offset
	MOV AX, BX				; AX = attribute + symbol

	Repeat_New_Line:

		PUSH CX

		Saved_Record_Symbol_Line:

			MOV SI, CS:Saved_Counter
			SHL SI, 1

			MOV CS:Array_Offsets[SI], DI

			MOV BX, ES:[DI]
			MOV CS:Array_Values[SI], BX

			INC CS:Saved_Counter

			MOV ES:[DI], AX
			ADD DI, 2

			LOOP Saved_Record_Symbol_Line

		POP CX

		ADD DI, 160			; new line

		SUB DI, CX			;
		SUB DI, CX			; move start

		DEC DX
		CMP DX, 0
		JNE Repeat_New_Line

	RESTORE_REGS

	Finish_Print_Rectangle:

		RET




;--------------------------------------------------------------------
; Print_Frame - draws a rectangular two-lane frame
;
; Input:   AL = line (0-24)
;          AH = column (0-79)
;          BH = attribute
;          CX = horizontal length (from 0 to 80-AL)
;          DX = vertical length (from 0 to 25-AH)
;
; Output:  none
;--------------------------------------------------------------------

Print_Frame:

	JCXZ Finish_Print_Frame

	CMP DX, 0
	JE Finish_Print_Frame

	SAVE_REGS

	MOV BL, 0CDh
	CALL Print_Line

	ADD AL, DL
	SUB AL, 1
	CALL Print_Line

	MOV BL, 0BAh
	SUB AL, DL
	ADD AL, 1
	XCHG CX, DX
	CALL Print_Column

	ADD AH, DL
	SUB AH, 1
	CALL Print_Column
	SUB AH, DL
	ADD AH, 1
	XCHG CX, DX

	CALL Calculate_Offset
	MOV BL, 0C9h
	MOV ES:[DI], BX

	ADD DI, CX
	ADD DI, CX
	SUB DI, 2
	MOV BL, 0BBh
	MOV ES:[DI], BX

	ADD AL, DL
	DEC AL
	CALL Calculate_Offset
	MOV BL, 0C8h
	MOV ES:[DI], BX

	ADD DI, CX
	ADD DI, CX
	SUB DI, 2
	MOV BL, 0BCh
	MOV ES:[DI], BX

	RESTORE_REGS

	Finish_Print_Frame:

		RET




;--------------------------------------------------------------------
; Print_Column - draws a vertical column of symbol
;
; Input:   AL = line (0-24)
;          AH = column (0-79)
;          BX = word (BH = attribute, BL = symbol)
;          CX = vertical length (from 0 to 25-AH)
;
; Output:  none
;--------------------------------------------------------------------

Print_Column:

	JCXZ Finish_Print_Column

	SAVE_REGS

	CALL Calculate_Offset
	MOV AX, BX				; AX = attribute + symbol

	Record_Symbol_Column:

		MOV ES:[DI], AX
		ADD DI, 160

		LOOP Record_Symbol_Column

	RESTORE_REGS

	Finish_Print_Column:

		RET




;--------------------------------------------------------------------
; Print_Line - draws a horizontal line of symbol
;
; Input:   AL = line (0-24)
;          AH = column (0-79)
;          BX = word (BH = attribute, BL = symbol)
;          CX = horizontal lenght (from 0 to 80-AL)
;
; Output:  none
;--------------------------------------------------------------------

Print_Line:

	JCXZ Finish_Print_Line

	SAVE_REGS

	CALL Calculate_Offset
	MOV AX, BX				; AX = attribute + symbol

	CLD 					; DF = 0 (right)
	REP STOSW				; AX in ES:[DI] and DI+=2

	RESTORE_REGS

	Finish_Print_Line:

		RET




;--------------------------------------------------------------------
; Restore_Screen - restores all saved screen cells from Array_Values
;                  and Array_Offsets
;
; Input:   AL = line (0-24)
;          AH = column (0-79)
;          BX = word (BH = attribute, BL = symbol)
;          CX = length line (from 0 to 80-AL)
;
; Output:  none
;--------------------------------------------------------------------

Restore_Screen:

    SAVE_REGS

	MOV CX, CS:Saved_Counter
    JCXZ Finish_Restore_Screen

    MOV AX, 0B800h
    MOV ES, AX
	XOR SI, SI

	Record_Saved_Symbol:

		MOV BX, CS:Array_Offsets[SI]	; offset
		MOV AX, CS:Array_Values[SI]	; word
		MOV ES:[BX], AX
		ADD SI, 2

		LOOP Record_Saved_Symbol

	Finish_Restore_Screen:

		RESTORE_REGS

		RET




;--------------------------------------------------------------------
; Calculate_Offset - computes byte offset in video memory and sets ES
;
; Input:   AL = line (0-24)
;          AH = column (0-79)
;
;
; Output:  ES = B800
;          DI = 80 * line + column
;--------------------------------------------------------------------

Calculate_Offset:

	PUSH AX
	PUSH CX
	PUSH DX
	PUSHF

	MOV DL, AH				;
	XOR DH, DH				; DX = 00DL

	MOV CL, 80				; CL = 80
	MUL CL					; AX = AL * CL

	ADD AX, DX				; AX = 80 * line + column
	SHL AX, 1				; AX *= 2

	MOV DI, AX				; DI = position

	MOV AX, 0B800h			;
	MOV ES, AX				; ES = B800

	POPF
	POP DX
	POP CX
	POP AX

	RET




Data:
	Array_Offsets dw 4000 dup (0)		;
	Array_Values  dw 4000 dup (0)
	Saved_Counter dw 0

	Correct_Password db '123454321'
	Len_Correct      equ $ - Correct_Password

	Text_1     db 'Password check'
	Len_Text_1 equ $ - Text_1
	Text_2     db 'Enter password please:'
	Len_Text_2 equ $ - Text_2
	Text_3     db 'Password is too long, please try again (press Enter)'
	Len_Text_3 equ $ - Text_3
	Text_4     db 'Access granted'
	Len_Text_4 equ $ - Text_4
	Text_5     db 'Access denied'
	Len_Text_5 equ $ - Text_5

	Password_Buffer db 66 dup (0)
	Len_Input       dw 0




end Start

