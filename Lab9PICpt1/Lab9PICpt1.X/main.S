// Ashton Tolman
// RCET3373
// Lab9PICpt1
// https://github.com/Ashton-Tolman/Semester-5-Lab-9.git
// linker code:-Wl,-presetVect=0000h,-pisrVect=0004h,-pcode=0008h

; PIC16F883 Configuration Bit Settings

; Assembly source line config statements

//; CONFIG1
  CONFIG  FOSC = XT             ; Oscillator Selection bits (XT oscillator: Crystal/resonator on RA6/OSC2/CLKOUT and RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF           ; Power-up Timer Enable bit (PWRT disabled)
  CONFIG  MCLRE = ON            ; RE3/MCLR pin function select bit (RE3/MCLR pin function is MCLR)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF             ; Low Voltage Programming Enable bit (RB3 pin has digital I/O, HV on MCLR must be used for programming)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

// config statements should precede project file includes.
#include <xc.inc>
    DisplayRegister EQU 0x70	;the letter we are about to show
    Count5ms EQU 0x72 ; Outer debounce delay counter
    Count50us EQU 0x73 ; Inner debounce delay counter

 
; Reset Vector at 000h. Execution starts here after reset 
PSECT resetVect,class=CODE,delta=2
ResetVector:
    goto Setup
    
    
; Interrupt Vector at 0004h. Execution starts here after an interrupt.
PSECT isrVect,class=CODE,delta=2
InterruptVector:
    goto Main
    
; Main code section starts at 0008h. User code goes here
PSECT code,class=CODE,delta=2

Setup:
    ; add device setup here
    BSF 0x03, 06	    ;
    BSF 0x03, 05	    ; Set bank 3 active
    CLRF ANSEL		    ; Make PortA digital
    CLRF ANSELH		    ; Make PortB digital
    
    BCF 0x03, 06	    ;
    BSF 0x03, 05	    ; Set bank 1 active 
    BCF OPTION_REG,7	    ; Turn on the built-in pull-up resistors for PortB
    MOVLW 0b00000011
    MOVWF WPUB		    ; Use the pull-ups on RB0 and RB1 only
    CLRF TRISC		    ; Set PortC output
    BSF TRISB,0		    ; RB0 is an input (Select button)
    BSF TRISB,1		    ; RB1 is an input (Write button)
    BCF TRISA,1		    ; RA1 is an output (read marker)
    BCF TRISA,2		    ; RA2 is an output (write marker)	 
		    
    BCF 0x03, 06	    ;
    BCF 0x03, 05	    ; Set bank 0 active 
    CLRF PORTA		    ; Both markers start LOW
    CLRF PORTC		    ; Display starts blank
    goto Main
    

Main:
    CALL ReadEEPROM		; Read Data in EEPROM address 0x00
    MOVWF DisplayRegister	; Data read is in W, send to display
    MOVWF PORTC
    
    StartUpSequence:
    MOVF DisplayRegister,W
    XORLW 0x41			; Test current display for A
    BTFSS STATUS,2		; Test the Zero bit to see if A matched
    goto TestB
    goto CheckButtons
    
    TestB:
    MOVF DisplayRegister,W
    XORLW 0x42
    BTFSS STATUS,2		; Test the Zero bit to see if B matched
    goto StartupDisplay
    
    CheckButtons:
    CALL CheckWritePressed	; See if the write button is pressed
    goto Main
    
    StartupDisplay:
    MOVLW 0x41
    MOVWF DisplayRegister
    goto CheckButtons
    
;ReadEEPROM reads data in address 0x00 and puts it in W
;Diagnostic port is toggled to show this on RA1
ReadEEPROM:
    BSF PORTA,1			; Data is being read Bit ON
    BANKSEL EEADR		;
    CLRF EEADR			; Read Data in address 0x00
    
    BANKSEL EECON1		;
    BCF EECON1,7		; Read data in EEPROM not program Memory
    BSF EECON1,0		; Begin reading
    BANKSEL EEDATA		; 
    MOVF EEDATA,W		; Get data from EEDATA register
    BANKSEL PORTA		; 
    BCF PORTA,1			; Data is no longer read Bit OFF
    RETURN
    
CheckWritePressed:
    BTFSC PORTB,1		; Test if button has been pressed
    RETURN			; If it hasent, RETURN
    
    CALL Delay10ms		; Wait 10 milliseconds
    BTFSC PORTB,1		; If still pressed continue
    RETURN			; If not, Bounce Detected so RETURN
    
    WriteHeld:
    BTFSC PORTB,1		; Test if button has been Released
    CALL Delay10ms		; If it has been, wait 10ms
    BTFSC PORTB,1		; Test again for debounce
    goto EEPROMWrite		; If it has goto EEPROMWrite
    
    BTFSC PORTB,0		; Test Select button
    goto WriteHeld		; If not pressed Stay here until Write is released
    CALL Delay10ms		; Test for bounces
    BTFSC PORTB,0	    
    goto WriteHeld		; Bounce detected, stay here
    
    SelectPressed:
    BTFSC PORTB,0		; Test if Select button has been releasted
    CALL Delay10ms		;
    BTFSS PORTB,0		; Check for bouncing
    goto SelectPressed		;
    
    MOVLW 0x03
    XORWF DisplayRegister,F	; Switch the pick: 'A' becomes 'B', 'B' becomes 'A'
    MOVF DisplayRegister,W	; 
    MOVWF PORTC			; Display new letter on PortC
    goto WriteHeld
    
    
    EEPROMWrite:
    BANKSEL PORTA
    BSF PORTA,2			;write marker ON
    BANKSEL EEADR
    CLRF EEADR			;the address to write is 0
    MOVF DisplayRegister,W
    MOVWF EEDATA		;the letter to store
    BANKSEL EECON1
    BCF EECON1,7		;pick data EEPROM
    BSF EECON1,2		;allow writing
    BCF INTCON,7		;make sure no interrupt can get in the way of the next lines
    MOVLW 0x55			;the chip needs this exact code, in this exact order,
    MOVWF EECON2		;with nothing in between, or it ignores the write
    MOVLW 0xAA
    MOVWF EECON2
    BSF EECON1,1		;start the write

    BTFSC EECON1,1		;the chip clears this bit when it is finished
    goto $-1			;if it is still writing then wait
    BCF EECON1,2		;turn writing off again so nothing can write by accident
    BANKSEL PIR2
    BCF PIR2,4			;clear the "write finished" flag
    BANKSEL PORTA
    BCF PORTA,2			;write marker OFF
    RETURN
    
Delay10ms:
    CALL Delay5ms
    CALL Delay5ms
    RETURN
    
    Delay5ms:
    MOVLW   0x5E
    MOVWF   Count5ms
    
    Delay5msLoop:
    Call    Delay50usLoop
    DECFSZ  Count5ms
    goto    Delay5msLoop
    MOVLW   0x04
    MOVWF   Count5ms
    DECFSZ  Count5ms
    goto    $-1
    RETURN
    
    Delay50usLoop:
    ;Delay loop is equals 44 Tcy when count is 15
    MOVLW 0x0F             ;1 Tcy move W=15 to count
    MOVWF Count50us        ;1 Tcy make count equal 15                                    
    DECFSZ Count50us,1     ;1 Tcy if not zero, 2 Tcy if zero
    goto $-1               ;2 Tcy delay runs 15 times before skiping
    RETURN
End