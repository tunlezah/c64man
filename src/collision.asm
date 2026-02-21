// ============================================================================
// CHOMPER - Collision Detection Module
// ============================================================================
// Handles player-ghost collisions using tile-based distance checks.
//
// OPTIMIZATION: Instead of using VIC-II hardware sprite collision
// (which is imprecise and has timing issues), we use tile-position
// comparison which is both faster and more accurate.
//
// When player and ghost occupy the same tile:
//   - Normal/Chase mode: Player dies
//   - Frightened mode: Ghost is eaten (200/400/800/1600 points)
// ============================================================================

// Score values for eating ghosts (BCD, doubles each time)
GhostScoreTable:
    .byte $02, $00          // 200
    .byte $04, $00          // 400
    .byte $08, $00          // 800
    .byte $16, $00          // 1600

// ============================================================================
// CheckCollisions - Main collision check
// ============================================================================
CheckCollisions:
    ldy #0                  // Ghost data offset
    ldx #0                  // Ghost index

!collLoop:
    // Only check active ghosts (not in house or leaving)
    lda ZP_GHOST_DATA+3,y
    cmp #3                  // In house?
    beq !collSkip+
    cmp #4                  // Leaving house?
    beq !collSkip+
    cmp #2                  // Already eaten (eyes)?
    beq !collSkip+

    // Check if player and ghost are on the same tile
    lda ZP_PLAYER_X
    cmp ZP_GHOST_DATA+0,y
    bne !collSkip+
    lda ZP_PLAYER_Y
    cmp ZP_GHOST_DATA+1,y
    bne !collSkip+

    // COLLISION! Check ghost state
    lda ZP_GHOST_DATA+3,y
    cmp #1                  // Frightened?
    beq !eatGhost+

    // Ghost is normal - player dies
    jmp PlayerDies

!eatGhost:
    // Player eats frightened ghost!
    jsr EatGhost

!collSkip:
    tya
    clc
    adc #GHOST_STRIDE
    tay
    inx
    cpx #4
    bne !collLoop-

    rts

// ============================================================================
// EatGhost - Player eats a frightened ghost
// ============================================================================
// Scores 200, 400, 800, 1600 for successive ghosts eaten per power pellet
// ============================================================================
EatGhost:
    // Set ghost to "eaten" state (eyes return home)
    lda #2
    sta ZP_GHOST_DATA+3,y

    // Award progressive points
    lda ZP_GHOST_EAT_CT
    asl                     // x2 (each entry is 2 bytes)
    tax

    // Add score (BCD addition)
    sed                     // Enable BCD mode
    lda ZP_SCORE
    clc
    adc GhostScoreTable,x
    sta ZP_SCORE
    lda ZP_SCORE_MID
    adc GhostScoreTable+1,x
    sta ZP_SCORE_MID
    lda ZP_SCORE_HI
    adc #0
    sta ZP_SCORE_HI
    cld                     // Disable BCD mode

    // Increment consecutive ghost counter (max 3)
    lda ZP_GHOST_EAT_CT
    cmp #3
    bcs !maxEats+
    inc ZP_GHOST_EAT_CT
!maxEats:

    // Brief freeze for score display
    lda #30                 // 30 frames (~0.6 seconds)
    sta ZP_FREEZE_TIMER

    // Check for high score update
    jsr CheckHighScore

    // Play ghost eat sound
    lda #SFX_EAT_GHOST
    jsr PlaySFX

    // Check for extra life at 10000 points
    jsr CheckExtraLife

    rts

// ============================================================================
// PlayerDies - Handle player death
// ============================================================================
PlayerDies:
    lda #STATE_DYING
    sta ZP_GAME_STATE

    // Set death animation timer
    lda #0
    sta DeathAnimFrame
    lda #120                // 120 frames for death animation (~2.4s)
    sta ZP_FREEZE_TIMER

    // Play death sound
    lda #SFX_DEATH
    jsr PlaySFX

    rts

DeathAnimFrame:
    .byte 0

// ============================================================================
// UpdateDeathAnimation - Animate player death
// ============================================================================
UpdateDeathAnimation:
    dec ZP_FREEZE_TIMER
    lda ZP_FREEZE_TIMER
    bne !animating+

    // Death animation finished
    dec ZP_LIVES
    lda ZP_LIVES
    bmi !gameOver+

    // Still have lives - restart level
    jsr InitPlayer
    jsr InitGhosts
    lda #STATE_GET_READY
    sta ZP_GAME_STATE
    lda #100                // "GET READY" display timer
    sta ZP_FREEZE_TIMER
    rts

!gameOver:
    lda #STATE_GAME_OVER
    sta ZP_GAME_STATE
    lda #0
    sta ZP_LIVES            // Clamp to 0
    rts

!animating:
    // Update death sprite frame based on timer
    lda ZP_FREEZE_TIMER
    lsr
    lsr
    lsr
    lsr                     // Divide by 16 for frame index
    and #$03
    tax
    lda DeathSpriteFrames,x
    // Update sprite 0 pointer
    sta SCREEN_RAM+$03F8    // Sprite 0 pointer location

    rts

// Death animation sprite frame sequence
DeathSpriteFrames:
    .byte 170, 171, 172, 173   // Death1-4 sprite pointers

// ============================================================================
// CheckExtraLife - Award extra life at 10000 points
// ============================================================================
CheckExtraLife:
    // Check if score crossed 10000 (check hi byte of BCD score)
    lda ZP_SCORE_HI
    cmp #$01
    bcc !noExtra+
    lda ExtraLifeAwarded
    bne !noExtra+           // Already awarded

    // Award extra life!
    inc ZP_LIVES
    lda #1
    sta ExtraLifeAwarded

    // Play extra life sound
    lda #SFX_EXTRA_LIFE
    jsr PlaySFX

!noExtra:
    rts

ExtraLifeAwarded:
    .byte 0

// ============================================================================
// CheckHighScore - Update high score if current score exceeds it
// ============================================================================
CheckHighScore:
    // Compare BCD scores (hi byte first)
    lda ZP_SCORE_HI
    cmp ZP_HISCORE_HI
    bcc !noNewHi+
    bne !newHi+
    lda ZP_SCORE_MID
    cmp ZP_HISCORE_MID
    bcc !noNewHi+
    bne !newHi+
    lda ZP_SCORE
    cmp ZP_HISCORE
    bcc !noNewHi+

!newHi:
    lda ZP_SCORE
    sta ZP_HISCORE
    lda ZP_SCORE_MID
    sta ZP_HISCORE_MID
    lda ZP_SCORE_HI
    sta ZP_HISCORE_HI

!noNewHi:
    rts

// ============================================================================
// AddScore10 - Add 10 points (BCD)
// ============================================================================
AddScore10:
    sed
    lda ZP_SCORE
    clc
    adc #$10
    sta ZP_SCORE
    lda ZP_SCORE_MID
    adc #0
    sta ZP_SCORE_MID
    lda ZP_SCORE_HI
    adc #0
    sta ZP_SCORE_HI
    cld
    jsr CheckHighScore
    rts

// ============================================================================
// AddScore50 - Add 50 points (BCD)
// ============================================================================
AddScore50:
    sed
    lda ZP_SCORE
    clc
    adc #$50
    sta ZP_SCORE
    lda ZP_SCORE_MID
    adc #0
    sta ZP_SCORE_MID
    lda ZP_SCORE_HI
    adc #0
    sta ZP_SCORE_HI
    cld
    jsr CheckHighScore
    rts
