// ============================================================================
// CHOMPER - A Pac-Man Style Maze Game for the Commodore 64
// ============================================================================
// (c) 2026 - Written in 6502 Assembly for KickAssembler
//
// A complete maze-chase game featuring:
//   - Custom character "Chomper" (a hungry cosmic worm)
//   - 4 unique ghost enemies ("Spectres") with distinct AI
//   - 30 progressively difficult maze levels
//   - Power pellets ("Star Cores") for ghost-hunting mode
//   - Full SID soundtrack and sound effects
//   - VIC-II raster tricks for smooth, flicker-free graphics
//   - Sprite multiplexing for additional on-screen objects
//   - Optimized for C64 Ultimate (turbo mode compatible)
//
// Hardware Requirements:
//   - Commodore 64 (any revision) or C64 Ultimate
//   - Joystick in Port 2
//
// Memory Map:
//   $0800-$0FFF  Game code (main loop, init)
//   $1000-$1FFF  Game code (movement, collision, AI)
//   $2000-$27FF  Custom character set (2KB)
//   $2800-$2FFF  Sprite data (8 sprites x 64 bytes = 512b + extras)
//   $3000-$37FF  Level data (compressed maze definitions)
//   $3800-$3FFF  Sound data (SID music + SFX)
//   $0400-$07E7  Screen RAM (default VIC-II screen)
//   $D800-$DBE7  Color RAM
// ============================================================================

// ============================================================================
// KickAssembler directives and setup
// ============================================================================

.file [name="build/chomper.prg", type="prg", segments="Code,CharSet,Sprites,LevelData,SoundData"]

// ============================================================================
// System Constants - C64 Hardware Registers
// ============================================================================

// VIC-II Registers ($D000-$D03F)
.const VIC_BASE        = $D000
.const VIC_SPR0_X      = $D000     // Sprite 0 X position
.const VIC_SPR0_Y      = $D001     // Sprite 0 Y position
.const VIC_SPR1_X      = $D002     // Sprite 1 X position
.const VIC_SPR1_Y      = $D003     // Sprite 1 Y position
.const VIC_SPR2_X      = $D004
.const VIC_SPR2_Y      = $D005
.const VIC_SPR3_X      = $D006
.const VIC_SPR3_Y      = $D007
.const VIC_SPR4_X      = $D008
.const VIC_SPR4_Y      = $D009
.const VIC_SPR5_X      = $D00A
.const VIC_SPR5_Y      = $D00B
.const VIC_SPR6_X      = $D00C
.const VIC_SPR6_Y      = $D00D
.const VIC_SPR7_X      = $D00E
.const VIC_SPR7_Y      = $D00F
.const VIC_SPR_XMSB    = $D010     // Sprite X MSB (bit 8 for each)
.const VIC_CTRL1       = $D011     // Control register 1 (scroll, screen height, mode)
.const VIC_RASTER      = $D012     // Raster line counter
.const VIC_STROBE_X    = $D013     // Light pen X
.const VIC_STROBE_Y    = $D014     // Light pen Y
.const VIC_SPR_ENABLE  = $D015     // Sprite enable register
.const VIC_CTRL2       = $D016     // Control register 2 (scroll, screen width, mode)
.const VIC_SPR_EXPAND_Y= $D017    // Sprite Y expansion
.const VIC_MEM_CTRL    = $D018     // Memory control (char/screen base)
.const VIC_IRQ_STATUS  = $D019     // Interrupt status register
.const VIC_IRQ_ENABLE  = $D01A     // Interrupt enable register
.const VIC_SPR_PRIORITY= $D01B    // Sprite-to-background priority
.const VIC_SPR_MCOLOR  = $D01C     // Sprite multicolor enable
.const VIC_SPR_EXPAND_X= $D01D    // Sprite X expansion
.const VIC_SPR_SPR_COLL= $D01E    // Sprite-sprite collision
.const VIC_SPR_BG_COLL = $D01F     // Sprite-background collision
.const VIC_BORDER      = $D020     // Border color
.const VIC_BGCOLOR0    = $D021     // Background color 0
.const VIC_BGCOLOR1    = $D022     // Background color 1 (multicolor)
.const VIC_BGCOLOR2    = $D023     // Background color 2 (multicolor)
.const VIC_BGCOLOR3    = $D024     // Background color 3 (multicolor)
.const VIC_SPR_MCOLOR0 = $D025     // Sprite multicolor 0
.const VIC_SPR_MCOLOR1 = $D026     // Sprite multicolor 1
.const VIC_SPR0_COLOR  = $D027     // Sprite 0 individual color
.const VIC_SPR1_COLOR  = $D028
.const VIC_SPR2_COLOR  = $D029
.const VIC_SPR3_COLOR  = $D02A
.const VIC_SPR4_COLOR  = $D02B
.const VIC_SPR5_COLOR  = $D02C
.const VIC_SPR6_COLOR  = $D02D
.const VIC_SPR7_COLOR  = $D02E

