;;==============================================================================
;; AP startup | @file /asm/tsl_ap.asm
;;=============================================================================
;; AP's will start execution at TSL_BASE_ADDRESS and fall through to this code.
;;=============================================================================


%include "./asm/include/sysvar.inc"


global bootmode_branch


;; 1 pagina reservada en 0x8000 para booteo en 16 bits de los ap. Terminado ese
;; codigo, se salta a 0x800000.


section .text


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;BITS 16

ap_startup:
	cli
	xor eax, eax
	xor ebx, ebx
	xor ecx, ecx
	xor edx, edx
	xor esi, esi
	xor edi, edi
	xor ebp, ebp
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax
	mov esp, 0x7000


; =============================================================================
; INIT SMP AP
; =============================================================================

;; sysvar.asm
;;extern GDTR32
extern GDTR64
extern SYS64_CODE_SEL
extern IDTR64

;; cpu.asm
extern init_cpu
;; tsl.asm
extern start64

BITS 16

init_smp_ap:

	; Check boot method of BSP
	cmp byte [p_BootMode], 'U'
	je skip_a20_ap			; If UEFI, then skip A20 code

	; Enable the A20 gate
set_A20_ap:
	in al, 0x64
	test al, 0x02
	jnz set_A20_ap
	mov al, 0xD1
	out 0x64, al
check_A20_ap:
	in al, 0x64
	test al, 0x02
	jnz check_A20_ap
	mov al, 0xDF
	out 0x60, al
skip_a20_ap:

	; At this point we are done with real mode and BIOS interrupts. Jump to 32-bit mode.
	lgdt [cs:GDTR32]		; Load GDT register

	mov eax, cr0 			; Switch to 32-bit protected mode
	or al, 1
	mov cr0, eax

	jmp 8:startap32

align 16


; =============================================================================
; 32-bit mode
BITS 32

startap32:
	mov eax, 16			; Load 4 GB data descriptor
	mov ds, ax			; to all data segment registers
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax
	xor eax, eax
	xor ebx, ebx
	xor ecx, ecx
	xor edx, edx
	xor esi, esi
	xor edi, edi
	xor ebp, ebp
	mov esp, 0x7000			; Set a known free location for the temporary stack (shared by all APs)

	; Load the GDT
	lgdt [GDTR64]

	; Enable extended properties
	mov eax, cr4
	or eax, 0x0000000B0		; PGE (Bit 7), PAE (Bit 5), and PSE (Bit 4)
	mov cr4, eax

	; Point cr3 at PML4
	mov eax, 0x00002008		; Write-thru (Bit 3)
	mov cr3, eax

	; Enable long mode and SYSCALL/SYSRET
	mov ecx, 0xC0000080		; EFER MSR number
	rdmsr				; Read EFER
	or eax, 0x00000101 		; LME (Bit 8)
	wrmsr				; Write EFER

	; Enable paging to activate long mode
	mov eax, cr0
	or eax, 0x80000000		; PG (Bit 31)
	mov cr0, eax

	; Make the jump directly from 16-bit real mode to 64-bit long mode
	jmp SYS64_CODE_SEL:startap64

align 16


; =============================================================================
; 64-bit mode
BITS 64

startap64:
	xor eax, eax
	xor ebx, ebx
	xor ecx, ecx
	xor edx, edx
	xor esi, esi
	xor edi, edi
	xor ebp, ebp
	xor esp, esp
	xor r8, r8
	xor r9, r9
	xor r10, r10
	xor r11, r11
	xor r12, r12
	xor r13, r13
	xor r14, r14
	xor r15, r15

	mov ax, 0x10		; TODO Is this needed?
	mov ds, ax			; Clear the legacy segment registers
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax

	;; Reset the stack. Each CPU gets a 1024-byte unique stack location.
	mov rsi, [p_LocalAPICAddress]	;; We would call p_smp_get_id here but stack
									;; is not yet defined. It is safer to find t
									;; he value directly.
	add rsi, 0x20
	lodsd				;; Load a 32-bit value. We only want the high 8 bits.
	shr rax, 24			;; al = CPU APIC ID.
	shl rax, 10			;; Shift left 10 bits for a 1024 byte stack.
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;add rax, 0x00090000
	add rax, 0x00050000
	mov rsp, rax		;; 0x50000 - 0x9FFFF free so we use that

	lgdt [GDTR64]		;; Load the GDT
	lidt [IDTR64]		;; Load the IDT

	call init_cpu		;; Setup CPU

	sti					;; Activate interrupts for SMP
	jmp ap_sleep

align 16

ap_sleep:
	hlt				; Suspend CPU until an interrupt is received. opcode for hlt is 0xF4
	jmp ap_sleep			; just-in-case of an NMI


;;==============================================================================
;; 32-bit code. Instructions must also be 64 bit compatible. If a 'U' is stored 
;; at 0x5FFF then we know it was a UEFI boot and immediately proceed to start64.
;; Otherwise we need to set up a minimal 64-bit environment.

BITS 32

bootmode_branch:
	cmp bl, 'U'	;; If uefi boot then already in 64 bit mode.
	je start64

%ifdef BIOS
%include "./asm/bios/bios_32_64.asm"
%endif


;;==============================================================================
;; System Variables | @file /asm/sysvar.asm
;;==============================================================================


section .data


align 16
GDTR32:										;; Global Descriptors Table Register
				dw gdt32_end - gdt32 - 1	;; Limit.
				dq gdt32					;; Linear address of GDT

align 16
gdt32:
SYS32_NULL_SEL:	equ $ - gdt32			;; Null Segment
				dq 0x0000000000000000
SYS32_CODE_SEL:	equ $ - gdt32			;; 32-bit code descriptor
				dq 0x00CF9A000000FFFF	;; 55 Granularity 4KiB, 54 Size 32bit, 4
										;; 7 Present, 44 Code/Data, 43 Executabl
										;; e, 41 Readable.
SYS32_DATA_SEL:	equ $ - gdt32			;; 32-bit data descriptor		
				dq 0x00CF92000000FFFF	;; 55 Granularity 4KiB, 54 Size 32bit, 4
										;; 7 Present, 44 Code/Data, 41 Writeable
gdt32_end:
