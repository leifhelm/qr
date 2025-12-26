.include "../common/constants.S"


.section .elf
elf_start:  
    .byte 0x7f                 
    .ascii "ELF"                // magic
    .byte 0x02                  // class (64-bit)
    .byte 0x01                  // endianness (little)
    .byte 0x01                  // version
    .byte 0x00                  // os abi (System V)
    .byte 0x00                  // abi version
    .skip 7                     // padding
    .2byte 0x02                     // type (EXEC)
    .2byte 0xb7                     // machine (aarch64)
    .4byte 1                        // elf version -- free realestate
    .8byte _start                    // entry
    .8byte ph-elf_start             // program header offset
    .8byte 0                        // section header offset
    .4byte 0                        // flags
    .2byte 0x40                     // elf header size
    .2byte 0x38                     // program header size

ph:
    .4byte 0x01                     // program header count (lower 2 bytes) and type (LOAD)
    .4byte 0x7                      // flags (R-X)
    .8byte load_start-elf_start     // offset
    .8byte load_start               // virtual address
    .8byte load_start               // physical address
    .8byte load_end-load_start      // size in file
    .8byte bss_end-load_start       // size in memory
    .8byte 0x10000                  // align

.section .text
load_start:
.global _start
_start:
    adr x0, msg
    adr x1, key
    mov x2, key_len
    mov x5, 0
loop:
    ldr w3, [x1, x5]
    ldr w4, [x0, x5]
    eor w3, w3, w4
    str w3, [x1, x5]
    add x5, x5, 4
    cmp x5, x2
    blt loop
    mov x8, SYS_write
    mov x0, STDOUT_FILENO     
    svc 0
    mov x8, SYS_exit
    mov x0, 0
    svc 0

key:
    .4byte 0x5414070e
    .4byte 0x550a1141
    .4byte 0x1241010e
    .4byte 0x0711491b
    .4byte 0x466d4f03
    .equ key_len, . - key - 1
msg:
    .ascii "What could go wrong?"
    .equ msg_len, . - msg

load_end:
bss_end:
