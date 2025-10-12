;;==============================================================================
;; Real mode swich to protected mode | @file /asm/bios/start16.asm
;;==============================================================================
;; Para bios boot primero real mode a protected mode. Uefi saltea esta parte, ya
;; bootea en 64. 
;;
;; -- https://wiki.osdev.org/A20_Line
;; https://wiki.osdev.org/Detecting_Memory_(x86)#BIOS_Function:_INT_0x15,_EAX_=_
;; 0xE820
;; https://wiki.osdev.org/Detecting_Memory_(x86)#Getting_an_E820_Memory_Map
;;==============================================================================


%include "./asm/include/sysvar.inc"

;; mbr.asm
extern print_bios
extern diskcpy
extern msg_ok

;; /lib/bios16.asm
extern a20_line
extern e820
extern vesa

;; /lib.bios32.asm
extern load_tsl_hi
extern vesa2uefi
extern config_paging

;; tsl.asm
extern start64

;; tsl_ap.asm
;;extern GDTR32
GDTR32: equ 0x8200

;; tsl.asm
extern tmpGDTR64	;; Only for bios boot. See tsl.asm 1178 TO-DO.
extern SYS64_CODE_SEL


section .text


;;==============================================================================
;; In the following 16 bit code, the processor will to to 32 bit protected mode.
;;==============================================================================

BITS 16

start16:

	call a20_line

	mov si, msg_e820
	call print_bios

	call e820
	call vesa

	cli

	lgdt [cs:GDTR32]
	mov eax, cr0
	or al, 0x01					;; Set protected mode bit.
	mov cr0, eax

start32_jump:
	jmp 0x08:start32			;; To 32-bit code.


;;==============================================================================
;; In the following 32 bit code, the processor will go from protected 32 bit mod
;; e to 64 bit flat mode.
;;==============================================================================

BITS 32

start32:
	mov ax, 0x10				;; Segments.
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax

	xor eax, eax
	xor ebx, ebx
	xor ecx, ecx
	xor edx, edx
	xor esi, esi
	xor edi, edi
	xor ebp, ebp

	mov esp, 0x7000

	call load_tsl_hi
	call vesa2uefi
	call config_paging

	lgdt [tmpGDTR64]

	mov eax, cr4
	or eax, 0x0000000B0			;; PGE (Bit 7), PAE (Bit 5), and PSE (Bit 4).
	mov cr4, eax				;; Enable extended properties.

	mov eax, 0x00202008			;; Write-thru enabled (Bit 3).
	mov cr3, eax				;; Point cr3 at PML4.

	;; Enable long mode and SYSCALL/SYSRET
	mov ecx, 0xC0000080			;; EFER MSR number
	rdmsr						;; Read EFER
	or eax, 0x00000101			;; LME (Bit 8)
	wrmsr						;; Write EFER

en_paging:
	mov eax, cr0
	or eax, 0x80000000			;; PG (bit 31).
	mov cr0, eax

	mov bl, 'B'

start64_jump:
	jmp SYS64_CODE_SEL:start64	;; To 64-bit mode.


;;==============================================================================
;; section .data
;;==============================================================================

;; TO-DO: agregar section data.

msg_e820:			db "Performing e820..", 0


;; Zero fill.
;;;;times 512 - $ + $$	db 0
