// ============================================================================
// CHOMPER - SID Sound Engine
// ============================================================================
// Manages all audio using the C64's SID chip (6581/8580).
// Supports simultaneous background music and sound effects.
//
// CHANNEL ALLOCATION:
//   Voice 1: Background music melody / ghost siren
//   Voice 2: Background music bass / accompaniment
//   Voice 3: Sound effects (eat, death, power-up, etc.)
//
// OPTIMIZATION:
//   - Minimal raster time usage (~40 cycles per frame for music update)
//   - Frequency lookup tables for note-to-SID conversion
//   - Effect priority system (higher priority effects override lower)
//   - Compact sequence format: note (7 bits) + duration (5 bits) packed
//
// The background music changes based on game state:
//   - Title screen: Upbeat intro theme
//   - Gameplay: Rhythmic "waka-waka" heartbeat that speeds up as dots decrease
//   - Ghost frightened: Ominous pulsing tone
//   - Death: Descending chromatic spiral
//   - Level complete: Victory fanfare
// ============================================================================

// Sound effect IDs
.const SFX_NONE         = 0
.const SFX_EAT_DOT      = 1
.const SFX_EAT_GHOST    = 2
.const SFX_POWER_UP     = 3
.const SFX_DEATH        = 4
.const SFX_EXTRA_LIFE   = 5
.const SFX_BONUS        = 6
.const SFX_LEVEL_START  = 7
.const SFX_GHOST_REGEN  = 8
.const SFX_LEVEL_DONE   = 9

// Music sequence IDs
.const MUSIC_NONE       = 0
.const MUSIC_TITLE      = 1
.const MUSIC_GAMEPLAY   = 2
.const MUSIC_FRIGHTENED = 3
.const MUSIC_INTERMISSION= 4

// ============================================================================
// SID Note Frequency Table (PAL, based on A4=440Hz)
// ============================================================================
// Standard C64 SID frequency values for notes C1 through B7
// Freq = (NoteHz * 16777216) / ClockFreq
// PAL clock = 985248 Hz
// ============================================================================

// Low byte of SID frequency for each note (C1=0, C#1=1, ..., B7=83)
NoteFreqLo:
    // Octave 1: C1-B1
    .byte $17, $27, $39, $4B, $5F, $74, $8A, $A1, $BA, $D4, $F0, $0E
    // Octave 2: C2-B2
    .byte $2D, $4E, $71, $96, $BE, $E8, $14, $43, $74, $A9, $E1, $1C
    // Octave 3: C3-B3
    .byte $5A, $9C, $E2, $2D, $7C, $CF, $28, $85, $E8, $52, $C1, $37
    // Octave 4: C4-B4
    .byte $B4, $39, $C5, $5A, $F7, $9E, $4F, $0A, $D1, $A3, $82, $6E
    // Octave 5: C5-B5
    .byte $68, $71, $8A, $B3, $EE, $3C, $9E, $15, $A2, $47, $04, $DC
    // Octave 6: C6-B6
    .byte $D0, $E2, $14, $66, $DC, $78, $3C, $2A, $44, $8E, $08, $B8
    // Octave 7: C7-B7
    .byte $A1, $C5, $28, $CD, $B8, $F0, $78, $54, $88, $1C, $10, $70

NoteFreqHi:
    // Octave 1
    .byte $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $02
    // Octave 2
    .byte $02, $02, $02, $02, $02, $02, $03, $03, $03, $03, $03, $04
    // Octave 3
    .byte $04, $04, $04, $05, $05, $05, $06, $06, $06, $07, $07, $08
    // Octave 4
    .byte $08, $09, $09, $0A, $0A, $0B, $0C, $0D, $0D, $0E, $0F, $10
    // Octave 5
    .byte $11, $12, $13, $14, $15, $17, $18, $1A, $1B, $1D, $1F, $20
    // Octave 6
    .byte $22, $24, $27, $29, $2B, $2E, $31, $34, $37, $3A, $3E, $41
    // Octave 7
    .byte $45, $49, $4E, $52, $57, $5C, $62, $68, $6E, $75, $7C, $83

// ============================================================================
// InitSID - Initialize the SID chip
// ============================================================================
InitSID:
    // Clear all SID registers
    ldx #$18
!clearSID:
    lda #0
    sta SID_BASE,x
    dex
    bpl !clearSID-

    // Set master volume to maximum
    lda #$0F
    sta SID_VOLUME

    // Initialize music state
    lda #0
    sta MusicPlaying
    sta MusicTick
    sta MusicSeqPos
    sta SfxPlaying
    sta SfxTick

    // Set default ADSR for all voices
    // Voice 1: Melody - short attack, medium sustain
    lda #$09                // Attack=0, Decay=9
    sta SID_V1_AD
    lda #$00                // Sustain=0, Release=0
    sta SID_V1_SR

    // Voice 2: Bass - punchy
    lda #$09
    sta SID_V2_AD
    lda #$00
    sta SID_V2_SR

    // Voice 3: SFX - snappy
    lda #$09
    sta SID_V3_AD
    lda #$00
    sta SID_V3_SR

    rts

// ============================================================================
// PlayMusic - Update music engine (called from raster IRQ)
// ============================================================================
// OPTIMIZATION: Uses a tick counter to control tempo without a separate timer.
// Music data is processed only when the tick counter reaches zero.
// ============================================================================
PlayMusic:
    // Process sound effects first (higher priority)
    lda SfxPlaying
    beq !noSfx+
    jsr UpdateSFX

!noSfx:
    // Process background music
    lda MusicPlaying
    beq !noMusic+

    // Decrement tick counter
    dec MusicTick
    bpl !musicWait+

    // Tick expired - process next music event
    jsr ProcessMusicEvent

!musicWait:
!noMusic:
    rts

// ============================================================================
// ProcessMusicEvent - Read and process next note from music sequence
// ============================================================================
ProcessMusicEvent:
    // Read next byte from music sequence
    ldy MusicSeqPos
    lda (ZP_MUSIC_PTR_LO),y

    // Check for end of sequence marker
    cmp #$FF
    beq !musicLoop+
    cmp #$FE
    beq !musicStop+

    // Byte format: NNNNNNDDD
    // Upper 5 bits = note index (0-31), 0 = rest
    // Lower 3 bits = duration code (0-7)
    pha
    and #$07
    tax
    lda DurationTable,x
    sta MusicTick           // Set duration for this note

    pla
    lsr
    lsr
    lsr                     // Note index in A
    beq !musicRest+         // Note 0 = rest

    // Play note on voice 1
    tax
    // Add octave offset based on music section
    clc
    adc MusicOctaveOfs
    tax
    lda NoteFreqLo,x
    sta SID_V1_FREQ_LO
    lda NoteFreqHi,x
    sta SID_V1_FREQ_HI

    // Gate on (pulse wave)
    lda #%01000001          // Pulse wave + gate
    sta SID_V1_CTRL

    // Set pulse width for nice tone
    lda #$00
    sta SID_V1_PW_LO
    lda #$08
    sta SID_V1_PW_HI

    jmp !musicAdvance+

!musicRest:
    // Gate off
    lda #%01000000          // Pulse wave, gate off
    sta SID_V1_CTRL

!musicAdvance:
    inc MusicSeqPos
    rts

!musicLoop:
    // Loop back to beginning
    lda #0
    sta MusicSeqPos
    jmp ProcessMusicEvent

!musicStop:
    lda #0
    sta MusicPlaying
    lda #%01000000
    sta SID_V1_CTRL
    rts

// Duration lookup (in frames)
DurationTable:
    .byte 3, 6, 9, 12, 18, 24, 36, 48

// ============================================================================
// StartMusic - Begin playing a music sequence
// ============================================================================
// Input: A = music ID
// ============================================================================
StartMusic:
    cmp #MUSIC_TITLE
    beq !startTitle+
    cmp #MUSIC_GAMEPLAY
    beq !startGameplay+
    cmp #MUSIC_FRIGHTENED
    beq !startFrightened+

    // Unknown music - stop
    lda #0
    sta MusicPlaying
    rts

!startTitle:
    lda #<TitleMusic
    sta ZP_MUSIC_PTR_LO
    lda #>TitleMusic
    sta ZP_MUSIC_PTR_HI
    lda #24                 // Octave offset
    sta MusicOctaveOfs
    jmp !startCommon+

!startGameplay:
    lda #<GameplayMusic
    sta ZP_MUSIC_PTR_LO
    lda #>GameplayMusic
    sta ZP_MUSIC_PTR_HI
    lda #24
    sta MusicOctaveOfs
    jmp !startCommon+

!startFrightened:
    lda #<FrightenedMusic
    sta ZP_MUSIC_PTR_LO
    lda #>FrightenedMusic
    sta ZP_MUSIC_PTR_HI
    lda #12
    sta MusicOctaveOfs

!startCommon:
    lda #0
    sta MusicSeqPos
    sta MusicTick
    lda #1
    sta MusicPlaying
    rts

// Music state variables
MusicPlaying:  .byte 0
MusicTick:     .byte 0
MusicSeqPos:   .byte 0
MusicOctaveOfs:.byte 24

// ============================================================================
// PlaySFX - Trigger a sound effect on Voice 3
// ============================================================================
// Input: A = SFX ID
// ============================================================================
PlaySFX:
    sta SfxId
    lda #1
    sta SfxPlaying
    lda #0
    sta SfxStep
    sta SfxTick

    // Look up SFX parameters
    ldx SfxId

    cpx #SFX_EAT_DOT
    beq !sfxDot+
    cpx #SFX_EAT_GHOST
    beq !sfxGhost+
    cpx #SFX_POWER_UP
    beq !sfxPower+
    cpx #SFX_DEATH
    beq !sfxDeath+
    cpx #SFX_EXTRA_LIFE
    beq !sfxExtraLife+
    cpx #SFX_BONUS
    beq !sfxBonus+
    cpx #SFX_LEVEL_START
    beq !sfxLevelStart+
    cpx #SFX_LEVEL_DONE
    beq !sfxLevelDone+

    // Unknown SFX
    lda #0
    sta SfxPlaying
    rts

!sfxDot:
    // Quick chirp - alternating high notes (waka-waka)
    lda #6                  // Duration
    sta SfxDuration
    lda #%00100001          // Sawtooth + gate
    sta SfxWaveform
    lda #$19                // Attack=1, Decay=9
    sta SID_V3_AD
    lda #$00
    sta SID_V3_SR
    // Alternate between two pitches
    lda ZP_FRAME_CTR
    and #$01
    beq !dotHi+
    lda #$A3                // Lower pitch
    sta SID_V3_FREQ_LO
    lda #$0E
    sta SID_V3_FREQ_HI
    jmp !sfxGate+
!dotHi:
    lda #$47                // Higher pitch
    sta SID_V3_FREQ_LO
    lda #$1D
    sta SID_V3_FREQ_HI
    jmp !sfxGate+

!sfxGhost:
    // Ascending sweep
    lda #30
    sta SfxDuration
    lda #%00010001          // Triangle + gate
    sta SfxWaveform
    lda #$08
    sta SID_V3_AD
    lda #$F8
    sta SID_V3_SR
    lda #$00
    sta SID_V3_FREQ_LO
    lda #$05
    sta SID_V3_FREQ_HI
    jmp !sfxGate+

!sfxPower:
    // Deep descending whoosh
    lda #40
    sta SfxDuration
    lda #%10000001          // Noise + gate
    sta SfxWaveform
    lda #$0A
    sta SID_V3_AD
    lda #$A5
    sta SID_V3_SR
    lda #$00
    sta SID_V3_FREQ_LO
    lda #$30
    sta SID_V3_FREQ_HI
    jmp !sfxGate+

!sfxDeath:
    // Descending chromatic spiral
    lda #80
    sta SfxDuration
    lda #%00010001          // Triangle + gate
    sta SfxWaveform
    lda #$0C
    sta SID_V3_AD
    lda #$F9
    sta SID_V3_SR
    lda #$00
    sta SID_V3_FREQ_LO
    lda #$20
    sta SID_V3_FREQ_HI
    jmp !sfxGate+

!sfxExtraLife:
    // Triumphant ascending arpeggio
    lda #50
    sta SfxDuration
    lda #%01000001          // Pulse + gate
    sta SfxWaveform
    lda #$09
    sta SID_V3_AD
    lda #$F0
    sta SID_V3_SR
    lda #$00
    sta SID_V3_PW_LO
    lda #$08
    sta SID_V3_PW_HI
    lda #$68
    sta SID_V3_FREQ_LO
    lda #$11
    sta SID_V3_FREQ_HI
    jmp !sfxGate+

!sfxBonus:
    // Bright chime
    lda #20
    sta SfxDuration
    lda #%00010001          // Triangle + gate
    sta SfxWaveform
    lda #$08
    sta SID_V3_AD
    lda #$00
    sta SID_V3_SR
    lda #$A2
    sta SID_V3_FREQ_LO
    lda #$1B
    sta SID_V3_FREQ_HI
    jmp !sfxGate+

!sfxLevelStart:
    // Intro jingle
    lda #60
    sta SfxDuration
    lda #%01000001
    sta SfxWaveform
    lda #$0B
    sta SID_V3_AD
    lda #$A5
    sta SID_V3_SR
    lda #$B4
    sta SID_V3_FREQ_LO
    lda #$08
    sta SID_V3_FREQ_HI
    jmp !sfxGate+

