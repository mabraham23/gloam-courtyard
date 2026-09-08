"""Report temporal gait relationships in an extracted CMU run trace."""

import json
import math
import sys
from pathlib import Path


trace = json.loads(Path(sys.argv[1]).read_text())
rows = trace["frames"][1:]  # Added T-pose is frame one, not captured motion.
fps = float(trace["fps"])


def point(row, bone):
    return row["bones"][bone]["head"]


def dist(a, b):
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def speed(index, bone):
    if index == 0:
        return 0.0
    return dist(point(rows[index], bone), point(rows[index - 1], bone)) * fps


for axis, name in enumerate("xyz"):
    values = [point(row, "Hips")[axis] for row in rows]
    print(f"hips_{name}_range={min(values):.5f}..{max(values):.5f}")

for side in ("Left", "Right"):
    for bone in (f"{side}Foot", f"{side}ToeBase"):
        ys = [point(row, bone)[2] for row in rows]
        speeds = [speed(i, bone) for i in range(len(rows))]
        print(
            f"{bone} y={min(ys):.5f}..{max(ys):.5f} "
            f"speed={min(speeds[1:]):.3f}..{max(speeds):.3f}"
        )

# A contact candidate must be near that foot's low percentile and moving slowly.
contacts = {}
for side in ("Left", "Right"):
    bone = f"{side}ToeBase"
    ys = sorted(point(row, bone)[2] for row in rows)
    floor = ys[max(0, int(len(ys) * 0.08) - 1)]
    mask = [point(row, bone)[2] <= floor + 0.018 and speed(i, bone) <= 1.2 for i, row in enumerate(rows)]
    spans = []
    start = None
    for i, active in enumerate(mask + [False]):
        if active and start is None:
            start = i
        elif not active and start is not None:
            if i - start >= 3:
                spans.append((rows[start]["frame"], rows[i - 1]["frame"]))
            start = None
    contacts[side] = spans
    print(f"{side.lower()}_contact_candidates={spans}")

# Print a compact temporal trace for visual correlation and cycle selection.
print("frame,time,hips_y,left_foot_y,right_foot_y,left_toe_speed,right_toe_speed")
for i in range(0, len(rows), 6):
    row = rows[i]
    print(
        f"{row['frame']},{row['time']:.4f},{point(row,'Hips')[2]:.5f},"
        f"{point(row,'LeftFoot')[2]:.5f},{point(row,'RightFoot')[2]:.5f},"
        f"{speed(i,'LeftToeBase'):.3f},{speed(i,'RightToeBase'):.3f}"
    )
