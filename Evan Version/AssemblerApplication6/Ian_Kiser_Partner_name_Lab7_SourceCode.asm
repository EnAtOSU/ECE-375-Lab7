
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
;*	 Author: Ian Kiser, Evan Shishido
;*	   Date: 12/6/2024
;*
;***********************************************************

.include "m32U4def.inc"         ; Include definition file

;***********************************************************
;*  Internal Register Definitions and Constants
;***********************************************************
.def    mpr = r16    ; Multi-Purpose Register		
.def	choice_left = r17
.def	choice_right = r18 ;makes sense to store choice values seperately from LCD because it will be easier to send between boards and interract with LCD
.def	data = r19

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

.org		$0002 ;int 0, will be tied to PD4, interrupts will need EIMSK, and EICRA/B registers set correctly
		rjmp select_choice_left
		reti

.org		$0004 ;int 1, might be tied to PD5, for extra credit
		;select choice right
		reti

.org	$0032 ; recieve flag interrupt
rcall recieve
reti
;.org read interrupt vector on usart 1

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
	ldi mpr, 0
	out DDRD, mpr ;set portD for input
	ldi mpr, $FF
	out PORTD, mpr ;set pull up resistors

	;port B -> PORTB[4:7] output for LED countdown/timer counter, PB[0:2] used by LCD driver
	ldi mpr, $FF
	out DDRB, mpr; set PORTB for output 

	;configure external interrupts to trigger on falling edge ie button pressed, pin shorted to ground, for int0 and int1
	;EICRA gets 0b00001010
	ldi mpr, 0b00000010
	sts EICRA, mpr
	ldi mpr, 0b00000001 ; enable int0 
	sts EIMSK, mpr



	;USART1
	;Set baudrate at 2400bps -> I believe system clock is 8MHz, therefore UBRR gets 207 by table 18-4 in data sheet
	;Enable receiver and transmitter
	;Set frame format: 8 data bits, 2 stop bits
	;do not use SBI and CBI, and sbis sbic because of fifo 

	;UCSR1A: bit 7 RXC1(recieve complete) -> 0, bit 6 TXC1 (transmit complete) -> 0, bit 5 UDRE1 (data reg empty) -> 1, error bits[4:2] -> 0
	; bit 1 U2X1 (double transmit speed) -> 0 for normal speed, bit 0 MPCM1 (multi processor communication) -> 0 (do not want to send address info)

	;UCSR1B: bit 7 RXCIE1 (RX complete interrupt enable) -> set for interrupt, bit 6 TXCIE1 (TX interrupt) -> set for interrupt, bit 5 UDRIE1 (interrupt for UDRE1 flag) -> set for interrupt
	;bit 4 RXEN1 (reciever enable) -> 1, bit 3 TXEN1 (transmit enable) -> 1, bit 2 UCSZ12 (character size) -> 0 for 8 bit characters, bits[1:0] RX/TX 81 (recieve and transmit data bit 8) -> 0 I think since frams will be 8 bit  
	
	;UCSR1C: bits [7:6] UMSEL1 1/0 (usart mode select) -> 00 for asychronous, UPM1 1/0 (parit mode) -> 00 for disabled, bit 3 USBS1 (stop bit select) -> 1 for 2 bit, bits [2:1] UCSZ1 [1:0] (character size) -> 11 for 8 bit,
	; bit 0 UCPOL1 (clock polarity) -> 0 for falling edge

	;UCSR1D: might need to set bits 1:0 but probably not, they control something called transmission and reception flow control

	;UCSR1A need not be loaded
	;UCSR1B gets 0b10011000 -> enable read interrupt
	;UCSR1C gets 0b00001110
	;UBRRH1 gets 0b00000000
	;UBRRL1 gets $CF -> 207


	ldi mpr, 0b10011000 ; enable read interrupt
	sts UCSR1B, mpr
	ldi mpr, 0b00001110
	sts UCSR1C, mpr

	ldi mpr, 0
	sts UBRR1H, mpr
	ldi mpr, $CF
	sts UBRR1L, mpr


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
	ldi choice_left, 0
	ldi choice_right, 0
	ldi data, 0

	sei


;***********************************************************
;*  Main Program
;***********************************************************
MAIN:
sei

;testing
;call welcome
rcall welcome
; Sends message to lcd waiting for oppenent.

;mpr means somethig past here
transmit_loop:
ldi mpr, SendReady ; loads mp
rcall transmit	   ; transmits
cpi data, SendReady	; compares
brne transmit_loop  ; if not equal loop
; data has been transmitted and received.

; Game start
Game_Start:
ldi ZL, low(str_game<<1)
ldi ZH, high(str_game<<1)
ldi YL, low(str_game_end<<1)
ldi YH, high(str_game_end<<1)
rcall print_zy_top
; Game Start printed on top line.
rcall Choice_Function		; interrupt isnt working maybe cuz not wired together.

; Print Results
rcall Print_Results

; Calculate Results
rcall Calculate_Results


;***********************************************************
;*	Functions and Subroutines
;***********************************************************
;***********************************************************
;*	Func: Print_Results
;*	desc: print results of game
;***********************************************************
Print_Results:
push mpr
push ZH
push ZL
push YH
push YL

; check what opponent chose
Opp_Choice:
cpi data, 1
breq Opp_Rock
cpi data, 2 
breq Opp_Paper
cpi data, 3
breq Opp_Scissors

Opp_Rock:
ldi ZL, low(str_rock<<1)
ldi ZH, high(str_rock<<1)
ldi YL, low(str_rock_end<<1)
ldi YH, high(str_rock_end<<1)
rcall print_zy_top
rjmp User_Choice

Opp_Paper:
ldi ZL, low(str_paper<<1)
ldi ZH, high(str_paper<<1)
ldi YL, low(str_paper_end<<1)
ldi YH, high(str_paper_end<<1)
rcall print_zy_top
rjmp User_Choice

Opp_Scissors:
ldi ZL, low(str_scissors<<1)
ldi ZH, high(str_scissors<<1)
ldi YL, low(str_scissors_end<<1)
ldi YH, high(str_scissors_end<<1)
rcall print_zy_top
rjmp User_Choice

User_Choice:
cpi choice_left, 1
breq User_Rock
cpi choice_left, 2
breq User_Paper
cpi choice_left, 3
breq User_Scissors

User_Rock:
ldi ZL, low(str_rock<<1)
ldi ZH, high(str_rock<<1)
ldi YL, low(str_rock_end<<1)
ldi YH, high(str_rock_end<<1)
rcall print_zy_bottom
rjmp Calculate_Results

User_Paper:
ldi ZL, low(str_paper<<1)
ldi ZH, high(str_paper<<1)
ldi YL, low(str_paper_end<<1)
ldi YH, high(str_paper_end<<1)
rcall print_zy_bottom
rjmp Calculate_Results

User_Scissors:
ldi ZL, low(str_scissors<<1)
ldi ZH, high(str_scissors<<1)
ldi YL, low(str_scissors_end<<1)
ldi YH, high(str_scissors_end<<1)
rcall print_zy_bottom
rjmp Calculate_Results

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Calculate_Results:
mov mpr, data
cp mpr, choice_left ; compare results
breq Display_Draw ; Draw

cpi mpr, 1
breq Opp_Chose_Rock
cpi mpr, 2 
breq Opp_Chose_Paper
cpi mpr, 3
breq Opp_Chose_Scissors

Opp_Chose_Rock:
cpi choice_left, 2
breq User_Win
cpi choice_left, 3
breq User_Lost

Opp_Chose_Paper
cpi choice_left, 1
breq User_Win
cpi choice_left, 3
breq User_Lost

Opp_Chose_Scissors
cpi choice_left, 1
breq User_Win
cpi choice_left, 2
breq User_Lost


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
User_Win:
ldi ZL, low(str_win<<1)
ldi ZH, high(str_win<<1)
ldi YL, low(str_win_end<<1)
ldi YH, high(str_win_end<<1)
rcall print_zy_top
cpi choice_left, 1
breq Chose_Rock
cpi choice_left, 2
breq Chose_Paper
cpi choice_left, 3
breq Chose_Scissors


User_Lost:
ldi ZL, low(str_lose<<1)
ldi ZH, high(str_lose<<1)
ldi YL, low(str_lose_end<<1)
ldi YH, high(str_lsoe_end<<1)
rcall print_zy_top
cpi choice_left, 1
breq Chose_Rock
cpi choice_left, 2
breq Chose_Paper
cpi choice_left, 3
breq Chose_Scissors

Display_Draw:
ldi ZL, low(str_draw<<1)
ldi ZH, high(str_draw<<1)
ldi YL, low(str_draw_end<<1)
ldi YH, high(str_draw_end<<1)
rcall print_zy_top
cpi choice_left, 1
breq Chose_Rock
cpi choice_left, 2
breq Chose_Paper
cpi choice_left, 3
breq Chose_Scissors

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Chose_Rock:
ldi ZL, low(str_rock<<1)
ldi ZH, high(str_rock<<1)
ldi YL, low(str_rock_end<<1)
ldi YH, high(str_rock_end<<1)
rcall print_zy_bottom
rjmp End_Print_Results

Chose_Paper:
ldi ZL, low(str_paper<<1)
ldi ZH, high(str_paper<<1)
ldi YL, low(str_paper_end<<1)
ldi YH, high(str_paper_end<<1)
rcall print_zy_bottom
rjmp End_Print_Results

Chose_Scissors:
ldi ZL, low(str_scissors<<1)
ldi ZH, high(str_scissors<<1)
ldi YL, low(str_scissors_end<<1)
ldi YH, high(str_scissors_end<<1)
rcall print_zy_bottom
rjmp End_Print_Results

End_Print_Results:
pop YL
pop YH
pop ZL
pop ZH
pop mpr
ret

;***********************************************************
;*	Func: Choice_Function
;*	desc: allow the user to scroll through different options.
;***********************************************************
Choice_Function:
push mpr

rcall led_countdown

pop mpr
ret

;***********************************************************
;*	Func: transmit
;*	desc: transmits mpr to UDR1
;***********************************************************
transmit:
push mpr
sts UDR1, mpr
rcall check_UDR1
pop mpr


ret

;***********************************************************
;*	Func: recieve
;*	desc: loads data register with usart reception value
;***********************************************************
recieve:
push mpr
in mpr, SREG
push mpr
lds data, UDR1
rcall check_UDR1

pop mpr
out SREG, mpr
pop mpr

ret

;***********************************************************
;*	Func: check_UDR1
;*	desc: returns once the UDR1 register has been cleared, uses 
;***********************************************************
check_UDR1:
push mpr

check_UDR1_not_clear:
lds mpr, UCSR1A
sbrs mpr, 5
brne check_UDR1_not_clear ;if data reg not empty wait for it to be empty

pop mpr
ret

;***********************************************************
;*	Func: welcome
;*	desc: display welcome screen and poll for PD7, exit when pressed and then released
;***********************************************************
welcome:
push mpr


ldi ZL, low(str_welcome1<<1)
ldi ZH, high(str_welcome1<<1)
ldi YL, low(str_welcome1_end<<1)
ldi YH, high(str_welcome1_end<<1)

rcall print_zy_top

ldi ZL, low(str_welcome2<<1)
ldi ZH, high(str_welcome2<<1)
ldi YL, low(str_welcome2_end<<1)
ldi YH, high(str_welcome2_end<<1)

rcall print_zy_bottom


welcome_not_pressed:
sbic PIND, PD7
rjmp welcome_not_pressed
;PD7 is now pressed
nop
nop ;avoid some debouncing
welcome_pressed:
sbis PIND, PD7
rjmp welcome_pressed
;PD7 is now released

rcall LCDClr

ldi ZL, low(str_start1<<1)
ldi ZH, high(str_start1<<1)
ldi YL, low(str_start1_end<<1)
ldi YH, high(str_start1_end<<1)
rcall print_zy_top

ldi ZL, low(str_start2<<1)
ldi ZH, high(str_start2<<1)
ldi YL, low(str_start2_end<<1)
ldi YH, high(str_start2_end<<1)
rcall print_zy_bottom

;rcall LCDClr

pop mpr
ret

;***********************************************************
;*	Func: select_choice_left
;*	desc: cycles through choices for rock paper scissors and prints them to the LCD on the left hand side, preserves right hand side of LCD
;***********************************************************
select_choice_left:
push mpr
push choice_right
;changes made to choice left will be saved globally

