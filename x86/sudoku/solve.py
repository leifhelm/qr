#!/usr/bin/env python3
import sys
from lxml import etree
import subprocess
import time

files = sys.argv[1:]

for filename in files:
    with open(filename) as f:
        sudokus = list(f)
    for sudoku in sudokus:
        sudoku = sudoku.strip()
        res = subprocess.run(
            ["qqwing", "--solve", "--one-line"],
            input=sudoku.encode(),
            capture_output=True,
        )
        solution = res.stdout.decode().strip()
        prev_x = 0
        prev_y = 0
        for y in range(9):
            for x in range(9):
                if sudoku[x + 9 * y] == ".":
                    if prev_x - x > 0:
                        print(end="h" * (prev_x - x))
                    elif prev_x - x < 0:
                        print(end="l" * (x - prev_x))
                    if y > prev_y:
                        print(end="j" * (y - prev_y))
                    prev_x = x
                    prev_y = y
                    print(end=solution[x + 9 * y], flush=True)
        time.sleep(1)
        print()
# time.sleep(10000)
