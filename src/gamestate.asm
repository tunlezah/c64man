// ============================================================================
// CHOMPER - Game State Management Module
// ============================================================================
// Handles game initialization, level transitions, and state management.
//
// GAME FLOW:
//   Title Screen -> "GET READY" -> Playing -> Level Up / Dying
//                                          -> Game Over -> Title Screen
//
// DIFFICULTY PROGRESSION:
//   Levels 1-5:   Easy - slow ghosts, long frightened time, simple mazes
//   Levels 6-10:  Medium - faster ghosts, shorter fright, more complex mazes
//   Levels 11-15: Hard - fast ghosts, brief fright, tricky mazes
//   Levels 16-20: Expert - very fast ghosts, minimal fright, devious mazes
//   Levels 21-25: Master - near-max speed, almost no fright
//   Levels 26-30: Insane - max speed, no fright, most complex mazes
// ============================================================================

// ============================================================================
// InitGameState - Full game initialization (called once at startup)
// ============================================================================
InitGameState:
    // Set initial game state to title screen
    lda #STATE_TITLE
    sta ZP_GAME_STATE

    // Clear score
    lda #0
    sta ZP_SCORE
    sta ZP_SCORE_MID
    sta ZP_SCORE_HI

    // Set default high score to 10000
    lda #$00
    sta ZP_HISCORE
    lda #$00
    sta ZP_HISCORE_MID
    lda #$01
    sta ZP_HISCORE_HI

    // Initialize other state
    lda #0
    sta ZP_LEVEL
    sta ZP_FRAME_CTR
    sta ZP_BONUS_ACTIVE
    sta ZP_WARP_FLAG
    sta ExtraLifeAwarded
    sta ZP_RNG_SEED

    lda #3
    sta ZP_LIVES

    // Show title screen
    jsr DrawTitleScreen

    // Start title music
    lda #MUSIC_TITLE
    jsr StartMusic

    rts

// ============================================================================
// StartNewGame - Begin a new game
// ============================================================================
StartNewGame:
    // Reset score and lives
    lda #0
    sta ZP_SCORE
    sta ZP_SCORE_MID
    sta ZP_SCORE_HI
    sta ZP_LEVEL
    sta ZP_BONUS_ACTIVE
    sta ExtraLifeAwarded
    sta ZP_GHOST_EAT_CT

    lda #3
    sta ZP_LIVES

    // Load first level
    jsr LoadLevel

    // Initialize player and ghosts
    jsr InitPlayer
    jsr InitGhosts

    // Show "GET READY" state
    lda #STATE_GET_READY
    sta ZP_GAME_STATE
    lda #150                // 3 seconds at 50Hz
    sta ZP_FREEZE_TIMER

    // Play level start sound
    lda #SFX_LEVEL_START
    jsr PlaySFX

    // Start gameplay music
    lda #MUSIC_GAMEPLAY
    jsr StartMusic

    rts

// ============================================================================
// LoadLevel - Load and render the current level
// ============================================================================
LoadLevel:
    // Draw the maze
    jsr DrawMaze

    // Set difficulty parameters for this level
    jsr SetDifficultyParams

    rts

// ============================================================================
// SetDifficultyParams - Configure difficulty based on current level
// ============================================================================
// Adjusts: ghost speed, frightened duration, scatter/chase timing,
//          ghost release delays, and AI aggressiveness
// ============================================================================
SetDifficultyParams:
    lda ZP_LEVEL

    // Speed tier
    cmp #5
    bcc !diffEasy+
    cmp #10
    bcc !diffMedium+
    cmp #15
    bcc !diffHard+
    cmp #20
    bcc !diffExpert+
    cmp #25
    bcc !diffMaster+

    // Levels 26-30: Insane
    lda #4
    sta ZP_DIFFICULTY
    rts

!diffMaster:
    lda #4
    sta ZP_DIFFICULTY
    rts

!diffExpert:
    lda #3
    sta ZP_DIFFICULTY
    rts

!diffHard:
    lda #2
    sta ZP_DIFFICULTY
    rts

!diffMedium:
    lda #1
    sta ZP_DIFFICULTY
    rts

!diffEasy:
    lda #0
    sta ZP_DIFFICULTY
    rts

