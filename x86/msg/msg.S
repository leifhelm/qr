bits 32
section .text progbits

elf_start:
    org 0x8000000               ; Place elf header at page boundary
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

ph:
    dd 0x01                     ; program header count (lower 2 bytes) and type (LOAD)
    dd load_start-elf_start     ; offset
    dd load_start               ; virtual address
    dd load_start               ; physical address
    dd load_end-load_start      ; size in file
    dd bss_end-load_start       ; size in memory
    dd 0x7                      ; flags (R-X)
    dd 0x1                      ; align



load_start:
entry:
    lea ecx, [msg]              ; Load address of msg
    xor dword [ecx + 0x00], 0x5414070e ; Decrypt
    xor dword [ecx + 0x04], 0x550a1141 ; Decrypt
    xor dword [ecx + 0x08], 0x1241010e ; Decrypt
    xor dword [ecx + 0x0c], 0x0711491b ; Decrypt
    xor dword [ecx + 0x10], 0x466d4f03 ; Decrypt
    add ebx, 1                  ; ebx = 1 (STDOUT_FILENO)
    add eax, 4                  ; eax = 4 (SYS_WRITE)
    add edx, 19                 ; edx = 19 (length of msg)
    int 0x80                    ; write(STDOUT_FILENO, msg, 19) syscall
    sub eax, 18                 ; eax = SYS_EXIT (18)
    xor ebx, ebx                ; ebx = 0
    int 0x80                    ; exit(0) syscall

msg:
    db "What could go wrong?"

load_end:
bss_end:
