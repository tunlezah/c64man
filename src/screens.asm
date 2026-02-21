// ============================================================================
// CHOMPER - Screen Layouts Module
// ============================================================================
// Contains pre-built screen layouts for title screen and intermission screens.
//
// TITLE SCREEN LAYOUT:
//   Rows 0-1:   (empty/border)
//   Rows 2-5:   CHOMPER logo (large characters)
//   Rows 6-7:   (empty)
//   Rows 8-10:  Animated Chomper chasing a Spectre
//   Rows 11-12: (empty)
//   Rows 13-14: "A COSMIC MAZE ADVENTURE"
//   Rows 15-16: (empty)
//   Rows 17-18: High Score display
//   Rows 19-20: "PRESS FIRE TO START"
//   Rows 21-22: (empty)
//   Rows 23-24: Credits / copyright
// ============================================================================

// ============================================================================
// DrawTitleScreen - Render the title screen
// ============================================================================
DrawTitleScreen:
    // Clear screen
    jsr ClearScreen

    // Set title screen colors
    lda #COL_BLACK
    sta VIC_BORDER
    sta VIC_BGCOLOR0
    lda #COL_BLUE
    sta VIC_BGCOLOR1

    // ---- Draw CHOMPER title ----
    // Using custom title characters (33-39 = C,H,O,M,P,E,R)
    // Row 3, centered

    // "CHOMPER" at row 3, columns 14-20 (centered in 40 cols)
    lda #33                 // 'C'
    sta SCREEN_RAM + 3*40 + 14
    lda #34                 // 'H'
    sta SCREEN_RAM + 3*40 + 15
    lda #35                 // 'O'
    sta SCREEN_RAM + 3*40 + 16
    lda #36                 // 'M'
    sta SCREEN_RAM + 3*40 + 17
    lda #37                 // 'P'
    sta SCREEN_RAM + 3*40 + 18
    lda #38                 // 'E'
    sta SCREEN_RAM + 3*40 + 19
    lda #39                 // 'R'
    sta SCREEN_RAM + 3*40 + 20

    // Title color
    lda #COL_YELLOW
    ldx #0
!tColor:
    sta COLOR_RAM + 3*40 + 14,x
    inx
    cpx #7
    bne !tColor-

    // ---- Chomper icon (big mouth character) ----
    lda #40                 // Chomper logo mouth open
    sta SCREEN_RAM + 3*40 + 12
    lda #COL_YELLOW
    sta COLOR_RAM + 3*40 + 12

    // Ghost icon on other side
    lda #42                 // Ghost icon
    sta SCREEN_RAM + 3*40 + 22
    lda #COL_RED
    sta COLOR_RAM + 3*40 + 22

    // ---- Row of dots (decorative) ----
    ldx #0
!dotsRow:
    lda #CHR_DOT
    sta SCREEN_RAM + 5*40 + 6,x
    lda #COL_WHITE
    sta COLOR_RAM + 5*40 + 6,x
    inx
    cpx #28
    bne !dotsRow-

    // ---- Subtitle: use remaining chars to spell descriptive text ----
    // "A COSMIC MAZE" approximation using available characters
    // Row 8 - we'll show the ghost character descriptions instead

    // ---- Ghost presentation (Row 8-11) ----
    // Show each ghost with its name and color

    // Row 8: "SPECTRES" header
    lda #43                 // 'S'
    sta SCREEN_RAM + 8*40 + 15
    lda #37                 // 'P'
    sta SCREEN_RAM + 8*40 + 16
    lda #38                 // 'E'
    sta SCREEN_RAM + 8*40 + 17
    lda #33                 // 'C'
    sta SCREEN_RAM + 8*40 + 18
    lda #62                 // 'T'
    sta SCREEN_RAM + 8*40 + 19
    lda #39                 // 'R'
    sta SCREEN_RAM + 8*40 + 20
    lda #38                 // 'E'
    sta SCREEN_RAM + 8*40 + 21
    lda #43                 // 'S'
    sta SCREEN_RAM + 8*40 + 22

    lda #COL_LIGHT_GREY
    ldx #0
!specColor:
    sta COLOR_RAM + 8*40 + 15,x
    inx
    cpx #8
    bne !specColor-

    // Row 10: Red ghost icon + "SHADE"
    lda #42
    sta SCREEN_RAM + 10*40 + 12
    lda #COL_RED
    sta COLOR_RAM + 10*40 + 12

    lda #43                 // 'S'
    sta SCREEN_RAM + 10*40 + 14
    lda #34                 // 'H'
    sta SCREEN_RAM + 10*40 + 15
    lda #59                 // 'A'
    sta SCREEN_RAM + 10*40 + 16
    lda #60                 // 'D'
    sta SCREEN_RAM + 10*40 + 17
    lda #38                 // 'E'
    sta SCREEN_RAM + 10*40 + 18
    lda #COL_RED
    ldx #0
!shadeC:
    sta COLOR_RAM + 10*40 + 14,x
    inx
    cpx #5
    bne !shadeC-

    // Row 11: Cyan ghost icon + "GLIMMER"
    lda #42
    sta SCREEN_RAM + 11*40 + 12
    lda #COL_CYAN
    sta COLOR_RAM + 11*40 + 12

    lda #61                 // 'G'
    sta SCREEN_RAM + 11*40 + 14
    lda #45                 // 'L'
    sta SCREEN_RAM + 11*40 + 15
    lda #44                 // 'I'
    sta SCREEN_RAM + 11*40 + 16
    lda #36                 // 'M'
    sta SCREEN_RAM + 11*40 + 17
    lda #36                 // 'M'
    sta SCREEN_RAM + 11*40 + 18
    lda #38                 // 'E'
    sta SCREEN_RAM + 11*40 + 19
    lda #39                 // 'R'
    sta SCREEN_RAM + 11*40 + 20
    lda #COL_CYAN
    ldx #0
!glimC:
    sta COLOR_RAM + 11*40 + 14,x
    inx
    cpx #7
    bne !glimC-

    // Row 12: Purple ghost icon + "PHANTOM"
    lda #42
    sta SCREEN_RAM + 12*40 + 12
    lda #COL_PURPLE
    sta COLOR_RAM + 12*40 + 12

    lda #37                 // 'P'
    sta SCREEN_RAM + 12*40 + 14
    lda #34                 // 'H'
    sta SCREEN_RAM + 12*40 + 15
    lda #59                 // 'A'
    sta SCREEN_RAM + 12*40 + 16
    lda #47                 // 'N'
    sta SCREEN_RAM + 12*40 + 17
    lda #62                 // 'T'
    sta SCREEN_RAM + 12*40 + 18
    lda #35                 // 'O'
    sta SCREEN_RAM + 12*40 + 19
    lda #36                 // 'M'
    sta SCREEN_RAM + 12*40 + 20
    lda #COL_PURPLE
    ldx #0
!phantC:
    sta COLOR_RAM + 12*40 + 14,x
    inx
    cpx #7
    bne !phantC-

    // Row 13: Orange ghost icon + "EMBER"
    lda #42
    sta SCREEN_RAM + 13*40 + 12
    lda #COL_ORANGE
    sta COLOR_RAM + 13*40 + 12

    lda #38                 // 'E'
    sta SCREEN_RAM + 13*40 + 14
    lda #36                 // 'M'
    sta SCREEN_RAM + 13*40 + 15
    lda #33+29              // 'B' (approximate)
    sta SCREEN_RAM + 13*40 + 16
    lda #38                 // 'E'
    sta SCREEN_RAM + 13*40 + 17
    lda #39                 // 'R'
    sta SCREEN_RAM + 13*40 + 18
    lda #COL_ORANGE
    ldx #0
!embC:
    sta COLOR_RAM + 13*40 + 14,x
    inx
    cpx #5
    bne !embC-

    // ---- High Score display (Row 16) ----
    lda #34                 // 'H'
    sta SCREEN_RAM + 16*40 + 13
    lda #44                 // 'I'
    sta SCREEN_RAM + 16*40 + 14
    lda #COL_WHITE
    sta COLOR_RAM + 16*40 + 13
    sta COLOR_RAM + 16*40 + 14

    // High score digits at row 16
    lda ZP_HISCORE_HI
    lsr
    lsr
    lsr
    lsr
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM + 16*40 + 16
    lda ZP_HISCORE_HI
    and #$0F
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM + 16*40 + 17
    lda ZP_HISCORE_MID
    lsr
    lsr
    lsr
    lsr
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM + 16*40 + 18
    lda ZP_HISCORE_MID
    and #$0F
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM + 16*40 + 19
    lda ZP_HISCORE
    lsr
    lsr
    lsr
    lsr
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM + 16*40 + 20
    lda ZP_HISCORE
    and #$0F
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM + 16*40 + 21

    lda #COL_CYAN
    ldx #0
!hiScColor:
    sta COLOR_RAM + 16*40 + 16,x
    inx
    cpx #6
    bne !hiScColor-

    // ---- "PRESS FIRE" will be animated by UpdateTitleScreen ----
    // (blinking effect handled in gamestate.asm)

    // ---- Bottom row: Year/credit ----
    // "2026" at bottom
    lda #50                 // '2'
    sta SCREEN_RAM + 23*40 + 17
    lda #48                 // '0'
    sta SCREEN_RAM + 23*40 + 18
    lda #50                 // '2'
    sta SCREEN_RAM + 23*40 + 19
    lda #54                 // '6'
    sta SCREEN_RAM + 23*40 + 20

    lda #COL_DARK_GREY
    sta COLOR_RAM + 23*40 + 17
    sta COLOR_RAM + 23*40 + 18
    sta COLOR_RAM + 23*40 + 19
    sta COLOR_RAM + 23*40 + 20

    // Enable sprites for title screen animation
    lda #%00000011          // Sprites 0 and 1 only
    sta VIC_SPR_ENABLE

    // Position sprites for title animation (chomper chasing ghost)
    lda #60
    sta VIC_SPR0_X
    lda #100
    sta VIC_SPR1_X
    lda #115                // Row 7ish in pixels
    sta VIC_SPR0_Y
    sta VIC_SPR1_Y

    // Set sprite frames
    lda #160                // Chomper right
    sta SCREEN_RAM+$03F8
    lda #165                // Ghost frame 1
    sta SCREEN_RAM+$03F9

    lda #COL_YELLOW
    sta VIC_SPR0_COLOR
    lda #COL_RED
    sta VIC_SPR1_COLOR

    rts
