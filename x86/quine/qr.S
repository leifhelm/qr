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

    jmp png

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
    jmp exit

png:
    mov %esp, %ebp
    sub $16, %esp
    mov $png_header, %ecx
    mov $png_header_len, %edx
    call write

    mov $png_idat, %esi
    mov $chunk_header+4, %edi
    mov $png_idat_len, %ecx
    rep movsb                   # move precomputed header

    sub $1, %edi # compensate for incomplete byte
    mov %edi, -4(%ebp)
    movb $5, -8(%ebp)

    # esi: x, edi: y
    xor %edi, %edi
png_y:
    xor %esi, %esi
    mov $0b010101010, %eax
    mov $9, %edx
    call bitstring_put          # put literals 0x00 0xFF 0xFF 0xFF 0xFF
png_x:
    imul $177, %edi, %eax
    add %esi, %eax
    mov bitmap(%eax), %dl
    testb $1, bitmap(%eax)
    je png_white
png_black:
    xor %eax, %eax
    mov $1, %edx                # put literal 0x00
    jmp png_bitstring_put
png_white:
    mov $0b01, %eax
    mov $2, %edx                # put literal 0xFF
png_bitstring_put:
    call bitstring_put
    inc %esi
    cmp $177, %esi
    jne png_x
    mov $png_scanline_end, %ebx
    mov $png_scanline_end_bit_len, %ecx
    call bitstring_concat
    inc %edi
    cmp $177, %edi
    jne png_y
    mov $png_quiet_end, %ebx
    mov $png_quiet_end_bit_len, %ecx
    call bitstring_concat

png_compute_adler32:
    movl $1, -12(%ebp)      # a = 1
    movl $0, -16(%ebp)      # b = 1
    call png_adler32_quiet_full
    xor %edi, %edi
png_compute_adler32_y:
    xor %esi, %esi
    xor %edx, %edx
    call update_adler32
    call png_adler32_quiet
png_compute_adler32_x:
    imul $177, %edi, %eax
    add %esi, %eax
    mov bitmap(%eax), %dl
    testb $1, bitmap(%eax)
    je png_compute_adler32_white    # bitmap[177*y+x] & 0x01 != 1
png_compute_adler32_black:
    xor %edx, %edx
    jmp png_compute_adler32_call
png_compute_adler32_white:
    mov $0xff, %edx
png_compute_adler32_call:
    call update_adler32
    inc %esi                # x++
    cmp $177, %esi
    jne png_compute_adler32_x # x != 177
    call png_adler32_quiet
    mov $7, %ecx
png_compute_adler32_repeat:
    call png_adler32_scanline_end
    dec %ecx
    jnz png_compute_adler32_repeat
    inc %edi
    cmp $177, %edi
    jne png_compute_adler32_y

    call png_adler32_quiet_full
png_compute_adler32_finish:
    mov -12(%ebp), %eax     # eax = a
    mov -16(%ebp), %ebx     # ebx = b
    sal $16, %ebx
    or %eax, %ebx
    bswap %ebx              # ebx = adler in big endian
    mov -4(%ebp), %edi      # edi = chunk ptr
    cmpb $1, -8(%ebp)
    sbb $-1, %edi           # if (bit position != 0) edi = edi + 1
    mov %ebx, (%edi)        # write Adler32 sum
    add $4, %edi            # edi += 4 i.e. move edi after Adler32 sum

    mov %edi, %eax
    sub $chunk_data, %eax   # eax = size of chunk
    bswap %eax
    mov %eax, chunk_header  # set chunk length

    # eax: c, ebx: i, edx: n
png_compute_crc_table:
    xor %edx, %edx
png_compute_crc_table_outer:
    mov %edx, %eax
    mov $8, %ebx
png_compute_crc_table_inner:
    mov %eax, %ecx          # ecx = c
    shr $1, %eax            # c >>= 1
    and $1, %ecx
    neg %ecx                # ecx = -1 ? ecx & 1 : 0
    and $0xedb88320, %ecx   # ecx ^= 0xedb88320
    xor %ecx, %eax          # c &= ecx
    dec %ebx
    jnz png_compute_crc_table_inner # i != 0
    mov %eax, crc_table(,%edx,4)
    inc %edx                # n += 1
    cmp $256, %edx
    jne png_compute_crc_table_outer # n != 256

    # eax: c, edx: buf, current buffer pointer, edi: end pointer
png_compute_idat_chunk_crc:
    mov $0xffffffff, %eax   # c = 0xffffffff
    mov $chunk_header+4, %edx   # init buf
png_compute_idat_chunk_crc_loop:
    cmp %edi, %edx
    je png_write_idat_chunk_crc # buf == end
    mov (%edx), %cl         # ecx = *buf
    inc %edx                # buf++
    xor %eax, %ecx          # ecx ^= c
    movzb %cl, %ecx         # ecx &= 0xff
    shr $8, %eax
    xor crc_table(,%ecx,4), %eax # c = crc_table[ecx] ^ (c << 8)
    jmp png_compute_idat_chunk_crc_loop
png_write_idat_chunk_crc:
    not %eax                # crc = ~crc
    bswap %eax
    movl %eax, (%edi)       # write crc
    mov %edi, %edx
    sub $chunk_header-4, %edx
    mov $chunk_header, %ecx
    call write              # write idat chunk




png_write_iend:
    mov $png_iend, %ecx
    mov $png_iend_len, %edx
    call write


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
    dec %edi
    jnz init_blocks_loop
    ret


    # eax: bits, edx: number of bits
    # -4(ebp): byte ptr
    # -8(ebp): bit position
    # clobers: eax, edx
bitstring_put:
    push %ebx
    push %esi
    push %ecx
bitstring_put_loop:
    test %edx, %edx
    je bitstring_put_ret    # number of bits = 0
    dec %edx
    mov %eax, %esi          # esi = bits
    sar $1, %eax            # bits >>= 1
    and $1, %esi            # esi & 0x01
bitset:
    mov -4(%ebp), %ebx
    mov (%ebx), %bl     # bl = *byte ptr
    mov -8(%ebp), %ecx  # ecx: bit position
    sal %cl, %esi
    btr %ecx, %ebx
    or %esi, %ebx
    mov -4(%ebp), %esi
    mov %bl, (%esi)     # *byte ptr = *byte ptr with bit %cl equal %esi
    cmp $7, %cl
    jne bitstring_put_default_inc
    incl -4(%ebp)       # byte ptr++
    movl $0, -8(%ebp)   # bit position = 0
    jmp bitstring_put_loop
bitstring_put_default_inc:
    incl -8(%ebp)       # bit position++
    jmp bitstring_put_loop
bitstring_put_ret:
    pop %ecx
    pop %esi
    pop %ebx
    ret

    # ebx: src bytes, ecx: src bit length
    # clobbers directly: ebx, ecx
bitstring_concat:
    movzb (%ebx), %eax
    cmp $8, %ecx
    jb bitstring_concat_last
    mov $8, %edx
    call bitstring_put
    inc %ebx
    sub $8, %ecx
    jmp bitstring_concat
bitstring_concat_last:
    mov %ecx, %edx
    call bitstring_put
    ret

    #  dl: new byte
    # -12(ebp): a
    # -16(ebp): b
update_adler32:
    push %ecx
    movzb %dl, %edx
    mov $65521, %ecx
    mov -12(%ebp), %eax     # eax = a
    add %edx, %eax
    xor %edx, %edx
    div %ecx
    mov %edx, -12(%ebp)     # a = (a + new byte) % 65521
    mov -16(%ebp), %ebx     # ebx = b
    lea (%edx,%ebx), %eax   # eax = a + b
    xor %edx, %edx
    div %ecx
    mov %edx, -16(%ebp)
    pop %ecx
    ret

png_adler32_quiet_full:
    xor %edx, %edx
    call update_adler32     # 0x00
    mov $185, %esi
png_adler32_quiet_full_initial_0xff:
    mov $0xff, %dl
    call update_adler32     # 0xFF * 185
    dec %esi
    jnz png_adler32_quiet_full_initial_0xff
    mov $31, %edi
png_adler32_quiet_full_y:
    call png_adler32_scanline_end
    dec %edi
    jnz png_adler32_quiet_full_y
    ret

png_adler32_scanline_end:
    mov $0x02, %dl
    call update_adler32     # 0x02
    mov $185, %esi
png_adler32_scanline_end_x:
    xor %edx, %edx
    call update_adler32     # 0x00 * 185
    dec %esi
    jnz png_adler32_scanline_end_x
    ret


png_adler32_quiet:
    mov $0xff, %dl
    call update_adler32
    mov $0xff, %dl
    call update_adler32
    mov $0xff, %dl
    call update_adler32
    mov $0xff, %dl
    call update_adler32
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


png_header:
    .byte 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A    # magic
    .byte 0x00, 0x00, 0x00, 0x0D                            # length = 13
    .byte 0x49, 0x48, 0x44, 0x52                            # chunk type = IHDR
    .byte 0x00, 0x00, 0x05, 0xC8                            # width = 1480
    .byte 0x00, 0x00, 0x05, 0xC8                            # height = 1480
    .byte 0x01                                              # bit depth = 1
    .byte 0x00                                              # color type = greyscale
    .byte 0x00                                              # compression method = deflate
    .byte 0x00                                              # filter method = 0 (default)
    .byte 0x00                                              # interlace method = none
    .byte 0xa6, 0x4c, 0x10, 0xd6                            # CRC
    png_header_len = . - png_header

png_iend:
    .byte 0x00, 0x00, 0x00, 0x00                            # length = 0
    .byte 0x49, 0x45, 0x4E, 0x44                            # chunk type = IEND
    .byte 0xae, 0x42, 0x60, 0x82                            # CRC
    png_iend_len = . - png_iend

png_idat:
    .byte 0x49, 0x44, 0x41, 0x54                            # chunk type = IDAT
    .byte 0x78, 0x01                                        # zlib header: deflate, no preset, level fast, 32K window size
    .byte 0xed,0xd0,0x01,0x09,0x03,0x41,0x14,0xc5,0xc0,0xe1,0xfc,0x7b,0x4e,0x55,0x2c,0xf4,0xc3,0x8b,0x82,0x21,0xba,0xda,0xe7,0x6a,0x93,0x4f,0x3e,0xf9,0xe4,0x93,0x4f,0x3e,0xf9,0xe4,0x93,0x4f,0x3e,0xf9,0xe4,0x93,0x4f,0x3e,0xf9,0xe4,0x93,0x4f,0x3e,0xf9,0xe4,0x93,0xff,0xbf,0x1c # bit position = 5, bit length = 421
    png_idat_len = . - png_idat

png_scanline_end:
    .byte 0x55,0x77,0x9f,0x4f,0x3e,0xf9,0xe4,0x93,0xbf,0x90,0x03 # bit position = 2, bit length = 82
    png_scanline_end_bit_len = 82
png_quiet_end:
    .byte 0xba,0xda,0xdd,0xe7,0x93,0x4f,0x3e,0xf9,0xe4,0x93,0x4f,0x3e,0xf9,0xe4,0x93,0x4f,0x3e,0xf9,0xe4,0x93,0x4f,0x3e,0xf9,0xe4,0x93,0x4f,0x3e,0xf9,0xe4,0x93,0xff,0xbf,0xfc,0x07 # bit position = 4, bit length = 268
    png_quiet_end_bit_len = 268

bitmap:
    .include "bitmap.S"

generator:
    .byte 0xb4,0xc0,0x28,0xee,0xd8,0xfb,0x25,0x9c,0x82,0xe0,0xc1,0xe2,0xad,0x2a,0x7d,0xde,0x60,0xef,0x56,0x6e,0x30,0x32,0xb6,0xb3,0x1f,0xd8,0x98,0x91,0xad,0x29

.section .bss
alpha:
    .skip 256
aindex:
    .skip 256
crc_table:
    .skip 256 * 4

blocks:
    .skip sizeof_block * (19+6)
blocks_end:

bitstream:
    .skip 2956
bitstream_end:


codewords:
    .skip 3706
codewords_end:

chunk_header:
    .skip 8
chunk_data:
    .skip 0xa000
