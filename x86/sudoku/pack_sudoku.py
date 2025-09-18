#!/usr/bin/env python3
import sys

output_file = sys.argv[1]
files = sys.argv[2:]

with open(output_file, "w") as f:
    for filename in files:
        with open(filename) as sudokus:
            for sudoku in sudokus:
                sudoku = sudoku.strip()
                for cell in sudoku:
                    digit = "0" if cell == "." else cell
                    f.write(f"    db {digit}\n")
