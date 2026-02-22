#!/usr/bin/env python3
"""Generate a horse-head level (23x26) with 50 arrows, zero conflicts, full coverage."""
import json, sys

COLS, ROWS = 23, 26

# Shape: horse head facing left
ROW_BOUNDS = {
    0:  [(7, 8)],       # 2
    1:  [(5, 9)],       # 5
    2:  [(5, 11)],      # 7
    3:  [(4, 13), (17, 20)],  # 14
    4:  [(3, 20)],      # 18
    5:  [(3, 20)],      # 18
    6:  [(2, 20)],      # 19
    7:  [(1, 20)],      # 20
    8:  [(1, 18)],      # 18
    9:  [(0, 19)],      # 20
    10: [(0, 21)],      # 22
    11: [(0, 22)],      # 23
}
for r in range(12, 26):
    ROW_BOUNDS[r] = [(0, 22)]

shape_set = set()
for row in range(ROWS):
    for lo, hi in ROW_BOUNDS[row]:
        for col in range(lo, hi + 1):
            shape_set.add((col, row))

# Expand waypoints to cells
def expand(path):
    cells = []
    for i in range(len(path) - 1):
        c1, r1 = path[i]
        c2, r2 = path[i + 1]
        if c1 == c2:
            step = 1 if r2 > r1 else -1
            for r in range(r1, r2, step):
                cells.append((c1, r))
        elif r1 == r2:
            step = 1 if c2 > c1 else -1
            for c in range(c1, c2, step):
                cells.append((c, r1))
        else:
            raise ValueError(f"Diagonal: {path[i]} -> {path[i+1]}")
    cells.append(tuple(path[-1]))
    return cells

used = set()
arrows = []
errors = []

def add(d, path, label=""):
    cells = expand(path)
    for c in cells:
        if c not in shape_set:
            errors.append(f"[{label}] {c} outside shape")
        if c in used:
            errors.append(f"[{label}] {c} conflict")
    used.update(cells)
    arrows.append({"dir": d, "path": path})

# ═══════════════════════════════════════════════════════════════
# 50 ARROWS — conflict-free, full coverage
# ═══════════════════════════════════════════════════════════════

# --- TOP EAR (rows 0-3) ---
# A1: ↑ left ear path. (5,2)->(6,2)->(7,2)->(7,1)->(7,0) = 5 cells
add("U", [[5,2],[7,2],[7,0]], "A1")
# A2: ↑ right ear path. (10,2)->(9,2)->(8,2)->(8,1)->(8,0) = 5 cells
add("U", [[10,2],[8,2],[8,0]], "A2")
# A3: ↓ (5,1) single cell
add("D", [[5,1]], "A3")
# A4: ↓ (6,1)→(6,1) single cell
add("D", [[6,1]], "A4")
# A5: ↑ (7,1) — wait, used by A1. So: (9,1) single
add("U", [[9,1]], "A5")
# A6: → (11,2) single cell
add("R", [[11,2]], "A6")
# Now row 3: (4,3)-(13,3) + (17,3)-(20,3) = 14 cells
# A7: → (4,3)→(9,3) = 6 cells
add("R", [[4,3],[9,3]], "A7")
# A8: ← (13,3)→(10,3) = 4 cells
add("L", [[13,3],[10,3]], "A8")
# A9: → (17,3)→(20,3) = 4 cells
add("R", [[17,3],[20,3]], "A9")

# --- ROWS 4-5 (18 cells each) ---
# A10: → (3,4)→(10,4) = 8
add("R", [[3,4],[10,4]], "A10")
# A11: ← (20,4)→(11,4) = 10
add("L", [[20,4],[11,4]], "A11")
# A12: → (3,5)→(10,5) = 8
add("R", [[3,5],[10,5]], "A12")
# A13: ← (20,5)→(11,5) = 10
add("L", [[20,5],[11,5]], "A13")

# --- ROWS 6-7 (19 and 20 cells) ---
# A14: → (2,6)→(10,6) = 9
add("R", [[2,6],[10,6]], "A14")
# A15: ← (20,6)→(11,6) = 10
add("L", [[20,6],[11,6]], "A15")
# A16: ← (10,7)→(1,7) = 10
add("L", [[10,7],[1,7]], "A16")
# A17: → (11,7)→(20,7) = 10
add("R", [[11,7],[20,7]], "A17")

# --- ROW 8 (cols 1-18 = 18 cells) ---
# A18: → (1,8)→(9,8) = 9
add("R", [[1,8],[9,8]], "A18")
# A19: ← (18,8)→(10,8) = 9
add("L", [[18,8],[10,8]], "A19")

# --- ROW 9 (cols 0-19 = 20 cells) ---
# A20: ↓ (0,9)→(0,10) = 2
add("D", [[0,9],[0,10]], "A20")
# A21: → (1,9)→(10,9) = 10
add("R", [[1,9],[10,9]], "A21")
# A22: ← (19,9)→(11,9) = 9
add("L", [[19,9],[11,9]], "A22")

# --- ROW 10 (cols 0-21 = 22 cells, (0,10) used by A20) ---
# A23: → (1,10)→(11,10) = 11
add("R", [[1,10],[11,10]], "A23")
# A24: ← (21,10)→(12,10) = 10
add("L", [[21,10],[12,10]], "A24")

# --- ROW 11 (cols 0-22 = 23 cells) ---
# A25: ← (11,11)→(0,11) = 12
add("L", [[11,11],[0,11]], "A25")
# A26: → (12,11)→(22,11) = 11
add("R", [[12,11],[22,11]], "A26")

# --- ROW 12 (23 cells) ---
# A27: → (0,12)→(11,12) = 12
add("R", [[0,12],[11,12]], "A27")
# A28: ← (22,12)→(12,12) = 11
add("L", [[22,12],[12,12]], "A28")

# --- ROW 13 (23 cells) ---
# A29: ← (11,13)→(0,13) = 12
add("L", [[11,13],[0,13]], "A29")
# A30: → (12,13)→(22,13) = 11
add("R", [[12,13],[22,13]], "A30")

# --- ROW 14 (23 cells) ---
# A31: → (0,14)→(11,14) = 12
add("R", [[0,14],[11,14]], "A31")
# A32: ← (22,14)→(12,14) = 11
add("L", [[22,14],[12,14]], "A32")

# --- ROW 15 (23 cells) ---
# A33: ← (22,15)→(0,15) = 23
add("L", [[22,15],[0,15]], "A33")

# --- ROW 16 (23 cells) ---
# A34: → (0,16)→(22,16) = 23
add("R", [[0,16],[22,16]], "A34")

# --- ROW 17 (23 cells) ---
# A35: ← (22,17)→(0,17) = 23
add("L", [[22,17],[0,17]], "A35")

# --- ROW 18 (23 cells) ---
# A36: → (0,18)→(22,18) = 23
add("R", [[0,18],[22,18]], "A36")

# --- ROW 19 (23 cells) ---
# A37: ← (22,19)→(0,19) = 23
add("L", [[22,19],[0,19]], "A37")

# --- ROW 20 (23 cells, split into 2 arrows) ---
# A38: → (0,20)→(11,20) = 12
add("R", [[0,20],[11,20]], "A38")
# A39: ← (22,20)→(12,20) = 11
add("L", [[22,20],[12,20]], "A39")

# --- ROW 21 (23 cells) ---
# A40: ← (11,21)→(0,21) = 12
add("L", [[11,21],[0,21]], "A40")
# A41: → (12,21)→(22,21) = 11
add("R", [[12,21],[22,21]], "A41")

# --- ROW 22 (23 cells) ---
# A42: → (0,22)→(11,22) = 12
add("R", [[0,22],[11,22]], "A42")
# A43: ← (22,22)→(12,22) = 11
add("L", [[22,22],[12,22]], "A43")

# --- ROW 23 (23 cells) ---
# A44: ← (11,23)→(0,23) = 12
add("L", [[11,23],[0,23]], "A44")
# A45: → (12,23)→(22,23) = 11
add("R", [[12,23],[22,23]], "A45")

# --- ROW 24 (23 cells) ---
# A46: → (0,24)→(11,24) = 12
add("R", [[0,24],[11,24]], "A46")
# A47: ← (22,24)→(12,24) = 11
add("L", [[22,24],[12,24]], "A47")

# --- ROW 25 (23 cells) ---
# A48: ← (11,25)→(0,25) = 12
add("L", [[11,25],[0,25]], "A48")
# A49: → (12,25)→(22,25) = 11
add("R", [[12,25],[22,25]], "A49")

# Count check
assert len(arrows) == 49, f"Got {len(arrows)} arrows, need 50"
# We have 49, need one more. Let me check remaining...

# Actually I need 50. Let me check: (0,10) used by A20, remaining row 3 cells...
# Hmm let me count. Actually A20 uses (0,9) and (0,10). Row 10 remaining from A23: (1-11), A24: (12-21). That's 11+10=21 + A20's (0,10) = 22 cells. Row 10 has 22 cells (0-21). Good.
# But we need 50 arrows and only have 49. Split one of the long arrows.

# Remove A33 (full row 15, 23 cells) and replace with 2 arrows
arrows.pop(32)  # A33 was index 32
used -= set(expand([[22,15],[0,15]]))

# A33a: ← (22,15)→(12,15) = 11
add("L", [[22,15],[12,15]], "A33a")
# A33b: ← (11,15)→(0,15) = 12
add("L", [[11,15],[0,15]], "A33b")

# ═══════════════════════════════════════════════════════════════
print(f"Shape cells: {len(shape_set)}", file=sys.stderr)
print(f"Arrow count: {len(arrows)}", file=sys.stderr)
print(f"Cells used: {len(used)}", file=sys.stderr)
unused = shape_set - used
outside = used - shape_set
print(f"Unused: {len(unused)}", file=sys.stderr)
if unused:
    for c in sorted(unused)[:10]:
        print(f"  {c}", file=sys.stderr)
print(f"Outside: {len(outside)}", file=sys.stderr)
if errors:
    print("ERRORS:", file=sys.stderr)
    for e in errors:
        print(e, file=sys.stderr)

shape_list = sorted(shape_set, key=lambda c: (c[1], c[0]))
level = {
    "name": "Horse Head",
    "columns": COLS,
    "rows": ROWS,
    "shape": [list(c) for c in shape_list],
    "arrows": arrows,
}
print(json.dumps(level))
