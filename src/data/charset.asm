// ============================================================================
// CHOMPER - Custom Character Set Data
// ============================================================================
// 256 characters x 8 bytes each = 2048 bytes (2KB)
// Located at $2000-$27FF
//
// Character Design Philosophy:
//   - Maze walls use multicolor mode for a rich, 3D-beveled look
//   - In multicolor mode, each char is 4x8 "fat pixels"
//   - Bit pairs: 00=bgcolor0, 01=bgcolor1, 10=bgcolor2, 11=char color
//   - Dots and power pellets use hi-res mode (individual color per char)
//
// Character Index:
//   0    = Empty space
//   1    = Horizontal wall segment
//   2    = Vertical wall segment
//   3-6  = Corner pieces (TL, TR, BL, BR)
//   7    = Dot (regular pellet)
//   8    = Power pellet (Star Core) frame 1
//   9    = Ghost house gate
//   10-18= Additional wall pieces (T-junctions, dead ends)
//   19   = Life indicator icon
//   20-25= Double-line outer wall pieces
//   26   = Power pellet frame 2 (blink)
//   27-30= Bonus item characters
//   32-47= Title screen letters (CHOMPER)
//   48-57= Digits 0-9
//   58-63= Score labels (SC, HI, LV)
// ============================================================================

// Character 0: Empty space
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00000000

// Character 1: Horizontal wall (multicolor)
// Uses bit pairs: 01=blue(wall), 10=dark_grey(shade), 11=char_color(highlight)
    .byte %00000000
    .byte %00000000
    .byte %11111111       // Top highlight line
    .byte %01010101       // Wall fill (blue)
    .byte %01010101       // Wall fill
    .byte %10101010       // Bottom shade
    .byte %00000000
    .byte %00000000

// Character 2: Vertical wall (multicolor)
    .byte %00110100
    .byte %00110100
    .byte %00110100
    .byte %00110100
    .byte %00110100
    .byte %00110100
    .byte %00110100
    .byte %00110100

// Character 3: Top-left corner (multicolor)
    .byte %00000000
    .byte %00000000
    .byte %00001111       // Horizontal enters from right
    .byte %00010101       // Corner fill
    .byte %00010101
    .byte %00110100       // Vertical exits downward
    .byte %00110100
    .byte %00110100

// Character 4: Top-right corner (multicolor)
    .byte %00000000
    .byte %00000000
    .byte %11110000       // Horizontal enters from left
    .byte %01010100       // Corner fill
    .byte %01010100
    .byte %00110100       // Vertical exits downward (centered)
    .byte %00110100
    .byte %00110100

// Character 5: Bottom-left corner (multicolor)
    .byte %00110100
    .byte %00110100
    .byte %00110100       // Vertical enters from top
    .byte %00010101       // Corner fill
    .byte %00010101
    .byte %00001111       // Horizontal exits right
    .byte %00000000
    .byte %00000000

// Character 6: Bottom-right corner (multicolor)
    .byte %00110100
    .byte %00110100
    .byte %00110100       // Vertical enters from top
    .byte %01010100       // Corner fill
    .byte %01010100
    .byte %11110000       // Horizontal exits left
    .byte %00000000
    .byte %00000000

// Character 7: Dot (hi-res - uses char color from Color RAM)
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00011000       // Small centered dot
    .byte %00011000
    .byte %00000000
    .byte %00000000
    .byte %00000000

// Character 8: Power Pellet / Star Core frame 1 (hi-res)
    .byte %00000000
    .byte %00111100
    .byte %01111110
    .byte %01111110       // Large glowing orb
    .byte %01111110
    .byte %01111110
    .byte %00111100
    .byte %00000000

// Character 9: Ghost house gate (multicolor)
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %11111111       // Thin gate line
    .byte %11111111
    .byte %00000000
    .byte %00000000
    .byte %00000000

// Character 10: T-junction top (wall goes left, right, down)
    .byte %00000000
    .byte %00000000
    .byte %11111111
    .byte %01010101
    .byte %01010101
    .byte %00110100
    .byte %00110100
    .byte %00110100

// Character 11: T-junction bottom (wall goes left, right, up)
    .byte %00110100
    .byte %00110100
    .byte %00110100
    .byte %01010101
    .byte %01010101
    .byte %10101010
    .byte %00000000
    .byte %00000000

// Character 12: T-junction left (wall goes up, down, right)
    .byte %00110100
    .byte %00110100
    .byte %00110101
    .byte %00010101
    .byte %00010101
    .byte %00110101
    .byte %00110100
    .byte %00110100

// Character 13: T-junction right (wall goes up, down, left)
    .byte %00110100
    .byte %00110100
    .byte %01010100
    .byte %01010100
    .byte %01010100
    .byte %01010100
    .byte %00110100
    .byte %00110100

// Character 14: Cross junction (all four directions)
    .byte %00110100
    .byte %00110100
    .byte %01010101
    .byte %01010101
    .byte %01010101
    .byte %01010101
    .byte %00110100
    .byte %00110100

// Character 15: Dead end up (wall stub pointing up)
    .byte %00110100
    .byte %00110100
    .byte %00110100
    .byte %00010100
    .byte %00101000
    .byte %00000000
    .byte %00000000
    .byte %00000000

// Character 16: Dead end down (wall stub pointing down)
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00010100
    .byte %00110100
    .byte %00110100
    .byte %00110100
    .byte %00110100

// Character 17: Dead end left
    .byte %00000000
    .byte %00000000
    .byte %00001111
    .byte %00000101
    .byte %00000101
    .byte %00001010
    .byte %00000000
    .byte %00000000

// Character 18: Dead end right
    .byte %00000000
    .byte %00000000
    .byte %11110000
    .byte %01010000
    .byte %01010000
    .byte %10100000
    .byte %00000000
    .byte %00000000

// Character 19: Life indicator (small chomper icon)
    .byte %00000000
    .byte %00111100
    .byte %01111110
    .byte %01111000       // Mouth open to the right
    .byte %01110000
    .byte %01111110
    .byte %00111100
    .byte %00000000

// Character 20: Double horizontal wall (outer border)
    .byte %00000000
    .byte %11111111
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %11111111
    .byte %00000000

// Character 21: Double vertical wall (outer border)
    .byte %01100110
    .byte %01100110
    .byte %01100110
    .byte %01100110
    .byte %01100110
    .byte %01100110
    .byte %01100110
    .byte %01100110

// Character 22: Double corner top-left
    .byte %00000000
    .byte %00111111
    .byte %00100000
    .byte %00100000
    .byte %00100000
    .byte %00100000
    .byte %00111111
    .byte %00000000

// Character 23: Double corner top-right
    .byte %00000000
    .byte %11111100
    .byte %00000100
    .byte %00000100
    .byte %00000100
    .byte %00000100
    .byte %11111100
    .byte %00000000

// Character 24: Double corner bottom-left
    .byte %00000000
    .byte %00111111
    .byte %00100000
    .byte %00100000
    .byte %00100000
    .byte %00100000
    .byte %00111111
    .byte %00000000

// Character 25: Double corner bottom-right
    .byte %00000000
    .byte %11111100
    .byte %00000100
    .byte %00000100
    .byte %00000100
    .byte %00000100
    .byte %11111100
    .byte %00000000

// Character 26: Power pellet frame 2 (smaller - blink animation)
    .byte %00000000
    .byte %00000000
    .byte %00111100
    .byte %00111100
    .byte %00111100
    .byte %00111100
    .byte %00000000
    .byte %00000000

// Character 27: Bonus - Cosmic Cherry
    .byte %00000100
    .byte %00001000
    .byte %00111100
    .byte %01111110
    .byte %01111110
    .byte %01111110
    .byte %00111100
    .byte %00000000

// Character 28: Bonus - Nova Star
    .byte %00010000
    .byte %00111000
    .byte %11111110
    .byte %01111100
    .byte %01111100
    .byte %11111110
    .byte %00111000
    .byte %00010000

// Character 29: Bonus - Quantum Diamond
    .byte %00010000
    .byte %00111000
    .byte %01111100
    .byte %11111110
    .byte %01111100
    .byte %00111000
    .byte %00010000
    .byte %00000000

// Character 30: Bonus - Stellar Crown
    .byte %01010100
    .byte %01010100
    .byte %11111110
    .byte %11111110
    .byte %01111100
    .byte %01111100
    .byte %01111100
    .byte %00000000

// Character 31: Bonus - Nebula Key
    .byte %01110000
    .byte %10001000
    .byte %10001000
    .byte %01110000
    .byte %00100000
    .byte %00111000
    .byte %00100000
    .byte %00111000

// Characters 32-47: Title screen graphics
// Character 32: Space (standard)
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00000000

// Character 33: 'C' for CHOMPER title
    .byte %00111110
    .byte %01111111
    .byte %01100000
    .byte %01100000
    .byte %01100000
    .byte %01111111
    .byte %00111110
    .byte %00000000

// Character 34: 'H'
    .byte %01100110
    .byte %01100110
    .byte %01100110
    .byte %01111110
    .byte %01100110
    .byte %01100110
    .byte %01100110
    .byte %00000000

// Character 35: 'O'
    .byte %00111100
    .byte %01100110
    .byte %01100110
    .byte %01100110
    .byte %01100110
    .byte %01100110
    .byte %00111100
    .byte %00000000

// Character 36: 'M'
    .byte %01100011
    .byte %01110111
    .byte %01111111
    .byte %01101011
    .byte %01100011
    .byte %01100011
    .byte %01100011
    .byte %00000000

// Character 37: 'P'
    .byte %01111100
    .byte %01100110
    .byte %01100110
    .byte %01111100
    .byte %01100000
    .byte %01100000
    .byte %01100000
    .byte %00000000

// Character 38: 'E'
    .byte %01111110
    .byte %01100000
    .byte %01100000
    .byte %01111100
    .byte %01100000
    .byte %01100000
    .byte %01111110
    .byte %00000000

// Character 39: 'R'
    .byte %01111100
    .byte %01100110
    .byte %01100110
    .byte %01111100
    .byte %01101000
    .byte %01100100
    .byte %01100010
    .byte %00000000

// Character 40: Chomper logo mouth open (decorative)
    .byte %00011110
    .byte %01111111
    .byte %11111100
    .byte %11110000
    .byte %11111100
    .byte %01111111
    .byte %00011110
    .byte %00000000

// Character 41: Chomper logo mouth closed
    .byte %00011110
    .byte %01111111
    .byte %11111111
    .byte %11111111
    .byte %11111111
    .byte %01111111
    .byte %00011110
    .byte %00000000

// Character 42: Ghost/Spectre icon for title
    .byte %00111100
    .byte %01111110
    .byte %01011010
    .byte %01111110
    .byte %01111110
    .byte %01111110
    .byte %01010101
    .byte %00000000

// Character 43: 'S' for SCORE etc
    .byte %00111110
    .byte %01100000
    .byte %01100000
    .byte %00111100
    .byte %00000110
    .byte %00000110
    .byte %01111100
    .byte %00000000

// Character 44: 'I'
    .byte %00111100
    .byte %00011000
    .byte %00011000
    .byte %00011000
    .byte %00011000
    .byte %00011000
    .byte %00111100
    .byte %00000000

// Character 45: 'L'
    .byte %01100000
    .byte %01100000
    .byte %01100000
    .byte %01100000
    .byte %01100000
    .byte %01100000
    .byte %01111110
    .byte %00000000

// Character 46: 'V'
    .byte %01100110
    .byte %01100110
    .byte %01100110
    .byte %01100110
    .byte %01100110
    .byte %00111100
    .byte %00011000
    .byte %00000000

// Character 47: 'N'
    .byte %01100011
    .byte %01110011
    .byte %01111011
    .byte %01101111
    .byte %01100111
    .byte %01100011
    .byte %01100011
    .byte %00000000

// Characters 48-57: Digits 0-9 (hi-res for score display)
// Character 48: '0'
    .byte %00111100
    .byte %01100110
    .byte %01101110
    .byte %01110110
    .byte %01100110
    .byte %01100110
    .byte %00111100
    .byte %00000000

// Character 49: '1'
    .byte %00011000
    .byte %00111000
    .byte %00011000
    .byte %00011000
    .byte %00011000
    .byte %00011000
    .byte %01111110
    .byte %00000000

// Character 50: '2'
    .byte %00111100
    .byte %01100110
    .byte %00000110
    .byte %00011100
    .byte %00110000
    .byte %01100000
    .byte %01111110
    .byte %00000000

// Character 51: '3'
    .byte %00111100
    .byte %01100110
    .byte %00000110
    .byte %00011100
    .byte %00000110
    .byte %01100110
    .byte %00111100
    .byte %00000000

// Character 52: '4'
    .byte %00001100
    .byte %00011100
    .byte %00101100
    .byte %01001100
    .byte %01111110
    .byte %00001100
    .byte %00001100
    .byte %00000000

// Character 53: '5'
    .byte %01111110
    .byte %01100000
    .byte %01111100
    .byte %00000110
    .byte %00000110
    .byte %01100110
    .byte %00111100
    .byte %00000000

// Character 54: '6'
    .byte %00111100
    .byte %01100110
    .byte %01100000
    .byte %01111100
    .byte %01100110
    .byte %01100110
    .byte %00111100
    .byte %00000000

// Character 55: '7'
    .byte %01111110
    .byte %00000110
    .byte %00001100
    .byte %00011000
    .byte %00110000
    .byte %00110000
    .byte %00110000
    .byte %00000000

// Character 56: '8'
    .byte %00111100
    .byte %01100110
    .byte %01100110
    .byte %00111100
    .byte %01100110
    .byte %01100110
    .byte %00111100
    .byte %00000000

// Character 57: '9'
    .byte %00111100
    .byte %01100110
    .byte %01100110
    .byte %00111110
    .byte %00000110
    .byte %01100110
    .byte %00111100
    .byte %00000000

// Characters 58-63: Additional label characters
// Character 58: ':'
    .byte %00000000
    .byte %00011000
    .byte %00011000
    .byte %00000000
    .byte %00011000
    .byte %00011000
    .byte %00000000
    .byte %00000000

// Character 59: 'A'
    .byte %00111100
    .byte %01100110
    .byte %01100110
    .byte %01111110
    .byte %01100110
    .byte %01100110
    .byte %01100110
    .byte %00000000

// Character 60: 'D'
    .byte %01111100
    .byte %01100110
    .byte %01100110
    .byte %01100110
    .byte %01100110
    .byte %01100110
    .byte %01111100
    .byte %00000000

// Character 61: 'G'
    .byte %00111110
    .byte %01100000
    .byte %01100000
    .byte %01101110
    .byte %01100110
    .byte %01100110
    .byte %00111110
    .byte %00000000

// Character 62: 'T'
    .byte %01111110
    .byte %00011000
    .byte %00011000
    .byte %00011000
    .byte %00011000
    .byte %00011000
    .byte %00011000
    .byte %00000000

// Character 63: 'Y'
    .byte %01100110
    .byte %01100110
    .byte %01100110
    .byte %00111100
    .byte %00011000
    .byte %00011000
    .byte %00011000
    .byte %00000000

// Characters 64-127: Maze wall auto-tile lookup (filled with wall variants)
// These are generated variants for the maze renderer's auto-tiling system
// Each character handles a specific neighbor configuration

// Isolated wall block
    .byte %00000000
    .byte %00111100
    .byte %01111110
    .byte %01111110
    .byte %01111110
    .byte %00111100
    .byte %00000000
    .byte %00000000

// Fill remaining characters 65-127 with wall variants
.fill 63*8, {
    .var charIdx = floor(i/8)
    .var row = i % 8
    .var hasN = (charIdx & 1) != 0
    .var hasS = (charIdx & 2) != 0
    .var hasW = (charIdx & 4) != 0
    .var hasE = (charIdx & 8) != 0
    .var inner = (charIdx & 16) != 0
    .var topEdge = (row == 0 || row == 1)
    .var botEdge = (row == 6 || row == 7)

    .eval {
        .var val = %00000000
        // Vertical connection
        .if (hasN && topEdge) .eval val = val | %00110000
        .if (hasS && botEdge) .eval val = val | %00110000
        // Horizontal connection
        .if (hasW && row >= 2 && row <= 5) .eval val = val | %11000000
        .if (hasE && row >= 2 && row <= 5) .eval val = val | %00000011
        // Core body
        .if (row >= 2 && row <= 5) .eval val = val | %00111100
        // Return
        .eval val
    }
}

// Characters 128-191: Inverse/alternate versions for effects
.fill 64*8, {
    .var charIdx = floor(i/8)
    .var row = i % 8
    // Frightened mode wall flash pattern
    .if (charIdx < 32) {
        .eval ((row + charIdx) & 1) == 0 ? %10101010 : %01010101
    } else {
        .eval %00000000
    }
}

// Characters 192-255: Reserved for dynamic updates / tunnel animation
.fill 64*8, $00
