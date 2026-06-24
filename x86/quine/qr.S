.include "../common/constants.S"
.att_syntax

    .struct 0
block_data:
    .struct . + 4
block_data_len:
    .struct . + 4
block_ecc:
    .struct . + 30
sizeof_block:


.section .text
.global _start
_start:
    # esi points to the first byte after the elf file, by the design of the elf decompressor
    mov $0x7f000, %edi
    mov $bitstream, %edx


write_mode_and_character_count:
    mov %esi, %eax
    sub %edi, %eax
    mov %eax, %ebx
    shr $12, %ax
    or $0x40, %ax
    mov %al, (%edx)
    inc %edx
    mov %ebx, %eax
    shr $4, %ax
    mov %al, (%edx)
    inc %edx
    sal $4, %ebx
    mov %bl, (%edx)

encode_bitstream:
    mov (%edi), %al
    inc %edi
    mov %eax, %ecx
    sal $4, %eax
    shr $4, %cl
    or %cl, (%edx)
    inc %edx
    or %al, (%edx)
    cmp %esi, %edi
    jne encode_bitstream

pad_bitstream:
    inc %edx
    cmp $bitstream_end, %edx
    je pad_bitstream_end
    movb $0xec, (%edx)
    inc %edx
    cmp $bitstream_end, %edx
    je pad_bitstream_end
    movb $0x11, (%edx)
    jmp pad_bitstream
pad_bitstream_end:

init_lookup_table: # from libqrencode
    movb $0xff, aindex
    mov $1, %eax            # b
    xor %edx, %edx          # i
init_lookup_table_loop:
    mov %al, alpha(%edx)    # alpha[i] = b
    mov %dl, aindex(%eax)   # aindex[b] = i
    add %eax, %eax          # b <<= 1
    mov %eax, %ecx
    xor $0x11d, %ecx        # b ^ 0x11d
    test $1, %ah
    cmovne %ecx, %eax       # b = b ^ 0x11d ? (b & 0x100) : b
    inc %edx
    cmp $0xff, %edx
    jne init_lookup_table_loop

init_blocks:
    mov $blocks, %esi       # block*
    mov $bitstream, %edx    # data*

    mov $19, %edi           # iterations
    mov $118, %ecx          # data length
    call init_blocks_loop

    mov $6, %edi            # iterations
    mov $119, %ecx          # data length
    call init_blocks_loop


    # ecx: codewords, esi: i, edi: j
place_codewords:
    mov $codewords, %ecx    # codewords = codewords
    xor %edi, %edi          # j = 0
place_codewords_first_outer:
    xor %esi, %esi          # i = 0
place_codewords_first_inner:
    imul $sizeof_block, %esi, %eax
    mov blocks(%eax), %eax
    mov (%eax, %edi), %al
    mov %al, (%ecx)         # *codewords = blocks[i].data[j]
    inc %ecx                # codewords++
    inc %esi                # i++
    cmp $25, %esi           # i < 25
    jne place_codewords_first_inner
    inc %edi                # j++
    cmp $118, %edi          # j < 118
    jne place_codewords_first_outer
    mov $19, %esi           # i = 19
place_codewords_long_data:
    imul $sizeof_block, %esi, %eax
    mov blocks(%eax), %eax
    mov 118(%eax), %al
    mov %al, (%ecx)         # *codewords = blocks[i].data[119]
    inc %ecx                # codewords++
    inc %esi                # i++
    cmp $25, %esi           # i < 25
    jne place_codewords_long_data
    xor %edi, %edi          # j = 0
place_codewords_ecc_outer:
    xor %esi, %esi          # i = 0
place_codewords_ecc_inner:
    imul $sizeof_block, %esi, %eax
    mov blocks+block_ecc(%eax,%edi), %al
    mov %al, (%ecx)         # *codewords = blocks[i].ecc[j]
    inc %ecx                # codewords++
    inc %esi                # i++
    cmp $25, %esi           # i < 25
    jne place_codewords_ecc_inner
    inc %edi                # j++
    cmp $30, %edi           # j < 30
    jne place_codewords_ecc_outer

fill:
    # ecx: current_bitmap*, esi: x, edi: y
    # edx: status
    # -16(esp): codewords*
    # -20(esp): j (bit counter)
    xor %edx, %edx          # status = 0
    movl $codewords, -16(%esp)
    mov $bitmap+(177*(177-1)+177-1), %ecx
    mov $177-1, %esi        # x = 177-1
    mov %esi, %edi          # y = 177-1
fill_next_codeword:
    movl $7, -20(%esp)      # j = 7
fill_next_bit:
    mov -16(%esp), %ebx
    movzb (%ebx), %eax
    movzb -20(%esp), %ebx
    bt %ebx, %eax
    setc (%ecx)             # *current_bitmap = (*codewords >> j) & 0x01
fill_next_position:
    cmp $2, %dl
    je fill_next_position_2
    ja fill_next_position_3
    dec %esi                # x--
    dec %dl
    mov $3, %dl             # status = 3
    jz fill_update_cur      # status == 1
    mov $2, %dl             # status = 2
    jmp fill_update_cur
fill_next_position_2:
    test %edi, %edi         # y != 0
    jnz fill_next_position_2_normal
fill_next_position_y0:
    dec %esi                # x--
    cmp $6, %esi            # x != 7
    jne fill_next_position_status_1
    jmp fill_next_position_y0
fill_next_position_2_normal:
    dec %edi                # y--
    inc %esi                # x++
    jmp fill_next_position_status_0
