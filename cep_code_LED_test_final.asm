; --- TIC TAC TOE FOR 8051 (LED VERSION) ---
; BOARD: 30H-38H (0=Empty, 1=X, 2=O)
; OUTPUT: P1 (LEDs 1-8), P0.0 (LED 9)

; --- VARIABLE DEFINITIONS (RAM ADDRESSES) ---
BOARD   EQU 30H    ; Start of 9-byte board (30H to 38H)
CUR     EQU 3AH    ; Current player (1 for X, 2 for O)
MODE    EQU 3BH    ; Game mode (1 for PvP, 2 for PvAI)
MCNT    EQU 3CH    ; Move count (0 to 9)
GSTAT   EQU 3DH    ; Game status (0:Play, 1:X wins, 2:O wins, 3:Draw)
TA      EQU 3EH    ; Temporary register A
TB      EQU 3FH    ; Temporary register B
W1      EQU 40H    ; Winning Index 1
W2      EQU 41H    ; Winning Index 2
W3      EQU 42H    ; Winning Index 3
MODE_SW  EQU P2.7   ; The hardware switch pin
OLD_MODE EQU 43H    ; RAM to store the previous switch state

; --- CONSTANTS ---
EMPTY   EQU 00H
PLX     EQU 01H
PLO     EQU 02H
PVP     EQU 01H
PVAI    EQU 02H

ORG 0000H
LJMP MAIN

ORG 0030H
MAIN:
    MOV SP, #70H
    ACALL INIT_HARDWARE
    ACALL BLINK_ALL    

    ; --- SYNC STARTUP STATE ---
    ; Immediately read the physical switch to set the starting mode
    JB MODE_SW, SET_START_PVP
    MOV MODE, #PVAI
    MOV OLD_MODE, #PVAI
    SJMP RESTART
SET_START_PVP:
    MOV MODE, #PVP
    MOV OLD_MODE, #PVP

RESTART:
    ACALL INIT_GAME
    ACALL GAME_LOOP
    ACALL SHOW_RESULT
    LJMP RESTART

INIT_HARDWARE:
    MOV P1, #00H        ; Clear Red 1-8
    MOV P0, #00H        ; Clear Red 9 and Green 1-7
    
    ; Setup Port 2: Clear LEDs (4,5) and set Switch (7) + Keypad (0-3) as inputs
    MOV A, P2
    ANL A, #11001111B   ; Keep bits 0,1,2,3 and 6,7 (Clears LED bits)
    ORL A, #10001111B   ; Ensure Switch (7) and Keypad (0-3) are High (Input mode)
    MOV P2, A
    RET
        
INIT_GAME:
    MOV R0, #BOARD
    MOV R7, #9
IG1:
    MOV @R0, #EMPTY
    INC R0
    DJNZ R7, IG1
    MOV CUR, #PLX
    MOV MCNT, #0
    MOV GSTAT, #0
    RET

GAME_LOOP:
    ACALL SHOW_BOARD
GL1:
    MOV A, CUR
    CJNE A, #PLX, GL_O
    ACALL GET_MOVE     ; Player X Move
    SJMP GL_POST
GL_O:
    MOV A, MODE
    CJNE A, #PVAI, GL_OH
    ACALL DELAY        ; Small pause for AI "thinking"
    ACALL AI_MOVE      ; AI Move
    SJMP GL_POST
GL_OH:
    ACALL GET_MOVE     ; Player O Move
GL_POST:
    ACALL SHOW_BOARD
    ACALL CHK_END
    MOV A, GSTAT
    CJNE A, #0, GL_DONE
    ; Switch Players
    MOV A, CUR
    CJNE A, #PLX, GL_SX
    MOV CUR, #PLO
    SJMP GL1
GL_SX:
    MOV CUR, #PLX
    SJMP GL1
GL_DONE:
    RET

; --- OUTPUT LOGIC: MAPPING RAM TO PINS ---
; --- CORRECTED OUTPUT LOGIC ---
SHOW_BOARD:
    ; --- Step 1: Initialize Ports (Clear all LED pins) ---
    MOV P1, #00H         ; Clear Red 1-8
    MOV P0, #00H         ; Clear Red 9 and Green 1-7
    ANL P2, #11001111B   ; Clear Green 8-9 (P2.4, P2.5)

    ; --- Step 2: Loop through Board RAM (30H to 38H) ---
    MOV R0, #BOARD
    MOV R7, #0           ; R7 is our index counter (0 to 8)

SB_LOOP:
    MOV A, @R0
    JZ SB_NEXT           ; If cell is EMPTY, do nothing
    CJNE A, #PLX, SB_GRN ; If not Player X, jump to Green logic

    ; --- RED LOGIC (Player X) ---
    MOV A, R7
    CJNE A, #8, SB_R1_8  ; Is it the 9th LED?
    SETB P0.0            ; Turn on D9 Red
    SJMP SB_NEXT
SB_R1_8:
    MOV B, #01H          ; Start with bitmask for LED 1 (00000001)
    MOV A, R7            ; Get index (0-7)
    JZ SB_R_OUT          ; If index is 0, no shift needed
    MOV R2, A            ; Use index as shift count
    MOV A, B             ; Move mask to A to rotate
SB_R_ROT:
    RL A
    DJNZ R2, SB_R_ROT
    MOV B, A             ; Save rotated mask back to B
SB_R_OUT:
    MOV A, B
    ORL P1, A            ; Turn on the specific Red LED
    SJMP SB_NEXT

    ; --- GREEN LOGIC (Player O) ---
SB_GRN:
    MOV A, R7
    CJNE A, #7, SB_G9    ; Is it LED 8?
    SETB P2.4            ; D8 Green
    SJMP SB_NEXT
SB_G9:
    CJNE A, #8, SB_G1_7  ; Is it LED 9?
    SETB P2.5            ; D9 Green
    SJMP SB_NEXT
SB_G1_7:
    MOV B, #02H          ; Green 1 starts at P0.1 (00000010)
    MOV A, R7            ; Get index (0-6)
    JZ SB_G_OUT          ; If index is 0, no shift needed
    MOV R2, A
    MOV A, B
SB_G_ROT:
    RL A
    DJNZ R2, SB_G_ROT
    MOV B, A
SB_G_OUT:
    MOV A, B
    ORL P0, A            ; Turn on specific Green LED on Port 0
    
SB_NEXT:
    INC R0               ; Next RAM location
    INC R7               ; Next index
    MOV A, R7
    CJNE A, #9, SB_LOOP  ; Loop until all 9 cells checked
    RET
    
; --- INPUT LOGIC: KEYPAD ---
GET_MOVE:
GM1:
    ACALL CHECK_MODE_CHANGE ;
    
    ACALL KP_SCAN
    CJNE A, #0FFH, GM2
    SJMP GM1
GM2:
    ; Convert Keypad 1-9 to 0-8 Index
    MOV TA, A
    DEC TA
    MOV A, TA
    ADD A, #BOARD
    MOV R0, A
    MOV A, @R0
    CJNE A, #EMPTY, GM1 ; If spot taken, ignore and wait again
    MOV A, CUR
    MOV @R0, A
    INC MCNT
    RET

; --- WIN CHECKING LOGIC ---
CHK_END:
    MOV TB, #PLX
    ACALL ANY3
    JNC CE2
    MOV GSTAT, #1
    RET
CE2:
    MOV TB, #PLO
    ACALL ANY3
    JNC CE3
    MOV GSTAT, #2
    RET
CE3:
    MOV A, MCNT
    CJNE A, #9, CE4
    MOV GSTAT, #3
    RET
CE4:
    MOV GSTAT, #0
    RET

ANY3:
    MOV R1, #0
    MOV R2, #1
    MOV R3, #2
    ACALL C3
    JC AYES
    
    MOV R1, #3
    MOV R2, #4
    MOV R3, #5
    ACALL C3
    JC AYES
    
    MOV R1, #6
    MOV R2, #7
    MOV R3, #8
    ACALL C3
    JC AYES
    
    MOV R1, #0
    MOV R2, #3
    MOV R3, #6
    ACALL C3
    JC AYES
    
    MOV R1, #1
    MOV R2, #4
    MOV R3, #7
    ACALL C3
    JC AYES
    
    MOV R1, #2
    MOV R2, #5
    MOV R3, #8
    ACALL C3
    JC AYES
    
    MOV R1, #0
    MOV R2, #4
    MOV R3, #8
    ACALL C3
    JC AYES
    
    MOV R1, #2
    MOV R2, #4
    MOV R3, #6
    ACALL C3
    JC AYES
    
    CLR C
    RET
AYES:
    ; Save the winning line indices before returning
    MOV W1, R1
    MOV W2, R2
    MOV W3, R3
    SETB C
    RET
 

C3:
    ; Check first position
    MOV A, R1
    ADD A, #BOARD
    MOV R0, A
    MOV A, @R0
    CJNE A, TB, C3F    ; TB is the value we are looking for (X or O)
    
    ; Check second position
    MOV A, R2
    ADD A, #BOARD
    MOV R0, A
    MOV A, @R0
    CJNE A, TB, C3F
    
    ; Check third position
    MOV A, R3
    ADD A, #BOARD
    MOV R0, A
    MOV A, @R0
    CJNE A, TB, C3F
    
    SETB C             ; All three matched
    RET
C3F:
    CLR C              ; Match failed
    RET

; --- AI LOGIC ---
; --- SMART AI LOGIC ---
; --- SMART AI LOGIC ---
AI_MOVE:
    ; 1. Try to WIN (Look for 2 Green and 1 Empty)
    MOV TB, #PLO
    ACALL FIND_BEST
    MOV A, TA
    CJNE A, #0FFH, AI_DO_MOVE

    ; 2. Try to BLOCK (Look for 2 Red and 1 Empty)
    MOV TB, #PLX
    ACALL FIND_BEST
    MOV A, TA
    CJNE A, #0FFH, AI_DO_MOVE

    ; 3. Take CENTER (Index 4)
    MOV R0, #BOARD+4
    MOV A, @R0
    CJNE A, #EMPTY, AI_CORNERS
    MOV TA, #4
    SJMP AI_DO_MOVE

AI_CORNERS:
    MOV R0, #BOARD
    MOV A, @R0
    CJNE A, #EMPTY, AI_C2
    MOV TA, #0
    SJMP AI_DO_MOVE
AI_C2:
    MOV R0, #BOARD+2
    MOV A, @R0
    CJNE A, #EMPTY, AI_C6
    MOV TA, #2
    SJMP AI_DO_MOVE
AI_C6:
    MOV R0, #BOARD+6
    MOV A, @R0
    CJNE A, #EMPTY, AI_C8
    MOV TA, #6
    SJMP AI_DO_MOVE
AI_C8:
    MOV R0, #BOARD+8
    MOV A, @R0
    CJNE A, #EMPTY, AI_SIDES
    MOV TA, #8
    SJMP AI_DO_MOVE

AI_SIDES:
    MOV R0, #BOARD+1
    MOV A, @R0
    CJNE A, #EMPTY, AI_S3
    MOV TA, #1
    SJMP AI_DO_MOVE
AI_S3:
    MOV R0, #BOARD+3
    MOV A, @R0
    CJNE A, #EMPTY, AI_S5
    MOV TA, #3
    SJMP AI_DO_MOVE
AI_S5:
    MOV R0, #BOARD+5
    MOV A, @R0
    CJNE A, #EMPTY, AI_S7
    MOV TA, #5
    SJMP AI_DO_MOVE
AI_S7:
    MOV TA, #7

AI_DO_MOVE:
    MOV A, TA
    ADD A, #BOARD
    MOV R0, A
    MOV @R0, #PLO
    INC MCNT
    RET

; --- HELPER: FIND BEST MOVE ---
FIND_BEST:
    MOV TA, #0FFH
    ; We check all 8 lines one by one
    MOV R1, #0
    MOV R2, #1
    MOV R3, #2
    ACALL CHKL
    MOV A, TA
    CJNE A, #0FFH, FB_DN
    
    MOV R1, #3
    MOV R2, #4
    MOV R3, #5
    ACALL CHKL
    MOV A, TA
    CJNE A, #0FFH, FB_DN
    
    MOV R1, #6
    MOV R2, #7
    MOV R3, #8
    ACALL CHKL
    MOV A, TA
    CJNE A, #0FFH, FB_DN
    
    MOV R1, #0
    MOV R2, #3
    MOV R3, #6
    ACALL CHKL
    MOV A, TA
    CJNE A, #0FFH, FB_DN
    
    MOV R1, #1
    MOV R2, #4
    MOV R3, #7
    ACALL CHKL
    MOV A, TA
    CJNE A, #0FFH, FB_DN
    
    MOV R1, #2
    MOV R2, #5
    MOV R3, #8
    ACALL CHKL
    MOV A, TA
    CJNE A, #0FFH, FB_DN
    
    MOV R1, #0
    MOV R2, #4
    MOV R3, #8
    ACALL CHKL
    MOV A, TA
    CJNE A, #0FFH, FB_DN
    
    MOV R1, #2
    MOV R2, #4
    MOV R3, #6
    ACALL CHKL
FB_DN:
    RET

CHKL:
    MOV R5, #0         ; Match counter
    MOV R4, #0FFH      ; Target empty index
    
    ; Check first index (R1)
    MOV A, R1
    ADD A, #BOARD
    MOV R0, A
    MOV A, @R0
    CJNE A, TB, CHK_E0
    INC R5
    SJMP CHK1
CHK_E0:
    CJNE A, #EMPTY, CHK1
    MOV A, R1          ; Bridge R1 -> A
    MOV R4, A          ; Bridge A -> R4
CHK1:
    ; Check second index (R2)
    MOV A, R2
    ADD A, #BOARD
    MOV R0, A
    MOV A, @R0
    CJNE A, TB, CHK_E1
    INC R5
    SJMP CHK2
CHK_E1:
    CJNE A, #EMPTY, CHK2
    MOV A, R2          ; Bridge R2 -> A
    MOV R4, A          ; Bridge A -> R4
CHK2:
    ; Check third index (R3)
    MOV A, R3
    ADD A, #BOARD
    MOV R0, A
    MOV A, @R0
    CJNE A, TB, CHK_E2
    INC R5
    SJMP CHK_FIN
CHK_E2:
    CJNE A, #EMPTY, CHK_FIN
    MOV A, R3          ; Bridge R3 -> A
    MOV R4, A          ; Bridge A -> R4
CHK_FIN:
    ; Winner/Blocker found if matches = 2 and one spot is empty
    MOV A, R5
    CJNE A, #2, CHK_RET
    MOV A, R4
    CJNE A, #0FFH, CHK_VAL
    RET
CHK_VAL:
    MOV TA, R4         ; Save the move
CHK_RET:
    RET

; --- MISC UTILITIES ---
SEL_MODE:
    ACALL KP_SCAN
    CJNE A, #1, SM_2
    MOV MODE, #PVP 
    RET
SM_2:
    CJNE A, #2, SEL_MODE
    MOV MODE, #PVAI 
    RET

SHOW_RESULT:
    MOV A, GSTAT
    CJNE A, #3, BLINK_WINNER ; If not a draw, blink the winner
    ; --- DRAW LOGIC ---
    ; Just blink everything once to show game over
    ACALL BLINK_ALL
    SJMP SR_DONE

BLINK_WINNER:
    MOV R5, #3              ; Blink 10 times
SR_LP:
    ; 1. All OFF
    ACALL INIT_HARDWARE
    ACALL LONG_DLY
    
    ; 2. Only the winning 3 ON
    MOV R1, W1 
    ACALL SHOW_SINGLE_WINNER
    
    MOV R1, W2 
    ACALL SHOW_SINGLE_WINNER
    
    MOV R1, W3 
    ACALL SHOW_SINGLE_WINNER
    
    ACALL LONG_DLY
    
    DJNZ R5, SR_LP

SR_DONE:
    ACALL WAIT_KEY
    RET

BLINK_ALL:
    ; Turn everything ON (Test all colors)
    MOV P1, #0FFH 
    MOV P0, #0FFH
    ORL P2, #00110000B  ; Set P2.4 and P2.5
    ACALL LONG_DLY
    
    ; Turn everything OFF
    ACALL INIT_HARDWARE
    RET

; --- SUBROUTINE: TURN ON ONLY ONE WINNING LED ---
; Input: R1 = Index (0-8), GSTAT = Color (1=X, 2=O)
SHOW_SINGLE_WINNER:
    MOV A, GSTAT
    CJNE A, #PLX, SSW_GRN
    
    ; --- RED LOGIC (Winner X) ---
    MOV A, R1
    CJNE A, #8, SSW_R1_8
    SETB P0.0           ; LED 9 Red
    RET
SSW_R1_8:
    MOV A, R1
    MOV R2, A           ; Use R2 as shift counter
    MOV A, #01H         ; Starting mask
    JZ SSW_R_OUT        ; If index 0, no shift
SSW_R_ROT: 
    RL A 
    DJNZ R2, SSW_R_ROT
SSW_R_OUT: 
    ORL P1, A           ; Apply to Port 1
    RET

    ; --- GREEN LOGIC (Winner O) ---
SSW_GRN:
    MOV A, R1
    CJNE A, #7, SSW_G9
    SETB P2.4           ; LED 8 Green
    RET
SSW_G9:
    CJNE A, #8, SSW_G1_7
    SETB P2.5           ; LED 9 Green
    RET
SSW_G1_7:
    MOV A, R1
    MOV R2, A
    MOV A, #02H         ; Green 1 starts at P0.1
    JZ SSW_G_OUT
SSW_G_ROT: 
    RL A 
    DJNZ R2, SSW_G_ROT