// ============================================================================
// UpdateGetReady - Handle the "GET READY!" pre-level state
// ============================================================================
UpdateGetReady:
    dec ZP_FREEZE_TIMER
    lda ZP_FREEZE_TIMER
    bne !stillWaiting+

    // Timer expired - start playing
    lda #STATE_PLAYING
    sta ZP_GAME_STATE
    rts

!stillWaiting:
    // Display "GET READY!" text in center of screen
    // Only draw text once (when timer is at 149)
    cmp #149
    bne !readyWait+

    // Draw "GET READY!" at screen center (row 12)
    // Row 12, starting at column 13 (for centering)
    lda #61                 // 'G'
    sta SCREEN_RAM + 12*40 + 15
    lda #38                 // 'E'
    sta SCREEN_RAM + 12*40 + 16
    lda #62                 // 'T'
    sta SCREEN_RAM + 12*40 + 17
    lda #CHR_EMPTY
    sta SCREEN_RAM + 12*40 + 18
    lda #39                 // 'R'
    sta SCREEN_RAM + 12*40 + 19
    lda #38                 // 'E'
    sta SCREEN_RAM + 12*40 + 20
    lda #59                 // 'A'
    sta SCREEN_RAM + 12*40 + 21
    lda #60                 // 'D'
    sta SCREEN_RAM + 12*40 + 22
    lda #63                 // 'Y'
    sta SCREEN_RAM + 12*40 + 23

    // Color the text yellow
    lda #COL_YELLOW
    ldx #0
!readyColor:
    sta COLOR_RAM + 12*40 + 15,x
    inx
    cpx #9
    bne !readyColor-

!readyWait:
    // Clear "GET READY!" text halfway through
    lda ZP_FREEZE_TIMER
    cmp #10
    bne !noReadyClear+
    ldx #0
    lda #CHR_EMPTY
!clearReady:
    sta SCREEN_RAM + 12*40 + 15,x
    inx
    cpx #9
    bne !clearReady-
!noReadyClear:
    rts

// ============================================================================
// UpdateLevelTransition - Handle level completion animation
// ============================================================================
UpdateLevelTransition:
    // First time: set up the animation
    lda ZP_FREEZE_TIMER
    bne !animRunning+

    // Initialize level complete animation
    lda #100                // 2 seconds
    sta ZP_FREEZE_TIMER

    // Play level complete sound
    lda #SFX_LEVEL_DONE
    jsr PlaySFX

    // Hide ghost sprites during animation
    lda #%00000001          // Only player sprite visible
    sta VIC_SPR_ENABLE

!animRunning:
    dec ZP_FREEZE_TIMER
    lda ZP_FREEZE_TIMER
    bne !levelAnimating+

    // Animation complete - advance to next level
    inc ZP_LEVEL
    lda ZP_LEVEL
    cmp #30                 // Check if all 30 levels completed
    bcc !moreLevels+

    // All levels beaten! Show victory and loop back
    lda #29                 // Stay on level 30 (0-indexed: 29)
    sta ZP_LEVEL

!moreLevels:
    // Load new level
    jsr LoadLevel
    jsr InitPlayer
    jsr InitGhosts

    // Reset bonus and extra life tracking for new level
    lda #0
    sta ZP_BONUS_ACTIVE
    sta ExtraLifeAwarded

    // Show "GET READY"
    lda #STATE_GET_READY
    sta ZP_GAME_STATE
    lda #150
    sta ZP_FREEZE_TIMER

    // Re-enable all sprites
    lda #%00011111
    sta VIC_SPR_ENABLE

    rts

!levelAnimating:
    // Flash the maze walls during level complete
    lda ZP_FREEZE_TIMER
    and #$04
    beq !wallsNormal+

    // Flash walls to white
    lda #COL_WHITE
    sta VIC_BGCOLOR1
    rts

!wallsNormal:
    lda #COL_BLUE
    sta VIC_BGCOLOR1
    rts

// ============================================================================
// UpdateGameOver - Handle game over screen
// ============================================================================
UpdateGameOver:
    // First frame: set up game over display
    lda ZP_FREEZE_TIMER
    bne !goAnimating+

    // Initialize game over
    lda #250                // 5 seconds
    sta ZP_FREEZE_TIMER

    // Display "GAME OVER" text at screen center
    // G A M E   O V E R
    lda #61                 // 'G'
    sta SCREEN_RAM + 12*40 + 14
    lda #59                 // 'A'
    sta SCREEN_RAM + 12*40 + 15
    lda #36                 // 'M'
    sta SCREEN_RAM + 12*40 + 16
    lda #38                 // 'E'
    sta SCREEN_RAM + 12*40 + 17
    lda #CHR_EMPTY
    sta SCREEN_RAM + 12*40 + 18
    lda #35                 // 'O'
    sta SCREEN_RAM + 12*40 + 19
    lda #46                 // 'V'
    sta SCREEN_RAM + 12*40 + 20
    lda #38                 // 'E'
    sta SCREEN_RAM + 12*40 + 21
    lda #39                 // 'R'
    sta SCREEN_RAM + 12*40 + 22

    // Color red
    lda #COL_RED
    ldx #0
!goColor:
    sta COLOR_RAM + 12*40 + 14,x
    inx
    cpx #9
    bne !goColor-

    // Stop music
    lda #0
    sta MusicPlaying

    // Hide sprites
    lda #$00
    sta VIC_SPR_ENABLE

!goAnimating:
    dec ZP_FREEZE_TIMER
    lda ZP_FREEZE_TIMER
    bne !goWait+

    // Return to title screen
    lda #STATE_TITLE
    sta ZP_GAME_STATE
    jsr DrawTitleScreen
    lda #MUSIC_TITLE
    jsr StartMusic

!goWait:
    rts

// ============================================================================
// UpdateTitleScreen - Handle title screen input
// ============================================================================
UpdateTitleScreen:
    // Animate title (color cycling)
    lda ZP_FRAME_CTR
    lsr
    lsr
    lsr                     // Change every 8 frames
    and #$07
    tax
    lda TitleColorCycle,x

    // Apply to CHOMPER title letters
    ldx #0
!titleColor:
    sta COLOR_RAM + 3*40 + 14,x
    inx
    cpx #7                  // "CHOMPER" = 7 chars
    bne !titleColor-

    // Blink "PRESS FIRE" text
    lda ZP_FRAME_CTR
    and #$20
    beq !showPressfire+

    // Hide press fire text
    ldx #0
    lda #CHR_EMPTY
!hidePF:
    sta SCREEN_RAM + 18*40 + 12,x
    inx
    cpx #16
    bne !hidePF-
    jmp !checkFire+

!showPressfire:
    // Show "PRESS FIRE" (using available chars)
    lda #37                 // 'P'
    sta SCREEN_RAM + 18*40 + 14
    lda #39                 // 'R'
    sta SCREEN_RAM + 18*40 + 15
    lda #38                 // 'E'
    sta SCREEN_RAM + 18*40 + 16
    lda #43                 // 'S'
    sta SCREEN_RAM + 18*40 + 17
    lda #43                 // 'S'
    sta SCREEN_RAM + 18*40 + 18
    lda #CHR_EMPTY
    sta SCREEN_RAM + 18*40 + 19
    lda #33+29              // 'F' (approximate using available chars)
    sta SCREEN_RAM + 18*40 + 20
    lda #44                 // 'I'
    sta SCREEN_RAM + 18*40 + 21
    lda #39                 // 'R'
    sta SCREEN_RAM + 18*40 + 22
    lda #38                 // 'E'
    sta SCREEN_RAM + 18*40 + 23

    lda #COL_LIGHT_GREEN
    ldx #0
!pfColor:
    sta COLOR_RAM + 18*40 + 14,x
    inx
    cpx #10
    bne !pfColor-

!checkFire:
    // Check for fire button to start game
    lda CIA1_DATA_A
    eor #$FF
    and #$10                // Fire button
    beq !noStart+

    jsr StartNewGame

!noStart:
    rts

// Title color cycle
TitleColorCycle:
    .byte COL_YELLOW, COL_ORANGE, COL_RED, COL_LIGHT_RED
    .byte COL_PURPLE, COL_LIGHT_BLUE, COL_CYAN, COL_WHITE