fill_next_position_3:
    cmp $177-1, %edi        # y != 177-1
    jne fill_next_position_3_normal
    dec %esi                # x--
fill_next_position_status_0:
    xor %edx, %edx          # status = 0
    jmp fill_update_cur
fill_next_position_3_normal:
    inc %esi                # x++
    inc %edi                # y++
fill_next_position_status_1:
    mov $1, %dl             # status = 1
fill_update_cur:
    imul $177, %edi, %ebx
    lea bitmap(%esi, %ebx), %ecx # current_bitmap = &bitmap[y*177+x]
    cmpb $0, (%ecx)
    js fill_next_position   # *current_bitmap & 1
    subl $1, -20(%esp)       # (j--)
    jnb fill_next_bit       # j-- != 0
    incl -16(%esp)           # codewords++
    //cmpl $codewords+3596, -16(%esp)
    cmpl $codewords_end, -16(%esp)
    jne fill_next_codeword  # codewords != codewords_end



mask:
    # esi: x, edi: y
    mov $bitmap, %edx
    xor %edi, %edi
mask_y:
    xor %esi, %esi
mask_x:
    mov (%edx), %cl
    test %cl, %cl
    js mask_inc
    lea (%esi,%edi), %eax
    and $1, %eax
    not %eax
    xor %eax, %ecx
    mov %cl, (%edx)
mask_inc:
    inc %edx
    inc %esi
    cmp $177, %esi
    jne mask_x
    inc %edi
    cmp $177, %edi
    jne mask_y

    # esi: x, edi: y
print:
    call print_quiet
    xor %edi, %edi
print_y:
    xor %esi, %esi
print_x:
    # load value at x, y into eax
    imul $177, %edi, %eax
    add %esi, %eax
    mov bitmap(%eax), %dl
    testb $1, bitmap(%eax)
    je print_white
print_black:
    mov $black, %ecx
    mov $black_len, %edx
    jmp print_write
print_white:
    mov $white, %ecx
    mov $white_len, %edx
print_write:
    call write
    inc %esi
    cmp $177, %esi
    jne print_x
    mov $new_line, %ecx
    mov $new_line_len, %edx
    call write
    inc %edi
    cmp $177, %edi
    jne print_y
    call print_quiet

exit:
    mov $SYS_exit, %eax
    xor %ebx, %ebx
    int $0x80

    # input:
    # esi: block*, edx: data*, edi: iterations, ecx: data length
init_blocks_loop:
    mov %edx, block_data(%esi)
    mov %ecx, block_data_len(%esi)
    # call block_init
    push %ecx
    push %edi

    # ebx: feedback, ecx: loop counter
ecc_encode:
    movzb (%edx), %eax
    xor block_ecc(%esi), %al
    movzb aindex(%eax), %ebx
    cmp $0xff, %bl
    je ecc_memmove_ecc

    # edi: j
    mov $1, %edi
    push %edx
    push %ecx
ecc_encode_loop1:
    mov %edi, %eax
    neg %eax
    movzb generator+30(%eax), %eax
    xor %edx, %edx
    mov $0xff, %ecx
    add %ebx, %eax
    div %ecx                # edx = eax % 0xff, eax = eax / 0xff
    mov alpha(%edx), %al
    xor %al, block_ecc(%esi, %edi)
    inc %edi
    cmp $30, %edi
    jne ecc_encode_loop1
    pop %ecx
    pop %edx
ecc_memmove_ecc:
    xor %edi, %edi
ecc_memmove_ecc_loop:
    mov block_ecc+1(%esi, %edi), %al
    mov %al, block_ecc(%esi, %edi)
    incl %edi
    cmp $29, %edi
    jne ecc_memmove_ecc_loop

    xor %eax, %eax
    cmp $0xff, %bl
    je ecc_encode_inc
    push %edx
    push %ecx
    movzb generator, %eax
    xor %edx, %edx
    mov $0xff, %ecx
    add %ebx, %eax
    div %ecx
    mov alpha(%edx),%al
    pop %ecx
    pop %edx
ecc_encode_inc:
    mov %al, block_ecc+29(%esi)
    inc %edx
    dec %ecx
    jnz ecc_encode

    pop %edi
    pop %ecx
    add $sizeof_block, %esi
    #add %ecx, %edx
    dec %edi
    jnz init_blocks_loop
    ret


print_quiet:
    mov $new_line, %ecx
    mov $new_line_len, %edx
    mov $4, %esi
print_quiet_loop:
    call write
    dec %esi
    jnz print_quiet_loop
    ret

    # ecx: data, edx: data length
write:
    mov $SYS_write, %eax
    mov $STDOUT_FILENO, %ebx
    int $0x80
    ret

.section .data
black:
    .ascii "██"
    .set black_len, . - black

white:
    .ascii "  "
    .equ white_len, . - white
new_line:
    .ascii "\n        "
    .equ new_line_len, . - new_line

bitmap:
    .include "bitmap.S"

generator:
    .byte 0xb4,0xc0,0x28,0xee,0xd8,0xfb,0x25,0x9c,0x82,0xe0,0xc1,0xe2,0xad,0x2a,0x7d,0xde,0x60,0xef,0x56,0x6e,0x30,0x32,0xb6,0xb3,0x1f,0xd8,0x98,0x91,0xad,0x29

.section .bss
alpha:
    .skip 256
aindex:
    .skip 256

blocks:
    .skip sizeof_block * (19+6)
blocks_end:

bitstream:
    .skip 2956
bitstream_end:


codewords:
    .skip 3706
codewords_end:
