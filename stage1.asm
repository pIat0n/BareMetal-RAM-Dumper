; stage1.asm
BITS 16
ORG 0x7C00

start:
    cli
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0x7C00
    mov [boot_drive], dl

    mov si, dap
    mov ah, 0x42
    mov dl, [boot_drive]
    int 0x13
    jc  hang

    jmp 0x0000:0x8000

hang:
    cli
    hlt

boot_drive: db 0

dap:
    db 0x10
    db 0
    dw 15
    dw 0x8000
    dw 0x0000
    dq 1

times 510-($-$$) db 0
dw 0xAA55