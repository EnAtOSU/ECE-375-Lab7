
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
.def    mpr = r16    ; Multi-Purpose Register		
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

.org		$0002 ;int 0, will be tied to PD4
		;select choice left
		reti

.org		$0004 ;int 1, might be tied to PD5, for extra credit
		;select choice right
		reti

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
	;port D -> input for button presses, 
	;port B -> PORTB[4:7] output for LED countdown/timer counter, PB[0:2] used by LCD driver
	ldi mpr, $FF
	out DDRB, mpr; set PORTB for output 



	;USART1
	;Set baudrate at 2400bps -> I believe system clock is 8MHz, therefore UBRR gets either 207 or 416 depending on U2Xn by table 18-4 in data sheet
	;Enable receiver and transmitter
	;Set frame format: 8 data bits, 2 stop bits




	;TIMER/COUNTER1
	;Set Normal mode
	;No need for external pin interrupts -> all OC bits set low, Normal mode -> WGM bits low as well
	;TCCR1A gets 0b00000000, This is initial value by default, no need to load
	;no ICN stabilization, normal mode, and 1/256 prescaling -> TOV flag set about every 1.5 seconds when TCNT initially gets 48E4
	;TCCR1B gets 0b00000010
	ldi mpr, 0b00000000
	sts TCCR1A, mpr
	ldi mpr, 0b00000100
	sts TCCR1B, mpr


	

	;Other
	rcall LCDInit
	rcall LCDBacklightOn 
	rcall LCDClr
	sei


;***********************************************************
;*  Main Program
;***********************************************************
MAIN:

;launch to welcome screen, poll for PD7
;loop until PD7 pressed

;PD7 pressed
;ready transmit
;display ready and waiting screen

;ready recieved
;start LED timer
;display game start

;enable int 0 (and possibly int 1 if extra credit) in interrupt mask
;PD4 selects play option via interrupt

;timer ends
;disable int 0 (and possibly int 1 if extra credit) in interrupt mask
;display choices
;timer start again

;timer ends
;display win/lose screen
;timer start again

;timer ends
;restart code





end_main:

rjmp end_main

;***********************************************************
;*	Functions and Subroutines
;***********************************************************



;***********************************************************
;*	Func: led_countdown
;*	desc: counts down 6 seconds and displays on led's
;***********************************************************
led_countdown:
push mpr

in mpr, PORTB
ori mpr, 0b11110000
out PORTB, mpr ;all led's are now set

rcall timer_1_5 ;wait
cbi PORTB, 4 ;clear bit 4
rcall timer_1_5 ;repeat for other bits
cbi PORTB, 5
rcall timer_1_5
cbi PORTB, 6
rcall timer_1_5
cbi PORTB, 7

pop mpr
ret
;end led_countdown

;***********************************************************
;*	Func: timer_1_5
;*	desc: polls timer counter 1 for a 1.5 second timer
;***********************************************************
timer_1_5:
;push stuff to stack
push mpr



ldi mpr, $48
sts TCNT1H, mpr
ldi mpr, $E4
sts TCNT1L, mpr

timer_1_5_NoFlag:
sbis TIFR1, 0 ;skip loop if TOV1 is set
rjmp timer_1_5_NoFlag

sbi TIFR1, 0 ;reset TOV1

;pop stuff from stack

pop mpr
ret
;end timer_1_5


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

rcall	LCDWrLn1 ;once done write to LCD

pop YH
pop YL
pop ZH
pop ZL
pop XH
pop XL 
pop mpr
ret
;end print_zy_bottom




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

rcall	LCDWrLn2 ;once done write to LCD 

pop YH
pop YL
pop ZH
pop ZL
pop XH
pop XL 
pop mpr
ret
;end print_zy_bottom


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

str_draw:
.db "You Draw! "
str_draw_end:

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


