#!/usr/bin/env python3
"""
CHOMPER - C64 Screen Mockup Generator
======================================
Generates JPEG screenshots showing what the game looks like on a C64.
Uses the actual C64 color palette and character/sprite designs from the game.

Outputs:
  screenshots/01_title_screen.jpg    - Title screen with logo and ghost names
  screenshots/02_gameplay_level1.jpg - Level 1 gameplay with maze, dots, ghosts
  screenshots/03_power_pellet.jpg    - Power pellet mode (frightened ghosts)
  screenshots/04_level_10.jpg        - Mid-game level with higher difficulty
  screenshots/05_game_over.jpg       - Game over screen
  screenshots/06_level_25.jpg        - Late-game complex maze
"""

import os
import struct

# Output directory
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
OUTPUT_DIR = os.path.join(PROJECT_DIR, "screenshots")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# C64 Color Palette (RGB values)
C64_COLORS = {
    0:  (0, 0, 0),         # Black
    1:  (255, 255, 255),   # White
    2:  (136, 0, 0),       # Red
    3:  (170, 255, 238),   # Cyan
    4:  (204, 68, 204),    # Purple
    5:  (0, 204, 85),      # Green
    6:  (0, 0, 170),       # Blue
    7:  (238, 238, 119),   # Yellow
    8:  (221, 136, 85),    # Orange
    9:  (102, 68, 0),      # Brown
    10: (255, 119, 119),   # Light Red
    11: (51, 51, 51),      # Dark Grey
    12: (119, 119, 119),   # Grey
    13: (170, 255, 102),   # Light Green
    14: (0, 136, 255),     # Light Blue
    15: (187, 187, 187),   # Light Grey
}

# Screen dimensions
CHAR_W = 8
CHAR_H = 8
SCREEN_COLS = 40
SCREEN_ROWS = 25
SCREEN_W = SCREEN_COLS * CHAR_W  # 320
SCREEN_H = SCREEN_ROWS * CHAR_H  # 200
BORDER = 32
TOTAL_W = SCREEN_W + BORDER * 2  # 384
TOTAL_H = SCREEN_H + BORDER * 2  # 264

# Scale factor for output
SCALE = 3
OUT_W = TOTAL_W * SCALE
OUT_H = TOTAL_H * SCALE

# ============================================================================
# Minimal BMP/JPEG writer (no PIL dependency)
# We'll write BMP files and note they can be converted, OR we write
# a simple PPM and convert. Let's write BMP directly.
# ============================================================================

def create_image(width, height):
    """Create a blank image as a 2D array of (r,g,b) tuples."""
    return [[(0, 0, 0)] * width for _ in range(height)]

def set_pixel(img, x, y, color):
    """Set a pixel with bounds checking."""
    if 0 <= x < len(img[0]) and 0 <= y < len(img):
        img[y][x] = color

def fill_rect(img, x, y, w, h, color):
    """Fill a rectangle with a solid color."""
    for dy in range(h):
        for dx in range(w):
            set_pixel(img, x + dx, y + dy, color)

def draw_char(img, cx, cy, char_data, fg_color, bg_color=None, scale=SCALE):
    """Draw an 8x8 character at screen position (cx, cy) with scaling."""
    px = (BORDER + cx * CHAR_W) * scale
    py = (BORDER + cy * CHAR_H) * scale
    for row in range(8):
        byte = char_data[row] if row < len(char_data) else 0
        for col in range(8):
            bit = (byte >> (7 - col)) & 1
            color = fg_color if bit else bg_color
            if color is not None:
                for sy in range(scale):
                    for sx in range(scale):
                        set_pixel(img, px + col * scale + sx,
                                 py + row * scale + sy, color)

def draw_sprite(img, sx, sy, sprite_data, color, mc0, mc1, scale=SCALE):
    """Draw a 24x21 multicolor sprite at pixel position (sx, sy)."""
    px = (BORDER + sx) * scale
    py = (BORDER + sy) * scale
    for row in range(21):
        base = row * 3
        if base + 2 >= len(sprite_data):
            break
        # 3 bytes per row = 24 bits = 12 multicolor pixels
        bits = (sprite_data[base] << 16) | (sprite_data[base+1] << 8) | sprite_data[base+2]
        for col in range(12):
            pair = (bits >> (22 - col * 2)) & 0x03
            if pair == 0:
                continue  # Transparent
            elif pair == 1:
                c = mc0
            elif pair == 2:
                c = color
            else:
                c = mc1
            # Each MC pixel is 2 real pixels wide
            for sy2 in range(scale):
                for sx2 in range(scale * 2):
                    set_pixel(img, px + col * scale * 2 + sx2,
                             py + row * scale + sy2, c)

