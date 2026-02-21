// ============================================================================
// CHOMPER - Input Handling Module
// ============================================================================
// Reads Joystick Port 2 via CIA1 Data Port A ($DC00)
//
// Joystick bits (active low - 0 = pressed):
//   Bit 0: Up
//   Bit 1: Down
//   Bit 2: Left
//   Bit 3: Right
//   Bit 4: Fire button
//
// OPTIMIZATION: We read the joystick once per frame and store the result.
// The "desired direction" system allows the player to pre-buffer a turn,
// making the controls feel responsive (same technique as arcade Pac-Man).
// ============================================================================

// ============================================================================
// ReadJoystick - Read joystick and update desired direction
// ============================================================================
ReadJoystick:
    lda CIA1_DATA_A         // Read joystick port 2
    eor #$FF                // Invert (make 1=pressed)
    sta ZP_JOY_STATE        // Store raw state

    // Check each direction - priority: last pressed wins
    // This gives responsive feel for corner-turning

    lda ZP_JOY_STATE
    and #$08                // Right?
    beq !notRight+
    lda #DIR_RIGHT
    sta ZP_PLAYER_NEXT
    jmp !joyDone+
!notRight:

    lda ZP_JOY_STATE
    and #$04                // Left?
    beq !notLeft+
    lda #DIR_LEFT
    sta ZP_PLAYER_NEXT
    jmp !joyDone+
!notLeft:

    lda ZP_JOY_STATE
    and #$01                // Up?
    beq !notUp+
    lda #DIR_UP
    sta ZP_PLAYER_NEXT
    jmp !joyDone+
!notUp:

    lda ZP_JOY_STATE
    and #$02                // Down?
    beq !notDown+
    lda #DIR_DOWN
    sta ZP_PLAYER_NEXT
    jmp !joyDone+
!notDown:

    // No direction pressed - keep current desired direction
    // (this is the "pre-buffer" - player can press direction early)

!joyDone:

    // Check fire button for pause toggle
    lda ZP_JOY_STATE
    and #$10                // Fire button?
    beq !noFire+

    // Debounce: only trigger on transition from not-pressed to pressed
    lda FirePrevState
    bne !noFire+            // Was already pressed last frame

    // Fire button just pressed - toggle pause
    lda ZP_GAME_STATE
    cmp #STATE_PLAYING
    bne !checkUnpause+
    lda #STATE_PAUSED
    sta ZP_GAME_STATE
    jmp !fireHandled+
!checkUnpause:
    cmp #STATE_PAUSED
    bne !fireHandled+
    lda #STATE_PLAYING
    sta ZP_GAME_STATE
!fireHandled:

!noFire:
    // Store current fire state for next frame's debounce
    lda ZP_JOY_STATE
    and #$10
    sta FirePrevState

    rts

// Fire button previous state (for debouncing)
FirePrevState:
    .byte 0

// ============================================================================
// CheckKeyboard - Check for keyboard input (pause, quit)
// ============================================================================
// OPTIMIZATION: We only scan specific keys rather than full keyboard matrix
// This saves precious raster time compared to a full KERNAL scan
// ============================================================================
CheckKeyboard:
    // Scan for 'P' key (pause) - Row 2, Column 1
    lda #%11111101          // Select keyboard row 2
    sta CIA1_DATA_A
    lda CIA1_DATA_B
    and #%00000010          // Check column for 'P'
    bne !noP+
    // P pressed - toggle pause (with debounce)
    lda KeyPrevState
    bne !noP+
    lda ZP_GAME_STATE
    cmp #STATE_PLAYING
    bne !noP+
    lda #STATE_PAUSED
    sta ZP_GAME_STATE
    lda #$01
    sta KeyPrevState
    rts
!noP:

    // Scan for RunStop key (quit to title)
    lda #%01111111          // Select keyboard row 7
    sta CIA1_DATA_A
    lda CIA1_DATA_B
    and #%10000000          // Check RunStop
    bne !noRunStop+
    lda #STATE_TITLE
    sta ZP_GAME_STATE
!noRunStop:

    // Reset key debounce
    lda #$00
    sta KeyPrevState

    // Restore joystick port direction
    lda #$FF
    sta CIA1_DATA_A

    rts

KeyPrevState:
    .byte 0
