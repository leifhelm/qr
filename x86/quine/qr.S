.include "../common/constants.S"
.att_syntax

    .struct 0
block_data:
    .skip 4
block_data_len:
    .skip 4
block_ecc:
    .skip 30
sizeof_block:

# Global stack frame (scratch space)
    .struct 0
file:
    .skip 4
byte_ptr:
    .skip 4
adler32_a:
    .skip 4
adler32_b:
    .skip 4
best_score:
    .skip 4
apply_mask_p:
    .skip 4
apply_mask_i_plus_j:
    .skip 4
# Byte aligned variables
output_type:
    .skip 1
bit_position:
    .skip 1
mask:
    .skip 1
best_mask:
    .skip 1
    .align 4
sizeof_scratch:


.section .text
.global _start
_start:
    # esi points to the first byte after the elf file, by the design of the elf decompressor
    mov (%esp), %edi            # edi = argc
    mov $1, %edx                # i = 1
    lea (%esp, %edx, 4), %ecx   # ecx = argv
    mov $scratch, %ebp          # set up scratch space
//    push %esi                   # save esi
args_loop:
    cmp %edi, %edx
    jae args_complete
    mov (%ecx, %edx, 4), %ebx   # string 2 = argv[i]
    mov $flag_help, %eax
    call str_cmp
    test %eax, %eax
    jnz print_help              # argv[i] == flag_help
    mov $flag_png, %eax
    call str_cmp
    test %eax, %eax
    jz args_after_png           # argv[i] != flag_png
    movb $1, output_type(%ebp)  # output_type = 1
    jmp args_inc
args_after_png:
    mov %ebx, file(%ebp)        # file = argv[i]
args_inc:
    inc %edx
    jmp args_loop
args_complete:
    cmpl $0, file(%ebp)
    je encode_self              # file == 0
    mov $SYS_open, %eax
    mov file(%ebp), %ebx
    mov $O_RDONLY, %ecx
    int $0x80                   # fd = open(file, O_RDONLY)
    test %eax, %eax
    js print_cannot_open_file   # fd < 0

    mov %eax, %ebx
    mov $SYS_read, %eax
    mov $input, %ecx
    mov $2953, %edx
    int $0x80                   # read(fd, data, 2953)
    test %eax, %eax
    jle print_cannot_read_file  # ret <= 0
    mov %ecx, %edi              # data
    lea (%ecx, %eax), %esi      # data end = data + length
    jmp encode_qr_code
encode_self:
    mov $0x7f000, %edi

    # edi: data, esi: data end
encode_qr_code:
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

    # eax: i
    # edx: v
write_timing:
    xor %eax, %eax      # i = 0
write_timing_loop:
    lea 1(%eax), %edx   # v = i+1
    and $1, %edx        # v &= 1
    or $-0x80, %edx     # v = 0x80 | ((i+1)&1)
    mov %dl, bitmap+177*6(%eax) # bitmap[177*6+i] = v
    imul $177, %eax, %ecx
    mov %dl, bitmap+6(%ecx)     # bitmpa[177*i+6] = v
    inc %eax            # i++
    cmp $177, %eax
    jne write_timing_loop   # i != 177

write_finder_pattern:
    mov $7, %ecx        # size = 7
    mov $finder_pattern, %edx   # pattern = finder_pattern
    xor %eax, %eax      # seperator offset = 0
    xor %ebx, %ebx      # finder offset = 0
    call write_seperator
    call write_pattern
    mov $177-8, %eax    # seperator offset = 177-8
    lea 1(%eax), %ebx   # finder offset = 177-7
    call write_seperator
    call write_pattern
    mov $177*(177-8), %eax  # seperator offset = 177*(177-8)
    lea 177(%eax), %ebx # finder offset = 177*(177-7)
    call write_seperator
    call write_pattern

    # eax: end
    # ecx: d
    # edx: second position
    # esi: x
    # edi: y
write_alignment_pattern:
    mov $28, %edx       # second position = 28
    mov $28, %ecx       # d = 28
    mov $28+28*5, %eax  # end = second position + d*5
    mov %edx, %esi      # x = second position
    mov $4, %edi        # y = 4
write_alignment_pattern_loop:
    call write_one_alignment_pattern
    xchg %esi, %edi     # exchange x and y
    call write_one_alignment_pattern
    xchg %esi, %edi     # switch x and y back
    add %ecx, %esi      # x += d
    cmp %eax, %esi
    jne write_alignment_pattern_loop    # x != end
    add %ecx, %eax      # end += d
    mov %edx, %edi      # y = second position
write_alignment_pattern_y:
    mov %edx, %esi      # x = second position
write_alignment_pattern_x:
    call write_one_alignment_pattern
    add %ecx, %esi      # x += d
    cmp %eax, %esi
    jne write_alignment_pattern_x   # x != end
    add %ecx, %edi      # y += d
    cmp %eax, %edi
    jne write_alignment_pattern_y   # y != end

add_placeholders:
    xor %esi, %esi
    call write_format_info  # write_format_info(0)
    movb $0x80, bitmap+177*(177-8)+8    # placeholder at dark module
    xor %ebx, %ebx
    call write_version_info # write_version_info(0)

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

select_mask:
    movl $0xffffffff, best_score(%ebp)  # best_score = INT_MAX
select_mask_loop:
    call apply_mask

    # ebx: score
score_mask:
    xor %ebx, %ebx      # score = 0

    # edi: i
score_n1n3:
    xor %edi, %edi      # i = 0
score_n1n3_loop:
    mov $1, %eax        # stride = 1
    imul $177, %edi, %ecx
    add $bitmap, %ecx   # bitmap = bitmap + i * 177
    call compute_run_length
    call compute_n1n3
    mov $177, %eax      # stride = 177
    lea bitmap(%edi), %ecx  # bitmap = bitmap + i
    call compute_run_length
    call compute_n1n3

    inc %edi
    cmp $177, %edi
    jne score_n1n3_loop

    # edx: *bitmap
    # esi: x
    # edi: y
    # al: light
    # cl: dark
score_n2:
    xor %edi, %edi  # y = 0
score_n2_y:
    xor %esi, %esi  # x = 0
score_n2_x:
    imul $177, %edi, %edx
    lea bitmap(%esi, %edx), %edx    # bitmap = bitmap + x + 177 * y

    mov (%edx), %al
    or 1(%edx), %al
    or 177(%edx), %al
    or 178(%edx), %al
    not %eax        # light = (bitmap[0] | bitmap[1] | bitmap[177] | bitmap[178]) ^ 0xff
    mov (%edx), %cl
    and 1(%edx), %cl
    and 177(%edx), %cl
    and 178(%edx), %cl  # dark = (bitmap[0] & bitmap[1] & bitmap[177] & bitmap[178])
    or %al, %cl
    and $1, %ecx    # ecx = (light | dark) & 1
    lea (%ecx, %ecx, 2), %ecx   # ecx *= 3
    add %ecx, %ebx  # score += 3 * ((light | dark) & 1)

    inc %esi
    cmp $176, %esi
    jne score_n2_x  # x != 176
    inc %edi
    cmp $176, %edi
    jne score_n2_y  # y != 176

    # esi: x
    # edi: y
    # eax: darks
score_n4:
    xor %eax, %eax  # darks = 0
    xor %edi, %edi  # y = 0
score_n4_y:
    xor %esi, %esi  # x = 0
score_n4_x:
    imul $177, %edi, %edx
    lea bitmap(%esi, %edx), %edx    # bitmap = bitmap + x + 177 * y

    mov (%edx), %cl
    and $1, %ecx
    add %ecx, %eax  # darks += *bitmap & 1

    inc %esi
    cmp $177, %esi
    jne score_n4_x  # x != 177
    inc %edi
    cmp $177, %edi
    jne score_n4_y  # y != 177

    imul $200, %eax, %eax # eax = 200 * darks
    add $177*177, %eax # eax = 200 * darks + 177 * 177
    mov $177*177*2, %ecx    # ecx = 177 * 177 * 2
    xor %edx, %edx  # edx = 0
    div %ecx        # eax = (200 * darks + 177 * 177) / (177 * 2)
    sub $50, %eax   # eax -= 50
    mov %eax, %edx
    neg %edx
    cmovns %edx, %eax   # eax = abs(eax)
    cdq             # sign extend eax to edx:eax
    mov $5, %ecx
    idiv %ecx       # eax = eax / 5
    imull $10, %eax, %eax   # eax *= 10
    add %eax, %ebx  # score += eax
    cmp %ebx, best_score(%ebp)
    jbe select_mask_inc # best score <= score

    mov %ebx, best_score(%ebp)  # best score = score
    mov mask(%ebp), %al
    mov %al, best_mask(%ebp)    # best mask = mask
select_mask_inc:
    call apply_mask # revert mask
    incb mask(%ebp) # mask++
    cmpb $8, mask(%ebp)
    jne select_mask_loop    # mask != 8

    mov best_mask(%ebp), %al
    mov %al, mask(%ebp) # mask = best mask
    call apply_mask

add_format_info:
    movzb best_mask(%ebp), %eax
    movzw format_info(,%eax, 2), %esi   # format = format_info[mask]
    call write_format_info
    movb $0x81, bitmap+177*(177-8)+8    # place dark module
add_version_info:
    mov $0x28c69, %ebx
    call write_version_info

    cmpb $0, output_type(%ebp)
    jne png             # output_type != 0

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
    call write_stdout
    inc %esi
    cmp $177, %esi
    jne print_x
    mov $new_line, %ecx
    mov $new_line_len, %edx
    call write_stdout
    inc %edi
    cmp $177, %edi
    jne print_y
    call print_quiet
    jmp exit0

png:
    mov %esp, %ebp
    sub $16, %esp
    mov $png_header, %ecx
    mov $png_header_len, %edx
    call write_stdout

    mov $png_idat, %esi
    mov $chunk_header+4, %edi
    mov $png_idat_len, %ecx
    rep movsb                   # move precomputed header

    dec %edi                    # compensate for incomplete byte
    mov %edi, byte_ptr(%ebp)
    movb $7, bit_position(%ebp) # bit position = 7

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
    movl $1, adler32_a(%ebp)    # a = 1
    movl $0, adler32_b(%ebp)    # b = 1
    call png_adler32_quiet_full
    xor %edi, %edi
png_compute_adler32_y:
    mov $8, %ecx
png_compute_adler32_repeat:
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
    jne png_compute_adler32_x   # x != 177
    call png_adler32_quiet
    dec %ecx
    jnz png_compute_adler32_repeat
    inc %edi
    cmp $177, %edi
    jne png_compute_adler32_y

    call png_adler32_quiet_full
png_compute_adler32_finish:
    mov adler32_a(%ebp), %eax   # eax = a
    mov adler32_b(%ebp), %ebx   # ebx = b
    sal $16, %ebx
    or %eax, %ebx
    bswap %ebx              # ebx = adler in big endian
    mov byte_ptr(%ebp), %edi    # edi = byte ptr
    cmpb $1, bit_position(%ebp)
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
    call write_stdout       # write idat chunk




png_write_iend:
    mov $png_iend, %ecx
    mov $png_iend_len, %edx
    call write_stdout


exit0:
    xor %ebx, %ebx          # exit(0)
    # ebx: exit code
exit:
    mov $SYS_exit, %eax
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

    # Input:
    # ebx: offset
    # ecx: size
    # edx: pattern
    # Local:
    # esi: x
    # edi: y
write_pattern:
    push %edx
    xor %edi, %edi      # y = 0
write_pattern_y:
    xor %esi, %esi      # x = 0
write_pattern_x:
    mov (%edx, %esi), %al   # al = pattern[x]
    mov %al, bitmap(%ebx, %esi) # bitmap[offset+x] = al
    inc %esi            # x++
    cmp %ecx, %esi
    jne write_pattern_x # x != size
    add %ecx, %edx      # pattern += size
    add $177, %ebx      # offset += 177
    inc %edi            # y++
    cmp %ecx, %edi
    jne write_pattern_y # y != size
    pop %edx
    ret

    # Input:
    # eax: offset
    # Local:
    # esi: end
    # edi: i
write_seperator:
    lea 177*8(%eax), %esi   # end = offset + 177*8
write_seperator_y:
    xor %edi, %edi      # i = 0
write_seperator_x:
    movb $-0x80, bitmap(%eax, %edi) # bitmap[offset+i] = 0x80
    inc %edi            # i++
    cmp $8, %edi
    jne write_seperator_x   # i != 8
    add $177, %eax      # offset += 177
    cmp %eax, %esi
    jne write_seperator_y
    ret

    # Input:
    # esi: x
    # edi: y
    # Local:
    # ebx: offset
    # ecx: size
    # edx: pattern
write_one_alignment_pattern:
    push %esi
    push %edi
    push %ecx
    push %edx
    push %eax
    mov $5, %ecx        # size = 5
    mov $alignment_pattern, %edx    # pattern = alignment_pattern
    imul $177, %edi, %ebx   # offset = 177*y
    add %esi, %ebx      # offset += x
    call write_pattern
    pop %eax
    pop %edx
    pop %ecx
    pop %edi
    pop %esi
    ret

    # Input:
    # esi: format
    # Local:
    # eax: i
    # ecx: bitmap
    # edx: v
    # esi: format
write_format_info:
    xor %eax, %eax      # i = 0
    mov $bitmap, %ecx   # ecx = bitmap
write_format_info_loop:
    mov %esi, %edx      # v = format
    and $1, %edx        # v &= 1
    add $-0x80, %edx    # v += 0x80
    cmp $7, %eax
    ja write_format_info_above_7    # i > 7
    mov $177*8+177-1, %edi
    sub %eax, %edi      # edi -= i
    mov %dl, (%ecx, %edi)   # bitmap[177*8+177-1-i] = v
    lea 1(%eax), %edi   # edi = i + 1
    cmp $5, %eax
    cmovbe %eax, %edi   # edi = i <= 5 ? i : i+1
    imul $177, %edi, %edi   # edi *= 177
    add $8, %edi        # edi += 8
    jmp write_format_info_inc
write_format_info_above_7:
    imul $177, %eax, %edi   # edi = i * 177
    mov %dl, 177*(177-15)+8(%ecx, %edi) # bitmap[177*(177-15+i)+8] = v
    mov $177*8+14, %edi
    sub %eax, %edi      # edi = 177*8+14-i
    mov $177*8+7, %ebx
    cmp $8, %eax
    cmove %ebx, %edi
write_format_info_inc:
    mov %dl, (%ecx, %edi)   # bitmap[edi] = v
    inc %eax            # i++
    shrl %esi           # format >>= 1
    cmp $15, %eax
    jne write_format_info_loop
    ret

    # Input:
    # ebx: version
    # Local:
    # eax: p
    # ecx: v
    # edx: temp
    # esi: x
    # edi: y
write_version_info:
    mov %ebx, %ecx      # v = version
    xor %esi, %esi      # x = 0
write_version_info_1_x:
    xor %edi, %edi      # y = 0
    lea bitmap+177*(177-11)(%esi), %eax # p = bitmap + 177*(177-11) + x
write_version_info_1_y:
    mov %ecx, %edx      # edx = v
    and $1, %edx        # edx &= 1
    or $-0x80, %edx     # dl = 0x80 | (v&1)
    mov %dl, (%eax)     # *p = 0x80 | (v&1)
    shrl %ecx           # v >>= 1
    inc %edi            # y++
    add $177, %eax      # p += 177
    cmp $3, %edi
    jne write_version_info_1_y  # y != 3
    inc %esi            # x++
    cmp $6, %esi
    jne write_version_info_1_x  # x != 6

    mov $bitmap+177-11, %eax    # p = bitmap + 177-11
    xor %edi, %edi      # y = 0
write_version_info_2_y:
    xor %esi, %esi      # x = 0
write_version_info_2_x:
    mov %ebx, %edx      # edx = version
    and $1, %edx        # edx &= 1
    or $-0x80, %edx     # dl = 0x80 | (v&1)
    mov %dl, (%eax, %esi)   # p[x] = 0x80 | (v&1)
    shrl %ebx           # version >>= 1
    inc %esi            # x++
    cmp $3, %esi
    jne write_version_info_2_x  # x != 3
    add $177, %eax      # p += 177
    inc %edi            # y++
    cmp $6, %edi
    jne write_version_info_2_y  # y != 6
    ret

    # Input:
    # mask(ebp): mask
    # Local:
    # esi: j (x)
    # edi: i (y)
    # ebx: i*j
    # ecx: v
apply_mask:
    movl $bitmap, apply_mask_p(%ebp)    # p = bitmap
    xor %edi, %edi      # i = 0
apply_mask_i:
    xor %esi, %esi      # j = 0
    mov %edi, apply_mask_i_plus_j(%ebp) # i+j = i
    xor %ebx, %ebx      # i*j = 0
apply_mask_j:
    mov apply_mask_p(%ebp), %eax
    mov (%eax), %cl
    test %cl, %cl
    js apply_mask_inc
    movzb mask(%ebp), %eax
    jmp *apply_mask_jump_table(,%eax, 4)
apply_mask_jump_table:
    .long apply_mask_0
    .long apply_mask_1
    .long apply_mask_2
    .long apply_mask_3
    .long apply_mask_4
    .long apply_mask_5
    .long apply_mask_6
    .long apply_mask_7
apply_mask_0:
    mov apply_mask_i_plus_j(%ebp), %ecx # v = i+j
    jmp apply_mask_v_mod_2_eql_0
apply_mask_1:
    mov %edi, %ecx  # v = i
    jmp apply_mask_v_mod_2_eql_0
apply_mask_2:
    mov %esi, %eax      # eax = j
    jmp apply_mask_mod_3_eql_0
apply_mask_3:
    mov apply_mask_i_plus_j(%ebp), %eax # eax = i+j
apply_mask_mod_3_eql_0:
    xor %edx, %edx
    mov $3, %ecx
    div %ecx    # edx = eax % 3
    test %edx, %edx
    jmp apply_mask_zf
apply_mask_4:
    xor %edx, %edx
    mov %esi, %eax
    mov $3, %ecx
    div %ecx        # eax = j / 3
    mov %edi, %ecx
    shrl %ecx       # v = i/2
    add %eax, %ecx  # v += j/3
    jmp apply_mask_v_mod_2_eql_0
apply_mask_5:
    xor %edx, %edx
    mov %ebx, %eax
    mov $3, %ecx
    div %ecx        # edx = i*j % 3
    mov %ebx, %ecx
    and $1, %ecx
    add %ecx, %edx
apply_mask_zf:
    setz %cl    # v = zero flag
    jmp apply_mask_mask
apply_mask_6:
    xor %edx, %edx
    mov %ebx, %eax
    mov $3, %ecx
    div %ecx        # edx = i*j % 3
    lea (%edx, %ebx), %ecx  # v = (i*j) % 3 + i*j
    jmp apply_mask_v_mod_2_eql_0
apply_mask_7:
    mov $3, %ecx
    xor %edx, %edx
    mov %ebx, %eax
    div %ecx        # edx = i*j % 3
    add apply_mask_i_plus_j(%ebp), %edx
    mov %edx, %ecx  # v = i*j % 3 + i+j
apply_mask_v_mod_2_eql_0:
    not %ecx
    and $1, %ecx    # v = v % 2 == 0
apply_mask_mask:
    mov apply_mask_p(%ebp), %eax
    xor (%eax), %cl
    mov %cl, (%eax)
apply_mask_inc:
    incl apply_mask_p(%ebp) # p++
    incl apply_mask_i_plus_j(%ebp)  # i+j += 1
    add %edi, %ebx      # i*j += i
    inc %esi            # j++
    cmp $177, %esi
    jne apply_mask_j
    inc %edi            # i++
    cmp $177, %edi
    jne apply_mask_i
    ret

    # Input:
    # eax: stride
    # ecx: *bitmap
    # Local:
    # (esp): stride
    # ebx: run_length_idx
    # eax: prev
    # edx: count
    # ecx: *bitmap
    # esi: i
compute_run_length:
    push %ebx
    push %eax

    xor %ebx, %ebx      # run_lenght_idx = 0
    xor %eax, %eax      # prev = 0
    xor %edx, %edx      # count = 0
    mov $177, %esi      # i = 177
compute_run_length_loop:
    xor (%ecx), %al
    and $1, %al
    jz compute_run_length_countpp # ((*bitmap ^ prev) & 1) == 0
    mov %dl, run_length(%ebx)   # run_length[run_length_idx] = count
    inc %ebx            # run_length_idx++
    mov $1, %edx        # count = 1
    jmp compute_run_length_inc
compute_run_length_countpp:
    inc %edx            # count++
compute_run_length_inc:
    mov (%ecx), %al     # prev = *bitmap
    add (%esp), %ecx    # bitmap += stride
    dec %esi            # i--
    jnz compute_run_length_loop # i != 0
    mov %dl, run_length(%ebx)   # run_length[run_length_idx] = count
    inc %ebx            # run_length_idx++
    mov %ebx, run_length_len    #run_length_len = run_length_idx

    pop %eax
    pop %ebx
    ret

    # ebx: score
    # eax: run_length_len
    # edx: i
    # Preserves: edi
compute_n1n3:
    push %edi
    xor %edx, %edx      # i = 0
    mov run_length_len, %eax
compute_n1n3_loop:
    cmp %eax, %edx
    je compute_n1n3_ret # i == run_length_len
    movzb run_length(%edx), %ecx    # ecx = run_length[i]
    lea -2(%ebx, %ecx), %esi    # esi = score + run_length[i] - 2
    cmp $5, %cl
    cmovae %esi, %ebx   # score = run_length[i] >= 5 ? score + run_length[i] - 2 : score
    test $1, %dl
    jz compute_n1n3_inc # (i & 1) == 0
    lea 4(%edx), %esi   # esi = i + 4
    cmp %eax, %esi
    jae compute_n1n3_inc    # i+4 >= run_lenght_len
    cmp run_length+1(%ebx), %cl
    jne compute_n1n3_inc    # run_length[i+1] != run_length[i]
    movzb run_length+2(%ebx), %edi  # esi = run_length[i+2]
    lea (%ecx, %ecx, 2), %edi   # edi = run_length[i] * 3
    cmp %esi, %edi
    jne compute_n1n3_inc    # run_length[i+2] != 3 * run_length[i]
    cmp run_length+3(%edx), %cl
    jne compute_n1n3_inc    # run_length[i+3] != run_length[i]
    cmp run_length+4(%edx), %cl
    jne compute_n1n3_inc    # run_length[i+3] != run_length[i]
    movzb run_length-1(%ebx), %edi  # edi = run_length[i-1]
    sal $2, %ecx            # ecx <<= 2
    cmp %ecx, %esi
    je compute_n1n3_add40   # run_length[i-1] == 4 * run_length[i]
    lea 5(%edx), %esi   # esi = i + 5
    cmp %eax, %esi
    jae compute_n1n3_inc    # i + 5 >= run_length_len
    movzb run_length+5(%edx), %esi
    cmp %ecx, %esi
    jne compute_n1n3_inc    # 4 * run_length[i] != run_length[i+5]
compute_n1n3_add40:
    add $40, %ebx       # score += 40
compute_n1n3_inc:
    inc %edx            # i++
    jmp compute_n1n3_loop
compute_n1n3_ret:
    pop %edi
    ret

    # eax: bits, edx: number of bits
    # byte_ptr(ebp): byte ptr
    # bit_position(ebp): bit position
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
    mov byte_ptr(%ebp), %ebx
    mov (%ebx), %bl     # bl = *byte ptr
    mov bit_position(%ebp), %ecx    # ecx: bit position
    sal %cl, %esi
    btr %ecx, %ebx
    or %esi, %ebx
    mov byte_ptr(%ebp), %esi
    mov %bl, (%esi)     # *byte ptr = *byte ptr with bit %cl equal %esi
    cmp $7, %cl
    jne bitstring_put_default_inc
    incl byte_ptr(%ebp) # byte ptr++
    movl $0, bit_position(%ebp) # bit position = 0
    jmp bitstring_put_loop
bitstring_put_default_inc:
    incl bit_position(%ebp) # bit position++
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

    # dl: new byte
    # adler32_a(ebp): a
    # adler32_b(ebp): b
update_adler32:
    push %ecx
    movzb %dl, %edx
    mov $65521, %ecx
    mov adler32_a(%ebp), %eax   # eax = a
    add %edx, %eax
    xor %edx, %edx
    div %ecx
    mov %edx, adler32_a(%ebp)   # a = (a + new byte) % 65521
    mov adler32_b(%ebp), %ebx   # ebx = b
    lea (%edx,%ebx), %eax   # eax = a + b
    xor %edx, %edx
    div %ecx
    mov %edx, adler32_b(%ebp)   # b = (a + b) % 65521
    pop %ecx
    ret

png_adler32_quiet_full:
    mov $32, %ecx
png_adler32_quiet_full_y:
    xor %edx, %edx
    call update_adler32     # 0x00
    mov $185, %esi
png_adler32_quiet_full_x:
    mov $0xff, %dl
    call update_adler32     # 0xFF * 185
    dec %esi
    jnz png_adler32_quiet_full_x
    dec %ecx
    jnz png_adler32_quiet_full_y
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
    call write_stdout
    dec %esi
    jnz print_quiet_loop
    ret

print_cannot_open_file:
    mov $cannot_open_file, %ecx
    mov $cannot_open_file_len, %edx
    call write_stderr       # write to stderr
    mov $1, %ebx
    jmp exit                # exit(1)

print_cannot_read_file:
    mov $cannot_read_file, %ecx
    mov $cannot_read_file_len, %edx
    call write_stderr       # write to stderr
    mov $1, %ebx
    jmp exit                # exit(1)

print_help:
    mov $help, %ecx
    mov $help_len, %edx
    call write_stdout
    jmp exit0

    # eax: string 1, ebx: string 2
    # eax: return value
str_cmp:
    # ecx: i
    push %ecx
    push %edx
    xor %ecx, %ecx          # i = 0
str_cmp_loop:
    mov (%eax, %ecx), %dl   # dl = string 1[i]
    cmp (%ebx, %ecx), %dl
    jne str_cmp_ret0        # dl != string 2[i]
    inc %ecx                # i++
    test %dl, %dl
    jnz str_cmp_loop        # dl != 0
    mov $1, %eax
    pop %edx
    pop %ecx
    ret                     # return 1
str_cmp_ret0:
    xor %eax, %eax
    pop %edx
    pop %ecx
    ret                     # return 0

    # ecx: data, edx: data length
write_stderr:
    mov $STDERR_FILENO, %ebx
    jmp write

    # ecx: data, edx: data length
write_stdout:
    mov $STDOUT_FILENO, %ebx
write:
    mov $SYS_write, %eax
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

help:
    .ascii "Usage: ./qr [OPTIONS] [FILE]\n"
    .ascii "Encode FILE as an QR Code.\n"
    .ascii "\n"
    .ascii "Without FILE the program encodes itself.\n"
    .ascii "Output is always standard output.\n"
    .ascii "\n"
    .ascii "      --png   Output QR Code as PNG image\n"
    .ascii "      --help  Display help and exit\n"
    help_len = . - help

cannot_open_file:
    .ascii "Cannot open file.\n"
    cannot_open_file_len = . - cannot_open_file
cannot_read_file:
    .ascii "Cannot read file.\n"
    cannot_read_file_len = . - cannot_read_file

flag_help:
    .asciz "--help"
flag_png:
    .asciz "--png"

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
    .byte 0xed,0xd0,0x31,0x0d,0xc0,0x40,0x10,0xc4,0xc0,0xe1,0x4f,0xda,0x69,0x8f,0xc0,0x17,0x91,0xd6,0x08,0x46,0xd6,0x5f,0x9b,0x7c,0xf2,0xc9,0x27,0x9f,0x7c,0xf2,0xc9,0x27,0x9f,0x7c,0xf2,0xc9,0x27,0x9f,0x7c,0xf2,0xc9,0x27,0x9f,0x7c,0xf2,0xc9,0x27,0x9f,0x7c,0xf2,0x77,0x72 # bit position = 7, bit length = 415
    png_idat_len = . - png_idat

png_scanline_end:
    .byte 0x55,0x93,0x4f,0x3e,0xf9,0xe4,0x93,0x5f,0x39 # bit position = 6, bit length = 70
    png_scanline_end_bit_len = 70
png_quiet_end:
    .byte 0xfa,0x6b,0x93,0x4f,0x3e,0xf9,0xe4,0x93,0x4f,0x3e,0xf9,0xe4,0x93,0x4f,0x3e,0xf9,0xe4,0x93,0x4f,0x3e,0xf9,0xe4,0x93,0x4f,0x3e,0xf9,0xe4,0x93,0x4f,0xfe,0x4e,0xfe,0x01 # bit position = 2, bit length = 258
    png_quiet_end_bit_len = 258

finder_pattern:
    .byte 0x81, 0x81, 0x81, 0x81, 0x81, 0x81, 0x81
    .byte 0x81, 0x80, 0x80, 0x80, 0x80, 0x80, 0x81
    .byte 0x81, 0x80, 0x81, 0x81, 0x81, 0x80, 0x81
    .byte 0x81, 0x80, 0x81, 0x81, 0x81, 0x80, 0x81
    .byte 0x81, 0x80, 0x81, 0x81, 0x81, 0x80, 0x81
    .byte 0x81, 0x80, 0x80, 0x80, 0x80, 0x80, 0x81
    .byte 0x81, 0x81, 0x81, 0x81, 0x81, 0x81, 0x81

alignment_pattern:
    .byte 0x81, 0x81, 0x81, 0x81, 0x81
    .byte 0x81, 0x80, 0x80, 0x80, 0x81
    .byte 0x81, 0x80, 0x81, 0x80, 0x81
    .byte 0x81, 0x80, 0x80, 0x80, 0x81
    .byte 0x81, 0x81, 0x81, 0x81, 0x81

format_info:
    .short 0x77c4, 0x72f3, 0x7daa, 0x789d, 0x662f, 0x6318, 0x6c41, 0x6976

generator:
    .byte 0xb4,0xc0,0x28,0xee,0xd8,0xfb,0x25,0x9c,0x82,0xe0,0xc1,0xe2,0xad,0x2a,0x7d,0xde,0x60,0xef,0x56,0x6e,0x30,0x32,0xb6,0xb3,0x1f,0xd8,0x98,0x91,0xad,0x29

.section .bss
scratch:
    .skip sizeof_scratch
alpha:
    .skip 256
aindex:
    .skip 256

    .align 4
crc_table:
    .skip 256 * 4

bitmap:
    .skip 177*177

    .align 4
blocks:
    .skip sizeof_block * (19+6)
blocks_end:

    .align 4
run_length_len:
    .skip 4
run_length:
    .skip 178

bitstream:
    .skip 2956
bitstream_end:

input:
codewords:
    .skip 3706
codewords_end:

    .align 4
chunk_header:
    .skip 8
chunk_data:
    .skip 0xa000