SSW_G_OUT: 
    ORL P0, A           ; Apply to Port 0
    RET
    
WAIT_KEY:
WK1: 
    ACALL CHECK_MODE_CHANGE
    
    ACALL KP_SCAN 
    CJNE A, #0FFH, WK2 
    SJMP WK1
WK2: 
    RET
; --- KEYPAD SCANNER ---
KP_SCAN:
    ; 1. Ensure Column pins (P2.0-P2.3) are set as inputs
    ORL P2, #00001111B  
    ; 2. Pull all Rows (P3.0-P3.3) Low to detect any key press
    ANL P3, #11110000B  
    
    MOV A, P2
    ANL A, #00001111B   ; Read only column bits
    CJNE A, #00001111B, KS_DEB
    MOV A, #0FFH        ; No key pressed
    RET

KS_DEB:
    ACALL DELAY         ; Debounce
    ; --- Start scanning Row by Row ---
    ; Set all rows High first
    ORL P3, #00001111B  

    ; Scan Row 0 (P3.0)
    CLR P3.0
    MOV A, P2
    ANL A, #0FH
    CJNE A, #0FH, KS_R0
    SETB P3.0           ; Back to High

    ; Scan Row 1 (P3.1)
    CLR P3.1
    MOV A, P2
    ANL A, #0FH
    CJNE A, #0FH, KS_R1
    SETB P3.1

    ; Scan Row 2 (P3.2)
    CLR P3.2
    MOV A, P2
    ANL A, #0FH
    CJNE A, #0FH, KS_R2
    SETB P3.2

    ; Scan Row 3 (P3.3)
    CLR P3.3
    MOV A, P2
    ANL A, #0FH
    CJNE A, #0FH, KS_R3
    SETB P3.3

    MOV A, #0FFH        ; Ghost trigger (no key found)
    RET

KS_R0: 
    MOV R7, #0 
    SJMP KS_COL
KS_R1: 
    MOV R7, #1 
    SJMP KS_COL
KS_R2: 
    MOV R7, #2 
    SJMP KS_COL
KS_R3: 
    MOV R7, #3

KS_COL:
    ; ACC already contains P2 column data from the check above
    JB ACC.0, KS_C1 
    MOV R6, #0 
    SJMP KS_LK
KS_C1: 
    JB ACC.1, KS_C2 
    MOV R6, #1 
    SJMP KS_LK
KS_C2: 
    JB ACC.2, KS_C3 
    MOV R6, #2 
    SJMP KS_LK
KS_C3: 
    MOV R6, #3

KS_LK:
    ; Index = (Row * 4) + Column
    MOV A, R7 
    MOV B, #4 
    MUL AB 
    ADD A, R6
    MOV DPTR, #KMAP 
    MOVC A, @A+DPTR 
    MOV TA, A 

KS_REL:
    ; Wait for release: Pull rows low without touching P3.4-P3.7
    ANL P3, #11110000B  
    MOV A, P2
    ANL A, #0FH
    CJNE A, #0FH, KS_REL
    
    ACALL DELAY
    MOV A, TA           ; Return the final key value
    RET

KMAP: DB 1, 2, 3, 10, 4, 5, 6, 11, 7, 8, 9, 12, 14, 0, 15, 13

DELAY:
    MOV R3, #50
DL1:
    MOV R4, #255
DL2:
    DJNZ R4, DL2      ; This replaces the "DJNZ R4, $"
    DJNZ R3, DL1
    RET

LONG_DLY:
    MOV R2, #20
LD1:
    ACALL DELAY
    DJNZ R2, LD1
    RET

; --- SUBROUTINE: MONITOR MODE SWITCH FOR AUTO-RESET ---
CHECK_MODE_CHANGE:
    ; 1. Read physical switch state
    JB MODE_SW, SW_PHYS_PVP
    MOV A, #PVAI
    SJMP DO_MODE_SYNC
SW_PHYS_PVP:
    MOV A, #PVP

DO_MODE_SYNC:
    ; 2. Ensure the active MODE variable matches physical switch
    MOV MODE, A
    
    ; 3. Compare current switch against the "Stored" state (OLD_MODE)
    CJNE A, OLD_MODE, TRIGGER_RESET
    RET             ; No change, continue game

TRIGGER_RESET:
    ; 4. State changed! Update OLD_MODE and jump to Restart
    MOV OLD_MODE, A
    MOV SP, #70H        
    ACALL INIT_HARDWARE 
    LJMP RESTART
    
END