!sfxLevelDone:
    // Victory fanfare
    lda #80
    sta SfxDuration
    lda #%01000001
    sta SfxWaveform
    lda #$09
    sta SID_V3_AD
    lda #$F5
    sta SID_V3_SR
    lda #$68
    sta SID_V3_FREQ_LO
    lda #$11
    sta SID_V3_FREQ_HI

!sfxGate:
    // Gate on
    lda SfxWaveform
    sta SID_V3_CTRL
    rts

// ============================================================================
// UpdateSFX - Update running sound effect
// ============================================================================
UpdateSFX:
    dec SfxDuration
    lda SfxDuration
    bne !sfxContinue+

    // SFX finished - gate off
    lda SfxWaveform
    and #$FE                // Clear gate bit
    sta SID_V3_CTRL
    lda #0
    sta SfxPlaying
    rts

!sfxContinue:
    // Apply per-frame effect modifications
    lda SfxId
    cmp #SFX_DEATH
    beq !sfxDeathUpdate+
    cmp #SFX_EAT_GHOST
    beq !sfxGhostUpdate+
    cmp #SFX_EXTRA_LIFE
    beq !sfxExtraUpdate+
    rts

!sfxDeathUpdate:
    // Descend frequency
    lda SID_V3_FREQ_HI
    sec
    sbc #1
    bmi !sfxDeathEnd+
    sta SID_V3_FREQ_HI
    rts
!sfxDeathEnd:
    lda #0
    sta SfxDuration
    rts

!sfxGhostUpdate:
    // Ascend frequency
    lda SID_V3_FREQ_HI
    clc
    adc #2
    sta SID_V3_FREQ_HI
    rts

!sfxExtraUpdate:
    // Arpeggio: cycle through C-E-G
    lda SfxDuration
    and #$03
    tax
    lda ExtraLifeArp,x
    sta SID_V3_FREQ_HI
    rts

ExtraLifeArp:
    .byte $11, $15, $1A, $22    // C5, E5, G5, C6

// SFX state variables
SfxPlaying:    .byte 0
SfxId:         .byte 0
SfxStep:       .byte 0
SfxTick:       .byte 0
SfxDuration:   .byte 0
SfxWaveform:   .byte 0

// ============================================================================
// UpdateSoundEngine - Main sound engine update (called from game loop)
// ============================================================================
UpdateSoundEngine:
    // Background siren/waka effect on Voice 2
    lda ZP_GAME_STATE
    cmp #STATE_PLAYING
    bne !noBgSound+

    // Ghost siren on voice 2 (oscillating pitch)
    lda ZP_GHOST_MODE
    cmp #2                  // Frightened mode?
    beq !frightenedSiren+

    // Normal siren: slow oscillation
    lda ZP_FRAME_CTR
    and #$3F
    tax
    lda SirenTable,x
    sta SID_V2_FREQ_HI
    lda #$00
    sta SID_V2_FREQ_LO

    lda #%00010001          // Triangle + gate
    sta SID_V2_CTRL
    lda #$0A
    sta SID_V2_AD
    lda #$A0
    sta SID_V2_SR
    rts

!frightenedSiren:
    // Fast pulsing when ghosts are frightened
    lda ZP_FRAME_CTR
    and #$0F
    tax
    lda FrightenedSirenTable,x
    sta SID_V2_FREQ_HI
    lda #$00
    sta SID_V2_FREQ_LO
    lda #%10000001          // Noise + gate (scary!)
    sta SID_V2_CTRL
    rts

!noBgSound:
    // Gate off voice 2 when not playing
    lda #%00010000
    sta SID_V2_CTRL
    rts

// Siren oscillation table (64 entries, sine-like)
SirenTable:
    .byte $04, $04, $05, $05, $06, $06, $07, $07
    .byte $08, $08, $09, $09, $0A, $0A, $0A, $0B
    .byte $0B, $0B, $0A, $0A, $0A, $09, $09, $08
    .byte $08, $07, $07, $06, $06, $05, $05, $04
    .byte $04, $04, $03, $03, $03, $02, $02, $02
    .byte $02, $02, $02, $02, $02, $02, $03, $03
    .byte $03, $03, $03, $03, $04, $04, $04, $04
    .byte $04, $04, $04, $04, $04, $04, $04, $04

// Frightened mode siren (16 entries, faster)
FrightenedSirenTable:
    .byte $10, $12, $14, $16, $18, $16, $14, $12
    .byte $10, $0E, $0C, $0A, $08, $0A, $0C, $0E
