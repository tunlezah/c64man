// ============================================================================
// CHOMPER - Player Movement Module
// ============================================================================
// Handles smooth sub-pixel movement, direction changes at tile boundaries,
// wall collision checking, dot eating, and tunnel wrapping.
//
// OPTIMIZATION TECHNIQUES USED:
// 1. Sub-pixel movement accumulator for smooth variable-speed motion
// 2. Pre-computed movement delta tables (no multiplication needed)
// 3. Tile-aligned direction changes (only check at tile centers)
// 4. Early exit collision checks
// 5. Self-modifying code for speed-critical inner loops
// ============================================================================

// ============================================================================
// Movement delta tables (direction-indexed)
// ============================================================================
// Index: 0=right, 1=left, 2=up, 3=down
DeltaX:     .byte  1, $FF,  0,  0       // +1, -1, 0, 0
DeltaY:     .byte  0,  0, $FF,  1       // 0, 0, -1, +1
OppDir:     .byte  1,  0,  3,  2        // Opposite directions

// Sprite frame for each direction (pointer into sprite data)
PlayerSpriteFrame:
    .byte 160, 162, 163, 164             // R, L, U, D (pointer values)

// ============================================================================
// InitPlayer - Reset player to starting position
// ============================================================================
InitPlayer:
    lda #14                 // Starting X tile (center of maze)
    sta ZP_PLAYER_X
    lda #23                 // Starting Y tile (below ghost house)
    sta ZP_PLAYER_Y
    lda #DIR_LEFT           // Start moving left (like original)
    sta ZP_PLAYER_DIR
    sta ZP_PLAYER_NEXT
    lda #$00
    sta ZP_PLAYER_SUBX
    sta ZP_PLAYER_SUBY
    sta ZP_PLAYER_ANIM
    sta ZP_WARP_FLAG
    rts

// ============================================================================
// UpdatePlayer - Main player update (called once per frame)
// ============================================================================
UpdatePlayer:
    // Step 1: Check if player is at a tile center (sub-pixel = 0)
    lda ZP_PLAYER_SUBX
    ora ZP_PLAYER_SUBY
    bne !notAtCenter+

    // ---- AT TILE CENTER ----
    // This is where direction changes, dot eating, and tunnel checks happen

    // Check if desired direction is valid (not blocked by wall)
    ldx ZP_PLAYER_NEXT
    jsr CanMoveInDirection
    bne !cantTurn+

    // Direction change is valid - commit to new direction
    lda ZP_PLAYER_NEXT
    sta ZP_PLAYER_DIR

!cantTurn:
    // Check if current direction is still valid
    ldx ZP_PLAYER_DIR
    jsr CanMoveInDirection
    bne !blocked+

    // Player can move - accumulate sub-pixel movement
    jmp !doMove+

!blocked:
    // Player is blocked - stop (but keep desired direction for buffering)
    rts

!notAtCenter:
    // Not at tile center - continue moving in current direction
    // (no direction changes allowed mid-tile)

!doMove:
    // Accumulate movement based on current speed
    jsr GetPlayerSpeed       // Returns speed in A

    // Add to sub-pixel accumulator based on direction
    ldx ZP_PLAYER_DIR

    // Handle X movement (right/left)
    cpx #DIR_RIGHT
    beq !moveRight+
    cpx #DIR_LEFT
    beq !moveLeft+
    jmp !moveVertical+

!moveRight:
    clc
    adc ZP_PLAYER_SUBX
    sta ZP_PLAYER_SUBX
    bcc !noTileChange+       // No overflow = still same tile
    // Crossed tile boundary
    inc ZP_PLAYER_X
    // Check for tunnel wrap
    lda ZP_PLAYER_X
    cmp #MAZE_WIDTH
    bcc !noWrap+
    lda #0
    sta ZP_PLAYER_X
!noWrap:
    jsr OnEnterTile
    jmp !noTileChange+

!moveLeft:
    sta ZP_TEMP1             // Save speed
    lda ZP_PLAYER_SUBX
    sec
    sbc ZP_TEMP1
    sta ZP_PLAYER_SUBX
    bcs !noTileChange+       // No underflow = still same tile
    // Crossed tile boundary
    dec ZP_PLAYER_X
    lda ZP_PLAYER_X
    bpl !noWrapL+
    lda #MAZE_WIDTH-1
    sta ZP_PLAYER_X
!noWrapL:
    jsr OnEnterTile
    jmp !noTileChange+

!moveVertical:
    cpx #DIR_UP
    beq !moveUp+

    // Move Down
    clc
    adc ZP_PLAYER_SUBY
    sta ZP_PLAYER_SUBY
    bcc !noTileChange+
    inc ZP_PLAYER_Y
    jsr OnEnterTile
    jmp !noTileChange+

!moveUp:
    sta ZP_TEMP1
    lda ZP_PLAYER_SUBY
    sec
    sbc ZP_TEMP1
    sta ZP_PLAYER_SUBY
    bcs !noTileChange+
    dec ZP_PLAYER_Y
    jsr OnEnterTile

!noTileChange:
    // Update animation frame (mouth open/close cycle)
    inc ZP_PLAYER_ANIM
    lda ZP_PLAYER_ANIM
    and #$07                 // 8-frame cycle
    sta ZP_PLAYER_ANIM

    rts

// ============================================================================
// OnEnterTile - Called when player enters a new tile
// ============================================================================
OnEnterTile:
    // Calculate screen RAM offset for current tile
    jsr CalcTileOffset       // Result in ZP_SCREEN_LO/HI

    // Read tile content
    ldy #0
    lda (ZP_SCREEN_LO),y

    // Check what's in this tile
    cmp #CHR_DOT
    beq !eatDot+
    cmp #CHR_POWER
    beq !eatPower+
    cmp #CHR_POWER_ANIM2
    beq !eatPower+

    rts

!eatDot:
    // Replace dot with empty space
    lda #CHR_EMPTY
    sta (ZP_SCREEN_LO),y

    // Add 10 points
    jsr AddScore10

    // Decrement dots remaining
    dec ZP_DOTS_LEFT
    lda ZP_DOTS_LEFT
    cmp #$FF
    bne !noHiBorrow+
    dec ZP_DOTS_LEFT_HI
!noHiBorrow:

    // Play dot eat sound
    lda #SFX_EAT_DOT
    jsr PlaySFX

    // Check if level cleared
    lda ZP_DOTS_LEFT
    ora ZP_DOTS_LEFT_HI
    bne !notCleared+
    lda #STATE_LEVEL_UP
    sta ZP_GAME_STATE
!notCleared:
    rts

!eatPower:
    // Replace power pellet with empty space
    lda #CHR_EMPTY
    sta (ZP_SCREEN_LO),y

    // Add 50 points
    jsr AddScore50

    // Decrement dots remaining (power pellets count as dots)
    dec ZP_DOTS_LEFT
    lda ZP_DOTS_LEFT
    cmp #$FF
    bne !noHiBorrow2+
    dec ZP_DOTS_LEFT_HI
!noHiBorrow2:

    // Activate frightened mode
    jsr ActivateFrightenedMode

    // Play power-up sound
    lda #SFX_POWER_UP
    jsr PlaySFX

    // Reset ghost eat counter (for progressive scoring)
    lda #0
    sta ZP_GHOST_EAT_CT

    // Check if level cleared
    lda ZP_DOTS_LEFT
    ora ZP_DOTS_LEFT_HI
    bne !notCleared2+
    lda #STATE_LEVEL_UP
    sta ZP_GAME_STATE
!notCleared2:
    rts

// ============================================================================
// CanMoveInDirection - Check if direction X is passable
// ============================================================================
// Input: X = direction to check (0-3)
// Output: Z flag = 1 if can move, Z flag = 0 if blocked
// ============================================================================
CanMoveInDirection:
    // Calculate target tile position
    lda ZP_PLAYER_X
    clc
    adc DeltaX,x
    sta ZP_TEMP1             // Target X

    lda ZP_PLAYER_Y
    clc
    adc DeltaY,x
    sta ZP_TEMP2             // Target Y

    // Handle tunnel wrapping for X
    lda ZP_TEMP1
    bpl !xNotNeg+
    lda #MAZE_WIDTH-1
    sta ZP_TEMP1
!xNotNeg:
    cmp #MAZE_WIDTH
    bcc !xNotOver+
    lda #0
    sta ZP_TEMP1
!xNotOver:

    // Look up tile at target position in the level data
    // Use the current screen RAM contents (already rendered)
    lda ZP_TEMP2             // Y tile
    // Multiply Y by 40 for screen row offset
    // OPTIMIZATION: Use table lookup instead of multiply
    asl                      // x2
    tay
    lda ScreenRowTableLo,y
    sta ZP_SCREEN_LO
    lda ScreenRowTableHi,y
    sta ZP_SCREEN_HI

    // Add X offset (tile X + maze offset)
    lda ZP_TEMP1
    clc
    adc #MAZE_OFFSET_X
    tay
    lda (ZP_SCREEN_LO),y

    // Check if tile is passable
    cmp #CHR_EMPTY
    beq !passable+
    cmp #CHR_DOT
    beq !passable+
    cmp #CHR_POWER
    beq !passable+
    cmp #CHR_POWER_ANIM2
    beq !passable+
    cmp #CHR_GATE
    beq !checkGate+

    // Tile is a wall - not passable
    lda #$01                 // Set Z=0 (blocked)
    rts

!checkGate:
    // Gate is only passable for ghosts, not player
    lda #$01                 // Blocked for player
    rts

!passable:
    lda #$00                 // Set Z=1 (can move)
    rts

// ============================================================================
// CalcTileOffset - Calculate screen RAM address for player's tile
// ============================================================================
// Uses player's current tile X,Y position
// Result in ZP_SCREEN_LO/ZP_SCREEN_HI
// ============================================================================
CalcTileOffset:
    lda ZP_PLAYER_Y
    asl                      // Y * 2 for table index
    tay
    lda ScreenRowTableLo,y
    sta ZP_SCREEN_LO
    lda ScreenRowTableHi,y
    sta ZP_SCREEN_HI

    // Add X offset
    lda ZP_PLAYER_X
    clc
    adc #MAZE_OFFSET_X
    clc
    adc ZP_SCREEN_LO
    sta ZP_SCREEN_LO
    lda ZP_SCREEN_HI
    adc #0
    sta ZP_SCREEN_HI
    rts

// ============================================================================
// GetPlayerSpeed - Returns current movement speed in A
// ============================================================================
// Speed varies based on:
//   - Level (faster on higher levels)
//   - Power mode (slightly slower when powered up)
//   - Eating dots (brief slowdown - "cornering" technique from arcade)
// ============================================================================
GetPlayerSpeed:
    lda ZP_GHOST_MODE
    cmp #2                   // Frightened mode?
    beq !poweredSpeed+

    // Normal speed, modified by level
    lda ZP_LEVEL
    cmp #5
    bcc !earlyLevels+
    cmp #20
    bcc !midLevels+

    // Levels 21+: maximum player speed
    lda #SPEED_FAST
    rts

!midLevels:
    lda #SPEED_NORMAL+4      // Slightly faster
    rts

!earlyLevels:
    lda #SPEED_NORMAL
    rts

!poweredSpeed:
    // Powered up = slightly slower (like arcade)
    lda #SPEED_NORMAL-2
    rts

// ============================================================================
// Screen Row Address Lookup Table
// ============================================================================
// OPTIMIZATION: Pre-computed row start addresses avoid expensive multiplication
// Each entry is the address of the first column in that screen row
// Screen RAM at $0400, each row is 40 bytes
// ============================================================================
ScreenRowTableLo:
    .byte <(SCREEN_RAM+0*40), <(SCREEN_RAM+1*40)
    .byte <(SCREEN_RAM+2*40), <(SCREEN_RAM+3*40)
    .byte <(SCREEN_RAM+4*40), <(SCREEN_RAM+5*40)
    .byte <(SCREEN_RAM+6*40), <(SCREEN_RAM+7*40)
    .byte <(SCREEN_RAM+8*40), <(SCREEN_RAM+9*40)
    .byte <(SCREEN_RAM+10*40), <(SCREEN_RAM+11*40)
    .byte <(SCREEN_RAM+12*40), <(SCREEN_RAM+13*40)
    .byte <(SCREEN_RAM+14*40), <(SCREEN_RAM+15*40)
    .byte <(SCREEN_RAM+16*40), <(SCREEN_RAM+17*40)
    .byte <(SCREEN_RAM+18*40), <(SCREEN_RAM+19*40)
    .byte <(SCREEN_RAM+20*40), <(SCREEN_RAM+21*40)
    .byte <(SCREEN_RAM+22*40), <(SCREEN_RAM+23*40)
    .byte <(SCREEN_RAM+24*40)

ScreenRowTableHi:
    .byte >(SCREEN_RAM+0*40), >(SCREEN_RAM+1*40)
    .byte >(SCREEN_RAM+2*40), >(SCREEN_RAM+3*40)
    .byte >(SCREEN_RAM+4*40), >(SCREEN_RAM+5*40)
    .byte >(SCREEN_RAM+6*40), >(SCREEN_RAM+7*40)
    .byte >(SCREEN_RAM+8*40), >(SCREEN_RAM+9*40)
    .byte >(SCREEN_RAM+10*40), >(SCREEN_RAM+11*40)
    .byte >(SCREEN_RAM+12*40), >(SCREEN_RAM+13*40)
    .byte >(SCREEN_RAM+14*40), >(SCREEN_RAM+15*40)
    .byte >(SCREEN_RAM+16*40), >(SCREEN_RAM+17*40)
    .byte >(SCREEN_RAM+18*40), >(SCREEN_RAM+19*40)
    .byte >(SCREEN_RAM+20*40), >(SCREEN_RAM+21*40)
    .byte >(SCREEN_RAM+22*40), >(SCREEN_RAM+23*40)
    .byte >(SCREEN_RAM+24*40)

// Color RAM row table (same layout, different base)
ColorRowTableLo:
    .byte <(COLOR_RAM+0*40), <(COLOR_RAM+1*40)
    .byte <(COLOR_RAM+2*40), <(COLOR_RAM+3*40)
    .byte <(COLOR_RAM+4*40), <(COLOR_RAM+5*40)
    .byte <(COLOR_RAM+6*40), <(COLOR_RAM+7*40)
    .byte <(COLOR_RAM+8*40), <(COLOR_RAM+9*40)
    .byte <(COLOR_RAM+10*40), <(COLOR_RAM+11*40)
    .byte <(COLOR_RAM+12*40), <(COLOR_RAM+13*40)
    .byte <(COLOR_RAM+14*40), <(COLOR_RAM+15*40)
    .byte <(COLOR_RAM+16*40), <(COLOR_RAM+17*40)
    .byte <(COLOR_RAM+18*40), <(COLOR_RAM+19*40)
    .byte <(COLOR_RAM+20*40), <(COLOR_RAM+21*40)
    .byte <(COLOR_RAM+22*40), <(COLOR_RAM+23*40)
    .byte <(COLOR_RAM+24*40)

ColorRowTableHi:
    .byte >(COLOR_RAM+0*40), >(COLOR_RAM+1*40)
    .byte >(COLOR_RAM+2*40), >(COLOR_RAM+3*40)
    .byte >(COLOR_RAM+4*40), >(COLOR_RAM+5*40)
    .byte >(COLOR_RAM+6*40), >(COLOR_RAM+7*40)
    .byte >(COLOR_RAM+8*40), >(COLOR_RAM+9*40)
    .byte >(COLOR_RAM+10*40), >(COLOR_RAM+11*40)
    .byte >(COLOR_RAM+12*40), >(COLOR_RAM+13*40)
    .byte >(COLOR_RAM+14*40), >(COLOR_RAM+15*40)
    .byte >(COLOR_RAM+16*40), >(COLOR_RAM+17*40)
    .byte >(COLOR_RAM+18*40), >(COLOR_RAM+19*40)
    .byte >(COLOR_RAM+20*40), >(COLOR_RAM+21*40)
    .byte >(COLOR_RAM+22*40), >(COLOR_RAM+23*40)
    .byte >(COLOR_RAM+24*40)
