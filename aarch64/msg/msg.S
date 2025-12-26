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
    .8byte 0x1                      // align

.section .text
load_start:
.global _start
_start:
    mov x8, SYS_write
    mov x0, STDOUT_FILENO     
    adr x1, msg
    mov x2, msg_len
    svc 0
    mov x8, SYS_exit
    mov x0, 0
    svc 0

msg:
    .ascii "Hello, world!\n"
    .equ msg_len, . - msg

load_end:
bss_end:
