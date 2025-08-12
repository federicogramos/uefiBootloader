;;==============================================================================
;; ap startup | @file /asm/tsl_ap.asm
;;==============================================================================
;; APs comienzan en TSL_BASE_ADDRESS y luego vienen a este codigo.
;;
;; En memoria, hay 1KiB reservado en 0x8000 para booteo en 16 bits de los ap. Te
;; rminado ese codigo, se salta a 0x800000 (el bsp, no los ap, los cuales se que
;; dan aqui).
;;
;; Nota de gdb y el booteo de aps. Cuando un ap arranaca, lo hara en 0x8000. Gdb
;; muestra el codigo de 64 bits. El address que el procesador ejecuta se muestra
;; como 0x0000 pero es un tema** de visualizacion de gdb, porque el que esta eje
;; cutando es 0x8000 y en modo i8086. Como esta en modo real, y sipi indica vv =
;; 08 entonces cs:ip = 0800:0000 lo cual se verifica en gdb. Y esto en modo real
;; es 8 * 2^4 + 0 = 0x8000. Si se agarra el dump de memoria de 0x8000 y desensam
;; bla para i8086, vamos simplemente a ver el codigo de aqui, pero no coincide c
;; on la visualizacion de gdb, que es para x64.
;;
;; ** no lo llamaria error, dado que el target le indica i386:x86-64 a gdb y no 
;; se puede hacer set architecture porque al menos en gdb-9.2 el comando toma "e
;; l mas featureful" de los sets cuando son compatibles, y eso implica que nunca
;; se va a poder hacer set architecture i8086 mientras se encuentra en x64 y el 
;; target (qemu) se lo indica.
;;==============================================================================

;; TODO: add elf so to specify BITS16 / 32 and qemu x32_64 be able to show i386
;; disas correctly.
;; https://gitlab.com/qemu-project/qemu/-/issues/141
;; https://sourceware.org/bugzilla/show_bug.cgi?id=22869

%include "./asm/include/sysvar.inc"


global bootmode_branch

;; sysvar.asm
extern GDTR64
extern SYS64_CODE_SEL
extern IDTR64

;; cpu.asm
extern init_cpu

;; tsl.asm
extern start64


section .text


;;=============================================================================
;;
;;=============================================================================

BITS 16

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
	jmp 0x0000:init_smp_ap	;; Asi ya cambio el cs.


;;==============================================================================
;; INIT SMP AP
;;==============================================================================

BITS 16

init_smp_ap:
	;; Check boot method of BSP.
	cmp byte [p_BootMode], 'U'
	je skip_a20_ap				;; If UEFI, then skip A20 code.

;; Enable the A20 gate.
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

;; Done with real mode and BIOS interrupts. Jump to 32-bit mode.
skip_a20_ap:
	;;mov ax, [GDTR32] 
	;;mov ax, [cs:GDTR32] 
	;;mov eax, [GDTR32] 
	;;mov eax, [cs:GDTR32] 
	lgdt [cs:GDTR32]

	mov eax, cr0		;; Protected mode.
	or al, 1
	mov cr0, eax

	;;mov eax, startap32
	jmp 8:startap32
	;;jmp eax


;;==============================================================================
;; 32-bit mode
;;==============================================================================

align 16

BITS 32

startap32:

	mov eax, 16			;; 4 GB data descriptor.
	mov ds, ax			;; To data segment registers.
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
	mov esp, 0x7000		;; Set a known free location for the temporary stack (sh
						;; ared by all APs)

	lgdt [GDTR64]

	mov eax, cr4
	or eax, 0x0000000B0	;; PGE (Bit 7), PAE (Bit 5), and PSE (Bit 4).
	mov cr4, eax

	mov eax, 0x00002008	;; Write-thru (Bit 3)
	mov cr3, eax		;; cr3 points PML4.

	;; Enable long mode and syscall/sysret.
	mov ecx, 0xC0000080	;; EFER MSR number.
	rdmsr				;; Read EFER.
	or eax, 0x00000101	;; LME (Bit 8).
	wrmsr				;; Write EFER.

	mov eax, cr0
	or eax, 0x80000000	;; Enable paging to activate long mode. PG (Bit 31).
	mov cr0, eax

	jmp SYS64_CODE_SEL:startap64	;; Jump from 16-bit real mode to 64-bit long
									;; mode.


;;==============================================================================
;; 64-bit mode
;;==============================================================================

align 16

BITS 64

startap64:
	xor rax, rax
	xor rbx, rbx
	xor rcx, rcx
	xor rdx, rdx
	xor rsi, rsi
	xor rdi, rdi
	xor rbp, rbp
	xor rsp, rsp
	xor r8, r8
	xor r9, r9
	xor r10, r10
	xor r11, r11
	xor r12, r12
	xor r13, r13
	xor r14, r14
	xor r15, r15

	mov ax, 0x10	;; TODO: is this needed?
	mov ds, ax		;; Clear the legacy segment registers.
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
	add rax, 0x00050000
	mov rsp, rax		;; 0x50000 - 0x9FFFF free so we use that.

	lgdt [GDTR64]
	lidt [IDTR64]

	call init_cpu		;; Setup CPU.

	sti					;; Interrupts for SMP.
	jmp ap_sleep


;;==============================================================================
;;
;;==============================================================================

align 16

ap_sleep:
	hlt				;; Suspend CPU until an interrupt is received.
	jmp ap_sleep	;; just-in-case of NMI.


;;==============================================================================
;; 32-bit code. Instructions must also be 64 bit compatible. If a 'U' is stored 
;; at 0x5FFF then we know it was a UEFI boot and immediately proceed to start64.
;; Otherwise we need to set up a minimal 64-bit environment.
;;==============================================================================

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

GDTR32:										;; Global Descriptor Table Register.
				dw gdt32_end - gdt32 - 1	;; Size.
				dq gdt32					;; Linear address of GDT.

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
