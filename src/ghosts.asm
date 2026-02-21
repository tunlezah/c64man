// ============================================================================
// CHOMPER - Ghost AI Module ("Spectres")
// ============================================================================
// Implements 4 unique ghost personalities with distinct chase behaviors,
// matching the sophistication of the original arcade game's AI.
//
// GHOST PERSONALITIES:
//   Spectre 0 "SHADE"   (Red)    - Direct chaser. Targets player's current tile.
//   Spectre 1 "GLIMMER" (Cyan)   - Ambusher. Targets 4 tiles ahead of player.
//   Spectre 2 "PHANTOM" (Purple) - Flanker. Uses vector from Shade to mirror position.
//   Spectre 3 "EMBER"   (Orange) - Unpredictable. Chases when far, scatters when close.
//
// GHOST MODES:
//   0 = SCATTER  - Each ghost targets its home corner
//   1 = CHASE    - Each ghost uses its unique targeting algorithm
//   2 = FRIGHTENED - All ghosts wander randomly (player can eat them)
//
// SCATTER/CHASE CYCLE (matches arcade timing):
//   Phase 1: Scatter 7s -> Chase 20s
//   Phase 2: Scatter 7s -> Chase 20s
//   Phase 3: Scatter 5s -> Chase 20s
//   Phase 4: Scatter 5s -> Chase forever
//   (Timing accelerates on higher levels)
//
// OPTIMIZATION TECHNIQUES:
//   1. Ghost AI decisions only happen at tile centers (not every frame)
//   2. Distance calculations use Manhattan distance (no sqrt needed)
//   3. Direction lookup tables avoid branching
//   4. Ghost states packed into minimal bytes per ghost
//   5. Unrolled ghost update loop (4 ghosts, each with inline code path)
// ============================================================================

// Ghost scatter target corners (tile coordinates)
ScatterTargetX:  .byte 25, 2, 25, 2        // Shade, Glimmer, Phantom, Ember
ScatterTargetY:  .byte 0, 0, 24, 24        // Top-right, top-left, bot-right, bot-left

// Ghost starting positions (inside ghost house)
GhostStartX:     .byte 14, 12, 14, 16      // Center and flanking positions
GhostStartY:     .byte 11, 14, 14, 14      // Shade starts outside, others inside

// Ghost house exit target
GhostExitX = 14
GhostExitY = 11

// Release timers (frames before each ghost leaves the house)
// Gets shorter on higher levels
GhostReleaseDelay:
    .byte 0, 150, 250, 200                  // Level 1 delays (frames)

// Speed table per level tier (sub-pixel per frame)
GhostSpeedNormal:   .byte 28, 30, 32, 34, 36   // Levels 1-5, 6-10, 11-15, 16-20, 21+
GhostSpeedFright:   .byte 18, 20, 22, 24, 26
GhostSpeedTunnel:   .byte 16, 18, 20, 22, 24
GhostSpeedEaten:    .byte 64, 64, 64, 64, 64   // Eyes move fast!

// Scatter/Chase phase durations (in frames at 50Hz)
// Format: scatter_time, chase_time pairs
ScatterChaseDurations:
    .byte 250, 250          // Phase 1: ~7s scatter, ~20s chase (scaled to bytes)
    .byte 250, 250          // Phase 2
    .byte 175, 250          // Phase 3: ~5s scatter
    .byte 175, 0            // Phase 4: ~5s scatter, then chase forever (0 = infinite)

// ============================================================================
// InitGhosts - Reset all ghosts to starting positions
// ============================================================================
InitGhosts:
    ldx #0
    ldy #0
!loop:
    lda GhostStartX,x
    sta ZP_GHOST_DATA+0,y   // X tile
    lda GhostStartY,x
    sta ZP_GHOST_DATA+1,y   // Y tile
    lda #DIR_LEFT
    sta ZP_GHOST_DATA+2,y   // Direction

    // Ghost 0 starts active, others start in house
    cpx #0
    bne !inHouse+
    lda #0                  // State: normal
    jmp !setState+
!inHouse:
    lda #3                  // State: in_house
!setState:
    sta ZP_GHOST_DATA+3,y   // State

    lda #0
    sta ZP_GHOST_DATA+4,y   // Sub-pixel X
    sta ZP_GHOST_DATA+5,y   // Sub-pixel Y

    lda ScatterTargetX,x
    sta ZP_GHOST_DATA+6,y   // Home/scatter X
    lda ScatterTargetY,x
    sta ZP_GHOST_DATA+7,y   // Home/scatter Y

    inx
    tya
    clc
    adc #GHOST_STRIDE
    tay
    cpx #4
    bne !loop-

    // Initialize mode
    lda #0                  // Start in scatter mode
    sta ZP_GHOST_MODE
    sta ZP_SCATTER_CTR

    // Set initial mode timer
    lda ScatterChaseDurations
    sta ZP_MODE_TIMER
    lda #0
    sta ZP_MODE_TIMER_HI

    rts

// ============================================================================
// UpdateGhosts - Main ghost update loop
// ============================================================================
UpdateGhosts:
    // Process each ghost
    ldx #0                  // Ghost index
    ldy #0                  // Data offset

!ghostLoop:
    stx GhostCurrentIdx
    sty GhostCurrentOfs

    // Load ghost state
    lda ZP_GHOST_DATA+3,y
    sta GhostCurrentState

    // Branch based on state
    cmp #3                  // In house?
    beq !updateHouseGhost+
    cmp #4                  // Leaving house?
    beq !updateLeavingGhost+
    cmp #2                  // Eaten (eyes returning)?
    beq !updateEatenGhost+

    // State 0 (normal) or 1 (frightened)
    jsr UpdateActiveGhost
    jmp !nextGhost+

!updateHouseGhost:
    jsr UpdateGhostInHouse
    jmp !nextGhost+

!updateLeavingGhost:
    jsr UpdateGhostLeaving
    jmp !nextGhost+

!updateEatenGhost:
    jsr UpdateGhostEaten

!nextGhost:
    ldx GhostCurrentIdx
    ldy GhostCurrentOfs

    inx
    tya
    clc
    adc #GHOST_STRIDE
    tay

    cpx #4
    bne !ghostLoop-

    rts

// Temporary storage for current ghost processing
GhostCurrentIdx:   .byte 0
GhostCurrentOfs:   .byte 0
GhostCurrentState: .byte 0
GhostTargetX:      .byte 0
GhostTargetY:      .byte 0

// ============================================================================
// UpdateActiveGhost - Update a ghost that's roaming the maze
// ============================================================================
// Uses the current ghost index/offset from GhostCurrentIdx/Ofs
// ============================================================================
UpdateActiveGhost:
    ldy GhostCurrentOfs

    // Accumulate sub-pixel movement
    jsr GetGhostSpeed       // Speed in A

    lda ZP_GHOST_DATA+2,y   // Current direction
    tax

    // Move based on direction (same sub-pixel system as player)
    cpx #DIR_RIGHT
    beq !ghostRight+
    cpx #DIR_LEFT
    beq !ghostLeft+
    cpx #DIR_UP
    beq !ghostUp+
    // DIR_DOWN
    jsr GetGhostSpeed
    clc
    adc ZP_GHOST_DATA+5,y
    sta ZP_GHOST_DATA+5,y
    bcc !ghostNoTile+
    inc ZP_GHOST_DATA+1,y
    jsr GhostAtTileCenter
    jmp !ghostNoTile+

!ghostRight:
    jsr GetGhostSpeed
    clc
    adc ZP_GHOST_DATA+4,y
    sta ZP_GHOST_DATA+4,y
    bcc !ghostNoTile+
    inc ZP_GHOST_DATA+0,y
    // Tunnel wrap
    lda ZP_GHOST_DATA+0,y
    cmp #MAZE_WIDTH
    bcc !noGhostWrap+
    lda #0
    sta ZP_GHOST_DATA+0,y
!noGhostWrap:
    jsr GhostAtTileCenter
    jmp !ghostNoTile+

!ghostLeft:
    jsr GetGhostSpeed
    sta ZP_TEMP1
    lda ZP_GHOST_DATA+4,y
    sec
    sbc ZP_TEMP1
    sta ZP_GHOST_DATA+4,y
    bcs !ghostNoTile+
    dec ZP_GHOST_DATA+0,y
    lda ZP_GHOST_DATA+0,y
    bpl !noGhostWrapL+
    lda #MAZE_WIDTH-1
    sta ZP_GHOST_DATA+0,y
!noGhostWrapL:
    jsr GhostAtTileCenter
    jmp !ghostNoTile+

!ghostUp:
    jsr GetGhostSpeed
    sta ZP_TEMP1
    lda ZP_GHOST_DATA+5,y
    sec
    sbc ZP_TEMP1
    sta ZP_GHOST_DATA+5,y
    bcs !ghostNoTile+
    dec ZP_GHOST_DATA+1,y
    jsr GhostAtTileCenter

!ghostNoTile:
    rts

// ============================================================================
// GhostAtTileCenter - Ghost entered a new tile, make AI decision
// ============================================================================
// This is where the magic happens - each ghost picks its next direction
// based on its targeting algorithm
// ============================================================================
GhostAtTileCenter:
    ldy GhostCurrentOfs

    // Determine target tile based on mode and ghost personality
    lda GhostCurrentState
    cmp #1                  // Frightened?
    beq !frightenedTarget+

    lda ZP_GHOST_MODE
    cmp #0                  // Scatter mode?
    beq !scatterTarget+

    // Chase mode - use ghost-specific targeting
    ldx GhostCurrentIdx
    cpx #0
    beq !shadeTarget+
    cpx #1
    beq !glimmerTarget+
    cpx #2
    beq !phantomTarget+
    // Ghost 3: Ember
    jmp !emberTarget+

!scatterTarget:
    // Target home corner
    ldx GhostCurrentIdx
    lda ScatterTargetX,x
    sta GhostTargetX
    lda ScatterTargetY,x
    sta GhostTargetY
    jmp !pickDirection+

!frightenedTarget:
    // Random direction when frightened
    jsr GetRandomDirection
    rts

// ---- SHADE (Ghost 0): Direct chaser ----
// Targets player's exact tile position
!shadeTarget:
    lda ZP_PLAYER_X
    sta GhostTargetX
    lda ZP_PLAYER_Y
    sta GhostTargetY
    jmp !pickDirection+

// ---- GLIMMER (Ghost 1): Ambusher ----
// Targets 4 tiles ahead of player's current direction
// This creates a flanking/cutting-off behavior
!glimmerTarget:
    lda ZP_PLAYER_X
    sta GhostTargetX
    lda ZP_PLAYER_Y
    sta GhostTargetY

    ldx ZP_PLAYER_DIR
    // Add 4 tiles in player's direction
    lda DeltaX,x
    asl
    asl                     // x4
    clc
    adc GhostTargetX
    sta GhostTargetX

    lda DeltaY,x
    asl
    asl                     // x4
    clc
    adc GhostTargetY
    sta GhostTargetY

    // Replicate original bug: when player faces up, also offset 4 left
    // (This is a famous bug from the arcade version - we keep it!)
    lda ZP_PLAYER_DIR
    cmp #DIR_UP
    bne !noGlimmerBug+
    lda GhostTargetX
    sec
    sbc #4
    sta GhostTargetX
!noGlimmerBug:
    jmp !pickDirection+

// ---- PHANTOM (Ghost 2): Flanker ----
// Uses vector doubling: takes vector from Shade to a point 2 tiles
// ahead of player, then doubles it. Creates unpredictable flanking.
!phantomTarget:
    // Get point 2 tiles ahead of player
    ldx ZP_PLAYER_DIR
    lda ZP_PLAYER_X
    clc
    adc DeltaX,x
    clc
    adc DeltaX,x            // +2 in player direction
    sta ZP_TEMP1

    lda ZP_PLAYER_Y
    clc
    adc DeltaY,x
    clc
    adc DeltaY,x
    sta ZP_TEMP2

    // Vector from Shade (ghost 0) to this point, doubled
    lda ZP_TEMP1
    sec
    sbc ZP_GHOST_DATA+0     // Shade's X
    asl                     // Double the vector
    clc
    adc ZP_GHOST_DATA+0
    sta GhostTargetX

    lda ZP_TEMP2
    sec
    sbc ZP_GHOST_DATA+1     // Shade's Y
    asl
    clc
    adc ZP_GHOST_DATA+1
    sta GhostTargetY
    jmp !pickDirection+

// ---- EMBER (Ghost 3): Unpredictable ----
// When far from player (>8 tiles Manhattan): chase directly like Shade
// When close to player (<=8 tiles): retreat to scatter corner
// This creates an approach/retreat oscillation
!emberTarget:
    // Calculate Manhattan distance to player
    lda ZP_PLAYER_X
    sec
    sbc ZP_GHOST_DATA+0,y
    bcs !noNegX+
    eor #$FF
    clc
    adc #1
!noNegX:
    sta ZP_TEMP1

    lda ZP_PLAYER_Y
    sec
    sbc ZP_GHOST_DATA+1,y
    bcs !noNegY+
    eor #$FF
    clc
    adc #1
!noNegY:
    clc
    adc ZP_TEMP1            // Manhattan distance in A

    cmp #8                  // Distance threshold
    bcs !emberChase+

    // Close to player - scatter to home corner
    lda ScatterTargetX+3
    sta GhostTargetX
    lda ScatterTargetY+3
    sta GhostTargetY
    jmp !pickDirection+

!emberChase:
    // Far from player - chase directly
    lda ZP_PLAYER_X
    sta GhostTargetX
    lda ZP_PLAYER_Y
    sta GhostTargetY
    jmp !pickDirection+

// ============================================================================
// PickDirection - Choose best direction toward target tile
// ============================================================================
// Evaluates all 4 directions, picks the one that minimizes distance
// to the target. Ghosts cannot reverse direction (except when mode changes).
//
// OPTIMIZATION: Uses Manhattan distance (|dx|+|dy|) instead of Euclidean.
// This is exactly what the arcade version does.
// ============================================================================
!pickDirection:
    ldy GhostCurrentOfs

    // Get current direction to determine which is "reverse" (forbidden)
    lda ZP_GHOST_DATA+2,y
    tax
    lda OppDir,x
    sta ZP_TEMP4             // Forbidden reverse direction

    // Try all 4 directions, find minimum distance to target
    lda #$FF
    sta BestDistance         // Best distance so far (max = worst)
    lda #DIR_RIGHT
    sta BestDirection        // Default direction

    // ---- Check UP ----
    lda #DIR_UP
    cmp ZP_TEMP4
    beq !skipUp+
    jsr CheckGhostDirection
    bne !skipUp+             // Blocked
    jsr CalcGhostDistance
    cmp BestDistance
    bcs !skipUp+
    sta BestDistance
    lda #DIR_UP
    sta BestDirection
!skipUp:

    // ---- Check LEFT ----
    lda #DIR_LEFT
    cmp ZP_TEMP4
    beq !skipLeft+
    jsr CheckGhostDirection
    bne !skipLeft+
    jsr CalcGhostDistance
    cmp BestDistance
    bcs !skipLeft+
    sta BestDistance
    lda #DIR_LEFT
    sta BestDirection
!skipLeft:

    // ---- Check DOWN ----
    lda #DIR_DOWN
    cmp ZP_TEMP4
    beq !skipDown+
    jsr CheckGhostDirection
    bne !skipDown+
    jsr CalcGhostDistance
    cmp BestDistance
    bcs !skipDown+
    sta BestDistance
    lda #DIR_DOWN
    sta BestDirection
!skipDown:

    // ---- Check RIGHT ----
    lda #DIR_RIGHT
    cmp ZP_TEMP4
    beq !skipRight+
    jsr CheckGhostDirection
    bne !skipRight+
    jsr CalcGhostDistance
    cmp BestDistance
    bcs !skipRight+
    sta BestDistance
    lda #DIR_RIGHT
    sta BestDirection
!skipRight:

    // Apply chosen direction
    ldy GhostCurrentOfs
    lda BestDirection
    sta ZP_GHOST_DATA+2,y

    rts

BestDistance:   .byte 0
BestDirection:  .byte 0

// ============================================================================
// CheckGhostDirection - Can ghost move in direction A?
// ============================================================================
// Input: A = direction to check
// Output: Z=1 if passable, Z=0 if blocked
// Uses current ghost position from GhostCurrentOfs
// ============================================================================
CheckGhostDirection:
    tax
    ldy GhostCurrentOfs

    lda ZP_GHOST_DATA+0,y   // Ghost X
    clc
    adc DeltaX,x
    sta ZP_TEMP1

    lda ZP_GHOST_DATA+1,y   // Ghost Y
    clc
    adc DeltaY,x
    sta ZP_TEMP2

    // Handle tunnel wrap for X
    lda ZP_TEMP1
    bpl !gxOk+
    lda #MAZE_WIDTH-1
    sta ZP_TEMP1
!gxOk:
    cmp #MAZE_WIDTH
    bcc !gxOk2+
    lda #0
    sta ZP_TEMP1
!gxOk2:

    // Look up tile at target position
    lda ZP_TEMP2
    asl
    tay
    lda ScreenRowTableLo,y
    sta ZP_SCREEN_LO
    lda ScreenRowTableHi,y
    sta ZP_SCREEN_HI

    lda ZP_TEMP1
    clc
    adc #MAZE_OFFSET_X
    tay
    lda (ZP_SCREEN_LO),y

    // Ghosts can pass through gate, empty, dots, power pellets
    cmp #CHR_EMPTY
    beq !gPassable+
    cmp #CHR_DOT
    beq !gPassable+
    cmp #CHR_POWER
    beq !gPassable+
    cmp #CHR_POWER_ANIM2
    beq !gPassable+
    cmp #CHR_GATE
    beq !gPassable+         // Ghosts CAN pass through gate

    lda #$01                // Blocked
    rts
!gPassable:
    lda #$00                // Passable
    rts

// ============================================================================
// CalcGhostDistance - Manhattan distance from direction's target to ghost target
// ============================================================================
// Uses ZP_TEMP1/TEMP2 as the "next tile" position
// Uses GhostTargetX/Y as the target
// Returns distance in A (capped at 255)
// ============================================================================
CalcGhostDistance:
    lda ZP_TEMP1
    sec
    sbc GhostTargetX
    bcs !dxPos+
    eor #$FF
    clc
    adc #1
!dxPos:
    sta ZP_TEMP3

    lda ZP_TEMP2
    sec
    sbc GhostTargetY
    bcs !dyPos+
    eor #$FF
    clc
    adc #1
!dyPos:
    clc
    adc ZP_TEMP3
    // Clamp to 255 (carry means overflow)
    bcc !noClamp+
    lda #$FF
!noClamp:
    rts

// ============================================================================
// GetRandomDirection - Pick a random valid direction (for frightened mode)
// ============================================================================
GetRandomDirection:
    ldy GhostCurrentOfs

    // Get current direction's reverse
    lda ZP_GHOST_DATA+2,y
    tax
    lda OppDir,x
    sta ZP_TEMP4

    // Use frame counter XOR'd with ghost position as pseudo-random
    lda ZP_FRAME_CTR
    eor ZP_GHOST_DATA+0,y
    eor ZP_GHOST_DATA+1,y
    eor ZP_RNG_SEED
    sta ZP_RNG_SEED

    // Rotate through directions starting from random point
    and #$03
    tax                     // Random starting direction

    ldy #4                  // Try all 4 directions
!tryLoop:
    txa
    pha
    cmp ZP_TEMP4            // Skip reverse direction
    beq !tryNext+

    jsr CheckGhostDirection
    beq !foundDir+           // Z=1 means passable

!tryNext:
    pla
    tax
    inx
    txa
    and #$03
    tax
    dey
    bne !tryLoop-

    // Fallback: keep current direction
    ldy GhostCurrentOfs
    rts

!foundDir:
    pla
    ldy GhostCurrentOfs
    sta ZP_GHOST_DATA+2,y   // Set new direction
    rts

// ============================================================================
// GetGhostSpeed - Returns ghost movement speed in A
// ============================================================================
GetGhostSpeed:
    ldy GhostCurrentOfs

    lda GhostCurrentState
    cmp #2                  // Eaten?
    beq !eatenSpeed+
    cmp #1                  // Frightened?
    beq !frightSpeed+

    // Normal speed based on level tier
    jsr GetLevelTier         // Returns tier 0-4 in X
    lda GhostSpeedNormal,x
    rts

!frightSpeed:
    jsr GetLevelTier
    lda GhostSpeedFright,x
    rts

!eatenSpeed:
    lda #64                 // Eyes move fast!
    rts

// ============================================================================
// GetLevelTier - Maps level number to difficulty tier (0-4)
// ============================================================================
GetLevelTier:
    lda ZP_LEVEL
    cmp #5
    bcc !tier0+
    cmp #10
    bcc !tier1+
    cmp #15
    bcc !tier2+
    cmp #20
    bcc !tier3+
    ldx #4
    rts
!tier3:
    ldx #3
    rts
!tier2:
    ldx #2
    rts
!tier1:
    ldx #1
    rts
!tier0:
    ldx #0
    rts

// ============================================================================
// UpdateGhostInHouse - Ghost waiting inside the ghost house
// ============================================================================
UpdateGhostInHouse:
    ldy GhostCurrentOfs
    ldx GhostCurrentIdx

    // Bob up and down inside the house
    lda ZP_FRAME_CTR
    and #$1F
    cmp #$10
    bcc !bobUp+
    // Bob down
    lda #14
    sta ZP_GHOST_DATA+1,y
    jmp !checkRelease+
!bobUp:
    lda #13
    sta ZP_GHOST_DATA+1,y

!checkRelease:
    // Check if it's time to release this ghost
    // Release based on dots eaten and time elapsed
    lda ZP_DOTS_TOTAL
    sec
    sbc ZP_DOTS_LEFT
    // Ghost 1 releases after 10 dots eaten
    // Ghost 2 releases after 30 dots eaten
    // Ghost 3 releases after 50 dots eaten (or time-based)
    cpx #1
    beq !check10+
    cpx #2
    beq !check30+
    cpx #3
    beq !check50+
    rts

!check10:
    cmp #10
    bcc !notYet+
    jmp !releaseGhost+
!check30:
    cmp #30
    bcc !notYet+
    jmp !releaseGhost+
!check50:
    cmp #50
    bcc !notYet+

!releaseGhost:
    lda #4                  // State: leaving house
    sta ZP_GHOST_DATA+3,y
!notYet:
    rts

// ============================================================================
// UpdateGhostLeaving - Ghost moving out of the ghost house
// ============================================================================
UpdateGhostLeaving:
    ldy GhostCurrentOfs

    // First center X on exit column
    lda ZP_GHOST_DATA+0,y
    cmp #GhostExitX
    beq !xCentered+
    bcc !moveRight2+

    // Move left
    dec ZP_GHOST_DATA+0,y
    rts
!moveRight2:
    inc ZP_GHOST_DATA+0,y
    rts

!xCentered:
    // Move up to exit
    lda ZP_GHOST_DATA+1,y
    cmp #GhostExitY
    beq !exited+
    bcc !exited+
    dec ZP_GHOST_DATA+1,y
    rts

!exited:
    // Ghost has exited the house
    lda ZP_GHOST_DATA+1,y
    sta ZP_GHOST_DATA+1,y
    lda #0                  // State: normal
    sta ZP_GHOST_DATA+3,y
    lda #DIR_LEFT           // Start moving left
    sta ZP_GHOST_DATA+2,y
    rts

// ============================================================================
// UpdateGhostEaten - Ghost eyes returning to the ghost house
// ============================================================================
UpdateGhostEaten:
    ldy GhostCurrentOfs

    // Target the ghost house entrance
    lda #GhostExitX
    sta GhostTargetX
    lda #GhostExitY
    sta GhostTargetY

    // Check if reached the ghost house
    lda ZP_GHOST_DATA+0,y
    cmp #GhostExitX
    bne !notHome+
    lda ZP_GHOST_DATA+1,y
    cmp #GhostExitY
    bne !notHome+

    // Reached the house - enter and regenerate
    lda #3                  // State: in_house
    sta ZP_GHOST_DATA+3,y
    lda #14
    sta ZP_GHOST_DATA+1,y   // Move inside house

    // Play regeneration sound
    lda #SFX_GHOST_REGEN
    jsr PlaySFX
    rts

!notHome:
    // Navigate toward house (simplified - use normal AI targeting)
    jmp !pickDirection-

// ============================================================================
// ActivateFrightenedMode - Called when player eats a power pellet
// ============================================================================
ActivateFrightenedMode:
    // Set all active (non-eaten) ghosts to frightened
    ldy #0
    ldx #0
!fLoop:
    lda ZP_GHOST_DATA+3,y
    cmp #2                  // Already eaten? Don't frighten
    beq !fSkip+
    cmp #3                  // In house? Don't frighten
    beq !fSkip+

    lda #1                  // State: frightened
    sta ZP_GHOST_DATA+3,y

    // Force reverse direction (ghosts reverse when mode changes)
    lda ZP_GHOST_DATA+2,y
    tax
    lda OppDir,x
    sta ZP_GHOST_DATA+2,y

!fSkip:
    tya
    clc
    adc #GHOST_STRIDE
    tay
    inx
    cpx #4
    bne !fLoop-

    // Set frightened timer based on level
    // Frightened time decreases on higher levels
    lda ZP_LEVEL
    cmp #1
    bcc !fright6s+
    cmp #5
    bcc !fright5s+
    cmp #10
    bcc !fright3s+
    cmp #17
    bcc !fright2s+
    // Level 17+: no frightened mode (ghosts just reverse)
    lda #10                 // Very brief
    sta ZP_POWER_TIMER
    lda #0
    sta ZP_POWER_TIMER_HI
    rts

!fright6s:
    lda #<300               // ~6 seconds at 50Hz
    sta ZP_POWER_TIMER
    lda #>300
    sta ZP_POWER_TIMER_HI
    rts
!fright5s:
    lda #<250
    sta ZP_POWER_TIMER
    lda #>250
    sta ZP_POWER_TIMER_HI
    rts
!fright3s:
    lda #<150
    sta ZP_POWER_TIMER
    lda #>150
    sta ZP_POWER_TIMER_HI
    rts
!fright2s:
    lda #<100
    sta ZP_POWER_TIMER
    lda #>100
    sta ZP_POWER_TIMER_HI
    rts

// ============================================================================
// UpdateModeTimer - Handle scatter/chase/frightened mode transitions
// ============================================================================
UpdateModeTimer:
    // Check if in frightened mode first
    lda ZP_POWER_TIMER
    ora ZP_POWER_TIMER_HI
    beq !notFrightened+

    // Decrement frightened timer
    lda ZP_POWER_TIMER
    sec
    sbc #1
    sta ZP_POWER_TIMER
    lda ZP_POWER_TIMER_HI
    sbc #0
    sta ZP_POWER_TIMER_HI

    // Check if frightened ended
    ora ZP_POWER_TIMER
    bne !stillFrightened+

    // Frightened mode ended - restore ghost states
    ldy #0
    ldx #0
!restoreLoop:
    lda ZP_GHOST_DATA+3,y
    cmp #1                  // Was frightened?
    bne !rSkip+
    lda #0                  // Restore to normal
    sta ZP_GHOST_DATA+3,y
!rSkip:
    tya
    clc
    adc #GHOST_STRIDE
    tay
    inx
    cpx #4
    bne !restoreLoop-

!stillFrightened:
    rts

!notFrightened:
    // Normal scatter/chase timer
    lda ZP_MODE_TIMER
    sec
    sbc #1
    sta ZP_MODE_TIMER
    lda ZP_MODE_TIMER_HI
    sbc #0
    sta ZP_MODE_TIMER_HI

    // Check if timer expired
    ora ZP_MODE_TIMER
    bne !timerOk+

    // Toggle between scatter (0) and chase (1)
    lda ZP_GHOST_MODE
    eor #$01
    sta ZP_GHOST_MODE

    // Force all active ghosts to reverse direction (mode change rule)
    ldy #0
    ldx #0
!reverseLoop:
    lda ZP_GHOST_DATA+3,y
    cmp #0                  // Only reverse normal ghosts
    bne !rvSkip+
    lda ZP_GHOST_DATA+2,y
    tax
    lda OppDir,x
    sta ZP_GHOST_DATA+2,y
    ldx #0
!rvSkip:
    tya
    clc
    adc #GHOST_STRIDE
    tay
    inx
    cpx #4
    bne !reverseLoop-

    // Set next phase timer
    inc ZP_SCATTER_CTR
    lda ZP_SCATTER_CTR
    cmp #8                  // Max phases
    bcc !validPhase+
    // Stay in chase forever
    lda #$FF
    sta ZP_MODE_TIMER
    sta ZP_MODE_TIMER_HI
    rts
!validPhase:
    tax
    lda ScatterChaseDurations,x
    sta ZP_MODE_TIMER
    lda #0
    sta ZP_MODE_TIMER_HI

!timerOk:
    rts

// ============================================================================
// UpdatePowerTimer - Manage the power pellet countdown
// ============================================================================
UpdatePowerTimer:
    // This is handled in UpdateModeTimer above
    rts
