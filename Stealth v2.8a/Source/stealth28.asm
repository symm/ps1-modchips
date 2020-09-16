; PSX modchip
; Stealth_28 "ST2.8 MCUK"

	TITLE	"Stealth2.8"

	RADIX       DEC
	__IDLOCS    h'0208'

	
    ifdef __12C508A
		LIST P=12F508A
		include <p12c508a.inc>
		__CONFIG	_IntRC_OSC & _WDT_OFF & _MCLRE_OFF & _CP_OFF
	endif
    ifdef __12F508
		LIST P=12F508
		include <p12f508.inc>
		__CONFIG	_IntRC_OSC & _WDT_OFF & _MCLRE_OFF & _CP_OFF
	endif
    ifdef __12C509A
		LIST P=12F509A
		include <p12c509a.inc>
		__CONFIG	_IntRC_OSC & _WDT_OFF & _MCLRE_OFF & _CP_OFF
	endif
    ifdef __12F509
		LIST P=12F509
		include <p12f509.inc>
		__CONFIG	_IntRC_OSC & _WDT_OFF & _MCLRE_OFF & _CP_OFF
	endif
    ifdef __12F683
		LIST P=12F683
		include <p12f683.inc>
		__CONFIG	_INTRC_OSC_NOCLKOUT & _WDT_OFF & _MCLRE_OFF & _PWRTE_OFF & _CP_OFF & _CPD_OFF & _BOD_ON & _FCMEN_OFF & _IESO_OFF
	endif


;**************************************************************************
; EUR, JAP, USA, WORLD
#define EUR

#define REGION_CODE_EUR		"SCEE"
#define REGION_CODE_USA		"SCEA"
#define REGION_CODE_JAP		"SCEI"
#define REGION_CODE_WORLD	"SCEW"

; 250 bps, n,8,2

	ifdef EUR
; SCEE (Europe)
; Modchip HEX: 09 A9 3D 2B A5 74
; TrackingError Signal "BIN": 10011010100 10011110100 10101110100 11101110100
;
#define	REGION_CODE	REGION_CODE_EUR
	endif
	ifdef JAP
; SCEI (Japan)
; Modchip HEX: 09 A9 3D 2B A5 B4
; TrackingError Signal "BIN": 10011010100 10011110100 10101110100 11110110100
;
#define	REGION_CODE	REGION_CODE_JAP
	endif
	ifdef USA
; SCEA (U.S.A. & America)
; Modchip HEX: 09 A9 3D 2B A5 F4
; BIN: (0000)1001 10101001 00111101 00101011 10100101 11110100
;
#define REGION_CODE	REGION_CODE_USA
	endif
	ifdef WORLD
; SCEW (World)
; Modchip HEX: 09 A9 3D 2B A5 A8
; TrackingError Signal "BIN": 10011010100 10011110100 10101110100 11110101000
;
#define REGION_CODE	REGION_CODE_WORLD
	endif

#define REGION_CODE_1	REGION_CODE
#define REGION_CODE_2	REGION_CODE
#define REGION_CODE_3	REGION_CODE

;**************************************************************************

    ifdef __12F683
RAMbase EQU 20H
    endif
    ifdef __12C508A
RAMbase EQU 07H
    endif
    ifdef __12F508
RAMbase EQU 07H
    endif
    ifdef __12C509A
RAMbase EQU 07H
    endif
    ifdef __12F509
RAMbase EQU 07H
    endif

    CBLOCK  RAMbase
		counter, count, bitcnt, cnt0, cnt1
		txbyte, byteptr, count1, count0
		memflag, rstflag, bittime, bittime1, bittime2
		signum3, signum2, signum1
		dummy, unused, gatebsyflg, dino_mode
;		r0x1c, r0x1d, r0x1e, r0x1f
    ENDC

;**************************************************************************
;                         ____  ____
;                        |    \/    |
;                  Vdd --+ 1      8 +-- Vss
;    Mem Card            |          |
;    (GP5) Conn. Pin 3 --+ 2      7 +-- signal from door (GP0)
;                        |          |
; (GP4) LED +-|>|-/\/\/--+ 3      6 +-- data stream (GP1)
;                        |          |
;          (GP3) reset --+ 4      5 +-- gate in/out (GP2)
;                        |          |
;                        +----------+

#define	DOOR_SW		GPIO, 0x0	; Door switch (in) (open=0, closed=1)
#define	DATA_OUT	GPIO, 0x1	; Data out (out)
#define	GATE		GPIO, 0x2	; Gate in (in/out)
#define	RESET		GPIO, 0x3	; Reset (in)       (reset=0, normal=1)
#define	LED			GPIO, 0x4   ; Led (out)        (on=0, off=1)
#define	MEM_ACCESS	GPIO, 0x5   ; Mem access (in)

;**************************************************************************
;MACROS
;
; Check every 50ms if RESET is active (low) and wait until inactive
WAIT_RST  macro
	  local Loop
Loop	CALL	Dly_50ms
		BTFSS	RESET		; Check if RESET is released
		GOTO	Loop
	endm
;
;----------------------------
;Macro to avoid the limit of the 12c508 two level stack unfolding the code
;
DINO_MODE  macro mode
	local Start, Loop, Exit
Start
		WAIT_RST			; Wait until RESET is released

		CLRF	byteptr		; Start of string
		CALL	TXregcode	; Send 1st region_code datagram
		BTFSS	RESET		; Check if Reset
		GOTO	Exit		; Yes. Go next mode

		CALL	TXregcode	; Send 2nd region_code datagram
		BTFSS	RESET		; Check if Reset
		GOTO	Exit		; Yes. Go next mode

		CALL	TXregcode	; Send 3rd region_code datagram

		MOVLW	.38 + mode	; Wait 3.8 to 5 sec between
		MOVWF	dino_mode                             
Loop	CALL	Dly_100ms
		BTFSS	RESET		; Check if Reset
		GOTO	Exit		; Yes. Go next mode

		DECFSZ	dino_mode, F                         
		GOTO	Loop

		CALL	Loadregs	; bittime=bittime1 : bittime2
		GOTO	Start		; Keep sending datagrams while not reset
Exit
	endm
;
;----------------------------
;
M001 macro
		MOVLW	0xfb		;--x1xx1x DATA=1, LED=1 (OFF)
		BTFSS	GATE		; If GATE=0 then set DATA=0
		MOVLW	0xf9		;--x1xx0x DATA=0, LED=1 (OFF)
		MOVWF	GPIO
		NOP                                    
	endm

;**************************************************************************
; ENTRY POINT * ENTRY POINT * ENTRY POINT * ENTRY POINT * ENTRY POINT *
;**************************************************************************

        ORG 0

Reset
	ifdef __12C508A
		MOVWF	OSCCAL		; Set calibration
		GOTO	Start

		dt "ST2.8 MCUK"
	endif
    ifdef __12F508
		MOVWF	OSCCAL		; Set calibration
		GOTO	Start

		dt "ST2.8 MCUK"
	endif
	ifdef __12C509A
		MOVWF	OSCCAL		; Set calibration
		GOTO	Start

		dt "ST2.8 MCUK"
	endif
    ifdef __12F509
		MOVWF	OSCCAL		; Set calibration
		GOTO	Start

		dt "ST2.8 MCUK"
	endif
    ifdef __12F683
		MOVLW	07h			; Setup I/O
		MOVWF	CMCON0		; Set GP<2:0> to digital I/O
		BSF     STATUS,RP0
  errorlevel -302			; Turn off banking message
; Disable A/D input !!!
		CLRF    ANSEL		; digital I/O
;		MOVLW   b'00101111'
;		MOVWF   TRISIO
; WakeUp,PullUp Disabled, T0CS=Fosc/4, PSA Prescaler to Timer0, PS2:PS0=1:8
;		MOVLW   0xc2		;
;		MOVWF   OPTION_REG
  errorlevel +302			; Enable banking message
		BCF     STATUS,RP0

		GOTO	Start

		dt "ST2.8"
	endif
;
;**************************************************************************
;
		ORG 0xc

; Preload bittime with alternating count values to send with dual baudrate
; inc dummy; (odd)? bittime=bittime1 : bittime=bittime2
Loadregs
		INCF	dummy, F
		BTFSS	dummy, 0
		GOTO	Dummyodd

		MOVF	bittime2, W	; dummy was even
		MOVWF	bittime
		RETLW 0                                
;
Dummyodd
		MOVF	bittime1, W	; dummy was odd
		MOVWF	bittime
		RETLW 0                                
;
;
;
;**************************************************************************
; Delay 100 milliseconds aprox.
;
Dly_100ms
		MOVLW	.100
		GOTO	Delay_W
;
;----------------------------
; Delay 10 milliseconds aprox.
;
Dly_10ms
		MOVLW	.10
		GOTO	Delay_W
;
;----------------------------
; Delay 50 milliseconds aprox.
;
Dly_50ms
		MOVLW	.50
;
;----------------------------
; Delay W milliseconds aprox.
;
Delay_W	MOVWF	cnt0		;
Dloop1
		MOVLW	0xc6		;
		MOVWF	cnt1		;
Dloop2
		BTFSS	MEM_ACCESS	; Mem access? (Memcard is accessed when the machine has booted)
		CLRF	memflag		; Yes. Clear flag
		DECFSZ	cnt1, F                          
		GOTO	Dloop2

		BTFSS	RESET		; Resetting?
		CLRF	rstflag		; Yes. Clear flag
		DECFSZ	cnt0, F                          
		GOTO	Dloop1

		RETLW 0                                
;
;
;
;**************************************************************************
; send bit=0
TXb_0	BTFSC	gatebsyflg, 0	; GATE busy?
		GOTO	TXb_0nogate	; Yes. Then send bits without forcing GATE

		NOP					; MEM, LED, RESET, GATE, DATA, DOOR
		MOVLW	0xe9		;--101001 DATA, GATE, LED output
		TRIS	GPIO
		MOVLW	0xe9		;--x0x00x DATA=0, GATE=0, LED=0 (ON)
		MOVWF	GPIO
		GOTO	Dly_4ms
;
;
;
TXb_0nogate
		MOVLW	0xed		;--101101 DATA, LED output, GATE input
		TRIS	GPIO
		MOVLW	0xe9		;--x0xx0x DATA=0, LED=0 (ON)
		MOVWF	GPIO

		GOTO	Dly_4ms
;
;
;
; send bit=1
TXb_1	BTFSC	gatebsyflg, 0	; GATE busy?
		GOTO	TXb_1nogate	; Yes. Then send bits without forcing GATE

		NOP					; MEM, LED, RESET, GATE, DATA, DOOR
		MOVLW	0xeb		;--101011 DATA input, GATE, LED output
		TRIS	GPIO
		MOVLW	0xf9		;--x1x0xx GATE=0, LED=1 (OFF), DATA=1 (ext. pullup)
		MOVWF	GPIO

		GOTO	Dly_4ms
;
;
; Wait 4ms per bit for a rate of 250bps
;
Dly_4ms	MOVF	bittime, W                           
		MOVWF	cnt1                              
Dly_4msloop1
		MOVLW	.2
		MOVWF	cnt0
Dly_4msloop2
		BTFSS	MEM_ACCESS	; Mem access?
		CLRF	memflag		; Yes. Clear flag
		BTFSS	RESET		; Resetting?
		CLRF	rstflag		; Yes. Clear flag

		DECFSZ	cnt0, F                          
		GOTO	Dly_4msloop2

		DECFSZ	cnt1, F                          
		GOTO	Dly_4msloop1

		RETLW 0                                
;
;
; Wait 4ms per bit for a rate of 250bps
;
TXb_1nogate					; MEM, LED, RESET, GATE, DATA, DOOR
		MOVLW	0xed		;--101101 DATA, LED output, GATE input
		TRIS	GPIO

		MOVF	bittime, W                           
		MOVWF	cnt1                              
TXb1ngloop
		MOVLW	0xfb		;--x1xx1x DATA=1, LED=1 (OFF)
		BTFSS	GATE		; If GATE=0 then set DATA=0
		MOVLW	0xf9		;--x1xx0x DATA=0, LED=1 (OFF)
		MOVWF	GPIO
		NOP                                    

		BTFSS	MEM_ACCESS	; Mem access?
		CLRF	memflag		; Yes. Clear flag
		BTFSS	RESET		; Resetting?
		CLRF	rstflag		; Yes. Clear flag

		MOVLW	0xfb		;--x1xx1x DATA=1, LED=1 (OFF)
		BTFSS	GATE		; If GATE=0 then set DATA=0
		MOVLW	0xf9		;--x1xx0x DATA=0, LED=1 (OFF)
		MOVWF	GPIO
		NOP                                    

		NOP                                    
		DECFSZ	cnt1, F                          
		GOTO	TXb1ngloop

		NOP                                    

		MOVLW	0xfb		;--x1xx1x DATA=1, LED=1 (OFF)
		BTFSS	GATE		; If GATE=0 then set DATA=0
		MOVLW	0xf9		;--x1xx0x DATA=0, LED=1 (OFF)
		MOVWF	GPIO
		NOP                                    

		MOVLW	0xfb		;--x1xx1x DATA=1, LED=1 (OFF)
		BTFSS	GATE		; If GATE=0 then set DATA=0
		MOVLW	0xf9		;--x1xx0x DATA=0, LED=1 (OFF)
		MOVWF	GPIO
		NOP                                    

		RETLW 0                                
;
;
;----------------------------
; Transmit region_code signature datagram 250bps,8,n,2 inverted
; DATA=0 previoulsy
TXregcode
		MOVLW	.72			; Delay 72 ms marker at head
		CALL	Delay_W

		MOVLW	.4			; region_code datagram len=4
		MOVWF	count		;
TXrc_byteloop
		MOVF	byteptr, W	; Get current char pointer
		CALL	Table		; Read signature from Table
		MOVWF	txbyte		; Store temp code
		COMF	txbyte, F	; The signature must be complemented
		MOVLW	.9			; start+byte=9 
		MOVWF	bitcnt                              
		GOTO	TXrc_b1		; Send start bit=1

TXrc_bitloop
		RRF		txbyte, F	; LSB rotate byte thru carry
		BTFSS	STATUS, C	; Is carry set?
		GOTO	TXrc_b0		; c=0
TXrc_b1
		CALL	TXb_1		; Send bit=1
		GOTO	TXrc_bnxt
TXrc_b0
		CALL	TXb_0		; Send bit=0
		NOP                                    
TXrc_bnxt
		DECFSZ	bitcnt, F	; Last bit?
		GOTO	TXrc_bitloop	; Send next

		CALL	TXb_0		; Send stop bit=0
		CALL	TXb_0      	; Send stop bit=0
		INCF	byteptr, F	; Point to next byte
		DECFSZ	count, F	; Last byte?
		GOTO	TXrc_byteloop	; Send next byte

		RETLW 0
;
;
;
;**************************************************************************
Table	ADDWF	PCL, F		; Table with region_codes
		dt	REGION_CODE_1	; 1st
		dt	REGION_CODE_2	; 2nd
		dt	REGION_CODE_3	; 3rd
;
;
;
;**************************************************************************
Main_1	CLRF	dummy
		CALL	Dly_50ms	; Wait 50ms
		BTFSC	RESET		; Reset active?
		GOTO	Main_2		; No

		MOVLW	.250		; delay 2.5 secs
		MOVWF	count1
Mloop1	BTFSC	RESET		; Reset active?
		GOTO	Main_2		; No

		CALL	Dly_10ms                              
		DECFSZ	count1, F
		GOTO	Mloop1

		WAIT_RST			; Wait until RESET is released. Could've been in the dino macro if were after the jump.

		GOTO	Dino1		; RESET active > 2.5 sec starts dino mode
;
;
;
Main_2
		MOVLW	.18			; delay 900ms
		MOVWF	counter
Mloop2	CALL	Dly_50ms
		DECFSZ	counter, F
		GOTO	Mloop2
;
		CLRF	gatebsyflg	; Initialize flag
;
; Wait up to 5 secs until GATE is quiet high or low
;
		MOVLW	.25                             
		MOVWF	count1

ChkGateloop
		MOVLW	.20
		MOVWF	count0
ChkGateloop1
		BTFSC	GATE
		GOTO	ChkGatehigh

		DECFSZ	count0, F
		GOTO	ChkGateloop1

		GOTO	Gatequiet	; GATE was low 100us
;
ChkGatehigh
		MOVLW	.20
		MOVWF	count0
ChkGateloop2
		BTFSS	GATE
		GOTO	ChkGateagain

		DECFSZ	count0, F
		GOTO	ChkGateloop2

		GOTO	Gatequiet	; GATE was high 100us

ChkGateagain
		DECFSZ	count1, F
		GOTO	ChkGateloop
;
; More than 5 secs with a data stream in GATE
; Set DATA=0, LED=0	(ON) and GATE as input
;
		BSF		gatebsyflg, 0	; Set to mark that GATE is busy

		MOVLW	0xe9		;--101001 DATA=0, GATE=0, LED=0	(ON)
		MOVWF	GPIO
		MOVLW	0xed		;--101101 DATA, LED output, GATE input
		TRIS	GPIO		; MEM, LED, RESET, GATE, DATA, DOOR
		GOTO	Gatecont
;
; GATE is quiet high or low
; Set DATA=0, GATE=0, LED=0 (ON)
;
Gatequiet
		MOVLW	0xe9		;--101001 DATA=0, GATE=0, LED=0 (ON)
		MOVWF	GPIO
		MOVLW	0xe9		;--101001 DATA, GATE, LED output
		TRIS	GPIO		; MEM, LED, RESET, GATE, DATA, DOOR                              

Gatecont
		BSF		rstflag, 0	; Initialize flag
		BSF		memflag, 0	; Initialize flag
;
; Wait 314 ms before sending the country code
;
		MOVLW	.157		; delay 157 ms
		CALL	Delay_W                             
		MOVLW	.157		; delay 157 ms
		CALL	Delay_W                             
;
; Send (signum2=18) * 3 times the country code
;
		MOVF	signum2, W	; signum2=18
		MOVWF	count1
TXsig
		MOVLW	.3			; Send 3 region_code datagrams (MAX=3)
		MOVWF	count0
		CLRF	byteptr		; Start of string
TXsigloop1
		CALL	TXregcode	; Send region_code datagram
		BTFSS	rstflag, 0	; Resetting?
		GOTO	Main		; Yes

		BTFSS	memflag, 0	; Mem access?
		GOTO	TXsigloop6	; Yes

		DECFSZ	count0, F
		GOTO	TXsigloop1	; Send next region code

		CALL	Loadregs	; bittime=bittime1 : bittime2
		DECFSZ	count1, F
		GOTO	TXsig		; Send all again

		GOTO	TXsigloop5
;
; Send (signum1=3) * 3 times the country code
;
TXsigloop6
		MOVF	signum1, W	; signum1=3
		MOVWF	count1
		BSF		memflag, 0	; Initialize flag
TXsigloop3
		CLRF	byteptr		; Start of string

		MOVLW	.3			; Send 3 region_code datagrams (MAX=3)
		MOVWF	count0
TXsigloop2
		CALL	TXregcode	; Send region_code datagram
		BTFSS	rstflag, 0	; Resetting?
		GOTO	Main		; Yes

		DECFSZ	count0, F
		GOTO	TXsigloop2

		CALL	Loadregs	; bittime=bittime1 : bittime2
		BTFSS	memflag, 0	; Mem access?
		GOTO	TXsigloop6	; Yes

		DECFSZ	count1, F
		GOTO	TXsigloop3
;
;Keep sending 3 times the country code unless thereis a memcard access
;
TXsigloop5
		CLRF	byteptr		; Start of string

		MOVLW	.3			; Send 3 region_code datagrams (MAX=3)
		MOVWF	count0
TXsigloop4
		CALL	TXregcode	; Send region_code datagram
		BTFSS	memflag, 0	; Mem access?
		GOTO	Stealth		; Yes

		BTFSS	rstflag, 0	; Resetting?
		GOTO	Main		; Yes

		DECFSZ	count0, F
		GOTO	TXsigloop4

		CALL	Loadregs	; bittime=bittime1 : bittime2
		GOTO	TXsigloop5	; Keep sending
;
;
; Enter stealth mode with GPIO tristate. Wait for reset or door open
;
Stealth	MOVLW	0xff		; All GPIO tristate
		TRIS	GPIO
Stwaitopen
		BTFSS	RESET		; Reset?
		GOTO	Main		; Yes. Start again

		BTFSS	DOOR_SW		; Door open?
		GOTO	Stwaitopen	; No. Keep waiting
							; Yes. Wait to let the door to be fully open
		MOVLW	.255		; delay 255 ms
		CALL	Delay_W                             
		MOVLW	.255		; delay 255 ms
		CALL	Delay_W                             

Stwaitclose
		BTFSS	RESET		; Reset?
		GOTO	Main		; Yes. Start again

		BTFSC	DOOR_SW		; Door open?
		GOTO	Stwaitclose	; Yes. Keep waiting

		BTFSS	RESET		; Reset?
		GOTO	Main		; Yes. Start again
;
; Try to boot the second CD and enter stealth mode again
; Send (signum3=40) * 3 times the country code
;
		MOVF	signum3, W	; signum3=40
		MOVWF	count1
		BSF		rstflag, 0	; Initialize flag
		CLRF	dummy
Stloop3
		CALL	Loadregs	; bittime=bittime1 : bittime2
		CLRF	byteptr		; Start of string
		MOVLW	.3			; Send 3 region_code datagrams (MAX=3)
		MOVWF	count0
Stloop4
		CALL	TXregcode	; Send region_code datagram
		BTFSS	rstflag, 0	; Resetting?
		GOTO	Main		; Yes

		BTFSC	DOOR_SW		; Door open?
		GOTO	Stealth		; Yes?. Try again

		DECFSZ	count0, F
		GOTO	Stloop4

		DECFSZ	count1, F
		GOTO	Stloop3

		GOTO	Stealth		; All sent. Loop stealth again
;
;
;
;**************************************************************************
Start	MOVLW	0xc2		; WakeUp,PullUp Disabled, T0CS=Fosc/4
		OPTION				; PSA Prescaler to Timer0, PS2:PS0=1:8

Main	MOVLW	0xff		; All GPIO tristate
		TRIS	GPIO

		MOVLW	.40			; Loop 40 times
		MOVWF	signum3		;
		MOVLW	.221		; 4ms @ 4MHz for 250bps
		MOVWF	bittime		; Bit time counter preload
		MOVWF	bittime1	; Bit time count 1
		MOVLW	.221		;
		MOVWF	bittime2	; Bit time count 2
		MOVLW	.18			; Loop 18 times
		MOVWF	signum2		;
		MOVLW	.3			; Loop 3 times
		MOVWF	signum1
		GOTO	Main_1		;
;
;
;
;**************************************************************************
; Dino mode. Press Reset 3 sec to enter
;
Dino1	CLRF	byteptr		; Start of string
		CALL	TXregcode                              
		BTFSS	RESET                        
		GOTO	Nextdino

		CALL	TXregcode                              
		BTFSS	RESET                        
		GOTO	Nextdino

		CALL	TXregcode                              

		MOVLW	.38 + 1
		MOVWF	dino_mode                             
Dino1loop
		CALL	Dly_100ms                              
		BTFSS	RESET                        
		GOTO	Nextdino

		DECFSZ	dino_mode, F                         
		GOTO	Dino1loop

		CALL	Loadregs	; bittime=bittime1 : bittime2
		GOTO	Dino1

Nextdino
		DINO_MODE	.2
		DINO_MODE	.3
		DINO_MODE	.4
		DINO_MODE	.5
		DINO_MODE	.6
		DINO_MODE	.7
		DINO_MODE	.8
		DINO_MODE	.9
		DINO_MODE	.10
		DINO_MODE	.11

Lock	GOTO	Lock		; Disabled. Power cycle to reset

;**************************************************************************
; Check that factory programmed OSCCAL is not overwritten
	if ($ > 0x1ff)
    	ifdef __12C508A
			error "Overwritting factory programmed OSCCAL at 0x1ff"
		endif
    	ifdef __12F508
			error "Overwritting factory programmed OSCCAL at 0x1ff"
		endif
	endif
;**************************************************************************
	end
