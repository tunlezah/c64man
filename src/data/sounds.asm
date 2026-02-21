// ============================================================================
// CHOMPER - Music & Sound Data
// ============================================================================
// Music sequences and sound effect parameters for the SID chip.
//
// MUSIC FORMAT:
//   Each byte encodes: NNNNN DDD
//   - NNNNN (bits 7-3): Note index (0=rest, 1-31 = notes from scale)
//     Note mapping: 1=C, 2=C#, 3=D, 4=D#, 5=E, 6=F, 7=F#, 8=G,
//                   9=G#, 10=A, 11=A#, 12=B, then repeats for next octave
//   - DDD (bits 2-0): Duration code
//     0=3 frames, 1=6, 2=9, 3=12, 4=18, 5=24, 6=36, 7=48
//
//   Special bytes:
//     $FF = Loop to beginning
//     $FE = End of sequence (stop playing)
//
// SEQUENCES:
//   TitleMusic      - Upbeat chiptune theme for title screen
//   GameplayMusic   - Rhythmic waka-waka loop during gameplay
//   FrightenedMusic - Ominous pulsing for power pellet mode
// ============================================================================

// ============================================================================
// Title Screen Music
// ============================================================================
// A catchy, energetic 8-bar melody in C major
// Designed to loop seamlessly and capture attention
//
// Melody: C E G C' B G E C | D F A D' C' A F D |
//         E G B E' D' B G E | C E G E C . . .
// ============================================================================
TitleMusic:
    // Bar 1: C major ascending arpeggio
    .byte (1 << 3) | 1     // C4, 6 frames
    .byte (5 << 3) | 0     // E4, 3 frames
    .byte (8 << 3) | 0     // G4, 3 frames
    .byte (13 << 3) | 1    // C5, 6 frames
    .byte (12 << 3) | 0    // B4, 3 frames
    .byte (8 << 3) | 0     // G4, 3 frames
    .byte (5 << 3) | 1     // E4, 6 frames
    .byte (1 << 3) | 1     // C4, 6 frames

    // Bar 2: D minor arpeggio
    .byte (3 << 3) | 1     // D4, 6 frames
    .byte (6 << 3) | 0     // F4, 3 frames
    .byte (10 << 3) | 0    // A4, 3 frames
    .byte (15 << 3) | 1    // D5, 6 frames
    .byte (13 << 3) | 0    // C5, 3 frames
    .byte (10 << 3) | 0    // A4, 3 frames
    .byte (6 << 3) | 1     // F4, 6 frames
    .byte (3 << 3) | 1     // D4, 6 frames

    // Bar 3: E minor arpeggio
    .byte (5 << 3) | 1     // E4, 6 frames
    .byte (8 << 3) | 0     // G4, 3 frames
    .byte (12 << 3) | 0    // B4, 3 frames
    .byte (17 << 3) | 1    // E5, 6 frames
    .byte (15 << 3) | 0    // D5, 3 frames
    .byte (12 << 3) | 0    // B4, 3 frames
    .byte (8 << 3) | 1     // G4, 6 frames
    .byte (5 << 3) | 1     // E4, 6 frames

    // Bar 4: Resolution back to C
    .byte (1 << 3) | 2     // C4, 9 frames
    .byte (5 << 3) | 1     // E4, 6 frames
    .byte (8 << 3) | 2     // G4, 9 frames
    .byte (5 << 3) | 1     // E4, 6 frames
    .byte (1 << 3) | 3     // C4, 12 frames

    // Bar 5: Rhythmic variation
    .byte (8 << 3) | 0     // G4, 3 frames
    .byte (0 << 3) | 0     // rest, 3 frames
    .byte (8 << 3) | 0     // G4, 3 frames
    .byte (10 << 3) | 1    // A4, 6 frames
    .byte (8 << 3) | 0     // G4, 3 frames
    .byte (0 << 3) | 0     // rest
    .byte (5 << 3) | 2     // E4, 9 frames
    .byte (1 << 3) | 2     // C4, 9 frames

    // Bar 6: Build up
    .byte (3 << 3) | 0     // D4
    .byte (5 << 3) | 0     // E4
    .byte (6 << 3) | 0     // F4
    .byte (8 << 3) | 0     // G4
    .byte (10 << 3) | 0    // A4
    .byte (12 << 3) | 0    // B4
    .byte (13 << 3) | 1    // C5, 6 frames
    .byte (0 << 3) | 1     // rest

    // Bar 7: Descending with rhythm
    .byte (13 << 3) | 0    // C5
    .byte (12 << 3) | 0    // B4
    .byte (10 << 3) | 0    // A4
    .byte (8 << 3) | 1     // G4
    .byte (6 << 3) | 0     // F4
    .byte (5 << 3) | 0     // E4
    .byte (3 << 3) | 0     // D4
    .byte (1 << 3) | 1     // C4

    // Bar 8: Ending flourish
    .byte (1 << 3) | 0     // C4
    .byte (8 << 3) | 0     // G4
    .byte (13 << 3) | 0    // C5
    .byte (8 << 3) | 0     // G4
    .byte (1 << 3) | 2     // C4, held
    .byte (0 << 3) | 2     // rest

    .byte $FF               // Loop

// ============================================================================
// Gameplay Music - "Waka-Waka" Rhythmic Loop
// ============================================================================
// Simple, repetitive rhythm that complements the dot-eating sounds
// Inspired by the arcade's background siren but more musical
// Uses low octave notes for a driving bass feel
// ============================================================================
GameplayMusic:
    // Driving bass pattern
    .byte (1 << 3) | 0     // C, quick
    .byte (0 << 3) | 0     // rest
    .byte (1 << 3) | 0     // C
    .byte (0 << 3) | 0     // rest
    .byte (5 << 3) | 0     // E
    .byte (0 << 3) | 0     // rest
    .byte (1 << 3) | 0     // C
    .byte (0 << 3) | 0     // rest

    .byte (8 << 3) | 0     // G
    .byte (0 << 3) | 0     // rest
    .byte (5 << 3) | 0     // E
    .byte (0 << 3) | 0     // rest
    .byte (1 << 3) | 1     // C, held
    .byte (0 << 3) | 0     // rest

    .byte (1 << 3) | 0     // C
    .byte (0 << 3) | 0     // rest
    .byte (3 << 3) | 0     // D
    .byte (0 << 3) | 0     // rest
    .byte (5 << 3) | 0     // E
    .byte (0 << 3) | 0     // rest
    .byte (6 << 3) | 0     // F
    .byte (0 << 3) | 0     // rest

    .byte (5 << 3) | 1     // E, held
    .byte (3 << 3) | 0     // D
    .byte (1 << 3) | 1     // C, held
    .byte (0 << 3) | 1     // rest

    .byte $FF               // Loop

// ============================================================================
// Frightened Mode Music - Ominous Pulse
// ============================================================================
// Low, threatening pulse when ghosts are frightened
// Creates tension and urgency
// ============================================================================
FrightenedMusic:
    .byte (1 << 3) | 0     // Low C
    .byte (2 << 3) | 0     // C#
    .byte (1 << 3) | 0     // C
    .byte (0 << 3) | 0     // rest
    .byte (1 << 3) | 0     // C
    .byte (2 << 3) | 0     // C#
    .byte (3 << 3) | 0     // D
    .byte (0 << 3) | 0     // rest

    .byte (1 << 3) | 0     // C
    .byte (0 << 3) | 0     // rest
    .byte (6 << 3) | 0     // F (tritone - dissonant!)
    .byte (0 << 3) | 0     // rest
    .byte (1 << 3) | 1     // C
    .byte (0 << 3) | 1     // rest

    .byte $FF               // Loop

// ============================================================================
// Intermission Music (played between certain levels)
// ============================================================================
IntermissionMusic:
    // Fun little ditty
    .byte (8 << 3) | 1     // G
    .byte (10 << 3) | 0    // A
    .byte (12 << 3) | 0    // B
    .byte (13 << 3) | 2    // C5, held
    .byte (12 << 3) | 0    // B
    .byte (10 << 3) | 0    // A
    .byte (8 << 3) | 2     // G

    .byte (5 << 3) | 1     // E
    .byte (8 << 3) | 0     // G
    .byte (10 << 3) | 0    // A
    .byte (8 << 3) | 2     // G
    .byte (5 << 3) | 1     // E
    .byte (1 << 3) | 3     // C, long hold

    .byte (0 << 3) | 3     // rest

    .byte $FE               // Stop (don't loop)
