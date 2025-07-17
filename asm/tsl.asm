;;==============================================================================
;; Transient System Load | @file /asm/tsl.asm
;;=============================================================================
;; Recibe la informacion del sistema. Hace configuraciones basicas del mismo. Co
;; pia el kernel a su ubicacion final. Salta al punto de entrada _start del kern
;; el en 0x100000.
;;=============================================================================


BITS 64

TSL_BASE_ADDRESS equ 0x800000
ORG TSL_BASE_ADDRESS

start:
	jmp bootmode	;; Will be overwritten with 'NOP's before AP's are started.
	nop
	db "UEFIBOOT"	;; Marca para un simple chequeo de que hay payload.
	nop
	nop


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
	jmp 0x0000:init_smp_ap

%include "./asm/init/smp_ap.asm"	;; AP's will start execution at TSL_BASE_ADDRESS and fall through to this code

;;==============================================================================
;; 32-bit code. Instructions must also be 64 bit compatible. If a 'U' is stored 
;; at 0x5FFF then we know it was a UEFI boot and can immediately proceed to star
;; t64. Otherwise we need to set up a minimal 64-bit environment.

BITS 32

bootmode:
	cmp bl, 'U'	;; If uefi boot then already in 64 bit mode.
	je start64

%ifdef BIOS
%include "./asm/bios/bios_32_64.asm"
%endif

BITS 64

start64:

	mov rsp, TSL_BASE_ADDRESS

	;; El cursor quedo en el anterior loader.
	mov rax, [FB]
	mov [print_cursor], rax	;; Inicializar cursor.
	mov rax, 0x00000000
	call memsetFramebuffer	;; Borrar pantalla.


	mov rdi, InfoMap	;; Begins at 0x5000: clr mem for info map and sys vars.
	xor rax, rax
	mov rcx, 960		;; 3840 bytes (Range is 0x5000 - 0x5EFF)
	rep stosd			;; Ciudado: en 0x5F00 hay datos de UEFI/BIOS.

	push rbx
	mov r9, msg_transient_sys_load
	call print
	pop rbx


	;; Sysvars.
	mov [p_BootMode], bl
	mov [p_BootDisk], bh	
	mov ax, 0x03		;; Set flags for legacy ports (in case of no ACPI data)
	mov [p_IAPC_BOOT_ARCH], ax

	mov r9, msg_setup_pic_and_irq
	call print

	;; Mask all PIC interrupts
	mov al, 0xFF
	out 0x21, al
	out 0xA1, al

	; Initialize and remap PIC IRQ's
	; ICW1
	mov al, 0x11;			; Initialize PIC 1, init (bit 4) and ICW4 (bit 0)
	out 0x20, al
	mov al, 0x11;			; Initialize PIC 2, init (bit 4) and ICW4 (bit 0)
	out 0xA0, al
	; ICW2
	mov al, 0x20			; IRQ 0-7: interrupts 20h-27h
	out 0x21, al
	mov al, 0x28			; IRQ 8-15: interrupts 28h-2Fh
	out 0xA1, al
	; ICW3
	mov al, 4
	out 0x21, al
	mov al, 2
	out 0xA1, al
	; ICW4
	mov al, 1
	out 0x21, al
	mov al, 1
	out 0xA1, al

	;; Disable NMIs
	in al, 0x70
	or al, 0x80
	out 0x70, al
	in al, 0x71

	;; Disable PIT
	mov al, 0x30			; Channel 0 (7:6), Access Mode lo/hi (5:4), Mode 0 (3:1), Binary (0)
	out 0x43, al
	mov al, 0x00
	out 0x40, al

	mov r9, msg_ready
	call print

	mov r9, msg_clearing_space_sys_tables
	call print

; Clear out the first 20KiB of memory. This will store the 64-bit IDT, GDT, PML4, PDP Low, and PDP High
	mov ecx, 5120
	xor eax, eax
	mov edi, eax
	rep stosd

; Clear memory for the Page Descriptor Entries (0x10000 - 0x5FFFF)
	mov edi, 0x00010000
	mov ecx, 81920
	rep stosd			; Write 320KiB

	mov r9, msg_ready
	call print


	mov r9, msg_gdt
	call print

	mov esi, gdt64
	mov edi, 0x00001000			;; GDT address.
	mov ecx, gdt64_end - gdt64
	rep movsb					;; Move GDT to final location in memory.

	mov r9, msg_pml4
	call print

;; Complete Page Map Level 4 table (PML4)
;; PML4 is stored at 0x0000000000002000, create the first entry there
;; A single PML4 entry can map 512GiB ----- ver tema paginas 2M 1G
;; A single PML4 entry is 8 bytes in length
	mov edi, 0x00002000		; Create a PML4 entry for physical memory
	mov eax, 0x00003003		; Bits 0 (P), 1 (R/W), location of low PDP (4KiB aligned)
	stosq
	mov edi, 0x00002800		; Create a PML4 entry for higher half (starting at 0xFFFF800000000000)
	mov eax, 0x00004003		; Bits 0 (P), 1 (R/W), location of high PDP (4KiB aligned)
	stosq

	mov r9, msg_ready
	call print

; Check to see if the system supports 1 GiB pages
; If it does we will use that for identity mapping the lower memory
	mov r9, msg_support_1g_pages	;; Comienza aviso de soporte.
	call print

	mov eax, 0x80000001
	cpuid
	bt edx, 26			; Page1GB

jc pdpte_1GB

	mov r9, msg_support_1g_pages_no	;; Completa: no soporta pags 1GB.
	call print



	;; 2MiB pages.
	mov r9, msg_pdpt
	call print

; Create the Low Page-Directory-Pointer-Table Entries (PDPTE)
; PDPTE starts at 0x0000000000003000, create the first entry there
; A single PDPTE can map 1GiB
; A single PDPTE is 8 bytes in length
; A PDPTE points to 4KiB of memory which contains 512 PDEs
; FIXME - This will completely fill the 64K set for the low PDE (only 16GiB identity mapped)
	mov ecx, 16			; number of PDPE's to make.. each PDPE maps 1GiB of physical memory
	mov edi, 0x00003000		; location of low PDPE
	mov eax, 0x00010003		; Bits 0 (P), 1 (R/W), location of first low PD (4KiB aligned)
pdpte_low:
	stosq
	add rax, 0x00001000		; 4KiB later (512 records x 8 bytes)
	dec ecx
	jnz pdpte_low

	mov r9, msg_ready
	call print

	mov r9, msg_pd
	call print

; Create the Low Page-Directory Entries (PDE)
; A single PDE can map 2MiB of RAM
; A single PDE is 8 bytes in length
;;	mov edi, 0x00010000		; Location of first PDE
;;	mov eax, 0x00000083		; Bits 0 (P), 1 (R/W), and 7 (PS) set
;;	mov ecx, 8192			; Create 8192 2MiB page maps
pde_low:				; Create a 2MiB page
;;	stosq
;;	add rax, 0x00200000		; Increment by 2MiB
;;	dec ecx
;;	jnz pde_low

	mov r9, msg_ready
	call print

	jmp skip1GB

; 1GiB Pages
; Create the Low Page-Directory-Pointer Table Entries (PDPTE)
; PDPTE starts at 0x0000000000010000, create the first entry there
; A single PDPTE can map 1GiB
; A single PDPTE is 8 bytes in length
; A PDPTE points to 4KiB of memory which contains 512 PDEs
; 8191 entries are created to map the first 8191GiB of RAM
; The last entry is reserved for the virtual LFB address
pdpte_1GB:

	mov r9, msg_support_1g_pages_yes	;; Completa: no soporta pags 1GB.
	call print

;; TODO: revisar esta rama.
	mov byte [p_1GPages], 1

; Overwrite the original PML4 entry for physical memory
	mov ecx, 16
	mov edi, 0x00002000		; Create a PML4 entry for physical memory
	mov eax, 0x00010003		; Bits 0 (P), 1 (R/W), location of low PDP (4KiB aligned)
pml4_low_1GB:
	stosq
	add rax, 0x00001000		; 4KiB later (512 records x 8 bytes)
	dec ecx
	jnz pml4_low_1GB

	mov ecx, 8191			; number of PDPE's to make.. each PDPE maps 1GiB of physical memory
	mov edi, 0x00010000		; location of low PDPE
	mov eax, 0x00000083		; Bits 0 (P), 1 (R/W), 7 (PS)
pdpte_low_1GB:				; Create a 1GiB page
	stosq
	add rax, 0x40000000		; Increment by 1GiB
	dec ecx
	jnz pdpte_low_1GB

skip1GB:
	mov r9, msg_load_gdt
	call print
	lgdt [GDTR64]
	mov r9, msg_ready
	call print




; Point cr3 at PML4
;	mov rax, 0x00002008		; Write-thru enabled (Bit 3)
;	mov cr3, rax
;;;;;;;;;;;;;;;;;;; exito: comentando esto bootea el SO exitosamente, ahora el problema
;; se traslada a arreglar la memoria de video, que queda cambiada.
;; actualizacion 20250516 esto esta bien lo dejo asi habilitado.
;; 20250516 2337 confirmo lo siguiente basado en pruebas:
;; mismo usb booteable en pc intel i7 pantalla 1920 * 1080 boot ok aun sin comentar lo de arriba.
;; mismo usb en br1100 no bootea, sino resetea idem otra tb con pantalla 1377 * 768
;; ahora, comento esto de cr3 y funciona en todo.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;fgr;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;hlt;;;;;;;;;;aqui no ha llegado.. parece que mov cr3 jode ;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	xor rax, rax
	xor rbx, rbx
	xor rcx, rcx
	xor rdx, rdx
	xor rsi, rsi
	xor rdi, rdi
	xor rbp, rbp
	mov rsp, TSL_BASE_ADDRESS
	xor r8, r8
	xor r9, r9
	xor r10, r10
	xor r11, r11
	xor r12, r12
	xor r13, r13
	xor r14, r14
	xor r15, r15

	mov ax, 0x10	;; TODO Is this needed?
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax

	;; Set CS with a far return
	push SYS64_CODE_SEL
	push clearcs64
	retfq
clearcs64:

	lgdt [GDTR64]	;; Reload the GDT

	mov r9, msg_idt
	call print
	xor rdi, rdi	;; IDT at linear address 0x0000000000000000.

	;; TODO: modificar print para que no modifique registros.
	push rdi
	mov r9, msg_idt_exceptions
	call print
	pop rdi

	mov rcx, 32

load_exception_gates:
	mov rax, exception_gate
	push rax				;; Save exception gate for later use.
	stosw					;; A15..A0
	mov ax, SYS64_CODE_SEL
	stosw					;; Segment Selector.
	mov ax, 0x8E00
	stosw					;; Exception gate marker.
	pop rax
	shr rax, 16
	stosw					;; A31..A16
	shr rax, 16
	stosd					;; A63..A32
	xor rax, rax
	stosd					;; Reserved.
	dec rcx
	jnz load_exception_gates

	push rdi
	mov r9, msg_idt_irqs
	call print
	pop rdi

	mov rcx, 256-32

load_interrupt_gates:
	mov rax, interrupt_gate
	push rax				;; Later use.
	stosw					;; A15..A0
	mov ax, SYS64_CODE_SEL
	stosw					;; Segment selector.
	mov ax, 0x8F00
	stosw					;; Interrupt gate marker.
	pop rax
	shr rax, 16
	stosw					;; A31..A16
	shr rax, 16
	stosd					;; A63..A32
	xor eax, eax
	stosd					;; Reserved
	dec rcx
	jnz load_interrupt_gates

	;; Set up the exception gates for all of the CPU exceptions.
	mov word [0x00 * 16], exception_gate_00	;; #DE
	mov word [0x01 * 16], exception_gate_01	;; #DB
	mov word [0x02 * 16], exception_gate_02
	mov word [0x03 * 16], exception_gate_03	;; #BP
	mov word [0x04 * 16], exception_gate_04	;; #OF
	mov word [0x05 * 16], exception_gate_05	;; #BR
	mov word [0x06 * 16], exception_gate_06	;; #UD
	mov word [0x07 * 16], exception_gate_07	;; #NM
	mov word [0x08 * 16], exception_gate_08	;; #DF
	mov word [0x09 * 16], exception_gate_09	;; #MF
	mov word [0x0A * 16], exception_gate_10	;; #TS
	mov word [0x0B * 16], exception_gate_11	;; #NP
	mov word [0x0C * 16], exception_gate_12	;; #SS
	mov word [0x0D * 16], exception_gate_13	;; #GP
	mov word [0x0E * 16], exception_gate_14	;; #PF
	mov word [0x0F * 16], exception_gate_15
	mov word [0x10 * 16], exception_gate_16	;; #MF
	mov word [0x11 * 16], exception_gate_17	;; #AC
	mov word [0x12 * 16], exception_gate_18	;; #MC
	mov word [0x13 * 16], exception_gate_19	;; #XM
	mov word [0x14 * 16], exception_gate_20	;; #VE
	mov word [0x15 * 16], exception_gate_21	;; #CP

	mov r9, msg_idt_load
	call print

	lidt [IDTR64]			; load IDT register

	mov r9, msg_ready
	call print

; AP's will be told to start execution at TSL_BASE_ADDRESS.
patch_ap_code:
	mov edi, start
	mov rax, 0x9090909090909090
	stosq						;; Remove code between start and ap_startup, so
	stosq						;; they can reach their starting code.


;; Parse the memory map provided by UEFI
%ifdef UEFI

parse_memmap:
	;; Find all usable memory. Types 1-7 are ok to use once Boot Services has exited.
	;; Anything else not usable.
	xor r9, r9
	xor ebx, ebx
	mov esi, 0x00220000 - 48	;; UEFI map - 48 bytes for the loop start.
	mov edi, 0x00200000			;; Memory map at 0x200000

.next_entry:
	add esi, 48
	mov rax, [rsi + 24]	;; Next entry.
	cmp rax, 0			;; If 0 pages, then we have finished.
	je .finish
	mov rax, [rsi + 8]
	cmp rax, 0x100000	;; Test if the Physical Address less than 0x100000.
	jb .next_entry		;; If so, skip it.
	mov rax, [rsi]
	cmp rax, 0			;; EfiReservedMemoryType (Not usable)
	je .next_entry
	cmp rax, 7			;; EfiConventionalMemory (Free)
	jbe .usable
	mov bl, 0
	jmp .next_entry

.usable:
	cmp bl, 1
	je .usable_contiguous
	mov rax, [rsi + 8]
	stosq				;; Physical Start.
	mov rax, [rsi + 24]
	stosq				;; Number of pages.

.usable_contiguous_next:
	mov r9, rax
	shl r9, 12			;; r9 * 2^12
	add r9, [rsi + 8]	;; r9 should match the physical address of the next reco
						;; rd if they are contiguous.
	mov bl, 0			;; Non-contiguous.
	cmp r9, [rsi + 56]	;; r9 against the next Physical Start.
	jne .next_entry
	mov bl, 1			;; Contiguous.
	jmp .next_entry

.usable_contiguous:
	sub rdi, 8
	mov rax, [rsi + 24]
	add rax, [rdi]
	stosq
	mov rax, [rsi + 24]
	jmp .usable_contiguous_next

.finish:
	xor eax, eax	;; Blank record at the end.
	stosq
	stosq

	;; Clear entries < 3MiB.
	mov rsi, 0x00200000		;; Memory map at 0x200000
	mov rdi, 0x00200000
clear_small:
	lodsq
	cmp rax, 0
	je .finish
	stosq
	lodsq
	cmp rax, 0x300
	jb .remove
	stosq
	jmp clear_small
.remove:
	sub rdi, 8
	jmp clear_small
.finish:
	xor rax, rax	;; Blank record.
	stosq
	stosq

;; Round up Physical Address to next 2MiB boundary if needed and convert 4KiB pa
;; ges to 1MiB pages.
	mov esi, 0x00200000 - 16	;; Memory map at 0x200000
	xor ecx, ecx				;; MiB counter.
uefi_round:
	add esi, 16
	mov rax, [rsi]	;; Physical Address.
	cmp rax, 0
	je .finish
	mov rbx, rax		;; Physical Address to rbx.
	and rbx, 0x1FFFFF	;; Check if any bits between 20-0 are set.
	cmp rbx, 0			;; If not, rbx should be 0.
	jz .convert

	;; At this point one of the bits between 20 and 0 in the starting address ar
	;; e set. Round the starting address up to the next 2MiB.
	shr rax, 21
	shl rax, 21
	add rax, 0x200000
	mov [rsi], rax
	mov rax, [rsi + 8]
	shr rax, 8			;; 4K blocks to MiB.
	sub rax, 1			;; Subtract 1MiB
	mov [rsi + 8], rax
	add rcx, rax		;; Add to MiB counter.
	jmp uefi_round
.convert:
	mov rax, [rsi + 8]
	shr rax, 8			;; 4K blocks to MiB
	mov [rsi + 8], rax
	add rcx, rax		;; Add to MiB counter
	jmp uefi_round
.finish:
	sub ecx, 2
	mov dword [p_mem_amount], ecx
	xor eax, eax		;; Blank record.
	stosq
	stosq
	jmp memmap_end
%endif

%ifdef BIOS
; Parse the memory map provided by BIOS
bios_memmap:
; Stage 1 - Process the E820 memory map to find all possible 2MiB pages that are free to use
; Build an available memory map at 0x200000
	xor ecx, ecx
	xor ebx, ebx			; Running counter of available MiBs
	mov esi, 0x00006000		; E820 Map location
	mov edi, 0x00200000		; 2MiB
bios_memmap_nextentry:
	add esi, 16			; Skip ESI to type marker
	mov eax, [esi]			; Load the 32-bit type marker
	cmp eax, 0			; End of the list?
	je bios_memmap_end820
	cmp eax, 1			; Is it marked as free?
	je bios_memmap_processfree
	add esi, 16			; Skip ESI to start of next entry
	jmp bios_memmap_nextentry
bios_memmap_processfree:
	; TODO Check ACPI 3.0 Extended Attributes - Bit 0 should be set
	sub esi, 16
	mov rax, [rsi]			; Physical start address
	add esi, 8
	mov rcx, [rsi]			; Physical length
	add esi, 24
	shr rcx, 20			; Convert bytes to MiB
	cmp rcx, 0			; Do we have at least 1 page?
	je bios_memmap_nextentry
	stosq
	mov rax, rcx
	stosq
	add ebx, ecx
	jmp bios_memmap_nextentry
bios_memmap_end820:

; Stage 2 - Sanitize the records
	mov esi, 0x00200000
memmap_sani:
	mov rax, [rsi]
	cmp rax, 0
	je memmap_saniend
	bt rax, 20
	jc memmap_itsodd
	add esi, 16
	jmp memmap_sani
memmap_itsodd:
	add rax, 0x100000
	mov [rsi], rax
	mov rax, [rsi+8]
	sub rax, 1
	mov [rsi+8], rax
	add esi, 16
	jmp memmap_sani
memmap_saniend:
	sub ebx, 2			; Subtract 2MiB for the CPU stacks
	mov dword [p_mem_amount], ebx
	xor eax, eax
	stosq
	stosq
%endif

memmap_end:

;; Create the High Page-Directory-Pointer-Table Entries (PDPTE). High PDPTE is s
;; tored at 0x0000000000004000, create the first entry there. A single PDPTE can
;; map 1GiB with 2MiB pages. A single PDPTE is 8 bytes in length.
	mov ecx, dword [p_mem_amount]
	shr ecx, 10				;; MB to GB.
	add rcx, 1				;; Add 1. This is the number of PDPE's to make.
	mov edi, 0x00004000		;; Location of high PDPE.
	mov eax, 0x00020003		;; Location of first high PD. Bits 0 (P) and 1 (R/W)
							;; set.
create_pdpe_high:
	stosq
	add rax, 0x00001000		;; 4K later (512 records x 8 bytes).
	dec ecx
	cmp ecx, 0
	jne create_pdpe_high

	;; Create the High Page-Directory Entries (PDE). A single PDE can map 2MiB o
	;; f RAM. A single PDE is 8 bytes in length.
	mov esi, 0x00200000		;; Memory map.
	mov edi, 0x00020000		;; Location of first PDE.
pde_next_range:
	lodsq					;; Base
	xchg rax, rcx
	lodsq					;; Length
	xchg rax, rcx
	cmp rax, 0				;; End of records.
	je .finish
	cmp rax, 0x00200000
	ja .skipfirst4mb
	add rax, 0x00200000		; Add 2 MiB to the base
	sub rcx, 2			; Subtract 2 MiB from the length
.skipfirst4mb:
	shr ecx, 1			; Quick divide by 2 for 2 MB pages
	add rax, 0x00000083		; Bits 0 (P), 1 (R/W), and 7 (PS) set
.pde_high:				; Create a 2MiB page
	stosq
	add rax, 0x00200000		; Increment by 2MiB
	cmp ecx, 0
	je pde_next_range
	dec ecx
	cmp ecx, 0
	jne .pde_high
	jmp pde_next_range
.finish:

;; Read APIC Address from MSR and enable it (if not done so already).
	mov ecx, IA32_APIC_BASE
	rdmsr				;; Returns APIC in edx:eax
	bts eax, 11			;; APIC Global Enable.
	wrmsr
	and eax, 0xFFFFF000	;; Clear lower 12 bits.
	shl rdx, 32			;; Shift lower 32 bits to upper 32 bits.
	add rax, rdx
	mov [p_LocalAPICAddress], rax

;; Check for x2APIC support.
	mov eax, 1
	cpuid					;; x2APIC is supported if bit 21 is set.
	shr ecx, 21
	and cl, 1
	mov byte [p_x2APIC], cl

	call init_acpi			;; Find and process the ACPI tables
	call init_cpu			;; Configure the BSP CPU
	call init_hpet			;; Configure the HPET

	call init_smp			; Init of SMP, deactivate interrupts

;; Reset rsp the proper location (was set to TSL_BASE_ADDRESS previously).
	mov rsi, [p_LocalAPICAddress]	;; We would call p_smp_get_id here but stack
									;; not yet defined. It is safer to find the 
									;; value directly.
	add rsi, 0x20
	lodsd				;; Load a 32-bit value. We only want the high 8 bits.
	shr rax, 24			;; Shift to the right and AL now holds the CPU's APIC ID
	shl rax, 10			;; shift left 10 bits for a 1024 byte stack.
	add rax, 0x0000000000050400
	mov rsp, rax		;; Leave 0x50000-0x9FFFF free to use.

;; Build the InfoMap
	xor edi, edi
	mov di, 0x5000
	mov rax, [p_ACPITableAddress]
	stosq
	mov eax, [p_BSP]
	stosd

	mov di, 0x5010
	mov ax, [p_cpu_speed]
	stosw
	mov ax, [p_cpu_activated]
	stosw
	mov ax, [p_cpu_detected]
	stosw

	mov di, 0x5020
	mov eax, [p_mem_amount]
	and eax, 0xFFFFFFFE
	stosd

	mov di, 0x5030
	mov al, [p_IOAPICCount]
	stosb
	mov al, [p_IOAPICIntSourceC]
	stosb

	mov di, 0x5040
	mov rax, [p_HPET_Address]
	stosq
	mov eax, [p_HPET_Frequency]
	stosd
	mov ax, [p_HPET_CounterMin]
	stosw
	mov al, [p_HPET_Timers]
	stosb

	mov di, 0x5060
	mov rax, [p_LocalAPICAddress]
	stosq

	;; Copy data received from UEFI.
	mov di, 0x5080
	mov rax, [0x00005F00]			;; Video memory.
	stosq
	mov eax, [0x00005F00 + 0x10]	;; X and Y resolution (16-bits each)
	stosd
	mov eax, [0x00005F00 + 0x14]	;; Pixels per scan line.
	stosw
	mov ax, 32						;; Hardcodeado, idem que el uefi.sys
	stosw

;; PCI(e) data.
	mov di, 0x5090
	mov ax, [p_PCIECount]
	stosw
	mov ax, [p_IAPC_BOOT_ARCH]
	stosw

;; Miscellaneous flags.
	mov di, 0x50E0
	mov al, [p_1GPages]
	stosb
	mov al, [p_x2APIC]
	stosb

;; Atributos de paginas que contienen buffer de video (use write-combining).
	mov eax, 0x80000001
	cpuid
	bt edx, 26	;; Pages 1GB?
	jnc lfb_wc_2mb

;; Set the 1GB page the frame buffer is in to WC - PAT = 1, PCD = 0, PWT = 1 (WC
;; = write combining), PAT (Page Attribute Table), PWT (Page Write-Through, need
;; ed, not to be catched), PCD (Page Cache Disable).

lfb_wc_1gb:
	mov rax, [0x00005F00]		;; FB
	mov rbx, 0x100000000		;; Compare to 4GB
	cmp rax, rbx
	jbe lfb_wc_end				;; If less, don't set WC.

	mov rbx, rax
	mov rcx, 0xFFFFFFFFC0000000 ;; 7 * 4 + 2 = 30 ceros, 2^30 = 1GB (los ceros),
								;; directorios y nros de pagina.
	and rax, rcx				;; Upper bits.
	mov rcx, 0x000000003FFFFFFF	;; Primer GB, es el offset dentro de la pagina.
	and rbx, rcx				;; offset. Hasta aqui separa el address del fram
								;; ebuffer en 2 partes tomando como umbral el 1e
								;; r GB.
	
	;; Atributos:
	mov ax, 0x108B				;; P (0), R/W (1), PWT (3), PS (7), PAT (12)
	mov rdi, 0x1FFF8
	mov [rdi], rax				;; Write updated PDPTE

	mov rax, 0x000007FFC0000000	;; 8191GiB
	add rax, rbx				;; Add offset within 1GiB page.
	mov [0x00005080], rax		;; Write out new virtual address to FB.

	jmp lfb_wc_end

;; Set the relevant 2MB pages the frame buffer is in to WC
lfb_wc_2mb:

	mov ecx, 4				;; 4 2MiB pages - TODO only set the pages needed
	mov edi, 0x00010000
	mov rax, [0x00005F00]	;; Base address of video memory
	shr rax, 18
	add rdi, rax

.next_page:
	mov eax, [edi]			;; Load the 8-byte value.
	or ax, 0x1008			;; Set bits 12 (PAT) and 3 (PWT).
	and ax, 0xFFEF			;; Clear bit 4 (PCD).
	mov [edi], eax			;; Write it back.
	add edi, 8
	sub ecx, 1
	jnz .next_page

lfb_wc_end:
	mov rax, cr3			; Flush TLB
	mov cr3, rax
	wbinvd				; Flush Cache

	;; Kernel to its final location.
	mov esi, TSL_BASE_ADDRESS + BOOTLOADER_SIZE	;; Offset to end of tsl.sys
	
	;; La direccion a la cual el kernel se copia, tal como luego comienza ejecut
	;; ando en _start en 0x100000
	mov rdi, 0x100000		;; Final Destination.
	mov rcx, ((32768 - BOOTLOADER_SIZE) / 8)
	rep movsq

%ifdef BIOS
	cmp byte [p_BootDisk], 'F'	;; Check if sys is booted from floppy?
	jnz clear_regs
	call read_floppy		;; Then load whole floppy at memory
%endif

clear_regs:
	xor rax, rax
	xor rbx, rbx
	xor rcx, rcx
	xor rdx, rdx
	xor rsi, rsi
	xor rdi, rdi
	xor rbp, rbp
	xor r8, r8
	xor r9, r9
	xor r10, r10
	xor r11, r11
	xor r12, r12
	xor r13, r13
	xor r14, r14
	xor r15, r15

	mov r9, msg_system_setup_ready
	call print

	call keyboard_get_key

	jmp 0x00100000	;; Jump to kernel.


%include "./asm/init/acpi.asm"
%include "./asm/init/cpu.asm"
%include "./asm/init/hpet.asm"
%include "./asm/init/smp.asm"

%ifdef BIOS
%include "./asm/bios/dma.asm"
%include "./asm/bios/fdc_64.asm"
%endif

%include "./asm/interrupts.asm"
%include "./asm/sysvar.asm"

; -----------------------------------------------------------------------------
%ifdef BIOS
; -----------------------------------------------------------------------------
; debug_progressbar
; IN:	EBX = Index #
; Note:	During a floppy load this function gets called 40 times
debug_progressbar:
	mov rdi, [0x00005F00]		; Frame buffer base
	add rdi, rbx
	; Offset to start of progress bar location
	; 1024 - screen width
	; 367 - Line # to display bar
	; 32 - Offset to start of the progress blocks
	; 512 - Middle of screen
	; 4 - 32-bit pixels
	add rdi, ((1024 * 387 - 32) + 512) * 4

	; Draw the pixel
	mov eax, 0x00FFFFFF		; White
	stosd
	add rdi, (1024 * 4) - 4
	stosd

	ret
; -----------------------------------------------------------------------------
%endif








































;;==============================================================================
;; @file /asm/lib/lib.asm
;;==============================================================================


;;extern PPSL
;;extern FB
;;extern FB_SIZE
;;extern STEP_MODE_FLAG

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;section .text


;;==============================================================================
; num2hexStr - escribe el hexadecimal de un nro, dentro de un placeholder utf8
;;==============================================================================
;; Argumentos:
;; -- placeholder por stack, 1er push.
;; -- el numero entero de 64 bit a convertir, pasado por stack (2do push)
;; Retorno:
;; -- rax = cantidad de caracteres escritos.
;;
;; Altera unicamente rax, restantes registros los devuelve como los recibe.
;;==============================================================================

num2hexStr:
    push rbp
	mov rbp, rsp

	push rcx
	push rdx	

.division_init:
	mov rcx, 16
	mov rdx, 0  			;; En cero la parte mas significativa del acum.
	mov rax, [rbp + 8 * 2]  ;; Numero a convertir.
    push qword 0			;; Marca para dejar de popear durante write.

.division:
	div rcx
	push qword [hexConvert8 + rdx]  
	cmp rax, 0
	jz .write_init
	mov rdx, 0
	jmp .division

.write_init:
	mov rax, 0				;; Contara chars copiados para valor de retorno.
	mov rcx, [rbp + 8 * 3]	;; Placeholder.

.write:
    pop rdx
	mov [rcx + rax], rdx
	cmp rdx, 0
	je .end
	inc rax
    jmp .write

.end:
	pop rdx
	pop rcx

	mov rsp, rbp
	pop rbp	 
	ret


;;==============================================================================
;; num2str - convierte un entero en un string null terminated
;;==============================================================================
;; Argumentos:
;; -- placeholder por stack, 1er push.
;; -- el numero entero de 64 bit a convertir, pasado por stack (2do push)
;; Retorno:
;; -- rax = cantidad de caracteres escritos.
;;
;; Altera unicamente rax, restantes registros los devuelve como los recibe.
;;==============================================================================

num2str:
    push rbp
	mov rbp, rsp

	push rcx
	push rdx	

.division_init:
	mov rcx, 10
	mov rdx, 0  			;; En cero la parte mas significativa del acum.
	mov rax, [rbp + 8 * 2]  ;; Numero a convertir.
    push qword 0			;; Marca para dejar de popear durante write.

.division:
	div rcx
	or dl, 0x30				;; Convierto el resto  menor a 10 a ASCII.
	push rdx  
	cmp rax, 0
	jz .write_init
	mov rdx, 0
	jmp .division

.write_init:
	mov rax, 0				;; Contara chars copiados para valor de retorno.
	mov rcx, [rbp + 8 * 3]	;; Placeholder.

.write:
    pop rdx
	mov [rcx + rax], dl
	cmp rdx, 0
	je .end
	inc rax
    jmp .write

.end:
	;;add rsp, 8	;; El cero que marcaba fin, elimino para popear regs.
	pop rdx
	pop rcx

	mov rsp, rbp
	pop rbp	 
	ret



;;==============================================================================
;; print - impresion utf8 a buffer de video luego de ExitBootSerivces()
;;==============================================================================
;; Argumentos:
;; -- r9 = cadena fmt
;; -- rsi = 2do argumento en caso de haber %.
;; Retorno:
;; -- rax = cursor (address fb) siguiente a la ultima posicion escrita.
;;
;; El comportamiento si la cadena de fmt tiene % huerfano (no hay ninguna de las
;; siguientes a continuacion: d, h, c, s) es: ignora el % y sigue imprimiendo. S
;; i tiene muchos % siempre va a usar el mismo argumento para la conversion (el 
;; unico que recibe en rsi).
;;
;; El cursor para esta funcion, es la direccion del pixel superior izquierdo del
;; bounding box del caracter de la fuente.
;;
;; Aclaracion: de la memoria de video usa PPSL el cual puede ser indistintamente
;; qword (durante efi) o word (post-efi).
;;==============================================================================

print:
	mov rax, [print_cursor]
	mov rdi, [PPSL]
	and rdi, 0x0000FFFF	;; No necesario durante efi, pero si necesario durante 2
						;; do loader puesto que en 0x5F00 queda  HR, VR y PPSL e
						;; n tamanos de dato word.
	mov r8, 0	;; ix src str.
	
.loop_read_string_char:
	push rax	;; FB cursor, apunta a inicio de char (pixel exactamente) a come
				;; nzar imprimir.
	mov rcx, 0	;; Blanqueo de parte alta para uso en resolucion de addrress en 
				;; .print_next_font.
	mov cl, [r9 + r8]
	cmp cl, 0
	je .string_flush_end

	cmp cl, 0x0A
	je .linefeed
	cmp cl, '%'
	jne .print_next_font
	inc r8
	mov cl, [r9 + r8]
	mov [print_cursor], rax	;; Update cursor to current position.

	cmp cl, 'd'
	je .integer
	cmp cl, 'h'
	je .hexadecimal
	cmp cl, 'c'
	je .character
	cmp cl, 's'
	je .string
		
.print_next_font:
	lea r10, [font_data + 8 * rcx]	;; r10 p2fontLine 16px chars.
	lea r10, [r10 + 8 * rcx]
	mov rdx, 0

.loop_font_vertical_line:
	cmp rdx, font_height
	je .char_flush_end
	mov rcx, 0
	mov rbx, 0
	mov bl, [r10 + rdx]

.loop_font_horizontal_pixel:
	cmp rcx, 8
	je .next_line
	bt rbx, rcx
	jc .setPixel

.resetPixel:
	mov dword [rax + 4 * rcx], 0x00000000
	jmp .nextPixel
.setPixel:
	mov dword [rax + 4 * rcx], 0x00E0E0E0
.nextPixel:
	inc rcx
	jmp .loop_font_horizontal_pixel

.next_line:
	inc rdx
	lea rax, [rax + 4 * rdi]
	jmp .loop_font_vertical_line

.char_flush_end:
	add qword [rsp], 32	;; rax += 8px * 4bytes/px

.avance_next_char:
	pop rax
	inc r8
	jmp .loop_read_string_char

.linefeed:
	mov rdx, 0			;; rdx:rax = 0:rax
	sub rax, [FB]
	mov rbx, [PPSL]
	and rbx, 0x0000FFFF	;; No necesario durante efi, si en 2do loader.
	lea rbx, [4 * rbx]	;; 4b/px * ppsl
	div rbx				;; rdx = offset desde comienzo de linea.

	sub [rsp], rdx		;; Carriage return.

	mov rbx, [PPSL]
	and rbx, 0x0000FFFF	;; No necesario durante efi, si en 2do loader.

	mov rax, 4 * 16		;; Bajar 16px.
	mov rdx, 0
	mul rbx				;; rax = offset_bytes
	add [rsp], rax
	jmp .avance_next_char

.integer:
	push rdi
	push r8
	push r9
	
	push volatile_placeholder
	push rsi
	call num2str
	add rsp, 8 * 2
	mov r9, volatile_placeholder
	call print
	pop r9
	pop r8
	pop rdi

	mov [rsp], rax			;; Actualiza cursor.
	jmp .avance_next_char

.hexadecimal:
	push rdi
	push r8
	push r9
	
	push volatile_placeholder
	push rsi
	call num2hexStr
	add rsp, 8 * 2
	mov r9, volatile_placeholder
	call print
	pop r9
	pop r8
	pop rdi

	mov [rsp], rax			;; Actualiza cursor.
	jmp .avance_next_char

.character:
	;; No necesario por el momento.

.string:
	push rdi
	push r8
	push r9
	mov r9, rsi
	call print
	pop r9
	pop r8
	pop rdi

	mov [rsp], rax			;; Actualiza cursor.
	jmp .avance_next_char

.string_flush_end:
	add rsp, 8				;; Quita push de rax q se hace para cada caracter.
	mov [print_cursor], rax	;; Update cursor to current position.
	ret


;;==============================================================================
;; memsetFramebuffer
;;==============================================================================
;; Argumentos:
;; -- rax = 0x00RRGGBB
;;==============================================================================

memsetFramebuffer:
	mov rdi, [FB]
	mov rcx, [FB_SIZE]
	shr rcx, 2	;; FB_SIZE /= 4.
	rep stosd
	ret


;;==============================================================================
;; keyboard_command
;;==============================================================================
;; Argumentos:
;; -- al = command
;; -- ah = byte requerido por el comando (de ser necesario)
;; -- bit 16 de rax = 0 si comando no requiere ah, 1 si comando requiere enviar 
;;    ah a continuacion de al.
;;==============================================================================

keyboard_command:
	push rbp
	mov rbp, rsp

	out 0x64, al
	bt rax, 16
	jnc .fin
	mov al, ah
	out 0x60, al

.fin:
	mov rsp, rbp
	pop rbp
	ret


;;==============================================================================
;; keyboard_get_key | Se queda esperando tecla 'n'.
;;==============================================================================

keyboard_get_key:
	push rbp
	mov rbp, rsp

	cmp byte [STEP_MODE_FLAG], 0
	je .fin

	mov rax, 0
.loop:
	in al, 0x64
	and al, 0x01
	cmp al, 0
	je .loop
	in al, 0x60

;; TODO: revisar por que en pc fgr escritorio, llega a bootloader y cualga o se 
;; queda aleatoriamente.
;; Sin estas dos, pasa oka.
	cmp al, 0x31	;; Scancode tecla 'n'.
	jne .loop

.fin:
	mov rsp, rbp
	pop rbp
	ret


;;==============================================================================
;; emptyKbBuffer - Vacia el teclado, dejando ninguna tecla pendiente.
;;==============================================================================

emptyKbBuffer:
	push rbp
	mov rbp, rsp
	mov rax, 0
.loop:
	in al, 0x64
	and al, 0x01
	cmp al, 1
	jne .exit
	in al, 0x60
	jmp .loop
.exit:
	mov rsp, rbp
	pop rbp
	ret




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;section .data

hexConvert8:				db "0123456789ABCDEF"
print_cursor dq 0 ;; El cursor es tan solo puntero a framebuffer.

;; Hay otro con el mismo nombre en uefi.asm pero ese pertenece a efi_print.
volatile_placeholder:
times	64 dw 0x0000

font_height	equ 16
font_data:
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x00 uni0000
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x01 uni0001
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x02 uni0002
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x03 uni0003
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x04 uni0004
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x05 uni0005
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x06 uni0006
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x07 uni0007
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x08 uni0008
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x09 uni0009
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x0a uni000A
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x0b uni000B
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x0c uni000C
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x0d uni000D
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x0e uni000E
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x0f uni000F
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x10 uni0010
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x11 uni0011
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x12 uni0012
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x13 uni0013
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x14 uni0014
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x15 uni0015
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x16 uni0016
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x17 uni0017
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x18 uni0018
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x19 uni0019
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x1a uni001A
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x1b uni001B
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x1c uni001C
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x1d uni001D
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x1e uni001E
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x1f uni001F
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x20 space
	dd 0x08080000, 0x08080808, 0x00000808, 0x00000808 ;; 0x21 exclam
	dd 0x14140000, 0x00001414, 0x00000000, 0x00000000 ;; 0x22 quotedbl
	dd 0x48000000, 0x24FE4848, 0x127F2424, 0x00001212 ;; 0x23 numbersign
	dd 0x08080000, 0x0909493E, 0x4848380E, 0x08083E49 ;; 0x24 dollar
	dd 0x09060000, 0x30C60909, 0x9090630C, 0x00006090 ;; 0x25 percent
	dd 0x221C0000, 0x04040202, 0x41A1918A, 0x0000BC42 ;; 0x26 ampersand
	dd 0x08080000, 0x00000808, 0x00000000, 0x00000000 ;; 0x27 quotesingle
	dd 0x10200000, 0x04040808, 0x04040404, 0x20100808 ;; 0x28 parenleft
	dd 0x08040000, 0x20201010, 0x20202020, 0x04081010 ;; 0x29 parenright
	dd 0x08080000, 0x2A1C2A49, 0x00080849, 0x00000000 ;; 0x2a asterisk
	dd 0x00000000, 0x08080000, 0x08087F08, 0x00000008 ;; 0x2b plus
	dd 0x00000000, 0x00000000, 0x00000000, 0x0C181818 ;; 0x2c comma
	dd 0x00000000, 0x00000000, 0x00007E00, 0x00000000 ;; 0x2d hyphen
	dd 0x00000000, 0x00000000, 0x00000000, 0x00001818 ;; 0x2e period
	dd 0x40400000, 0x10102020, 0x04040808, 0x01010202 ;; 0x2f slash
	dd 0x221C0000, 0x49515161, 0x43454549, 0x00001C22 ;; 0x30 zero
	dd 0x0C080000, 0x0808090A, 0x08080808, 0x00003F08 ;; 0x31 one
	dd 0x221C0000, 0x20404041, 0x02040810, 0x00007F01 ;; 0x32 two
	dd 0x211E0000, 0x1E204040, 0x40404020, 0x00001E21 ;; 0x33 three
	dd 0x28300000, 0x22242428, 0x207F2122, 0x00002020 ;; 0x34 four
	dd 0x013F0000, 0x201F0101, 0x40404040, 0x00001E21 ;; 0x35 five
	dd 0x221C0000, 0x231D0102, 0x41414141, 0x00001C22 ;; 0x36 six
	dd 0x407F0000, 0x10102020, 0x04040808, 0x00000202 ;; 0x37 seven
	dd 0x221C0000, 0x1C224141, 0x41414122, 0x00001C22 ;; 0x38 eight
	dd 0x221C0000, 0x41414141, 0x40405C62, 0x00001C22 ;; 0x39 nine
	dd 0x00000000, 0x18180000, 0x00000000, 0x00001818 ;; 0x3a colon
	dd 0x00000000, 0x18180000, 0x00000000, 0x0C181818 ;; 0x3b semicolon
	dd 0x00000000, 0x0C30C000, 0x300C0303, 0x000000C0 ;; 0x3c less
	dd 0x00000000, 0x7F000000, 0x007F0000, 0x00000000 ;; 0x3d equal
	dd 0x00000000, 0x300C0300, 0x0C30C0C0, 0x00000003 ;; 0x3e greater
	dd 0x423C0000, 0x20404040, 0x00080810, 0x00000808 ;; 0x3f question
	dd 0x38000000, 0xC9B28244, 0x89898989, 0x0402B2C9 ;; 0x40 at
	dd 0x18180000, 0x24242424, 0x427E4242, 0x00008181 ;; 0x41 A
	dd 0x211F0000, 0x1F214141, 0x41414121, 0x00001F21 ;; 0x42 B
	dd 0x423C0000, 0x01010102, 0x02010101, 0x00003C42 ;; 0x43 C
	dd 0x211F0000, 0x41414141, 0x41414141, 0x00001F21 ;; 0x44 D
	dd 0x017F0000, 0x7F010101, 0x01010101, 0x00007F01 ;; 0x45 E
	dd 0x017F0000, 0x7F010101, 0x01010101, 0x00000101 ;; 0x46 F
	dd 0x423C0000, 0x01010102, 0x42414171, 0x00003C42 ;; 0x47 G
	dd 0x41410000, 0x7F414141, 0x41414141, 0x00004141 ;; 0x48 H
	dd 0x083E0000, 0x08080808, 0x08080808, 0x00003E08 ;; 0x49 I
	dd 0x40780000, 0x40404040, 0x40404040, 0x00003E41 ;; 0x4a J
	dd 0x41010000, 0x05091121, 0x21110907, 0x00008141 ;; 0x4b K
	dd 0x01010000, 0x01010101, 0x01010101, 0x00007F01 ;; 0x4c L
	dd 0x63630000, 0x49555555, 0x41414949, 0x00004141 ;; 0x4d M
	dd 0x43430000, 0x49494545, 0x61615151, 0x00004141 ;; 0x4e N
	dd 0x221C0000, 0x41414141, 0x41414141, 0x00001C22 ;; 0x4f O
	dd 0x211F0000, 0x21414141, 0x0101011F, 0x00000101 ;; 0x50 P
	dd 0x221C0000, 0x41414141, 0x49414141, 0x20101C2A ;; 0x51 Q
	dd 0x211F0000, 0x21414141, 0x4141211F, 0x00008141 ;; 0x52 R
	dd 0x413E0000, 0x3E010101, 0x40404040, 0x00003E41 ;; 0x53 S
	dd 0x087F0000, 0x08080808, 0x08080808, 0x00000808 ;; 0x54 T
	dd 0x41410000, 0x41414141, 0x41414141, 0x00001C22 ;; 0x55 U
	dd 0x81810000, 0x42424281, 0x24242442, 0x00001818 ;; 0x56 V
	dd 0x41410000, 0x49494941, 0x55555555, 0x00002222 ;; 0x57 W
	dd 0x41410000, 0x08142222, 0x22221408, 0x00004141 ;; 0x58 X
	dd 0x41410000, 0x14142222, 0x08080808, 0x00000808 ;; 0x59 Y
	dd 0x407F0000, 0x08101020, 0x02040408, 0x00007F01 ;; 0x5a Z
	dd 0x041C0000, 0x04040404, 0x04040404, 0x1C040404 ;; 0x5b bracketleft
	dd 0x01010000, 0x04040202, 0x10100808, 0x40402020 ;; 0x5c backslash
	dd 0x101C0000, 0x10101010, 0x10101010, 0x1C101010 ;; 0x5d bracketright
	dd 0x24180000, 0x00008142, 0x00000000, 0x00000000 ;; 0x5e asciicircum
	dd 0x00000000, 0x00000000, 0x00000000, 0xFF000000 ;; 0x5f underscore
	dd 0x10080400, 0x00000000, 0x00000000, 0x00000000 ;; 0x60 grave
	dd 0x00000000, 0x40423C00, 0x4141417E, 0x00005E61 ;; 0x61 a
	dd 0x01010000, 0x41231D01, 0x41414141, 0x00001D23 ;; 0x62 b
	dd 0x00000000, 0x01423C00, 0x01010101, 0x00003C42 ;; 0x63 c
	dd 0x40400000, 0x41625C40, 0x41414141, 0x00005C62 ;; 0x64 d
	dd 0x00000000, 0x41221C00, 0x01017F41, 0x00003C42 ;; 0x65 e
	dd 0x08700000, 0x08087E08, 0x08080808, 0x00000808 ;; 0x66 f
	dd 0x00000000, 0x41625C00, 0x41414141, 0x22405C62 ;; 0x67 g
	dd 0x01010000, 0x41231D01, 0x41414141, 0x00004141 ;; 0x68 h
	dd 0x08080000, 0x08080E00, 0x08080808, 0x00007F08 ;; 0x69 i
	dd 0x10100000, 0x10101C00, 0x10101010, 0x10101010 ;; 0x6a j
	dd 0x01010000, 0x09112101, 0x21110B05, 0x00008141 ;; 0x6b k
	dd 0x080F0000, 0x08080808, 0x08080808, 0x00007008 ;; 0x6c l
	dd 0x00000000, 0x49493F00, 0x49494949, 0x00004949 ;; 0x6d m
	dd 0x00000000, 0x41231D00, 0x41414141, 0x00004141 ;; 0x6e n
	dd 0x00000000, 0x41221C00, 0x41414141, 0x00001C22 ;; 0x6f o
	dd 0x00000000, 0x41231D00, 0x41414141, 0x01011D23 ;; 0x70 p
	dd 0x00000000, 0x41625C00, 0x41414141, 0x40405C62 ;; 0x71 q
	dd 0x00000000, 0x02463A00, 0x02020202, 0x00000202 ;; 0x72 r
	dd 0x00000000, 0x01413E00, 0x40403E01, 0x00003E41 ;; 0x73 s
	dd 0x08000000, 0x08087E08, 0x08080808, 0x00007008 ;; 0x74 t
	dd 0x00000000, 0x41414100, 0x41414141, 0x00005E61 ;; 0x75 u
	dd 0x00000000, 0x41414100, 0x14222222, 0x00000814 ;; 0x76 v
	dd 0x00000000, 0x49414100, 0x55555555, 0x00002222 ;; 0x77 w
	dd 0x00000000, 0x22414100, 0x22140814, 0x00004141 ;; 0x78 x
	dd 0x00000000, 0x42414100, 0x18242422, 0x08101018 ;; 0x79 y
	dd 0x00000000, 0x20407F00, 0x02040810, 0x00007F01 ;; 0x7a z
	dd 0x08300000, 0x08080808, 0x08080608, 0x08080808 ;; 0x7b braceleft
	dd 0x08080000, 0x08080808, 0x08080808, 0x08080808 ;; 0x7c bar
	dd 0x08060000, 0x08080808, 0x08083008, 0x08080808 ;; 0x7d braceright
	dd 0x00000000, 0x00000000, 0x0000324C, 0x00000000 ;; 0x7e asciitilde
	dd 0x00000000, 0x00000000, 0x00000000, 0x00000000 ;; 0x7f uni007F


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
STEP_MODE_FLAG		db 1	;; Lo activa presionar 's' al booteo.




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; estos son agregados por poder imprimir aqui adentro
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
msg_transient_sys_load	db "Transient system load starting", 0x0A, 0
msg_system_setup_ready	db "System setup ready: jumping to kernel...", 0x0A
						db "[press 'n' to continue...]", 0x0A, 0
msg_clearing_space_sys_tables db "Clearing space for system tables... ", 0
msg_setup_pic_and_irq db "Init PIC, masks and IRQs... ", 0
msg_ready db "ready", 0x0A, 0
msg_entries db "entries... ", 0
msg_gdt		db "Setting up GDT... ", 0
msg_pml4	db "PML4... ", 0
msg_pdpt	db "PDPT... ", 0
msg_pd		db "PD... ", 0
msg_support_1g_pages:	db "Support for 1GB pages = ", 0
msg_support_1g_pages_yes:	db "yes", 0x0A, 0
msg_support_1g_pages_no:	db "no", 0x0A, 0
msg_load_gdt db "Load gdt... ", 0
msg_idt	db "Setting up IDT... ", 0
msg_idt_exceptions	db "exceptions... ", 0
msg_idt_irqs db "irqs ", 0
msg_idt_load	db "load... ", 0
msg_exception_occurred db "An exception has occurred in the system.", 0x0A, 0








































BOOTLOADER_SIZE equ 0x2000	;; 8KiB


;;;;;;;;;;; para generar un loop y dejar q se vea mensaje antes de ir a bootloader
;;; sacar, no va
;;;time_delay dq 800000

EOF:
	db 0xDE, 0xAD, 0xC0, 0xDE

; Pad to an even KB file
times BOOTLOADER_SIZE-($-$$) db 0x90











; =============================================================================
; EOF