def draw_text(img, x, y, text, color, bg_color=None, scale=SCALE):
    """Draw text using simple built-in font approximation."""
    # Simple 5x7 font for common characters
    font = get_simple_font()
    for i, ch in enumerate(text):
        ch_upper = ch.upper()
        if ch_upper in font:
            char_data = font[ch_upper]
        elif ch == ' ':
            char_data = [0] * 8
        else:
            char_data = [0x7E, 0x42, 0x42, 0x42, 0x42, 0x42, 0x7E, 0]  # box
        draw_char(img, x + i, y, char_data, color, bg_color, scale)

def get_simple_font():
    """Return a minimal bitmap font for text rendering."""
    return {
        'A': [0x3C, 0x66, 0x66, 0x7E, 0x66, 0x66, 0x66, 0x00],
        'B': [0x7C, 0x66, 0x66, 0x7C, 0x66, 0x66, 0x7C, 0x00],
        'C': [0x3E, 0x60, 0x60, 0x60, 0x60, 0x60, 0x3E, 0x00],
        'D': [0x7C, 0x66, 0x66, 0x66, 0x66, 0x66, 0x7C, 0x00],
        'E': [0x7E, 0x60, 0x60, 0x7C, 0x60, 0x60, 0x7E, 0x00],
        'F': [0x7E, 0x60, 0x60, 0x7C, 0x60, 0x60, 0x60, 0x00],
        'G': [0x3E, 0x60, 0x60, 0x6E, 0x66, 0x66, 0x3E, 0x00],
        'H': [0x66, 0x66, 0x66, 0x7E, 0x66, 0x66, 0x66, 0x00],
        'I': [0x3C, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3C, 0x00],
        'J': [0x06, 0x06, 0x06, 0x06, 0x06, 0x66, 0x3C, 0x00],
        'K': [0x66, 0x6C, 0x78, 0x70, 0x78, 0x6C, 0x66, 0x00],
        'L': [0x60, 0x60, 0x60, 0x60, 0x60, 0x60, 0x7E, 0x00],
        'M': [0x63, 0x77, 0x7F, 0x6B, 0x63, 0x63, 0x63, 0x00],
        'N': [0x63, 0x73, 0x7B, 0x6F, 0x67, 0x63, 0x63, 0x00],
        'O': [0x3C, 0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x00],
        'P': [0x7C, 0x66, 0x66, 0x7C, 0x60, 0x60, 0x60, 0x00],
        'Q': [0x3C, 0x66, 0x66, 0x66, 0x6A, 0x6C, 0x36, 0x00],
        'R': [0x7C, 0x66, 0x66, 0x7C, 0x68, 0x64, 0x62, 0x00],
        'S': [0x3E, 0x60, 0x60, 0x3C, 0x06, 0x06, 0x7C, 0x00],
        'T': [0x7E, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00],
        'U': [0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x00],
        'V': [0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x18, 0x00],
        'W': [0x63, 0x63, 0x63, 0x6B, 0x7F, 0x77, 0x63, 0x00],
        'X': [0x66, 0x66, 0x3C, 0x18, 0x3C, 0x66, 0x66, 0x00],
        'Y': [0x66, 0x66, 0x66, 0x3C, 0x18, 0x18, 0x18, 0x00],
        'Z': [0x7E, 0x06, 0x0C, 0x18, 0x30, 0x60, 0x7E, 0x00],
        '0': [0x3C, 0x66, 0x6E, 0x76, 0x66, 0x66, 0x3C, 0x00],
        '1': [0x18, 0x38, 0x18, 0x18, 0x18, 0x18, 0x7E, 0x00],
        '2': [0x3C, 0x66, 0x06, 0x1C, 0x30, 0x60, 0x7E, 0x00],
        '3': [0x3C, 0x66, 0x06, 0x1C, 0x06, 0x66, 0x3C, 0x00],
        '4': [0x0C, 0x1C, 0x2C, 0x4C, 0x7E, 0x0C, 0x0C, 0x00],
        '5': [0x7E, 0x60, 0x7C, 0x06, 0x06, 0x66, 0x3C, 0x00],
        '6': [0x3C, 0x66, 0x60, 0x7C, 0x66, 0x66, 0x3C, 0x00],
        '7': [0x7E, 0x06, 0x0C, 0x18, 0x30, 0x30, 0x30, 0x00],
        '8': [0x3C, 0x66, 0x66, 0x3C, 0x66, 0x66, 0x3C, 0x00],
        '9': [0x3C, 0x66, 0x66, 0x3E, 0x06, 0x66, 0x3C, 0x00],
        ':': [0x00, 0x18, 0x18, 0x00, 0x18, 0x18, 0x00, 0x00],
        '!': [0x18, 0x18, 0x18, 0x18, 0x18, 0x00, 0x18, 0x00],
        '-': [0x00, 0x00, 0x00, 0x7E, 0x00, 0x00, 0x00, 0x00],
        '.': [0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x00],
        ' ': [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
    }

def save_bmp(img, filepath):
    """Save image as BMP file."""
    height = len(img)
    width = len(img[0])

    # BMP row padding (rows must be multiple of 4 bytes)
    row_size = width * 3
    padding = (4 - (row_size % 4)) % 4
    padded_row_size = row_size + padding

    # File size
    pixel_data_size = padded_row_size * height
    file_size = 54 + pixel_data_size

    with open(filepath, 'wb') as f:
        # BMP Header (14 bytes)
        f.write(b'BM')
        f.write(struct.pack('<I', file_size))
        f.write(struct.pack('<HH', 0, 0))
        f.write(struct.pack('<I', 54))

        # DIB Header (40 bytes - BITMAPINFOHEADER)
        f.write(struct.pack('<I', 40))
        f.write(struct.pack('<i', width))
        f.write(struct.pack('<i', height))
        f.write(struct.pack('<HH', 1, 24))
        f.write(struct.pack('<I', 0))  # No compression
        f.write(struct.pack('<I', pixel_data_size))
        f.write(struct.pack('<i', 2835))  # 72 DPI
        f.write(struct.pack('<i', 2835))
        f.write(struct.pack('<I', 0))
        f.write(struct.pack('<I', 0))

        # Pixel data (bottom-up)
        for y in range(height - 1, -1, -1):
            for x in range(width):
                r, g, b = img[y][x]
                f.write(struct.pack('BBB', b, g, r))  # BGR format
            f.write(b'\x00' * padding)

def save_jpg(img, filepath, quality=90):
    """Save as BMP (JPG requires external lib). We'll save as BMP and note it."""
    # Save as BMP - the file extension will be .jpg but content is BMP
    # For true JPEG we'd need PIL. Let's try PIL first, fallback to BMP.
    try:
        from PIL import Image
        pil_img = Image.new('RGB', (len(img[0]), len(img)))
        for y in range(len(img)):
            for x in range(len(img[0])):
                pil_img.putpixel((x, y), img[y][x])
        pil_img.save(filepath, 'JPEG', quality=quality)
        return True
    except ImportError:
        # Fallback: save as BMP with .bmp extension
        bmp_path = filepath.replace('.jpg', '.bmp')
        save_bmp(img, bmp_path)
        print(f"  (Saved as BMP - install Pillow for JPEG: pip install Pillow)")
        return False


# ============================================================================
# Maze drawing helpers
# ============================================================================

# Simple level 1 maze pattern (28x25)
# 0=empty, 1=wall, 2=dot, 3=power, 4=gate
LEVEL1_MAZE = [
    [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
    [1,2,2,2,2,2,2,2,2,2,2,2,2,1,1,2,2,2,2,2,2,2,2,2,2,2,2,1],
    [1,2,1,1,1,1,2,1,1,1,1,1,2,1,1,2,1,1,1,1,1,2,1,1,1,1,2,1],
    [1,3,1,1,1,1,2,1,1,1,1,1,2,1,1,2,1,1,1,1,1,2,1,1,1,1,3,1],
    [1,2,1,1,1,1,2,1,1,1,1,1,2,1,1,2,1,1,1,1,1,2,1,1,1,1,2,1],
    [1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1],
    [1,2,1,1,1,1,2,1,1,2,1,1,1,1,1,1,1,1,2,1,1,2,1,1,1,1,2,1],
    [1,2,1,1,1,1,2,1,1,2,1,1,1,1,1,1,1,1,2,1,1,2,1,1,1,1,2,1],
    [1,2,2,2,2,2,2,1,1,2,2,2,2,1,1,2,2,2,2,1,1,2,2,2,2,2,2,1],
    [1,1,1,1,1,1,2,1,1,1,1,1,0,1,1,0,1,1,1,1,1,2,1,1,1,1,1,1],
    [0,0,0,0,0,1,2,1,1,0,0,0,0,4,4,0,0,0,0,1,1,2,1,0,0,0,0,0],
    [0,0,0,0,0,1,2,1,1,0,1,1,1,0,0,1,1,1,0,1,1,2,1,0,0,0,0,0],
    [1,1,1,1,1,1,2,0,0,0,1,0,0,0,0,0,0,1,0,0,0,2,1,1,1,1,1,1],
    [0,0,0,0,0,0,2,1,1,0,1,0,0,0,0,0,0,1,0,1,1,2,0,0,0,0,0,0],
    [1,1,1,1,1,1,2,1,1,0,1,1,1,1,1,1,1,1,0,1,1,2,1,1,1,1,1,1],
    [0,0,0,0,0,1,2,1,1,0,0,0,0,0,0,0,0,0,0,1,1,2,1,0,0,0,0,0],
    [0,0,0,0,0,1,2,1,1,0,1,1,1,1,1,1,1,1,0,1,1,2,1,0,0,0,0,0],
    [1,1,1,1,1,1,2,1,1,2,1,1,1,1,1,1,1,1,2,1,1,2,1,1,1,1,1,1],
    [1,2,2,2,2,2,2,2,2,2,2,2,2,1,1,2,2,2,2,2,2,2,2,2,2,2,2,1],
    [1,2,1,1,1,1,2,1,1,1,1,1,2,1,1,2,1,1,1,1,1,2,1,1,1,1,2,1],
    [1,3,2,2,1,1,2,2,2,2,2,2,2,0,0,2,2,2,2,2,2,2,1,1,2,2,3,1],
    [1,1,1,2,1,1,2,1,1,2,1,1,1,1,1,1,1,1,2,1,1,2,1,1,2,1,1,1],
    [1,2,2,2,2,2,2,1,1,2,2,2,2,1,1,2,2,2,2,1,1,2,2,2,2,2,2,1],
    [1,2,1,1,1,1,1,1,1,1,1,1,2,1,1,2,1,1,1,1,1,1,1,1,1,1,2,1],
    [1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1],
]

# Wall character data (for rendering maze walls)
WALL_CHAR = [0x00, 0x00, 0xFF, 0x55, 0x55, 0xAA, 0x00, 0x00]
DOT_CHAR = [0x00, 0x00, 0x00, 0x18, 0x18, 0x00, 0x00, 0x00]
POWER_CHAR = [0x00, 0x3C, 0x7E, 0x7E, 0x7E, 0x7E, 0x3C, 0x00]
GATE_CHAR = [0x00, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00]
EMPTY_CHAR = [0x00] * 8

# Sprite data
CHOMPER_RIGHT = [
    0x05, 0x50, 0x00, 0x15, 0x54, 0x00, 0x55, 0x55, 0x00,
    0x55, 0x55, 0x00, 0x57, 0x55, 0x40, 0x57, 0x54, 0x00,
    0x55, 0x50, 0x00, 0x55, 0x40, 0x00, 0x55, 0x00, 0x00,
    0x54, 0x00, 0x00, 0x54, 0x00, 0x00, 0x55, 0x00, 0x00,
    0x55, 0x40, 0x00, 0x55, 0x50, 0x00, 0x55, 0x54, 0x00,
    0x55, 0x55, 0x00, 0x55, 0x55, 0x00, 0x15, 0x54, 0x00,
    0x05, 0x50, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
]

GHOST_SPRITE = [
    0x05, 0x50, 0x00, 0x15, 0x54, 0x00, 0x55, 0x55, 0x00,
    0x55, 0x55, 0x40, 0x55, 0x55, 0x40, 0x75, 0x5D, 0x40,
    0xF5, 0x5F, 0x40, 0xD5, 0x5D, 0x40, 0x55, 0x55, 0x40,
    0x55, 0x55, 0x40, 0x55, 0x55, 0x40, 0x55, 0x55, 0x40,
    0x55, 0x55, 0x40, 0x55, 0x55, 0x40, 0x55, 0x55, 0x40,
    0x55, 0x55, 0x40, 0x55, 0x55, 0x40, 0x51, 0x45, 0x40,
    0x40, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
]

GHOST_FRIGHTENED = [
    0x05, 0x50, 0x00, 0x15, 0x54, 0x00, 0x55, 0x55, 0x00,
    0x55, 0x55, 0x40, 0x55, 0x55, 0x40, 0x55, 0x55, 0x40,
    0x5D, 0x75, 0x40, 0x55, 0x55, 0x40, 0x55, 0x55, 0x40,
    0x55, 0x55, 0x40, 0x55, 0x55, 0x40, 0x55, 0x55, 0x40,
    0x75, 0x5D, 0x40, 0x5D, 0x75, 0x40, 0x55, 0x55, 0x40,
    0x55, 0x55, 0x40, 0x55, 0x55, 0x40, 0x51, 0x45, 0x40,
    0x40, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
]


def draw_maze(img, maze, maze_offset_x=6, wall_color=14, dot_color=1,
              power_color=1, gate_color=10, bg_color=0):
    """Draw a maze grid on the image."""
    bg = C64_COLORS[bg_color]
    for row in range(len(maze)):
        for col in range(len(maze[row])):
            tile = maze[row][col]
            sx = maze_offset_x + col
            sy = row

            if tile == 1:
                draw_char(img, sx, sy, WALL_CHAR, C64_COLORS[wall_color], bg)
            elif tile == 2:
                draw_char(img, sx, sy, DOT_CHAR, C64_COLORS[dot_color], bg)
            elif tile == 3:
                draw_char(img, sx, sy, POWER_CHAR, C64_COLORS[power_color], bg)
            elif tile == 4:
                draw_char(img, sx, sy, GATE_CHAR, C64_COLORS[gate_color], bg)
            else:
                draw_char(img, sx, sy, EMPTY_CHAR, bg, bg)


def draw_border(img, color_idx=0):
    """Fill the border area around the screen."""
    c = C64_COLORS[color_idx]
    # Top border
    fill_rect(img, 0, 0, OUT_W, BORDER * SCALE, c)
    # Bottom border
    fill_rect(img, 0, (BORDER + SCREEN_H) * SCALE, OUT_W, BORDER * SCALE, c)
    # Left border
    fill_rect(img, 0, 0, BORDER * SCALE, OUT_H, c)
    # Right border
    fill_rect(img, (BORDER + SCREEN_W) * SCALE, 0, BORDER * SCALE, OUT_H, c)


def draw_hud(img, score="001230", hi_score="010000", lives=3, level=1):
    """Draw the score, lives, and level HUD in the side columns."""
    # Score label
    draw_text(img, 0, 0, "SC", C64_COLORS[1])
    draw_text(img, 0, 1, score, C64_COLORS[7])

    # High score
    draw_text(img, 0, 3, "HI", C64_COLORS[1])
    draw_text(img, 0, 4, hi_score, C64_COLORS[3])

    # Lives
    draw_text(img, 0, 6, "L", C64_COLORS[1])
    life_icon = [0x00, 0x3C, 0x7E, 0x78, 0x70, 0x7E, 0x3C, 0x00]
    for i in range(min(lives, 5)):
        draw_char(img, 1 + i, 6, life_icon, C64_COLORS[7])

    # Level
    draw_text(img, 0, 8, "LV", C64_COLORS[1])
    draw_text(img, 2, 8, f"{level:02d}", C64_COLORS[5])


# ============================================================================
# Generate each screenshot
# ============================================================================

def generate_title_screen():
    """Generate the title screen screenshot."""
    print("Generating: Title Screen...")
    img = create_image(OUT_W, OUT_H)

    # Black background + border
    fill_rect(img, 0, 0, OUT_W, OUT_H, C64_COLORS[0])

    # "CHOMPER" title
    draw_text(img, 14, 3, "CHOMPER", C64_COLORS[7])

    # Decorative dot row
    for i in range(28):
        draw_char(img, 6 + i, 5, DOT_CHAR, C64_COLORS[1])

    # "SPECTRES" header
    draw_text(img, 15, 8, "SPECTRES", C64_COLORS[15])

    # Ghost names with colors
    ghost_icon = [0x3C, 0x7E, 0x5A, 0x7E, 0x7E, 0x7E, 0x55, 0x00]
    ghosts = [
        (10, "SHADE", 2),      # Red
        (11, "GLIMMER", 3),    # Cyan
        (12, "PHANTOM", 4),    # Purple
        (13, "EMBER", 8),      # Orange
    ]
    for row, name, color in ghosts:
        draw_char(img, 12, row, ghost_icon, C64_COLORS[color])
        draw_text(img, 14, row, name, C64_COLORS[color])

    # High score
    draw_text(img, 13, 16, "HI 010000", C64_COLORS[3])

    # "PRESS FIRE"
    draw_text(img, 14, 18, "PRESS FIRE", C64_COLORS[13])

    # Year
    draw_text(img, 17, 23, "2026", C64_COLORS[11])

    # Chomper sprite on title (approximate with char)
    chomper_icon = [0x1E, 0x7F, 0xFC, 0xF0, 0xFC, 0x7F, 0x1E, 0x00]
    draw_char(img, 12, 3, chomper_icon, C64_COLORS[7])
    draw_char(img, 22, 3, ghost_icon, C64_COLORS[2])

    save_jpg(img, os.path.join(OUTPUT_DIR, "01_title_screen.jpg"))
    print("  -> 01_title_screen.jpg")


def generate_gameplay_level1():
    """Generate gameplay screenshot for level 1."""
    print("Generating: Gameplay Level 1...")
    img = create_image(OUT_W, OUT_H)
    fill_rect(img, 0, 0, OUT_W, OUT_H, C64_COLORS[0])

    # Draw maze
    draw_maze(img, LEVEL1_MAZE)

    # Draw HUD
    draw_hud(img, "001230", "010000", 3, 1)

    # Draw player sprite (chomper) at position ~(14,20) in maze coords
    # Pixel position: (6+14)*8 = 160, 20*8 = 160
    player_x = (6 + 14) * 8
    player_y = 20 * 8
    draw_sprite(img, player_x - 8, player_y - 4, CHOMPER_RIGHT,
                C64_COLORS[7], C64_COLORS[0], C64_COLORS[1])

    # Draw ghosts at various positions
    ghost_positions = [
        ((6 + 13) * 8, 5 * 8, 2),   # Shade (red) chasing
        ((6 + 4) * 8, 8 * 8, 3),    # Glimmer (cyan) flanking
        ((6 + 13) * 8, 12 * 8, 4),  # Phantom (purple) in house
        ((6 + 15) * 8, 12 * 8, 8),  # Ember (orange) in house
    ]
    for gx, gy, gc in ghost_positions:
        draw_sprite(img, gx - 8, gy - 4, GHOST_SPRITE,
                    C64_COLORS[gc], C64_COLORS[0], C64_COLORS[1])

    save_jpg(img, os.path.join(OUTPUT_DIR, "02_gameplay_level1.jpg"))
    print("  -> 02_gameplay_level1.jpg")


def generate_power_pellet():
    """Generate screenshot showing power pellet mode."""
    print("Generating: Power Pellet Mode...")
    img = create_image(OUT_W, OUT_H)
    fill_rect(img, 0, 0, OUT_W, OUT_H, C64_COLORS[0])

    # Draw maze (with some dots eaten)
    maze = [row[:] for row in LEVEL1_MAZE]  # Copy
    # Eat some dots to show progress
    for r in range(1, 6):
        for c in range(1, 14):
            if maze[r][c] == 2:
                maze[r][c] = 0
    # Remove the top-left power pellet (just eaten)
    maze[3][1] = 0

    draw_maze(img, maze)
    draw_hud(img, "003450", "010000", 3, 1)

    # Draw player
    player_x = (6 + 4) * 8
    player_y = 5 * 8
    draw_sprite(img, player_x - 8, player_y - 4, CHOMPER_RIGHT,
                C64_COLORS[7], C64_COLORS[0], C64_COLORS[1])

    # Draw frightened ghosts (blue)
    fright_positions = [
        ((6 + 8) * 8, 5 * 8),
        ((6 + 12) * 8, 8 * 8),
        ((6 + 20) * 8, 5 * 8),
    ]
    for gx, gy in fright_positions:
        draw_sprite(img, gx - 8, gy - 4, GHOST_FRIGHTENED,
                    C64_COLORS[6], C64_COLORS[0], C64_COLORS[1])

    # One ghost still in house (not frightened)
    draw_sprite(img, (6 + 14) * 8 - 8, 12 * 8 - 4, GHOST_SPRITE,
                C64_COLORS[8], C64_COLORS[0], C64_COLORS[1])

    save_jpg(img, os.path.join(OUTPUT_DIR, "03_power_pellet.jpg"))
    print("  -> 03_power_pellet.jpg")


def generate_level10():
    """Generate screenshot for a mid-game level (level 10)."""
    print("Generating: Level 10 Gameplay...")
    img = create_image(OUT_W, OUT_H)
    fill_rect(img, 0, 0, OUT_W, OUT_H, C64_COLORS[0])

    # Modified maze for level 10 (more complex)
    maze10 = [
        [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
        [1,2,2,2,2,2,1,2,2,2,2,2,2,1,1,2,2,2,2,2,2,1,2,2,2,2,2,1],
        [1,2,1,1,1,2,1,2,1,1,1,1,2,1,1,2,1,1,1,1,2,1,2,1,1,1,2,1],
        [1,3,1,1,1,2,2,2,2,2,1,1,2,1,1,2,1,1,2,2,2,2,2,1,1,1,3,1],
        [1,2,1,1,1,2,1,1,1,2,1,1,2,1,1,2,1,1,2,1,1,1,2,1,1,1,2,1],
        [1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1],
        [1,2,1,1,2,1,1,2,1,1,2,1,1,1,1,1,1,2,1,1,2,1,1,2,1,1,2,1],
        [1,2,1,1,2,1,1,2,1,1,2,2,2,2,2,2,2,2,1,1,2,1,1,2,1,1,2,1],
        [1,2,2,2,2,2,2,2,1,1,1,1,2,1,1,2,1,1,1,1,2,2,2,2,2,2,2,1],
        [1,1,1,1,2,1,1,2,1,1,1,1,2,1,1,2,1,1,1,1,2,1,1,2,1,1,1,1],
        [0,0,0,1,2,1,1,2,2,2,0,0,0,4,4,0,0,0,2,2,1,1,2,1,0,0,0,0],
        [1,1,1,1,2,1,1,1,1,0,1,1,1,0,0,1,1,1,0,1,1,1,1,2,1,1,1,1],
        [0,0,0,0,2,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,2,0,0,0,0],
        [1,1,1,1,2,1,1,1,1,0,1,0,0,0,0,0,0,1,0,1,1,1,1,2,1,1,1,1],
        [0,0,0,1,2,1,1,0,0,0,1,1,1,1,1,1,1,1,0,0,0,1,1,2,1,0,0,0],
        [1,1,1,1,2,1,1,2,1,0,0,0,0,0,0,0,0,0,0,1,2,1,1,2,1,1,1,1],
        [1,2,2,2,2,2,2,2,1,2,1,1,1,1,1,1,1,1,2,1,2,2,2,2,2,2,2,1],
        [1,2,1,1,1,1,2,1,1,2,2,2,2,1,1,2,2,2,2,1,1,2,1,1,1,1,2,1],
        [1,2,2,2,2,2,2,2,2,2,1,1,2,1,1,2,1,1,2,2,2,2,2,2,2,2,2,1],
        [1,1,1,2,1,1,2,1,1,2,1,1,2,2,2,2,1,1,2,1,1,2,1,1,2,1,1,1],
        [1,3,2,2,1,1,2,1,1,2,2,2,2,1,1,2,2,2,2,1,1,2,1,1,2,2,3,1],
        [1,2,1,2,1,1,2,1,1,1,1,1,2,1,1,2,1,1,1,1,1,2,1,1,2,1,2,1],
        [1,2,1,2,2,2,2,2,2,2,2,2,2,1,1,2,2,2,2,2,2,2,2,2,2,1,2,1],
        [1,2,1,1,1,1,1,1,1,1,1,1,2,1,1,2,1,1,1,1,1,1,1,1,1,1,2,1],
        [1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1],
    ]

    draw_maze(img, maze10, wall_color=14)
    draw_hud(img, "025670", "025670", 2, 10)

    # Player at different position
    player_x = (6 + 20) * 8
    player_y = 18 * 8
    draw_sprite(img, player_x - 8, player_y - 4, CHOMPER_RIGHT,
                C64_COLORS[7], C64_COLORS[0], C64_COLORS[1])

    # Ghosts in chase formation
    ghost_data = [
        ((6 + 18) * 8, 18 * 8, 2),  # Shade close behind
        ((6 + 22) * 8, 16 * 8, 3),  # Glimmer ahead
        ((6 + 10) * 8, 18 * 8, 4),  # Phantom
        ((6 + 14) * 8, 20 * 8, 8),  # Ember
    ]
    for gx, gy, gc in ghost_data:
        draw_sprite(img, gx - 8, gy - 4, GHOST_SPRITE,
                    C64_COLORS[gc], C64_COLORS[0], C64_COLORS[1])

    save_jpg(img, os.path.join(OUTPUT_DIR, "04_level_10.jpg"))
    print("  -> 04_level_10.jpg")


def generate_game_over():
    """Generate game over screenshot."""
    print("Generating: Game Over...")
    img = create_image(OUT_W, OUT_H)
    fill_rect(img, 0, 0, OUT_W, OUT_H, C64_COLORS[0])

    # Draw a partially-played maze
    maze = [row[:] for row in LEVEL1_MAZE]
    # Eat most dots
    for r in range(len(maze)):
        for c in range(len(maze[r])):
            if maze[r][c] == 2 and (r + c) % 3 != 0:
                maze[r][c] = 0
    draw_maze(img, maze)

    # "GAME OVER" text overlaid on maze
    draw_text(img, 14, 12, "GAME OVER", C64_COLORS[2])

    # Score display
    draw_hud(img, "045230", "045230", 0, 5)

    save_jpg(img, os.path.join(OUTPUT_DIR, "05_game_over.jpg"))
    print("  -> 05_game_over.jpg")


def generate_level25():
    """Generate screenshot for a late-game complex level."""
    print("Generating: Level 25 Gameplay...")
    img = create_image(OUT_W, OUT_H)
    fill_rect(img, 0, 0, OUT_W, OUT_H, C64_COLORS[0])

    # Complex maze for level 25
    maze25 = [
        [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
        [1,2,2,2,1,2,2,2,2,2,1,2,2,1,1,2,2,1,2,2,2,2,2,1,2,2,2,1],
        [1,2,1,2,1,2,1,1,1,2,1,2,1,1,1,1,2,1,2,1,1,1,2,1,2,1,2,1],
        [1,3,1,2,2,2,2,2,1,2,2,2,2,2,2,2,2,2,1,2,2,2,2,2,1,2,3,1],
        [1,2,1,1,1,1,1,2,1,1,1,2,1,1,1,1,2,1,1,1,2,1,1,1,1,1,2,1],
        [1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1],
        [1,1,1,2,1,2,1,1,2,1,2,1,1,1,1,1,1,2,1,2,1,1,2,1,2,1,1,1],
        [1,2,2,2,1,2,1,1,2,1,2,2,2,2,2,2,2,2,1,2,1,1,2,1,2,2,2,1],
        [1,2,1,1,1,2,2,2,2,1,1,1,2,1,1,2,1,1,1,2,2,2,2,1,1,1,2,1],
        [1,2,2,2,2,2,1,1,2,2,2,2,2,1,1,2,2,2,2,1,1,2,2,2,2,2,2,1],
        [0,0,1,1,1,2,1,1,1,1,0,0,0,4,4,0,0,0,1,1,1,1,2,1,1,1,0,0],
        [1,1,1,2,2,2,1,0,0,0,1,1,1,0,0,1,1,1,0,0,0,1,2,2,2,1,1,1],
        [0,0,0,2,1,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,1,2,0,0,0],
        [1,1,1,2,1,1,1,0,0,0,1,0,0,0,0,0,0,1,0,0,0,1,1,1,2,1,1,1],
        [0,0,1,2,1,2,1,0,0,0,1,1,1,1,1,1,1,1,0,0,0,1,2,1,2,1,0,0],
        [1,1,1,2,2,2,1,1,2,0,0,0,0,0,0,0,0,0,0,2,1,1,2,2,2,1,1,1],
        [1,2,2,2,1,2,2,2,2,1,1,1,2,1,1,2,1,1,1,2,2,2,2,1,2,2,2,1],
        [1,2,1,1,1,2,1,1,2,2,2,2,2,1,1,2,2,2,2,2,1,1,2,1,1,1,2,1],
        [1,2,2,2,2,2,1,1,1,1,1,2,1,1,1,1,2,1,1,1,1,1,2,2,2,2,2,1],
        [1,1,1,2,1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,2,1,1,1],
        [1,3,2,2,1,2,1,1,2,1,1,2,1,0,0,1,2,1,1,2,1,1,2,1,2,2,3,1],
        [1,2,1,1,1,2,1,1,2,1,1,2,1,1,1,1,2,1,1,2,1,1,2,1,1,1,2,1],
        [1,2,2,2,2,2,2,2,2,2,2,2,2,1,1,2,2,2,2,2,2,2,2,2,2,2,2,1],
        [1,2,1,1,1,1,1,2,1,1,1,1,2,1,1,2,1,1,1,1,2,1,1,1,1,1,2,1],
        [1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1],
    ]

    draw_maze(img, maze25, wall_color=4)  # Purple walls for variety
    draw_hud(img, "089320", "089320", 1, 25)

    # Player in tight spot
    player_x = (6 + 5) * 8
    player_y = 5 * 8
    draw_sprite(img, player_x - 8, player_y - 4, CHOMPER_RIGHT,
                C64_COLORS[7], C64_COLORS[0], C64_COLORS[1])

    # Ghosts closing in
    ghost_data = [
        ((6 + 5) * 8, 7 * 8, 2),    # Shade below
        ((6 + 8) * 8, 5 * 8, 3),    # Glimmer to right
        ((6 + 3) * 8, 3 * 8, 4),    # Phantom above
        ((6 + 2) * 8, 5 * 8, 8),    # Ember to left
    ]
    for gx, gy, gc in ghost_data:
        draw_sprite(img, gx - 8, gy - 4, GHOST_SPRITE,
                    C64_COLORS[gc], C64_COLORS[0], C64_COLORS[1])

    save_jpg(img, os.path.join(OUTPUT_DIR, "06_level_25.jpg"))
    print("  -> 06_level_25.jpg")


# ============================================================================
# Main
# ============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("CHOMPER - C64 Screen Mockup Generator")
    print("=" * 60)
    print()

    generate_title_screen()
    generate_gameplay_level1()
    generate_power_pellet()
    generate_level10()
    generate_game_over()
    generate_level25()

    print()
    print(f"All screenshots saved to: {OUTPUT_DIR}/")
    print("Done!")
