#!/usr/bin/env python3

modules = 177
qr = [[0 for x in range(modules)] for y in range(modules)]


def set_area(x, y, w, h, value):
    for i in range(w):
        for j in range(h):
            if x + i < 0 or x + i >= modules or y + j < 0 or y + j >= modules:
                continue
            qr[y + j][x + i] = value


def draw_finder(x, y):
    set_area(x - 1, y - 1, 9, 9, 0x80)
    set_area(x, y, 7, 7, 0x81)
    set_area(x + 1, y + 1, 5, 5, 0x80)
    set_area(x + 2, y + 2, 3, 3, 0x81)


def draw_alignment(x, y):
    set_area(x, y, 5, 5, 0x81)
    set_area(x + 1, y + 1, 3, 3, 0x80)
    qr[y + 2][x + 2] = 0x81


for x in range(modules):
    qr[6][x] = 0x81 if x % 2 == 0 else 0x80
for y in range(modules):
    qr[y][6] = 0x81 if y % 2 == 0 else 0x80
draw_finder(0, 0)
draw_finder(modules - 7, 0)
draw_finder(0, modules - 7)

format_information = [0, 0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1]
# format_mask = [1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0]
# format_information = [a ^ b for a, b in zip(format_information, format_mask)]
format_information.reverse()

qr[0][8] = format_information[0] | 0x80
qr[1][8] = format_information[1] | 0x80
qr[2][8] = format_information[2] | 0x80
qr[3][8] = format_information[3] | 0x80
qr[4][8] = format_information[4] | 0x80
qr[5][8] = format_information[5] | 0x80
qr[7][8] = format_information[6] | 0x80
qr[8][8] = format_information[7] | 0x80
qr[8][7] = format_information[8] | 0x80
qr[8][5] = format_information[9] | 0x80
qr[8][4] = format_information[10] | 0x80
qr[8][3] = format_information[11] | 0x80
qr[8][2] = format_information[12] | 0x80
qr[8][1] = format_information[13] | 0x80
qr[8][0] = format_information[14] | 0x80

qr[8][modules - 1] = format_information[0] | 0x80
qr[8][modules - 2] = format_information[1] | 0x80
qr[8][modules - 3] = format_information[2] | 0x80
qr[8][modules - 4] = format_information[3] | 0x80
qr[8][modules - 5] = format_information[4] | 0x80
qr[8][modules - 6] = format_information[5] | 0x80
qr[8][modules - 7] = format_information[6] | 0x80
qr[8][modules - 8] = format_information[7] | 0x80
qr[modules - 8][8] = 0x81
qr[modules - 7][8] = format_information[8] | 0x80
qr[modules - 6][8] = format_information[9] | 0x80
qr[modules - 5][8] = format_information[10] | 0x80
qr[modules - 4][8] = format_information[11] | 0x80
qr[modules - 3][8] = format_information[12] | 0x80
qr[modules - 2][8] = format_information[13] | 0x80
qr[modules - 1][8] = format_information[14] | 0x80

version_information = [1, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 1, 0, 0, 1]
version_information.reverse()

for i in range(6):
    for j in range(3):
        qr[modules - 11 + j][i] = version_information[i * 3 + j] | 0x80
for j in range(6):
    for i in range(3):
        qr[j][modules - 11 + i] = version_information[j * 3 + i] | 0x80

alignment = [4, 28, 56, 84, 112, 140, 168]
for x in alignment:
    for y in alignment:
        # skip finder
        if (
            (x < 8 and y < 8)
            or (x > modules - 12 and y < 8)
            or (x < 8 and y > modules - 12)
        ):
            continue
        draw_alignment(x, y)


def print_qr():
    for y in range(modules):
        for x in range(modules):
            if qr[y][x] == 0:
                print(end="▒▒")
            if qr[y][x] == 0x80:
                print(end="  ")
            if qr[y][x] == 0x81:
                print(end="██")
        print()


def print_asm():
    for x in range(modules):
        print(f"    .dc.b {','.join([f'0x{qr[y][x]:02x}' for y in range(modules)])}")


print_asm()