;valid choice values include 1,2,3, for rock paper and scissors respectively. 0 will be initialization value so when button is first pressed rock is shown 
;check if choice left is 10, load with 00 if so
;otherwise increment choice left

cpi choice_left, 3
breq select_choice_left_rollover ;if at two do not increment

inc choice_left

rjmp select_choice_left_chosen ;do not roll over if unneeded 

select_choice_left_rollover:
ldi choice_left, 1

select_choice_left_chosen:
;load z and y with labels for str clear
;call zy print function to write spaces to left hand side of LCD without clearing right hand side
;based on choice left value load Z and Y with appropriate labels for word
;call zy print function

ldi ZL, low(str_clear<<1)
ldi ZH, high(str_clear<<1)

ldi YL, low(str_clear_end<<1)
ldi YH, high(str_clear_end<<1)

rcall print_zy_bottom ;write clear string to left side of LCD
rcall load_choice_left ;load Z and Y registers with correct string lables
rcall print_zy_bottom ;print correct choice of string to LCD




pop choice_right
pop mpr
ret
;end select_choice_left




;***********************************************************
;*	Func: select_choice_right
;*	desc: cycles through choices for rock paper scissors and prints them to the LCD on the left hand side, preserves right hand side of LCD
;***********************************************************
select_choice_right:
push mpr

;changes made to choice left will be saved globally

;valid choice values include 1,2,3, for rock paper and scissors respectively. 0 will be initialization value so when button is first pressed rock is shown 
;check if choice left is 10, load with 00 if so
;otherwise increment choice left

cpi choice_right, 3
breq select_choice_right_rollover ;if at two do not increment

inc choice_right

rjmp select_choice_right_chosen ;do not roll over if unneeded 

select_choice_right_rollover:
ldi choice_right, 1

select_choice_right_chosen:
;load z and y with labels for str clear
;call zy print function to write spaces to left hand side of LCD without clearing right hand side
;based on choice left value load Z and Y with appropriate labels for word
;call zy print function

ldi ZL, low(str_clear<<1)
ldi ZH, high(str_clear<<1)

ldi YL, low(str_clear_end<<1)
ldi YH, high(str_clear_end<<1)

rcall print_yz_bottom ;write clear string to left side of LCD
rcall load_choice_right ;load Z and Y registers with correct string lables
rcall print_yz_bottom ;print correct choice of string to LCD



pop mpr
ret
;end select_choice_right








;***********************************************************
;*	Func: load_choice_left
;*	desc: loads correct string into Z and Y registers depending on choice left value
;***********************************************************
load_choice_left:
push mpr

cpi choice_left, 1
breq load_choice_left_rock

cpi choice_left, 2
breq load_choice_left_paper		;find choice_left value

cpi choice_left, 3
breq load_choice_left_scissors


load_choice_left_rock:
ldi ZL, low(str_rock<<1)
ldi ZH, high(str_rock<<1)

ldi YL, low(str_rock_end<<1)
ldi YH, high(str_rock_end<<1)

rjmp load_choice_left_end

load_choice_left_paper:				;load correct string beginning into Z, and end into Y
ldi ZL, low(str_paper<<1)
ldi ZH, high(str_paper<<1)

ldi YL, low(str_paper_end<<1)
ldi YH, high(str_paper_end<<1)

rjmp load_choice_left_end

load_choice_left_scissors:
ldi ZL, low(str_scissors<<1)
ldi ZH, high(str_scissors<<1)

ldi YL, low(str_scissors_end<<1)
ldi YH, high(str_scissors_end<<1)

load_choice_left_end:
pop mpr
ret
;end load_choice_left


;***********************************************************
;*	Func: load_choice_right
;*	desc: loads correct string into Z and Y registers depending on choice right value
;***********************************************************
load_choice_right:
push mpr

cpi choice_right, 1
breq load_choice_right_rock

cpi choice_right, 2
breq load_choice_right_paper		;find choice_left value

cpi choice_right, 3
breq load_choice_right_scissors


load_choice_right_rock:
ldi ZL, low(str_rock<<1)
ldi ZH, high(str_rock<<1)

ldi YL, low(str_rock_end<<1)
ldi YH, high(str_rock_end<<1)

rjmp load_choice_right_end

load_choice_right_paper:				;load correct string beginning into Z, and end into Y
ldi ZL, low(str_paper<<1)
ldi ZH, high(str_paper<<1)

ldi YL, low(str_paper_end<<1)
ldi YH, high(str_paper_end<<1)

rjmp load_choice_right_end

load_choice_right_scissors:
ldi ZL, low(str_scissors<<1)
ldi ZH, high(str_scissors<<1)

ldi YL, low(str_scissors_end<<1)
ldi YH, high(str_scissors_end<<1)

load_choice_right_end:
pop mpr
ret

;end load_choice_right


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
;end print_zy_top













;***********************************************************
;*	Func: print_zy_bottom
;*	desc: stores string stored in program memory and writes it to the bottom line of the LCD screen on the left
;*	REMEMBER: the address stored in z and in y must be initially bit shifted by 1 due to least sig bit being low or high indicator. 
;*	REMEMBER: you must clear line outside of this function to prevent overwriting
;*	WARNING: assumes Z stores the address of the beginning of the string and Y stores the end of the string to print.
;***********************************************************
print_zy_bottom:
push mpr
push XL
push XH
push ZL
push ZH
push YL
push YH


ldi XL, LOW(lcd_buffer_addr+16) ;point x to the bottom line of the LCD buffer address in data memory
ldi XH, HIGH(lcd_buffer_addr+16)

print_zy_bottom_left_loop:
lpm mpr, Z+ ;load value stored at the address to the beginning of the string (stored in X) to mpr, then inc X to point to next char. ie. first character of string is loaded into mpr
st X+, mpr ;Store that character to the beginning of the LCD buffer, then increment to next spot in LCD buffer

cp ZL, YL ;compare where Z points (current address) to Y (end of string), we only need Low byte since start and end are definitely not far enough away to cause roll over errors
brne print_zy_bottom_left_loop ;if not at end keep loading LCD buffer

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
;*	Func: print_yz_bottom
;*	desc: stores string stored in program memory and writes it to the bottom line of the LCD screen on the right
;*	REMEMBER: the address stored in z and in y must be initially bit shifted by 1 due to least sig bit being low or high indicator. 
;*	REMEMBER: you must clear line outside of this function to prevent overwriting
;*	WARNING: assumes Z stores the address of the beginning of the string and Y stores the end of the string to print.
;***********************************************************
print_yz_bottom:
push mpr
push XL
push XH
push ZL
push ZH
push YL
push YH

;must call lpm on Z, and need to call at end adress so shift Z->Y, and Y->Z for sake of function
mov XL, ZL
mov XH, ZH ;X now temporarily holds old Z

mov ZL, YL
mov ZH, YH ;Z now holds old Y 

mov YL, XL
mov YH, XH ;Y now holds old Z via X

ldi XL, LOW(lcd_buffer_addr+32) ;point x to the bottom line of the LCD buffer address in data memory
ldi XH, HIGH(lcd_buffer_addr+32)

print_yz_bottom_loop:
lpm mpr, Z ;load value stored at the address to the beginning of the string (stored in X) to mpr, then inc X to point to next char. ie. first character of string is loaded into mpr
st X, mpr ;Store that character to the beginning of the LCD buffer, then increment to next spot in LCD buffer

sbiw ZH:ZL, 1
sbiw XH:XL, 1


cp ZL, YL ;compare where Z points (beginning of string) to Y (Current address), we only need Low byte since start and end are definitely not far enough away to cause roll over errors
brne print_yz_bottom_loop ;if not at end keep loading LCD buffer

lpm mpr, Z; store last character (dec YL inside loop triggers reset interrupt for some reason)
st X, mpr

rcall	LCDWrLn2 ;once done write to LCD 

pop YH
pop YL
pop ZH
pop ZL
pop XH
pop XL 
pop mpr
ret
;end print_yz_bottom












;***********************************************************
;*	Stored Program Data
;***********************************************************

;-----------------------------------------------------------
; An example of storing a string. Note the labels before and
; after the .DB directive; these can help to access the data
;-----------------------------------------------------------

str_clear:
.db "        "
str_clear_end:

str_rock:
.db	"Rock"		
str_rock_end:

str_paper:
.db "paper "
str_paper_end:

str_scissors:
.db "scissor "
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


