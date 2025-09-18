bits 32
section .text progbits

F_SETFL equ 4
O_NONBLOCK equ 04000

;;; syscall.h
SYS_exit        equ 1
SYS_read        equ 3
SYS_write       equ 4
SYS_ioctl       equ 54
SYS_fcntl       equ 55
SYS_sigaction   equ 67

;;; signal.h
SIGINT equ 2

;;; ioctls.h
TCGETS equ 0x5401
TCSETS equ 0x5402

;;; termios.h
VTIME   equ 5
VMIN    equ 6

BRKINT  equ 0000002
INPCK   equ 0000020
ISTRIP  equ 0000040
ICRNL   equ 0000400
IXON    equ 0002000

OPOST   equ 0000001
ECHO    equ 0000010

CS8     equ 0000060

ICANON  equ 0000002



TERM_WIDTH equ 160
TERM_HEIGHT equ 40

%define CSI 0x1b, "["

elf_start:
    org 0x800000 - 0x54         ; Place elf header before loaded section
    db 0x7f
    db "ELF"                    ; magic
    db 0x01                     ; class (32-bit)
    db 0x01                     ; endianness (little)
    db 0x01                     ; version
    db 0x00                     ; os abi (System V)
    db 0x00                     ; abi version
    times 7 db 0                ; padding -- free realestate
    dw 0x02                     ; type (EXEC)
    dw 0x03                     ; machine (i386)
    dd 1                        ; elf version -- free realestate
    dd entry                    ; entry
    dd ph-elf_start             ; program header offset
    dd 0                        ; section header offset
    dd 0                        ; flags
    dw 0x34                     ; elf header size
    dw 0x20                     ; program header size
    dw 1                        ; program header count
    dw 0x28                     ; section header size
    dw 0                        ; section header count
    dw 0                        ; string section

ph:
    dd 0x01                     ; type (LOAD)
    dd load_start-elf_start     ; offset
    dd load_start               ; virtual address
    dd load_start               ; physical address
    dd load_end-load_start      ; size in file
    dd bss_end-load_start       ; size in memory
    dd 0x7                      ; flags (RWX)
    dd 0x1                      ; align


load_start:
entry:
    ;; raw terminal
    mov eax, SYS_ioctl
    xor ebx, ebx                ; STDIN
    mov ecx, TCGETS
    mov edx, old_termios
    int 0x80
    mov esi, old_termios
    mov edi, new_termios
    mov edx, old_termios_end
    call memcpy
    and dword [new_termios + termios_t.c_iflag], ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON)
    and dword [new_termios + termios_t.c_oflag], ~(OPOST)
    or  dword [new_termios + termios_t.c_cflag], CS8
    and dword [new_termios + termios_t.c_lflag], ~(ECHO | ICANON)
    mov byte  [new_termios + termios_t.c_cc + VMIN], 1
    mov byte  [new_termios + termios_t.c_cc + VTIME], 0
    mov eax, SYS_ioctl
    mov ecx, TCSETS
    mov edx, new_termios
    int 0x80
    ;; init terminal
    mov ecx, init_term
    mov edx, init_term_len
    call write
    ;; register SIGINT handler
    mov dword [sigaction + sigaction_t.sa_handler], handle_sigint
    mov eax, SYS_sigaction
    mov ebx, SIGINT             ; int
    mov ecx, sigaction          ; const struct old_sigaction *
    xor edx, edx                ; struct old_sigaction *
    int 0x80

draw_grid:
    mov ecx, clear_screen
    mov edx, clear_screen_len
    call write

    xor esi, esi
draw_grid_loop:
    mov ecx, [box+4*esi]
    movzx edx, word [box_sizes+2*esi]
    call write
    add esi, 1
    cmp esi, box_len
    jne draw_grid_loop

    mov ecx, help
    mov edx, help_len
    call write

draw_givens:
    mov ecx, cursor_to_top_left_cell
    mov edx, cursor_to_top_left_cell_len
    call write
    ;; esi: x, edi: y
    xor edi, edi
    imul ebp, [level], 81
    add ebp, sudoku_givens
draw_givens_y:
    xor esi, esi
draw_givens_x:
    imul eax, edi, 9
    add eax, esi
    mov dl, [ebp + eax]
    test dl, dl
    je draw_givens_inc
    add dl, "0"
    mov [write_given+4], dl
    mov ecx, write_given
    mov edx, write_given_len
    call write
draw_givens_inc:
    mov ecx, cursor_right
    mov edx, cursor_right_len
    call write
    add esi, 1
    cmp esi, 9
    jne draw_givens_x
    ;; end of draw_givens_x loop
    mov ecx, cursor_start_down
    mov edx, cursor_start_down_len
    call write
    add edi, 1
    cmp edi, 9
    jne draw_givens_y
    ;; end of draw_givens_y loop

setup_sudoku_grid:
    mov edi, sudoku_grid
    mov esi, ebp
    lea edx, [ebp + 84]
    call memcpy

update:
    mov ecx, cursor_to_top_left_cell
    mov edx, cursor_to_top_left_cell_len
    call write
    mov dword [cursor_x], 0
    mov dword [cursor_y], 0

    sub esp, 16

update_loop:
    mov eax, SYS_read
    xor ebx, ebx
    lea ecx, [esp]
    mov edx, 1
    int 0x80
    mov al, [esp]
    cmp al, "k"
    je mov_cur_up
    cmp al, "j"
    je mov_cur_down
    cmp al, "h"
    je mov_cur_left
    cmp al, "l"
    je mov_cur_right
    cmp al, "q"
    je handle_sigint
    imul ebx, [cursor_y], 9
    add ebx, [cursor_x]
    mov bl, [ebp + ebx]
    test bl, bl
    jne update_loop
    sub al, "0"
    cmp al, 0
    je clear_cell
    cmp al, 9
    jbe set_cell

    jmp update_loop

mov_cur_up:
    cmp dword [cursor_y], 0
    je update_loop
    sub dword [cursor_y], 1
    mov ecx, cursor_up
    mov edx, cursor_up_len
    call write
    jmp update_loop

mov_cur_down:
    cmp dword [cursor_y], 8
    je update_loop
    add dword [cursor_y], 1
    mov ecx, cursor_down
    mov edx, cursor_down_len
    call write
    jmp update_loop

mov_cur_left:
    cmp dword [cursor_x], 0
    je update_loop
    sub dword [cursor_x], 1
    mov ecx, cursor_left
    mov edx, cursor_left_len
    call write
    jmp update_loop

mov_cur_right:
    cmp dword [cursor_x], 8
    je update_loop
    add dword [cursor_x], 1
    mov ecx, cursor_right
    mov edx, cursor_right_len
    call write
    jmp update_loop

clear_cell:
    mov cl, " "
    call write_cell
    jmp update_loop

set_cell:
    mov cl, [esp]
    call write_cell
    ;; jmp check_sudoku

check_sudoku:
check_row:
    xor ecx, ecx
    ;; esp + 12: invalid, esp + 13: incomplete
    mov [esp + 12], ecx
    ;; ebx: x, ecx: y
check_row_y:
    xor ebx, ebx
    mov [esp], ebx
    mov [esp + 4], ebx
    mov [esp + 8], ebx
check_row_x:
    imul eax, ecx, 9
    add eax, ebx
    movzx edx, byte [sudoku_grid + eax]
    test edx, edx
    jne check_row_check
    mov byte [esp + 13], 1
    jmp check_row_inc
check_row_check:
    cmp byte [esp + edx], 0
    je check_row_inc
    mov byte [esp + 12], 1
check_row_inc:
    mov byte [esp + edx], 1
    add ebx, 1
    cmp ebx, 9
    jne check_row_x
    ;; end of check_row_x loop
    add ecx, 1
    cmp ecx, 9
    jne check_row_y
    ;; end of check_row_y loop

check_column:
    xor ebx, ebx
    ;; ebx: x, ecx: y
check_column_x:
    xor ecx, ecx
    mov [esp], ecx
    mov [esp + 4], ecx
    mov [esp + 8], ecx
check_column_y:
    imul eax, ecx, 9
    add eax, ebx
    movzx edx, byte [sudoku_grid + eax]
    test edx, edx
    je check_column_inc         ; skip check when cell not set
    cmp byte [esp + edx], 0
    je check_column_inc
    mov byte [esp + 12], 1
check_column_inc:
    mov byte [esp + edx], 1
    add ecx, 1
    cmp ecx, 9
    jne check_column_y
    ;; end of check_column_y loop
    add ebx, 1
    cmp ebx, 9
    jne check_column_x
    ;; end of check_column_x loop

check_box:
    xor ecx, ecx
    ;; ebx: block x, ecx: block y
    ;; esi: inner block x, edi inner block y
check_box_y:
    xor ebx, ebx
check_box_x:
    xor edi, edi
    mov [esp], edi
    mov [esp + 4], edi
    mov [esp + 8], edi
check_box_iy:
    xor esi, esi
check_box_ix:
    imul eax, ecx, 3
    add eax, edi
    imul eax, eax, 9
    imul edx, ebx, 3
    add eax, edx
    add eax, esi
    movzx edx, byte [sudoku_grid + eax]
    test edx, edx
    je check_box_inc         ; skip check when cell not set
    cmp byte [esp + edx], 0
    je check_box_inc
    mov byte [esp + 12], 1
check_box_inc:
    mov byte [esp + edx], 1
    add esi, 1
    cmp esi, 3
    jne check_box_ix
    ;; end of check_box_ix loop
    add edi, 1
    cmp edi, 3
    jne check_box_iy
    ;; end of check_box_iy loop
    add ebx, 1
    cmp ebx, 3
    jne check_box_x
    ;; end of check_box_x loop
    add ecx, 1
    cmp ecx, 3
    jne check_box_y
    ;; end of check_box_y loop

    cmp byte [esp + 13], 0
    je check_complete
    jmp update_loop

check_complete:
    cmp byte [esp + 12], 0
    je correct

incorrect:
    mov ecx, incorrect_msg
    mov edx, incorrect_msg_len
    call display_msg
    mov ecx, erase_line
    mov edx, erase_line_len
    call write
    mov ecx, cursor_to_top_left_cell
    mov edx, cursor_to_top_left_cell_len
    call write
    add esp, 16
    jmp update

correct:
    add dword [level], 1
    cmp dword [level], 40
    je win
    mov ecx, correct_msg
    mov edx, correct_msg_len
    call display_msg
    add esp, 16
    jmp draw_grid

display_msg:
    call write
    ;; wait for a key press
    mov eax, SYS_read
    xor ebx, ebx
    lea ecx, [esp - 4]
    mov edx, 1
    int 0x80
    ret




;;; al: value, cl: ascii value
write_cell:
    imul ebx, [cursor_y], 9
    add ebx, [cursor_x]
    mov byte sudoku_grid[ebx], al
    mov [write_cell_str], cl
    mov ecx, write_cell_str
    mov edx, write_cell_str_len
    call write
    ret


write:
    mov eax, SYS_write
    mov ebx, 1
    int 0x80
    ret

win:
    mov ecx, win_msg
    mov edx, win_msg_len
    call display_msg

handle_sigint:
    ;; reset terminal
    mov ecx, deinit_term
    mov edx, deinit_term_len
    call write
    ;; restore termios
    mov eax, SYS_ioctl
    xor ebx, ebx                ; STDIN
    mov ecx, TCSETS
    mov edx, old_termios
    int 0x80
    ;; exit 0
    mov eax, SYS_exit
    xor ebx, ebx
    int 0x80

;;; esi src, edi dest, edx src end
;;; clobbers esi, edi, eax
memcpy:
    cmp esi, edx
    je ret
    mov eax, [esi]
    mov [edi], eax
    add esi, 4
    add edi, 4
    jmp memcpy
    ret:
        ret


init_term:
    db CSI, "?1049h"            ; enable alternate buffer
init_term_len: equ $ - init_term

deinit_term:
    db CSI, "?1049l"            ; disable alternate buffer
    db CSI, "?25h"              ; show cursor
deinit_term_len: equ $ - deinit_term

struc sigaction_t
    .sa_handler:    resd 1      ; void(*) (int)
    .sa_mask:       resb 128    ; sigset_t
    .sa_flags:      resd 1      ; int
    .sa_sigaction:  resd 1      ; void(*) (int, siginfo_t *, void *)
endstruc

struc termios_t
    .c_iflag:   resd 1          ; input mode flags
    .c_oflag:   resd 1          ; output mode flags
    .c_cflag:   resd 1          ; control mode flags
    .c_lflag:   resd 1          ; local mode flags
    .c_line:    resb 1          ; line discipline
    .c_cc:      resb 32         ; control characters
    .c_ispeed:  resd 1          ; input speed
    .c_ospeed:  resd 1          ; output speed
endstruc

section .data
cursor_x:
    dd 0
cursor_y:
    dd 0
level:
    dd 0

;;; Replace AA by number or space before use
write_cell_str:
    db 0xAA, CSI, "D"
write_cell_str_len: equ $ - write_cell_str

write_given:
    db CSI, "1m", 0xAA, CSI, "0m", CSI, "D"
write_given_len: equ $ - write_given

clear_screen:
    db CSI, "2J", CSI, "H", CSI, "?25h"
clear_screen_len: equ $ - clear_screen
cursor_to_top_left_cell:
    db CSI, "2;3H"