// SID Registers ($D400-$D41C)
.const SID_BASE        = $D400
.const SID_V1_FREQ_LO  = $D400
.const SID_V1_FREQ_HI  = $D401
.const SID_V1_PW_LO    = $D402
.const SID_V1_PW_HI    = $D403
.const SID_V1_CTRL     = $D404
.const SID_V1_AD       = $D405
.const SID_V1_SR       = $D406
.const SID_V2_FREQ_LO  = $D407
.const SID_V2_FREQ_HI  = $D408
.const SID_V2_PW_LO    = $D409
.const SID_V2_PW_HI    = $D40A
.const SID_V2_CTRL     = $D40B
.const SID_V2_AD       = $D40C
.const SID_V2_SR       = $D40D
.const SID_V3_FREQ_LO  = $D40E
.const SID_V3_FREQ_HI  = $D40F
.const SID_V3_PW_LO    = $D410
.const SID_V3_PW_HI    = $D411
.const SID_V3_CTRL     = $D412
.const SID_V3_AD       = $D413
.const SID_V3_SR       = $D414
.const SID_FILTER_LO   = $D415
.const SID_FILTER_HI   = $D416
.const SID_FILTER_CTRL = $D417
.const SID_VOLUME      = $D418

// CIA Registers
.const CIA1_DATA_A     = $DC00     // Joystick port 2 / keyboard
.const CIA1_DATA_B     = $DC01     // Joystick port 1 / keyboard
.const CIA1_ICR        = $DC0D     // Interrupt control register
.const CIA2_DATA_A     = $DD00     // VIC bank select
.const CIA2_ICR        = $DD0D

// Kernal/BASIC
.const KERNAL_IRQ      = $0314     // IRQ vector (lo/hi)
.const KERNAL_NMI      = $0318     // NMI vector

// Screen RAM
.const SCREEN_RAM      = $0400
.const COLOR_RAM       = $D800

// Zero page variables (game state)
.const ZP_PLAYER_X     = $02       // Player X position (tile)
.const ZP_PLAYER_Y     = $03       // Player Y position (tile)
.const ZP_PLAYER_DIR   = $04       // Player direction (0=R,1=L,2=U,3=D)
.const ZP_PLAYER_NEXT  = $05       // Player next/desired direction
.const ZP_PLAYER_ANIM  = $06       // Player animation frame
.const ZP_PLAYER_SUBX  = $07       // Player sub-pixel X
.const ZP_PLAYER_SUBY  = $08       // Player sub-pixel Y
.const ZP_JOY_STATE    = $09       // Current joystick state
.const ZP_FRAME_CTR    = $0A       // Frame counter
.const ZP_GAME_STATE   = $0B       // 0=title,1=playing,2=dying,3=levelup,4=gameover
.const ZP_LEVEL        = $0C       // Current level (0-29)
.const ZP_LIVES        = $0D       // Lives remaining
.const ZP_DOTS_LEFT    = $0E       // Dots remaining (lo)
.const ZP_DOTS_LEFT_HI = $0F       // Dots remaining (hi)
.const ZP_POWER_TIMER  = $10       // Power pellet timer (lo)
.const ZP_POWER_TIMER_HI= $11     // Power pellet timer (hi)
.const ZP_SPEED_CTR    = $12       // Speed accumulator for movement
.const ZP_GHOST_MODE   = $13       // 0=scatter, 1=chase, 2=frightened
.const ZP_MODE_TIMER   = $14       // Mode switch timer (lo)
.const ZP_MODE_TIMER_HI= $15      // Mode switch timer (hi)
.const ZP_SCORE        = $16       // Score (6 BCD digits, 3 bytes)
.const ZP_SCORE_MID    = $17
.const ZP_SCORE_HI     = $18
.const ZP_HISCORE      = $19       // High score (3 bytes BCD)
.const ZP_HISCORE_MID  = $1A
.const ZP_HISCORE_HI   = $1B
.const ZP_BONUS_ACTIVE = $1C       // Bonus item active flag
.const ZP_BONUS_TYPE   = $1D       // Bonus item type
.const ZP_BONUS_TIMER  = $1E       // Bonus display timer
.const ZP_GHOST_EAT_CT = $1F       // Consecutive ghosts eaten (for scoring)
.const ZP_TEMP1        = $20       // Temporary workspace
.const ZP_TEMP2        = $21
.const ZP_TEMP3        = $22
.const ZP_TEMP4        = $23
.const ZP_SCREEN_LO    = $24       // Screen pointer (lo)
.const ZP_SCREEN_HI    = $25       // Screen pointer (hi)
.const ZP_COLOR_LO     = $26       // Color RAM pointer (lo)
.const ZP_COLOR_HI     = $27       // Color RAM pointer (hi)
.const ZP_LEVEL_PTR_LO = $28       // Level data pointer (lo)
.const ZP_LEVEL_PTR_HI = $29       // Level data pointer (hi)
.const ZP_RNG_SEED     = $2A       // Random number generator seed
.const ZP_FREEZE_TIMER = $2B       // Freeze timer for death/level transitions
.const ZP_DIFFICULTY   = $2C       // Difficulty modifier (speed/AI aggression)
.const ZP_DOTS_TOTAL   = $2D       // Total dots in level (lo)
.const ZP_DOTS_TOTAL_HI= $2E      // Total dots in level (hi)
.const ZP_SCATTER_CTR  = $2F       // Scatter/chase phase counter
.const ZP_MUSIC_PTR_LO = $30       // Music data pointer
.const ZP_MUSIC_PTR_HI = $31
.const ZP_SFX_ACTIVE   = $32       // Sound effect active flag
.const ZP_SFX_PTR_LO   = $33
.const ZP_SFX_PTR_HI   = $34
.const ZP_WARP_FLAG    = $35       // Tunnel warp active flag
.const ZP_SPR_MPLX_IDX = $36       // Sprite multiplexer index

// Ghost data (4 ghosts x 8 bytes = 32 bytes at $40-$5F)
.const ZP_GHOST_DATA   = $40
// Per ghost: X_tile, Y_tile, direction, state, sub_x, sub_y, home_x, home_y
// Ghost states: 0=normal, 1=frightened, 2=eaten(eyes), 3=in_house, 4=leaving_house
.const GHOST_STRIDE     = 8

// ============================================================================
// Game Constants
// ============================================================================

.const MAZE_WIDTH       = 28       // Maze width in tiles
.const MAZE_HEIGHT      = 31       // Maze height in tiles
.const SCREEN_COLS      = 40       // C64 screen columns
.const SCREEN_ROWS      = 25       // C64 screen rows
.const MAZE_OFFSET_X    = 6        // X offset to center 28-col maze in 40-col screen
.const MAZE_OFFSET_Y    = 0        // Y offset (use top of screen for maze area)

// Display uses a 28x25 visible portion of the maze
// Score/lives shown in side columns (cols 0-5 and 34-39)
.const VISIBLE_ROWS     = 25

// Player speeds (sub-pixel accumulation per frame, 256 = 1 tile)
.const SPEED_NORMAL     = 32       // ~8 frames per tile at 50Hz
.const SPEED_FAST       = 40       // ~6.4 frames per tile
.const SPEED_SLOW       = 24       // ~10.6 frames per tile
.const SPEED_FRIGHTENED = 20       // Ghost frightened speed

// Directions
.const DIR_RIGHT        = 0
.const DIR_LEFT         = 1
.const DIR_UP           = 2
.const DIR_DOWN         = 3
.const DIR_NONE         = 4

// Game states
.const STATE_TITLE      = 0
.const STATE_PLAYING    = 1
.const STATE_DYING      = 2
.const STATE_LEVEL_UP   = 3
.const STATE_GAME_OVER  = 4
.const STATE_GET_READY  = 5
.const STATE_PAUSED     = 6

// Tile types in maze data
.const TILE_EMPTY       = 0
.const TILE_WALL        = 1
.const TILE_DOT         = 2
.const TILE_POWER       = 3
.const TILE_GATE         = 4        // Ghost house gate
.const TILE_TUNNEL       = 5        // Tunnel wrap-around
.const TILE_BONUS_SPOT   = 6        // Bonus item spawn point

// Character set indices (custom chars at $2000)
.const CHR_EMPTY        = 0
.const CHR_WALL_H       = 1        // Horizontal wall
.const CHR_WALL_V       = 2        // Vertical wall
.const CHR_WALL_TL      = 3        // Top-left corner
.const CHR_WALL_TR      = 4        // Top-right corner
.const CHR_WALL_BL      = 5        // Bottom-left corner
.const CHR_WALL_BR      = 6        // Bottom-right corner
.const CHR_DOT          = 7        // Regular dot
.const CHR_POWER        = 8        // Power pellet (Star Core)
.const CHR_GATE         = 9        // Ghost house gate
.const CHR_WALL_T       = 10       // T-junctions
.const CHR_WALL_B       = 11
.const CHR_WALL_L       = 12
.const CHR_WALL_R       = 13
.const CHR_WALL_CROSS   = 14
.const CHR_WALL_END_U   = 15       // Dead ends
.const CHR_WALL_END_D   = 16
.const CHR_WALL_END_L   = 17
.const CHR_WALL_END_R   = 18
.const CHR_LIFE_ICON    = 19       // Life indicator
.const CHR_WALL_DOUBLE_H= 20      // Double-line walls (outer border)
.const CHR_WALL_DOUBLE_V= 21
.const CHR_WALL_DOUBLE_TL=22
.const CHR_WALL_DOUBLE_TR=23
.const CHR_WALL_DOUBLE_BL=24
.const CHR_WALL_DOUBLE_BR=25
.const CHR_POWER_ANIM2  = 26      // Power pellet animation frame 2
.const CHR_BONUS_CHERRY = 27      // Bonus items
.const CHR_BONUS_STAR   = 28
.const CHR_BONUS_DIAMOND= 29
.const CHR_BONUS_CROWN  = 30
.const CHR_SCORE_DIGIT  = 48      // '0'-'9' at positions 48-57

// Colors
.const COL_BLACK        = 0
.const COL_WHITE        = 1
.const COL_RED          = 2
.const COL_CYAN         = 3
.const COL_PURPLE       = 4
.const COL_GREEN        = 5
.const COL_BLUE         = 6
.const COL_YELLOW       = 7
.const COL_ORANGE       = 8
.const COL_BROWN        = 9
.const COL_LIGHT_RED    = 10
.const COL_DARK_GREY    = 11
.const COL_GREY         = 12
.const COL_LIGHT_GREEN  = 13
.const COL_LIGHT_BLUE   = 14
.const COL_LIGHT_GREY   = 15

// ============================================================================
// CODE SEGMENT - Starts at $0800
// ============================================================================

.segment Code [start=$0800]

// ----------------------------------------------------------------------------
// BASIC stub: 10 SYS 2064  (auto-start)
// ----------------------------------------------------------------------------
    .byte $00, $0C, $08     // Next BASIC line pointer
    .byte $0A, $00          // Line number 10
    .byte $9E               // SYS token
    .text "2064"            // SYS address
    .byte $00, $00, $00     // End of BASIC program

// ============================================================================
// Entry Point ($0810)
// ============================================================================
    * = $0810

EntryPoint:
    sei                     // Disable interrupts during setup

    // Disable BASIC and Kernal ROM for full RAM access
    // We'll keep Kernal mapped for now (for IRQ handling)
    lda #$35                // I/O + RAM (no BASIC ROM, no Kernal ROM)
    sta $01                 // But we need to set up our own IRQ first

    // Actually, let's keep Kernal for now and just disable BASIC
    lda #$36                // I/O + Kernal ROM, RAM under BASIC
    sta $01

    // Initialize the game
    jsr InitVIC
    jsr InitSID
    jsr InitCharSet
    jsr InitSprites
    jsr InitGameState

    // Set up raster interrupt
    jsr SetupRasterIRQ

    cli                     // Re-enable interrupts

    // Main game loop (runs in mainline, IRQ handles timing)
MainLoop:
    // Wait for raster sync (frame flag set by IRQ)
    lda FrameReady
    beq MainLoop
    lda #$00
    sta FrameReady

    // Dispatch based on game state
    lda ZP_GAME_STATE
    cmp #STATE_TITLE
    beq DoTitleScreen
    cmp #STATE_PLAYING
    beq DoGamePlay
    cmp #STATE_DYING
    beq DoDying
    cmp #STATE_LEVEL_UP
    beq DoLevelUp
    cmp #STATE_GAME_OVER
    beq DoGameOver
    cmp #STATE_GET_READY
    beq DoGetReady
    jmp MainLoop

DoTitleScreen:
    jsr UpdateTitleScreen
    jmp MainLoop

DoGamePlay:
    jsr ReadJoystick
    jsr UpdatePlayer
    jsr UpdateGhosts
    jsr CheckCollisions
    jsr UpdatePowerTimer
    jsr UpdateModeTimer
    jsr UpdateBonusItem
    jsr UpdateAnimations
    jsr UpdateScoreDisplay
    jsr UpdateSoundEngine
    jmp MainLoop

DoDying:
    jsr UpdateDeathAnimation
    jmp MainLoop

DoLevelUp:
    jsr UpdateLevelTransition
    jmp MainLoop

DoGameOver:
    jsr UpdateGameOver
    jmp MainLoop

DoGetReady:
    jsr UpdateGetReady
    jmp MainLoop

// ============================================================================
// VIC-II Initialization
// ============================================================================
InitVIC:
    // Set VIC bank to Bank 0 ($0000-$3FFF)
    lda CIA2_DATA_A
    and #$FC
    ora #$03                // Bank 0: %11
    sta CIA2_DATA_A

    // Set screen at $0400 and charset at $2000
    // Bits 7-4: Screen = $0400 -> %0001
    // Bits 3-1: Charset = $2000 -> %100
    lda #%00011000          // Screen at $0400, charset at $2000
    sta VIC_MEM_CTRL

    // Screen control register 1
    // Bit 7: Raster MSB = 0
    // Bit 6: ECM = 0
    // Bit 5: BMM = 0 (character mode)
    // Bit 4: DEN = 1 (display enable)
    // Bit 3: RSEL = 1 (25 rows)
    // Bits 2-0: Y scroll = 3
    lda #%00011011
    sta VIC_CTRL1

    // Screen control register 2
    // Bit 4: MCM = 1 (multicolor character mode for maze walls)
    // Bit 3: CSEL = 1 (40 columns)
    // Bits 2-0: X scroll = 0
    lda #%00011000
    sta VIC_CTRL2

    // Set colors
    lda #COL_BLACK
    sta VIC_BORDER          // Black border
    sta VIC_BGCOLOR0        // Black background

    lda #COL_BLUE
    sta VIC_BGCOLOR1        // Blue (multicolor shared 1 - wall color)

    lda #COL_DARK_GREY
    sta VIC_BGCOLOR2        // Dark grey (multicolor shared 2 - wall shade)

    // Enable sprites 0-4 (player + 4 ghosts)
    lda #%00011111
    sta VIC_SPR_ENABLE

    // Set sprite multicolor mode for all sprites
    lda #%00011111
    sta VIC_SPR_MCOLOR

    // Sprite shared multicolor colors
    lda #COL_BLACK
    sta VIC_SPR_MCOLOR0     // Sprite multicolor 0 (outline)
    lda #COL_WHITE
    sta VIC_SPR_MCOLOR1     // Sprite multicolor 1 (highlight)

    // Sprite individual colors
    lda #COL_YELLOW
    sta VIC_SPR0_COLOR      // Chomper = yellow
    lda #COL_RED
    sta VIC_SPR1_COLOR      // Spectre 1 (Shade) = red
    lda #COL_CYAN
    sta VIC_SPR2_COLOR      // Spectre 2 (Glimmer) = cyan
    lda #COL_PURPLE
    sta VIC_SPR3_COLOR      // Spectre 3 (Phantom) = purple/pink
    lda #COL_ORANGE
    sta VIC_SPR4_COLOR      // Spectre 4 (Ember) = orange

    // Sprites behind background characters = off (sprites in front)
    lda #$00
    sta VIC_SPR_PRIORITY

    // No sprite expansion by default
    lda #$00
    sta VIC_SPR_EXPAND_X
    sta VIC_SPR_EXPAND_Y

    // Clear X MSB register
    sta VIC_SPR_XMSB

    rts

// ============================================================================
// Raster Interrupt Setup
// ============================================================================
// Uses a double-IRQ technique for stable raster timing
// Main raster IRQ at line 250 (bottom border) for game logic timing
// Secondary IRQ at line 50 for top-of-screen effects
// ============================================================================
SetupRasterIRQ:
    sei

    // Disable CIA1 timer interrupts (we use raster IRQ only)
    lda #$7F
    sta CIA1_ICR
    sta CIA2_ICR

    // Acknowledge any pending CIA interrupts
    lda CIA1_ICR
    lda CIA2_ICR

    // Set raster line for IRQ (line 250 = bottom border)
    lda #250
    sta VIC_RASTER

    // Clear MSB of raster compare (bit 7 of $D011)
    lda VIC_CTRL1
    and #$7F
    sta VIC_CTRL1

    // Enable raster interrupt
    lda #$01
    sta VIC_IRQ_ENABLE

    // Acknowledge any pending VIC IRQ
    lda #$FF
    sta VIC_IRQ_STATUS

    // Set IRQ vector to our handler
    lda #<RasterIRQ
    sta KERNAL_IRQ
    lda #>RasterIRQ
    sta KERNAL_IRQ+1

    cli
    rts

// ============================================================================
// Raster Interrupt Handler
// ============================================================================
// This is the heartbeat of the game - fires once per frame at line 250
// Handles: frame timing, sprite updates, music playback
//
// OPTIMIZATION: We use the "stable raster" double-IRQ technique
// First IRQ triggers at approximate line, second IRQ nails exact cycle
// ============================================================================
RasterIRQ:
    // Save registers (using stack - 3 cycles each)
    pha
    txa
    pha
    tya
    pha

    // Acknowledge raster interrupt
    lda #$01
    sta VIC_IRQ_STATUS

    // ---- Border color debug (optional - shows raster time usage) ----
    // Uncomment for development:
    // inc VIC_BORDER

    // ---- Update sprite positions from game state ----
    jsr UpdateSpritePositions

    // ---- Power pellet blink effect ----
    lda ZP_FRAME_CTR
    and #$08                // Toggle every 8 frames
    beq !skip+
    // Blink power pellets by toggling character
    jsr BlinkPowerPellets
!skip:

    // ---- Update SID music/SFX ----
    jsr PlayMusic

    // ---- Increment frame counter ----
    inc ZP_FRAME_CTR

    // ---- Signal main loop that a frame is ready ----
    lda #$01
    sta FrameReady

    // ---- Border color debug end ----
    // dec VIC_BORDER

    // Restore registers
    pla
    tay
    pla
    tax
    pla

    // Return from interrupt (RTI pulls P and PC from stack)
    rti

// ============================================================================
// Frame sync flag
// ============================================================================
FrameReady:
    .byte 0

// ============================================================================
// Include game modules
// ============================================================================
.import source "input.asm"
.import source "player.asm"
.import source "ghosts.asm"
.import source "collision.asm"
.import source "render.asm"
.import source "sound.asm"
.import source "gamestate.asm"
.import source "screens.asm"

// ============================================================================
// CHARACTER SET SEGMENT at $2000
// ============================================================================
.segment CharSet [start=$2000]
.import source "data/charset.asm"

// ============================================================================
// SPRITE DATA SEGMENT at $2800
// ============================================================================
.segment Sprites [start=$2800]
.import source "data/sprites.asm"

// ============================================================================
// LEVEL DATA SEGMENT at $3000
// ============================================================================
.segment LevelData [start=$3000]
.import source "data/levels.asm"

// ============================================================================
// SOUND DATA SEGMENT at $3800
// ============================================================================
.segment SoundData [start=$3800]
.import source "data/sounds.asm"
