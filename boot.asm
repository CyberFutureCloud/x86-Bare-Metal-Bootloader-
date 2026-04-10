; boot.asm - x86 Bare Metal Bootloader
; Transitions: 16-bit Real Mode -> 32-bit Protected Mode -> 64-bit Long Mode

[BITS 16]
[ORG 0x7C00]

; ============================================================
; 16-BIT REAL MODE ENTRY POINT
; ============================================================
start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    ; Print 'A' in 16-bit real mode via BIOS INT 10h
    mov ah, 0x0E
    mov al, 'A'
    xor bh, bh
    int 0x10

    cli

    ; Enable A20 line via fast A20 port 0x92
    in al, 0x92
    or al, 0x02
    out 0x92, al

    ; Load 32-bit GDT and switch to protected mode
    lgdt [gdt32_desc]
    mov eax, cr0
    or eax, 0x1
    mov cr0, eax
    jmp 0x08:pmode32

; ============================================================
; GDT FOR 32-BIT PROTECTED MODE
; ============================================================
gdt32:
    dq 0x0000000000000000    ; Null descriptor
    dq 0x00CF9A000000FFFF    ; Code: base=0, limit=4G, 32-bit, exec/read
    dq 0x00CF92000000FFFF    ; Data: base=0, limit=4G, 32-bit, read/write
gdt32_end:

gdt32_desc:
    dw gdt32_end - gdt32 - 1
    dd gdt32

; ============================================================
; 32-BIT PROTECTED MODE
; ============================================================
[BITS 32]
pmode32:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x9FC00

    ; Clear 3 pages for PML4, PDPT, PD at 0x1000, 0x2000, 0x3000
    ; 3 pages * 4096 bytes / 4 bytes per STOSD = 3072 (0xC00) dwords
    mov edi, 0x1000
    mov ecx, 0xC00
    xor eax, eax
    rep stosd

    ; Identity-map the first 2 MB using 2 MB pages
    mov dword [0x1000], 0x2003   ; PML4[0] -> PDPT @ 0x2000 (P, R/W)
    mov dword [0x1004], 0x0
    mov dword [0x2000], 0x3003   ; PDPT[0] -> PD   @ 0x3000 (P, R/W)
    mov dword [0x2004], 0x0
    mov dword [0x3000], 0x0083   ; PD[0]   -> 0x0, 2 MB page (P, R/W, PS)
    mov dword [0x3004], 0x0

    ; Enable PAE
    mov eax, cr4
    or eax, 0x20
    mov cr4, eax

    ; Load PML4 address into CR3
    mov eax, 0x1000
    mov cr3, eax

    ; Enable Long Mode in EFER MSR (bit 8)
    mov ecx, 0xC0000080
    rdmsr
    or eax, 0x100
    wrmsr

    ; Enable paging to activate Long Mode
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

    ; Load 64-bit GDT and far-jump to Long Mode
    lgdt [gdt64_desc]
    jmp 0x08:lmode64

; ============================================================
; GDT FOR 64-BIT LONG MODE
; ============================================================
gdt64:
    dq 0x0000000000000000    ; Null descriptor
    dq 0x00AF9A000000FFFF    ; Code: 64-bit, exec/read (L bit set)
    dq 0x00CF92000000FFFF    ; Data: read/write
gdt64_end:

gdt64_desc:
    dw gdt64_end - gdt64 - 1
    dd gdt64

; ============================================================
; 64-BIT LONG MODE
; ============================================================
[BITS 64]
lmode64:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Print 'k' to VGA text buffer (white on black, 3rd character)
    ; VGA text mode: 2 bytes per cell (char + attribute); position 2 = byte offset 4
    mov rdi, 0xB8000
    mov byte [rdi + 4], 'k'
    mov byte [rdi + 5], 0x0F

    ; Halt
    cli
    hlt

; Pad to 510 bytes and append the x86 boot signature
times 510 - ($ - $$) db 0
dw 0xAA55
