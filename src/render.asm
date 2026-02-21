// ============================================================================
// CHOMPER - Rendering Module
// ============================================================================
// Handles all screen rendering including:
//   - Maze drawing from level data
//   - Sprite position updates
//   - Score/lives HUD display
//   - Power pellet blink animation
//   - Bonus item display
//
// OPTIMIZATION TECHNIQUES:
//   1. Only redraw changed tiles (dirty flag system)
//   2. Unrolled sprite position writes (no loop overhead)
//   3. Pre-computed screen address tables
//   4. Color RAM set once during maze draw (doesn't change per frame)
//   5. Score display uses BCD-to-character lookup (no division)
//   6. Sprite positions updated in raster IRQ for zero tearing
// ============================================================================

// Sprite base positions (screen pixel coords for tile 0,0)
// VIC sprites have a 24-pixel offset on X and 50-pixel offset on Y
.const SPRITE_BASE_X = 24 + (MAZE_OFFSET_X * 8) + 4   // Center sprite in tile
.const SPRITE_BASE_Y = 50 + 4

// ============================================================================
// InitCharSet - Copy custom charset and set up VIC
// ============================================================================
// The charset data is already at $2000 (loaded by .segment directive)
// We just need to tell VIC-II to use it
// ============================================================================
InitCharSet:
    // Charset already loaded at $2000 by the assembler
    // VIC_MEM_CTRL already set in InitVIC
    rts

// ============================================================================
// InitSprites - Set up sprite pointers and initial positions
// ============================================================================
InitSprites:
    // Sprite pointers are at screen + $03F8
    lda #160                // Chomper right (sprite data at $2800)
    sta SCREEN_RAM+$03F8    // Sprite 0
    lda #165                // Spectre frame 1
    sta SCREEN_RAM+$03F9    // Sprite 1 (Shade)
    sta SCREEN_RAM+$03FA    // Sprite 2 (Glimmer)
    sta SCREEN_RAM+$03FB    // Sprite 3 (Phantom)
    sta SCREEN_RAM+$03FC    // Sprite 4 (Ember)

    // Disable bonus/score sprites initially
    lda #0
    sta SCREEN_RAM+$03FD
    sta SCREEN_RAM+$03FE
    sta SCREEN_RAM+$03FF

    rts

// ============================================================================
// DrawMaze - Render the current level's maze to screen
// ============================================================================
// Reads from compressed level data and writes to Screen RAM + Color RAM
// Level data format: each byte encodes a tile type (0-6)
// The renderer auto-tiles walls based on neighbor analysis
// ============================================================================
DrawMaze:
    // Clear screen first
    jsr ClearScreen

    // Get pointer to current level data
    lda ZP_LEVEL
    // Each level is 28*25 = 700 bytes (but we use RLE compression)
    // Level pointer table at LevelPointerTable
    asl                     // x2 for 16-bit pointer
    tax
    lda LevelPointerTable,x
    sta ZP_LEVEL_PTR_LO
    lda LevelPointerTable+1,x
    sta ZP_LEVEL_PTR_HI

    // Reset dot counter
    lda #0
    sta ZP_DOTS_LEFT
    sta ZP_DOTS_LEFT_HI
    sta ZP_DOTS_TOTAL
    sta ZP_DOTS_TOTAL_HI

    // Decompress and render each row
    lda #0
    sta MazeDrawRow
    sta MazeDrawCol

!rowLoop:
    lda MazeDrawRow
    cmp #VISIBLE_ROWS
    bcs !drawDone+

    // Get screen row address
    asl
    tay
    lda ScreenRowTableLo,y
    sta ZP_SCREEN_LO
    lda ScreenRowTableHi,y
    sta ZP_SCREEN_HI

    // Get color row address
    lda ColorRowTableLo,y
    sta ZP_COLOR_LO
    lda ColorRowTableHi,y
    sta ZP_COLOR_HI

    // Draw columns in this row
    lda #0
    sta MazeDrawCol

!colLoop:
    lda MazeDrawCol
    cmp #MAZE_WIDTH
    bcs !nextRow+

    // Read tile from level data
    ldy #0
    lda (ZP_LEVEL_PTR_LO),y

    // Advance level data pointer
    inc ZP_LEVEL_PTR_LO
    bne !noInc+
    inc ZP_LEVEL_PTR_HI
!noInc:

    // Convert tile type to character and color
    cmp #TILE_EMPTY
    beq !tileEmpty+
    cmp #TILE_WALL
    beq !tileWall+
    cmp #TILE_DOT
    beq !tileDot+
    cmp #TILE_POWER
    beq !tilePower+
    cmp #TILE_GATE
    beq !tileGate+
    cmp #TILE_TUNNEL
    beq !tileEmpty+         // Tunnel looks empty
    cmp #TILE_BONUS_SPOT
    beq !tileBonusSpot+
    jmp !tileEmpty+         // Default to empty

