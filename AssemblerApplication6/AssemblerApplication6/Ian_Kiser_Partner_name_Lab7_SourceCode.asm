
;***********************************************************
;*
;*	This is the TRANSMIT skeleton file for Lab 7 of ECE 375
;*
;*  	Rock Paper Scissors
;* 	Requirement:
;* 	1. USART1 communication
;* 	2. Timer/counter1 Normal mode to create a 1.5-sec delay
;***********************************************************
;*
;*	 Author: Ian Kiser, Evan Something
;*	   Date: 12/6/2024
;*
;***********************************************************

.include "m32U4def.inc"         ; Include definition file

;***********************************************************
;*  Internal Register Definitions and Constants
;***********************************************************
.def    mpr = r16               ; Multi-Purpose Register		
;r20-r22 reserved


; Use this signal code between two boards for their game ready
.equ    SendReady = 0b11111111

;***********************************************************
;*  Start of Code Segment
;***********************************************************
.cseg                           ; Beginning of code segment

;***********************************************************
;*  Interrupt Vectors
;***********************************************************
.org    $0000                   ; Beginning of IVs
	    rjmp    INIT            	; Reset interrupt


.org    $0056                   ; End of Interrupt Vectors

;***********************************************************
;*  Program Initialization
;***********************************************************
INIT:
	;Stack Pointer (VERY IMPORTANT!!!!)
	ldi mpr, low(RAMEND) ;retrieve ramend low from program memory
	out SPL, mpr ;load ramend low into stack pointer low via mpr, out is needed as SP(stack pointer) is in io mem
	ldi mpr, high(RAMEND);retrieve ramend high from program memory
	out SPH, mpr ;load ramend high into stack pointer low via mpr
	;I/O Ports

	;USART1
		;Set baudrate at 2400bps
		;Enable receiver and transmitter
		;Set frame format: 8 data bits, 2 stop bits

	;TIMER/COUNTER1
	;Set Normal mode

	;Other
	rcall LCDInit
	rcall LCDBacklightOn 
	rcall LCDClr



;***********************************************************
;*  Main Program
;***********************************************************
MAIN:
ldi ZL, low(str_rock<<1)
ldi ZH, high(str_rock<<1)
ldi YL, low(str_rock_end<<1)
ldi YH, high(str_rock_end<<1)
rcall print_zy_top

ldi ZL, low(str_paper<<1)
ldi ZH, high(str_paper<<1)
ldi YL, low(str_paper_end<<1)
ldi YH, high(str_paper_end<<1)
rcall print_zy_top



end_main:
		rjmp end_main

;***********************************************************
;*	Functions and Subroutines
;***********************************************************


;***********************************************************
;*	Func: print_zy_top
;*	desc: stores string stored in program memory and writes it to the top line of the LCD screen
;*	REMEMBER: the address stored in z and in y must be initially bit shifted by 1 due to least sig bit being low or high indicator. 
;*	WARNING - assumes Z stores the address of the beginning of the string and Y stores the end of the string to print.
;***********************************************************
print_zy_top:
push mpr
push XL
push XH
push ZL
push ZH
push YL
push YH

rcall	LCDClrLn1 ;clear line to be writen to
ldi XL, LOW(lcd_buffer_addr) ;point X to the top line of the LCD buffer address in data memory
ldi XH, HIGH(lcd_buffer_addr)

print_zy_top_loop:
lpm mpr, Z+ ;load value stored at the address to the beginning of the string (stored in X) to mpr, then inc X to point to next char. ie. first character of string is loaded into mpr
st X+, mpr ;Store that character to the beginning of the LCD buffer, then increment to next spot in LCD buffer

cp ZL, YL  ;compare where Z points (current address) to Y (end of string), we only need Low byte since start and end are definitely far enough away to cause roll over errors
brne print_zy_top_loop ;if not at end keep loading LCD buffer

rcall LCDWrite ;once done write to LCD

pop YH
pop YL
pop ZH
pop ZL
pop XH
pop XL 
pop mpr
ret

;***********************************************************
;*	Func: print_zy_bottom
;*	desc: stores string stored in program memory and writes it to the top line of the LCD screen
;*	REMEMBER: the address stored in z and in y must be initially bit shifted by 1 due to least sig bit being low or high indicator. 
;*	WARNING - assumes Z stores the address of the beginning of the string and Y stores the end of the string to print.
;***********************************************************
print_zy_bottom:
push mpr
push XL
push XH
push ZL
push ZH
push YL
push YH

rcall	LCDClrLn2 ;clear line to be writen to
ldi XL, LOW(lcd_buffer_addr+16) ;point x to the bottom line of the LCD buffer address in data memory
ldi XH, HIGH(lcd_buffer_addr+16)

print_zy_bottom_loop:
lpm mpr, Z+ ;load value stored at the address to the beginning of the string (stored in X) to mpr, then inc X to point to next char. ie. first character of string is loaded into mpr
st X+, mpr ;Store that character to the beginning of the LCD buffer, then increment to next spot in LCD buffer

cp ZL, YL ;compare where Z points (current address) to Y (end of string), we only need Low byte since start and end are definitely far enough away to cause roll over errors
brne print_zy_bottom_loop ;if not at end keep loading LCD buffer

rcall LCDWrite ;once done write to LCD 

pop YH
pop YL
pop ZH
pop ZL
pop XH
pop XL 
pop mpr
ret

;***********************************************************
;*	Stored Program Data
;***********************************************************

;-----------------------------------------------------------
; An example of storing a string. Note the labels before and
; after the .DB directive; these can help to access the data
;-----------------------------------------------------------
str_rock:
    .DB		"Rock"		
str_rock_end:

str_paper:
.db "paper "
str_paper_end:

str_scissors:
.db "scissors"
str_scissors_end:

str_lose:
.db "You Lose"
str_lose_end:

str_win:
.db "You Win!"
str_win_end:

str_welcome1:
.db "welcome "
str_welcome1_end:

str_welcome2:
.db "Please Press PD7"
str_welcome2_end:

str_start1:
.db "Ready, Waiting"
str_start1_end:

str_start2:
.db "for the opponent"
str_start2_end:

str_game:
.db "Game Start"
str_game_end:




;***********************************************************
;*	Additional Program Includes
;***********************************************************
.include "LCDDriver.asm"		; Include the LCD Driver