cursor_to_top_left_cell_len: equ $ - cursor_to_top_left_cell
cursor_start_down:
    db CSI, "2E", CSI, "2C"
cursor_start_down_len: equ $ - cursor_start_down
cursor_up:
    db CSI, "2A"
cursor_up_len: equ $ - cursor_up
cursor_down:
    db CSI, "2B"
cursor_down_len: equ $ - cursor_down
cursor_left:
    db CSI, "4D"
cursor_left_len: equ $ - cursor_left
cursor_right:
    db CSI, "4C"
cursor_right_len: equ $ - cursor_right

win_msg:
    db CSI, "2J", CSI, "H", "You won! 🎉", 0xD, 0xA, "Made with ❤ by realleif."
win_msg_len equ $ - win_msg
correct_msg:
    db CSI, "24H", CSI, "32mLevel complete!", CSI, "0m Press any key to continue.", CSI, "?25l"
correct_msg_len equ $ - correct_msg
incorrect_msg:
    db CSI, "24H", CSI, "31mYour solution is invalid.", CSI, "0m Press any key to try again.", CSI, "?25l"
incorrect_msg_len equ $ - incorrect_msg

erase_line:
    db CSI, "?25h", CSI, "1K"
erase_line_len equ $ - erase_line

box:
    dd box_top, box_cell, box_mid_light, box_cell, box_mid_light, box_cell
    dd box_mid_heavy, box_cell, box_mid_light, box_cell, box_mid_light, box_cell
    dd box_mid_heavy, box_cell, box_mid_light, box_cell, box_mid_light, box_cell
    dd box_bottom
box_len equ ($ - box) / 4
box_sizes:
    dw box_top_len, box_cell_len, box_mid_light_len, box_cell_len, box_mid_light_len, box_cell_len
    dw box_mid_heavy_len, box_cell_len, box_mid_light_len, box_cell_len, box_mid_light_len, box_cell_len
    dw box_mid_heavy_len, box_cell_len, box_mid_light_len, box_cell_len, box_mid_light_len, box_cell_len
    dw box_bottom_len


box_top:
    db "┏━━━┯━━━┯━━━┳━━━┯━━━┯━━━┳━━━┯━━━┯━━━┓", 0xD, 0xA
box_top_len: equ $ - box_top
box_cell:
    db "┃   │   │   ┃   │   │   ┃   │   │   ┃", 0xD, 0xA
box_cell_len: equ $ - box_cell
box_mid_light:
    db "┠───┼───┼───╂───┼───┼───╂───┼───┼───┨", 0xD, 0xA
box_mid_light_len: equ $ - box_mid_light
box_mid_heavy:
    db "┣━━━┿━━━┿━━━╋━━━┿━━━┿━━━╋━━━┿━━━┿━━━┫", 0xD, 0xA
box_mid_heavy_len: equ $ - box_mid_heavy
box_bottom:
    db "┗━━━┷━━━┷━━━┻━━━┷━━━┷━━━┻━━━┷━━━┷━━━┛", 0xD, 0xA
box_bottom_len: equ $ - box_bottom
help:
    db "Press h, j, k, l to move left, down, up, right.", 0xD, 0xA
    db "Press 1-9 to set a number, press 0 to clear a cell.", 0xD, 0xA
    db "Press q to quit."
help_len equ $ - help


align 4
sudoku_givens:
%include "build/sudoku.S"

load_end:

section .bss
    align 4
sigaction:
    istruc sigaction_t
        at .sa_handler,     resd 1
        at .sa_mask,        resb 128
        at .sa_flags,       resd 1
        at .sa_sigaction,   resd 1
    iend

align 4
old_termios:
    istruc termios_t
        at .c_iflag,   resd 1
        at .c_oflag,   resd 1
        at .c_cflag,   resd 1
        at .c_lflag,   resd 1
        at .c_line,    resb 1
        at .c_cc,      resb 32
        at .c_ispeed,  resd 1
        at .c_ospeed,  resd 1
    iend
    resb 3
old_termios_end:

align 4
new_termios:
    istruc termios_t
        at .c_iflag,   resd 1
        at .c_oflag,   resd 1
        at .c_cflag,   resd 1
        at .c_lflag,   resd 1
        at .c_line,    resb 1
        at .c_cc,      resb 32
        at .c_ispeed,  resd 1
        at .c_ospeed,  resd 1
    iend
    resb 3

align 4
sudoku_grid:
    resb 84                     ; 81 cells + 3 extra padding for 4 byte operations

buf:
    resb 1
bss_end:
