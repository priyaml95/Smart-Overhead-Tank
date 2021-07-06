#make_bin#

; BIN is plain binary format similar to .com format, but not limited to 1 segment;
; All values between # are directives, these values are saved into a separate .binf file.
; Before loading .bin file emulator reads .binf file with the same file name.

; All directives are optional, if you don't need them, delete them.

; set loading address, .bin file will be loaded to this address:
#LOAD_SEGMENT=0000h#
#LOAD_OFFSET=0000h#

; set entry point:
#CS=0000h#	; same as loading segment
#IP=0000h#	; same as loading offset

; set segment registers
#DS=0000h#	; same as loading segment
#ES=0000h#	; same as loading segment

; set stack
#SS=0000h#	; same as loading segment
#SP=FFFEh#	; set to top of loading segment

; set general registers (optional)
#AX=0000h#
#BX=0000h#
#CX=0000h#
#DX=0000h#
#SI=0000h#
#DI=0000h#
#BP=0000h#	

;proteus allows you to change the reset address - hence changing it to 00000H - so every time 
;system is reset it will go and execute the instruction at address 00000H - which is jmp st1
	JMP ST1

; JMP STL - 3 bytes
; We are not using INT 00 - 31H, so we fill the next 253 bytes with '0'
	DB 253 DUP(0)

; 40H (Minute Interrupt) ; Address : 40*4 = 0100H
	DW ISR_INT_HOUR
	DW 0000

; We are not using INT 41H, so we fill the next 4 bytes with '0'
	DB 4 DUP(0)

; 42H (Sensor Interrupt) ; Address : 42*4 = 0108H
	DW ISR_L2_S
	DW 0000

; 43H (Sensor Interrupt) ; Address : 43*4 = 010CH
	DW ISR_L3_S
	DW 0000

; 44H (Sensor Interrupt) ; Address : 44*4 = 0110H
	DW ISR_L1_S_NOT
	DW 0000

; 45H (Sensor Interrupt) ; Address : 45*4 = 0114H
	DW ISR_L2_S_NOT
	DW 0000

; 46H (Sensor Interrupt) ; Address : 46*4 = 0118H
	DW ISR_L3_S_NOT
	DW 0000

; We are not using INT 47 - FFH, so we fill the next 740 bytes with '0'
	DB 740 DUP(0)


; Main Program
ST1:      CLI

	; Initialize DS, ES, SS to start of RAM
          MOV       AX, 0200h
          MOV       DS, AX
          MOV       ES, AX
          MOV       SS, AX
          MOV       SP, 0FFFEH
          MOV       SI, 0000 
	
	; 8255
	PORTA 		EQU		00H
	PORTB 		EQU		02H
	PORTC		EQU		04H
	C_REG_8255	EQU		06H	

	; 8253
	COUNT0 		EQU		08H
	COUNT1 		EQU		0AH
	COUNT2 		EQU		0CH
	C_REG_8253	EQU		0EH	

	; 8259
	ADD_8259_0	EQU		10H
	ADD_8259_1	EQU		12H

          
; Initialize Port A as input and Port B, C as output
          MOV       AL, 10011010B
          OUT       C_REG_8255, AL

; Initialize Counter 1 and 2 of Timer (Mode 2)
; Timing Signal for 1 Minute (1/60 Hz)
		  
		  MOV AL, 00110100B ; Counter 0
		  OUT C_REG_8253, AL

		  MOV AL, 01110100B ; Counter 1
		  OUT C_REG_8253, AL
		  
		  MOV AL, 10010100B ; Counter 1
		  OUT C_REG_8253, AL
		  
		  MOV AL, 0A8H		; Count = 25000 (61A8H)
		  OUT COUNT0, AL
		  MOV AL, 61h
		  OUT COUNT0, AL
		  
		  MOV AL, 70h		; Count = 6000 (1770H)
		  OUT COUNT1, AL
		  MOV AL, 17h
		  OUT COUNT1, AL

		  MOV AL, 3Ch		; Count = 60 (3CH)
		  OUT COUNT2, AL

; Initialize 8259 (Vector No: 40H, Edge Triggered, No slave, Disable AEOI, Disable IR7)
		  
		  MOV AL, 00010011B		; ICW 1
		  OUT ADD_8259_0, AL

		  MOV AL, 01000000B		; ICW 2
		  OUT ADD_8259_1, AL

		  MOV AL, 00000011B		; ICW 4
		  OUT ADD_8259_1, AL

		  MOV AL, 10000010B		; OCW 1
		  OUT ADD_8259_1, AL

		  STI

; Initializing variables in RAM

		  HOUR 		EQU 	000H
		  MOV 		AL, 00h
		  MOV 		HOUR, AL
		  
		  LEVEL1 	EQU 	0001H
		  MOV 		AL, 7		; Sensor 1, 2, 3 HIGH
		  MOV 		LEVEL1, AL
		  
		  LEVEL2 	EQU 	0002H
		  MOV 		AL, 6		; Sensor 2, 3 HIGH
		  MOV 		LEVEL2, AL
		  
		  LEVEL3 	EQU 	0003H
		  MOV 		AL, 4		; Sensor 3 HIGH
		  MOV 		LEVEL3, AL

		  P_LEVEL 	EQU 	0004H
		  MOV 		AL, 4		; Previous water level
		  MOV 		P_LEVEL, AL

		  C_LEVEL 	EQU 	0005H
		  MOV 		AL, 4		; Current water level
		  MOV 		C_LEVEL, AL
		  
; Infinite Loop (Waiting for Interrupts...)
INFI:	  JMP INFI


; Interrupt Service Routines
ISR_INT_HOUR:	

			STI
			
			MOV BL, C_LEVEL
			MOV P_LEVEL, BL		; Set Previous Level

			MOV CL, HOUR
			INC CL			; Increment Hour

			CMP CL, 24		; Check for 12 midnight
			JNE HR_5
		
			MOV CL, 00		; 12 midnight

		HR_5:	
			MOV HOUR, CL	; Setting current Hour

			CMP CL, 05
			JGE HR_6

			MOV CH, LEVEL3	; 12 Midnight - 5 AM
			JMP SENSOR_I
		HR_6:
			CMP CL, 06
			JGE HR_10

			MOV CH, LEVEL2 	; 5 AM - 6 AM
			JMP SENSOR_I
		HR_10:
			CMP CL, 10
			JGE HR_17

			MOV CH, LEVEL1 	; 6 AM - 10 AM
			JMP SENSOR_I
		HR_17:
			CMP CL, 17
			JGE HR_19

			MOV CH, LEVEL2 	; 10 AM - 5 PM
			JMP SENSOR_I
		HR_19:
			CMP CL, 19
			JGE HR_00

			MOV CH, LEVEL1 	; 5 PM - 7 PM
			JMP SENSOR_I
		HR_00:
			MOV CH, LEVEL2 	; 7 PM - 12 Midnight

		SENSOR_I:

			MOV C_LEVEL, CH		; Set Current Level

			CMP BL, CH		; Comparing previous and current level
			JG VALVE_OPEN

			IN  AL, PORTC		; Getting PC 4, 5 & 6
			AND AL, 01110000B
			MOV CL, 4
			ROR AL, CL
			
			CMP AL, CH		; Comparing sensor input with current level
			JL MOTOR_ON

			IRET
			
		VALVE_OPEN:	
			MOV AL, 00000100B	; Open the valve
			OUT C_REG_8255, AL

			IRET
			
		MOTOR_ON:	
			MOV AL, 00000011B	; Switch on the Motor
			OUT C_REG_8255, AL

			IRET

ISR_L1_S_NOT:
			STI
			
			MOV AL, 00000010B	; Switch off the Motor
			OUT C_REG_8255, AL

			IRET

ISR_L2_S:
			STI
			
			MOV CL, P_LEVEL
			MOV CH, LEVEL1

			CMP CL, CH
			JNE NO_CLOSE_1

			MOV AL, 00000101B	; Close the valve
			OUT C_REG_8255, AL
		
		NO_CLOSE_1:	

			IRET

ISR_L2_S_NOT:
			STI
			
			MOV CL, C_LEVEL
			MOV CH, LEVEL2

			CMP CL, CH
			JNE NO_CLOSE_2

			MOV AL, 00000010B	; Switch off the Motor
			OUT C_REG_8255, AL
		
		NO_CLOSE_2:	

			IRET

ISR_L3_S:
			STI
			
			MOV CL, P_LEVEL
			MOV CH, LEVEL2

			CMP CL, CH
			JNE NO_CLOSE_3

			MOV AL, 00000101B	; Close the valve
			OUT C_REG_8255, AL
		
		NO_CLOSE_3:	

			IRET

ISR_L3_S_NOT:
			STI
			
			MOV CL, C_LEVEL
			MOV CH, LEVEL3

			CMP CL, CH
			JNE NO_CLOSE_4

			MOV AL, 00000010B	; Switch off the Motor
			OUT C_REG_8255, AL
		
		NO_CLOSE_4:	

			IRET