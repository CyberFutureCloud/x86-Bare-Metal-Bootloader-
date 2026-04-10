section .data

gdt_start:
gdt_null: dq 0x0
gdt_code: dq 0x00CF9A000000FFFF
gdt_data: dq 0x00CF92000000FFFF
gdt_64_code: dq 0x00209A00000000
gdt_end:

gdt_descriptor:
	dw gdt_end - gdt_start - 1
	dd gdt_start
	
CODE_SEL equ 0x08
DATA_SEL equ 0x10
LONG_CODE_SEL_SEL equ 0x18

section .text
global _start

[bits 16]
[org 07C00]

_start:
	
	mov ah, 0x0E
	mov al, 'A'
	int 0x10
	
	lgdt [gdt_descriptor]
	
	mov eax, cr0
	or eax, 1 
	mov cr0, eax
	
	jmp CODE_SEL:protected_mode_start
	
[bits 32]
protected_mode_start:
	mov ax, DATA_SEL
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov esp, stack_bottom + 4096
	mov eax, cr4 
	
	or eax, 0x20 
	mov cr4, eax
	mov ecx, 0xC0000080
	rdmsr 
	or eax, 0x100 
	wrmsr 
	
	mov eax, pdpt
	or eax, 3
	mov [pml4], eax
	
	mov eax, pd 
	or eax, 3 
	mov [pdpt], eax
	
	mov ecx, 0 
	xor edx, edx
	1:
	mov eax, ecx
	shl eax, 21
	or eax, 3
	mov [pd+ecx*8], eax
	mov [pd + ecx*8 + 4], edx
	inc ecx
	cmp ecx, 512
	jl 1b
	
	mov eax, pml4 
	mov cr3, eax
	mov eax, cr0 
	or eax, 1 
	or eax, 0x80000000
	mov cr0, eax
	
	jmp LONG_CODE_SEL_SEL:long_mode_start
	
[bits 64]
long_mode_start:
	mov rsp, stack_bottom + 8192
	mov rdi, 0xB8000
	mov al, 'k'
	mov byte [rdi], al
	mov byte [rdi + 1], 0x07
	
	
section .bss

align 4096
pml4: resq 512
pdpt: resq 512
pd: resq 512
stack_bottom: resb 8192
stack_top:
