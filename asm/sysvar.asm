;;==============================================================================
;; System Variables | @file /asm/sysvar.asm
;;==============================================================================


section .data


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;global GDTR32	;; Requiere ubicacion hasta FFFFFFFF.
global GDTR64
global SYS64_CODE_SEL
global IDTR64

cfg_smpinit:	db 1	; By default SMP is enabled. Set to 0 to disable.


align 16

tGDTR64:									;; Global Descriptors Table Register
				dw gdt64_end - gdt64 - 1	;; Limit.
				dq gdt64					;; linear address of GDT

align 16
GDTR64:										;; Global Descriptors Table Register
				dw gdt64_end - gdt64 - 1	;; Limit.
				dq 0x0000000000001000		;; linear address of GDT

gdt64:									;; Struct copied to 0x0000000000001000
SYS64_NULL_SEL:	equ $ - gdt64			;; Null Segment
				dq 0x0000000000000000
SYS64_CODE_SEL:	equ $ - gdt64			;; Code segment, read/execute, nonconfor
										;; ming
				dq 0x00209A0000000000	;; 53 Long mode code, 47 Present, 44 Cod
										;; e/Data, 43 Executable, 41 Readable
SYS64_DATA_SEL:	equ $ - gdt64			;; Data segment, read/write, expand down
				dq 0x0000920000000000	;; 47 Present, 44 Code/Data, 41 Writable
gdt64_end:

IDTR64:									;; Interrupt Descriptor Table Register
				dw 256 * 16 - 1			;; Limit = 4096 - 1
				dq 0x0000000000000000	;; linear address of IDT


