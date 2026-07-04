; stage2.asm

BITS 16
ORG 0x8000

start16:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax

    mov ax, 0x7000
    mov ss, ax
    mov sp, 0xFFFF

    mov [boot_drv], dl

    mov ax, 0x0003
    int 0x10

    mov si, msg_start
    call print_string

    in  al, 0x92
    or  al, 0x02
    out 0x92, al

    mov si, msg_edd
    call print_string

    mov ah, 0x41
    mov bx, 0x55AA
    mov dl, [boot_drv]
    int 0x13
    jc no_edd
    cmp bx, 0xAA55
    jne no_edd

    mov si, msg_ok
    call print_string

    call load_e820

    call calc_ram_size

    lgdt [gdt_desc]

    mov dword [src_ptr], 0
    mov dword [lba_lo], 64
    mov dword [lba_hi], 0

    mov dword [chunks], 131072
    mov dword [total_chunks], 131072

.dump_loop:
    mov esi, [src_ptr]
    call is_valid_ram

    pushf 

    cli
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    mov ax, 0x10
    mov ds, ax
    mov es, ax

    mov eax, cr0
    and eax, 0xFFFFFFFE
    mov cr0, eax

    popf
    jc .is_ram

    mov edi, 0x90000
    mov ecx, 8192
    xor eax, eax
    a32 rep stosd
    jmp .write_disk

.is_ram:
    mov esi, [src_ptr]
    mov edi, 0x90000
    mov ecx, 8192
    a32 rep movsd

.write_disk:
    xor ax, ax
    mov ds, ax
    mov es, ax
    sti

    mov word [dap + 2], 64
    mov word [dap_off], 0
    mov word [dap_seg], 0x9000

    mov cx, 3
.retry:
    mov ah, 0x43
    mov al, 0
    mov dl, [boot_drv]
    mov si, dap
    int 0x13
    jnc .ok
    loop .retry
    jmp disk_error

.ok:
    mov eax, [chunks]
    and eax, 0xFF
    jnz .skip_ui
    call print_progress
.skip_ui:
    add dword [src_ptr], 32768
    add dword [lba_lo], 64
    adc dword [lba_hi], 0

    mov eax, [lba_lo]
    mov [dap_lba_lo], eax
    mov eax, [lba_hi]
    mov [dap_lba_hi], eax

    dec dword [chunks]
    jnz .dump_loop

    call print_progress
    mov si, msg_done
    call print_string

    cli
    hlt

load_e820:
    mov di, 0x0500
    xor ebx, ebx
.e820_loop:
    mov eax, 0xE820
    mov ecx, 24
    mov edx, 0x534D4150
    int 0x15
    jc .e820_done
    cmp eax, 0x534D4150
    jne .e820_done

    add di, 20
    test ebx, ebx
    jnz .e820_loop
.e820_done:
    mov [e820_end], di
    ret

calc_ram_size:
    mov di, 0x0500
    mov dword [ram_top], 0
.cc_loop:
    cmp di, [e820_end]
    jae .cc_done

    mov eax, [di + 16]
    cmp eax, 1
    jne .cc_next

    mov edx, [di + 4]
    test edx, edx
    jnz .cc_next

    mov eax, [di]
    mov ebx, [di + 8]
    add eax, ebx
    jc .cc_next

    cmp eax, [ram_top]
    jbe .cc_next
    mov [ram_top], eax

.cc_next:
    add di, 20
    jmp .cc_loop

.cc_done:
    mov si, msg_ramsize
    call print_string
    mov eax, [ram_top]
    shr eax, 20
    call print_number
    mov si, msg_mb
    call print_string
    ret

is_valid_ram:
    pushad
    mov di, 0x0500
.check_loop:
    cmp di, [e820_end]
    jae .invalid

    mov eax, [di + 16]
    cmp eax, 1
    jne .next_entry

    mov edx, [di + 4]
    test edx, edx
    jnz .next_entry

    mov eax, [di]
    cmp esi, eax
    jb .next_entry

    mov ebx, [di + 8]
    add eax, ebx
    jc .valid_found
    
    mov ecx, esi
    add ecx, 32767
    cmp ecx, eax
    jae .next_entry

.valid_found:
    popad
    stc
    ret

.next_entry:
    add di, 20
    jmp .check_loop

.invalid:
    popad
    clc
    ret

print_progress:
    mov si, msg_progress
    call print_string

    mov eax, [total_chunks]
    sub eax, [chunks]
    xor edx, edx
    mov ebx, 100
    mul ebx
    div dword [total_chunks]

    call print_number

    mov al, '%'
    mov ah, 0x0E
    int 0x10
    ret

print_number:
    push 0
.loop:
    xor edx, edx
    mov ebx, 10
    div ebx
    add dl, '0'
    push dx
    test eax, eax
    jnz .loop
.print_loop:
    pop ax
    test ax, ax
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .print_loop
.done:
    ret

print_string:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print_string
.done:
    ret

no_edd:
    mov si, msg_no_edd
    call print_string
    cli
    hlt

disk_error:
    mov si, msg_err_disk
    call print_string
    cli
    hlt

boot_drv:     db 0
src_ptr:      dd 0
lba_lo:       dd 64
lba_hi:       dd 0
chunks:       dd 0
total_chunks: dd 0
ram_top:      dd 0
e820_end:     dw 0x0500

dap:
    db 0x10
    db 0
    dw 64
dap_off: dw 0
dap_seg: dw 0x9000
dap_lba_lo: dd 64
dap_lba_hi: dd 0

msg_start:    db "RAM DUMP",13,10,0
msg_edd:      db "Checking EDD... ",0
msg_ok:       db "OK!",13,10,0
msg_no_edd:   db "NO EDD!",13,10,0
msg_err_disk: db 13,10,"DISK WRITE ERROR!",13,10,0
msg_progress: db 13,"Progress: ",0
msg_done:     db 13,10,"DUMP COMPLETE!",13,10,0
msg_ramsize:  db "Max Valid RAM detected: ",0
msg_mb:       db " MB",13,10,0

gdt_start:
    dq 0
    dq 0x00CF9A000000FFFF
    dq 0x00CF92000000FFFF
gdt_end:

gdt_desc:
    dw gdt_end - gdt_start - 1
    dd gdt_start

times (15*512)-($-$$) db 0