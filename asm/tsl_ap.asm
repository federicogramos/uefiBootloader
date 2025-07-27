;;==============================================================================
;; Transient System Load | @file /asm/tsl_ap.asm
;;=============================================================================
;; Recibe la informacion del sistema. Hace configuraciones basicas del mismo. Co
;; pia el kernel a su ubicacion final. Salta al punto de entrada _start del kern
;; el en 0x100000.
;;=============================================================================


global bootmode


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
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;jmp 0x0000:init_smp_ap

%include "./asm/init/smp_ap.asm"	;; AP's will start execution at TSL_BASE_ADD
									;; RESS and fall through to this code.

;;==============================================================================
;; 32-bit code. Instructions must also be 64 bit compatible. If a 'U' is stored 
;; at 0x5FFF then we know it was a UEFI boot and immediately proceed to start64.
;; Otherwise we need to set up a minimal 64-bit environment.

BITS 32

bootmode:
	cmp bl, 'U'	;; If uefi boot then already in 64 bit mode.
	je start64

%ifdef BIOS
%include "./asm/bios/bios_32_64.asm"
%endif

