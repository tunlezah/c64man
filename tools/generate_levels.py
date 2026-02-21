#!/usr/bin/env python3
"""
CHOMPER - Level Data Generator
================================
Generates 30 unique maze levels as KickAssembler source code.
Each level is a 28x25 grid with progressive difficulty.

Tile values: 0=empty, 1=wall, 2=dot, 3=power_pellet, 4=gate, 5=tunnel, 6=bonus_spawn
"""

import random

W, H = 28, 25  # Maze dimensions

# Tile constants
EMPTY = 0
WALL = 1
DOT = 2
POWER = 3
GATE = 4
TUNNEL = 5
BONUS = 6

def make_base_maze():
    """Create a base maze with outer walls and ghost house."""
    m = [[WALL]*W for _ in range(H)]
    # Fill interior with dots initially
    for y in range(1, H-1):
        for x in range(1, W-1):
            m[y][x] = DOT
    return m

def add_ghost_house(m):
    """Add the ghost house in the center (rows 10-14, cols 10-17)."""
    # Clear area around ghost house
    for y in range(9, 16):
        for x in range(9, 19):
            m[y][x] = EMPTY

    # Ghost house walls
    for x in range(10, 18):
        m[10][x] = WALL  # Top wall
        m[14][x] = WALL  # Bottom wall
    for y in range(10, 15):
        m[y][10] = WALL   # Left wall
        m[y][17] = WALL   # Right wall

    # Gate at top center
    m[10][13] = GATE
    m[10][14] = GATE

    # Interior is empty
    for y in range(11, 14):
        for x in range(11, 17):
            m[y][x] = EMPTY

    # Space above gate
    m[9][13] = EMPTY
    m[9][14] = EMPTY

def add_tunnels(m, rows):
    """Add tunnel wraps on specified rows."""
    for r in rows:
        if 0 < r < H-1:
            m[r][0] = TUNNEL
            m[r][W-1] = TUNNEL
            # Clear a path from tunnel inward
            for x in range(1, 5):
                if m[r][x] == WALL:
                    m[r][x] = DOT
            for x in range(W-5, W-1):
                if m[r][x] == WALL:
                    m[r][x] = DOT

def add_power_pellets(m, positions=None):
    """Place 4 power pellets near the corners."""
    if positions is None:
        positions = [(1, 3), (26, 3), (1, 21), (26, 21)]
    for x, y in positions:
        if 0 <= x < W and 0 <= y < H:
            m[y][x] = POWER

def add_bonus_spot(m, x=14, y=17):
    """Add bonus spawn point below ghost house."""
    m[y][x] = BONUS

def carve_corridors(m, wall_density=0.3, seed=None):
    """Carve maze corridors with adjustable wall density."""
    if seed is not None:
        random.seed(seed)

    # Create horizontal corridors
    corridor_rows = [1, 5, 8, 9, 15, 16, 17, 18, 20, 22, 23]
    for r in corridor_rows:
        if 0 < r < H-1:
            for x in range(1, W-1):
                m[r][x] = DOT

    # Create vertical corridors
    corridor_cols = [1, 6, 9, 12, 13, 14, 15, 18, 21, 26]
    for c in corridor_cols:
        if 0 < c < W-1:
            for y in range(1, H-1):
                if m[y][c] != GATE and m[y][c] != TUNNEL:
                    m[y][c] = DOT

    # Add wall blocks based on density
    block_patterns = [
        # (x, y, w, h) - wall block definitions
        (2, 2, 4, 3),
        (7, 2, 5, 3),
        (16, 2, 5, 3),
        (22, 2, 4, 3),
        (2, 6, 4, 2),
        (7, 6, 2, 2),
        (19, 6, 2, 2),
        (22, 6, 4, 2),
        (2, 19, 4, 2),
        (7, 19, 5, 2),
        (16, 19, 5, 2),
        (22, 19, 4, 2),
        (10, 16, 3, 1),
        (15, 16, 3, 1),
    ]

    for bx, by, bw, bh in block_patterns:
        if random.random() < (1.0 - wall_density * 0.3):
            for dy in range(bh):
                for dx in range(bw):
                    nx, ny = bx + dx, by + dy
                    if 1 <= nx < W-1 and 1 <= ny < H-1:
                        if m[ny][nx] == DOT:
                            m[ny][nx] = WALL