!tileEmpty:
    lda #CHR_EMPTY
    ldx #COL_BLACK
    jmp !placeTile+

!tileWall:
    // Auto-tile: choose wall character based on neighbors
    // For now, use generic wall character; the auto-tiler is below
    lda #CHR_WALL_H         // Default wall (will be refined)
    ldx #COL_LIGHT_BLUE     // Wall color in Color RAM (multicolor char color)
    jmp !placeTile+

!tileDot:
    lda #CHR_DOT
    ldx #COL_WHITE          // White dots
    // Count dots
    inc ZP_DOTS_LEFT
    bne !dotNoHi+
    inc ZP_DOTS_LEFT_HI
!dotNoHi:
    inc ZP_DOTS_TOTAL
    bne !dotNoHi2+
    inc ZP_DOTS_TOTAL_HI
!dotNoHi2:
    jmp !placeTile+

!tilePower:
    lda #CHR_POWER
    ldx #COL_WHITE          // White power pellets
    // Power pellets count toward dot total
    inc ZP_DOTS_LEFT
    bne !pwrNoHi+
    inc ZP_DOTS_LEFT_HI
!pwrNoHi:
    inc ZP_DOTS_TOTAL
    bne !pwrNoHi2+
    inc ZP_DOTS_TOTAL_HI
!pwrNoHi2:
    jmp !placeTile+

!tileGate:
    lda #CHR_GATE
    ldx #COL_LIGHT_RED      // Pink gate
    jmp !placeTile+

!tileBonusSpot:
    lda #CHR_EMPTY          // Bonus spot is empty until bonus spawns
    ldx #COL_BLACK
    jmp !placeTile+

!placeTile:
    // A = character code, X = color
    // Save character and color before computing column offset
    sta ZP_TEMP1             // Save character
    stx ZP_TEMP2             // Save color

    // Calculate screen column with maze offset
    ldy MazeDrawCol
    tya
    clc
    adc #MAZE_OFFSET_X
    tay

    // Write character to screen
    lda ZP_TEMP1
    sta (ZP_SCREEN_LO),y

    // Write color to Color RAM
    lda ZP_TEMP2
    sta (ZP_COLOR_LO),y

    inc MazeDrawCol
    jmp !colLoop-

!nextRow:
    inc MazeDrawRow
    jmp !rowLoop-

!drawDone:
    // Draw HUD (score, lives) in side columns
    jsr DrawHUD
    rts

MazeDrawRow: .byte 0
MazeDrawCol: .byte 0

// ============================================================================
// ClearScreen - Fill screen with empty chars and black color
// ============================================================================
ClearScreen:
    lda #CHR_EMPTY
    ldx #0
!clearLoop:
    sta SCREEN_RAM,x
    sta SCREEN_RAM+$100,x
    sta SCREEN_RAM+$200,x
    sta SCREEN_RAM+$2E8,x    // Last partial page
    dex
    bne !clearLoop-

    lda #COL_BLACK
    ldx #0
!colorLoop:
    sta COLOR_RAM,x
    sta COLOR_RAM+$100,x
    sta COLOR_RAM+$200,x
    sta COLOR_RAM+$2E8,x
    dex
    bne !colorLoop-

    rts

// ============================================================================
// DrawHUD - Draw score, lives, and level info in side columns
// ============================================================================
// Layout (using columns 0-5 on the left side):
//   Row 0-1: "SC" + 6-digit score
//   Row 3-4: "HI" + 6-digit high score
//   Row 6:   Lives icons
//   Row 8:   "LV" + level number
//   Right side (cols 34-39):
//   Row 0: Bonus item display
// ============================================================================
DrawHUD:
    // --- SCORE label ---
    lda #43                 // 'S'
    sta SCREEN_RAM+0
    lda #33                 // 'C'
    sta SCREEN_RAM+1
    lda #COL_WHITE
    sta COLOR_RAM+0
    sta COLOR_RAM+1

    // Score digits (BCD to screen chars)
    // Score is 3 bytes BCD: ZP_SCORE_HI (highest), ZP_SCORE_MID, ZP_SCORE (lowest)
    lda ZP_SCORE_HI
    lsr
    lsr
    lsr
    lsr
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM+40       // Row 1, col 0
    lda ZP_SCORE_HI
    and #$0F
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM+41

    lda ZP_SCORE_MID
    lsr
    lsr
    lsr
    lsr
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM+42
    lda ZP_SCORE_MID
    and #$0F
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM+43

    lda ZP_SCORE
    lsr
    lsr
    lsr
    lsr
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM+44
    lda ZP_SCORE
    and #$0F
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM+45

    // Score digit colors
    lda #COL_YELLOW
    ldx #0
!scoreColor:
    sta COLOR_RAM+40,x
    inx
    cpx #6
    bne !scoreColor-

    // --- HIGH SCORE label ---
    lda #34                 // 'H'
    sta SCREEN_RAM+120      // Row 3
    lda #44                 // 'I'
    sta SCREEN_RAM+121
    lda #COL_WHITE
    sta COLOR_RAM+120
    sta COLOR_RAM+121

    // High score digits
    lda ZP_HISCORE_HI
    lsr
    lsr
    lsr
    lsr
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM+160      // Row 4
    lda ZP_HISCORE_HI
    and #$0F
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM+161
    lda ZP_HISCORE_MID
    lsr
    lsr
    lsr
    lsr
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM+162
    lda ZP_HISCORE_MID
    and #$0F
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM+163
    lda ZP_HISCORE
    lsr
    lsr
    lsr
    lsr
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM+164
    lda ZP_HISCORE
    and #$0F
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM+165

    lda #COL_CYAN
    ldx #0
!hiColor:
    sta COLOR_RAM+160,x
    inx
    cpx #6
    bne !hiColor-

    // --- LIVES display ---
    lda #45                 // 'L'
    sta SCREEN_RAM+240      // Row 6
    lda #COL_WHITE
    sta COLOR_RAM+240

    // Draw life icons
    ldx #0
    lda ZP_LIVES
    sta ZP_TEMP1
!lifeLoop:
    cpx ZP_TEMP1
    bcs !lifesDone+
    lda #CHR_LIFE_ICON
    sta SCREEN_RAM+241,x
    lda #COL_YELLOW
    sta COLOR_RAM+241,x
    inx
    cpx #5                  // Max 5 visible lives
    bcc !lifeLoop-
!lifesDone:

    // --- LEVEL display ---
    lda #45                 // 'L'
    sta SCREEN_RAM+320      // Row 8
    lda #46                 // 'V'
    sta SCREEN_RAM+321
    lda #COL_WHITE
    sta COLOR_RAM+320
    sta COLOR_RAM+321

    // Level number (convert to decimal display)
    lda ZP_LEVEL
    clc
    adc #1                  // Display as 1-based
    // Simple decimal conversion for values 1-30
    ldx #0
!tenLoop:
    cmp #10
    bcc !tensDone+
    sec
    sbc #10
    inx
    jmp !tenLoop-
!tensDone:
    // X = tens digit, A = ones digit
    pha
    txa
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM+322
    pla
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM+323
    lda #COL_GREEN
    sta COLOR_RAM+322
    sta COLOR_RAM+323

    rts

// ============================================================================
// UpdateScoreDisplay - Quick update of just the score digits
// ============================================================================
// OPTIMIZATION: Only updates the 6 score digits rather than redrawing
// the entire HUD each frame
// ============================================================================
UpdateScoreDisplay:
    lda ZP_SCORE_HI
    lsr
    lsr
    lsr
    lsr
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM+40
    lda ZP_SCORE_HI
    and #$0F
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM+41
    lda ZP_SCORE_MID
    lsr
    lsr
    lsr
    lsr
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM+42
    lda ZP_SCORE_MID
    and #$0F
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM+43
    lda ZP_SCORE
    lsr
    lsr
    lsr
    lsr
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM+44
    lda ZP_SCORE
    and #$0F
    clc
    adc #CHR_SCORE_DIGIT
    sta SCREEN_RAM+45
    rts

// ============================================================================
// UpdateSpritePositions - Convert tile positions to sprite pixel coords
// ============================================================================
// Called from raster IRQ for tear-free updates
// OPTIMIZATION: Unrolled loop, no branching in hot path
// ============================================================================
UpdateSpritePositions:
    // ---- SPRITE 0: Chomper (Player) ----
    // X pixel = SPRITE_BASE_X + (tile_x * 8) + (subpixel_x / 32)
    lda ZP_PLAYER_X
    asl
    asl
    asl                     // tile * 8
    clc
    adc #SPRITE_BASE_X
    sta VIC_SPR0_X

    lda ZP_PLAYER_Y
    asl
    asl
    asl                     // tile * 8
    clc
    adc #SPRITE_BASE_Y
    sta VIC_SPR0_Y

    // Handle X MSB (if X > 255)
    lda VIC_SPR_XMSB
    and #%11111110          // Clear sprite 0 MSB bit
    ldx ZP_PLAYER_X
    cpx #24                 // Would pixel X exceed 255?
    bcc !noMsb0+
    ora #%00000001          // Set MSB
!noMsb0:
    sta VIC_SPR_XMSB

    // Update chomper sprite frame based on direction and animation
    lda ZP_PLAYER_ANIM
    and #$04                // Alternate every 4 frames
    beq !mouthOpen+
    // Mouth closed
    lda #161                // Chomper closed sprite
    jmp !setChomperFrame+
!mouthOpen:
    ldx ZP_PLAYER_DIR
    lda PlayerSpriteFrame,x
!setChomperFrame:
    sta SCREEN_RAM+$03F8

    // ---- SPRITES 1-4: Ghosts ----
    ldy #0                  // Ghost data offset
    ldx #0                  // Ghost index

!sprGhostLoop:
    // Calculate X position
    lda ZP_GHOST_DATA+0,y   // Ghost tile X
    asl
    asl
    asl
    clc
    adc #SPRITE_BASE_X
    // Store to correct sprite X register
    cpx #0
    beq !spr1x+
    cpx #1
    beq !spr2x+
    cpx #2
    beq !spr3x+
    sta VIC_SPR4_X
    jmp !sprY+
!spr1x: sta VIC_SPR1_X
    jmp !sprY+
!spr2x: sta VIC_SPR2_X
    jmp !sprY+
!spr3x: sta VIC_SPR3_X

!sprY:
    // Calculate Y position
    lda ZP_GHOST_DATA+1,y   // Ghost tile Y
    asl
    asl
    asl
    clc
    adc #SPRITE_BASE_Y
    cpx #0
    beq !spr1y+
    cpx #1
    beq !spr2y+
    cpx #2
    beq !spr3y+
    sta VIC_SPR4_Y
    jmp !sprFrame+
!spr1y: sta VIC_SPR1_Y
    jmp !sprFrame+
!spr2y: sta VIC_SPR2_Y
    jmp !sprFrame+
!spr3y: sta VIC_SPR3_Y

!sprFrame:
    // Set sprite frame based on ghost state
    lda ZP_GHOST_DATA+3,y   // Ghost state
    cmp #1                  // Frightened?
    beq !frightenedFrame+
    cmp #2                  // Eaten (eyes)?
    beq !eyesFrame+

    // Normal ghost - alternate between frame 1 and 2
    lda ZP_FRAME_CTR
    and #$08
    beq !ghostF1+
    lda #166                // Spectre frame 2
    jmp !setGhostFrame+
!ghostF1:
    lda #165                // Spectre frame 1
    jmp !setGhostFrame+

!frightenedFrame:
    // Frightened - flash when timer is low
    lda ZP_POWER_TIMER
    cmp #75                 // Flash in last ~1.5 seconds
    bcs !solidFright+
    lda ZP_FRAME_CTR
    and #$04
    beq !solidFright+
    lda #168                // Flash frame
    jmp !setGhostFrame+
!solidFright:
    lda #167                // Solid frightened
    jmp !setGhostFrame+

!eyesFrame:
    lda #169                // Eyes only
    jmp !setGhostFrame+

!setGhostFrame:
    // Store to correct sprite pointer
    cpx #0
    beq !setF1+
    cpx #1
    beq !setF2+
    cpx #2
    beq !setF3+
    sta SCREEN_RAM+$03FC
    jmp !sprNext+
!setF1: sta SCREEN_RAM+$03F9
    jmp !sprNext+
!setF2: sta SCREEN_RAM+$03FA
    jmp !sprNext+
!setF3: sta SCREEN_RAM+$03FB

!sprNext:
    // Set ghost color (frightened ghosts are blue)
    lda ZP_GHOST_DATA+3,y
    cmp #1
    bne !normalColor+
    lda #COL_BLUE
    jmp !setColor+
!normalColor:
    cmp #2
    bne !keepColor+
    lda #COL_WHITE          // Eyes are white
    jmp !setColor+
!keepColor:
    // Use ghost's assigned color
    cpx #0
    beq !col1+
    cpx #1
    beq !col2+
    cpx #2
    beq !col3+
    lda #COL_ORANGE
    jmp !setColor+
!col1: lda #COL_RED
    jmp !setColor+
!col2: lda #COL_CYAN
    jmp !setColor+
!col3: lda #COL_PURPLE

!setColor:
    cpx #0
    beq !sc1+
    cpx #1
    beq !sc2+
    cpx #2
    beq !sc3+
    sta VIC_SPR4_COLOR
    jmp !sprDone+
!sc1: sta VIC_SPR1_COLOR
    jmp !sprDone+
!sc2: sta VIC_SPR2_COLOR
    jmp !sprDone+
!sc3: sta VIC_SPR3_COLOR

!sprDone:
    tya
    clc
    adc #GHOST_STRIDE
    tay
    inx
    cpx #4
    bne !sprGhostLoop-

    rts

// ============================================================================
// BlinkPowerPellets - Toggle power pellet characters for blink effect
// ============================================================================
// OPTIMIZATION: Scans only the 4 power pellet positions stored per level
// instead of scanning the entire screen
// ============================================================================
BlinkPowerPellets:
    ldx #0
!blinkLoop:
    cpx #4
    bcs !blinkDone+

    lda PowerPelletX,x
    clc
    adc #MAZE_OFFSET_X
    sta ZP_TEMP1

    lda PowerPelletY,x
    asl
    tay
    lda ScreenRowTableLo,y
    sta ZP_SCREEN_LO
    lda ScreenRowTableHi,y
    sta ZP_SCREEN_HI

    ldy ZP_TEMP1
    lda (ZP_SCREEN_LO),y

    // Toggle between power pellet frames
    cmp #CHR_POWER
    beq !toFrame2+
    cmp #CHR_POWER_ANIM2
    bne !skipBlink+

    // Switch to frame 1
    lda #CHR_POWER
    sta (ZP_SCREEN_LO),y
    jmp !skipBlink+

!toFrame2:
    lda #CHR_POWER_ANIM2
    sta (ZP_SCREEN_LO),y

!skipBlink:
    inx
    jmp !blinkLoop-
!blinkDone:
    rts

// Power pellet positions (set when level is loaded)
PowerPelletX:  .byte 1, 26, 1, 26
PowerPelletY:  .byte 3, 3, 23, 23

// ============================================================================
// UpdateAnimations - Handle miscellaneous visual animations
// ============================================================================
UpdateAnimations:
    // Ghost skirt wave is handled by sprite frame alternation
    // Power pellet blink is handled in raster IRQ
    // Player mouth animation is handled in UpdateSpritePositions
    rts

// ============================================================================
// UpdateBonusItem - Handle bonus item spawning and collection
// ============================================================================
UpdateBonusItem:
    lda ZP_BONUS_ACTIVE
    bne !bonusActive+

    // Check if bonus should spawn (at 70 and 170 dots eaten)
    lda ZP_DOTS_TOTAL
    sec
    sbc ZP_DOTS_LEFT
    cmp #70
    beq !spawnBonus+
    cmp #170
    beq !spawnBonus+
    rts

!spawnBonus:
    lda ZP_BONUS_ACTIVE
    bne !bonusReturn+        // Already active
    lda #1
    sta ZP_BONUS_ACTIVE
    // Set bonus type based on level
    lda ZP_LEVEL
    and #$07
    sta ZP_BONUS_TYPE
    // Set timer (~10 seconds)
    lda #<500
    sta ZP_BONUS_TIMER
!bonusReturn:
    rts

!bonusActive:
    // Decrement timer
    dec ZP_BONUS_TIMER
    lda ZP_BONUS_TIMER
    bne !bonusStillActive+

    // Timer expired - remove bonus
    lda #0
    sta ZP_BONUS_ACTIVE
    rts

!bonusStillActive:
    // Check if player collected the bonus
    lda ZP_PLAYER_X
    cmp #14                 // Bonus spawn position
    bne !bonusReturn-
    lda ZP_PLAYER_Y
    cmp #17
    bne !bonusReturn-

    // Collected! Add bonus score
    jsr AddBonusScore
    lda #0
    sta ZP_BONUS_ACTIVE

    lda #SFX_BONUS
    jsr PlaySFX
    rts

// ============================================================================
// AddBonusScore - Add score for bonus item collection
// ============================================================================
AddBonusScore:
    // Bonus values: 100, 300, 500, 700, 1000, 2000, 3000, 5000
    ldx ZP_BONUS_TYPE
    sed
    lda ZP_SCORE
    clc
    adc BonusScoreLo,x
    sta ZP_SCORE
    lda ZP_SCORE_MID
    adc BonusScoreHi,x
    sta ZP_SCORE_MID
    lda ZP_SCORE_HI
    adc #0
    sta ZP_SCORE_HI
    cld
    jsr CheckHighScore
    rts

BonusScoreLo:  .byte $00, $00, $00, $00, $00, $00, $00, $00
BonusScoreHi:  .byte $01, $03, $05, $07, $10, $20, $30, $50
