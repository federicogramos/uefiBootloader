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