def ensure_connectivity(m):
    """Make sure all dot tiles are reachable from player start."""
    # Simple: ensure key paths are clear
    # Player starts at (14, 23)
    # Ensure path from (14,23) to all four quadrants

    # Clear the center column
    for y in range(1, H-1):
        if m[y][13] not in (WALL, GATE) and m[y][14] not in (WALL, GATE):
            continue
        if y < 10 or y > 14:  # Don't clear through ghost house
            if m[y][13] == WALL:
                m[y][13] = DOT
            if m[y][14] == WALL:
                m[y][14] = DOT

    # Ensure horizontal paths at key rows
    for x in range(1, W-1):
        if m[5][x] == WALL and m[5][x-1] == DOT and m[5][x+1] == DOT:
            if random.random() < 0.5:
                m[5][x] = DOT
        if m[18][x] == WALL and x != 0 and x != W-1:
            if m[18][x-1] in (DOT, POWER, EMPTY) and m[18][x+1] in (DOT, POWER, EMPTY):
                if random.random() < 0.3:
                    m[18][x] = DOT

def generate_level(level_num):
    """Generate a complete level maze."""
    m = make_base_maze()

    # Determine difficulty parameters
    if level_num <= 5:
        wall_density = 0.25 + (level_num - 1) * 0.02
        extra_walls = 0
    elif level_num <= 10:
        wall_density = 0.35 + (level_num - 6) * 0.02
        extra_walls = 2
    elif level_num <= 15:
        wall_density = 0.45 + (level_num - 11) * 0.02
        extra_walls = 4
    elif level_num <= 20:
        wall_density = 0.55 + (level_num - 16) * 0.01
        extra_walls = 6
    elif level_num <= 25:
        wall_density = 0.60 + (level_num - 21) * 0.01
        extra_walls = 8
    else:
        wall_density = 0.65 + (level_num - 26) * 0.01
        extra_walls = 10

    seed = level_num * 31337 + 42
    random.seed(seed)

    # Different corridor structures per level group
    if level_num <= 5:
        # Classic Pac-Man style: lots of corridors
        corridor_rows = [1, 2, 5, 8, 9, 15, 16, 18, 20, 22, 23]
        corridor_cols = [1, 6, 9, 12, 13, 14, 15, 18, 21, 26]
    elif level_num <= 10:
        corridor_rows = [1, 5, 8, 9, 15, 17, 18, 20, 23]
        corridor_cols = [1, 5, 9, 13, 14, 18, 22, 26]
    elif level_num <= 15:
        corridor_rows = [1, 5, 8, 9, 15, 17, 20, 23]
        corridor_cols = [1, 6, 10, 13, 14, 17, 21, 26]
    elif level_num <= 20:
        corridor_rows = [1, 4, 8, 9, 15, 17, 21, 23]
        corridor_cols = [1, 7, 11, 13, 14, 16, 20, 26]
    elif level_num <= 25:
        corridor_rows = [1, 5, 9, 15, 18, 23]
        corridor_cols = [1, 8, 13, 14, 19, 26]
    else:
        corridor_rows = [1, 5, 9, 15, 20, 23]
        corridor_cols = [1, 9, 13, 14, 18, 26]

    # Carve horizontal corridors
    for r in corridor_rows:
        if 0 < r < H-1:
            for x in range(1, W-1):
                m[r][x] = DOT

    # Carve vertical corridors
    for c in corridor_cols:
        if 0 < c < W-1:
            for y in range(1, H-1):
                m[y][c] = DOT

    # Add wall blocks (level-specific patterns)
    wall_blocks = []

    # Standard wall blocks (adapted per level)
    base_blocks = [
        (2, 2, 4, 2), (8, 2, 4, 2), (16, 2, 4, 2), (22, 2, 4, 2),
        (2, 6, 3, 2), (7, 6, 2, 3), (19, 6, 2, 3), (23, 6, 3, 2),
        (10, 6, 3, 2), (15, 6, 3, 2),
        (2, 19, 3, 2), (7, 19, 4, 2), (17, 19, 4, 2), (23, 19, 3, 2),
        (10, 16, 3, 1), (15, 16, 3, 1),
        (2, 21, 4, 2), (8, 21, 4, 1), (16, 21, 4, 1), (22, 21, 4, 2),
    ]

    # Add variation per level
    random.seed(seed + 100)
    for bx, by, bw, bh in base_blocks:
        # Shift blocks slightly per level
        shift_x = random.randint(-1, 1)
        shift_y = random.randint(0, 1)
        nbx = max(1, min(W-bw-1, bx + shift_x))
        nby = max(1, min(H-bh-1, by + shift_y))

        if random.random() < (0.6 + wall_density * 0.3):
            for dy in range(bh):
                for dx in range(bw):
                    nx, ny = nbx + dx, nby + dy
                    if 1 <= nx < W-1 and 1 <= ny < H-1:
                        if m[ny][nx] == DOT:
                            m[ny][nx] = WALL

    # Add extra difficulty walls
    for _ in range(extra_walls):
        bx = random.randint(2, W-5)
        by = random.randint(2, H-5)
        bw = random.randint(1, 3)
        bh = random.randint(1, 2)
        for dy in range(bh):
            for dx in range(bw):
                nx, ny = bx + dx, by + dy
                if 1 <= nx < W-1 and 1 <= ny < H-1:
                    if m[ny][nx] == DOT:
                        m[ny][nx] = WALL

    # Add ghost house (overwrites whatever was there)
    add_ghost_house(m)

    # Add tunnels
    tunnel_row = 12 + (level_num % 3) - 1  # Vary tunnel row slightly
    if tunnel_row < 10 or tunnel_row > 14:
        add_tunnels(m, [tunnel_row])
    else:
        add_tunnels(m, [12])

    # Add power pellets
    # Vary positions slightly per level
    pp_positions = [
        (1, 3 + level_num % 3),
        (26, 3 + (level_num + 1) % 3),
        (1, 20 + level_num % 3),
        (26, 20 + (level_num + 2) % 3),
    ]
    add_power_pellets(m, pp_positions)

    # Add bonus spot
    add_bonus_spot(m, 14, 17)

    # Ensure player start area is clear
    m[23][13] = DOT
    m[23][14] = DOT
    m[22][13] = DOT
    m[22][14] = DOT

    # Ensure connectivity
    ensure_connectivity(m)

    # Make sure the area around ghost house is navigable
    for y in [9, 15]:
        for x in range(9, 19):
            if m[y][x] == WALL:
                m[y][x] = EMPTY
    for x in [9, 18]:
        for y in range(10, 15):
            if m[y][x] == WALL:
                m[y][x] = EMPTY

    # Convert remaining EMPTY tiles near dot areas to DOT for score
    for y in range(1, H-1):
        for x in range(1, W-1):
            if m[y][x] == EMPTY:
                # Check if this is in the ghost house area
                if 10 <= y <= 14 and 10 <= x <= 17:
                    continue
                if 9 <= y <= 15 and 9 <= x <= 18:
                    continue
                # Check if adjacent to dots - if so, make it a dot too
                has_dot_neighbor = False
                for dx, dy in [(-1,0),(1,0),(0,-1),(0,1)]:
                    nx, ny = x+dx, y+dy
                    if 0 <= nx < W and 0 <= ny < H and m[ny][nx] in (DOT, POWER):
                        has_dot_neighbor = True
                        break
                if has_dot_neighbor:
                    m[y][x] = DOT

    # Count dots
    dot_count = sum(1 for y in range(H) for x in range(W) if m[y][x] in (DOT, POWER))

    return m, dot_count


def maze_to_asm(m, level_num, dot_count):
    """Convert a maze array to KickAssembler .byte directives."""
    lines = []
    lines.append(f"// Level {level_num} ({dot_count} dots)")
    lines.append(f"Level{level_num}Data:")
    for y in range(H):
        row_str = ", ".join(str(m[y][x]) for x in range(W))
        lines.append(f"    .byte {row_str}  // Row {y}")
    lines.append("")
    return "\n".join(lines)


def main():
    output_lines = []

    output_lines.append("// ============================================================================")
    output_lines.append("// CHOMPER - Level Data (30 Levels)")
    output_lines.append("// ============================================================================")
    output_lines.append("// Auto-generated by tools/generate_levels.py")
    output_lines.append("// Each level: 28 columns x 25 rows = 700 bytes")
    output_lines.append("// Tile values: 0=empty, 1=wall, 2=dot, 3=power, 4=gate, 5=tunnel, 6=bonus")
    output_lines.append("// ============================================================================")
    output_lines.append("")

    # Generate pointer table
    output_lines.append("// Level pointer table (30 entries, lo/hi byte pairs)")
    output_lines.append("LevelPointerTable:")
    for i in range(1, 31):
        output_lines.append(f"    .byte <Level{i}Data, >Level{i}Data")
    output_lines.append("")

    # Generate all 30 levels
    for level_num in range(1, 31):
        m, dot_count = generate_level(level_num)
        asm = maze_to_asm(m, level_num, dot_count)
        output_lines.append(asm)

    # Write the complete file
    content = "\n".join(output_lines)
    with open("/home/user/c64man/src/data/levels.asm", "w") as f:
        f.write(content)

    print(f"Generated 30 levels to src/data/levels.asm")
    print(f"File size: {len(content)} bytes")

    # Print dot counts per level
    for level_num in range(1, 31):
        m, dot_count = generate_level(level_num)
        print(f"  Level {level_num:2d}: {dot_count} dots")


if __name__ == "__main__":
    main()
