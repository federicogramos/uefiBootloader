;;==============================================================================
;; System Variables | @file /asm/sysvar.asm
;;==============================================================================


cfg_smpinit:	db 1	; By default SMP is enabled. Set to 0 to disable.

;; Memory locations
;; Info de video en 2 lugares para consultar: InfoMap y VBEModeInfoBlock.
;; Info de video desde 0x5080
;; 0x5080 = qword, framebuffer
;; 0x5088 = word, screen x
;; 0x508A = word, screen y
;; 0x508C = word, ppsl
;; 0x508E = word, bits ppx

InfoMap:			equ 0x0000000000005000
IM_DetectedCoreIDs:	equ 0x0000000000005100	;; 1 byte per entry. Each is the API
											;; C ID of a core.
IM_PCIE:			equ 0x0000000000005400	;; 16 bytes per entry
IM_IOAPICAddress:	equ 0x0000000000005600	;; 16 bytes per entry
IM_IOAPICIntSource:	equ 0x0000000000005700	;; 8 bytes per entry
SystemVariables:	equ 0x0000000000005800
IM_ActivedCoreIDs:	equ 0x0000000000005E00	;; 1by per entry. 1 = 1 core active.


;; Cuando bootea uefi, la info de video durante uefi la mete aqui:
;; [0x00005F00]	;; Frame buffer base
;; [0x00005F08]	;; Frame buffer size (bytes)
;; [0x00005F10]	;; Screen X
;; [0x00005F12]	;; Screen Y
;; [0x00005F14]	;; PixelsPerScanLine
;; Luego, durante el bootloader, la mantiene aqui, pero tambien copia al infoMap
;; 0x5080

VBEModeInfoBlock:
FB:			equ 0x0000000000005F00	;; 8 bytes, 256 bytes.
FB_SIZE		equ 0x0000000000005F08	;; 8 bytes, Frame buffer size (bytes)
HR:			equ 0x0000000000005F10	;; 2 bytes, Screen X
VR:			equ 0x0000000000005F12	;; 2 bytes, Screen Y
PPSL:		equ 0x0000000000005F14	;; 2 bytes, PixelsPerScanLine

;; DQ - Starting at offset 0, increments by 0x8
p_ACPITableAddress:	equ SystemVariables + 0x00
p_LocalAPICAddress:	equ SystemVariables + 0x10
p_Counter_Timer:	equ SystemVariables + 0x18
p_Counter_RTC:		equ SystemVariables + 0x20
p_HPET_Address:		equ SystemVariables + 0x28

;; DD - Starting at offset 0x80, increments by 4
p_BSP:				equ SystemVariables + 0x80
p_mem_amount:		equ SystemVariables + 0x84	;; MiB
p_HPET_Frequency:	equ SystemVariables + 0x88

;; DW - Starting at offset 0x100, increments by 2
p_cpu_speed:		equ SystemVariables + 0x100
p_cpu_activated:	equ SystemVariables + 0x102
p_cpu_detected:		equ SystemVariables + 0x104
p_PCIECount:		equ SystemVariables + 0x106
p_HPET_CounterMin:	equ SystemVariables + 0x108
p_IAPC_BOOT_ARCH:	equ SystemVariables + 0x10A

; DB - Starting at offset 0x180, increments by 1
p_IOAPICCount:		equ SystemVariables + 0x180
p_BootMode:			equ SystemVariables + 0x181	;; 'U' for UEFI, otherwise BIOS
p_IOAPICIntSourceC:	equ SystemVariables + 0x182
p_x2APIC:			equ SystemVariables + 0x183
p_HPET_Timers:		equ SystemVariables + 0x184
p_BootDisk:			equ SystemVariables + 0x185	;; 'F' for Floppy drive
p_1gb_pages:		equ SystemVariables + 0x186	;; 1 if 1GB pages are supported

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


